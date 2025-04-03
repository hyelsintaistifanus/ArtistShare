
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
