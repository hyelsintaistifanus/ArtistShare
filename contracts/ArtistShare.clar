
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
