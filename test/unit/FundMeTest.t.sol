// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant START_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
      DeployFundMe deployFundMe = new DeployFundMe();
      fundMe = deployFundMe.run();
      // 给USER发10个ether
      vm.deal(USER, START_BALANCE);
    }

    function testMinimumDollarIsFive() public view{
      assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view{

      assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
      uint256 version = fundMe.getVersion();
      assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
      vm.expectRevert();
      fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
      // 下笔交易由USER去发送
      vm.prank(USER);
      fundMe.fund{value: SEND_VALUE}();
      uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
      assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
      vm.prank(USER);

      fundMe.fund{ value: SEND_VALUE }();
      address funder = fundMe.getFunder(0);
      assertEq(funder, USER);
    }

    modifier funded() {
      vm.prank(USER);
      fundMe.fund{ value: SEND_VALUE };
      _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
      vm.expectRevert();
      fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
      uint256 startOwnerBalance = fundMe.getOwner().balance;
      uint256 startFundMeBalance = address(fundMe).balance;

      // uint256 gasStart = gasleft();
      // vm.txGasPrice(GAS_PRICE);
      vm.prank(fundMe.getOwner());
      fundMe.withdraw();

      // uint256 gasEnd = gasleft();
      // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
      // console.log(gasUsed);

      uint256 endOwnerBalance = fundMe.getOwner().balance;
      uint256 endFundMeBalance = address(fundMe).balance;

      assertEq(endFundMeBalance, 0);
      assertEq(startFundMeBalance + startOwnerBalance, endOwnerBalance);
    }

    function testWithdrawWithMultipleFunders() public {
      uint160 numberOfFunders = 10;
      uint160 startingFunderIndex = 1;
      for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
        // 下个交易由他发起且给他发送SEND_VALUE
        hoax(address(i), SEND_VALUE);
        fundMe.fund{value: SEND_VALUE}();
      }

      uint256 startOwnerBalance = fundMe.getOwner().balance;
      uint256 startFundMeBalance = address(fundMe).balance;

      vm.startPrank(fundMe.getOwner());
      fundMe.withdraw();
      vm.stopPrank();

      assert(address(fundMe).balance == 0);
      assert(startFundMeBalance + startOwnerBalance == fundMe.getOwner().balance);
    }

    function testCheaperWithdrawWithMultipleFunders() public {
      uint160 numberOfFunders = 10;
      uint160 startingFunderIndex = 1;
      for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
        // 下个交易由他发起且给他发送SEND_VALUE
        hoax(address(i), SEND_VALUE);
        fundMe.fund{value: SEND_VALUE}();
      }

      uint256 startOwnerBalance = fundMe.getOwner().balance;
      uint256 startFundMeBalance = address(fundMe).balance;

      vm.startPrank(fundMe.getOwner());
      fundMe.cheaperWithdraw();
      vm.stopPrank();

      assert(address(fundMe).balance == 0);
      assert(startFundMeBalance + startOwnerBalance == fundMe.getOwner().balance);
    }
}