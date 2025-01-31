;; LendHive - P2P Lending Platform

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-LOAN-NOT-FOUND (err u102))
(define-constant ERR-LOAN-ALREADY-FUNDED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-CANNOT-LIQUIDATE (err u105))

;; Data Variables
(define-data-var loan-counter uint u0)
(define-data-var liquidation-threshold uint u150) ;; 150% collateral requirement

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

;; Private Functions
(define-private (validate-loan-amount (amount uint))
    (> amount u0)
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
        (is-eq (get status loan) "ACTIVE")
        (>= current-time (+ loan-start loan-duration))
    ))
)

;; Public Functions
(define-public (create-loan-request (amount uint) (interest-rate uint) (duration uint))
    (let
        (
            (loan-id (var-get loan-counter))
        )
        (if (validate-loan-amount amount)
            (begin
                (map-set Loans loan-id {
                    borrower: tx-sender,
                    lender: none,
                    amount: amount,
                    interest-rate: interest-rate,
                    duration: duration,
                    status: "REQUESTED",
                    start-time: u0,
                    collateral: amount,
                    last-check: block-height
                })
                (var-set loan-counter (+ loan-id u1))
                (ok loan-id)
            )
            ERR-INVALID-AMOUNT
        )
    )
)

(define-public (fund-loan (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-LOAN-NOT-FOUND))
    )
    (if (is-eq (get status loan) "REQUESTED")
        (begin
            (try! (stx-transfer? (get amount loan) tx-sender (get borrower loan)))
            (map-set Loans loan-id (merge loan {
                lender: (some tx-sender),
                status: "ACTIVE", 
                start-time: block-height,
                last-check: block-height
            }))
            (ok true)
        )
        ERR-LOAN-ALREADY-FUNDED
    ))
)

(define-public (repay-loan (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-LOAN-NOT-FOUND))
        (repayment-amount (calculate-repayment-amount loan-id))
    )
    (if (and
            (is-eq (get status loan) "ACTIVE")
            (is-eq (get borrower loan) tx-sender)
        )
        (begin
            (try! (stx-transfer? repayment-amount tx-sender (unwrap! (get lender loan) ERR-LOAN-NOT-FOUND)))
            (map-set Loans loan-id (merge loan {
                status: "COMPLETED"
            }))
            (ok true)
        )
        ERR-NOT-AUTHORIZED
    ))
)

(define-public (liquidate-loan (loan-id uint))
    (let (
        (loan (unwrap! (map-get? Loans loan-id) ERR-LOAN-NOT-FOUND))
    )
    (if (and 
            (check-liquidation-condition loan-id)
            (is-some (get lender loan))
        )
        (begin
            (try! (stx-transfer? (get collateral loan) (get borrower loan) (unwrap! (get lender loan) ERR-LOAN-NOT-FOUND)))
            (map-set Loans loan-id (merge loan {
                status: "LIQUIDATED"
            }))
            (ok true)
        )
        ERR-CANNOT-LIQUIDATE
    ))
)

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
    (map-get? Loans loan-id)
)

(define-read-only (get-loan-count)
    (var-get loan-counter)
)

(define-read-only (can-be-liquidated (loan-id uint))
    (check-liquidation-condition loan-id)
)
