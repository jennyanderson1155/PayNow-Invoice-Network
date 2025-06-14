# Invoice Factoring Marketplace Smart Contract

A decentralized marketplace built on Stacks blockchain that enables businesses to sell their invoices at a discount for immediate capital, while allowing investors to purchase these invoices for potential returns.

## 🚀 Features

- **Invoice Creation**: Businesses can list invoices for factoring with customizable discount rates
- **Marketplace Trading**: Investors can browse and purchase available invoices
- **Payment Confirmation**: Buyers can confirm receipt of payments from debtors
- **Dispute Resolution**: Built-in dispute mechanism with admin resolution
- **Rating System**: Track performance metrics for both sellers and buyers
- **Platform Fees**: Configurable fee structure for platform sustainability
- **Overdue Tracking**: Automatic marking of overdue invoices

## 📋 Contract Overview

### Core Components

- **Invoice Management**: Create, purchase, and track invoice lifecycle
- **User Ratings**: Reputation system for sellers and buyers
- **Payment Processing**: Handle STX transfers and fee collection
- **Dispute System**: File and resolve disputes between parties
- **Admin Controls**: Platform configuration and dispute resolution

### Invoice Statuses

- `available` - Listed for purchase
- `sold` - Purchased by an investor
- `paid` - Payment confirmed by buyer
- `disputed` - Under dispute resolution
- `expired` - Overdue or cancelled

## 🛠 Installation & Deployment

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development
- Stacks wallet for deployment
- Node.js (optional, for testing scripts)

### Local Development

1. Clone the repository:
```bash
git clone <repository-url>
cd invoice-factoring-marketplace
```

2. Initialize Clarinet project (if not already done):
```bash
clarinet new invoice-factoring
cd invoice-factoring
```

3. Add the contract file to `contracts/` directory

4. Test the contract:
```bash
clarinet test
```

5. Check contract syntax:
```bash
clarinet check
```

### Deployment

Deploy to Stacks testnet:
```bash
clarinet deploy --testnet
```

Deploy to Stacks mainnet:
```bash
clarinet deploy --mainnet
```

## 🔧 Contract Configuration

### Default Settings

- **Platform Fee**: 2.5% (250 basis points)
- **Minimum Discount**: 5% (500 basis points)  
- **Maximum Discount**: 30% (3000 basis points)

### Admin Functions

Only the contract owner can:
- Set platform fee rates (max 10%)
- Configure discount rate limits (max 50%)
- Resolve disputes
- Withdraw collected platform fees

## 📖 Usage Guide

### For Invoice Sellers (Businesses)

#### 1. Create Invoice
```clarity
(contract-call? .invoice-factoring create-invoice
  'SP1234...DEBTOR  ;; debtor principal
  u100000          ;; original amount (100 STX)
  u1000            ;; discount rate (10%)
  u1000            ;; due date (block height)
  "Service invoice for Q1 2024"  ;; description
  "INV-2024-001"   ;; invoice number
)
```

#### 2. Cancel Invoice (if not sold)
```clarity
(contract-call? .invoice-factoring cancel-invoice u1)
```

### For Invoice Buyers (Investors)

#### 1. Purchase Invoice
```clarity
(contract-call? .invoice-factoring purchase-invoice u1)
```

#### 2. Confirm Payment Received
```clarity
(contract-call? .invoice-factoring confirm-payment 
  u1       ;; invoice ID
  u100000  ;; amount received from debtor
)
```

#### 3. File Dispute (if needed)
```clarity
(contract-call? .invoice-factoring file-dispute 
  u1 
  "Debtor failed to pay within agreed timeframe"
)
```

### Read-Only Functions

#### Get Invoice Details
```clarity
(contract-call? .invoice-factoring get-invoice u1)
```

#### Check Seller Rating
```clarity
(contract-call? .invoice-factoring get-seller-rating 'SP1234...)
```

#### Calculate ROI
```clarity
(contract-call? .invoice-factoring calculate-roi u1)
```

#### Platform Statistics
```clarity
(contract-call? .invoice-factoring get-platform-stats)
```

