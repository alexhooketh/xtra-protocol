// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IL2Gateway {

    function receiveHash(bytes memory retrievalData) external returns (uint256);
    function sendHash(uint256 batchHash, bytes memory sendData) external;
    
}