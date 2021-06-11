// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IAVLMerklePath} from "../bridge/library/IAVLMerklePath.sol";
import {Packets} from "../bridge/library/Packets.sol";
import {IBridge} from "../../interfaces/bridge/IBridge.sol";

/// @title BandChain MockBridge
/// @author Band Protocol Team
contract MockBridge is IBridge {
    using IAVLMerklePath for IAVLMerklePath.Data;

    /// Performs oracle state relay and oracle data verification in one go. The caller submits
    /// the encoded proof and receives back the decoded data, ready to be validated and used.
    /// @param data The encoded data for oracle state relay and data verification.
    function relayAndVerify(bytes calldata data)
        external
        override
        returns (RequestPacket memory, ResponsePacket memory)
    {
        (bytes memory _relayData, bytes memory verifyData) =
            abi.decode(data, (bytes, bytes));

        (
            uint256 _blockHeight,
            RequestPacket memory requestPacket,
            ResponsePacket memory responsePacket,
            uint256 _version,
            IAVLMerklePath.Data[] memory _merklePaths
        ) =
            abi.decode(
                verifyData,
                (
                    uint256,
                    RequestPacket,
                    ResponsePacket,
                    uint256,
                    IAVLMerklePath.Data[]
                )
            );

        return (requestPacket, responsePacket);
    }

    /// Performs oracle state relay and many times of oracle data verification in one go. The caller submits
    /// the encoded proof and receives back the decoded data, ready to be validated and used.
    /// @param data The encoded data for oracle state relay and an array of data verification.
    function relayAndMultiVerify(bytes calldata data)
        external
        override
        returns (RequestPacket[] memory, ResponsePacket[] memory)
    {
        revert("Unimplemented");
    }
}
