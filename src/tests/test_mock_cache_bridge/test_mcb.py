from brownie.network import account
import brownie
from brownie import accounts
from .conftest import *


def test_basic_init_global_vars():
    mcb = mock_cache_bridge(1, 1)
    assert mcb.templateRequestPacket() == ("", 42, "0x", 1, 1)

    mcb = mock_cache_bridge(3, 4)
    assert mcb.templateRequestPacket() == ("", 42, "0x", 4, 3)

    assert mcb.owner() == accounts[0]


def test_set_global_vars():
    mcb = mock_cache_bridge(1, 1)
    assert mcb.templateRequestPacket() == ("", 42, "0x", 1, 1)

    mcb.setTemplateResponsePacket(77, 88, 99, {"from": accounts[0]})
    assert mcb.templateRequestPacket() == ("", 77, "0x", 99, 88)


def test_relay_and_get_sync_result():
    mcb = mock_cache_bridge(1, 1)

    key = mcb.getCacheKey(
        4929795,
        '"0xc88beab5124712122d3888f5d59e4ab77ad14eb77f1c1f93fb41b42822465804"',
        '"0xeaa852323826c71cd7920c3b4c007184234c3945"',
        2,
    )
    assert key == "0xe67d7ce60d63d0184d27bec063f6a5f82a3db572a0bd7b9dd27a71d2dc15ddf7"

    rc = mcb.requestsCache(key)
    assert rc == ("0x" + "0" * 40, "0x" + "0" * 40, "0x")

    mcb.relayAndGetSyncResult(testnet3_proof_1_1(), {"from": accounts[1]})

    rc = mcb.requestsCache(key)
    assert rc == (
        "0xB011D306D36c396847bA42b1c7AEb8E96C540d9a",
        "0x499d11E0b6eAC7c0593d8Fb292DCBbF815Fb29Ae",
        "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
    )
