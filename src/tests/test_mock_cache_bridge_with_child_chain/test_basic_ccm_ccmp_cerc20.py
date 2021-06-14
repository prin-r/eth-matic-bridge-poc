from brownie.network import account
import brownie
from brownie import accounts
from .conftest import *


def test_child_chain_manager_basic_setup():
    ccm = child_chain_manager()
    assert ccm.hasRole(ccm.DEFAULT_ADMIN_ROLE(), accounts[0]) == True
    assert ccm.hasRole(ccm.MAPPER_ROLE(), accounts[0]) == True
    assert ccm.hasRole(ccm.STATE_SYNCER_ROLE(), accounts[0]) == True


def test_child_erc20_setup():
    ccm = child_chain_manager()
    cerc20 = mock_child_erc20(ccm)

    assert cerc20.childChainManagerProxy() == ccm
    assert cerc20.name() == "TEST"
    assert cerc20.symbol() == "TEST"
    assert cerc20.decimals() == 18
