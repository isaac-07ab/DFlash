;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Enhanced Pool Contract v2.0
;; Features:
;; - Advanced Liquidity Management with Dynamic APY
;; - Cross-Chain Yield Optimization
;; - Governance & DAO Integration
;; - Liquidity Mining & Rewards System
;; - Multi-Chain Pool Management
;; - Decentralized Pool Governance
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-trait pool-trait (
    (deposit
        (uint)
        (response bool uint)
    )
    (withdraw
        (uint)
        (response bool uint)
    )
    (get-apy
        ()
        (response uint uint)
    )
))

;; Implement pool trait
(impl-trait .traits.pool-trait)

;; ---------------------------
;; Core Data Structures
;; ---------------------------

;; Original deposit tracking
(define-map user-deposits
    principal
    uint
)

;; Enhanced user data with rewards and analytics
(define-map user-data
    principal
    {
        total-deposited: uint,
        total-withdrawn: uint,
        accumulated-rewards: uint,
        last-claim-block: uint,
        reward-multiplier: uint,
        stake-end-block: uint,
        governance-weight: uint
    }
)

;; ---------------------------
;; 1. Advanced Liquidity Management
;; ---------------------------

;; Dynamic APY calculation based on utilization and performance
(define-map apy-history
    uint ;; timestamp (block height)
    {
        apy: uint,
        utilization-rate: uint,
        total-deposits: uint,
        total-rewards: uint,
        performance-score: uint
    }
)

;; Liquidity mining rewards system
(define-map user-rewards
    principal
    {
        accumulated-rewards: uint,
        last-claim-block: uint,
        reward-multiplier: uint,
        staked-amount: uint,
        stake-duration: uint
    }
)

;; Reward pool configuration
(define-map reward-pools
    (string-ascii 32) ;; pool-type
    {
        total-rewards: uint,
        reward-rate: uint, ;; rewards per block
        start-block: uint,
        end-block: uint,
        active: bool
    }
)

;; ---------------------------
;; 3. Cross-Chain Yield Optimization
;; ---------------------------

;; Cross-chain pool coordination
(define-map cross-chain-pools
    uint ;; chain-id
    {
        pool-contract: principal,
        bridge-contract: principal,
        current-apy: uint,
        total-deposits: uint,
        bridge-fee: uint,
        min-deposit: uint,
        max-deposit: uint,
        active: bool,
        last-updated: uint
    }
)

;; Cross-chain operations tracking
(define-map cross-chain-operations
    uint ;; operation-id
    {
        user: principal,
        source-chain: uint,
        target-chain: uint,
        amount: uint,
        operation-type: (string-ascii 16), ;; "deposit", "withdraw", "rebalance"
        status: (string-ascii 16), ;; "pending", "completed", "failed"
        created-block: uint,
        completed-block: uint
    }
)

;; Bridge fee tracking
(define-map bridge-fees
    {source-chain: uint, target-chain: uint}
    {
        base-fee: uint,
        percentage-fee: uint,
        min-fee: uint,
        max-fee: uint
    }
)

;; ---------------------------
;; 7. Governance & DAO Integration
;; ---------------------------

;; Governance proposals for pool parameters
(define-map governance-proposals
    uint ;; proposal-id
    {
        proposer: principal,
        proposal-type: (string-ascii 32), ;; "apy-change", "fee-change", "parameter-change"
        target-parameter: (string-ascii 32),
        current-value: uint,
        new-value: uint,
        description: (string-ascii 256),
        votes-for: uint,
        votes-against: uint,
        total-weight-for: uint,
        total-weight-against: uint,
        created-block: uint,
        voting-end-block: uint,
        executed: bool,
        vetoed: bool
    }
)

;; Governance votes tracking
(define-map governance-votes
    {proposal-id: uint, voter: principal}
    {
        support: bool,
        weight: uint,
        timestamp: uint
    }
)

;; Governance configuration
(define-map governance-config
    (string-ascii 32) ;; config-key
    uint ;; config-value
)

;; Community strategy proposals
(define-map strategy-proposals
    uint ;; strategy-id
    {
        proposer: principal,
        strategy-name: (string-ascii 32),
        strategy-contract: principal,
        expected-apy: uint,
        risk-level: uint,
        votes-for: uint,
        votes-against: uint,
        approved: bool,
        active: bool
    }
)

