;; contracts/proposal.clar
(define-constant ERR-INSUFFICIENT-BALANCE (err u401))
(define-constant ERR-NOT-AUTHORIZED (err u402))
(define-constant ERR-VOTE-ALREADY-CAST (err u403))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u404))
(define-constant ERR-VOTING-CLOSED (err u405))
(define-constant ERR-WRONG-STATUS (err u406))
(define-constant ERR-MAX-LEVEL (err u407))
(define-constant ERR-CONFLICT (err u408))

(define-constant STATUS_REJECTED u0)
(define-constant STATUS_ACCEPTED u1)
(define-constant STATUS_UNDECIDED u2)

(define-constant QUORUM_LEVEL_0 u10000000) 
(define-constant QUORUM_LEVEL_1 u20000000)
(define-constant QUORUM_LEVEL_2 u30000000)

(define-map proposals
    { category-id: uint, index: uint }
    {   
        bip: uint,
        bip-given-by: principal,
        level: uint,
        created-by: principal,
        title: (string-utf8 256),
        type: (string-utf8 60),
        layer: (string-utf8 60),
        copyright: (string-utf8 60),
        abstract: (string-utf8 6000),
        motivation: (string-utf8 10000),
        specification: (string-utf8 20000),
        back-compat: (string-utf8 6000),
        ref-imp: (string-utf8 6000),
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint
    }
)

(define-map category-count-map 
    { category-id: uint } 
    uint
)

(define-map receipts
    { category-id: uint, index: uint, voter: principal }
    { voted: bool }
)

(define-map proposals-status
    { category-id: uint, index: uint }
    { status: uint }
)

(define-data-var category-count uint u0)

(define-read-only (get-category-count) (var-get category-count))

(define-read-only (get-current-block-height) block-height)

(define-public (cast-vote (category-id uint) (index uint) (vote-for bool))
    (let
        (
            (proposal (unwrap! (map-get? proposals { category-id: category-id, index: index }) ERR-PROPOSAL-NOT-FOUND))
            (voter-balance (unwrap! (contract-call? .governance-token get-balance tx-sender) ERR-INSUFFICIENT-BALANCE))
        )

        (asserts! (< block-height (get end-block proposal)) ERR-VOTING-CLOSED)
        (asserts! (> voter-balance u0) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-none (map-get? receipts { category-id: category-id, index: index, voter: tx-sender })) ERR-VOTE-ALREADY-CAST)

        (map-insert receipts { category-id: category-id, index: index, voter: tx-sender } { voted: true })
        (map-set proposals { category-id: category-id, index: index }
            (merge proposal
                {
                    yes-votes: (if vote-for (+ (get yes-votes proposal) voter-balance) (get yes-votes proposal)),
                    no-votes: (if vote-for (get no-votes proposal) (+ (get no-votes proposal) voter-balance))
                }
            )
        )

        (ok "Vote cast successfully")
    )
)
(define-public (cast-vote-and-cleanup (vote-cat-id uint) (vote-idx uint) (vote-for bool) (stale (list 50 (tuple (category-id uint) (index uint)))))
    (begin
        (try! (conclude-many stale))
        (cast-vote vote-cat-id vote-idx vote-for)
    )
)

(define-public (submit-proposal-and-cleanup (title (string-utf8 256)) (layer (string-utf8 60)) (type (string-utf8 60)) (abstract (string-utf8 6000)) (motivation (string-utf8 10000)) (duration uint) (stale (list 50 (tuple (category-id uint) (index uint)))))
    (begin
        (try! (conclude-many stale))
        (submit-proposal title layer type abstract motivation duration)
    )
)

(define-public (submit-proposal (title (string-utf8 256)) (layer (string-utf8 60)) (type (string-utf8 60)) (abstract (string-utf8 6000)) (motivation (string-utf8 10000)) (duration uint))
    (let
        (
            (current-cat-count (var-get category-count))
            (new-id (+ current-cat-count u1))
        )
        ;; ensure voting will end in the future
        (asserts! (> (+ duration block-height) block-height) (err u406))

        (map-insert proposals { category-id: new-id, index: u1 }
            {
                bip: u0,
                bip-given-by: tx-sender,
                created-by: tx-sender,
                title: title,
                type: type,
                layer: layer,
                level: u0,
                copyright: u"",
                abstract: abstract,
                motivation: motivation,
                specification: u"",
                back-compat: u"",
                ref-imp: u"",
                start-block: block-height,
                end-block: (+ duration block-height),
                yes-votes: u0,
                no-votes: u0
            }
        )

        (map-set category-count-map
            { category-id: new-id } 
            u1 
        )
        
        (var-set category-count new-id)
        
        (ok new-id)
    )
)

