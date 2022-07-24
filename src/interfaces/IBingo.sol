//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface Bingo {
    function bet(uint256 _gameId) external;

    function getCard(uint256 _gameId, bytes32 key) external;
}
