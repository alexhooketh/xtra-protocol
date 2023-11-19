npx hardhat compile
cp -r artifacts-zk/samples/zksync tests/artifacts
cp artifacts-zk/contracts/l1/L1Router.sol/L1Router.json tests/artifacts/L1Router.json
cp artifacts-zk/contracts/l2/MiniAccount.sol/MiniAccount.json tests/artifacts/MiniAccount.json
python3 tests/zksync.py