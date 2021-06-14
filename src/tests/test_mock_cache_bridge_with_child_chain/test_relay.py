from brownie.network import account
import brownie
from brownie import accounts
from .conftest import *
from eth_abi import encode_abi

USER = "0xb011d306d36c396847ba42b1c7aeb8e96c540d9a"
ROOT_CHAIN_TOKEN = "0x499d11e0b6eac7c0593d8fb292dcbbf815fb29ae"


def setup_contracts(min_count, ask_count):
    mcb = mock_cache_bridge(min_count, ask_count)
    ccm = child_chain_manager()
    ccm.setBridge(mcb)
    cerc20 = mock_child_erc20(ccm)

    return mcb, ccm, cerc20


def set_root_child_mapping(ccm, root, child):
    sync_type_map_token = ccm.MAP_TOKEN()
    sync_data = encode_abi(["address", "address", "bytes32"], [root, child, b"0" * 32])
    data = encode_abi(["bytes32", "bytes"], [sync_type_map_token, sync_data])

    ccm.onStateReceive(0, data)


def test_setup():
    mcb, ccm, _ = setup_contracts(1, 1)
    assert mcb == ccm.mockCacheBridge()


def test_map_root_child_token():
    _, ccm, cerc20 = setup_contracts(1, 1)

    assert ccm.rootToChildToken(ROOT_CHAIN_TOKEN) == "0x" + "0" * 40
    assert ccm.childToRootToken(cerc20) == "0x" + "0" * 40

    set_root_child_mapping(ccm, ROOT_CHAIN_TOKEN, cerc20.address)

    assert ccm.rootToChildToken(ROOT_CHAIN_TOKEN) == cerc20.address
    assert ccm.childToRootToken(cerc20) == ROOT_CHAIN_TOKEN


def test_relay_1_1():
    _, ccm, cerc20 = setup_contracts(1, 1)
    set_root_child_mapping(ccm, ROOT_CHAIN_TOKEN, cerc20.address)

    assert cerc20.balanceOf(USER) == 0

    sync_type_deposit = ccm.DEPOSIT()

    data = encode_abi(
        ["bytes32", "bytes"], [sync_type_deposit, bytes.fromhex(testnet3_proof_1_1())]
    )
    ccm.onStateReceive(0, data)

    assert cerc20.balanceOf(USER) == 1000000000000000000


def test_relay_3_4():
    _, ccm, cerc20 = setup_contracts(3, 4)
    set_root_child_mapping(ccm, ROOT_CHAIN_TOKEN, cerc20.address)

    assert cerc20.balanceOf(USER) == 0

    sync_type_deposit = ccm.DEPOSIT()

    data = encode_abi(
        ["bytes32", "bytes"], [sync_type_deposit, bytes.fromhex(testnet3_proof_3_4())]
    )
    ccm.onStateReceive(0, data)

    assert cerc20.balanceOf(USER) == 1000000000000000000
