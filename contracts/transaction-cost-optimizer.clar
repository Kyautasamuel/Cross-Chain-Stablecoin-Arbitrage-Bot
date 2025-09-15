;; Transaction Cost Optimizer for Cross-Chain Arbitrage
;; Dynamically tracks and optimizes transaction costs across chains and bridges

;; Constants
(define-constant contract-owner tx-sender)
(define-constant max-chains u10)
(define-constant max-bridges u5)
(define-constant gas-price-staleness-limit u20)

;; Error constants
(define-constant err-not-authorized (err u100))
(define-constant err-invalid-chain (err u101))
(define-constant err-invalid-bridge (err u102))
(define-constant err-stale-data (err u103))
(define-constant err-insufficient-data (err u104))

;; Data variables
(define-data-var optimization-enabled bool true)
(define-data-var cost-update-counter uint u0)
(define-data-var total-registered-chains uint u0)
(define-data-var total-registered-bridges uint u0)

;; Chain-specific gas price tracking
(define-map chain-gas-data
    { chain-id: uint }
    {
        chain-name: (string-ascii 20),
        current-gas-price: uint,
        average-gas-price: uint,
        base-fee: uint,
        priority-fee: uint,
        last-updated: uint,
        is-active: bool
    })

;; Bridge cost tracking with dynamic pricing
(define-map bridge-costs
    { bridge-id: uint }
    {
        bridge-name: (string-ascii 24),
        source-chain: uint,
        target-chain: uint,
        base-fee: uint,
        percentage-fee: uint,
        min-fee: uint,
        max-fee: uint,
        average-completion-time: uint,
        success-rate: uint,
        last-updated: uint,
        is-active: bool
    })

;; Transaction execution paths with cost analysis
(define-map execution-paths
    { path-id: uint }
    {
        route-description: (string-ascii 50),
        chains-involved: (list 5 uint),
        bridges-used: (list 3 uint),
        estimated-total-cost: uint,
        estimated-time: uint,
        confidence-score: uint,
        cached-at: uint
    })

;; Historical cost data for trend analysis
(define-map cost-history
    { history-id: uint }
    {
        chain-id: uint,
        gas-price: uint,
        timestamp: uint,
        trade-volume: uint
    })

;; Register new chain for cost tracking
(define-public (register-chain (target-chain-id uint) (chain-name (string-ascii 20)) (base-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (< (var-get total-registered-chains) max-chains) err-invalid-chain)
        
        (map-set chain-gas-data
            { chain-id: target-chain-id }
            {
                chain-name: chain-name,
                current-gas-price: base-fee,
                average-gas-price: base-fee,
                base-fee: base-fee,
                priority-fee: u0,
                last-updated: stacks-block-height,
                is-active: true
            })
        
        (var-set total-registered-chains (+ (var-get total-registered-chains) u1))
        (ok target-chain-id)))

