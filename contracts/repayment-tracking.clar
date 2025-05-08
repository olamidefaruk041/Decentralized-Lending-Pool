;; Risk Assessment Contract
;; This contract calculates appropriate interest rates

(define-constant min-interest-rate u500) ;; 5.00%
(define-constant max-interest-rate u3000) ;; 30.00%
(define-constant base-interest-rate u1000) ;; 10.00%

(define-map loan-risk-profiles uint {
  interest-rate: uint,
  risk-score: uint,
  loan-term: uint
})

(define-constant contract-owner tx-sender)

(define-read-only (get-risk-profile (loan-id uint))
  (map-get? loan-risk-profiles loan-id)
)

(define-read-only (calculate-interest-rate (credit-score uint) (loan-amount uint) (loan-term uint))
  (let (
    (credit-factor (if (> credit-score u700)
                      (- u1000 (* u500 (/ (- credit-score u700) u300)))
                      (+ u1000 (* u1000 (/ (- u700 credit-score) u700)))))
    (amount-factor (if (> loan-amount u10000)
                      (+ u100 (* u200 (/ loan-amount u10000)))
                      u100))
    (term-factor (if (> loan-term u12)
                    (+ u100 (* u50 (/ loan-term u12)))
                    u100))
    (calculated-rate (/ (* base-interest-rate (+ credit-factor amount-factor term-factor)) u300))
  )
    (if (< calculated-rate min-interest-rate)
        min-interest-rate
        (if (> calculated-rate max-interest-rate)
            max-interest-rate
            calculated-rate))
  )
)

(define-public (assess-loan-risk (loan-id uint) (credit-score uint) (loan-amount uint) (loan-term uint))
  (let (
    (interest-rate (calculate-interest-rate credit-score loan-amount loan-term))
    (risk-score (- u1000 (/ (* credit-score u1000) u1000)))
  )
    (begin
      (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can assess risk
      (map-set loan-risk-profiles loan-id {
        interest-rate: interest-rate,
        risk-score: risk-score,
        loan-term: loan-term
      })
      (ok interest-rate)
    )
  )
)

(define-public (update-risk-profile (loan-id uint) (new-interest-rate uint) (new-risk-score uint))
  (match (get-risk-profile loan-id)
    profile (begin
      (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can update
      (map-set loan-risk-profiles loan-id (merge profile {
        interest-rate: new-interest-rate,
        risk-score: new-risk-score
      }))
      (ok true)
    )
    (err u1) ;; Profile not found
  )
)
