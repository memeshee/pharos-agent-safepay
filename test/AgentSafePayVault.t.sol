// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { AgentSafePayVault } from "../src/AgentSafePayVault.sol";

contract MockERC20 {
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8 public decimals = 6;
    mapping(address account => uint256 balance) public balanceOf;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract AgentSafePayVaultTest is Test {
    AgentSafePayVault internal vault;
    MockERC20 internal token;

    address internal owner = address(0xA11CE);
    address internal agent = address(0xA6E17);
    address payable internal recipient = payable(address(0xB0B));
    address payable internal stranger = payable(address(0xBAD));

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(agent, 1 ether);

        vm.prank(owner);
        vault = new AgentSafePayVault(agent);

        token = new MockERC20();
        token.mint(address(vault), 1_000_000);

        vm.startPrank(owner);
        vault.setRecipientAllowed(recipient, true);
        vault.setDailyLimit(address(0), 1 ether);
        vault.setDailyLimit(address(token), 500_000);
        vault.depositNative{ value: 5 ether }();
        vm.stopPrank();
    }

    function testOwnerCanConfigureAgentRecipientAndLimit() public {
        address newAgent = address(0x1234);

        vm.startPrank(owner);
        vault.setAgent(newAgent);
        vault.setRecipientAllowed(stranger, true);
        vault.setDailyLimit(address(0), 2 ether);
        vm.stopPrank();

        assertEq(vault.agent(), newAgent);
        assertTrue(vault.allowedRecipients(stranger));
        assertEq(vault.dailyLimits(address(0)), 2 ether);
    }

    function testNonOwnerCannotConfigure() public {
        vm.prank(agent);
        vm.expectRevert(AgentSafePayVault.NotOwner.selector);
        vault.setDailyLimit(address(0), 2 ether);
    }

    function testAgentCanPayNativeAllowedRecipientWithinDailyLimit() public {
        bytes32 paymentId = keccak256("invoice-1");
        uint256 beforeBalance = recipient.balance;

        vm.prank(agent);
        vault.payNative(recipient, 0.25 ether, paymentId, keccak256("memo"));

        assertEq(recipient.balance, beforeBalance + 0.25 ether);
        assertEq(vault.spentByDay(address(0), block.timestamp / 1 days), 0.25 ether);
        assertTrue(vault.usedPaymentIds(paymentId));
        assertEq(vault.remainingToday(address(0)), 0.75 ether);
    }

    function testOwnerCanPayNativeToo() public {
        vm.prank(owner);
        vault.payNative(recipient, 0.1 ether, keccak256("owner-payment"), bytes32(0));

        assertEq(vault.remainingToday(address(0)), 0.9 ether);
    }

    function testDisallowedRecipientReverts() public {
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(AgentSafePayVault.RecipientNotAllowed.selector, stranger)
        );
        vault.payNative(stranger, 0.1 ether, keccak256("invoice-2"), bytes32(0));
    }

    function testDuplicatePaymentIdReverts() public {
        bytes32 paymentId = keccak256("invoice-3");

        vm.prank(agent);
        vault.payNative(recipient, 0.1 ether, paymentId, bytes32(0));

        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(AgentSafePayVault.DuplicatePayment.selector, paymentId)
        );
        vault.payNative(recipient, 0.1 ether, paymentId, bytes32(0));
    }

    function testDailyLimitExceededReverts() public {
        vm.prank(agent);
        vm.expectRevert(
            abi.encodeWithSelector(
                AgentSafePayVault.DailyLimitExceeded.selector, address(0), 1.1 ether, 1 ether
            )
        );
        vault.payNative(recipient, 1.1 ether, keccak256("invoice-4"), bytes32(0));
    }

    function testNewDayResetsBudget() public {
        vm.prank(agent);
        vault.payNative(recipient, 1 ether, keccak256("invoice-5"), bytes32(0));

        vm.warp(block.timestamp + 1 days);

        assertEq(vault.remainingToday(address(0)), 1 ether);
    }

    function testPauseBlocksPayments() public {
        vm.prank(owner);
        vault.setPaused(true);

        vm.prank(agent);
        vm.expectRevert(AgentSafePayVault.Paused.selector);
        vault.payNative(recipient, 0.1 ether, keccak256("invoice-6"), bytes32(0));
    }

    function testAgentCanPayERC20() public {
        vm.prank(agent);
        vault.payERC20(address(token), recipient, 250_000, keccak256("invoice-7"), bytes32(0));

        assertEq(token.balanceOf(recipient), 250_000);
        assertEq(vault.remainingToday(address(token)), 250_000);
    }

    function testOwnerCanSweepNativeAndERC20() public {
        uint256 nativeBefore = owner.balance;

        vm.prank(owner);
        vault.sweepNative(payable(owner), 1 ether);

        vm.prank(owner);
        vault.sweepERC20(address(token), owner, 100_000);

        assertEq(owner.balance, nativeBefore + 1 ether);
        assertEq(token.balanceOf(owner), 100_000);
    }
}
