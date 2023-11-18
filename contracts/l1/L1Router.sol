// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IL2Gateway.sol";

contract L1Router {
    address private owner;
    mapping(uint32 => IL2Gateway) private gateways;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ngmi");
        _;
    }

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setGateway(uint32 chainId, IL2Gateway gateway) external onlyOwner {
        gateways[chainId] = gateway;
    }

    function forwardBatch(uint32 fromChainId, bytes calldata retrievalData, bytes calldata sendData) external payable {
        uint256 batchHash = gateways[fromChainId].receiveHash(retrievalData); // this is chained hash
        uint32 toChainId = uint32(batchHash >> 224);
        gateways[toChainId].sendHash{value: msg.value}(batchHash, sendData);
    }
}