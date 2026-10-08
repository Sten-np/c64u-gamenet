; =====================================================================
; c64.inc - Commodore 64 system constants (original C64 behaviour)
; =====================================================================
;
; This file contains ONLY constants that apply to a stock Commodore 64.
; C64 Ultimate-specific hardware (e.g. the 6551 ACIA / SwiftLink
; emulation) must NOT be added here; it belongs in a separate,
; C64U-specific include file (Milestone 1).
;
; Sources:
;   CHROUT  - "6502 Assembly Language Programming for Apple, Commodore
;             and Atari Computers", pp. 98-99 and 111 (docs/reference/).
;   BASIC_* - Standard C64 BASIC V2 program format. NOT yet confirmed
;             by a project reference (the C64 BASIC reference is not
;             yet in docs/reference/). Needs verification.
;   PETSCII - Control codes used by the KERNAL screen editor. NOT yet
;             confirmed by a project reference. Needs verification.

.ifndef C64_INC
C64_INC = 1

; ---------------------------------------------------------------------
; KERNAL jump table
; ---------------------------------------------------------------------

; CHROUT - output the character in A to the current output device
; (the screen by default).
; The project references do not document which registers CHROUT
; preserves, so callers must not rely on X or Y surviving the call.
CHROUT              = $FFD2

; ---------------------------------------------------------------------
; BASIC program memory
; ---------------------------------------------------------------------

; Start of BASIC program text; the load address of a normal BASIC
; program / BASIC-stub machine-language program.
BASIC_START         = $0801

; BASIC V2 token for the SYS keyword.
BASIC_TOKEN_SYS     = $9E

; ---------------------------------------------------------------------
; PETSCII control codes
; ---------------------------------------------------------------------

PETSCII_RETURN      = $0D       ; carriage return / new line
PETSCII_CLEAR       = $93       ; clear screen, cursor home

.endif
