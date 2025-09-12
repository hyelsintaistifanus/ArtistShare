
;; summary: Musicians lock tokens to distribute royalties to subscribers
;; description: A platform for artists to share royalties with their fans

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-NO-SUBSCRIPTION (err u102))

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


;; Data map for collaborations
(define-map collaborations
    { collab-id: uint, artist1: principal, artist2: principal }
    { active: bool, revenue-split: uint, created-at: uint }
)

(define-data-var next-collab-id uint u1)

(define-public (create-collaboration (collaborator principal) (split uint))
    (let (
        (current-id (var-get next-collab-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (asserts! (is-some (map-get? artist-profiles collaborator)) ERR-NOT-AUTHORIZED)
            (var-set next-collab-id (+ current-id u1))
            (ok (map-set collaborations 
                { collab-id: current-id, artist1: tx-sender, artist2: collaborator }
                { active: true, revenue-split: split, created-at: stacks-block-height }
            ))
        )
    )
)

(define-public (get-collaboration-revenue (collab-id uint))
    (let (
        (collab-data (unwrap! (map-get? collaborations { collab-id: collab-id, artist1: tx-sender, artist2: tx-sender }) ERR-NOT-AUTHORIZED))
    )
        (ok (get revenue-split collab-data))
    )
)
(define-public (get-collaboration-status (collab-id uint))
    (let (
        (collab-data (unwrap! (map-get? collaborations { collab-id: collab-id, artist1: tx-sender, artist2: tx-sender }) ERR-NOT-AUTHORIZED))
    )
        (ok (get active collab-data))
    )
)


(define-public (get-collaboration-creation-date (collab-id uint))
    (let (
        (collab-data (unwrap! (map-get? collaborations { collab-id: collab-id, artist1: tx-sender, artist2: tx-sender }) ERR-NOT-AUTHORIZED))
    )
        (ok (get created-at collab-data))
    )
)
(define-public (get-collaboration-revenue-split (collab-id uint))
    (let (
        (collab-data (unwrap! (map-get? collaborations { collab-id: collab-id, artist1: tx-sender, artist2: tx-sender }) ERR-NOT-AUTHORIZED))
    )
        (ok (get revenue-split collab-data))
    )
)
(define-public (get-collaboration-active-status (collab-id uint))
    (let (
        (collab-data (unwrap! (map-get? collaborations { collab-id: collab-id, artist1: tx-sender, artist2: tx-sender }) ERR-NOT-AUTHORIZED))
    )
        (ok (get active collab-data))
    )
)


(define-map nft-drops
    uint
    { artist: principal, total-supply: uint, price: uint, remaining: uint }
)

(define-data-var next-drop-id uint u1)

(define-public (create-nft-drop (total-supply uint) (price uint))
    (let (
        (drop-id (var-get next-drop-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (var-set next-drop-id (+ drop-id u1))
            (ok (map-set nft-drops drop-id
                { artist: tx-sender, 
                  total-supply: total-supply, 
                  price: price, 
                  remaining: total-supply }
            ))
        )
    )
)


(define-map challenges
    uint
    { artist: principal, 
      description: (string-ascii 256), 
      reward: uint,
      end-block: uint,
      winner: (optional principal) }
)

(define-data-var next-challenge-id uint u1)

(define-public (create-challenge (description (string-ascii 256)) (reward uint) (duration uint))
    (let (
        (challenge-id (var-get next-challenge-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (var-set next-challenge-id (+ challenge-id u1))
            (ok (map-set challenges challenge-id
                { artist: tx-sender,
                  description: description,
                  reward: reward,
                  end-block: (+ stacks-block-height duration),
                  winner: none }
            ))
        )
    )
)


(define-map merchandise
    { item-id: uint, artist: principal }
    { name: (string-ascii 64),
      price: uint,
      stock: uint }
)

(define-data-var next-item-id uint u1)

(define-public (list-merchandise (name (string-ascii 64)) (price uint) (stock uint))
    (let (
        (item-id (var-get next-item-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (var-set next-item-id (+ item-id u1))
            (ok (map-set merchandise 
                { item-id: item-id, artist: tx-sender }
                { name: name, price: price, stock: stock }
            ))
        )
    )
)
(define-public (purchase-merchandise (item-id uint) (quantity uint))
    (let (
        (merch-data (unwrap! (map-get? merchandise { item-id: item-id, artist: tx-sender }) ERR-NOT-AUTHORIZED))
    )
        (begin
            (asserts! (> quantity u0) ERR-INVALID-AMOUNT)
            (asserts! (> (get stock merch-data) quantity) ERR-INVALID-AMOUNT)
            (map-set merchandise 
                { item-id: item-id, artist: tx-sender }
                { name: (get name merch-data), 
                  price: (get price merch-data), 
                  stock: (- (get stock merch-data) quantity) }
            )
            (ok true)
        )
    )
)


(define-map polls
    uint
    { artist: principal,
      question: (string-ascii 256),
      options: (list 4 (string-ascii 64)),
      votes: (list 4 uint),
      end-block: uint }
)

(define-data-var next-poll-id uint u1)

(define-public (create-poll (question (string-ascii 256)) (options (list 4 (string-ascii 64))) (duration uint))
    (let (
        (poll-id (var-get next-poll-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (var-set next-poll-id (+ poll-id u1))
            (ok (map-set polls poll-id
                { artist: tx-sender,
                  question: question,
                  options: options,
                  votes: (list u0 u0 u0 u0),
                  end-block: (+ stacks-block-height duration) }
            ))
        )
    )
)


(define-map milestones
    { artist: principal, milestone-id: uint }
    { target: uint,
      reward: uint,
      achieved: bool }
)

(define-public (set-milestone (target uint) (reward uint))
    (let (
        (artist-data (unwrap! (map-get? artist-profiles tx-sender) ERR-NOT-AUTHORIZED))
        (milestone-id (get subscriber-count artist-data))
    )
        (ok (map-set milestones 
            { artist: tx-sender, milestone-id: milestone-id }
            { target: target, reward: reward, achieved: false }
        ))
    )
)


(define-map referrals
    { referrer: principal, artist: principal }
    { count: uint, rewards-earned: uint }
)

(define-public (refer-fan (new-fan principal))
    (let (
        (current-referrals (default-to { count: u0, rewards-earned: u0 } 
            (map-get? referrals { referrer: tx-sender, artist: new-fan })))
    )
        (ok (map-set referrals 
            { referrer: tx-sender, artist: new-fan }
            { count: (+ (get count current-referrals) u1),
              rewards-earned: (get rewards-earned current-referrals) }
        ))
    )
)


(define-map subscription-bundles
    uint
    { artists: (list 5 principal),
      price: uint,
      duration: uint }
)

(define-data-var next-bundle-id uint u1)

(define-public (create-bundle (artists (list 5 principal)) (price uint) (duration uint))
    (let (
        (bundle-id (var-get next-bundle-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (var-set next-bundle-id (+ bundle-id u1))
            (ok (map-set subscription-bundles bundle-id
                { artists: artists,
                  price: price,
                  duration: duration }
            ))
        )
    )
)



(define-map revenue-pools
    uint
    {
        pool-name: (string-ascii 64),
        contributors: (list 10 principal),
        shares: (list 10 uint),
        total-revenue: uint,
        active: bool
    }
)

(define-data-var next-pool-id uint u1)

(define-public (create-revenue-pool (pool-name (string-ascii 64)) (contributors (list 10 principal)) (shares (list 10 uint)))
    (let (
        (pool-id (var-get next-pool-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (var-set next-pool-id (+ pool-id u1))
            (ok (map-set revenue-pools pool-id
                {
                    pool-name: pool-name,
                    contributors: contributors,
                    shares: shares,
                    total-revenue: u0,
                    active: true
                }
            ))
        )
    )
)

(define-public (add-revenue-to-pool (pool-id uint) (amount uint))
    (let (
        (pool (unwrap! (map-get? revenue-pools pool-id) ERR-NOT-AUTHORIZED))
    )
        (begin
            (asserts! (get active pool) ERR-NOT-AUTHORIZED)
            (ok (map-set revenue-pools pool-id
                (merge pool { total-revenue: (+ (get total-revenue pool) amount) })
            ))
        )
    )
)


(define-map time-locked-rewards
    uint
    {
        artist: principal,
        reward-amount: uint,
        unlock-height: uint,
        claimed: bool,
        recipient: principal
    }
)

(define-data-var next-reward-id uint u1)

(define-public (create-time-locked-reward (recipient principal) (amount uint) (lock-period uint))
    (let (
        (reward-id (var-get next-reward-id))
    )
        (begin
            (asserts! (is-some (map-get? artist-profiles tx-sender)) ERR-NOT-AUTHORIZED)
            (var-set next-reward-id (+ reward-id u1))
            (ok (map-set time-locked-rewards reward-id
                {
                    artist: tx-sender,
                    reward-amount: amount,
                    unlock-height: (+ stacks-block-height lock-period),
                    claimed: false,
                    recipient: recipient
                }
            ))
        )
    )
)

(define-public (claim-time-locked-reward (reward-id uint))
    (let (
        (reward (unwrap! (map-get? time-locked-rewards reward-id) ERR-NOT-AUTHORIZED))
    )
        (begin
            (asserts! (is-eq tx-sender (get recipient reward)) ERR-NOT-AUTHORIZED)
            (asserts! (>= stacks-block-height (get unlock-height reward)) ERR-NOT-AUTHORIZED)
            (asserts! (not (get claimed reward)) ERR-NOT-AUTHORIZED)
            (ok (map-set time-locked-rewards reward-id
                (merge reward { claimed: true })
            ))
        )
    )
)


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

;; =======================
;; MUSIC GENRE TRENDING SYSTEM
;; =======================
;; Simple feature to track trending music genres based on artist activity and fan engagement

;; Music genre definitions and trending data
(define-map music-genres
    uint
    {
        name: (string-ascii 30),
        description: (string-ascii 100),
        trend-score: uint,
        artist-count: uint,
        fan-count: uint,
        last-activity: uint,
        weekly-growth: uint
    }
)

;; Artist genre associations
(define-map artist-genres
    { artist: principal, genre-id: uint }
    {
        primary: bool,
        activity-score: uint,
        last-update: uint
    }
)

;; Fan genre preferences
(define-map fan-genre-preferences
    { fan: principal, genre-id: uint }
    {
        engagement-level: uint,
        last-interaction: uint,
        preference-strength: uint
    }
)

;; Weekly trending genres leaderboard
(define-map weekly-trending
    { week: uint, year: uint, rank: uint }
    {
        genre-id: uint,
        trend-score: uint,
        growth-percentage: uint
    }
)

(define-data-var next-genre-id uint u1)
(define-data-var current-week uint u1)
(define-data-var current-year uint u2024)

;; Register a new music genre
(define-public (register-music-genre (name (string-ascii 30)) (description (string-ascii 100)))
    (let (
        (genre-id (var-get next-genre-id))
    )
        (begin
            (map-set music-genres genre-id
                {
                    name: name,
                    description: description,
                    trend-score: u0,
                    artist-count: u0,
                    fan-count: u0,
                    last-activity: stacks-block-height,
                    weekly-growth: u0
                }
            )
            (var-set next-genre-id (+ genre-id u1))
            (ok genre-id)
        )
    )
)

;; Artist associates with a genre
(define-public (set-artist-genre (genre-id uint) (is-primary bool))
    (let (
        (genre (unwrap! (map-get? music-genres genre-id) ERR-NOT-AUTHORIZED))
        (artist-profile (unwrap! (map-get? artist-profiles tx-sender) ERR-NOT-AUTHORIZED))
    )
        (begin
            (map-set artist-genres { artist: tx-sender, genre-id: genre-id }
                {
                    primary: is-primary,
                    activity-score: u10,
                    last-update: stacks-block-height
                }
            )
            (map-set music-genres genre-id
                (merge genre {
                    artist-count: (+ (get artist-count genre) u1),
                    trend-score: (+ (get trend-score genre) u10),
                    last-activity: stacks-block-height
                })
            )
            (ok true)
        )
    )
)

;; Fan shows interest in a genre
(define-public (set-fan-genre-preference (genre-id uint) (engagement-level uint))
    (let (
        (genre (unwrap! (map-get? music-genres genre-id) ERR-NOT-AUTHORIZED))
        (existing-pref (map-get? fan-genre-preferences { fan: tx-sender, genre-id: genre-id }))
    )
        (begin
            (asserts! (and (> engagement-level u0) (<= engagement-level u10)) ERR-INVALID-AMOUNT)
            (map-set fan-genre-preferences { fan: tx-sender, genre-id: genre-id }
                {
                    engagement-level: engagement-level,
                    last-interaction: stacks-block-height,
                    preference-strength: (if (is-some existing-pref) 
                        (+ (get preference-strength (unwrap-panic existing-pref)) u1) u1)
                }
            )
            (if (is-none existing-pref)
                (map-set music-genres genre-id
                    (merge genre {
                        fan-count: (+ (get fan-count genre) u1),
                        trend-score: (+ (get trend-score genre) engagement-level),
                        last-activity: stacks-block-height
                    })
                )
                (map-set music-genres genre-id
                    (merge genre {
                        trend-score: (+ (get trend-score genre) engagement-level),
                        last-activity: stacks-block-height
                    })
                )
            )
            (ok true)
        )
    )
)

;; Update weekly trending based on current scores
(define-public (update-weekly-trending (week uint) (year uint))
    (begin
        (asserts! (and (> week u0) (<= week u52)) ERR-INVALID-AMOUNT)
        (asserts! (> year u2020) ERR-INVALID-AMOUNT)
        (var-set current-week week)
        (var-set current-year year)
        ;; In a real implementation, this would calculate top genres and update rankings
        ;; For simplicity, we'll just allow manual updates here
        (ok true)
    )
)

;; Set a genre's ranking for the week
(define-public (set-genre-weekly-rank (genre-id uint) (rank uint) (growth-percentage uint))
    (let (
        (genre (unwrap! (map-get? music-genres genre-id) ERR-NOT-AUTHORIZED))
        (week (var-get current-week))
        (year (var-get current-year))
    )
        (begin
            (asserts! (and (> rank u0) (<= rank u10)) ERR-INVALID-AMOUNT)
            (map-set weekly-trending { week: week, year: year, rank: rank }
                {
                    genre-id: genre-id,
                    trend-score: (get trend-score genre),
                    growth-percentage: growth-percentage
                }
            )
            (ok true)
        )
    )
)

;; Read-only functions for the trending system
(define-read-only (get-music-genre (genre-id uint))
    (map-get? music-genres genre-id)
)

(define-read-only (get-artist-genre-info (artist principal) (genre-id uint))
    (map-get? artist-genres { artist: artist, genre-id: genre-id })
)

(define-read-only (get-fan-genre-preference (fan principal) (genre-id uint))
    (map-get? fan-genre-preferences { fan: fan, genre-id: genre-id })
)

(define-read-only (get-weekly-trending-genre (week uint) (year uint) (rank uint))
    (map-get? weekly-trending { week: week, year: year, rank: rank })
)

(define-read-only (get-top-trending-genres (week uint) (year uint))
    (let (
        (rank-1 (map-get? weekly-trending { week: week, year: year, rank: u1 }))
        (rank-2 (map-get? weekly-trending { week: week, year: year, rank: u2 }))
        (rank-3 (map-get? weekly-trending { week: week, year: year, rank: u3 }))
    )
        { rank-1: rank-1, rank-2: rank-2, rank-3: rank-3 }
    )
)
