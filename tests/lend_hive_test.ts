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

// Rest of tests remain unchanged
