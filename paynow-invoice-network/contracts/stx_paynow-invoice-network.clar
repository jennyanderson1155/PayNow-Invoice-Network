;; Invoice Factoring Marketplace Smart Contract
;; Platform for businesses to sell invoices at a discount for immediate capital

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVOICE_NOT_FOUND (err u101))
(define-constant ERR_INVOICE_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_INVALID_DISCOUNT (err u104))
(define-constant ERR_INVOICE_EXPIRED (err u105))
(define-constant ERR_INSUFFICIENT_FUNDS (err u106))
(define-constant ERR_INVOICE_NOT_AVAILABLE (err u107))
(define-constant ERR_CANNOT_BUY_OWN_INVOICE (err u108))
(define-constant ERR_PAYMENT_ALREADY_MADE (err u109))
(define-constant ERR_INVOICE_OVERDUE (err u110))
(define-constant ERR_INVALID_STATUS (err u111))

;; Data Variables
(define-data-var invoice-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var min-discount-rate uint u500) ;; 5% minimum discount
(define-data-var max-discount-rate uint u3000) ;; 30% maximum discount
(define-data-var platform-fees-collected uint u0)

;; Invoice Status Types
(define-constant STATUS_AVAILABLE "available")
(define-constant STATUS_SOLD "sold")
(define-constant STATUS_PAID "paid")
(define-constant STATUS_DISPUTED "disputed")
(define-constant STATUS_EXPIRED "expired")

;; Data Maps
(define-map invoices
  { invoice-id: uint }
  {
    seller: principal,
    debtor: principal,
    original-amount: uint,
    discount-rate: uint, ;; in basis points (e.g., 1000 = 10%)
    discounted-amount: uint,
    due-date: uint,
    created-at: uint,
    status: (string-ascii 20),
    description: (string-ascii 500),
    invoice-number: (string-ascii 100)
  }
)

(define-map invoice-purchases
  { invoice-id: uint }
  {
    buyer: principal,
    purchase-price: uint,
    purchase-date: uint,
    payment-received: bool
  }
)

(define-map seller-ratings
  { seller: principal }
  {
    total-invoices: uint,
    successful-invoices: uint,
    disputed-invoices: uint,
    average-rating: uint,
    total-volume: uint
  }
)

(define-map buyer-ratings
  { buyer: principal }
  {
    total-purchases: uint,
    successful-purchases: uint,
    total-invested: uint,
    returns-earned: uint
  }
)

(define-map payment-confirmations
  { invoice-id: uint }
  {
    confirmer: principal,
    confirmation-date: uint,
    amount-paid: uint
  }
)

(define-map dispute-records
  { invoice-id: uint }
  {
    disputer: principal,
    dispute-reason: (string-ascii 500),
    dispute-date: uint,
    resolved: bool,
    resolution: (string-ascii 500)
  }
)

;; Helper functions
(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (>= a b) a b)
)

