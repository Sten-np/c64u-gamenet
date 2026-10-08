; =====================================================================
; commtest.s - Milestone 1 two-machine C64U communication test
; =====================================================================
;
; TEST PROGRAM ONLY. Not part of the GameNet API. Uses the internal
; C64U communication layer (src/c64u/) directly.
;
; Two C64 Ultimate systems run this program:
;   C64U A = CALLER   (press C) - dials the answerer with ATDT
;   C64U B = ANSWERER (press A) - waits for RING, answers with ATA
;
; Test protocol (test-only; NOT the future GameNet message format):
;   1. B, after ATA, repeats marker "#GNA" every ~0.5 s.
;   2. A shows/discards all modem text and the connect banner until
;      it sees "#GNA", then sends "#GNC" once.
;   3. B, on "#GNC": link synchronised.
;   4. A -> B: ~1 s pause, then 256 bytes $00,$01,...,$FF.
;   5. B verifies and shows the result.
;   6. B -> A: ~1 s pause, "#GNB", ~1 s pause, 256 bytes $FF,$FE,...,$00,
;      then one verdict byte 'P'/'F' (B's result for A -> B).
;   7. A verifies, shows the result, sends its verdict byte 'P'/'F'.
;   8. Both: show both results, "+++", "ATH", DTR off.
;
; The two directions use different patterns so that an echo of the
; sender's own data cannot be mistaken for a pass. Together the
; patterns contain all 256 byte values in each direction (binary
; transparency check, docs/c64u-communication.md Open Question 4).
; Two consecutive '+' bytes never occur in the patterns or markers.
;
; Resources: no zero page. KERNAL CHROUT/GETIN are used and the
; KERNAL IRQ stays enabled. Self-modifying code (runs from RAM).
; All timeouts are loop counts and only approximate.

.include "c64.inc"
.include "c64u.inc"

.import c64u_init
.import c64u_status
.import c64u_send
.import c64u_receive
.import c64u_shutdown
.import c64u_rx_status
.import c64u_delay
.import c64u_send_string
.import c64u_modem_dial
.import c64u_modem_answer
.import c64u_modem_hangup

.export start

; ---------------------------------------------------------------------
; Test constants
; ---------------------------------------------------------------------

PATTERN_AB_MASK     = $00       ; A -> B: byte i = i        ($00..$FF)
PATTERN_BA_MASK     = $FF       ; B -> A: byte i = i ^ $FF  ($FF..$00)

HOST_MAX            = 38        ; max. length of "host:port" input

VERDICT_PASS        = 'P'
VERDICT_FAIL        = 'F'
VERDICT_NONE        = '?'

; wait_byte failure reasons (returned in A with C = 1)
WAIT_TIMEOUT        = 1
WAIT_ABORT          = 2

; Delays in c64u_delay units (~10 ms)
TURNAROUND_UNITS    = 100       ; ~1 s pause before a data block

; Timeouts for wait_byte: (high, middle) bytes of a 24-bit loop
; counter. One wait_byte idle iteration is about 50 cycles, so one
; middle unit ~= 13 ms and one high unit ~= 3.3 s (approximate).
TMO_RING_HI         = $FF       ; ~14 min waiting for RING (key aborts)
TMO_ANSWER_HI       = 40        ; ~2 min caller waits for "#GNA"
TMO_RESEND_MID      = 40        ; ~0.5 s between "#GNA" repeats
SYNC_TRIES          = 60        ; ~30 s answerer waits for "#GNC"
TMO_BLOCK_HI        = 20        ; ~1 min waiting for "#GNB"
TMO_BYTE_HI         = 2         ; ~6 s between two pattern bytes
TMO_VERDICT_HI      = 10        ; ~30 s waiting for a verdict byte

ASCII_LOWER_A       = $61
ASCII_LOWER_Z       = $7A
ASCII_CASE_BIT      = $20

; ---------------------------------------------------------------------
; Macros
; ---------------------------------------------------------------------

; Print a zero-terminated string. Modifies A, X, Y.
.macro  PRINT   addr
        lda     #<(addr)
        ldy     #>(addr)
        jsr     print_str
.endmacro

; Arm the wait_byte timeout. Modifies A, X.
.macro  TIMEOUT hi, mid
        lda     #(hi)
        ldx     #(mid)
        jsr     timeout_set
.endmacro

; Select the marker string that match_feed looks for. Modifies A, Y.
.macro  MATCH   addr
        lda     #<(addr)
        ldy     #>(addr)
        jsr     match_set
.endmacro

; Send a zero-terminated string over the link. Modifies A, Y.
.macro  SEND    addr
        lda     #<(addr)
        ldy     #>(addr)
        jsr     c64u_send_string
.endmacro

.segment "CODE"

; =====================================================================
; start - entry point (BASIC SYS stub). Returns to BASIC when done.
; =====================================================================
.proc start
        lda     #VERDICT_NONE
        sta     result_ab
        sta     result_ba
        lda     #0
        sta     check_keys
        PRINT   msg_title
        PRINT   msg_role
role:   jsr     GETIN
        cmp     #'C'
        beq     caller
        cmp     #'A'
        beq     answerer
        jmp     role
caller: jmp     run_caller
answerer:
        jmp     run_answerer
.endproc

; =====================================================================
; run_caller - C64U A
; =====================================================================
.proc run_caller
        PRINT   msg_is_caller
        jsr     do_init

prompt: PRINT   msg_host
        jsr     input_line
        lda     in_len
        beq     prompt

        ; --- dial -----------------------------------------------------
        PRINT   msg_dialing
        PRINT   host_buf
        lda     #PETSCII_RETURN
        jsr     CHROUT
        lda     #<host_buf
        ldy     #>host_buf
        jsr     c64u_modem_dial

        ; --- wait for the answerer's sync marker, show modem text -----
        PRINT   msg_wait_answer
        MATCH   marker_ready
        TIMEOUT TMO_ANSWER_HI, 0
        lda     #1
        sta     check_keys
scan:   jsr     wait_byte
        bcc     :+
        jmp     fail_wait
:       jsr     fold_upper
        pha
        jsr     show_char
        pla
        jsr     match_feed
        bcc     scan
        lda     #0
        sta     check_keys

        PRINT   msg_connected
        jsr     show_status
        SEND    marker_ack

        ; --- A -> B ---------------------------------------------------
        lda     #TURNAROUND_UNITS
        jsr     c64u_delay
        PRINT   msg_send_ab
        lda     #PATTERN_AB_MASK
        jsr     send_pattern

        ; --- B -> A ---------------------------------------------------
        PRINT   msg_wait_block
        MATCH   marker_block
        TIMEOUT TMO_BLOCK_HI, 0
scan2:  jsr     wait_byte
        bcc     :+
        jmp     fail_wait
:       jsr     fold_upper
        jsr     match_feed
        bcc     scan2

        PRINT   msg_recv_ba
        lda     #PATTERN_BA_MASK
        jsr     receive_pattern
        lda     #PATTERN_BA_MASK
        jsr     verify_and_show
        sta     result_ba

        ; B's verdict on A -> B follows its pattern
        jsr     wait_verdict
        sta     result_ab

        ; tell B our verdict on B -> A
        lda     result_ba
        jsr     c64u_send
        jmp     finish
.endproc

; =====================================================================
; run_answerer - C64U B
; =====================================================================
.proc run_answerer
        PRINT   msg_is_answerer
        jsr     do_init

        ; --- wait for RING, show modem text --------------------------
        PRINT   msg_wait_ring
        MATCH   marker_ring
        TIMEOUT TMO_RING_HI, 0
        lda     #1
        sta     check_keys
scan:   jsr     wait_byte
        bcc     :+
        jmp     fail_wait
:       jsr     fold_upper
        pha
        jsr     show_char
        pla
        jsr     match_feed
        bcc     scan
        lda     #0
        sta     check_keys

        ; --- answer and synchronise ----------------------------------
        PRINT   msg_answering
        jsr     c64u_modem_answer
        lda     #TURNAROUND_UNITS
        jsr     c64u_delay
        PRINT   msg_syncing
        MATCH   marker_ack
        lda     #SYNC_TRIES
        sta     tries
try:    SEND    marker_ready
        TIMEOUT 0, TMO_RESEND_MID
scan2:  jsr     wait_byte
        bcs     retry
        jsr     fold_upper
        jsr     match_feed
        bcc     scan2
        jmp     synced
retry:  dec     tries
        bne     try
        lda     #WAIT_TIMEOUT
        jmp     fail_wait

synced: PRINT   msg_connected_b
        jsr     show_status

        ; --- A -> B ---------------------------------------------------
        PRINT   msg_recv_ab
        lda     #PATTERN_AB_MASK
        jsr     receive_pattern
        lda     #PATTERN_AB_MASK
        jsr     verify_and_show
        sta     result_ab

        ; --- B -> A ---------------------------------------------------
        lda     #TURNAROUND_UNITS
        jsr     c64u_delay
        SEND    marker_block
        lda     #TURNAROUND_UNITS
        jsr     c64u_delay
        PRINT   msg_send_ba
        lda     #PATTERN_BA_MASK
        jsr     send_pattern
        lda     result_ab               ; our verdict on A -> B
        jsr     c64u_send

        ; A's verdict on B -> A
        jsr     wait_verdict
        sta     result_ba
        jmp     finish
.endproc

; =====================================================================
; finish - show results, hang up, return to BASIC
; fail_wait - abort path; A = WAIT_TIMEOUT or WAIT_ABORT
;
; Both are entered with JMP from run_caller/run_answerer, i.e. at the
; stack level of `start`, so the final RTS returns to BASIC.
; =====================================================================
.proc finish
        PRINT   msg_res_ab
        lda     result_ab
        jsr     show_verdict
        PRINT   msg_res_ba
        lda     result_ba
        jsr     show_verdict
        lda     result_ab
        cmp     #VERDICT_PASS
        bne     fail
        lda     result_ba
        cmp     #VERDICT_PASS
        bne     fail
        PRINT   msg_overall_pass
        jmp     end_session
fail:   PRINT   msg_overall_fail
        jmp     end_session
.endproc

.proc fail_wait
        cmp     #WAIT_ABORT
        beq     aborted
        PRINT   msg_timeout
        jmp     report
aborted:
        PRINT   msg_aborted
report: PRINT   msg_overall_fail
        ; fall through
.endproc

.proc end_session
        PRINT   msg_hangup
        jsr     c64u_modem_hangup
        jsr     c64u_shutdown
        jsr     show_status
        PRINT   msg_done
        rts                             ; back to BASIC
.endproc

; =====================================================================
; Test helpers
; =====================================================================

; ---------------------------------------------------------------------
; do_init - initialise the communication layer and show its status
; Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc do_init
        PRINT   msg_init
        jsr     c64u_init
        PRINT   msg_ok
        jmp     show_status
.endproc

; ---------------------------------------------------------------------
; show_status - print raw ACIA status and its DCD/DSR bits
; (evidence for Open Questions 1 and 5)
; Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc show_status
        jsr     c64u_status
        sta     status_copy
        PRINT   msg_status
        lda     status_copy
        jsr     print_hex
        PRINT   msg_dcd
        lda     status_copy
        and     #ACIA_ST_DCD
        jsr     print_bit
        PRINT   msg_dsr
        lda     status_copy
        and     #ACIA_ST_DSR
        jsr     print_bit
        lda     #PETSCII_RETURN
        jmp     CHROUT
.endproc

; ---------------------------------------------------------------------
; send_pattern - send 256 bytes (i XOR A, i = 0..255), print progress
; In: A = pattern mask.  Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc send_pattern
        sta     pattern_mask
        lda     #0
        sta     tx_index
loop:   lda     tx_index
        eor     pattern_mask
        jsr     c64u_send
        lda     tx_index
        and     #$1F
        cmp     #$1F
        bne     next
        lda     #'.'                    ; one dot per 32 bytes sent
        jsr     CHROUT
next:   inc     tx_index
        bne     loop
        PRINT   msg_sent
        rts
.endproc

; ---------------------------------------------------------------------
; receive_pattern - receive up to 256 bytes into rx_buffer
;
; Tight loop: no screen output while data is arriving (the ACIA has a
; single receive register; emulation buffering is undocumented).
; Out: rx_count (0 = 256 when rx_complete = 1), rx_complete,
;      rx_errors (OR of ACIA_ST_ERRORS bits seen).  Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc receive_pattern
        lda     #0
        sta     rx_count
        sta     rx_errors
        sta     rx_complete
        sta     check_keys
loop:   TIMEOUT TMO_BYTE_HI, 0
        jsr     wait_byte
        bcs     done                    ; timeout: incomplete
        ldx     rx_count
        sta     rx_buffer,x
        lda     c64u_rx_status
        and     #ACIA_ST_ERRORS
        ora     rx_errors
        sta     rx_errors
        inc     rx_count
        bne     loop
        lda     #1
        sta     rx_complete
done:   rts
.endproc

; ---------------------------------------------------------------------
; verify_and_show - compare rx_buffer with the expected pattern and
; display count, mismatches, ACIA errors and sample rows.
; In:  A = pattern mask
; Out: A = VERDICT_PASS or VERDICT_FAIL.  Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc verify_and_show
        sta     pattern_mask
        lda     #0
        sta     mismatch_lo
        sta     mismatch_hi
        sta     have_bad

        ; --- count mismatches --------------------------------------
        ldx     #0
loop:   lda     rx_complete
        bne     check
        cpx     rx_count
        beq     counted                 ; only rx_count bytes received
check:  txa
        eor     pattern_mask            ; expected value
        cmp     rx_buffer,x
        beq     next
        inc     mismatch_lo
        bne     :+
        inc     mismatch_hi
:       lda     have_bad
        bne     next
        inc     have_bad                ; remember first mismatch
        stx     bad_index
        txa
        eor     pattern_mask
        sta     bad_expected
        lda     rx_buffer,x
        sta     bad_got
next:   inx
        bne     loop
counted:

        ; --- received count ----------------------------------------
        lda     rx_complete
        beq     partial
        PRINT   msg_got_all
        jmp     show_mm
partial:
        PRINT   msg_got_part
        lda     rx_count
        jsr     print_hex
        PRINT   msg_got_part2

        ; --- mismatches / errors -----------------------------------
show_mm:
        PRINT   msg_mismatch
        lda     mismatch_hi
        jsr     print_hex
        lda     mismatch_lo
        jsr     print_hex
        lda     #PETSCII_RETURN
        jsr     CHROUT
        lda     have_bad
        beq     errs
        PRINT   msg_first_bad
        lda     bad_index
        jsr     print_hex
        PRINT   msg_expected
        lda     bad_expected
        jsr     print_hex
        PRINT   msg_got
        lda     bad_got
        jsr     print_hex
        lda     #PETSCII_RETURN
        jsr     CHROUT
errs:   PRINT   msg_acia_err
        lda     rx_errors
        jsr     print_hex
        lda     #PETSCII_RETURN
        jsr     CHROUT

        ; --- sample rows: start, $7F/$80 boundary, end ----------------
        lda     rx_complete
        beq     verdict
        PRINT   msg_rows
        lda     #$00
        jsr     dump_row
        lda     #$7C
        jsr     dump_row
        lda     #$F8
        jsr     dump_row

verdict:
        lda     rx_complete
        beq     failed
        lda     mismatch_lo
        ora     mismatch_hi
        bne     failed
        PRINT   msg_dir_pass
        lda     #VERDICT_PASS
        rts
failed: PRINT   msg_dir_fail
        lda     #VERDICT_FAIL
        rts
.endproc

; ---------------------------------------------------------------------
; dump_row - print "ii: b0 b1 ... b7" from rx_buffer
; In: A = start index.  Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc dump_row
        sta     dump_index
        jsr     print_hex
        lda     #':'
        jsr     CHROUT
        lda     #8
        sta     dump_left
loop:   lda     #' '
        jsr     CHROUT
        ldx     dump_index
        lda     rx_buffer,x
        jsr     print_hex
        inc     dump_index
        dec     dump_left
        bne     loop
        lda     #PETSCII_RETURN
        jmp     CHROUT
.endproc

; ---------------------------------------------------------------------
; wait_verdict - wait for a 'P' or 'F' byte from the other machine
; Out: A = VERDICT_PASS, VERDICT_FAIL or VERDICT_NONE (timeout)
; Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc wait_verdict
        lda     #0
        sta     check_keys
        TIMEOUT TMO_VERDICT_HI, 0
loop:   jsr     wait_byte
        bcs     none
        cmp     #VERDICT_PASS
        beq     done
        cmp     #VERDICT_FAIL
        beq     done
        jmp     loop                    ; ignore anything else
none:   lda     #VERDICT_NONE
done:   rts
.endproc

; ---------------------------------------------------------------------
; show_verdict - print PASS / FAIL / NOT REPORTED for verdict in A
; Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc show_verdict
        cmp     #VERDICT_PASS
        beq     pass
        cmp     #VERDICT_FAIL
        beq     fail
        PRINT   msg_v_none
        rts
pass:   PRINT   msg_v_pass
        rts
fail:   PRINT   msg_v_fail
        rts
.endproc

; ---------------------------------------------------------------------
; timeout_set - arm the wait_byte timeout counter
; In: A = high byte, X = middle byte (low byte starts at 0)
; Modifies: A
; ---------------------------------------------------------------------
.proc timeout_set
        sta     tmo_hi
        stx     tmo_mid
        lda     #0
        sta     tmo_lo
        rts
.endproc

; ---------------------------------------------------------------------
; wait_byte - wait for one received byte
;
; Out: C = 0: A = received byte
;      C = 1: A = WAIT_TIMEOUT (counter expired) or
;                 WAIT_ABORT (key pressed; only if check_keys <> 0)
; Modifies: A, flags (X, Y preserved)
;
; The keyboard is checked every 256 idle iterations. Disable it
; (check_keys = 0) while data is streaming.
; ---------------------------------------------------------------------
.proc wait_byte
loop:   jsr     c64u_receive
        bcs     got
        ; 24-bit countdown: expire when it is already zero
        lda     tmo_lo
        bne     dec_lo
        lda     tmo_mid
        bne     dec_mid
        lda     tmo_hi
        beq     expired
        dec     tmo_hi
dec_mid:
        dec     tmo_mid
dec_lo: dec     tmo_lo
        bne     loop
        lda     check_keys
        beq     loop
        stx     save_x                  ; GETIN uses X and Y (book p.104)
        sty     save_y
        jsr     GETIN
        ldx     save_x
        ldy     save_y
        cmp     #0
        beq     loop
        lda     #WAIT_ABORT
        sec
        rts
expired:
        lda     #WAIT_TIMEOUT
        sec
        rts
got:    clc
        rts
.endproc

; ---------------------------------------------------------------------
; match_feed - feed one received byte to the marker matcher
; In:  A = byte
; Out: C = 1 when the complete marker has just been seen (matcher is
;      reset), else C = 0.  Modifies: A, X, flags
; ---------------------------------------------------------------------
.proc match_feed
        ldx     match_index
cmp_next:
        cmp     $FFFF,x                 ; operand patched by match_set
        beq     hit
cmp_first:
        cmp     $FFFF                   ; operand patched by match_set
        bne     miss
        ldx     #1                      ; byte restarts the marker
        stx     match_index
        clc
        rts
miss:   ldx     #0
        stx     match_index
        clc
        rts
hit:    inx
        stx     match_index
load_end:
        lda     $FFFF,x                 ; operand patched by match_set
        bne     partial
        lda     #0                      ; marker complete: reset
        sta     match_index
        sec
        rts
partial:
        clc
        rts
.endproc

; ---------------------------------------------------------------------
; match_set - select a zero-terminated marker (first byte must not
; occur again inside the marker); resets the matcher.
; In: A/Y = low/high address.  Modifies: A, flags
; (Placed after match_feed: ca65 needs the scope to be defined.)
; ---------------------------------------------------------------------
.proc match_set
        sta     match_feed::cmp_next + 1
        sty     match_feed::cmp_next + 2
        sta     match_feed::cmp_first + 1
        sty     match_feed::cmp_first + 2
        sta     match_feed::load_end + 1
        sty     match_feed::load_end + 2
        lda     #0
        sta     match_index
        rts
.endproc

; ---------------------------------------------------------------------
; fold_upper - convert ASCII 'a'..'z' to 'A'..'Z'
; In/Out: A.  Modifies: flags
; ---------------------------------------------------------------------
.proc fold_upper
        cmp     #ASCII_LOWER_A
        bcc     done
        cmp     #ASCII_LOWER_Z + 1
        bcs     done
        and     #<~ASCII_CASE_BIT
done:   rts
.endproc

; ---------------------------------------------------------------------
; show_char - display one received modem/banner byte (already folded)
; RETURN is printed, other control bytes are skipped, bytes that are
; not printable in the upper-case character set are shown as '?'.
; In: A.  Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc show_char
        cmp     #PETSCII_RETURN
        beq     out
        cmp     #' '
        bcc     skip
        cmp     #'Z' + 1
        bcc     out
        lda     #'?'
out:    jmp     CHROUT
skip:   rts
.endproc

; ---------------------------------------------------------------------
; input_line - read "host:port" from the keyboard into host_buf
; Accepts $20..$5A, DEL deletes, RETURN ends. Zero-terminated.
; Out: in_len = length.  Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc input_line
        lda     #0
        sta     in_len
loop:   jsr     GETIN
        cmp     #0
        beq     loop
        cmp     #PETSCII_RETURN
        beq     done
        cmp     #PETSCII_DEL
        beq     delete
        cmp     #' '
        bcc     loop
        cmp     #'Z' + 1
        bcs     loop
        ldx     in_len
        cpx     #HOST_MAX
        bcs     loop
        sta     host_buf,x
        inc     in_len
        jsr     CHROUT
        jmp     loop
delete: lda     in_len
        beq     loop
        dec     in_len
        lda     #PETSCII_DEL
        jsr     CHROUT
        jmp     loop
done:   ldx     in_len
        lda     #0
        sta     host_buf,x
        lda     #PETSCII_RETURN
        jmp     CHROUT
.endproc

; ---------------------------------------------------------------------
; print_str - print a zero-terminated string (max. 255 characters)
; In: A/Y = low/high address.  Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc print_str
        sta     load + 1
        sty     load + 2
        lda     #0
        sta     print_index
loop:   ldx     print_index
load:   lda     $FFFF,x                 ; operand patched above
        beq     done
        jsr     CHROUT
        inc     print_index
        bne     loop
done:   rts
.endproc

; ---------------------------------------------------------------------
; print_hex - print A as two hexadecimal digits
; Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc print_hex
        pha
        lsr
        lsr
        lsr
        lsr
        jsr     nibble
        pla
        and     #$0F
nibble: cmp     #10
        bcc     digit
        adc     #'A' - 10 - 1           ; C = 1 here
        jmp     CHROUT
digit:  adc     #'0'                    ; C = 0 here
        jmp     CHROUT
.endproc

; ---------------------------------------------------------------------
; print_bit - print '1' if A <> 0, else '0'
; Modifies: A, X, Y
; ---------------------------------------------------------------------
.proc print_bit
        beq     zero
        lda     #'1'
        jmp     CHROUT
zero:   lda     #'0'
        jmp     CHROUT
.endproc

; =====================================================================
; Data
; =====================================================================
.segment "RODATA"

; Link markers (ASCII). First byte '#' does not recur in a marker.
marker_ready:   .byte   "#GNA", 0       ; B -> A: answerer online
marker_ack:     .byte   "#GNC", 0       ; A -> B: caller saw #GNA
marker_block:   .byte   "#GNB", 0       ; B -> A: B -> A block follows
marker_ring:    .byte   "RING", 0       ; modem -> B [UG p.160]

; Screen text: upper-case ASCII = PETSCII upper case (see hello.s).
CR = PETSCII_RETURN

msg_title:      .byte   PETSCII_CLEAR, "C64U GAMENET M1 COMMUNICATION TEST", CR
                .byte   "(INTERNAL TEST - NOT THE GAMENET API)", CR, CR, 0
msg_role:       .byte   "C = CALLER   (C64U A)", CR
                .byte   "A = ANSWERER (C64U B)", CR, 0
msg_is_caller:  .byte   CR, "ROLE: CALLER (A)", CR, 0
msg_is_answerer:.byte   CR, "ROLE: ANSWERER (B)", CR, 0
msg_init:       .byte   "INIT ACIA $DE00... ", 0
msg_ok:         .byte   "OK", CR, 0
msg_status:     .byte   " STATUS $", 0
msg_dcd:        .byte   " DCD=", 0
msg_dsr:        .byte   " DSR=", 0
msg_host:       .byte   "ANSWERER HOST:PORT", CR
                .byte   "(E.G. 192.168.0.64:3000)", CR, "? ", 0
msg_dialing:    .byte   "DIALING ATDT", 0
msg_wait_answer:.byte   "WAITING FOR ANSWER (KEY ABORTS)", CR
                .byte   "MODEM/BANNER TEXT:", CR, 0
msg_wait_ring:  .byte   "WAITING FOR CALL (KEY ABORTS)", CR
                .byte   "MODEM TEXT:", CR, 0
msg_answering:  .byte   CR, "RING SEEN - SENDING ATA", CR, 0
msg_syncing:    .byte   "SENDING SYNC, WAITING FOR CALLER", CR, 0
msg_connected:  .byte   CR, "CONNECTED: ANSWERER SYNC RECEIVED", CR, 0
msg_connected_b:.byte   "CONNECTED: CALLER SYNC RECEIVED", CR, 0
msg_send_ab:    .byte   "SENDING A->B $00..$FF ", 0
msg_send_ba:    .byte   "SENDING B->A $FF..$00 ", 0
msg_sent:       .byte   " 256 SENT", CR, 0
msg_wait_block: .byte   "WAITING FOR B->A BLOCK", CR, 0
msg_recv_ab:    .byte   "RECEIVING A->B (EXPECT $00..$FF)", CR, 0
msg_recv_ba:    .byte   "RECEIVING B->A (EXPECT $FF..$00)", CR, 0
msg_got_all:    .byte   "RECEIVED 256 BYTES", CR, 0
msg_got_part:   .byte   "TIMEOUT: RECEIVED ONLY $", 0
msg_got_part2:  .byte   " BYTES", CR, 0
msg_mismatch:   .byte   "MISMATCHES: $", 0
msg_first_bad:  .byte   "FIRST AT $", 0
msg_expected:   .byte   " EXP $", 0
msg_got:        .byte   " GOT $", 0
msg_acia_err:   .byte   "ACIA PE/FE/OVRN BITS: $", 0
msg_rows:       .byte   "RECEIVED VALUES (IDX: BYTES):", CR, 0
msg_dir_pass:   .byte   "DIRECTION RESULT: PASS", CR, 0
msg_dir_fail:   .byte   "DIRECTION RESULT: FAIL", CR, 0
msg_res_ab:     .byte   CR, "A->B: ", 0
msg_res_ba:     .byte   "B->A: ", 0
msg_v_pass:     .byte   "PASS", CR, 0
msg_v_fail:     .byte   "FAIL", CR, 0
msg_v_none:     .byte   "NOT REPORTED", CR, 0
msg_overall_pass:.byte  "OVERALL: PASS", CR, 0
msg_overall_fail:.byte  "OVERALL: FAIL", CR, 0
msg_timeout:    .byte   CR, "TIMEOUT", CR, 0
msg_aborted:    .byte   CR, "ABORTED BY KEY", CR, 0
msg_hangup:     .byte   "HANGING UP (+++ ATH)", CR, 0
msg_done:       .byte   "DONE", CR, 0

.segment "BSS"

; All variables are initialised before use (BSS is not cleared).
result_ab:      .res    1       ; verdict for A -> B
result_ba:      .res    1       ; verdict for B -> A
check_keys:     .res    1       ; wait_byte: 0 = ignore keyboard
tmo_lo:         .res    1
tmo_mid:        .res    1
tmo_hi:         .res    1
save_x:         .res    1
save_y:         .res    1
tries:          .res    1
match_index:    .res    1
pattern_mask:   .res    1
tx_index:       .res    1
rx_count:       .res    1
rx_complete:    .res    1
rx_errors:      .res    1
mismatch_lo:    .res    1
mismatch_hi:    .res    1
have_bad:       .res    1
bad_index:      .res    1
bad_expected:   .res    1
bad_got:        .res    1
dump_index:     .res    1
dump_left:      .res    1
status_copy:    .res    1
print_index:    .res    1
in_len:         .res    1
host_buf:       .res    HOST_MAX + 1
rx_buffer:      .res    256
