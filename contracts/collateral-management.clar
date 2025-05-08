;; Collateral Management Contract
;; This contract tracks assets securing loans

(define-map loan-collaterals uint {
  owner: principal,
  asset-type: (string-ascii 20),
  amount: uint,
  locked: bool
})

(define-constant contract-owner tx-sender)

(define-read-only (get-collateral (loan-id uint))
  (map-get? loan-collaterals loan-id)
)

(define-read-only (is-collateral-locked (loan-id uint))
  (match (get-collateral loan-id)
    collateral (get locked collateral)
    false
  )
)

(define-public (add-collateral (loan-id uint) (asset-type (string-ascii 20)) (amount uint))
  (begin
    (asserts! (is-none (get-collateral loan-id)) (err u1)) ;; Collateral already exists
    (map-set loan-collaterals loan-id {
      owner: tx-sender,
      asset-type: asset-type,
      amount: amount,
      locked: false
    })
    (ok true)
  )
)

(define-public (lock-collateral (loan-id uint))
  (match (get-collateral loan-id)
    collateral (begin
      (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can lock
      (asserts! (not (get locked collateral)) (err u2)) ;; Already locked
      (map-set loan-collaterals loan-id (merge collateral { locked: true }))
      (ok true)
    )
    (err u3) ;; Collateral not found
  )
)

(define-public (unlock-collateral (loan-id uint))
  (match (get-collateral loan-id)
    collateral (begin
      (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can unlock
      (asserts! (get locked collateral) (err u4)) ;; Not locked
      (map-set loan-collaterals loan-id (merge collateral { locked: false }))
      (ok true)
    )
    (err u3) ;; Collateral not found
  )
)

(define-public (liquidate-collateral (loan-id uint))
  (match (get-collateral loan-id)
    collateral (begin
      (asserts! (is-eq tx-sender contract-owner) (err u403)) ;; Only owner can liquidate
      (asserts! (get locked collateral) (err u4)) ;; Not locked
      (map-delete loan-collaterals loan-id)
      (ok true)
    )
    (err u3) ;; Collateral not found
  )
)
