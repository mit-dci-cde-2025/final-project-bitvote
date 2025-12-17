;; contracts/sip-010-trait-ft-standard.clar
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    (get-name () (response (string-ascii 32) uint)) ;; the human readable name of the token

    (get-symbol () (response (string-ascii 32) uint)) ;; the ticker symbol

    (get-decimals () (response uint uint)) ;; the number of decimals used

    (get-balance (principal) (response uint uint)) ;; the balance of the passed principal

    (get-total-supply () (response uint uint)) ;; the current total supply

    (get-token-uri () (response (optional (string-utf8 256)) uint)) ;; URI representing metadata of token
  )
)