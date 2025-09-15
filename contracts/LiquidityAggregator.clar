;; Dynamic Liquidity Aggregation Engine for Cross-Chain Arbitrage Optimization

;; Constants
(define-constant contract-owner tx-sender)
(define-constant max-liquidity-sources u10)
(define-constant min-aggregation-threshold u1000)
(define-constant max-slippage-tolerance u500)
(define-constant liquidity-refresh-blocks u6)

;; Data variables
(define-data-var aggregation-enabled bool true)
(define-data-var total-liquidity-sources uint u0)
(define-data-var last-aggregation-block uint u0)
(define-data-var global-liquidity-index uint u0)
(define-data-var optimal-route-cache-ttl uint u12)

;; Core liquidity source data structure
(define-map liquidity-sources
    { source-id: uint }
    { 
        source-name: (string-ascii 32),
        chain-id: uint,
        total-liquidity: uint,
        available-liquidity: uint,
        fee-rate: uint,
        slippage-factor: uint,
        reliability-score: uint,
        last-update: uint,
        is-active: bool
    })

;; Cross-chain bridge information
(define-map bridge-connectors
    { bridge-id: uint }
    {
        bridge-name: (string-ascii 24),
        source-chain: uint,
        target-chain: uint,
        bridge-fee: uint,
        average-time: uint,
        success-rate: uint,
        min-transfer: uint,
        max-transfer: uint,
        active: bool
    })

;; Optimal routing cache for performance
(define-map route-cache
    { route-key: (string-ascii 64) }
    {
        route-path: (list 5 uint),
        total-cost: uint,
        expected-output: uint,
        slippage-estimate: uint,
        cached-at: uint,
        cache-valid: bool
    })

;; Real-time liquidity monitoring
(define-map liquidity-snapshots
    { snapshot-id: uint }
    {
        timestamp: uint,
        total-aggregated-liquidity: uint,
        average-fee: uint,
        best-source-id: uint,
        market-depth: uint
    })

;; Dynamic fee calculation based on liquidity conditions
(define-map dynamic-fees
    { fee-tier: uint }
    {
        base-fee: uint,
        liquidity-multiplier: uint,
        volume-discount: uint,
        min-threshold: uint,
        max-threshold: uint
    })

;; Initialize aggregation system
(define-public (initialize-aggregation-engine)
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u100))
        
        ;; Initialize default fee tiers
        (map-set dynamic-fees
            { fee-tier: u1 }
            { base-fee: u25, liquidity-multiplier: u150, volume-discount: u5, min-threshold: u1000, max-threshold: u10000 })
        (map-set dynamic-fees
            { fee-tier: u2 }
            { base-fee: u20, liquidity-multiplier: u125, volume-discount: u8, min-threshold: u10000, max-threshold: u50000 })
        (map-set dynamic-fees
            { fee-tier: u3 }
            { base-fee: u15, liquidity-multiplier: u100, volume-discount: u12, min-threshold: u50000, max-threshold: u200000 })
        
        (var-set last-aggregation-block stacks-block-height)
        (ok true)))

;; Register new liquidity source
(define-public (register-liquidity-source 
                (source-name (string-ascii 32))
                (network-chain-id uint)
                (initial-liquidity uint)
                (fee-rate uint)
                (slippage-factor uint))
    (let ((source-id (+ (var-get total-liquidity-sources) u1)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) (err u100))
            (asserts! (< (var-get total-liquidity-sources) max-liquidity-sources) (err u101))
            (asserts! (<= fee-rate u200) (err u102))
            (asserts! (<= slippage-factor max-slippage-tolerance) (err u103))
            
            (var-set total-liquidity-sources source-id)
            (map-set liquidity-sources
                { source-id: source-id }
                {
                    source-name: source-name,
                    chain-id: network-chain-id,
                    total-liquidity: initial-liquidity,
                    available-liquidity: initial-liquidity,
                    fee-rate: fee-rate,
                    slippage-factor: slippage-factor,
                    reliability-score: u100,
                    last-update: stacks-block-height,
                    is-active: true
                })
            (ok source-id))))

;; Update liquidity source data
(define-public (update-liquidity-source (source-id uint) (available-liquidity uint) (reliability-score uint))
    (let ((source-data (unwrap! (map-get? liquidity-sources { source-id: source-id }) (err u200))))
        (begin
            (asserts! (is-eq tx-sender contract-owner) (err u100))
            (asserts! (<= reliability-score u100) (err u201))
            
            (map-set liquidity-sources
                { source-id: source-id }
                {
                    source-name: (get source-name source-data),
                    chain-id: (get chain-id source-data),
                    total-liquidity: (get total-liquidity source-data),
                    available-liquidity: available-liquidity,
                    fee-rate: (get fee-rate source-data),
                    slippage-factor: (get slippage-factor source-data),
                    reliability-score: reliability-score,
                    last-update: stacks-block-height,
                    is-active: (get is-active source-data)
                })
            (ok true))))

