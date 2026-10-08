; =====================================================================
; modem.s - C64U communication layer: minimal modem command handling
; =====================================================================
;
; INTERNAL module (architecture layer 3). Implements ONLY what the
; Milestone 1 two-machine test needs: dial, answer, hang up. It is not
; a general modem library and it does not parse modem responses
; (their format is not documented by the C64U User Guide - see
; docs/c64u-communication.md, Open Question 7).
;
; Commands used (C64U User Guide pp.158-159):
;   ATDT<host>:<port><CR>   dial ("T" is ignored by the C64U)
;   ATA<CR>                 answer an incoming call after RING
;   +++                     escape to command mode (>= S12 jiffies,
;                           default 1 s, must follow)
;   ATH<CR>                 hang up
;
; Resources: no zero page, 1 byte BSS. c64u_send_string uses
; self-modifying code (must run from RAM; not re-entrant).

.include "c64u.inc"

.import c64u_send

.export c64u_delay
.export c64u_send_string
.export c64u_modem_dial
.export c64u_modem_answer
.export c64u_modem_hangup

; Inner loop repeat count per delay unit: 8 x 1279 cycles ~= 10,250
; cycles, i.e. roughly 10 ms at a ~1 MHz CPU clock.
DELAY_REPEAT        = 8

.segment "CODE"

; ---------------------------------------------------------------------
; c64u_delay - busy-wait for approximately A x 10 ms
;
; In:       A = number of units (1..255; 0 means 256)
; Out:      nothing
; Modifies: A, X, Y, flags
;
; Pure CPU loop; interrupts can only make it longer. Only used where a
; MINIMUM time is required (modem escape guard time).
; ---------------------------------------------------------------------
.proc c64u_delay
        tay
unit:   lda     #DELAY_REPEAT
        sta     delay_repeat
rep:    ldx     #0
inner:  dex                             ; 2
        bne     inner                   ; 3 (taken) -> 256 x 5 - 1 cycles
        dec     delay_repeat
        bne     rep
        dey
        bne     unit
        rts
.endproc

; ---------------------------------------------------------------------
; c64u_send_string - transmit a zero-terminated string
;
; In:       A = low byte, Y = high byte of the string address
;           (string length 0..255 bytes, terminator not sent)
; Out:      nothing
; Modifies: A, Y, flags (X preserved)
; ---------------------------------------------------------------------
.proc c64u_send_string
        sta     load + 1                ; patch operand of the LDA below
        sty     load + 2
        ldy     #0
load:   lda     $FFFF,y                 ; operand patched above
        beq     done
        jsr     c64u_send               ; preserves Y
        iny
        bne     load
done:   rts
.endproc

; ---------------------------------------------------------------------
; c64u_modem_dial - send "ATDT" <host:port> <CR>
;
; In:       A = low byte, Y = high byte of a zero-terminated ASCII
;           "host:port" string, e.g. "192.168.0.64:3000"
; Out:      nothing (connection result is NOT evaluated here)
; Modifies: A, Y, flags (X preserved)
; ---------------------------------------------------------------------
.proc c64u_modem_dial
        pha                             ; save host string address
        tya
        pha
        lda     #<cmd_dial
        ldy     #>cmd_dial
        jsr     c64u_send_string
        pla
        tay
        pla
        jsr     c64u_send_string
        lda     #MODEM_CR
        jmp     c64u_send
.endproc

; ---------------------------------------------------------------------
; c64u_modem_answer - send "ATA" <CR> (answer after RING, p.159-160)
;
; In:       nothing
; Out:      nothing
; Modifies: A, Y, flags (X preserved)
; ---------------------------------------------------------------------
.proc c64u_modem_answer
        lda     #<cmd_answer
        ldy     #>cmd_answer
        jmp     c64u_send_string
.endproc

; ---------------------------------------------------------------------
; c64u_modem_hangup - escape to command mode and hang up
;
; In:       nothing
; Out:      nothing
; Modifies: A, X, Y, flags
;
; Sequence: ~1.5 s silence, "+++", ~1.5 s silence (>= S12 jiffies,
; p.159), "ATH" <CR>. Takes roughly 3 seconds.
; ---------------------------------------------------------------------
.proc c64u_modem_hangup
        lda     #MODEM_GUARD_UNITS
        jsr     c64u_delay
        lda     #MODEM_ESCAPE_CHAR
        jsr     c64u_send
        jsr     c64u_send
        jsr     c64u_send               ; c64u_send preserves A
        lda     #MODEM_GUARD_UNITS
        jsr     c64u_delay
        lda     #<cmd_hangup
        ldy     #>cmd_hangup
        jmp     c64u_send_string
.endproc

; ---------------------------------------------------------------------
; Data - ASCII command strings (ca65 default character mapping is
; identity, so these are plain ASCII bytes).
; ---------------------------------------------------------------------
.segment "RODATA"

cmd_dial:
        .byte   "ATDT", 0
cmd_answer:
        .byte   "ATA", MODEM_CR, 0
cmd_hangup:
        .byte   "ATH", MODEM_CR, 0

.segment "BSS"

delay_repeat:
        .res    1