## 🏗 Contract Architecture

### Data Structures

- **invoices**: Core invoice information
- **invoice-purchases**: Purchase transaction records
- **seller-ratings**: Seller performance metrics
- **buyer-ratings**: Buyer performance metrics
- **payment-confirmations**: Payment verification records
- **dispute-records**: Dispute tracking and resolution

### Key Functions

| Function | Type | Description |
|----------|------|-------------|
| `create-invoice` | Public | List new invoice for factoring |
| `purchase-invoice` | Public | Buy available invoice |
| `confirm-payment` | Public | Confirm debtor payment received |
| `file-dispute` | Public | Initiate dispute process |
| `mark-overdue` | Public | Mark invoice as overdue |
| `resolve-dispute` | Admin | Resolve filed disputes |
| `withdraw-platform-fees` | Admin | Withdraw collected fees |

## 💰 Fee Structure

### Platform Fees
- Charged to buyers on purchase
- Default: 2.5% of purchase price
- Configurable by admin (max 10%)

### Discount Calculation
```
Discounted Amount = Original Amount - (Original Amount × Discount Rate / 10000)
```

### ROI Calculation
```
ROI = (Original Amount - Discounted Amount) × 10000 / Discounted Amount
```

## 🛡 Security Features

- **Access Control**: Function-level permissions
- **Input Validation**: Amount and rate bounds checking
- **Status Validation**: State transition controls
- **Overflow Protection**: Safe arithmetic operations
- **Replay Protection**: Transaction uniqueness

## 🚨 Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR_UNAUTHORIZED | Access denied |
| u101 | ERR_INVOICE_NOT_FOUND | Invoice doesn't exist |
| u102 | ERR_INVOICE_ALREADY_EXISTS | Duplicate invoice |
| u103 | ERR_INVALID_AMOUNT | Invalid amount specified |
| u104 | ERR_INVALID_DISCOUNT | Discount rate out of bounds |
| u105 | ERR_INVOICE_EXPIRED | Invoice past due date |
| u106 | ERR_INSUFFICIENT_FUNDS | Not enough STX balance |
| u107 | ERR_INVOICE_NOT_AVAILABLE | Invoice not available for purchase |
| u108 | ERR_CANNOT_BUY_OWN_INVOICE | Seller cannot buy own invoice |
| u109 | ERR_PAYMENT_ALREADY_MADE | Payment already confirmed |
| u110 | ERR_INVOICE_OVERDUE | Invoice is overdue |
| u111 | ERR_INVALID_STATUS | Invalid status for operation |

## 📊 Testing

### Unit Tests
Create test files in `tests/` directory:

```typescript
// tests/invoice-factoring_test.ts
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Create invoice successfully",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const seller = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("invoice-factoring", "create-invoice", [
                types.principal(seller.address),
                types.uint(100000),
                types.uint(1000),
                types.uint(1000),
                types.ascii("Test invoice"),
                types.ascii("INV-001")
            ], seller.address)
        ]);
        
        assertEquals(block.receipts[0].result.expectOk(), types.uint(1));
    }
});
```

### Integration Tests
Test complete workflows:
- Invoice creation → Purchase → Payment confirmation
- Dispute filing → Resolution
- Fee collection and withdrawal

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

### Development Guidelines

- Follow Clarity best practices
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure backward compatibility when possible

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Stacks Documentation](https://docs.stacks.co/)
- **Issues**: Create GitHub issues for bugs and feature requests
- **Discord**: Join the Stacks community Discord
- **Forum**: [Stacks Forum](https://forum.stacks.org/)

## 🗺 Roadmap

- [ ] Multi-token support (SIP-010 tokens)
- [ ] Automated payment notifications
- [ ] Advanced analytics dashboard
- [ ] Insurance integration
- [ ] Mobile app integration
- [ ] API endpoints for external integrations

## ⚠️ Disclaimer

This smart contract is provided as-is for educational and development purposes. Users should conduct thorough testing and security audits before deploying to mainnet. The developers assume no responsibility for any losses incurred through the use of this contract.