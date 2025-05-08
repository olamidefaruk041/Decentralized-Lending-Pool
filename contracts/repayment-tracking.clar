;; Repayment Tracking Contract
;; This contract manages loan servicing and collections

(define-map loans uint {
  borrower: principal,
  amount: uint,
  interest-rate: uint,
  term: uint,
  start-block: uint,
  end-block: uint,
  total-repaid: uint,
  status: (string-ascii 10)
})

(define-map repayments (tuple (loan-id uint) (payment-id uint)) {
  amount: uint,
  block-height: uint
})

(define-data-var next-payment-id uint u1)
(define-constant contract-owner tx-sender)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (get-repayment (loan-id uint) (payment-id uint))
  (map-get? repayments {loan-id: loan-id, payment-id: payment-id})
)

(define-read-only (calculate-remaining-balance (loan-id uint))
  (match (get-loan loan-id)
    loan (let (
      (principal-with-interest (+ (get amount loan) (/ (* (get amount loan) (get interest-rate loan) (get term loan)) u1200)))
      (total-repaid (get total-repaid loan))
    )
      (- principal-with-interest total-repaid))
    u0
  )
)

(define-public (create-loan (loan-id uint) (borrower principal) (amount uint) (interest-rate uint) (term uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can create loans
    (asserts! (is-none (get-loan loan-id)) (err u1)) ;; Loan ID already exists
    (map-set loans loan-id {
      borrower: borrower,
      amount: amount,
      interest-rate: interest-rate,
      term: term,
      start-block: block-height,
      end-block: (+ block-height (* term u144)), ;; ~144 blocks per day
      total-repaid: u0,
      status: "active"
    })
    (ok true)
  )
)

(define-public (make-repayment (loan-id uint) (amount uint))
  (match (get-loan loan-id)
    loan (let (
      (payment-id (var-get next-payment-id))
      (new-total-repaid (+ (get total-repaid loan) amount))
      (remaining (calculate-remaining-balance loan-id))
    )
      (begin
        (asserts! (is-eq tx-sender (get borrower loan)) (err u2)) ;; Not the borrower
        (asserts! (is-eq (get status loan) "active") (err u3)) ;; Loan not active
        (asserts! (> amount u0) (err u4)) ;; Amount must be positive

        ;; Record the payment
        (map-set repayments {loan-id: loan-id, payment-id: payment-id} {
          amount: amount,
          block-height: block-height
        })
        (var-set next-payment-id (+ payment-id u1))

        ;; Update loan with new total repaid
        (map-set loans loan-id (merge loan {
          total-repaid: new-total-repaid,
          status: (if (>= new-total-repaid (+ (get amount loan) (/ (* (get amount loan) (get interest-rate loan) (get term loan)) u1200)))
                    "completed"
                    "active")
        }))

        (ok true)
      ))
    (err u5) ;; Loan not found
  )
)

(define-public (mark-loan-defaulted (loan-id uint))
  (match (get-loan loan-id)
    loan (begin
      (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can mark default
      (asserts! (is-eq (get status loan) "active") (err u3)) ;; Loan not active
      (asserts! (> block-height (get end-block loan)) (err u6)) ;; Loan not yet expired

      ;; Mark as defaulted
      (map-set loans loan-id (merge loan { status: "defaulted" }))
      (ok true)
    )
    (err u5) ;; Loan not found
  )
)