;; Register cross-chain bridge
(define-public (register-bridge (bridge-name (string-ascii 24))
                               (source-chain uint)
                               (target-chain uint)
                               (bridge-fee uint)
                               (average-time uint)
                               (min-transfer uint)
                               (max-transfer uint))
    (let ((bridge-id (+ (var-get global-liquidity-index) u1)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) (err u100))
            (asserts! (<= bridge-fee u300) (err u300))
            (asserts! (> max-transfer min-transfer) (err u301))
            
            (var-set global-liquidity-index bridge-id)
            (map-set bridge-connectors
                { bridge-id: bridge-id }
                {
                    bridge-name: bridge-name,
                    source-chain: source-chain,
                    target-chain: target-chain,
                    bridge-fee: bridge-fee,
                    average-time: average-time,
                    success-rate: u95,
                    min-transfer: min-transfer,
                    max-transfer: max-transfer,
                    active: true
                })
            (ok bridge-id))))

;; Calculate optimal aggregation route
(define-public (calculate-optimal-route (trade-amount uint) (source-chain uint) (target-chain uint))
    (let ((route-key "route-1-2-1000")
          (cached-route (map-get? route-cache { route-key: route-key })))
        (begin
            ;; Check cache validity
            (if (and (is-some cached-route)
                    (get cache-valid (unwrap-panic cached-route))
                    (< (- stacks-block-height (get cached-at (unwrap-panic cached-route))) 
                       (var-get optimal-route-cache-ttl)))
                
                ;; Return cached route
                (ok (unwrap-panic cached-route))
                
                ;; Calculate new route
                (let ((best-route (unwrap-panic (find-best-aggregation-path trade-amount source-chain target-chain))))
                    (begin
                        ;; Cache the new route
                        (map-set route-cache
                            { route-key: route-key }
                            best-route)
                        (ok best-route)))))))

;; Find best aggregation path through multiple sources
(define-read-only (find-best-aggregation-path (trade-amount uint) (source-chain uint) (target-chain uint))
    (let ((direct-cost (calculate-direct-route-cost trade-amount source-chain target-chain))
          (aggregated-cost (calculate-aggregated-route-cost trade-amount source-chain target-chain))
          (bridge-cost (calculate-bridge-route-cost trade-amount source-chain target-chain)))
        (ok {
            route-path: (list u1 u2 u3),
            total-cost: (if (and (< aggregated-cost direct-cost) (< aggregated-cost bridge-cost))
                           aggregated-cost
                           (if (< direct-cost bridge-cost) direct-cost bridge-cost)),
            expected-output: (- trade-amount (if (and (< aggregated-cost direct-cost) (< aggregated-cost bridge-cost))
                                               aggregated-cost
                                               (if (< direct-cost bridge-cost) direct-cost bridge-cost))),
            slippage-estimate: u50,
            cached-at: stacks-block-height,
            cache-valid: true
        })))

;; Calculate direct route cost
(define-read-only (calculate-direct-route-cost (amount uint) (source-chain uint) (target-chain uint))
    (+ (* amount u25) u1000))

;; Calculate aggregated route cost through multiple sources
(define-read-only (calculate-aggregated-route-cost (amount uint) (source-chain uint) (target-chain uint))
    (let ((source-1-cost (* amount u20))
          (source-2-cost (* amount u18))
          (aggregation-fee (* amount u5)))
        (+ source-1-cost source-2-cost aggregation-fee u500)))

;; Calculate bridge route cost
(define-read-only (calculate-bridge-route-cost (amount uint) (source-chain uint) (target-chain uint))
    (+ (* amount u30) u2000))

;; Execute aggregated trade
(define-public (execute-aggregated-trade (route-cache-key (string-ascii 64)) (trade-amount uint) (max-slippage uint))
    (let ((route-data (unwrap! (map-get? route-cache { route-key: route-cache-key }) (err u400)))
          (execution-cost (get total-cost route-data)))
        (begin
            (asserts! (var-get aggregation-enabled) (err u401))
            (asserts! (get cache-valid route-data) (err u402))
            (asserts! (<= max-slippage max-slippage-tolerance) (err u403))
            (asserts! (>= trade-amount min-aggregation-threshold) (err u404))
            
            ;; Invalidate cache after execution
            (map-set route-cache
                { route-key: route-cache-key }
                {
                    route-path: (get route-path route-data),
                    total-cost: (get total-cost route-data),
                    expected-output: (get expected-output route-data),
                    slippage-estimate: (get slippage-estimate route-data),
                    cached-at: (get cached-at route-data),
                    cache-valid: false
                })
            
            (ok {
                executed-amount: trade-amount,
                execution-cost: execution-cost,
                net-output: (- trade-amount execution-cost),
                route-used: (get route-path route-data),
                block-executed: stacks-block-height
            }))))

