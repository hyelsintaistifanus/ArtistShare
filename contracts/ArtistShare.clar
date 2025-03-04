
;; summary: Musicians lock tokens to distribute royalties to subscribers
;; description: A platform for artists to share royalties with their fans

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-NO-SUBSCRIPTION (err u102))

;; Data Maps
(define-map artist-profiles
    principal
    {
        total-locked: uint,
        royalty-rate: uint,
        subscriber-count: uint
    }
)

(define-map subscriptions
    { artist: principal, subscriber: principal }
    { active: bool, joined-at: uint }
)

(define-map streaming-metrics
    principal
    { total-streams: uint, total-earnings: uint }
)

;; Public Functions
(define-public (register-artist (royalty-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (ok (map-set artist-profiles tx-sender {
            total-locked: u0,
            royalty-rate: royalty-rate,
            subscriber-count: u0
        }))
    )
)

(define-public (lock-tokens (amount uint))
    (let (
        (artist-data (unwrap! (map-get? artist-profiles tx-sender) ERR-NOT-AUTHORIZED))
    )
        (begin
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (map-set artist-profiles tx-sender (merge artist-data {
                total-locked: (+ (get total-locked artist-data) amount)
            }))
            (ok true)
        )
    )
)

(define-public (subscribe-to-artist (artist principal))
    (begin
        (asserts! (not (is-eq tx-sender artist)) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? artist-profiles artist)) ERR-NOT-AUTHORIZED)
        (ok (map-set subscriptions 
            { artist: artist, subscriber: tx-sender }
            { active: true, joined-at: stacks-block-height }
        ))
    )
)

;; Read-only Functions
(define-read-only (get-artist-profile (artist principal))
    (map-get? artist-profiles artist)
)

(define-read-only (get-subscription-status (artist principal) (subscriber principal))
    (map-get? subscriptions { artist: artist, subscriber: subscriber })
)

(define-read-only (get-streaming-metrics (artist principal))
    (map-get? streaming-metrics artist)
)


(define-map tips 
    { tipper: principal, artist: principal }
    { amount: uint, timestamp: uint }
)

(define-public (tip-artist (artist principal) (amount uint))
    (let (
        (artist-exists (unwrap! (map-get? artist-profiles artist) ERR-NOT-AUTHORIZED))
    )
        (begin
            (asserts! (> amount u0) ERR-INVALID-AMOUNT)
            (map-set tips 
                { tipper: tx-sender, artist: artist }
                { amount: amount, timestamp: stacks-block-height }
            )
            (ok true)
        )
    )
)


(define-map verified-artists 
    principal 
    { verified: bool, verified-at: uint }
)

(define-public (verify-artist (artist principal))
    (begin
        (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
        (ok (map-set verified-artists artist 
            { verified: true, verified-at: stacks-block-height }
        ))
    )
)



(define-map exclusive-content
    principal
    { content-hash: (string-ascii 64), price: uint }
)

(define-public (add-exclusive-content (content-hash (string-ascii 64)) (price uint))
    (begin
        (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
        (ok (map-set exclusive-content tx-sender 
            { content-hash: content-hash, price: price }
        ))
    )
)


(define-map subscription-tiers
    { artist: principal, tier: uint }
    { price: uint, benefits: (string-ascii 64) }
)

(define-public (create-subscription-tier (tier uint) (price uint) (benefits (string-ascii 64)))
    (begin
        (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
        (ok (map-set subscription-tiers 
            { artist: tx-sender, tier: tier }
            { price: price, benefits: benefits }
        ))
    )
)


(define-map fan-points
    { fan: principal, artist: principal }
    { points: uint, last-action: uint }
)

(define-public (award-fan-points (fan principal) (points uint))
    (let (
        (existing-points (default-to u0 (get points (map-get? fan-points { fan: fan, artist: tx-sender }))))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (ok (map-set fan-points 
                { fan: fan, artist: tx-sender }
                { points: (+ existing-points points), last-action: stacks-block-height }
            ))
        )
    )
)


(define-map special-offers
    principal
    { discount: uint, end-block: uint, active: bool }
)

(define-public (create-special-offer (discount uint) (duration uint))
    (begin
        (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
        (ok (map-set special-offers tx-sender
            { discount: discount, 
              end-block: (+ stacks-block-height duration), 
              active: true }
        ))
    )
)