;; ---------------------------
;; State Variables
;; ---------------------------

(define-data-var total-deposits uint u0)
(define-data-var current-apy uint u500) ;; 5% APY (500 basis points)
(define-data-var base-apy uint u300) ;; 3% base APY
(define-data-var max-apy uint u2000) ;; 20% max APY
(define-data-var utilization-target uint u8000) ;; 80% target utilization
(define-data-var total-rewards-distributed uint u0)
(define-data-var next-operation-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-strategy-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var governance-enabled bool true)
(define-data-var cross-chain-enabled bool true)

;; ---------------------------
;; Constants
;; ---------------------------

;; Original error codes
(define-constant ERR-INVALID-AMOUNT u1)
(define-constant ERR-INSUFFICIENT-BALANCE u2)
(define-constant ERR-OVERFLOW u3)
(define-constant ERR-INVALID-SENDER u4)

;; New error codes for enhanced features
(define-constant ERR-NOT-OWNER u5)
(define-constant ERR-GOVERNANCE-DISABLED u6)
(define-constant ERR-INVALID-PROPOSAL u7)
(define-constant ERR-ALREADY-VOTED u8)
(define-constant ERR-VOTING-ENDED u9)
(define-constant ERR-PROPOSAL-NOT-PASSED u10)
(define-constant ERR-CROSS-CHAIN-DISABLED u11)
(define-constant ERR-INVALID-CHAIN u12)
(define-constant ERR-BRIDGE-FAILED u13)
(define-constant ERR-INSUFFICIENT-REWARDS u14)
(define-constant ERR-STAKE-NOT-ENDED u15)
(define-constant ERR-INVALID-STRATEGY u16)
(define-constant ERR-STRATEGY-NOT-APPROVED u17)

;; Limits and bounds
(define-constant MAX-UINT u340282366920938463463374607431768211455)
(define-constant MIN-DEPOSIT u1)
(define-constant MAX-DEPOSIT u1000000000)
(define-constant MIN-STAKE-DURATION u144) ;; ~1 day in blocks
(define-constant MAX-STAKE-DURATION u52560) ;; ~1 year in blocks
(define-constant VOTING-PERIOD u1008) ;; ~1 week in blocks
(define-constant MIN-PROPOSAL-WEIGHT u1000) ;; Minimum weight to create proposals

;; ---------------------------
;; Validation Functions
;; ---------------------------

(define-private (validate-amount (amount uint))
    (begin
        (asserts!
            (and
                (>= amount MIN-DEPOSIT)
                (<= amount MAX-DEPOSIT)
            )
            (err ERR-INVALID-AMOUNT)
        )
        (ok amount)
    )
)

(define-private (check-overflow (a uint) (b uint))
    (let ((sum (+ a b)))
        (asserts!
            (and
                (>= sum a)
                (<= sum MAX-DEPOSIT)
            )
            (err ERR-OVERFLOW)
        )
        (ok sum)
    )
)

(define-private (validate-chain-id (target-chain-id uint))
    (begin
        (asserts! (is-some (map-get? cross-chain-pools target-chain-id)) (err ERR-INVALID-CHAIN))
        (asserts! (get active (unwrap! (map-get? cross-chain-pools target-chain-id) (err ERR-INVALID-CHAIN))) (err ERR-INVALID-CHAIN))
        (ok true)
    )
)

;; ---------------------------
;; 1. Advanced Liquidity Management Functions
;; ---------------------------

;; Calculate dynamic APY based on utilization and performance
(define-public (calculate-dynamic-apy)
    (let (
        (total-supply (var-get total-deposits))
        (utilization-rate (if (> total-supply u0) 
                            (/ (* total-supply u10000) (+ total-supply u1000000)) 
                            u0))
        (target-util (var-get utilization-target))
        (base-rate (var-get base-apy))
        (max-rate (var-get max-apy))
    )
    (let (
        (rate-adjustment (if (> utilization-rate target-util)
                           (/ (* (- utilization-rate target-util) (- max-rate base-rate)) (- u10000 target-util))
                           u0))
        (new-apy (+ base-rate rate-adjustment))
    )
    (begin
        ;; Update APY history
        (map-set apy-history stacks-block-height {
            apy: new-apy,
            utilization-rate: utilization-rate,
            total-deposits: total-supply,
            total-rewards: (var-get total-rewards-distributed),
            performance-score: (calculate-performance-score)
        })
        ;; Update current APY
        (var-set current-apy new-apy)
        (ok new-apy)
    ))))

