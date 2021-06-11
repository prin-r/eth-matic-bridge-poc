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


# def test_vrf_request_by_consumer(vrf_provider, mock_vrf_consumer):
#     key = vrf_provider.getKey(mock_vrf_consumer.address, *INPUT_SEED_TIME[0])
#     # before request
#     task = vrf_provider.tasks(key)
#     assert task == (
#         "0x" + ("0" * 40),
#         0,
#         False,
#         "0x00",
#     )

#     mock_vrf_consumer.requestRandomDataFromProvider(
#         *INPUT_SEED_TIME[0], {"from": accounts[1], "value": BOUNTY}
#     )

#     # after request
#     task = vrf_provider.tasks(key)
#     assert task == (
#         mock_vrf_consumer.address,
#         BOUNTY,
#         False,
#         "0x00",
#     )


# def test_consume_fail_not_the_provider(mock_vrf_consumer):
#     fake_result = "a" * 64
#     with brownie.reverts("Caller is not the provider"):
#         mock_vrf_consumer.consume(
#             INPUT_SEED_TIME[0][0], INPUT_SEED_TIME[0][1], fake_result, {"from": accounts[1]}
#         )


# def test_vrf_request_relay_consume_fail_task_not_found(vrf_provider, testnet_vrf_proof):
#     new_consumer = accounts[0].deploy(MockVRFConsumer, vrf_provider.address)
#     with brownie.reverts("Task not found"):
#         vrf_provider.relayProof(new_consumer.address, testnet_vrf_proof, {"from": accounts[1]})


# def test_vrf_request_relay_consume_fail_os_id_not_match(
#     mock_vrf_consumer, vrf_provider, testnet_vrf_proof_wrong_os
# ):
#     with brownie.reverts("Oracle Script ID not match"):
#         vrf_provider.relayProof(
#             mock_vrf_consumer.address, testnet_vrf_proof_wrong_os, {"from": accounts[1]}
#         )


# def test_vrf_request_relay_consume_fail_min_count_not_match(
#     mock_vrf_consumer, vrf_provider, testnet_vrf_proof_wrong_min_count
# ):
#     with brownie.reverts("Min Count not match"):
#         vrf_provider.relayProof(
#             mock_vrf_consumer.address, testnet_vrf_proof_wrong_min_count, {"from": accounts[1]}
#         )


# def test_vrf_request_relay_consume_fail_ask_count_not_match(
#     mock_vrf_consumer, vrf_provider, testnet_vrf_proof_wrong_ask_count
# ):
#     with brownie.reverts("Ask Count not match"):
#         vrf_provider.relayProof(
#             mock_vrf_consumer.address, testnet_vrf_proof_wrong_ask_count, {"from": accounts[1]}
#         )


# def test_vrf_request_relay_consume_success(vrf_provider, mock_vrf_consumer, testnet_vrf_proof):
#     assert mock_vrf_consumer.latestSeed() == ""
#     assert mock_vrf_consumer.latestTime() == 0
#     assert mock_vrf_consumer.latestResult() == "0x00"

#     account2_prev_balance = accounts[2].balance()
#     tx = vrf_provider.relayProof(
#         mock_vrf_consumer.address, testnet_vrf_proof, {"from": accounts[2]}
#     )
#     assert tx.status == 1

#     # relayer must receive the bounty
#     assert accounts[2].balance() == account2_prev_balance + BOUNTY

#     key = vrf_provider.getKey(mock_vrf_consumer.address, *INPUT_SEED_TIME[0])
#     task = vrf_provider.tasks(key)
#     assert task == (
#         mock_vrf_consumer.address,
#         BOUNTY,
#         True,
#         EXPECTED_RESULT,
#     )

#     assert mock_vrf_consumer.latestSeed() == INPUT_SEED_TIME[0][0]
#     assert mock_vrf_consumer.latestTime() == INPUT_SEED_TIME[0][1]
#     assert mock_vrf_consumer.latestResult() == EXPECTED_RESULT


# def test_vrf_request_relay_consume_fail_task_already_resolved(
#     vrf_provider, mock_vrf_consumer, testnet_vrf_proof
# ):
#     with brownie.reverts("Task already resolved"):
#         vrf_provider.relayProof(mock_vrf_consumer.address, testnet_vrf_proof, {"from": accounts[2]})
