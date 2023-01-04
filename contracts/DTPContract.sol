// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity ^0.8.7;
import "hardhat/console.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./DTPResources.sol";
import "./StringExtensions.sol";


contract DTPContract is AccessControl, ReentrancyGuard {
    using StringExtensions for string;
    using SafeERC20 for IERC20;

    bytes32 internal constant FEE_ROLE = keccak256("FEE_ROLE");
    bytes32 internal constant WITHDRAW_ROLE = keccak256("WITHDRAWAL_ROLE");

    uint256 constant MaxFee = 1e18 * 100;

    FeeToken public nativeToken;

    mapping(bytes32 => Claim) public claims;

    // @dev The fee for each claim type, default is 1e18 as the value is used as a multiplier.
    mapping(string => FeeToken) public claimFees; 

    // @dev The fee for each token address type, default is 1e18 as the value is used as a multiplier.
    mapping(address => FeeToken) private tokenFees;

    // @dev The fee for each issuer address, default is 1e18 as the value is used as a multiplier.
    mapping(address => FeeToken) private issuerFees;

    // Notify when someone sends native token to this contract.
    receive() external payable {
        emit TransferReceived(msg.sender, msg.value);
    }

    //constructor(address owner) {
    constructor() {

        address owner = msg.sender;
    
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(FEE_ROLE, owner);
        _grantRole(WITHDRAW_ROLE, owner);

        setNativeToken(true, 0);

        // Set the default fee for the no claim.        
        setClaimFee("", true, 1e18);
        
        // Set the default fee for the no issuer.
        setIssuerFee(address(0), true, 1e18);

        // Set the default fee for the no token.
        setTokenFee(address(0), true, 1e18);
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

    function estimateFee(Claim[] memory _claims, address issuer, address _token) public view returns (uint256 fee_) {
        FeeToken memory baseFee = (_token == address(0)) ? nativeToken: _getTokenFee(_token);

        require(baseFee.accepted, "Token not accepted");
        
        FeeToken memory issuerFee = _getIssuerFee(issuer);

        for (uint256 i = 0; i < _claims.length; i++) {
            FeeToken memory claimFee = _getClaimFeeFactor(_claims[i].typeId);
            fee_ += baseFee.fee * issuerFee.fee * claimFee.fee;
        }
    }

    function publishClaims(
        Claim[] memory _claims,
        address _token
    ) public payable nonReentrant returns (bytes32[] memory id_) {
        require(_claims.length > 0, "No claims provided");
        require(
            _claims.length <= 100,
            "No more than 100 claims can be submitted at once"
        );
        

        uint256 fee = estimateFee(_claims, msg.sender, _token);

        require(_token != address(0) || (_token == address(0) && msg.value >= fee), "Not enough fee provided");

        if(_token != address(0)) {
            // Only transfer the fee if the token is not native token.
            IERC20(_token).safeTransferFrom(msg.sender, address(this), fee);
        }

        id_ = new bytes32[](_claims.length);
        for (uint256 i = 0; i < _claims.length; i++) {
            id_[i] = _publishClaim(_claims[i]);
        }
    }

    // // -----------------------------------------------
    // // Owner functions
    // // -----------------------------------------------

    function setNativeToken(bool _accepted, uint256 _fee) public onlyRole(FEE_ROLE) {
        require(_fee <= MaxFee, "Fee is too large");

        nativeToken = FeeToken({accepted: _accepted, fee: _fee});
    }

    function setClaimFee(
        string memory _typeId,
        bool _accepted,
        uint256 _feeFactor
    ) public onlyRole(FEE_ROLE) {
        require(_feeFactor <= MaxFee, "Fee factor is too large");

        claimFees[_typeId] = FeeToken({accepted: _accepted, fee: _feeFactor});
    }


    function setTokenFee(
        address _token,
        bool _accepted,
        uint256 _fee
    ) public onlyRole(FEE_ROLE) {
        require(_fee <= MaxFee, "Fee is too large");

        tokenFees[_token] = FeeToken({accepted: _accepted, fee: _fee});
    }

    function setIssuerFee(
        address _subject,
        bool _accepted,
        uint256 _fee
    ) public onlyRole(FEE_ROLE) {
        require(_fee <= MaxFee, "Fee is too large");

        issuerFees[_subject] = FeeToken({
            accepted: _accepted,
            fee: _fee
        });
    }

    function withdraw(
        uint _amount,
        address payable _destAddr
    ) external onlyRole(WITHDRAW_ROLE) nonReentrant {
        require(_amount <= address(this).balance, "Insufficient funds");

        _destAddr.transfer(_amount);

        emit TransferSent(msg.sender, _destAddr, _amount);
    }

    function transferERC20(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external onlyRole(WITHDRAW_ROLE) nonReentrant {
        _token.safeTransfer(_to, _amount);
    }

    // // -----------------------------------------------
    // // Internals
    // // -----------------------------------------------

     function _getTokenFee(address _token) internal view returns (FeeToken memory fee_) {
        fee_ = tokenFees[_token];
        if (!fee_.accepted) {
            fee_ = tokenFees[address(0)]; // Default fee if no fee is set for the token.
        } 
    }
    
    function _getClaimFeeFactor(string memory _typeId) internal view returns (FeeToken memory fee_) {
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
            fee_ = issuerFees[address(0)];
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