;; Calculate performance score based on historical data
(define-private (calculate-performance-score)
    (let (
        (current-block stacks-block-height)
        (week-ago (- current-block u1008))
    )
    ;; Simple performance calculation - can be enhanced
    (if (> (var-get total-deposits) u0) u8500 u5000) ;; 85% or 50% performance score
    ))

;; Stake tokens for enhanced rewards
(define-public (stake-for-rewards (amount uint) (duration uint))
    (let ((validated-amount (try! (validate-amount amount))))
        (begin
            (asserts! (>= duration MIN-STAKE-DURATION) (err ERR-INVALID-AMOUNT))
            (asserts! (<= duration MAX-STAKE-DURATION) (err ERR-INVALID-AMOUNT))
            
            ;; Check user has sufficient balance
            (let ((current-balance (default-to u0 (map-get? user-deposits tx-sender))))
                (asserts! (>= current-balance validated-amount) (err ERR-INSUFFICIENT-BALANCE))
                
                ;; Calculate reward multiplier based on duration
                (let ((multiplier (+ u10000 (/ (* duration u5000) MAX-STAKE-DURATION)))) ;; 1x to 1.5x multiplier
                    ;; Update user rewards data
                    (map-set user-rewards tx-sender {
                        accumulated-rewards: (get accumulated-rewards (default-to {
                            accumulated-rewards: u0,
                            last-claim-block: stacks-block-height,
                            reward-multiplier: u10000,
                            staked-amount: u0,
                            stake-duration: u0
                        } (map-get? user-rewards tx-sender))),
                        last-claim-block: stacks-block-height,
                        reward-multiplier: multiplier,
                        staked-amount: validated-amount,
                        stake-duration: duration
                    })
                    
                    ;; Update user data
                    (map-set user-data tx-sender {
                        total-deposited: (get total-deposited (default-to {
                            total-deposited: u0,
                            total-withdrawn: u0,
                            accumulated-rewards: u0,
                            last-claim-block: stacks-block-height,
                            reward-multiplier: u10000,
                            stake-end-block: u0,
                            governance-weight: u0
                        } (map-get? user-data tx-sender))),
                        total-withdrawn: (get total-withdrawn (default-to {
                            total-deposited: u0,
                            total-withdrawn: u0,
                            accumulated-rewards: u0,
                            last-claim-block: stacks-block-height,
                            reward-multiplier: u10000,
                            stake-end-block: u0,
                            governance-weight: u0
                        } (map-get? user-data tx-sender))),
                        accumulated-rewards: (get accumulated-rewards (default-to {
                            total-deposited: u0,
                            total-withdrawn: u0,
                            accumulated-rewards: u0,
                            last-claim-block: stacks-block-height,
                            reward-multiplier: u10000,
                            stake-end-block: u0,
                            governance-weight: u0
                        } (map-get? user-data tx-sender))),
                        last-claim-block: stacks-block-height,
                        reward-multiplier: multiplier,
                        stake-end-block: (+ stacks-block-height duration),
                        governance-weight: (+ (get governance-weight (default-to {
                            total-deposited: u0,
                            total-withdrawn: u0,
                            accumulated-rewards: u0,
                            last-claim-block: stacks-block-height,
                            reward-multiplier: u10000,
                            stake-end-block: u0,
                            governance-weight: u0
                        } (map-get? user-data tx-sender))) validated-amount)
                    })
                    (ok true)
                )
            )
        )
    )
)

