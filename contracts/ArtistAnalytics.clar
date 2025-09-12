(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-PERIOD (err u201))
(define-constant ERR-NO-DATA (err u202))

(define-map artist-metrics
    principal
    {
        total-revenue: uint,
        total-distributions: uint,
        total-subscribers: uint,
        avg-distribution-amount: uint,
        highest-distribution: uint,
        last-distribution-height: uint,
        subscriber-growth-rate: uint
    }
)

(define-map distribution-analytics
    { artist: principal, distribution-id: uint }
    {
        claim-rate: uint,
        claim-speed: uint,
        subscriber-count: uint,
        total-amount: uint,
        completion-height: uint,
        is-completed: bool
    }
)

(define-map subscriber-engagement
    { artist: principal, subscriber: principal }
    {
        total-claims: uint,
        total-amount-claimed: uint,
        first-claim-height: uint,
        last-claim-height: uint,
        avg-claim-time: uint,
        loyalty-score: uint
    }
)

(define-map monthly-revenue
    { artist: principal, month: uint, year: uint }
    {
        total-revenue: uint,
        distribution-count: uint,
        unique-subscribers: uint,
        growth-percentage: uint
    }
)

(define-public (record-distribution-created (artist principal) (distribution-id uint) (amount uint) (subscribers-count uint))
    (let (
        (current-metrics (default-to 
            { total-revenue: u0, total-distributions: u0, total-subscribers: u0, avg-distribution-amount: u0, highest-distribution: u0, last-distribution-height: u0, subscriber-growth-rate: u0 }
            (map-get? artist-metrics artist)))
        (new-total-revenue (+ (get total-revenue current-metrics) amount))
        (new-distribution-count (+ (get total-distributions current-metrics) u1))
        (new-avg-amount (/ new-total-revenue new-distribution-count))
        (new-highest (if (> amount (get highest-distribution current-metrics)) amount (get highest-distribution current-metrics)))
        (growth-rate (if (> (get total-subscribers current-metrics) u0) 
            (/ (* (- subscribers-count (get total-subscribers current-metrics)) u100) (get total-subscribers current-metrics))
            u0))
    )
        (begin
            (asserts! (is-eq tx-sender artist) ERR-NOT-AUTHORIZED)
            (map-set artist-metrics artist
                {
                    total-revenue: new-total-revenue,
                    total-distributions: new-distribution-count,
                    total-subscribers: subscribers-count,
                    avg-distribution-amount: new-avg-amount,
                    highest-distribution: new-highest,
                    last-distribution-height: stacks-block-height,
                    subscriber-growth-rate: growth-rate
                }
            )
            (map-set distribution-analytics { artist: artist, distribution-id: distribution-id }
                {
                    claim-rate: u0,
                    claim-speed: u0,
                    subscriber-count: subscribers-count,
                    total-amount: amount,
                    completion-height: u0,
                    is-completed: false
                }
            )
            (ok true)
        )
    )
)

(define-public (record-subscriber-claim (artist principal) (distribution-id uint) (subscriber principal) (amount uint))
    (let (
        (analytics (unwrap! (map-get? distribution-analytics { artist: artist, distribution-id: distribution-id }) ERR-NO-DATA))
        (current-engagement (default-to 
            { total-claims: u0, total-amount-claimed: u0, first-claim-height: u0, last-claim-height: u0, avg-claim-time: u0, loyalty-score: u0 }
            (map-get? subscriber-engagement { artist: artist, subscriber: subscriber })))
        (new-claim-count (+ (get total-claims current-engagement) u1))
        (new-total-claimed (+ (get total-amount-claimed current-engagement) amount))
        (first-height (if (is-eq (get first-claim-height current-engagement) u0) stacks-block-height (get first-claim-height current-engagement)))
        (avg-time (if (> new-claim-count u1) (/ (- stacks-block-height first-height) (- new-claim-count u1)) u0))
        (loyalty-score (+ (get loyalty-score current-engagement) u10))
    )
        (begin
            (asserts! (is-eq tx-sender subscriber) ERR-NOT-AUTHORIZED)
            (map-set subscriber-engagement { artist: artist, subscriber: subscriber }
                {
                    total-claims: new-claim-count,
                    total-amount-claimed: new-total-claimed,
                    first-claim-height: first-height,
                    last-claim-height: stacks-block-height,
                    avg-claim-time: avg-time,
                    loyalty-score: loyalty-score
                }
            )
            (ok true)
        )
    )
)