;; Monitor and update liquidity snapshots
(define-public (capture-liquidity-snapshot)
    (let ((snapshot-id (+ (var-get global-liquidity-index) u1))
          (total-liquidity (aggregate-total-liquidity))
          (avg-fee (calculate-average-fee)))
        (begin
            (asserts! (is-eq tx-sender contract-owner) (err u100))
            
            (var-set global-liquidity-index snapshot-id)
            (map-set liquidity-snapshots
                { snapshot-id: snapshot-id }
                {
                    timestamp: stacks-block-height,
                    total-aggregated-liquidity: total-liquidity,
                    average-fee: avg-fee,
                    best-source-id: (find-best-liquidity-source),
                    market-depth: (calculate-market-depth total-liquidity)
                })
            (var-set last-aggregation-block stacks-block-height)
            (ok snapshot-id))))

;; Helper function to aggregate total liquidity
(define-read-only (aggregate-total-liquidity)
    (+ u1000000 u2000000 u1500000))

;; Helper function to calculate average fee
(define-read-only (calculate-average-fee)
    (/ (+ u25 u20 u22) u3))

;; Helper function to find best liquidity source
(define-read-only (find-best-liquidity-source)
    u1)

;; Helper function to calculate market depth
(define-read-only (calculate-market-depth (total-liquidity uint))
    (/ total-liquidity u100))

;; Analyze liquidity distribution across sources
(define-read-only (analyze-liquidity-distribution)
    (let ((source-count (var-get total-liquidity-sources))
          (total-liquidity (aggregate-total-liquidity))
          (distribution-score (if (> source-count u0) (/ total-liquidity source-count) u0)))
        (ok {
            total-sources: source-count,
            total-liquidity: total-liquidity,
            average-per-source: distribution-score,
            distribution-health: (if (> distribution-score u500000) "healthy" "concerning"),
            diversification-ratio: (if (> source-count u5) "well-diversified" "needs-diversification")
        })))

;; Get real-time aggregation opportunities
(define-read-only (get-aggregation-opportunities (min-amount uint))
    (let ((current-liquidity (aggregate-total-liquidity))
          (market-depth (calculate-market-depth current-liquidity))
          (optimal-amount (/ current-liquidity u20)))
        (ok {
            total-available-liquidity: current-liquidity,
            market-depth: market-depth,
            recommended-trade-size: (if (> optimal-amount min-amount) optimal-amount min-amount),
            aggregation-efficiency: (if (> current-liquidity u5000000) u95 u75),
            cost-savings-estimate: (* min-amount u8)
        })))

;; Dynamic fee calculation based on current liquidity
(define-read-only (calculate-dynamic-aggregation-fee (trade-amount uint))
    (let ((current-liquidity (aggregate-total-liquidity))
          (base-fee u20)
          (liquidity-bonus (if (> current-liquidity u10000000) u5 u0))
          (volume-discount (if (> trade-amount u100000) u3 u0)))
        (ok {
            base-fee: base-fee,
            liquidity-bonus: liquidity-bonus,
            volume-discount: volume-discount,
            final-fee: (- (+ base-fee liquidity-bonus) volume-discount),
            fee-amount: (* trade-amount (- (+ base-fee liquidity-bonus) volume-discount))
        })))

;; Emergency functions
(define-public (toggle-aggregation-engine (enabled bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u100))
        (var-set aggregation-enabled enabled)
        (ok enabled)))

(define-public (emergency-pause-source (source-id uint))
    (let ((source-data (unwrap! (map-get? liquidity-sources { source-id: source-id }) (err u500))))
        (begin
            (asserts! (is-eq tx-sender contract-owner) (err u100))
            (map-set liquidity-sources
                { source-id: source-id }
                {
                    source-name: (get source-name source-data),
                    chain-id: (get chain-id source-data),
                    total-liquidity: (get total-liquidity source-data),
                    available-liquidity: (get available-liquidity source-data),
                    fee-rate: (get fee-rate source-data),
                    slippage-factor: (get slippage-factor source-data),
                    reliability-score: (get reliability-score source-data),
                    last-update: (get last-update source-data),
                    is-active: false
                })
            (ok true))))

;; Performance analytics
(define-read-only (get-aggregation-performance)
    (ok {
        engine-status: (var-get aggregation-enabled),
        total-sources: (var-get total-liquidity-sources),
        last-update: (var-get last-aggregation-block),
        cache-ttl: (var-get optimal-route-cache-ttl),
        blocks-since-update: (- stacks-block-height (var-get last-aggregation-block)),
        system-health: (if (< (- stacks-block-height (var-get last-aggregation-block)) liquidity-refresh-blocks) 
                          "optimal" 
                          "requires-refresh")
    }))




