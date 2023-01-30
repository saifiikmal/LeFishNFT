// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract LeNFTUtility is AccessControl {

    address public nftAddress;
    address public feeReceiver;
    address public relayAddress;
    uint public pricePerMint;
    uint public relayPercentage = 50;

    event Purchased(address from, uint8 amount);

    constructor(address _nftAddress, uint _pricePerMint, address _feeReceiver, address _relayAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        nftAddress = _nftAddress;
        pricePerMint = _pricePerMint;
        feeReceiver = _feeReceiver;
        relayAddress = _relayAddress;
    }

    function setFeeReceiver(address _feeReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeReceiver = _feeReceiver;
    }

    function setRelayAddress(address _relayAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        relayAddress = _relayAddress;
    }

    function setRelayPercentage(uint8 _relayPercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        relayPercentage = _relayPercentage;
    }

    function purchase(uint8 amount) public payable {
        require(amount >= 1 && amount <= 10, "Invalid NFT amount");

        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
          require(msg.value >= pricePerMint * amount, "Insufficient amount");
        }

        if (msg.value > 0) {
            uint relayCut = (msg.value * relayPercentage) / 100;
            (bool success, ) = payable(feeReceiver).call{value: msg.value - relayCut}(
                ""
            );
            require(success);

            (bool success2, ) = payable(relayAddress).call{value: relayCut}(
                ""
            );
            require(success2);
        }

        emit Purchased(msg.sender, amount);
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(feeReceiver).transfer(address(this).balance);
    }

}