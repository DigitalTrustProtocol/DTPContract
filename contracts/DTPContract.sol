// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.7;
import "hardhat/console.sol";

import "@opengsn/contracts/src/ERC2771Recipient.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./DTPAccessControl.sol";
import "./DTPResources.sol";
import "./StringExtensions.sol";

contract DTPContract is ERC2771Recipient, DTPAccessControl, ReentrancyGuard {
    using StringExtensions for string;
    using SafeERC20 for IERC20;

    bytes32 internal constant FEE_ROLE = keccak256("FEE_ROLE");
    bytes32 internal constant WITHDRAW_ROLE = keccak256("WITHDRAWAL_ROLE");

    uint256 constant MaxFee = 1e18 * 100;

    FeeToken public nativeToken;

    // @dev The path to the claim, typeId => issuer => subject => context => claim
    mapping(string => mapping(address => mapping(address => mapping(string => Claim))))
        public claims;

    // @dev The fee for each claim type, default is 1e18 as the value is used as a multiplier.
    mapping(string => FeeToken) public claimFees;

    // @dev The fee for each token address type, default is 1e18. The token acts as a base fee value.
    mapping(address => FeeToken) private tokenFees;

    // @dev The fee for each issuer address, default is 1e18 as the value is used as a multiplier.
    mapping(address => FeeToken) private issuerFees;

    //constructor(address owner_, address forwarder_) { 
    constructor() { // Currently, the owner is the deployer and the forwarder is empty to testing purposes.
        address owner = _msgSender();
        _setTrustedForwarder(address(0));

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(FEE_ROLE, owner);
        _grantRole(WITHDRAW_ROLE, owner);

        setNativeToken(true, 0);

        // Set the default fee for the no claim.
        claimFees[""] = FeeToken({accepted: true, fee: 1e18});

        // Set the default fee for the no issuer.
        issuerFees[address(0)] = FeeToken({accepted: true, fee: 1e18});

        // Set the default fee for the no token.
        tokenFees[address(0)] = FeeToken({accepted: true, fee: 1e18});
    }

    // Notify when someone sends native token to this contract.
    // receive() external payable {
    //     emit TransferReceived(_msgSender(), msg.value);
    // }

    // -----------------------------------------------
    // Events
    // -----------------------------------------------

    event ClaimPublished(
        bytes32 indexed typeId, // The typeId is of bytes32 as string is not indexed
        address indexed issuer,
        address indexed subject,
        string value,
        string context,
        string comment,
        string link,
        uint256 activate,
        uint256 expires
    );
    //event TransferReceived(address indexed _from, uint _amount);
    event Withdraw(
        address indexed _from,
        address indexed _destAddr,
        uint _amount
    );

    // -----------------------------------------------
    // Publics
    // -----------------------------------------------

    function estimateFee(
        Claim[] memory _claims,
        address issuer,
        address _token
    ) public view returns (uint256 fee_) {
        require(
            _claims.length <= 100,
            "No more than 100 claims can be submitted at once"
        );

        FeeToken memory baseFee = (_token == address(0))
            ? nativeToken
            : _getTokenFee(_token);
        require(baseFee.accepted, "Token not accepted");

        FeeToken memory issuerFee = _getIssuerFee(issuer);

        for (uint256 i = 0; i < _claims.length; i++) {
            FeeToken memory claimFee = _getClaimFee(_claims[i].typeId);
            fee_ += baseFee.fee * issuerFee.fee * claimFee.fee;
        }
    }

    function publishClaims(
        Claim[] memory _claims,
        address _token // The token to pay the fee with. If address(0) then native token is used as in msg.value.
    ) public payable nonReentrant {
        require(_claims.length > 0, "No claims provided");
        require(
            _claims.length <= 100,
            "No more than 100 claims can be submitted at once"
        );

        uint256 fee = estimateFee(_claims, _msgSender(), _token);

        require(
            _token != address(0) || (_token == address(0) && msg.value >= fee),
            "Not enough fee provided"
        );

        if (_token != address(0)) {
            // Only transfer the fee if the token is not native token.
            IERC20(_token).safeTransferFrom(_msgSender(), address(this), fee);
        }

        for (uint256 i = 0; i < _claims.length; i++) {
            _publishClaim(_claims[i]);
        }
    }

    // // -----------------------------------------------
    // // Owner functions
    // // -----------------------------------------------

    function setNativeToken(
        bool _accepted,
        uint256 _fee
    ) public onlyRole(FEE_ROLE) {
        require(_fee <= MaxFee, "Fee is too large");

        nativeToken = FeeToken({accepted: _accepted, fee: _fee});
    }

    function setClaimFees(
        string[] memory _typeId,
        FeeToken[] memory _feeTokens
    ) public onlyRole(FEE_ROLE) {
        require(
            _typeId.length == _feeTokens.length,
            "Types and fees must be the same length"
        );

        for (uint256 i = 0; i < _typeId.length; i++) {
            claimFees[_typeId[i]] = _feeTokens[i];
        }
    }

    function setTokenFees(
        address[] memory _addrs,
        FeeToken[] memory _feeTokens
    ) public onlyRole(FEE_ROLE) {
        require(
            _addrs.length == _feeTokens.length,
            "Tokens and fees must be the same length"
        );

        for (uint256 i = 0; i < _addrs.length; i++) {
            tokenFees[_addrs[i]] = _feeTokens[i];
        }
    }

    function setIssuerFees(
        address[] memory _subjects,
        FeeToken[] memory _feeTokens
    ) public onlyRole(FEE_ROLE) {
        require(
            _subjects.length == _feeTokens.length,
            "Subjects and fees must be the same length"
        );

        for (uint256 i = 0; i < _subjects.length; i++) {
            issuerFees[_subjects[i]] = _feeTokens[i];
        }
    }

    function withdraw(
        uint _amount,
        address payable _destAddr
    ) external onlyRole(WITHDRAW_ROLE) nonReentrant { // @dev ERC2771Recipient _msgSender() is not used in onlyRole.
        require(_amount <= address(this).balance, "Insufficient funds");

        _destAddr.transfer(_amount);

        emit Withdraw(msg.sender, _destAddr, _amount);
    }

    function transfer(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external onlyRole(WITHDRAW_ROLE) nonReentrant { // @dev ERC2771Recipient _msgSender() is not used in onlyRole.
        _token.safeTransfer(_to, _amount);
    }

    // // -----------------------------------------------
    // // Internals
    // // -----------------------------------------------

    function _getTokenFee(
        address _token
    ) internal view returns (FeeToken memory fee_) {
        fee_ = tokenFees[_token];
        if (!fee_.accepted) {
            fee_ = tokenFees[address(0)]; // Default fee if no fee is set for the token.
        }
    }

    function _getClaimFee(
        string memory _typeId
    ) internal view returns (FeeToken memory fee_) {
        fee_ = claimFees[_typeId];
        if (!fee_.accepted) {
            fee_ = claimFees[""]; // Default fee if no fee is set for the claim type.
        }
    }

    function _getIssuerFee(
        address _subject
    ) internal view returns (FeeToken memory fee_) {
        fee_ = issuerFees[_subject];
        if (!fee_.accepted) {
            // Default fee if no fee is set for the issuer.
            fee_ = issuerFees[address(0)];
        }
    }

    function _publishClaim(Claim memory _claim) internal {
        require(
            bytes(_claim.typeId).length <= 31,
            "typeId is too long (max 31 bytes)"
        );

        require(
            bytes(_claim.value).length <= valueMaxLength,
            "Value is too long"
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

        _claim.issuer = _msgSender(); // Override the issuer to msg.sender. This ensures that the caller is always the issuer.
        //_claim.context = _claim.context.escapeHTML(); // ensure to escape the string
        //_claim.comment = _claim.comment.escapeHTML(); // ensure to escape the string

        claims[_claim.typeId][_claim.issuer][_claim.subject][
            _claim.context
        ] = _claim;

        emit ClaimPublished(
            bytes32(bytes(_claim.typeId)),
            _claim.issuer,
            _claim.subject,
            _claim.value,
            _claim.context,
            _claim.comment,
            _claim.link,
            _claim.activate,
            _claim.expires
        );
    }
}
