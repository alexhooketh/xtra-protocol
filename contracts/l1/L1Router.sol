// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IL2Gateway.sol";

contract L1Router {
    address public owner;

    mapping(uint256 => IL2Gateway) public gatewaysMap;
    mapping(uint256 => bytes32[]) public hashesMailbox;
    uint256[] public chainIds;


    modifier onlyOwner() {
        require(msg.sender == owner, "ngmi");
        _;
    }

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function receiveAll() public {
        for (uint256 i = 0; i < chainIds.length; i++) {
            receiveFrom(chainIds[i]);
        }
    }

    function receiveFrom(uint256 chainId) internal {
        IL2Gateway gateway = gatewaysMap[chainId];
        bytes32[] memory hashes = gateway.receiveHashes();

        for (uint256 j = 0; j < hashes.length; j++) {
            bytes32 _hash = hashes[j];
            uint256 destinationChain = uint256(_hash) >> 224;
            hashesMailbox[destinationChain].push(_hash);
        }
    }

    function sendAll() public {
        for (uint256 i = 0; i < chainIds.length; i++) {
            sendFrom(chainIds[i]);
        }
    }

    function sendFrom(uint256 chainId) internal {
        bytes32[] memory hashes = hashesMailbox[chainId];
        delete hashesMailbox[chainId];
        bytes32 aggrHash = keccak256(abi.encode(hashes));
        gatewaysMap[chainId].sendHash(aggrHash);
    }

    function executeAll() external {
        
    }

}