;; Claim accumulated rewards
(define-public (claim-rewards)
    (let ((user-reward-data (map-get? user-rewards tx-sender)))
        (match user-reward-data
            reward-data (let (
                (accumulated (get accumulated-rewards reward-data))
                (last-claim (get last-claim-block reward-data))
                (multiplier (get reward-multiplier reward-data))
                (staked-amount (get staked-amount reward-data))
            )
            (begin
                (asserts! (> accumulated u0) (err ERR-INSUFFICIENT-REWARDS))
                
                ;; Calculate additional rewards since last claim
                (let ((blocks-since-claim (- stacks-block-height last-claim))
                      (additional-rewards (/ (* staked-amount blocks-since-claim multiplier) u1000000)))
                    
                    (let ((total-rewards (+ accumulated additional-rewards)))
                        ;; Reset accumulated rewards
                        (map-set user-rewards tx-sender (merge reward-data {
                            accumulated-rewards: u0,
                            last-claim-block: stacks-block-height
                        }))
                        
                        ;; Update total rewards distributed
                        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) total-rewards))
                        (ok total-rewards)
                    )
                )
            ))
            (err ERR-INSUFFICIENT-REWARDS)
        )
    )
)

;; ---------------------------
;; 3. Cross-Chain Yield Optimization Functions
;; ---------------------------

