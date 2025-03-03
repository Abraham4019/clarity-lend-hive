import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a loan request with sufficient collateral",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const borrower = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('lend_hive', 'create-loan-request', [
                types.uint(1000), // amount
                types.uint(10),   // interest rate
                types.uint(30),   // duration
                types.uint(1200)  // collateral (120%)
            ], borrower.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        // Verify event emission
        assertEquals(block.receipts[0].events[0].type, "contract_event");
        
        let getLoan = chain.callReadOnlyFn(
            'lend_hive',
            'get-loan',
            [types.uint(0)],
            borrower.address
        );
        
        let loan = getLoan.result.expectSome().expectTuple();
        assertEquals(loan['borrower'], borrower.address);
        assertEquals(loan['status'], "REQUESTED");
        assertEquals(loan['collateral'], '1200');
    }
});

Clarinet.test({
    name: "Cannot create loan request with insufficient collateral",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('lend_hive', 'create-loan-request', [
                types.uint(1000), // amount
                types.uint(10),   // interest rate 
                types.uint(30),   // duration
                types.uint(1000)  // collateral (100% - insufficient)
            ], borrower.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(106);
    }
});

Clarinet.test({
    name: "Can fund a loan request",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        const lender = accounts.get('wallet_2')!;
        
        // Create loan request
        let block = chain.mineBlock([
            Tx.contractCall('lend_hive', 'create-loan-request', [
                types.uint(1000),
                types.uint(10),
                types.uint(30),
                types.uint(1200)
            ], borrower.address)
        ]);
        
        // Fund loan
        block = chain.mineBlock([
            Tx.contractCall('lend_hive', 'fund-loan', [
                types.uint(0)
            ], lender.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        let getLoan = chain.callReadOnlyFn(
            'lend_hive',
            'get-loan',
            [types.uint(0)],
            borrower.address
        );
        
        let loan = getLoan.result.expectSome().expectTuple();
        assertEquals(loan['status'], "ACTIVE");
        assertEquals(loan['lender'], lender.address);
    }
});

Clarinet.test({
    name: "Can make loan repayment",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const borrower = accounts.get('wallet_1')!;
        const lender = accounts.get('wallet_2')!;
        
        // Create and fund loan
        chain.mineBlock([
            Tx.contractCall('lend_hive', 'create-loan-request', [
                types.uint(1000),
                types.uint(10),
                types.uint(30),
                types.uint(1200)
            ], borrower.address)
        ]);
        
        chain.mineBlock([
            Tx.contractCall('lend_hive', 'fund-loan', [
                types.uint(0)
            ], lender.address)
        ]);
        
        // Make repayment
        let block = chain.mineBlock([
            Tx.contractCall('lend_hive', 'repay-loan', [
                types.uint(0),
                types.uint(500)
            ], borrower.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        let getLoan = chain.callReadOnlyFn(
            'lend_hive',
            'get-loan',
            [types.uint(0)],
            borrower.address
        );
        
        let loan = getLoan.result.expectSome().expectTuple();
        assertEquals(loan['repaid-amount'], '500');
    }
});
