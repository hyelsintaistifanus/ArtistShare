;; Concert Ticketing & Revenue Sharing
;; Allows artists to create virtual concerts, sell tickets, and share revenue with subscribers

(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-AMOUNT (err u401))
(define-constant ERR-EVENT-NOT-FOUND (err u402))
(define-constant ERR-SOLD-OUT (err u403))
(define-constant ERR-EVENT-ENDED (err u404))
(define-constant ERR-TICKET-NOT-FOUND (err u405))
(define-constant ERR-ALREADY-CLAIMED (err u406))
(define-constant ERR-INVALID-DATE (err u407))
(define-constant ERR-INSUFFICIENT-FUNDS (err u408))

;; Concert events created by artists
(define-map concert-events
    uint
    {
        artist: principal,
        title: (string-ascii 100),
        description: (string-utf8 300),
        event-date: uint,
        ticket-price: uint,
        max-tickets: uint,
        sold-tickets: uint,
        revenue-share-percent: uint,
        stream-url: (optional (string-ascii 200)),
        is-active: bool,
        created-at: uint
    }
)

;; Ticket purchases by fans
(define-map concert-tickets
    { event-id: uint, ticket-id: uint }
    {
        purchaser: principal,
        purchase-price: uint,
        purchase-time: uint,
        is-used: bool,
        seat-number: uint
    }
)

;; Revenue sharing for subscribers
(define-map subscriber-revenue-shares
    { event-id: uint, subscriber: principal }
    {
        share-amount: uint,
        claimed: bool,
        claim-height: uint
    }
)

;; Event statistics and analytics
(define-map event-analytics
    uint
    {
        total-revenue: uint,
        tickets-sold: uint,
        revenue-shared: uint,
        subscribers-paid: uint,
        avg-ticket-price: uint,
        event-completion: bool
    }
)

;; Artist event history
(define-map artist-event-history
    { artist: principal, event-index: uint }
    { event-id: uint }
)

(define-map artist-event-count
    principal
    { count: uint }
)

(define-data-var next-event-id uint u1)
(define-data-var next-ticket-id uint u1)

;; Create a new concert event
(define-public (create-concert-event 
    (title (string-ascii 100)) 
    (description (string-utf8 300)) 
    (event-date uint) 
    (ticket-price uint) 
    (max-tickets uint) 
    (revenue-share-percent uint))
    (let (
        (event-id (var-get next-event-id))
        (artist-count (default-to u0 (get count (map-get? artist-event-count tx-sender))))
    )
        (asserts! (> ticket-price u0) ERR-INVALID-AMOUNT)
        (asserts! (> max-tickets u0) ERR-INVALID-AMOUNT)
        (asserts! (> event-date stacks-block-height) ERR-INVALID-DATE)
        (asserts! (<= revenue-share-percent u50) ERR-INVALID-AMOUNT)
        
        (map-set concert-events event-id {
            artist: tx-sender,
            title: title,
            description: description,
            event-date: event-date,
            ticket-price: ticket-price,
            max-tickets: max-tickets,
            sold-tickets: u0,
            revenue-share-percent: revenue-share-percent,
            stream-url: none,
            is-active: true,
            created-at: stacks-block-height
        })
        
        (map-set artist-event-history 
            { artist: tx-sender, event-index: artist-count }
            { event-id: event-id }
        )
        
        (map-set artist-event-count tx-sender { count: (+ artist-count u1) })
        
        (map-set event-analytics event-id {
            total-revenue: u0,
            tickets-sold: u0,
            revenue-shared: u0,
            subscribers-paid: u0,
            avg-ticket-price: ticket-price,
            event-completion: false
        })
        
        (var-set next-event-id (+ event-id u1))
        (ok event-id)
    )
)

