// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./LeNFT.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LeNFTFactory is AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _nftCounter;
    address public libraryAddress;
    address[] public nftAddresses;

    event NFTCreated(address _nftAddress);

    constructor(address _libraryAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        libraryAddress = _libraryAddress;
    }

    function setLibraryAddress(address _libraryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        libraryAddress = _libraryAddress;
    }

    function createNFT(string calldata _name, string calldata _symbol, string calldata _baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address){
        address clone = Clones.clone(libraryAddress);
        LeNFT(clone).initialize(_name, _symbol, _baseURI);

        nftAddresses.push(clone);
        _nftCounter.increment();

        emit NFTCreated(clone);

        return clone;
    }

    function totalNFTs() public view returns (uint) {
      return _nftCounter.current();
    }

    function getLatestNFT() public view returns (address) {
      uint current = _nftCounter.current() - 1;
      return nftAddresses[current];
    }
}