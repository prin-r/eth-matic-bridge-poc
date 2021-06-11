// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {Utils} from "./Utils.sol";
import {IBridge} from "../../../interfaces/bridge/IBridge.sol";

library Packets {
    function encodeRequestPacket(IBridge.RequestPacket memory self)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(
                uint32(bytes(self.clientID).length),
                self.clientID,
                self.oracleScriptID,
                uint32(self.params.length),
                self.params,
                self.askCount,
                self.minCount
            );
    }

    function encodeResponsePacket(IBridge.ResponsePacket memory self)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(
                uint32(bytes(self.clientID).length),
                self.clientID,
                self.requestID,
                self.ansCount,
                self.requestTime,
                self.resolveTime,
                uint32(self.resolveStatus),
                uint32(bytes(self.result).length),
                self.result
            );
    }

    function getEncodedResult(
        IBridge.RequestPacket memory req,
        IBridge.ResponsePacket memory res
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                encodeRequestPacket(req),
                encodeResponsePacket(res)
            );
    }

    /// Returns the hash of a RequestPacket.
    /// @param request A tuple that represents RequestPacket struct.
    function getRequestKey(IBridge.RequestPacket memory request)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(request));
    }
}
