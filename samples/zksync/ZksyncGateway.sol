// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../contracts/l1/interfaces/IL2Gateway.sol";
import "@matterlabs/zksync-contracts/l1/contracts/zksync/interfaces/IZkSync.sol";
import "@matterlabs/zksync-contracts/l1/contracts/zksync/Storage.sol";

contract ZksyncGateway is IL2Gateway {

    IZkSync constant zkSync = IZkSync(0x32400084C286CF3E17e7B677ea9583e60a000324);
    address private immutable l2OpsManager;

    constructor(address _l2OpsManager) {
        l2OpsManager = _l2OpsManager;
    }

    function bytesToBytes32(bytes memory data) internal pure returns (bytes32[] memory) {
        bytes32[] memory dataArr = new bytes32[](data.length / 32);
        uint256 j = 0;
        for (uint256 i = 32; i <= data.length; i = i + 32) {
            bytes32 slot;
            assembly {
                slot := mload(add(data, i))
            }
            dataArr[j] = slot;
            j++;
        }
        return dataArr;
    }

    function receiveHash(bytes memory retrievalData) external returns (uint256) {
        (
            uint256 _l2BlockNumber,
            uint256 _index,
            uint16 txNumberInBlock,
            bytes32 _hash,
            bytes32[] memory _proof
        ) = abi.decode(retrievalData, (uint256, uint256, uint16, bytes32, bytes32[]));
        L2Message memory message = L2Message({
            txNumberInBlock: txNumberInBlock,
            sender: address(l2OpsManager),
            data: abi.encodePacked(_hash)
        });
        bool success = zkSync.proveL2MessageInclusion(_l2BlockNumber, _index, message, _proof);
        require(success, "empty");
        return uint256(_hash);
    }

    function sendHash(uint256 batchHash, bytes memory sendData) external {
        (
            uint256 _l2GasLimit,
            uint256 _l2GasPerPubdataByteLimit,
            address _refundRecipient
        ) = abi.decode(sendData, (uint256, uint256, address));

        bytes memory _calldata = abi.encodePacked(uint32(0xe3399cca), batchHash); // receiveBatchHash(uint256)
        bytes[] memory _factoryDeps;

        zkSync.requestL2Transaction(l2OpsManager, 0, _calldata, _l2GasLimit, _l2GasPerPubdataByteLimit, _factoryDeps, _refundRecipient);
    }
}