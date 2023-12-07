// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IChainlinkRegistry {
    function latestRoundData(address _base, address _quote) external view returns(uint256);
}