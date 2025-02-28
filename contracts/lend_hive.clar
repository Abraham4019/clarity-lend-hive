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
        last-check: uint
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

(define-private (check-liquidation-condition (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-LOAN-NOT-FOUND))
        (current-time block-height)
        (loan-duration (get duration loan))
        (loan-start (get start-time loan))
    )
    (and
        (is-eq (get status loan) STATUS-ACTIVE)
        (>= current-time (+ loan-start loan-duration))
    ))
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
                    last-check: block-height
                })
                (var-set loan-counter (+ loan-id u1))
                (emit-loan-created loan-id tx-sender amount)
                (ok loan-id)
            )
            ERR-INSUFFICIENT-COLLATERAL
        )
    )
)

;; Read-only function to get loan details
(define-read-only (get-loan (loan-id uint))
    (map-get? Loans loan-id)
)
