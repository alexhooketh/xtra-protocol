// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IL2OpsManager.sol";

abstract contract BaseL2OpsManager is IL2OpsManager {
    mapping(uint32 => ChainedHash[]) public opRequests;
    mapping(uint32 => uint256) public totalBid;

    mapping(uint256 => bool) public userOpHashes;
    mapping(uint256 => bool) public unrevealedBatches;

    address private immutable l1Router;
    address private immutable l2Gateway;

    constructor(address _l1Router, address _l2Gateway) {
        l1Router = _l1Router;
        l2Gateway = _l2Gateway;
    }

    modifier onlyFromL1Router {
        _onlyFromL1Router();
        _;
    }

    function calculateSendGas(uint256 batchLength) public pure virtual returns (uint256);

    function requestOp(ChainedHash calldata opHash) external payable {

        uint256 sendGas = calculateSendGas(opRequests[opHash.destinationChainId].length);
        uint256 totalSendFee = sendGas * block.basefee;
        require(totalBid[opHash.destinationChainId] + msg.value >= totalSendFee, "gas bid too low");
        
        opRequests[opHash.destinationChainId].push(opHash);
        totalBid[opHash.destinationChainId] += msg.value;
    }

    function sendChainedHashToL1(ChainedHash memory chainedHash) internal virtual;

    function sendBatch(uint32 chainId) external returns (ChainedHash[] memory hashes) {
        ChainedHash memory batchHash;
        batchHash.destinationChainId = chainId;
        batchHash.userOpHash = uint224(uint256(keccak256(abi.encode(opRequests[chainId]))));

        sendChainedHashToL1(batchHash);

        payable(msg.sender).call{value: totalBid[chainId]}("");
        hashes = opRequests[chainId];
        delete opRequests[chainId];
        delete totalBid[chainId];
    }

    function _onlyFromL1Router() internal virtual;

    function receiveBatchHash(uint256 batchHash) external onlyFromL1Router {
        unrevealedBatches[batchHash] = true;
    }

    function revealBatch(ChainedHash[] calldata batch) external {
        uint32 chainId;
        assembly {
            chainId := chainid()
        }
        ChainedHash memory batchHash;
        batchHash.destinationChainId = chainId;
        batchHash.userOpHash = uint224(uint256(keccak256(abi.encode(batch))));
        if (unrevealedBatches[serializeChainedHash(batchHash)]) {
            for (uint256 i = 0; i < batch.length; i++) {
                userOpHashes[serializeChainedHash(batch[i])] = true;
            }
        }
    }
}