(define-public (update-monthly-revenue (artist principal) (month uint) (year uint))
    (let (
        (current-month (default-to 
            { total-revenue: u0, distribution-count: u0, unique-subscribers: u0, growth-percentage: u0 }
            (map-get? monthly-revenue { artist: artist, month: month, year: year })))
        (artist-data (unwrap! (map-get? artist-metrics artist) ERR-NO-DATA))
    )
        (begin
            (asserts! (is-eq tx-sender artist) ERR-NOT-AUTHORIZED)
            (asserts! (and (> month u0) (<= month u12)) ERR-INVALID-PERIOD)
            (asserts! (> year u2020) ERR-INVALID-PERIOD)
            (map-set monthly-revenue { artist: artist, month: month, year: year }
                {
                    total-revenue: (get total-revenue artist-data),
                    distribution-count: (get total-distributions artist-data),
                    unique-subscribers: (get total-subscribers artist-data),
                    growth-percentage: (get subscriber-growth-rate artist-data)
                }
            )
            (ok true)
        )
    )
)

(define-public (calculate-performance-score (artist principal))
    (let (
        (metrics (unwrap! (map-get? artist-metrics artist) ERR-NO-DATA))
        (revenue-score (/ (get total-revenue metrics) u1000))
        (distribution-score (* (get total-distributions metrics) u5))
        (subscriber-score (/ (get total-subscribers metrics) u10))
        (growth-score (get subscriber-growth-rate metrics))
        (consistency-score (if (> (get avg-distribution-amount metrics) u0) u20 u0))
    )
        (ok (+ revenue-score distribution-score subscriber-score growth-score consistency-score))
    )
)

(define-read-only (get-artist-analytics (artist principal))
    (map-get? artist-metrics artist)
)

(define-read-only (get-distribution-analytics (artist principal) (distribution-id uint))
    (map-get? distribution-analytics { artist: artist, distribution-id: distribution-id })
)

(define-read-only (get-subscriber-engagement-stats (artist principal) (subscriber principal))
    (map-get? subscriber-engagement { artist: artist, subscriber: subscriber })
)

(define-read-only (get-monthly-revenue-data (artist principal) (month uint) (year uint))
    (map-get? monthly-revenue { artist: artist, month: month, year: year })
)


(define-private (get-subscriber-loyalty-score (subscriber principal))
    (let (
        (engagement-data (map-get? subscriber-engagement { artist: tx-sender, subscriber: subscriber }))
    )
        (match engagement-data
            some-data (get loyalty-score some-data)
            u0
        )
    )
)

(define-read-only (calculate-revenue-trend (artist principal) (months uint))
    (let (
        (maybe-metrics (map-get? artist-metrics artist))
    )
        (match maybe-metrics
            metrics
                (let (
                    (avg-monthly-revenue (/ (get total-revenue metrics) months))
                    (trend-multiplier (if (> (get subscriber-growth-rate metrics) u0) u110 u90))
                )
                    (/ (* avg-monthly-revenue trend-multiplier) u100)
                )
            u0
        )
    )
)

(define-read-only (get-distribution-completion-rate (artist principal) (distribution-id uint))
    (let (
        (maybe-analytics (map-get? distribution-analytics { artist: artist, distribution-id: distribution-id }))
    )
        (match maybe-analytics
            analytics (ok (/ (* (get claim-rate analytics) u100) (get subscriber-count analytics)))
            (ok u0)
        )
    )
)
