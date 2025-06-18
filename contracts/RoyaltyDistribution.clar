(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-NO-DISTRIBUTION (err u102))
(define-constant ERR-ALREADY-CLAIMED (err u103))

(define-map royalty-distributions
    uint
    {
        artist: principal,
        total-amount: uint,
        per-subscriber-amount: uint,
        distribution-height: uint,
        subscribers-count: uint,
        claimed-count: uint
    }
)

(define-map subscriber-claims
    { distribution-id: uint, subscriber: principal }
    { amount: uint, claimed: bool, claim-height: uint }
)

(define-map artist-balances
    principal
    { available-royalties: uint, total-distributed: uint }
)

(define-data-var next-distribution-id uint u1)

(define-public (deposit-royalties (amount uint))
    (let (
        (current-balance (default-to { available-royalties: u0, total-distributed: u0 } 
            (map-get? artist-balances tx-sender)))
    )
        (begin
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (ok (map-set artist-balances tx-sender
                {
                    available-royalties: (+ (get available-royalties current-balance) amount),
                    total-distributed: (get total-distributed current-balance)
                }
            ))
        )
    )
)

(define-public (create-distribution (amount uint) (subscribers-count uint))
    (let (
        (distribution-id (var-get next-distribution-id))
        (artist-balance (unwrap! (map-get? artist-balances tx-sender) ERR-NOT-AUTHORIZED))
        (per-subscriber (/ amount subscribers-count))
    )
        (begin
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (asserts! (> subscribers-count u0) ERR-INVALID-AMOUNT)
            (asserts! (>= (get available-royalties artist-balance) amount) ERR-INVALID-AMOUNT)
            (map-set artist-balances tx-sender
                {
                    available-royalties: (- (get available-royalties artist-balance) amount),
                    total-distributed: (+ (get total-distributed artist-balance) amount)
                }
            )
            (map-set royalty-distributions distribution-id
                {
                    artist: tx-sender,
                    total-amount: amount,
                    per-subscriber-amount: per-subscriber,
                    distribution-height: stacks-block-height,
                    subscribers-count: subscribers-count,
                    claimed-count: u0
                }
            )
            (var-set next-distribution-id (+ distribution-id u1))
            (ok distribution-id)
        )
    )
)

(define-public (register-subscriber-for-distribution (distribution-id uint) (subscriber principal))
    (let (
        (distribution (unwrap! (map-get? royalty-distributions distribution-id) ERR-NO-DISTRIBUTION))
    )
        (begin
            (asserts! (is-eq tx-sender (get artist distribution)) ERR-NOT-AUTHORIZED)
            (ok (map-set subscriber-claims 
                { distribution-id: distribution-id, subscriber: subscriber }
                {
                    amount: (get per-subscriber-amount distribution),
                    claimed: false,
                    claim-height: u0
                }
            ))
        )
    )
)

(define-public (claim-royalty-share (distribution-id uint))
    (let (
        (claim-data (unwrap! (map-get? subscriber-claims 
            { distribution-id: distribution-id, subscriber: tx-sender }) ERR-NO-DISTRIBUTION))
        (distribution (unwrap! (map-get? royalty-distributions distribution-id) ERR-NO-DISTRIBUTION))
    )
        (begin
            (asserts! (not (get claimed claim-data)) ERR-ALREADY-CLAIMED)
            (map-set subscriber-claims 
                { distribution-id: distribution-id, subscriber: tx-sender }
                {
                    amount: (get amount claim-data),
                    claimed: true,
                    claim-height: stacks-block-height
                }
            )
            (map-set royalty-distributions distribution-id
                (merge distribution { 
                    claimed-count: (+ (get claimed-count distribution) u1) 
                })
            )
            (ok (get amount claim-data))
        )
    )
)

(define-public (batch-register-subscribers (distribution-id uint) (subscribers (list 50 principal)))
    (let (
        (distribution (unwrap! (map-get? royalty-distributions distribution-id) ERR-NO-DISTRIBUTION))
    )
        (begin
            (asserts! (is-eq tx-sender (get artist distribution)) ERR-NOT-AUTHORIZED)
            (ok (map register-single-subscriber subscribers))
        )
    )
)

(define-private (register-single-subscriber (subscriber principal))
    (let (
        (distribution-id (- (var-get next-distribution-id) u1))
        (distribution (unwrap-panic (map-get? royalty-distributions distribution-id)))
    )
        (map-set subscriber-claims 
            { distribution-id: distribution-id, subscriber: subscriber }
            {
                amount: (get per-subscriber-amount distribution),
                claimed: false,
                claim-height: u0
            }
        )
    )
)

(define-read-only (get-distribution-info (distribution-id uint))
    (map-get? royalty-distributions distribution-id)
)

(define-read-only (get-subscriber-claim-status (distribution-id uint) (subscriber principal))
    (map-get? subscriber-claims { distribution-id: distribution-id, subscriber: subscriber })
)

(define-read-only (get-artist-balance (artist principal))
    (map-get? artist-balances artist)
)

(define-read-only (get-unclaimed-distributions (subscriber principal))
    (let (
        (current-distribution-id (var-get next-distribution-id))
    )
        (filter is-unclaimed-for-subscriber (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
    )
)

(define-private (is-unclaimed-for-subscriber (distribution-id uint))
    (let (
        (claim-data (map-get? subscriber-claims 
            { distribution-id: distribution-id, subscriber: tx-sender }))
    )
        (match claim-data
            some-claim (not (get claimed some-claim))
            false
        )
    )
)

(define-read-only (calculate-total-claimable (subscriber principal))
    (let (
        (unclaimed-list (get-unclaimed-distributions subscriber))
    )
        (fold + (map get-claim-amount unclaimed-list) u0)
    )
)

(define-private (get-claim-amount (distribution-id uint))
    (let (
        (claim-data (map-get? subscriber-claims 
            { distribution-id: distribution-id, subscriber: tx-sender }))
    )
        (match claim-data
            some-claim (if (get claimed some-claim) u0 (get amount some-claim))
            u0
        )
    )
)