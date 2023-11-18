// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IL2Gateway {

    function receiveHashes() external returns (bytes32[] memory);
    function sendHash(bytes32 aggrHash) external;
    
}