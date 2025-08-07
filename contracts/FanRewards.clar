;; Fan Engagement & Rewards System
;; Gamifies fan interactions with points, achievements, and exclusive perks

(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-AMOUNT (err u301))
(define-constant ERR-ACHIEVEMENT-NOT-FOUND (err u302))
(define-constant ERR-INSUFFICIENT-POINTS (err u303))
(define-constant ERR-REWARD-ALREADY-CLAIMED (err u304))
(define-constant ERR-INVALID-ACTION (err u305))
(define-constant ERR-STREAK-BROKEN (err u306))

;; Fan profile with engagement metrics and rewards
(define-map fan-profiles
    principal
    {
        total-points: uint,
        level: uint,
        current-streak: uint,
        longest-streak: uint,
        last-activity-height: uint,
        achievements-unlocked: uint,
        referrals-made: uint,
        early-claims: uint,
        social-shares: uint
    }
)

;; Achievement definitions and requirements
(define-map achievements
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 100),
        points-required: uint,
        activity-type: (string-ascii 20),
        threshold: uint,
        reward-points: uint,
        is-active: bool
    }
)

;; Fan achievement progress tracking
(define-map fan-achievements
    { fan: principal, achievement-id: uint }
    {
        progress: uint,
        completed: bool,
        completion-height: uint,
        reward-claimed: bool
    }
)

;; Exclusive perks that fans can unlock
(define-map exclusive-perks
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 100),
        points-cost: uint,
        level-required: uint,
        max-claims: uint,
        current-claims: uint,
        is-active: bool
    }
)

;; Fan perk claims tracking
(define-map fan-perk-claims
    { fan: principal, perk-id: uint }
    {
        claim-count: uint,
        last-claim-height: uint,
        total-points-spent: uint
    }
)

;; Daily challenge system
(define-map daily-challenges
    uint
    {
        challenge-date: uint,
        action-required: (string-ascii 30),
        points-reward: uint,
        participant-count: uint,
        completion-threshold: uint,
        is-active: bool
    }
)

;; Fan participation in daily challenges
(define-map challenge-participation
    { fan: principal, challenge-id: uint }
    {
        completed: bool,
        completion-height: uint,
        points-earned: uint
    }
)

;; Leaderboard system for top fans
(define-map monthly-leaderboard
    { month: uint, year: uint, rank: uint }
    {
        fan: principal,
        points-earned: uint,
        activities-completed: uint,
        streak-maintained: uint
    }
)

(define-data-var next-achievement-id uint u1)
(define-data-var next-perk-id uint u1)
(define-data-var next-challenge-id uint u1)

;; Initialize fan profile or update existing one
(define-public (update-fan-activity (fan principal) (action (string-ascii 20)) (points-earned uint))
    (let (
        (current-profile (default-to 
            { total-points: u0, level: u1, current-streak: u0, longest-streak: u0, last-activity-height: u0, achievements-unlocked: u0, referrals-made: u0, early-claims: u0, social-shares: u0 }
            (map-get? fan-profiles fan)))
        (new-total-points (+ (get total-points current-profile) points-earned))
        (new-level (calculate-level new-total-points))
        (streak-bonus (calculate-streak-bonus fan (get current-streak current-profile)))
        (action-count (get-action-count current-profile action))
    )
        (begin
            ;; Update fan profile with new activity
            (map-set fan-profiles fan
                {
                    total-points: (+ new-total-points streak-bonus),
                    level: new-level,
                    current-streak: (update-streak fan),
                    longest-streak: (if (> (update-streak fan) (get longest-streak current-profile)) (update-streak fan) (get longest-streak current-profile)),
                    last-activity-height: stacks-block-height,
                    achievements-unlocked: (get achievements-unlocked current-profile),
                    referrals-made: (if (is-eq action "referral") (+ (get referrals-made current-profile) u1) (get referrals-made current-profile)),
                    early-claims: (if (is-eq action "early_claim") (+ (get early-claims current-profile) u1) (get early-claims current-profile)),
                    social-shares: (if (is-eq action "social_share") (+ (get social-shares current-profile) u1) (get social-shares current-profile))
                }
            )
            ;; Check for achievement progress
            (check-achievement-progress fan action)
            (ok true)
        )
    )
)

