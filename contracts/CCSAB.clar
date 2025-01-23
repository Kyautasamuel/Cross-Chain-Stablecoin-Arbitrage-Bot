;; Cross-Chain Stablecoin Arbitrage Bot

;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-price-difference u100) ;; Minimum price difference in basis points (1% = 100)

;; Data vars
(define-data-var last-price-chain-a uint u0)
(define-data-var last-price-chain-b uint u0)

;; Public functions
(define-public (update-prices (price-a uint) (price-b uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u100))
        (var-set last-price-chain-a price-a)
        (var-set last-price-chain-b price-b)
        (ok true)))

(define-read-only (get-arbitrage-opportunity)
    (let (
        (price-a (var-get last-price-chain-a))
        (price-b (var-get last-price-chain-b))
        (difference (if (> price-a price-b)
            (- price-a price-b)
            (- price-b price-a))))
        
        (if (>= difference min-price-difference)
            (ok {
                price-difference: difference,
                buy-on: (if (> price-b price-a) "chain-a" "chain-b"),
                sell-on: (if (> price-b price-a) "chain-b" "chain-a")
            })
            (err u0))))



;; Add these data variables
(define-data-var price-history-a (list 100 uint) (list))
(define-data-var price-history-b (list 100 uint) (list))

;; Add this function
(define-public (record-price-history)
    (let ((current-history-a (var-get price-history-a))
          (current-history-b (var-get price-history-b)))
        (begin
            (var-set price-history-a (unwrap! (as-max-len? (concat (list (var-get last-price-chain-a)) current-history-a) u100) (err u1)))
            (var-set price-history-b (unwrap! (as-max-len? (concat (list (var-get last-price-chain-b)) current-history-b) u100) (err u1)))
            (ok true))))


;; Add constant
(define-constant transaction-fee u10) ;; 0.1% fee

(define-read-only (calculate-potential-profit (trade-amount uint))
    (let (
        (price-a (var-get last-price-chain-a))
        (price-b (var-get last-price-chain-b))
        (gross-profit (- (if (> price-a price-b) price-a price-b) 
                        (if (> price-a price-b) price-b price-a)))
        (fee-amount (* trade-amount transaction-fee))
    )
    (ok (- gross-profit fee-amount))))
