; =====================================================================
; hello.s - Milestone 0 minimal C64 program
; =====================================================================
;
; Purpose: prove that the toolchain and build system produce a valid,
; runnable C64 .prg. Contains NO networking code.
;
; Behaviour: clears the screen, prints a short banner through the
; KERNAL CHROUT routine and returns to BASIC (READY. prompt).
;
; Runs on a stock C64; uses no C64 Ultimate-specific hardware.

.include "c64.inc"

.export start

; ---------------------------------------------------------------------
; start - program entry point (called by the BASIC SYS stub)
;
; In:       nothing
; Out:      nothing
; Clobbers: A, X, Y (CHROUT register preservation is not documented
;           by the project references, so none is assumed)
; ---------------------------------------------------------------------
.segment "CODE"

.proc start
        lda     #0
        sta     msg_index
loop:
        ldx     msg_index
        lda     message,x
        beq     done                    ; zero terminator reached
        jsr     CHROUT
        inc     msg_index
        bne     loop                    ; message limited to 255 chars
done:
        rts                             ; back to BASIC
.endproc

; ---------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------
.segment "RODATA"

; Text uses upper-case ASCII letters only: with ca65's default
; (identity) character mapping these byte values coincide with the
; PETSCII upper-case letters shown in the C64's default character set.
message:
        .byte   PETSCII_CLEAR
        .byte   "C64U GAMENET", PETSCII_RETURN
        .byte   "MILESTONE 0 TOOLCHAIN OK", PETSCII_RETURN
        .byte   0

.assert (* - message) <= 256, error, "message too long for 8-bit index"

.segment "BSS"

msg_index:
        .res    1