;; Register bridge for cost analysis
(define-public (register-bridge (bridge-id uint)
                               (bridge-name (string-ascii 24))
                               (source-chain uint)
                               (target-chain uint)
                               (base-fee uint)
                               (percentage-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (asserts! (< (var-get total-registered-bridges) max-bridges) err-invalid-bridge)
        
        (map-set bridge-costs
            { bridge-id: bridge-id }
            {
                bridge-name: bridge-name,
                source-chain: source-chain,
                target-chain: target-chain,
                base-fee: base-fee,
                percentage-fee: percentage-fee,
                min-fee: (/ base-fee u2),
                max-fee: (* base-fee u5),
                average-completion-time: u300,
                success-rate: u95,
                last-updated: stacks-block-height,
                is-active: true
            })
        
        (var-set total-registered-bridges (+ (var-get total-registered-bridges) u1))
        (ok bridge-id)))

;; Update real-time gas prices
(define-public (update-gas-price (target-chain-id uint) (new-gas-price uint) (new-priority-fee uint))
    (let ((existing-data (unwrap! (map-get? chain-gas-data { chain-id: target-chain-id }) err-invalid-chain)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
            
            ;; Calculate new average (simple moving average)
            (let ((new-average (/ (+ (get average-gas-price existing-data) new-gas-price) u2)))
                (map-set chain-gas-data
                    { chain-id: target-chain-id }
                    {
                        chain-name: (get chain-name existing-data),
                        current-gas-price: new-gas-price,
                        average-gas-price: new-average,
                        base-fee: (get base-fee existing-data),
                        priority-fee: new-priority-fee,
                        last-updated: stacks-block-height,
                        is-active: (get is-active existing-data)
                    }))
            
            ;; Record in history
            (let ((history-id (+ (var-get cost-update-counter) u1)))
                (map-set cost-history
                    { history-id: history-id }
                    {
                        chain-id: target-chain-id,
                        gas-price: new-gas-price,
                        timestamp: stacks-block-height,
                        trade-volume: u1000
                    })
                (var-set cost-update-counter history-id))
            
            (ok new-gas-price))))

;; Calculate optimal execution path for given trade
(define-public (calculate-optimal-path (trade-amount uint) (source-chain uint) (target-chain uint))
    (let ((direct-cost (calculate-direct-chain-cost trade-amount source-chain target-chain))
          (bridge-cost (calculate-bridge-route-cost trade-amount source-chain target-chain)))
        
        (let ((path-id (+ (var-get cost-update-counter) u1))
              (optimal-cost (if (< direct-cost bridge-cost) direct-cost bridge-cost))
              (optimal-route (if (< direct-cost bridge-cost) "direct-chain" "bridge-route")))
            
            (map-set execution-paths
                { path-id: path-id }
                {
                    route-description: optimal-route,
                    chains-involved: (list source-chain target-chain),
                    bridges-used: (if (< direct-cost bridge-cost) (list) (list u1)),
                    estimated-total-cost: optimal-cost,
                    estimated-time: (if (< direct-cost bridge-cost) u60 u300),
                    confidence-score: u85,
                    cached-at: stacks-block-height
                })
            
            (ok {
                recommended-path: optimal-route,
                total-cost: optimal-cost,
                estimated-savings: (if (< direct-cost bridge-cost) 
                                     (- bridge-cost direct-cost)
                                     (- direct-cost bridge-cost)),
                execution-time: (if (< direct-cost bridge-cost) u60 u300),
                path-id: path-id
            }))))

;; Calculate direct chain execution cost
(define-read-only (calculate-direct-chain-cost (amount uint) (source-chain uint) (target-chain uint))
    (let ((source-gas-data (unwrap-panic (map-get? chain-gas-data { chain-id: source-chain })))
          (target-gas-data (unwrap-panic (map-get? chain-gas-data { chain-id: target-chain }))))
        
        (let ((source-cost (* (get current-gas-price source-gas-data) u21000))
              (target-cost (* (get current-gas-price target-gas-data) u21000))
              (total-gas-cost (+ source-cost target-cost)))
            (+ total-gas-cost (* amount u5)))))

;; Calculate bridge route execution cost  
(define-read-only (calculate-bridge-route-cost (amount uint) (source-chain uint) (target-chain uint))
    (let ((bridge-data (unwrap-panic (map-get? bridge-costs { bridge-id: u1 }))))
        (+ (get base-fee bridge-data)
           (* amount (get percentage-fee bridge-data))
           (* amount u10))))

;; Get cost comparison for multiple execution paths
(define-read-only (compare-execution-costs (trade-amount uint) (source-chain uint) (target-chain uint))
    (let ((direct-cost (calculate-direct-chain-cost trade-amount source-chain target-chain))
          (bridge-cost (calculate-bridge-route-cost trade-amount source-chain target-chain))
          (source-gas (unwrap-panic (map-get? chain-gas-data { chain-id: source-chain })))
          (target-gas (unwrap-panic (map-get? chain-gas-data { chain-id: target-chain }))))
        
        (ok {
            direct-path: {
                total-cost: direct-cost,
                gas-cost-source: (* (get current-gas-price source-gas) u21000),
                gas-cost-target: (* (get current-gas-price target-gas) u21000),
                estimated-time: u60,
                recommended: (< direct-cost bridge-cost)
            },
            bridge-path: {
                total-cost: bridge-cost,
                bridge-fee: (* trade-amount u10),
                estimated-time: u300,
                recommended: (< bridge-cost direct-cost)
            },
            cost-savings: (if (< direct-cost bridge-cost) 
                            (- bridge-cost direct-cost) 
                            (- direct-cost bridge-cost))
        })))

;; Read-only functions for system status
(define-read-only (get-system-status)
    (ok {
        optimization-enabled: (var-get optimization-enabled),
        total-chains: (var-get total-registered-chains),
        total-bridges: (var-get total-registered-bridges),
        cost-updates: (var-get cost-update-counter),
        current-block: stacks-block-height
    }))

(define-read-only (get-chain-info (target-chain-id uint))
    (map-get? chain-gas-data { chain-id: target-chain-id }))

(define-read-only (get-bridge-info (bridge-id uint))
    (map-get? bridge-costs { bridge-id: bridge-id }))
