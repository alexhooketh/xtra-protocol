// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Chained hash is keccak256 hash of ERC4337 user operation
// with destination chain id. Only last 224 bits of hash are used
// so the whole chained hash can be fit in 32 bytes
struct ChainedHash {
    uint32 destinationChainId;
    uint224 userOpHash; // user op which is hashed here must not contain signature field
}

function serializeChainedHash(ChainedHash memory opHash) pure returns (uint256) {
    return (uint256(opHash.destinationChainId) << 224) | uint256(opHash.userOpHash);
}

function deserializeChainedHash(uint256 serialized) pure returns (ChainedHash memory chainedHash) {
    chainedHash.destinationChainId = uint32(serialized >> 224);
    chainedHash.userOpHash = uint224(serialized);
}

interface IL2OpsManager {
    // Chained hashes of userop requests.
    // Key is destination chain, value is chained hash of user operation
    // function opRequests(uint32) external returns (ChainedHash[] memory);

    // Arrived userop hashes.
    // They're used for MiniAccount "signature" validations
    function userOpHashes(uint256) external returns (bool);

    // Arrived hashes of userop batches.
    // All hashes are removed when their original value is revealed
    // by revealBatch()
    // function unrevealedBatches(uint256) external returns (bool);

    // In order to save L1 calldata, userop requests are divided into
    // groups based on destination chain and hashed into chained hash.
    // This chained hash will be sent right to the destination L2,
    // and any operator can reveal batch's content to earn some reward.
    //
    // Then, these userop hashes are used in miniaccount's ERC4337 validateUserOp
    // so we don't need to implement custom mempools etc
    //
    // Because of this system, users have to add some fee in the common
    // reward pool so their batch becomes profitable to send
    function totalBid(uint32) external returns (uint256);

    // Calculates how much ETH will be spent when sending the hash to L1.
    // This function is needed for calculating minimum requestOp() bid.
    //
    // It's recommended that implementers of L2OpsManager on custom L2
    // add some additional fee to this function to prevent batch halt on
    // gas spikes and incentivize operators on L1 to forward the batch.
    function calculateSendFee() external returns (uint256);
    // Stores userop hash in the contract's storage until some operator
    // uses it to build the batch and send it to L1 router.
    //
    // Users have to send some amount of ETH which will be used as
    // incentive for operators. Minimum fee can be calculated like this:
    // calculateSendGas() * basefee
    function requestOp(ChainedHash calldata opHash) external payable;
    // Fetches all userop requests where destination id is chainId,
    // hashes them into chained hash and sends the hash to L1 router.
    // Total bid of all chosen requests is then sent to the batch sender.
    function sendBatch(uint32 chainId) external returns (bytes memory);
    // Receives the hash of the batch from L1.
    // It'll be stored in the contract storage until any operator
    // reveals the batch.
    //
    // This function MUST check if the tx was received from L1Router
    // and if it's not, revert
    function receiveBatchHash(uint256 batchHash) external;
    // Hashes all 
    // function revealBatch(uint256[] calldata batch) external;
}