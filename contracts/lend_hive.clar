;; LendHive - P2P Lending Platform

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-LOAN-NOT-FOUND (err u102))
(define-constant ERR-LOAN-ALREADY-FUNDED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-CANNOT-LIQUIDATE (err u105))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u106))
(define-constant ERR-INVALID-STATUS-TRANSITION (err u107))
(define-constant ERR-INVALID-REPAYMENT (err u108))

;; Loan Status Constants
(define-constant STATUS-REQUESTED "REQUESTED")
(define-constant STATUS-ACTIVE "ACTIVE")
(define-constant STATUS-REPAID "REPAID")
(define-constant STATUS-LIQUIDATED "LIQUIDATED")

;; Data Variables
(define-data-var loan-counter uint u0)
(define-data-var liquidation-threshold uint u150) ;; 150% collateral requirement
(define-data-var min-collateral-ratio uint u120) ;; 120% minimum collateral

;; Maps
(define-map Loans
    uint
    {
        borrower: principal,
        lender: (optional principal),
        amount: uint,
        interest-rate: uint,
        duration: uint,
        status: (string-ascii 20),
        start-time: uint,
        collateral: uint,
        last-check: uint,
        repaid-amount: uint
    }
)

(define-map UserLoans
    principal
    (list 100 uint)
)

;; Events
(define-private (emit-loan-created (loan-id uint) (borrower principal) (amount uint))
    (print { type: "loan-created", loan-id: loan-id, borrower: borrower, amount: amount })
)

(define-private (emit-loan-funded (loan-id uint) (lender principal))
    (print { type: "loan-funded", loan-id: loan-id, lender: lender })
)

(define-private (emit-loan-repayment (loan-id uint) (amount uint))
    (print { type: "loan-repayment", loan-id: loan-id, amount: amount })
)

;; Private Functions
(define-private (validate-loan-amount (amount uint))
    (> amount u0)
)

(define-private (validate-collateral (amount uint) (collateral uint))
    (let (
        (min-required (/ (* amount (var-get min-collateral-ratio)) u100))
    )
    (>= collateral min-required))
)

(define-private (validate-status-transition (current-status (string-ascii 20)) (new-status (string-ascii 20)))
    (or
        (and (is-eq current-status STATUS-REQUESTED) (is-eq new-status STATUS-ACTIVE))
        (and (is-eq current-status STATUS-ACTIVE) (is-eq new-status STATUS-REPAID))
        (and (is-eq current-status STATUS-ACTIVE) (is-eq new-status STATUS-LIQUIDATED))
    )
)

(define-private (calculate-repayment-amount (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) (err u102)))
        (interest-amount (/ (* (get amount loan) (get interest-rate loan)) u100))
    )
    (+ (get amount loan) interest-amount))
)

;; Public Functions
(define-public (create-loan-request (amount uint) (interest-rate uint) (duration uint) (collateral uint))
    (let
        (
            (loan-id (var-get loan-counter))
        )
        (if (and 
                (validate-loan-amount amount)
                (validate-collateral amount collateral)
            )
            (begin
                (map-set Loans loan-id {
                    borrower: tx-sender,
                    lender: none,
                    amount: amount,
                    interest-rate: interest-rate,
                    duration: duration,
                    status: STATUS-REQUESTED,
                    start-time: u0,
                    collateral: collateral,
                    last-check: block-height,
                    repaid-amount: u0
                })
                (var-set loan-counter (+ loan-id u1))
                (emit-loan-created loan-id tx-sender amount)
                (ok loan-id)
            )
            ERR-INSUFFICIENT-COLLATERAL
        )
    )
)

(define-public (fund-loan (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-LOAN-NOT-FOUND))
    )
    (asserts! (is-eq (get status loan) STATUS-REQUESTED) ERR-LOAN-ALREADY-FUNDED)
    (asserts! (is-none (get lender loan)) ERR-LOAN-ALREADY-FUNDED)
    
    (map-set Loans loan-id
        (merge loan {
            lender: (some tx-sender),
            status: STATUS-ACTIVE,
            start-time: block-height
        })
    )
    (emit-loan-funded loan-id tx-sender)
    (ok true))
)

(define-public (repay-loan (loan-id uint) (amount uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-LOAN-NOT-FOUND))
        (total-due (calculate-repayment-amount loan-id))
    )
    (asserts! (is-eq (get status loan) STATUS-ACTIVE) ERR-INVALID-STATUS-TRANSITION)
    (asserts! (is-eq (get borrower loan) tx-sender) ERR-NOT-AUTHORIZED)
    
    (let (
        (new-repaid-amount (+ (get repaid-amount loan) amount))
    )
    (map-set Loans loan-id
        (merge loan {
            repaid-amount: new-repaid-amount,
            status: (if (>= new-repaid-amount total-due) STATUS-REPAID STATUS-ACTIVE)
        })
    )
    (emit-loan-repayment loan-id amount)
    (ok true)))
)

;; Read-only function to get loan details
(define-read-only (get-loan (loan-id uint))
    (map-get? Loans loan-id)
)

;; Read-only function to get total repayment amount
(define-read-only (get-total-repayment-amount (loan-id uint))
    (ok (calculate-repayment-amount loan-id))
)