;; Purchase concert ticket
(define-public (purchase-ticket (event-id uint))
    (let (
        (event (unwrap! (map-get? concert-events event-id) ERR-EVENT-NOT-FOUND))
        (ticket-id (var-get next-ticket-id))
        (analytics (unwrap! (map-get? event-analytics event-id) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (get is-active event) ERR-EVENT-ENDED)
        (asserts! (< (get sold-tickets event) (get max-tickets event)) ERR-SOLD-OUT)
        (asserts! (>= (stx-get-balance tx-sender) (get ticket-price event)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Transfer payment to artist
        (try! (stx-transfer? (get ticket-price event) tx-sender (get artist event)))
        
        ;; Record ticket purchase
        (map-set concert-tickets 
            { event-id: event-id, ticket-id: ticket-id }
            {
                purchaser: tx-sender,
                purchase-price: (get ticket-price event),
                purchase-time: stacks-block-height,
                is-used: false,
                seat-number: (+ (get sold-tickets event) u1)
            }
        )
        
        ;; Update event stats
        (map-set concert-events event-id 
            (merge event { sold-tickets: (+ (get sold-tickets event) u1) })
        )
        
        (map-set event-analytics event-id
            (merge analytics {
                total-revenue: (+ (get total-revenue analytics) (get ticket-price event)),
                tickets-sold: (+ (get tickets-sold analytics) u1)
            })
        )
        
        (var-set next-ticket-id (+ ticket-id u1))
        (ok ticket-id)
    )
)

;; Distribute revenue to subscribers after event
(define-public (distribute-event-revenue (event-id uint) (subscribers (list 20 principal)))
    (let (
        (event (unwrap! (map-get? concert-events event-id) ERR-EVENT-NOT-FOUND))
        (analytics (unwrap! (map-get? event-analytics event-id) ERR-EVENT-NOT-FOUND))
        (total-revenue (get total-revenue analytics))
        (share-pool (/ (* total-revenue (get revenue-share-percent event)) u100))
        (per-subscriber-share (/ share-pool (len subscribers)))
    )
        (asserts! (is-eq tx-sender (get artist event)) ERR-NOT-AUTHORIZED)
        (asserts! (> stacks-block-height (get event-date event)) ERR-EVENT-ENDED)
        (asserts! (> share-pool u0) ERR-INVALID-AMOUNT)
        
        (map register-subscriber-share subscribers)
        
        (map-set event-analytics event-id
            (merge analytics {
                revenue-shared: share-pool,
                subscribers-paid: (len subscribers),
                event-completion: true
            })
        )
        
        (ok true)
    )
)

;; Helper function to register revenue share for individual subscriber
(define-private (register-subscriber-share (subscriber principal))
    (let (
        (current-event-id (- (var-get next-event-id) u1))
        (event (unwrap-panic (map-get? concert-events current-event-id)))
        (analytics (unwrap-panic (map-get? event-analytics current-event-id)))
        (share-pool (/ (* (get total-revenue analytics) (get revenue-share-percent event)) u100))
        (per-subscriber-share (/ share-pool u20)) ;; Assuming max 20 subscribers for simplicity
    )
        (map-set subscriber-revenue-shares 
            { event-id: current-event-id, subscriber: subscriber }
            {
                share-amount: per-subscriber-share,
                claimed: false,
                claim-height: u0
            }
        )
    )
)

;; Claim revenue share as subscriber
(define-public (claim-revenue-share (event-id uint))
    (let (
        (share (unwrap! (map-get? subscriber-revenue-shares { event-id: event-id, subscriber: tx-sender }) ERR-TICKET-NOT-FOUND))
        (event (unwrap! (map-get? concert-events event-id) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (not (get claimed share)) ERR-ALREADY-CLAIMED)
        (asserts! (> (get share-amount share) u0) ERR-INVALID-AMOUNT)
        
        ;; Transfer revenue share from artist to subscriber
        (try! (as-contract (stx-transfer? (get share-amount share) (get artist event) tx-sender)))
        
        (map-set subscriber-revenue-shares 
            { event-id: event-id, subscriber: tx-sender }
            (merge share { claimed: true, claim-height: stacks-block-height })
        )
        
        (ok (get share-amount share))
    )
)

;; Use ticket to attend event
(define-public (use-ticket (event-id uint) (ticket-id uint))
    (let (
        (ticket (unwrap! (map-get? concert-tickets { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
        (event (unwrap! (map-get? concert-events event-id) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (get purchaser ticket)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-used ticket)) ERR-ALREADY-CLAIMED)
        (asserts! (>= stacks-block-height (get event-date event)) ERR-EVENT-ENDED)
        
        (map-set concert-tickets 
            { event-id: event-id, ticket-id: ticket-id }
            (merge ticket { is-used: true })
        )
        
        (ok true)
    )
)

;; Update stream URL for virtual concert
(define-public (update-stream-url (event-id uint) (stream-url (string-ascii 200)))
    (let (
        (event (unwrap! (map-get? concert-events event-id) ERR-EVENT-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender (get artist event)) ERR-NOT-AUTHORIZED)
        
        (map-set concert-events event-id
            (merge event { stream-url: (some stream-url) })
        )
        
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-concert-event (event-id uint))
    (map-get? concert-events event-id)
)

(define-read-only (get-ticket-details (event-id uint) (ticket-id uint))
    (map-get? concert-tickets { event-id: event-id, ticket-id: ticket-id })
)

(define-read-only (get-event-analytics (event-id uint))
    (map-get? event-analytics event-id)
)

(define-read-only (get-subscriber-revenue-share (event-id uint) (subscriber principal))
    (map-get? subscriber-revenue-shares { event-id: event-id, subscriber: subscriber })
)

(define-read-only (get-artist-event-count (artist principal))
    (default-to u0 (get count (map-get? artist-event-count artist)))
)

(define-read-only (get-artist-event-by-index (artist principal) (index uint))
    (match (map-get? artist-event-history { artist: artist, event-index: index })
        event-entry (get-concert-event (get event-id event-entry))
        none
    )
)
