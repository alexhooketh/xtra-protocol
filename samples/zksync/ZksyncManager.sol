// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../contracts/l2/BaseL2OpsManager.sol";
import "../../contracts/l2/interfaces/IL2OpsManager.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/contracts/vendor/AddressAliasHelper.sol";

contract ZksyncManager is BaseL2OpsManager {

    address private immutable l2Gateway;

    constructor(address _l2Gateway) {
        l2Gateway = _l2Gateway;
    }

    function calculateSendFee() public pure override returns (uint256) {
        return 100000; // TODO: make more efficient gas calculation
    }

    function sendChainedHashToL1(ChainedHash memory chainedHash) internal override returns (bytes memory _msg) {
        uint256 rawHash = serializeChainedHash(chainedHash);
        _msg = abi.encodePacked(rawHash);
        L1_MESSENGER_CONTRACT.sendToL1(_msg);
    }

    function _onlyFromL1Router() internal view override {
        require(AddressAliasHelper.undoL1ToL2Alias(msg.sender) == l2Gateway, "ngmi");
    }
}