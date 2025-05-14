# 🧾 OnChainInvoice – Simple Invoice Management System in Solidity

![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue?style=flat&logo=solidity)
![License](https://img.shields.io/badge/License-LGPL--3.0--only-green?style=flat)
![Tested](https://img.shields.io/badge/Tested%20With-Foundry-orange?style=flat)
![Coverage](https://img.shields.io/badge/Coverage-100%25-brightgreen?style=flat)

---

## 📌 Description

**OnChainInvoice** is a minimal and gas-efficient Solidity smart contract that enables users to:

- Create invoices with amount, client, and description
- Accept payments securely via ETH
- Cancel invoices (by issuer or admin)
- Withdraw collected funds safely

Built with **Foundry**, the project showcases clean separation of logic, CEI pattern, and robust access control — with full 100% test coverage (lines, statements, functions, branches) and fuzzing included.

---

## 📁 Structure

```
├── src/
│   └── OnChainInvoice.sol         # Main contract
│   └── RejectETH.sol              # Mock contract to force transfer failure
├── test/
│   └── OnChainInvoiceTest.t.sol   # Full test suite using Foundry
```

---

## 🧱 Contract Overview

### Enum: `Status`

```solidity
enum Status { Pending, Paid, Cancelled }
```

### Struct: `Invoice`

```solidity
struct Invoice {
    address issuer;
    address client;
    uint256 amount;
    string description;
    Status status;
}
```

---

## 🔐 Modifiers

- `onlyClient(invoiceId)` – Only the client can pay
- `onlyIssuerOrAdmin(invoiceId)` – Only issuer or admin can cancel

---

## 🚀 Functions

### ✅ Create Invoice

```solidity
function createInvoice(address client, uint256 amount, string calldata description)
```

Creates a new invoice assigned to a client.

---

### 💸 Pay Invoice

```solidity
function payInvoice(uint256 invoiceId) external payable
```

Allows the invoice's client to pay the exact amount in ETH.

---

### ❌ Cancel Invoice

```solidity
function cancelInvoice(uint256 invoiceId) external
```

Only issuer or admin can cancel invoices in `Pending` state.

---

### 💰 Withdraw Funds

```solidity
function withdrawEther(uint256 amount) external
```

Allows issuers to withdraw collected ETH using the CEI pattern.
Handles edge cases like transfer failure using `call`.

---

## ⚠️ Rejection Handlers

```solidity
receive() external payable {
    revert("Use payInvoice");
}

fallback() external payable {
    revert("Invalid function");
}
```

Prevents accidental ETH transfers or undefined calls.

---

## 🧪 Testing

- Built with Foundry
- Covers all paths, including:
  - Valid/invalid payments
  - Cancellation logic (issuer/admin)
  - Transfer failure simulation using `RejectETH` contract
  - Fallback and receive handling
  - **Fuzz testing** of core logic (e.g. invoice creation) using random inputs
- ✅ 100% line, function, and branch coverage

---

## 📄 License

Licensed under the **GNU Lesser General Public License v3.0** – see the [`LICENSE`](./LICENSE) file.

---

## 🙋‍♂️ Author & Contributions

Open to contributions, PRs, and improvements. This project serves as a showcase of best practices in minimal on-chain billing systems.