;; Create new achievement for fans to unlock
(define-public (create-achievement (name (string-ascii 50)) (description (string-ascii 100)) (points-required uint) (activity-type (string-ascii 20)) (threshold uint) (reward-points uint))
    (let (
        (achievement-id (var-get next-achievement-id))
    )
        (begin
            (map-set achievements achievement-id
                {
                    name: name,
                    description: description,
                    points-required: points-required,
                    activity-type: activity-type,
                    threshold: threshold,
                    reward-points: reward-points,
                    is-active: true
                }
            )
            (var-set next-achievement-id (+ achievement-id u1))
            (ok achievement-id)
        )
    )
)

;; Create exclusive perk that fans can unlock with points
(define-public (create-exclusive-perk (name (string-ascii 50)) (description (string-ascii 100)) (points-cost uint) (level-required uint) (max-claims uint))
    (let (
        (perk-id (var-get next-perk-id))
    )
        (begin
            (map-set exclusive-perks perk-id
                {
                    name: name,
                    description: description,
                    points-cost: points-cost,
                    level-required: level-required,
                    max-claims: max-claims,
                    current-claims: u0,
                    is-active: true
                }
            )
            (var-set next-perk-id (+ perk-id u1))
            (ok perk-id)
        )
    )
)

;; Fan claims an exclusive perk using points
(define-public (claim-exclusive-perk (perk-id uint))
    (let (
        (perk (unwrap! (map-get? exclusive-perks perk-id) ERR-ACHIEVEMENT-NOT-FOUND))
        (fan-profile (unwrap! (map-get? fan-profiles tx-sender) ERR-NOT-AUTHORIZED))
        (claim-data (default-to 
            { claim-count: u0, last-claim-height: u0, total-points-spent: u0 }
            (map-get? fan-perk-claims { fan: tx-sender, perk-id: perk-id })))
    )
        (begin
            ;; Validate perk claim eligibility
            (asserts! (get is-active perk) ERR-INVALID-ACTION)
            (asserts! (>= (get total-points fan-profile) (get points-cost perk)) ERR-INSUFFICIENT-POINTS)
            (asserts! (>= (get level fan-profile) (get level-required perk)) ERR-NOT-AUTHORIZED)
            (asserts! (< (get current-claims perk) (get max-claims perk)) ERR-REWARD-ALREADY-CLAIMED)
            
            ;; Deduct points and update records
            (map-set fan-profiles tx-sender
                (merge fan-profile { 
                    total-points: (- (get total-points fan-profile) (get points-cost perk))
                })
            )
            (map-set fan-perk-claims { fan: tx-sender, perk-id: perk-id }
                {
                    claim-count: (+ (get claim-count claim-data) u1),
                    last-claim-height: stacks-block-height,
                    total-points-spent: (+ (get total-points-spent claim-data) (get points-cost perk))
                }
            )
            (map-set exclusive-perks perk-id
                (merge perk { 
                    current-claims: (+ (get current-claims perk) u1)
                })
            )
            (ok true)
        )
    )
)

;; Create daily challenge for fan engagement
(define-public (create-daily-challenge (challenge-date uint) (action-required (string-ascii 30)) (points-reward uint) (completion-threshold uint))
    (let (
        (challenge-id (var-get next-challenge-id))
    )
        (begin
            (map-set daily-challenges challenge-id
                {
                    challenge-date: challenge-date,
                    action-required: action-required,
                    points-reward: points-reward,
                    participant-count: u0,
                    completion-threshold: completion-threshold,
                    is-active: true
                }
            )
            (var-set next-challenge-id (+ challenge-id u1))
            (ok challenge-id)
        )
    )
)

;; Fan completes daily challenge
(define-public (complete-daily-challenge (challenge-id uint))
    (let (
        (challenge (unwrap! (map-get? daily-challenges challenge-id) ERR-ACHIEVEMENT-NOT-FOUND))
        (participation (default-to 
            { completed: false, completion-height: u0, points-earned: u0 }
            (map-get? challenge-participation { fan: tx-sender, challenge-id: challenge-id })))
    )
        (begin
            (asserts! (get is-active challenge) ERR-INVALID-ACTION)
            (asserts! (not (get completed participation)) ERR-REWARD-ALREADY-CLAIMED)
            
            ;; Mark challenge as completed
            (map-set challenge-participation { fan: tx-sender, challenge-id: challenge-id }
                {
                    completed: true,
                    completion-height: stacks-block-height,
                    points-earned: (get points-reward challenge)
                }
            )
            (map-set daily-challenges challenge-id
                (merge challenge { 
                    participant-count: (+ (get participant-count challenge) u1)
                })
            )
            
            ;; Award points to fan
            (update-fan-activity tx-sender "challenge_complete" (get points-reward challenge))
        )
    )
)