;; Add cross-chain pool configuration
(define-public (add-cross-chain-pool 
    (target-chain-id uint)
    (pool-contract principal)
    (bridge-contract principal)
    (pool-apy uint)
    (bridge-fee uint)
    (min-deposit uint)
    (max-deposit uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
        (map-set cross-chain-pools target-chain-id {
            pool-contract: pool-contract,
            bridge-contract: bridge-contract,
            current-apy: pool-apy,
            total-deposits: u0,
            bridge-fee: bridge-fee,
            min-deposit: min-deposit,
            max-deposit: max-deposit,
            active: true,
            last-updated: stacks-block-height
        })
        (ok true)
    )
)

;; Update cross-chain pool APY
(define-public (update-cross-chain-apy (target-chain-id uint) (new-apy uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
        (try! (validate-chain-id target-chain-id))
        
        (let ((pool-data (unwrap! (map-get? cross-chain-pools target-chain-id) (err ERR-INVALID-CHAIN))))
            (map-set cross-chain-pools target-chain-id (merge pool-data {
                current-apy: new-apy,
                last-updated: stacks-block-height
            }))
            (ok true)
        )
    )
)

;; Helper function to find maximum of two values
(define-private (max-two (a uint) (b uint))
    (if (> a b) a b)
)

;; Find optimal cross-chain yield opportunity
(define-public (find-optimal-yield)
    (let (
        (local-apy (var-get current-apy))
        (chain-1-data (map-get? cross-chain-pools u1))
        (chain-2-data (map-get? cross-chain-pools u2))
    )
    (let (
        (chain-1-net-apy (match chain-1-data
            data (- (get current-apy data) (get bridge-fee data))
            u0))
        (chain-2-net-apy (match chain-2-data
            data (- (get current-apy data) (get bridge-fee data))
            u0))
    )
    (let ((best-apy (max-two local-apy (max-two chain-1-net-apy chain-2-net-apy))))
        (if (is-eq best-apy local-apy)
            (ok {target-chain: u0, apy: local-apy, is-local: true})
            (if (is-eq best-apy chain-1-net-apy)
                (ok {target-chain: u1, apy: chain-1-net-apy, is-local: false})
                (ok {target-chain: u2, apy: chain-2-net-apy, is-local: false})
            )
        )
    ))))

;; Execute cross-chain deposit
(define-public (cross-chain-deposit (target-chain uint) (amount uint))
    (let ((validated-amount (try! (validate-amount amount))))
        (begin
            (asserts! (var-get cross-chain-enabled) (err ERR-CROSS-CHAIN-DISABLED))
            (try! (validate-chain-id target-chain))
            
            (let ((operation-id (var-get next-operation-id))
                  (pool-data (unwrap! (map-get? cross-chain-pools target-chain) (err ERR-INVALID-CHAIN))))
                
                (asserts! (>= validated-amount (get min-deposit pool-data)) (err ERR-INVALID-AMOUNT))
                (asserts! (<= validated-amount (get max-deposit pool-data)) (err ERR-INVALID-AMOUNT))
                
                ;; Check user has sufficient balance
                (let ((current-balance (default-to u0 (map-get? user-deposits tx-sender))))
                    (asserts! (>= current-balance validated-amount) (err ERR-INSUFFICIENT-BALANCE))
                    
                    ;; Create cross-chain operation record
                    (map-set cross-chain-operations operation-id {
                        user: tx-sender,
                        source-chain: u0, ;; Current chain
                        target-chain: target-chain,
                        amount: validated-amount,
                        operation-type: "deposit",
                        status: "pending",
                        created-block: stacks-block-height,
                        completed-block: u0
                    })
                    
                    ;; Update local balance (simulate bridge transfer)
                    (map-set user-deposits tx-sender (- current-balance validated-amount))
                    (var-set total-deposits (- (var-get total-deposits) validated-amount))
                    
                    ;; Update operation ID
                    (var-set next-operation-id (+ operation-id u1))
                    (ok operation-id)
                )
            )
        )
    )
)

;; Complete cross-chain operation (called by bridge)
(define-public (complete-cross-chain-operation (operation-id uint) (success bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
        
        (let ((operation (map-get? cross-chain-operations operation-id)))
            (match operation
                op-data (begin
                    (map-set cross-chain-operations operation-id (merge op-data {
                        status: (if success "completed" "failed"),
                        completed-block: stacks-block-height
                    }))
                    
                    ;; If failed, refund user
                    (if (not success)
                        (let ((user (get user op-data))
                              (amount (get amount op-data)))
                            (map-set user-deposits user 
                                (+ (default-to u0 (map-get? user-deposits user)) amount))
                            (var-set total-deposits (+ (var-get total-deposits) amount))
                        )
                        true
                    )
                    (ok success)
                )
                (err ERR-INVALID-PROPOSAL)
            )
        )
    )
)

;; ---------------------------
;; 7. Governance & DAO Integration Functions
;; ---------------------------

;; Create governance proposal
(define-public (create-governance-proposal 
    (proposal-type (string-ascii 32))
    (target-parameter (string-ascii 32))
    (new-value uint)
    (description (string-ascii 256)))
    (begin
        (asserts! (var-get governance-enabled) (err ERR-GOVERNANCE-DISABLED))
        
        ;; Check proposer has minimum governance weight
        (let ((proposer-data (map-get? user-data tx-sender)))
            (asserts! (is-some proposer-data) (err ERR-INSUFFICIENT-BALANCE))
            (let ((data (unwrap! proposer-data (err ERR-INSUFFICIENT-BALANCE))))
                (asserts! (>= (get governance-weight data) MIN-PROPOSAL-WEIGHT) (err ERR-INSUFFICIENT-BALANCE))
            )
        )
        
        (let ((proposal-id (var-get next-proposal-id))
              (current-value (get-parameter-value target-parameter)))
            
            (map-set governance-proposals proposal-id {
                proposer: tx-sender,
                proposal-type: proposal-type,
                target-parameter: target-parameter,
                current-value: current-value,
                new-value: new-value,
                description: description,
                votes-for: u0,
                votes-against: u0,
                total-weight-for: u0,
                total-weight-against: u0,
                created-block: stacks-block-height,
                voting-end-block: (+ stacks-block-height VOTING-PERIOD),
                executed: false,
                vetoed: false
            })
            
            (var-set next-proposal-id (+ proposal-id u1))
            (ok proposal-id)
        )
    )
)

;; Vote on governance proposal
(define-public (vote-on-proposal (proposal-id uint) (support bool))
    (let ((proposal (map-get? governance-proposals proposal-id)))
        (match proposal
            prop-data (begin
                (asserts! (not (get executed prop-data)) (err ERR-INVALID-PROPOSAL))
                (asserts! (not (get vetoed prop-data)) (err ERR-INVALID-PROPOSAL))
                (asserts! (<= stacks-block-height (get voting-end-block prop-data)) (err ERR-VOTING-ENDED))
                
                ;; Check if user already voted
                (asserts! (is-none (map-get? governance-votes {proposal-id: proposal-id, voter: tx-sender})) 
                         (err ERR-ALREADY-VOTED))
                
                ;; Get user's governance weight
                (let ((voter-data (map-get? user-data tx-sender)))
                    (match voter-data
                        data (let ((weight (get governance-weight data)))
                            (begin
                                ;; Record vote
                                (map-set governance-votes {proposal-id: proposal-id, voter: tx-sender} {
                                    support: support,
                                    weight: weight,
                                    timestamp: stacks-block-height
                                })
                                
                                ;; Update proposal vote counts
                                (map-set governance-proposals proposal-id (merge prop-data {
                                    votes-for: (if support (+ (get votes-for prop-data) u1) (get votes-for prop-data)),
                                    votes-against: (if (not support) (+ (get votes-against prop-data) u1) (get votes-against prop-data)),
                                    total-weight-for: (if support (+ (get total-weight-for prop-data) weight) (get total-weight-for prop-data)),
                                    total-weight-against: (if (not support) (+ (get total-weight-against prop-data) weight) (get total-weight-against prop-data))
                                }))
                                (ok true)
                            )
                        )
                        (err ERR-INSUFFICIENT-BALANCE)
                    )
                )
            )
            (err ERR-INVALID-PROPOSAL)
        )
    )
)

;; Execute governance proposal
(define-public (execute-governance-proposal (proposal-id uint))
    (let ((proposal (map-get? governance-proposals proposal-id)))
        (match proposal
            prop-data (begin
                (asserts! (not (get executed prop-data)) (err ERR-INVALID-PROPOSAL))
                (asserts! (not (get vetoed prop-data)) (err ERR-INVALID-PROPOSAL))
                (asserts! (> stacks-block-height (get voting-end-block prop-data)) (err ERR-VOTING-ENDED))
                
                ;; Check if proposal passed (more weight for than against)
                (asserts! (> (get total-weight-for prop-data) (get total-weight-against prop-data)) 
                         (err ERR-PROPOSAL-NOT-PASSED))
                
                ;; Execute the proposal based on type
                (let ((param-name (get target-parameter prop-data))
                      (new-value (get new-value prop-data)))
                    (unwrap! (execute-parameter-change param-name new-value) (err ERR-INVALID-PROPOSAL))
                    
                    ;; Mark as executed
                    (map-set governance-proposals proposal-id (merge prop-data {executed: true}))
                    (ok true)
                )
            )
            (err ERR-INVALID-PROPOSAL)
        )
    )
)

;; Propose new strategy
(define-public (propose-strategy 
    (strategy-name (string-ascii 32))
    (strategy-contract principal)
    (expected-apy uint)
    (risk-level uint))
    (begin
        (asserts! (var-get governance-enabled) (err ERR-GOVERNANCE-DISABLED))
        
        (let ((strategy-id (var-get next-strategy-id)))
            (map-set strategy-proposals strategy-id {
                proposer: tx-sender,
                strategy-name: strategy-name,
                strategy-contract: strategy-contract,
                expected-apy: expected-apy,
                risk-level: risk-level,
                votes-for: u0,
                votes-against: u0,
                approved: false,
                active: false
            })
            
            (var-set next-strategy-id (+ strategy-id u1))
            (ok strategy-id)
        )
    )
)

;; ---------------------------
;; Helper Functions
;; ---------------------------

(define-private (get-parameter-value (param-name (string-ascii 32)))
    (if (is-eq param-name "current-apy")
        (var-get current-apy)
        (if (is-eq param-name "base-apy")
            (var-get base-apy)
            (if (is-eq param-name "max-apy")
                (var-get max-apy)
                u0
            )
        )
    )
)

(define-private (execute-parameter-change (param-name (string-ascii 32)) (new-value uint))
    (if (is-eq param-name "current-apy")
        (begin (var-set current-apy new-value) (ok true))
        (if (is-eq param-name "base-apy")
            (begin (var-set base-apy new-value) (ok true))
            (if (is-eq param-name "max-apy")
                (begin (var-set max-apy new-value) (ok true))
                (ok true)
            )
        )
    )
)

;; ---------------------------
;; Core Pool Functions (Enhanced)
;; ---------------------------

;; Enhanced deposit with rewards tracking
(define-public (deposit (amount uint))
    (let ((validated-amount (try! (validate-amount amount))))
        (let ((current-balance (default-to u0 (map-get? user-deposits tx-sender))))
            (let (
                (new-balance (try! (check-overflow current-balance validated-amount)))
                (new-total (try! (check-overflow (var-get total-deposits) validated-amount))
            ))
            (begin
                ;; Update core deposit tracking
                (map-set user-deposits tx-sender new-balance)
                (var-set total-deposits new-total)
                
                ;; Update enhanced user data
                (let ((current-user-data (default-to {
                    total-deposited: u0,
                    total-withdrawn: u0,
                    accumulated-rewards: u0,
                    last-claim-block: stacks-block-height,
                    reward-multiplier: u10000,
                    stake-end-block: u0,
                    governance-weight: u0
                } (map-get? user-data tx-sender))))
                    
                    (map-set user-data tx-sender (merge current-user-data {
                        total-deposited: (+ (get total-deposited current-user-data) validated-amount),
                        governance-weight: (+ (get governance-weight current-user-data) validated-amount)
                    }))
                )
                
                ;; Recalculate dynamic APY
                (unwrap! (calculate-dynamic-apy) (err ERR-OVERFLOW))
                (ok true)
            )
        ))
    )
)

;; Enhanced withdraw with rewards handling
(define-public (withdraw (amount uint))
    (let ((validated-amount (try! (validate-amount amount))))
        (let ((current-balance (default-to u0 (map-get? user-deposits tx-sender))))
            (begin
                (asserts! (<= validated-amount current-balance) (err ERR-INSUFFICIENT-BALANCE))
                
                ;; Update core deposit tracking
                (map-set user-deposits tx-sender (- current-balance validated-amount))
                (var-set total-deposits (- (var-get total-deposits) validated-amount))
                
                ;; Update enhanced user data
                (let ((current-user-data (default-to {
                    total-deposited: u0,
                    total-withdrawn: u0,
                    accumulated-rewards: u0,
                    last-claim-block: stacks-block-height,
                    reward-multiplier: u10000,
                    stake-end-block: u0,
                    governance-weight: u0
                } (map-get? user-data tx-sender))))
                    
                    (map-set user-data tx-sender (merge current-user-data {
                        total-withdrawn: (+ (get total-withdrawn current-user-data) validated-amount),
                        governance-weight: (if (>= (get governance-weight current-user-data) validated-amount)
                                             (- (get governance-weight current-user-data) validated-amount)
                                             u0)
                    }))
                )
                
                ;; Recalculate dynamic APY
                (unwrap! (calculate-dynamic-apy) (err ERR-OVERFLOW))
                (ok true)
            )
        )
    )
)

;; Enhanced APY getter
(define-public (get-apy)
    (ok (var-get current-apy))
)

;; ---------------------------
;; Administrative Functions
;; ---------------------------

(define-public (set-governance-enabled (enabled bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
        (var-set governance-enabled enabled)
        (ok true)
    )
)

(define-public (set-cross-chain-enabled (enabled bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
        (var-set cross-chain-enabled enabled)
        (ok true)
    )
)

(define-public (emergency-pause-cross-chain (target-chain-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
        
        (let ((pool-data (map-get? cross-chain-pools target-chain-id)))
            (match pool-data
                data (begin
                    (map-set cross-chain-pools target-chain-id (merge data {active: false}))
                    (ok true)
                )
                (err ERR-INVALID-CHAIN)
            )
        )
    )
)

;; ---------------------------
;; Read-Only Functions
;; ---------------------------

(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-deposits user))
)

(define-read-only (get-user-data (user principal))
    (map-get? user-data user)
)

(define-read-only (get-user-rewards (user principal))
    (map-get? user-rewards user)
)

(define-read-only (get-total-deposits)
    (var-get total-deposits)
)

(define-read-only (get-apy-history (height uint))
    (map-get? apy-history height)
)

(define-read-only (get-cross-chain-pool (id uint))
    (map-get? cross-chain-pools id)
)

(define-read-only (get-cross-chain-operation (operation-id uint))
    (map-get? cross-chain-operations operation-id)
)

(define-read-only (get-governance-proposal (proposal-id uint))
    (map-get? governance-proposals proposal-id)
)

(define-read-only (get-governance-vote (proposal-id uint) (voter principal))
    (map-get? governance-votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-strategy-proposal (strategy-id uint))
    (map-get? strategy-proposals strategy-id)
)

(define-read-only (get-contract-info)
    {
        total-deposits: (var-get total-deposits),
        current-apy: (var-get current-apy),
        base-apy: (var-get base-apy),
        max-apy: (var-get max-apy),
        total-rewards-distributed: (var-get total-rewards-distributed),
        governance-enabled: (var-get governance-enabled),
        cross-chain-enabled: (var-get cross-chain-enabled),
        next-proposal-id: (var-get next-proposal-id),
        next-operation-id: (var-get next-operation-id)
    }
)