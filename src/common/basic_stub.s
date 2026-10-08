; =====================================================================
; basic_stub.s - BASIC loader line for machine-language programs
; =====================================================================
;
; Emits the two-byte PRG load address followed by a one-line BASIC
; program:
;
;     10 SYS <start>
;
; so the program can be started with RUN after LOAD, and so the
; C64 Ultimate Disk File Browser (which "resets the computer, copies
; the program into memory, and runs it" - C64U User Guide, "Using PRG
; and T64 Files", p. 27) can launch it.
;
; The program must export the symbol `start` (its entry point).
;
; NOTE: The BASIC line format (link pointer, line number, token,
; zero terminator, zero link) is standard C64 BASIC V2 behaviour that
; is not yet covered by a project reference. Needs verification.

.include "c64.inc"

.import start

; ---------------------------------------------------------------------
; PRG load address (first two bytes of the .prg file, little endian).
; The LOADADDR segment is placed two bytes before the program start
; by the linker configuration, so `* + 2` is the load address.
; ---------------------------------------------------------------------
.segment "LOADADDR"
        .addr   * + 2

; ---------------------------------------------------------------------
; BASIC line: 10 SYS <start>
; ---------------------------------------------------------------------
.segment "EXEHDR"

basic_line:
        .addr   basic_end               ; link to next BASIC line
        .word   10                      ; line number
        .byte   BASIC_TOKEN_SYS
        ; Entry address as four ASCII decimal digits (computed by the
        ; linker, because `start` is relocatable).
        .byte   <(((start / 1000) .mod 10) + '0')
        .byte   <(((start /  100) .mod 10) + '0')
        .byte   <(((start /   10) .mod 10) + '0')
        .byte   <(( start         .mod 10) + '0')
        .byte   0                       ; end of BASIC line
basic_end:
        .word   0                       ; end of BASIC program

; Four digits are emitted above; fail the link if that is not enough.
.assert start >= 1000 && start <= 9999, error, "start must be a 4-digit decimal address"