(define-public (submit-level-up-and-cleanup 
    (category-id uint) 
    (title (string-utf8 256)) 
    (abstract (string-utf8 6000)) 
    (motivation (string-utf8 10000)) 
    (duration uint)
    (copyright (string-utf8 60))
    (specification (string-utf8 20000))
    (back-compat (string-utf8 6000)) 
    (stale (list 50 (tuple (category-id uint) (index uint)))))
  (begin
        (try! (conclude-many stale))
        (submit-level-up category-id title abstract motivation duration copyright specification back-compat)
    )
)

(define-public (submit-level-up 
    (category-id uint) 
    (title (string-utf8 256)) 
    (abstract (string-utf8 6000)) 
    (motivation (string-utf8 10000)) 
    (duration uint)
    (copyright (string-utf8 60))
    (specification (string-utf8 20000))
    (back-compat (string-utf8 6000)) 
)
    (let
        (
            (current-idx (default-to u0 (map-get? category-count-map { category-id: category-id })))
            (prev-prop (unwrap! (map-get? proposals { category-id: category-id, index: current-idx }) ERR-PROPOSAL-NOT-FOUND))
            
            (prev-status (get-proposal-status category-id current-idx))
            
            (new-idx (+ current-idx u1))
            (new-level (+ (get level prev-prop) u1))

            (start-block block-height)
            (end-block (+ block-height duration))
        )

        (asserts! (is-eq tx-sender (get created-by prev-prop)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq prev-status STATUS_ACCEPTED) ERR-WRONG-STATUS)
        (asserts! (< (get level prev-prop) u2) ERR-MAX-LEVEL)
        (asserts! (> end-block block-height) (err u406))

        (map-insert proposals { category-id: category-id, index: new-idx }
            {
                type: (get type prev-prop),
                layer: (get layer prev-prop),
                
                title: title,
                abstract: abstract,
                motivation: motivation,
                level: new-level,
                created-by: tx-sender,
                start-block: start-block,
                end-block: end-block,
                bip-given-by: tx-sender,
                copyright: copyright, 
                specification: specification, 
                back-compat: back-compat, 
                ref-imp: u"",

                bip: u0,
                yes-votes: u0, 
                no-votes: u0
            }
        )

        (map-set category-count-map { category-id: category-id } new-idx)
        
        (ok new-idx)
    )
)

(define-private (internal-set-status (cat-id uint) (idx uint) (new-status uint))
    (begin
        (map-set proposals-status 
            { category-id: cat-id, index: idx }
            { status: new-status }
        )
        (ok new-status)
    )
)

(define-public (conclude-proposal (cat-id uint) (idx uint))
    (let
        (
            (proposal (unwrap! (map-get? proposals { category-id: cat-id, index: idx }) ERR-PROPOSAL-NOT-FOUND))
            
            (yes (get yes-votes proposal))
            (no (get no-votes proposal))
            (total (+ yes no))
            (level (get level proposal))
            
            (current-status (get-proposal-status cat-id idx))
        )
        
        (asserts! (>= block-height (get end-block proposal)) ERR-VOTING-CLOSED)
        (asserts! (is-eq current-status STATUS_UNDECIDED) ERR-CONFLICT)

        
        (if (is-eq level u0)
            ;; level 0: 10M quorum, >50% yes
            (if (and (>= total QUORUM_LEVEL_0) (> yes no))
                (internal-set-status cat-id idx STATUS_ACCEPTED)
                (internal-set-status cat-id idx STATUS_REJECTED)
            )
            ;; level 1: 20M quorum, >66% yes
            (if (is-eq level u1)
                (if (and (>= total QUORUM_LEVEL_1) (> yes (/ (* total u2) u3)))
                    (internal-set-status cat-id idx STATUS_ACCEPTED)
                    (internal-set-status cat-id idx STATUS_REJECTED)
                )
                ;; level 2: 30M quorum, >80% yes (level 2 is max)
                (if (and (>= total QUORUM_LEVEL_2) (> yes (/ (* total u4) u5)))
                    (internal-set-status cat-id idx STATUS_ACCEPTED)
                    (internal-set-status cat-id idx STATUS_REJECTED)
                )
            )
        )
    )
)

(define-private (batch-conclude-iter (item (tuple (category-id uint) (index uint))) (previous-result (response bool uint)))
    (begin
        (match (conclude-proposal (get category-id item) (get index item))
            success previous-result
            error previous-result
        )
    )
)

(define-public (conclude-many (proposal-list (list 50 (tuple (category-id uint) (index uint)))))
    (fold batch-conclude-iter proposal-list (ok true))
)

(define-read-only (get-count-in-category (cat-id uint))
    (default-to u0 (map-get? category-count-map { category-id: cat-id }))
)

(define-read-only (get-proposal (cat-id uint) (index uint))
    (map-get? proposals { category-id: cat-id, index: index })
)

(define-read-only (get-proposal-status (cat-id uint) (idx uint))
    (let
        (
            (entry (map-get? proposals-status { category-id: cat-id, index: idx }))
        )
        (match entry
            data (get status data)
            STATUS_UNDECIDED
        )
    )
)