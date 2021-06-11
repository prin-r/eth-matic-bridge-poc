// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Packets} from "../bridge/library/Packets.sol";
import {MockBridge} from "./MockBridge.sol";
import {IBridge} from "../../interfaces/bridge/IBridge.sol";
import {Obi} from "../obi/Obi.sol";

library ParamsDecoder {
    using Obi for Obi.Data;

    struct Params {
        uint64 block_number;
        string tx_hash;
        string statesender_contract_address;
        uint32 log_index;
    }

    function decodeParams(bytes memory _data)
        internal
        pure
        returns (Params memory result)
    {
        Obi.Data memory data = Obi.from(_data);
        result.block_number = data.decodeU64();
        result.tx_hash = string(data.decodeBytes());
        result.statesender_contract_address = string(data.decodeBytes());
        result.log_index = data.decodeU32();
    }
}

library ResultDecoder {
    using Obi for Obi.Data;

    struct Result {
        bytes user_address;
        bytes token_address;
        bytes deposit_data;
    }

    function decodeResult(bytes memory _data)
        internal
        pure
        returns (Result memory result)
    {
        Obi.Data memory data = Obi.from(_data);
        result.user_address = data.decodeBytes();
        result.token_address = data.decodeBytes();
        result.deposit_data = data.decodeBytes();
    }
}

contract MockCacheBridgeForChildChainManager is Ownable, MockBridge {
    using Packets for IBridge.RequestPacket;
    using ParamsDecoder for bytes;
    using ResultDecoder for bytes;

    struct SyncResult {
        address user_address;
        address token_address;
        bytes deposit_data;
    }

    IBridge.RequestPacket public templateRequestPacket;

    mapping(bytes32 => SyncResult) public requestsCache;

    constructor(
        uint64 oracleScriptID,
        uint64 minCount,
        uint64 askCount
    ) public {
        templateRequestPacket.oracleScriptID = oracleScriptID;
        templateRequestPacket.minCount = minCount;
        templateRequestPacket.askCount = askCount;
    }

    function setTemplateResponsePacket(
        uint64 oracleScriptID,
        uint64 minCount,
        uint64 askCount
    ) external onlyOwner {
        templateRequestPacket.oracleScriptID = oracleScriptID;
        templateRequestPacket.minCount = minCount;
        templateRequestPacket.askCount = askCount;
    }

    function bytesToAddress(bytes memory bys)
        public
        pure
        returns (address addr)
    {
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    function getCacheKey(
        uint64 block_number,
        string memory tx_hash,
        string memory statesender_contract_address,
        uint32 log_index
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    block_number,
                    tx_hash,
                    statesender_contract_address,
                    log_index
                )
            );
    }

    function _cacheResponse(
        RequestPacket memory request,
        ResponsePacket memory response
    ) internal returns (SyncResult memory) {
        require(
            request.oracleScriptID == templateRequestPacket.oracleScriptID,
            "FAIL_WRONG_OS_ID"
        );

        require(
            request.minCount == templateRequestPacket.minCount,
            "FAIL_WRONG_MIN_COUNT"
        );

        require(
            request.askCount == templateRequestPacket.askCount,
            "FAIL_WRONG_ASK_COUNT"
        );

        require(
            response.resolveStatus == 1,
            "FAIL_REQUEST_IS_NOT_SUCCESSFULLY_RESOLVED"
        );

        ParamsDecoder.Params memory params = request.params.decodeParams();
        bytes32 cacheKey =
            getCacheKey(
                params.block_number,
                params.tx_hash,
                params.statesender_contract_address,
                params.log_index
            );

        SyncResult storage sr = requestsCache[cacheKey];
        require(
            sr.user_address == address(0) && sr.token_address == address(0),
            "FAIL_THE_RESULT_ALREADY_EXISTS"
        );

        ResultDecoder.Result memory result = response.result.decodeResult();
        sr.user_address = bytesToAddress(result.user_address);
        sr.token_address = bytesToAddress(result.token_address);
        sr.deposit_data = result.deposit_data;

        return sr;
    }

    function relayAndGetSyncResult(bytes calldata data)
        external
        returns (
            address,
            address,
            bytes memory
        )
    {
        (RequestPacket memory request, ResponsePacket memory response) =
            this.relayAndVerify(data);

        SyncResult memory sr = _cacheResponse(request, response);
        return (sr.user_address, sr.token_address, sr.deposit_data);
    }
}