;; Update monthly leaderboard with top performers
(define-public (update-leaderboard (month uint) (year uint) (rank uint) (fan principal) (points-earned uint) (activities-completed uint) (streak-maintained uint))
    (begin
        (asserts! (and (> month u0) (<= month u12)) ERR-INVALID-AMOUNT)
        (asserts! (> year u2020) ERR-INVALID-AMOUNT)
        (asserts! (and (> rank u0) (<= rank u10)) ERR-INVALID-AMOUNT)
        
        (map-set monthly-leaderboard { month: month, year: year, rank: rank }
            {
                fan: fan,
                points-earned: points-earned,
                activities-completed: activities-completed,
                streak-maintained: streak-maintained
            }
        )
        (ok true)
    )
)

;; Private helper functions
(define-private (calculate-level (total-points uint))
    (if (<= total-points u100) u1
        (if (<= total-points u500) u2
            (if (<= total-points u1000) u3
                (if (<= total-points u2500) u4
                    (if (<= total-points u5000) u5
                        u6)))))
)

(define-private (calculate-streak-bonus (fan principal) (current-streak uint))
    (if (> current-streak u5) u20
        (if (> current-streak u2) u10
            u0))
)

(define-private (update-streak (fan principal))
    (let (
        (profile (unwrap-panic (map-get? fan-profiles fan)))
        (last-height (get last-activity-height profile))
        (current-height stacks-block-height)
        (height-diff (- current-height last-height))
    )
        (if (<= height-diff u144) ;; Within 24 hours (assuming ~10 min blocks)
            (+ (get current-streak profile) u1)
            u1) ;; Reset streak if too much time passed
    )
)

(define-private (get-action-count (profile { total-points: uint, level: uint, current-streak: uint, longest-streak: uint, last-activity-height: uint, achievements-unlocked: uint, referrals-made: uint, early-claims: uint, social-shares: uint }) (action (string-ascii 20)))
    (if (is-eq action "referral") (get referrals-made profile)
        (if (is-eq action "early_claim") (get early-claims profile)
            (if (is-eq action "social_share") (get social-shares profile)
                u0)))
)

(define-private (check-achievement-progress (fan principal) (action (string-ascii 20)))
    (let (
        (achievement-ids (list u1 u2 u3 u4 u5))
    )
        (map check-single-achievement achievement-ids)
        true
    )
)

(define-private (check-single-achievement (achievement-id uint))
    (let (
        (achievement (map-get? achievements achievement-id))
        (fan-progress (map-get? fan-achievements { fan: tx-sender, achievement-id: achievement-id }))
    )
        (match achievement
            some-achievement 
                (if (get is-active some-achievement)
                    true
                    false)
            false)
    )
)

;; Read-only functions
(define-read-only (get-fan-profile (fan principal))
    (map-get? fan-profiles fan)
)

(define-read-only (get-achievement-details (achievement-id uint))
    (map-get? achievements achievement-id)
)

(define-read-only (get-fan-achievement-progress (fan principal) (achievement-id uint))
    (map-get? fan-achievements { fan: fan, achievement-id: achievement-id })
)

(define-read-only (get-exclusive-perk-details (perk-id uint))
    (map-get? exclusive-perks perk-id)
)

(define-read-only (get-fan-perk-claims (fan principal) (perk-id uint))
    (map-get? fan-perk-claims { fan: fan, perk-id: perk-id })
)

(define-read-only (get-daily-challenge (challenge-id uint))
    (map-get? daily-challenges challenge-id)
)

(define-read-only (get-challenge-participation (fan principal) (challenge-id uint))
    (map-get? challenge-participation { fan: fan, challenge-id: challenge-id })
)

(define-read-only (get-leaderboard-entry (month uint) (year uint) (rank uint))
    (map-get? monthly-leaderboard { month: month, year: year, rank: rank })
)

(define-read-only (calculate-fan-rank (fan principal))
    (let (
        (profile (unwrap! (map-get? fan-profiles fan) (err u0)))
        (total-points (get total-points profile))
        (level (get level profile))
        (streak (get current-streak profile))
    )
        (ok (+ (* level u1000) (* streak u100) total-points))
    )
)

