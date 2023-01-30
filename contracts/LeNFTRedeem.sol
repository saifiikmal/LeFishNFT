// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "@opengsn/contracts/src/BaseRelayRecipient.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC721{
    function mint(address to, uint tokenId, string calldata uri) external;
}

struct NFTVoucher {
    uint256 tokenId;
    string tokenSHA256;
}

contract LeNFTRedeem is EIP712, AccessControl, BaseRelayRecipient {
    using ECDSA for bytes32;
    address public nftAddress;
    address public forwarder;

    event Redeem(address from, uint tokenId, string tokenSHA256);

    constructor(address _forwarder, address _nftAddress) EIP712("LeNFTRedeem", "1.0.0"){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setTrustedForwarder(_forwarder);


        forwarder = _forwarder;
        nftAddress = _nftAddress;
    }

    function setNftAddress(address _nftAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nftAddress = _nftAddress;
    }

    function setTrustedForwarder(address _forwarder) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTrustedForwarder(_forwarder);
        forwarder = _forwarder;
    }

    function redeem(NFTVoucher calldata voucher, bytes memory signature) public {
        address signer = _verify(voucher, signature);
        require(signer == _msgSender(), "Invalid redeemer");

        IERC721(nftAddress).mint(signer, voucher.tokenId, voucher.tokenSHA256);

        emit Redeem(signer, voucher.tokenId, voucher.tokenSHA256);
    }
    
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
        keccak256("NFTVoucher(uint256 tokenId,string tokenSHA256)"),
        voucher.tokenId,
        keccak256(bytes(voucher.tokenSHA256))
        )));
    }

    function _verify(NFTVoucher calldata voucher, bytes memory signature) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return digest.toEthSignedMessageHash().recover(signature);
    }

    function versionRecipient() external override pure returns (string memory){
        return "2.2.5";
    }

    function _msgSender() internal view override(Context, BaseRelayRecipient) returns (address) {
        return BaseRelayRecipient._msgSender();
    }

    function _msgData() internal override(Context, BaseRelayRecipient) virtual view returns (bytes calldata ret) {
        return BaseRelayRecipient._msgData();
    }
}