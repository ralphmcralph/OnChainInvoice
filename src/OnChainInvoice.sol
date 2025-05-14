// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity 0.8.24;

contract OnChainInvoice {
    // Variables
    address public admin;

    enum Status {
        Pending,
        Paid,
        Cancelled
    }

    struct Invoice {
        address issuer;
        address client;
        uint256 amount;
        string description;
        Status status;
    }

    mapping(uint256 => Invoice) public invoices;
    uint256 public invoiceCounter = 0;
    mapping(address => uint256) public userBalance;

    // Events
    event NewInvoice(uint256 indexed invoiceId_, address indexed issuer_, address indexed client_, uint256 amount_);
    event NewPayment(uint256 indexed invoiceId);
    event CancelInvoice(uint256 indexed invoiceId);
    event EtherWithDraw(address indexed user_, uint256 amount_);

    // Modifiers
    modifier onlyClient(uint256 invoiceId_) {
        require(invoices[invoiceId_].client == msg.sender, "Not allowed");
        _;
    }

    modifier onlyIssuerOrAdmin(uint256 invoiceId_) {
        require(msg.sender == invoices[invoiceId_].issuer || msg.sender == admin, "Not allowed");
        _;
    }

    constructor(address admin_) {
        admin = admin_;
    }

    // Functions
    function createInvoice(address client_, uint256 amount_, string calldata description_) external returns (uint256) {
        uint256 invoiceId = invoiceCounter++;

        invoices[invoiceId] = Invoice({
            issuer: msg.sender,
            client: client_,
            amount: amount_,
            description: description_,
            status: Status.Pending
        });

        emit NewInvoice(invoiceId, msg.sender, client_, amount_);

        return invoiceId;
    }

    function payInvoice(uint256 invoiceId_) external payable onlyClient(invoiceId_) {
        require(msg.value == invoices[invoiceId_].amount, "Enter exact amount");
        require(invoices[invoiceId_].status == Status.Pending, "Invoice is not payable");

        invoices[invoiceId_].status = Status.Paid;

        userBalance[invoices[invoiceId_].issuer] += msg.value;

        emit NewPayment(invoiceId_);
    }

    function cancelInvoice(uint256 invoiceId_) external onlyIssuerOrAdmin(invoiceId_) {
        require(invoices[invoiceId_].status == Status.Pending, "Cannot cancel invoice");
        invoices[invoiceId_].status = Status.Cancelled;

        emit CancelInvoice(invoiceId_);
    }

    function getInvoice(uint256 invoiceId_) external view returns (Invoice memory) {
        return invoices[invoiceId_];
    }

    function withdrawEther(uint256 amount_) external {
        require(userBalance[msg.sender] >= amount_, "Not enough ether");

        // CEI pattern:
        //  1. Checks
        //  2. Effects (Update States)
        //  3. Interactions
        // Avoid reentrancy attacks

        userBalance[msg.sender] -= amount_;
        (bool success,) = msg.sender.call{value: amount_}("");
        require(success, "Transfer failed");

        emit EtherWithDraw(msg.sender, amount_);
    }

    receive() external payable {
        revert("Use payInvoice");
    }

    fallback() external payable {
        revert("Invalid function");
    }
}
