// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity 0.8.24;

import "../src/OnChainInvoice.sol";
import "../src/RejectETH.sol";
import "forge-std/Test.sol";

contract OnChainInvoiceTest is Test {
    OnChainInvoice onchaininvoice;
    address public admin = vm.addr(1);
    address public randomIssuer = vm.addr(2);
    address public randomClient = vm.addr(3);
    address public randomUser = vm.addr(4);

    uint256 amount = 1 ether;
    string description = "Lorem ipsum sit amet";

    function setUp() public {
        onchaininvoice = new OnChainInvoice(admin);
    }

    // Unit testing - Given inputs
    function testCreateInvoice() public {
        assert(onchaininvoice.createInvoice(randomClient, amount, description) == 0);
    }

    function testPayInvoice() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomClient, amount);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount}(invoiceId);
        vm.stopPrank();

        // Verify if invoice is paid
        assert(onchaininvoice.getInvoice(invoiceId).status == OnChainInvoice.Status.Paid);
    }

    function testIfNotClientPayInvoice() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomUser, amount);
        vm.startPrank(randomUser);
        vm.expectRevert();
        onchaininvoice.payInvoice{value: amount}(invoiceId);
        vm.stopPrank();
    }

    function testCannotPayWrongAmount() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomClient, amount);
        vm.startPrank(randomClient);
        vm.expectRevert();
        onchaininvoice.payInvoice{value: amount - 0.1 ether}(invoiceId);
        vm.stopPrank();
    }

    function testIfNotPendingPayInvoice() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomClient, amount * 2);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount}(invoiceId);

        //Client tries to pay another time
        vm.expectRevert();
        onchaininvoice.payInvoice{value: amount}(invoiceId);

        vm.stopPrank();
    }

    function testCancelInvoice() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        onchaininvoice.cancelInvoice(invoiceId);
        vm.stopPrank();

        assert(onchaininvoice.getInvoice(invoiceId).status == OnChainInvoice.Status.Cancelled);
    }

    function testIfAlreadyPaidCancelInvoice() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomClient, amount);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount}(invoiceId);
        vm.stopPrank();

        //Issuer tries to cancel invoice
        vm.startPrank(randomIssuer);
        vm.expectRevert();
        onchaininvoice.cancelInvoice(invoiceId);
        vm.stopPrank();
    }

    function testIfNotIssuerCancelInvoice() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        vm.startPrank(randomUser);
        vm.expectRevert();
        onchaininvoice.cancelInvoice(invoiceId);
        vm.stopPrank();
    }

    function testIfAdminCancelInvoice() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        vm.startPrank(admin);
        onchaininvoice.cancelInvoice(invoiceId);
        vm.stopPrank();

        assert(onchaininvoice.getInvoice(invoiceId).status == OnChainInvoice.Status.Cancelled);
    }

    function testWithdrawEther() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomClient, amount);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount}(invoiceId);
        vm.stopPrank();

        // Issuer withdraws his current balance
        vm.startPrank(randomIssuer);
        onchaininvoice.withdrawEther(amount);
        vm.stopPrank();
    }

    function testCannotWithdrawMoreEtherThanBalance() public {
        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomClient, amount);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount}(invoiceId);
        vm.stopPrank();

        // Issuer withdraws his current balance
        vm.startPrank(randomIssuer);
        vm.expectRevert();
        onchaininvoice.withdrawEther(amount + 1 ether);
        vm.stopPrank();
    }

    function testIfWithdrawalFails() public {
        RejectETH badReceiver = new RejectETH();

        //Bad receiver creates invoice
        vm.startPrank(address(badReceiver));
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount, description);
        vm.stopPrank();

        //Client pays invoice
        vm.deal(randomClient, amount);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount}(invoiceId);
        vm.stopPrank();

        // Bad receiver (Contract simulating User that cannot receive ETH) tries to withdraw his current balance
        vm.startPrank(address(badReceiver));
        vm.expectRevert();
        onchaininvoice.withdrawEther(amount);
        vm.stopPrank();
    }

    function testReceive() public {
        vm.expectRevert();
        (bool success,) = payable(address(onchaininvoice)).call{value: 1 ether}("");
    }

    function testFallback() public {
        vm.expectRevert();
        bytes memory payload = abi.encodeWithSignature("nonexistentFunction()");
        (bool success,) = payable(address(onchaininvoice)).call{value: 1 ether}(payload);
    }
}
