// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@opengsn/contracts/src/forwarder/IForwarder.sol";
import "@opengsn/contracts/src/BasePaymaster.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LeNFTPaymaster is AccessControl, BasePaymaster {
    bool public useSenderWhitelist;
    bool public useTargetWhitelist;
    bool public useMethodWhitelist;
    mapping(address => bool) public senderWhitelist;
    mapping(address => bool) public targetWhitelist;
    mapping(address => mapping(bytes4 => bool)) public methodWhitelist;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function versionPaymaster() external view override virtual returns (string memory){
        return "2.2.5";
    }

    function whitelistSender(address sender, bool isAllowed) public onlyRole(DEFAULT_ADMIN_ROLE) {
        senderWhitelist[sender] = isAllowed;
        useSenderWhitelist = true;
    }

    function whitelistTarget(address target, bool isAllowed) public onlyRole(DEFAULT_ADMIN_ROLE) {
        targetWhitelist[target] = isAllowed;
        useTargetWhitelist = true;
    }

    function whitelistMethod(address target, bytes4 method, bool isAllowed) public onlyRole(DEFAULT_ADMIN_ROLE) {
        methodWhitelist[target][method] = isAllowed;
        useMethodWhitelist = true;
    }

    function setConfiguration(
        bool _useSenderWhitelist,
        bool _useTargetWhitelist,
        bool _useMethodWhitelist
    ) public onlyOwner {
        useSenderWhitelist = _useSenderWhitelist;
        useTargetWhitelist = _useTargetWhitelist;
        useMethodWhitelist = _useMethodWhitelist;
    }

    function preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
    external
    override
    virtual
    returns (bytes memory context, bool revertOnRecipientRevert) {
        // (relayRequest, signature, approvalData, maxPossibleGas);
        // return ("", false);
        //(signature);
        //_verifyForwarder(relayRequest);
        //(approvalData, maxPossibleGas);
        (signature, maxPossibleGas);
        _verifyForwarder(relayRequest);
        require(approvalData.length == 0, "approvalData: invalid length");
        require(relayRequest.relayData.paymasterData.length == 0, "paymasterData: invalid length");

        if (useSenderWhitelist) {
            address sender = relayRequest.request.from;
            require(senderWhitelist[sender], "sender not whitelisted");
        }

        if (useTargetWhitelist) {
            address target = relayRequest.request.to;
            require(targetWhitelist[target], "target not whitelisted");
        }

        if (useMethodWhitelist) {
            address target = relayRequest.request.to;
            bytes4 method = GsnUtils.getMethodSig(relayRequest.request.data);
            require(methodWhitelist[target][method], "method not whitelisted");
        }
        return ("no revert here",false);
    }

    function postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    ) external override virtual {
        (context, success, gasUseWithoutPost, relayData);
    }

    function deposit() public payable {
        require(address(relayHub) != address(0), "relay hub address not set");
        relayHub.depositFor{value:msg.value}(address(this));
    }

    function withdrawAll(address payable destination) public onlyOwner {
        uint256 amount = relayHub.balanceOf(address(this));
        withdrawRelayHubDepositTo(amount, destination);
    }
}