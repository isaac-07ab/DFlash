;; Define interface to Pool contract
(use-trait pool-trait .traits.pool-trait)

;; Track user deposits
(define-map deposits
    principal
    uint
)
(define-data-var total-deposits uint u0)

;; Execute yield optimization strategy
(define-public (optimize-yield
        (pool-1 <pool-trait>)
        (pool-2 <pool-trait>)
    )
    (let ((total (var-get total-deposits)))
        (match (contract-call? .DFlash flash-loan total "optimize")
            success (let (
                    (pool-1-response (contract-call? pool-1 get-apy))
                    (pool-2-response (contract-call? pool-2 get-apy))
                )
                (match pool-1-response
                    pool-1-apy (match pool-2-response
                        pool-2-apy (if (> pool-1-apy pool-2-apy)
                            ;; Both branches now return (response bool uint)
                            (contract-call? pool-1 deposit total)
                            (contract-call? pool-2 deposit total)
                        )
                        error-2 (err u2)
                    )
                    error-1 (err u1)
                )
            )
            error (err u0)
        )
    )
)
