// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {BlockHeaderMerkleParts} from "./library/BlockHeaderMerkleParts.sol";
import {MultiStore} from "./library/MultiStore.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAVLMerklePath} from "./library/IAVLMerklePath.sol";
import {TMSignature} from "./library/TMSignature.sol";
import {Utils} from "./library/Utils.sol";
import {Packets} from "./library/Packets.sol";
import {IBridge} from "../../interfaces/bridge/IBridge.sol";

/// @title BandChain Bridge
/// @author Band Protocol Team
contract Bridge is IBridge, Ownable {
    using BlockHeaderMerkleParts for BlockHeaderMerkleParts.Data;
    using MultiStore for MultiStore.Data;
    using IAVLMerklePath for IAVLMerklePath.Data;
    using TMSignature for TMSignature.Data;
    using SafeMath for uint256;

    struct ValidatorWithPower {
        address addr;
        uint256 power;
    }

    struct BlockDetail {
        bytes32 oracleState;
        uint64 timeSecond;
        uint32 timeNanoSecond;
    }

    /// Mapping from block height to the struct that contains block time and hash of "oracle" iAVL Merkle tree.
    mapping(uint256 => BlockDetail) public blockDetails;
    /// Mapping from an address to its voting power.
    mapping(address => uint256) public validatorPowers;
    /// The total voting power of active validators currently on duty.
    uint256 public totalValidatorPower;

    /// Initializes an oracle bridge to BandChain.
    /// @param validators The initial set of BandChain active validators.
    constructor(ValidatorWithPower[] memory validators) public {
        for (uint256 idx = 0; idx < validators.length; ++idx) {
            ValidatorWithPower memory validator = validators[idx];
            require(
                validatorPowers[validator.addr] == 0,
                "DUPLICATION_IN_INITIAL_VALIDATOR_SET"
            );
            validatorPowers[validator.addr] = validator.power;
            totalValidatorPower = totalValidatorPower.add(validator.power);
        }
    }

    /// Update validator powers by owner.
    /// @param validators The changed set of BandChain validators.
    function updateValidatorPowers(ValidatorWithPower[] memory validators)
        external
        onlyOwner
    {
        for (uint256 idx = 0; idx < validators.length; ++idx) {
            ValidatorWithPower memory validator = validators[idx];
            totalValidatorPower = totalValidatorPower.sub(
                validatorPowers[validator.addr]
            );
            validatorPowers[validator.addr] = validator.power;
            totalValidatorPower = totalValidatorPower.add(validator.power);
        }
    }

    /// Relays a detail of Bandchain block to the bridge contract.
    /// @param multiStore Extra multi store to compute app hash. See MultiStore lib.
    /// @param merkleParts Extra merkle parts to compute block hash. See BlockHeaderMerkleParts lib.
    /// @param signatures The signatures signed on this block, sorted alphabetically by address.
    function relayBlock(
        MultiStore.Data memory multiStore,
        BlockHeaderMerkleParts.Data memory merkleParts,
        TMSignature.Data[] memory signatures
    ) public {
        bytes32 appHash = multiStore.getAppHash();
        // Computes Tendermint's block header hash at this given block.
        bytes32 blockHeader = merkleParts.getBlockHeader(appHash);
        // Counts the total number of valid signatures signed by active validators.
        address lastSigner = address(0);
        uint256 sumVotingPower = 0;
        for (uint256 idx = 0; idx < signatures.length; ++idx) {
            address signer = signatures[idx].recoverSigner(blockHeader);
            require(signer > lastSigner, "INVALID_SIGNATURE_SIGNER_ORDER");
            sumVotingPower = sumVotingPower.add(validatorPowers[signer]);
            lastSigner = signer;
        }
        // Verifies that sufficient validators signed the block and saves the oracle state.
        require(
            sumVotingPower.mul(3) > totalValidatorPower.mul(2),
            "INSUFFICIENT_VALIDATOR_SIGNATURES"
        );
        blockDetails[merkleParts.height] = BlockDetail({
            oracleState: multiStore.oracleIAVLStateHash,
            timeSecond: merkleParts.timeSecond,
            timeNanoSecond: merkleParts.timeNanoSecond
        });
    }

    /// Helper struct to workaround Solidity's "stack too deep" problem.
    struct VerifyOracleDataLocalVariables {
        bytes encodedVarint;
        bytes32 dataHash;
    }

    /// Verifies that the given data is a valid data on BandChain as of the relayed block height.
    /// @param blockHeight The block height. Someone must already relay this block.
    /// @param requestPacket The request packet is this request.
    /// @param responsePacket The response packet of this request.
    /// @param version Lastest block height that the data node was updated.
    /// @param merklePaths Merkle proof that shows how the data leave is part of the oracle iAVL.
    function verifyOracleData(
        uint256 blockHeight,
        RequestPacket memory requestPacket,
        ResponsePacket memory responsePacket,
        uint256 version,
        IAVLMerklePath.Data[] memory merklePaths
    ) public view returns (RequestPacket memory, ResponsePacket memory) {
        bytes32 oracleStateRoot = blockDetails[blockHeight].oracleState;
        require(
            oracleStateRoot != bytes32(uint256(0)),
            "NO_ORACLE_ROOT_STATE_DATA"
        );
        // Computes the hash of leaf node for iAVL oracle tree.
        VerifyOracleDataLocalVariables memory vars;
        vars.encodedVarint = Utils.encodeVarintSigned(version);
        vars.dataHash = sha256(
            Packets.getEncodedResult(requestPacket, responsePacket)
        );
        bytes32 currentMerkleHash = sha256(
            abi.encodePacked(
                uint8(0), // Height of tree (only leaf node) is 0 (signed-varint encode)
                uint8(2), // Size of subtree is 1 (signed-varint encode)
                vars.encodedVarint,
                uint8(9), // Size of data key (1-byte constant 0x01 + 8-byte request ID)
                uint8(255), // Constant 0xff prefix data request info storage key
                responsePacket.requestID,
                uint8(32), // Size of data hash
                vars.dataHash
            )
        );
        // Goes step-by-step computing hash of parent nodes until reaching root node.
        for (uint256 idx = 0; idx < merklePaths.length; ++idx) {
            currentMerkleHash = merklePaths[idx].getParentHash(
                currentMerkleHash
            );
        }
        // Verifies that the computed Merkle root matches what currently exists.
        require(
            currentMerkleHash == oracleStateRoot,
            "INVALID_ORACLE_DATA_PROOF"
        );

        return (requestPacket, responsePacket);
    }

    /// Performs oracle state relay and oracle data verification in one go. The caller submits
    /// the encoded proof and receives back the decoded data, ready to be validated and used.
    /// @param data The encoded data for oracle state relay and data verification.
    function relayAndVerify(bytes calldata data)
        external
        override
        returns (RequestPacket memory, ResponsePacket memory)
    {
        (bytes memory relayData, bytes memory verifyData) = abi.decode(
            data,
            (bytes, bytes)
        );
        (bool relayOk, ) = address(this).call(
            abi.encodePacked(this.relayBlock.selector, relayData)
        );
        require(relayOk, "RELAY_BLOCK_FAILED");
        (bool verifyOk, bytes memory verifyResult) = address(this).staticcall(
            abi.encodePacked(this.verifyOracleData.selector, verifyData)
        );
        require(verifyOk, "VERIFY_ORACLE_DATA_FAILED");
        return abi.decode(verifyResult, (RequestPacket, ResponsePacket));
    }

    /// Performs oracle state relay and many times of oracle data verification in one go. The caller submits
    /// the encoded proof and receives back the decoded data, ready to be validated and used.
    /// @param data The encoded data for oracle state relay and an array of data verification.
    function relayAndMultiVerify(bytes calldata data)
        external
        override
        returns (RequestPacket[] memory, ResponsePacket[] memory)
    {
        (bytes memory relayData, bytes[] memory manyVerifyData) = abi.decode(
            data,
            (bytes, bytes[])
        );
        (bool relayOk, ) = address(this).call(
            abi.encodePacked(this.relayBlock.selector, relayData)
        );
        require(relayOk, "RELAY_BLOCK_FAILED");

        RequestPacket[] memory requests = new RequestPacket[](
            manyVerifyData.length
        );
        ResponsePacket[] memory responses = new ResponsePacket[](
            manyVerifyData.length
        );
        for (uint256 i = 0; i < manyVerifyData.length; i++) {
            (bool verifyOk, bytes memory verifyResult) = address(this)
                .staticcall(
                abi.encodePacked(
                    this.verifyOracleData.selector,
                    manyVerifyData[i]
                )
            );
            require(verifyOk, "VERIFY_ORACLE_DATA_FAILED");
            (requests[i], responses[i]) = abi.decode(
                verifyResult,
                (RequestPacket, ResponsePacket)
            );
        }

        return (requests, responses);
    }
}
