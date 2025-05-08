;; Lender Verification Contract
;; This contract validates funding participants

(define-data-var min-lending-amount uint u1000)
(define-map approved-lenders principal bool)
(define-map lender-balances principal uint)

;; Only contract owner can call this function
(define-constant contract-owner tx-sender)

(define-read-only (get-min-lending-amount)
  (var-get min-lending-amount)
)

(define-read-only (is-approved-lender (lender principal))
  (default-to false (map-get? approved-lenders lender))
)

(define-read-only (get-lender-balance (lender principal))
  (default-to u0 (map-get? lender-balances lender))
)

(define-public (register-as-lender)
  (begin
    (asserts! (not (is-approved-lender tx-sender)) (err u1)) ;; Already registered
    (map-set approved-lenders tx-sender true)
    (ok true)
  )
)

(define-public (update-min-lending-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can update
    (var-set min-lending-amount new-amount)
    (ok true)
  )
)

(define-public (add-funds (amount uint))
  (begin
    (asserts! (is-approved-lender tx-sender) (err u2)) ;; Not an approved lender
    (asserts! (>= amount (var-get min-lending-amount)) (err u3)) ;; Below minimum amount
    (map-set lender-balances tx-sender (+ (get-lender-balance tx-sender) amount))
    (ok true)
  )
)

(define-public (remove-funds (amount uint))
  (begin
    (asserts! (is-approved-lender tx-sender) (err u2)) ;; Not an approved lender
    (asserts! (<= amount (get-lender-balance tx-sender)) (err u4)) ;; Insufficient balance
    (map-set lender-balances tx-sender (- (get-lender-balance tx-sender) amount))
    (ok true)
  )
)
