from web3 import Web3
from web3.middleware import geth_poa_middleware, construct_sign_and_send_raw_middleware
from web3.utils.address import get_create_address
import json
import subprocess
import requests
import eth_abi
import time

# holy fucking hell it is so complex to build on zksync

l1web3 = Web3(Web3.HTTPProvider("http://localhost:8545"))
l1web3.middleware_onion.inject(geth_poa_middleware, layer=0)
assert l1web3.is_connected()

print("Connected to L1 RPC")

l2web3 = Web3(Web3.HTTPProvider("http://localhost:3050"))
assert l2web3.is_connected()

print("Connected to L2 RPC")

private_key = "0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110"

zksync_manager_json = json.loads(open("tests/artifacts/ZksyncManager.sol/ZksyncManager.json").read())
zksync_gateway_json = json.loads(open("tests/artifacts/ZksyncGateway.sol/ZksyncGateway.json").read())
l1router_json = json.loads(open("tests/artifacts/L1Router.json").read())
miniaccount_json = json.loads(open("tests/artifacts/MiniAccount.json").read())

print("Imported all L1 and L2 contracts data")

l1acc = l1web3.eth.account.from_key(private_key)
l1web3.middleware_onion.add(construct_sign_and_send_raw_middleware(l1acc))
l2acc = l2web3.eth.account.from_key(private_key)
l2web3.middleware_onion.add(construct_sign_and_send_raw_middleware(l2acc))

address = l1acc.address

print("Imported keys")

l1router_contract = l1web3.eth.contract(address=get_create_address(address, l1web3.eth.get_transaction_count(address)),
                                        abi=l1router_json["abi"],
                                        bytecode=l1router_json["bytecode"])
tx_hash = l1router_contract.constructor().transact({"from": address})

print("Deployed L1Router contract on L1:", tx_hash.hex())
print("L1Router address:", l1router_contract.address)

zksync_gateway_contract = l1web3.eth.contract(address=get_create_address(address, l1web3.eth.get_transaction_count(address)),
                                              abi=zksync_gateway_json["abi"],
                                              bytecode=zksync_gateway_json["bytecode"])

print("L2 nonce:", l2web3.eth.get_transaction_count(address))

env = open(".env").read()
open(".env", "a").write(f"\nL2GATEWAY={zksync_gateway_contract.address}\n")
data = subprocess.check_output(["npx", "hardhat", "deploy-zksync", "--network", "dockerizedNode"]).decode().strip()
open(".env", "w").write(env)

zksync_manager_contract = l2web3.eth.contract(address=data[-42:],
                                              abi=zksync_manager_json["abi"],
                                              bytecode=zksync_manager_json["bytecode"])

tx_hash = zksync_gateway_contract.constructor(zksync_manager_contract.address).transact({"from": address})

print("Deployed ZksyncGateway contract on L1:", tx_hash.hex())
print("ZksyncGateway address:", zksync_manager_contract.address)

print("\nGood news - deploying works! Now testing functionality")

tx_hash = zksync_manager_contract.functions.requestOp((l2web3.eth.chain_id, 1337)).transact({"from": address, "value": 10**18})
print("Request op tx:", tx_hash.hex())

time.sleep(5)

print("Requested user operation on sender L2")
total_bid = zksync_manager_contract.functions.totalBid(l2web3.eth.chain_id).call()
print("Total bid:", total_bid)
op_requests = []
for i in range(2**256):
    try:
        op_requests.append(zksync_manager_contract.functions.opRequests(l2web3.eth.chain_id, i).call())
    except:
        break
print("Op requests:", op_requests)
batch_hash = zksync_manager_contract.functions.sendBatch(l2web3.eth.chain_id).call({"from": address})
print("Batch data:", batch_hash.hex())
tx_hash = zksync_manager_contract.functions.sendBatch(l2web3.eth.chain_id).transact({"from": address})

print("Packed user operation in batch and sent to L1")

# i'm so tired

while True:
    response = requests.post("http://localhost:3050", json={
        "jsonrpc": "2.0",
        "id": 1,
        "method": "zks_getTransactionDetails",
        "params": [
            tx_hash.hex()
        ]
    }).json()
    if response["result"]["ethExecuteTxHash"] != None:
        print(response)
        break
    time.sleep(1)

print("Transaction was finalized, proving inclusion...")

# batch_hash = (l2web3.eth.chain_id << 224 | (2**224-1 & int.from_bytes(Web3.keccak(eth_abi.encode(["(uint32,uint224)[]"], [op_requests])), "little"))).to_bytes(32)
batch_hh = Web3.keccak(batch_hash)
print("Hash of batch hash (for proving):", batch_hh.hex())

block_number = l2web3.eth.get_transaction(tx_hash).blockNumber
response = requests.post("http://localhost:3050", json={
    "jsonrpc": "2.0",
    "id": 1,
    "method": "zks_getL2ToL1MsgProof",
    "params": [
        block_number,
        zksync_manager_contract.address,
        batch_hh.hex()
    ]
}).json()

print(response)

proof = [bytes.fromhex(x[2:]) for x in response["result"]["proof"]]

retrieval_data = eth_abi.encode(["(uint256,uint256,uint16,bytes32,bytes32[])"], [(block_number, 0, 0, batch_hash, proof)])
send_data = eth_abi.encode(["(uint256,uint256,address)"], [(10**6, 10**6, address)])

l1router_contract.functions.forwardBatch(l2web3.eth.chain_id, retrieval_data, send_data).transact({"from": address, "gas": 10000000})

print("Forwarded batch hash from L1 to L2")

time.sleep(5)

zksync_manager_contract.functions.revealBatch(op_requests).transact({"from": address})

print("Revealed batch contents")

# i think that's all but i also have to test erc4337 somehow

env = open(".env").read()
open(".env", "a").write(f"\nL2MANAGER={zksync_gateway_contract.address}\n")
data = subprocess.check_output(["npx", "hardhat", "deploy-zksync", "--network", "dockerizedNode"]).decode().strip()
open(".env", "w").write(env)

print("Deployed mini account on destination L2")

miniaccount_contract = l2web3.eth.contract(address=data[-42:],
                                           abi=miniaccount_json["abi"],
                                           bytecode=miniaccount_json["bytecode"])

is_valid = miniaccount_contract.functions.validateUserOp((address,0,b"",b"",0,0,0,0,0,b"",b""), ((l2web3.eth.chain_id << 224) | 1337).to_bytes(32), 0).call({"from": address})

print(is_valid)
assert is_valid == 0, "user op was not validated :("

print("all tests done! user op hash was successfully transmitted to the destination L2")
print("and now user can send their transaction through their ERC4337 miniaccount")