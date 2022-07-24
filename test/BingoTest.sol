// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/Bingo.sol";
import "../src/MockToken.sol";

contract BingoTest is Test {
    address public owner = address(12);
    address public player = address(13);
    address public player2 = address(14);
    address public VRFCORDINATOR = 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9;
    address public LINK_TOKEN_KOVAN =
        0xa36085F69e2889c224210F603D836748e7dC0088;
    address public LINK_WHALE = 0x75cf915Fe0A5727eF5befCb117F7659f02e64a1C;

    Bingo bingo;
    MockToken token;

    function setUp() public {
        vm.startPrank(owner);
        bingo = new Bingo(VRFCORDINATOR, LINK_TOKEN_KOVAN);
        token = new MockToken();
        vm.stopPrank();
        vm.prank(LINK_WHALE);
        IERC20(LINK_TOKEN_KOVAN).transfer(address(bingo), 100_000e18);
    }

    function test_config() public {
        assertEq(bingo.owner(), owner);
        assertEq(IERC20(token).balanceOf(owner), 1_000_000e18);
    }

    function test_createNewGame() public {
        vm.startPrank(owner);
        assertEq(bingo.getGameCount(), 0);
        bingo.addNewGame(address(token), 1_000e18, 1 days, 2);
        assertEq(bingo.getGameCount(), 1);
        assertEq(bingo.getGameDetails(0).token, address(token));
        assertEq(
            bingo.getGameDetails(0).joinDurationTime,
            block.timestamp + 1 days
        );
        assertEq(bingo.getGameDetails(0).turnDuration, 2);
        vm.stopPrank();
    }

    /**
    @dev notice, the randomness for the 25 numbers , fetching the VRF API takes some times to retrieve the random number
    the randomn number will always be 0 for the tests in a fork network, this will change in testnet
    */
    function test_bet() public {
        vm.prank(owner);
        bingo.addNewGame(address(token), 1_000e18, 1 days, 2);
        fund_account(player);

        vm.startPrank(player);
        IERC20(token).approve(address(bingo), 2**256 - 1);
        bytes32 key = bingo.bet(0);
        assertEq(bingo.getPlayerCard(player, 0).length, 25);
        vm.warp(block.timestamp + 20);
        bingo.getCard(0, key);
        // console2.log(key);
        for (uint256 i; i < 25; i++) {
            console2.log(bingo.getPlayerCard(player, 0)[i]);
        }
        assert(IERC20(token).balanceOf(address(bingo)) > 0);
    }

    function fund_account(address _player) public {
        vm.prank(owner);
        IERC20(token).transfer(_player, 2_000e18);
    }
}
