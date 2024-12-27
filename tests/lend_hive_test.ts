import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a loan request",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const borrower = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('lend_hive', 'create-loan-request', [
                types.uint(1000), // amount
                types.uint(10),   // interest rate
                types.uint(30)    // duration
            ], borrower.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        // Verify loan details
        let getLoan = chain.callReadOnlyFn(
            'lend_hive',
            'get-loan',
            [types.uint(0)],
            borrower.address
        );
        
        let loan = getLoan.result.expectSome().expectTuple();
        assertEquals(loan['borrower'], borrower.address);
        assertEquals(loan['status'], "REQUESTED");
    }
});

Clarinet.test({
    name: "Can fund and repay a loan",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const borrower = accounts.get('wallet_1')!;
        const lender = accounts.get('wallet_2')!;
        
        // Create loan request
        let block = chain.mineBlock([
            Tx.contractCall('lend_hive', 'create-loan-request', [
                types.uint(1000),
                types.uint(10),
                types.uint(30)
            ], borrower.address)
        ]);
        
        // Fund loan
        let fundBlock = chain.mineBlock([
            Tx.contractCall('lend_hive', 'fund-loan', [
                types.uint(0)
            ], lender.address)
        ]);
        
        fundBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify loan is active
        let getLoan = chain.callReadOnlyFn(
            'lend_hive',
            'get-loan',
            [types.uint(0)],
            borrower.address
        );
        
        let loan = getLoan.result.expectSome().expectTuple();
        assertEquals(loan['status'], "ACTIVE");
        assertEquals(loan['lender'].expectSome(), lender.address);
        
        // Repay loan
        let repayBlock = chain.mineBlock([
            Tx.contractCall('lend_hive', 'repay-loan', [
                types.uint(0)
            ], borrower.address)
        ]);
        
        repayBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify loan is completed
        getLoan = chain.callReadOnlyFn(
            'lend_hive',
            'get-loan',
            [types.uint(0)],
            borrower.address
        );
        
        loan = getLoan.result.expectSome().expectTuple();
        assertEquals(loan['status'], "COMPLETED");
    }
});