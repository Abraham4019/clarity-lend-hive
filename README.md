# LendHive

A decentralized peer-to-peer lending platform built on the Stacks blockchain. LendHive allows users to:

- Create loan requests specifying amount, interest rate, duration and collateral
- Fund loan requests as a lender
- Repay loans with interest
- Track loan status and payment history
- Liquidate overdue loans with automated collateral transfer

## Features

- Fully decentralized lending and borrowing
- Interest calculation
- Loan status tracking
- Secure fund transfers
- Automated repayment validation
- Smart liquidation system with collateral management
- Duration-based loan monitoring
- Minimum collateral ratio requirement (120%)

## Contract Functions

The contract implements the core lending functionality including:
- Creating loan requests with collateral validation
- Funding loans
- Processing repayments
- Calculating interest
- Managing loan status
- Liquidating overdue loans
- Transferring collateral

## Security

The contract includes various safety checks and requires collateral to protect lenders:
- Mandatory minimum collateral ratio of 120%
- Collateral validation on loan creation
- Automated liquidation triggers
- Secure fund transfers
- Duration-based loan monitoring
- Access control checks
