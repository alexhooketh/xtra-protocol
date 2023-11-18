// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../contracts/l2/BaseL2OpsManager.sol";
import "../../contracts/l2/interfaces/IL2OpsManager.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/contracts/vendor/AddressAliasHelper.sol";

contract ZksyncManager is BaseL2OpsManager {

    address private immutable l1Router;

    constructor(address _l1Router) {
        l1Router = _l1Router;
    }

    function calculateSendFee() public override returns (uint256) {
        return 100000; // TODO: make more efficient gas calculation
    }

    function sendChainedHashToL1(ChainedHash memory chainedHash) internal override {
        uint256 rawHash = serializeChainedHash(chainedHash);
        L1_MESSENGER_CONTRACT.sendToL1(abi.encodePacked(rawHash));
    }

    function _onlyFromL1Router() internal override {
        require(AddressAliasHelper.undoL1ToL2Alias(msg.sender) == l1Router, "ngmi");
    }
}