(define-private (calculate-discounted-amount (original-amount uint) (discount-rate uint))
  (let ((discount (/ (* original-amount discount-rate) u10000)))
    (- original-amount discount)
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

;; Read-only functions
(define-read-only (get-invoice (invoice-id uint))
  (map-get? invoices { invoice-id: invoice-id })
)

(define-read-only (get-invoice-purchase (invoice-id uint))
  (map-get? invoice-purchases { invoice-id: invoice-id })
)

(define-read-only (get-seller-rating (seller principal))
  (default-to 
    { total-invoices: u0, successful-invoices: u0, disputed-invoices: u0, average-rating: u0, total-volume: u0 }
    (map-get? seller-ratings { seller: seller })
  )
)

(define-read-only (get-buyer-rating (buyer principal))
  (default-to 
    { total-purchases: u0, successful-purchases: u0, total-invested: u0, returns-earned: u0 }
    (map-get? buyer-ratings { buyer: buyer })
  )
)

(define-read-only (get-payment-confirmation (invoice-id uint))
  (map-get? payment-confirmations { invoice-id: invoice-id })
)

(define-read-only (get-dispute-record (invoice-id uint))
  (map-get? dispute-records { invoice-id: invoice-id })
)

(define-read-only (get-platform-stats)
  {
    total-invoices: (var-get invoice-counter),
    platform-fee-rate: (var-get platform-fee-rate),
    min-discount-rate: (var-get min-discount-rate),
    max-discount-rate: (var-get max-discount-rate),
    fees-collected: (var-get platform-fees-collected)
  }
)

(define-read-only (is-invoice-overdue (invoice-id uint))
  (match (get-invoice invoice-id)
    invoice-info
    (and 
      (is-eq (get status invoice-info) STATUS_SOLD)
      (> stacks-block-height (get due-date invoice-info))
    )
    false
  )
)

(define-read-only (calculate-roi (invoice-id uint))
  (match (get-invoice invoice-id)
    invoice-info
    (let (
      (original (get original-amount invoice-info))
      (discounted (get discounted-amount invoice-info))
    )
      (if (> discounted u0)
        (/ (* (- original discounted) u10000) discounted)
        u0
      )
    )
    u0
  )
)

;; Public functions

;; Create a new invoice for factoring
(define-public (create-invoice 
  (debtor principal)
  (original-amount uint)
  (discount-rate uint)
  (due-date uint)
  (description (string-ascii 500))
  (invoice-number (string-ascii 100))
)
  (let (
    (seller tx-sender)
    (new-invoice-id (+ (var-get invoice-counter) u1))
    (discounted-amount (calculate-discounted-amount original-amount discount-rate))
  )
    (asserts! (> original-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= discount-rate (var-get min-discount-rate)) ERR_INVALID_DISCOUNT)
    (asserts! (<= discount-rate (var-get max-discount-rate)) ERR_INVALID_DISCOUNT)
    (asserts! (> due-date stacks-block-height) ERR_INVOICE_EXPIRED)
    
    ;; Create invoice record
    (map-set invoices
      { invoice-id: new-invoice-id }
      {
        seller: seller,
        debtor: debtor,
        original-amount: original-amount,
        discount-rate: discount-rate,
        discounted-amount: discounted-amount,
        due-date: due-date,
        created-at: stacks-block-height,
        status: STATUS_AVAILABLE,
        description: description,
        invoice-number: invoice-number
      }
    )
    
    ;; Update seller stats
    (let ((seller-stats (get-seller-rating seller)))
      (map-set seller-ratings
        { seller: seller }
        (merge seller-stats
          {
            total-invoices: (+ (get total-invoices seller-stats) u1),
            total-volume: (+ (get total-volume seller-stats) original-amount)
          }
        )
      )
    )
    
    (var-set invoice-counter new-invoice-id)
    (ok new-invoice-id)
  )
)

;; Purchase an invoice
(define-public (purchase-invoice (invoice-id uint))
  (let (
    (buyer tx-sender)
    (invoice-info (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
    (purchase-price (get discounted-amount invoice-info))
    (platform-fee (calculate-platform-fee purchase-price))
    (seller-payment (- purchase-price platform-fee))
  )
    (asserts! (is-eq (get status invoice-info) STATUS_AVAILABLE) ERR_INVOICE_NOT_AVAILABLE)
    (asserts! (not (is-eq buyer (get seller invoice-info))) ERR_CANNOT_BUY_OWN_INVOICE)
    (asserts! (< stacks-block-height (get due-date invoice-info)) ERR_INVOICE_EXPIRED)
    
    ;; Transfer funds: buyer pays purchase price
    (try! (stx-transfer? purchase-price buyer (as-contract tx-sender)))
    
    ;; Pay seller (minus platform fee)
    (try! (as-contract (stx-transfer? seller-payment tx-sender (get seller invoice-info))))
    
    ;; Record platform fee
    (var-set platform-fees-collected (+ (var-get platform-fees-collected) platform-fee))
    
    ;; Update invoice status
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-info { status: STATUS_SOLD })
    )
    
    ;; Record purchase
    (map-set invoice-purchases
      { invoice-id: invoice-id }
      {
        buyer: buyer,
        purchase-price: purchase-price,
        purchase-date: stacks-block-height,
        payment-received: false
      }
    )
    
    ;; Update buyer stats
    (let ((buyer-stats (get-buyer-rating buyer)))
      (map-set buyer-ratings
        { buyer: buyer }
        (merge buyer-stats
          {
            total-purchases: (+ (get total-purchases buyer-stats) u1),
            total-invested: (+ (get total-invested buyer-stats) purchase-price)
          }
        )
      )
    )
    
    (ok purchase-price)
  )
)

;; Confirm payment received from debtor
(define-public (confirm-payment (invoice-id uint) (amount-paid uint))
  (let (
    (invoice-info (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
    (purchase-info (unwrap! (get-invoice-purchase invoice-id) ERR_INVOICE_NOT_FOUND))
    (buyer (get buyer purchase-info))
  )
    (asserts! (is-eq tx-sender buyer) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status invoice-info) STATUS_SOLD) ERR_INVALID_STATUS)
    (asserts! (not (get payment-received purchase-info)) ERR_PAYMENT_ALREADY_MADE)
    (asserts! (> amount-paid u0) ERR_INVALID_AMOUNT)
    
    ;; Record payment confirmation
    (map-set payment-confirmations
      { invoice-id: invoice-id }
      {
        confirmer: tx-sender,
        confirmation-date: stacks-block-height,
        amount-paid: amount-paid
      }
    )
    
    ;; Update invoice status
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-info { status: STATUS_PAID })
    )
    
    ;; Update purchase record
    (map-set invoice-purchases
      { invoice-id: invoice-id }
      (merge purchase-info { payment-received: true })
    )
    
    ;; Update seller stats (successful invoice)
    (let ((seller-stats (get-seller-rating (get seller invoice-info))))
      (map-set seller-ratings
        { seller: (get seller invoice-info) }
        (merge seller-stats
          {
            successful-invoices: (+ (get successful-invoices seller-stats) u1)
          }
        )
      )
    )
    
    ;; Update buyer stats (successful purchase and returns)
    (let (
      (buyer-stats (get-buyer-rating buyer))
      (returns (- amount-paid (get purchase-price purchase-info)))
    )
      (map-set buyer-ratings
        { buyer: buyer }
        (merge buyer-stats
          {
            successful-purchases: (+ (get successful-purchases buyer-stats) u1),
            returns-earned: (+ (get returns-earned buyer-stats) returns)
          }
        )
      )
    )
    
    (ok amount-paid)
  )
)

