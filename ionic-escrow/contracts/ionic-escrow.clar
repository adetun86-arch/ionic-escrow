;; Ionic Escrow - DAO Governance Platform
;; Implements dynamic time-weighted ionic bonding for governance

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-proposal-expired (err u103))
(define-constant err-proposal-not-active (err u104))
(define-constant err-insufficient-bond (err u105))
(define-constant err-invalid-amount (err u106))

;; Data Variables
(define-data-var proposal-count uint u0)
(define-data-var min-bond-amount uint u1000)
(define-data-var base-voting-period uint u1440) ;; ~10 days in blocks

;; Data Maps
(define-map ionic-bonds
    principal
    {
        amount: uint,
        bond-start: uint,
        bond-strength: uint
    }
)

(define-map proposals
    uint
    {
        proposer: principal,
        title: (string-ascii 256),
        description: (string-ascii 1024),
        yes-votes: uint,
        no-votes: uint,
        start-block: uint,
        end-block: uint,
        executed: bool,
        passed: bool
    }
)

(define-map votes
    { proposal-id: uint, voter: principal }
    {
        vote-weight: uint,
        vote-choice: bool
    }
)

(define-map reputation-scores
    principal
    {
        score: uint,
        total-votes: uint,
        accurate-votes: uint
    }
)

;; Read-only functions

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-bond (account principal))
    (map-get? ionic-bonds account)
)

(define-read-only (get-reputation (account principal))
    (map-get? reputation-scores account)
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
    (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (calculate-voting-weight (account principal))
    (let
        (
            (bond-data (unwrap! (map-get? ionic-bonds account) u0))
            (bond-amount (get amount bond-data))
            (bond-duration (- block-height (get bond-start bond-data)))
            (reputation-data (default-to { score: u100, total-votes: u0, accurate-votes: u0 } 
                                         (map-get? reputation-scores account)))
            (reputation-multiplier (get score reputation-data))
        )
        ;; Weight = bond-amount * (1 + duration/1000) * (reputation/100)
        (/ (* (* bond-amount (+ u100 (/ bond-duration u10))) reputation-multiplier) u10000)
    )
)

(define-read-only (get-proposal-status (proposal-id uint))
    (let
        (
            (proposal-data (unwrap! (map-get? proposals proposal-id) (err err-not-found)))
        )
        (ok {
            active: (and 
                (>= block-height (get start-block proposal-data))
                (<= block-height (get end-block proposal-data))
                (not (get executed proposal-data))
            ),
            yes-votes: (get yes-votes proposal-data),
            no-votes: (get no-votes proposal-data),
            passed: (get passed proposal-data),
            executed: (get executed proposal-data)
        })
    )
)

;; Public functions

(define-public (create-bond (amount uint))
    (let
        (
            (existing-bond (map-get? ionic-bonds tx-sender))
        )
        (asserts! (>= amount (var-get min-bond-amount)) err-invalid-amount)
        (match existing-bond
            bond
            (begin
                (map-set ionic-bonds tx-sender
                    {
                        amount: (+ (get amount bond) amount),
                        bond-start: (get bond-start bond),
                        bond-strength: (+ (get bond-strength bond) u1)
                    }
                )
                (ok true)
            )
            (begin
                (map-set ionic-bonds tx-sender
                    {
                        amount: amount,
                        bond-start: block-height,
                        bond-strength: u1
                    }
                )
                (map-set reputation-scores tx-sender
                    {
                        score: u100,
                        total-votes: u0,
                        accurate-votes: u0
                    }
                )
                (ok true)
            )
        )
    )
)

(define-public (create-proposal (title (string-ascii 256)) (description (string-ascii 1024)))
    (let
        (
            (proposal-id (+ (var-get proposal-count) u1))
            (bond-data (unwrap! (map-get? ionic-bonds tx-sender) err-insufficient-bond))
        )
        (asserts! (>= (get amount bond-data) (var-get min-bond-amount)) err-insufficient-bond)
        (map-set proposals proposal-id
            {
                proposer: tx-sender,
                title: title,
                description: description,
                yes-votes: u0,
                no-votes: u0,
                start-block: block-height,
                end-block: (+ block-height (var-get base-voting-period)),
                executed: false,
                passed: false
            }
        )
        (var-set proposal-count proposal-id)
        (ok proposal-id)
    )
)

(define-public (cast-vote (proposal-id uint) (vote-choice bool))
    (let
        (
            (proposal-data (unwrap! (map-get? proposals proposal-id) err-not-found))
            (voting-weight (calculate-voting-weight tx-sender))
        )
        (asserts! (> voting-weight u0) err-insufficient-bond)
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) 
                 err-already-voted)
        (asserts! (>= block-height (get start-block proposal-data)) err-proposal-not-active)
        (asserts! (<= block-height (get end-block proposal-data)) err-proposal-expired)
        (asserts! (not (get executed proposal-data)) err-proposal-not-active)
        
        (map-set votes 
            { proposal-id: proposal-id, voter: tx-sender }
            { vote-weight: voting-weight, vote-choice: vote-choice }
        )
        
        (if vote-choice
            (map-set proposals proposal-id
                (merge proposal-data { yes-votes: (+ (get yes-votes proposal-data) voting-weight) })
            )
            (map-set proposals proposal-id
                (merge proposal-data { no-votes: (+ (get no-votes proposal-data) voting-weight) })
            )
        )
        
        (let
            (
                (rep-data (default-to { score: u100, total-votes: u0, accurate-votes: u0 }
                                     (map-get? reputation-scores tx-sender)))
            )
            (map-set reputation-scores tx-sender
                {
                    score: (get score rep-data),
                    total-votes: (+ (get total-votes rep-data) u1),
                    accurate-votes: (get accurate-votes rep-data)
                }
            )
        )
        
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal-data (unwrap! (map-get? proposals proposal-id) err-not-found))
        )
        (asserts! (> block-height (get end-block proposal-data)) err-proposal-not-active)
        (asserts! (not (get executed proposal-data)) err-proposal-not-active)
        
        (let
            (
                (total-votes (+ (get yes-votes proposal-data) (get no-votes proposal-data)))
                (passed (> (get yes-votes proposal-data) (get no-votes proposal-data)))
            )
            (map-set proposals proposal-id
                (merge proposal-data { executed: true, passed: passed })
            )
            (ok passed)
        )
    )
)

(define-public (update-reputation (account principal) (accurate bool))
    (let
        (
            (rep-data (unwrap! (map-get? reputation-scores account) err-not-found))
            (new-accurate (if accurate (+ (get accurate-votes rep-data) u1) (get accurate-votes rep-data)))
            (new-score (/ (* new-accurate u100) (get total-votes rep-data)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set reputation-scores account
            {
                score: (if (> new-score u0) new-score u1),
                total-votes: (get total-votes rep-data),
                accurate-votes: new-accurate
            }
        )
        (ok true)
    )
)

(define-public (set-min-bond (new-min uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set min-bond-amount new-min)
        (ok true)
    )
)

(define-public (set-voting-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set base-voting-period new-period)
        (ok true)
    )
)