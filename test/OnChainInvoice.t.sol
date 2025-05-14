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

        //Store before balance
        uint256 beforeBalance = randomIssuer.balance;

        //Client pays invoice
        vm.deal(randomClient, amount);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount}(invoiceId);
        vm.stopPrank();

        // Issuer withdraws his current balance
        vm.startPrank(randomIssuer);
        onchaininvoice.withdrawEther(amount);
        vm.stopPrank();

        assert(randomIssuer.balance == beforeBalance + amount);
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

    // Fuzzing testing
    function testFuzzCreateInvoice(address client_, uint256 amount_, string calldata description_) public {
        vm.assume(client_ != address(0) && amount_ > 0 && amount_ < 100 ether);
        uint256 id = onchaininvoice.createInvoice(client_, amount_, description_);
        assert(onchaininvoice.getInvoice(id).client == client_);
        assert(onchaininvoice.getInvoice(id).amount == amount_);
        assert(onchaininvoice.getInvoice(id).status == OnChainInvoice.Status.Pending);
    }

    function testFuzzWithdrawETH(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ <= 10 ether);

        //Issuer creates invoice
        vm.startPrank(randomIssuer);
        uint256 invoiceId = onchaininvoice.createInvoice(randomClient, amount_, description);
        vm.stopPrank();

        //Store before balance
        uint256 beforeBalance = randomIssuer.balance;

        //Client pays invoice
        vm.deal(randomClient, amount_);
        vm.startPrank(randomClient);
        onchaininvoice.payInvoice{value: amount_}(invoiceId);
        vm.stopPrank();

        // Issuer withdraws his current balance
        vm.startPrank(randomIssuer);
        onchaininvoice.withdrawEther(amount_);
        vm.stopPrank();

        assert(randomIssuer.balance == beforeBalance + amount_);
    }
}
