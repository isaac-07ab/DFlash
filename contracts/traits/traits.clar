(define-trait amm-trait (
    (swap-exact-tokens-for-tokens
        (uint principal principal uint uint)  ;; amount-in, token-in, token-out, min-out, deadline
        (response uint uint)                  ;; returns (ok amount-out) or (err error-code)
    )
    (get-pair-details
        (principal principal)
        (
            response             {
            token-x: principal,
            token-y: principal,
            reserves-x: uint,
            reserves-y: uint,
        }
            uint
        )
    )
    (get-contract
        ()
        (response principal uint)
    )
))

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

(define-trait flash-loan-trait (
    (flash-loan
        (uint (string-ascii 20))
        (response bool uint)
    )
))
