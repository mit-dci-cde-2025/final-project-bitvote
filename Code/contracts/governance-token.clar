;; contracts/governance-token.clar
(impl-trait .sip-010-trait-ft-standard.sip-010-trait)

(define-fungible-token bitvote-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-claimed (err u101))

(define-constant CLAIM-AMOUNT u1000000) 
(define-map claimed-wallets principal bool)
(define-read-only (has-claimed)
    (default-to false (map-get? claimed-wallets tx-sender))
)

;; SIP-010 fxns
(define-read-only (get-name)
    (ok "BitVote Governance Token"))

(define-read-only (get-symbol)
    (ok "BVT"))

(define-read-only (get-decimals)
    (ok u6))

(define-read-only (get-balance (who principal))
    (ok (ft-get-balance bitvote-token who)))

(define-read-only (get-total-supply)
    (ok (ft-get-supply bitvote-token)))

(define-read-only (get-token-uri)
    (ok none))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) (err u101))
        (try! (ft-transfer? bitvote-token amount sender recipient))
        (print memo)
        (ok true)))

(define-public (claim-tokens)
    (begin
        (asserts! (is-none (map-get? claimed-wallets tx-sender)) err-already-claimed)

        (try! (ft-mint? bitvote-token CLAIM-AMOUNT tx-sender))
        (map-set claimed-wallets tx-sender true)
        
        (ok true)
    ))

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ft-mint? bitvote-token amount recipient)))