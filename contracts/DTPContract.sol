// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.7;
import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./DTPResources.sol";
import "./StringExtensions.sol";

contract DTPContract is Ownable, ReentrancyGuard {
    using StringExtensions for string;
    using SafeERC20 for IERC20;

    uint256 constant MaxFee = 1e18 * 100;

    FeeToken public nativeToken;


    mapping(bytes32 => Claim) public claims;
    mapping(address => FeeToken) private feeTokens;
    mapping(address => mapping(address => FeeToken)) private individualFee;

    // Notify when someone sends native token to this contract.
    receive() external payable {
        emit TransferReceived(msg.sender, msg.value);
    }

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    event ClaimPublished(
        bytes32 claimId, 
        bytes32 indexed typeId, // The typeId is of bytes32 as string is not indexed
        address indexed issuer,
        address indexed subject,
        string value,
        string scope,
        string context,
        string comment,
        string link,
        uint256 activate,
        uint256 expire
    );

    event TransferReceived(address indexed _from, uint _amount);
    event TransferSent(
        address indexed _from,
        address indexed _destAddr,
        uint _amount
    );

    // -----------------------------------------------
    // Publics
    // -----------------------------------------------

    function getClaimId(
        string memory _typeId,
        address _issuer,
        address _subject,
        string memory _scope,
        string memory _context
    ) public pure returns (bytes32 id_) {
        require(bytes(_scope).length <= scopeMaxLength, "Context too long");
        require(bytes(_context).length <= contextMaxLength, "Context too long");

        id_ = keccak256(
            abi.encode(_typeId, _issuer, _subject, _scope, _context)
        );
    }

    function escapeClaim(
        Claim memory _claim
    ) public pure returns (Claim memory) {
        _claim.scope = _claim.scope.escapeHTML(); // ensure to escape the string
        _claim.context = _claim.context.escapeHTML(); // ensure to escape the string
        _claim.comment = _claim.comment.escapeHTML(); // ensure to escape the string
        //_claim.link // Link is not escaped!
        return _claim;
    }

    function publishClaims(
        Claim[] memory _claim,
        address _token,
        uint256 _fee // User provided fee as security feature.
    ) public payable nonReentrant returns (bytes32[] memory id_) {
        require(_claim.length > 0, "No claims provided");
        require(
            _claim.length <= 100,
            "No more than 100 claims can be submitted at once"
        );

        _transferFee(_token, _fee, _claim.length);

        id_ = new bytes32[](_claim.length);
        for (uint256 i = 0; i < _claim.length; i++) {
            id_[i] = _publishClaim(_claim[i]);
        }
    }

    function publishClaim(
        Claim memory _claim,
        address _token,
        uint256 _fee // User provided fee as security feature.
    ) public payable nonReentrant returns (bytes32 id_) {
        // Maybe?!
        //require(_activate == 0 || (_activate > 0 && _activate >= block.timestamp), "Activate cannot be less than blockchain timestamp");
        //require(_expire == 0 || (_expire > 0 && _expire >= block.timestamp), "Activate cannot be less than blockchain timestamp");

        _transferFee(_token, _fee, 1);
        id_ = _publishClaim(_claim);
    }

    // // -----------------------------------------------
    // // Owner functions
    // // -----------------------------------------------

    function setNativeToken(bool _accepted, uint256 _fee) external onlyOwner {
        require(_fee <= MaxFee, "Fee is too large");

        nativeToken = FeeToken({accepted: _accepted, fee: _fee});
    }

    function setFeeToken(
        address _token,
        bool _accepted,
        uint256 _fee
    ) external onlyOwner {
        require(_fee <= MaxFee, "Fee is too large");

        feeTokens[_token] = FeeToken({accepted: _accepted, fee: _fee});
    }

    function setIndividualFee(
        address _subject,
        address _token,
        bool _accepted,
        uint256 _fee
    ) external onlyOwner {
        require(_fee <= MaxFee, "Fee is too large");

        individualFee[_subject][_token] = FeeToken({
            accepted: _accepted,
            fee: _fee
        });
    }

    function withdraw(
        uint _amount,
        address payable _destAddr
    ) external onlyOwner nonReentrant {
        require(_amount <= address(this).balance, "Insufficient funds");

        _destAddr.transfer(_amount);

        emit TransferSent(msg.sender, _destAddr, _amount);
    }

    function transferERC20(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        //require(_amount <= _token.balanceOf(address(this)), "balance is low");
        _token.safeTransfer(_to, _amount);
    }

    // // -----------------------------------------------
    // // Internals
    // // -----------------------------------------------

    function _transferFee(
        address _token,
        uint256 _fee, // User provided fee as security feature.
        uint256 _feeMultiplier
    ) internal {
        uint256 fee = _fee * _feeMultiplier;
        require(fee <= MaxFee, "Fee is too large"); // Failsafe. Make sure that the fee is not too large.

        if (nativeToken.accepted) {
            // Pay the fee in native token.

            require(
                msg.value >= nativeToken.fee * _feeMultiplier,
                "Fee amount is too small"
            );
        } else if (_token != address(0)) {
            // Pay fee with token
            FeeToken memory feeToken = individualFee[msg.sender][_token];

            if (feeToken.accepted == false) {
                feeToken = feeTokens[_token];
                if (feeToken.accepted == false)
                    revert("Fee token provided is not accepted");
            }

            require(
                fee >= feeToken.fee * _feeMultiplier,
                "Fee amount is too small"
            );

            if (fee > 0)
                IERC20(_token).safeTransferFrom(msg.sender, address(this), fee);
        } else {
            revert("No fee provided");
        }
    }

    function _publishClaim(Claim memory _claim) internal returns (bytes32 id_) {
        require(
            bytes(_claim.typeId).length <= 31,
            "typeId is too long (max 31 bytes)"
        );

        require(
            bytes(_claim.value).length <= valueMaxLength,
            "Value is too long"
        );
        require(
            bytes(_claim.scope).length <= scopeMaxLength,
            "Scope is too long"
        );
        require(
            bytes(_claim.context).length <= contextMaxLength,
            "Context is too long"
        );
        require(
            bytes(_claim.comment).length <= commentMaxLength,
            "Comment is too long"
        );
        require(bytes(_claim.link).length <= linkMaxLength, "Link is too long");

        _claim.issuer = msg.sender; // Override the issuer to msg.sender. This ensures that the caller is always the issuer.
        _claim.scope = _claim.scope.escapeHTML(); // ensure to escape the string
        _claim.context = _claim.context.escapeHTML(); // ensure to escape the string
        _claim.comment = _claim.comment.escapeHTML(); // ensure to escape the string

        id_ = _setClaim(_claim);

        emit ClaimPublished(
            id_,
            bytes32(bytes(_claim.typeId)),
            _claim.issuer,
            _claim.subject,
            _claim.value,
            _claim.scope,
            _claim.context,
            _claim.comment,
            _claim.link,
            _claim.activate,
            _claim.expire
        );
    }

    function _setClaim(Claim memory _claim) internal returns (bytes32 id_) {
        id_ = getClaimId(
            _claim.typeId,
            _claim.issuer,
            _claim.subject,
            _claim.scope,
            _claim.context
        );
        claims[id_] = _claim;
    }
}