;; File a dispute
(define-public (file-dispute (invoice-id uint) (reason (string-ascii 500)))
  (let (
    (invoice-info (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
    (purchase-info (unwrap! (get-invoice-purchase invoice-id) ERR_INVOICE_NOT_FOUND))
  )
    (asserts! (or 
      (is-eq tx-sender (get buyer purchase-info))
      (is-eq tx-sender (get seller invoice-info))
    ) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status invoice-info) STATUS_SOLD) ERR_INVALID_STATUS)
    
    ;; Create dispute record
    (map-set dispute-records
      { invoice-id: invoice-id }
      {
        disputer: tx-sender,
        dispute-reason: reason,
        dispute-date: stacks-block-height,
        resolved: false,
        resolution: ""
      }
    )
    
    ;; Update invoice status
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-info { status: STATUS_DISPUTED })
    )
    
    ;; Update seller stats (disputed invoice)
    (let ((seller-stats (get-seller-rating (get seller invoice-info))))
      (map-set seller-ratings
        { seller: (get seller invoice-info) }
        (merge seller-stats
          {
            disputed-invoices: (+ (get disputed-invoices seller-stats) u1)
          }
        )
      )
    )
    
    (ok true)
  )
)

;; Mark invoice as overdue (can be called by anyone)
(define-public (mark-overdue (invoice-id uint))
  (let (
    (invoice-info (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
  )
    (asserts! (is-eq (get status invoice-info) STATUS_SOLD) ERR_INVALID_STATUS)
    (asserts! (> stacks-block-height (get due-date invoice-info)) ERR_INVOICE_OVERDUE)
    
    ;; Update invoice status
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-info { status: STATUS_EXPIRED })
    )
    
    (ok true)
  )
)

;; Cancel invoice (only seller, only if available)
(define-public (cancel-invoice (invoice-id uint))
  (let (
    (invoice-info (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get seller invoice-info)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status invoice-info) STATUS_AVAILABLE) ERR_INVALID_STATUS)
    
    ;; Update invoice status
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-info { status: STATUS_EXPIRED })
    )
    
    (ok true)
  )
)

;; Admin functions (only contract owner)
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_AMOUNT) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (set-discount-limits (min-rate uint) (max-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (< min-rate max-rate) ERR_INVALID_DISCOUNT)
    (asserts! (<= max-rate u5000) ERR_INVALID_DISCOUNT) ;; Max 50%
    (var-set min-discount-rate min-rate)
    (var-set max-discount-rate max-rate)
    (ok true)
  )
)

(define-public (resolve-dispute (invoice-id uint) (resolution (string-ascii 500)))
  (let (
    (dispute-info (unwrap! (get-dispute-record invoice-id) ERR_INVOICE_NOT_FOUND))
    (invoice-info (unwrap! (get-invoice invoice-id) ERR_INVOICE_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status invoice-info) STATUS_DISPUTED) ERR_INVALID_STATUS)
    
    ;; Update dispute record
    (map-set dispute-records
      { invoice-id: invoice-id }
      (merge dispute-info 
        {
          resolved: true,
          resolution: resolution
        }
      )
    )
    
    ;; Update invoice status back to sold
    (map-set invoices
      { invoice-id: invoice-id }
      (merge invoice-info { status: STATUS_SOLD })
    )
    
    (ok true)
  )
)

(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get platform-fees-collected)) ERR_INSUFFICIENT_FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (var-set platform-fees-collected (- (var-get platform-fees-collected) amount))
    (ok amount)
  )
)