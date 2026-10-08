; =====================================================================
; acia.s - C64U communication layer: 6551 ACIA access (polled)
; =====================================================================
;
; INTERNAL module (architecture layer 3). This is the only GameNet
; module that touches the ACIA registers. It is NOT the public GameNet
; API; routine names and conventions are not final.
;
; C64 ULTIMATE REQUIREMENT: the C64U modem emulation must be enabled
; with "ACIA (6551) Mapping" = DE00/NMI and "Hardware Mode" = SwiftLink
; (C64U User Guide p.157). See docs/c64u-communication.md.
;
; Resources: no zero page, 1 byte BSS, no interrupts, no vectors.
; ACIA interrupts are kept disabled (polled operation only).

.include "c64u.inc"

.export c64u_init
.export c64u_status
.export c64u_send
.export c64u_receive
.export c64u_shutdown
.export c64u_rx_status

.segment "CODE"

; ---------------------------------------------------------------------
; c64u_init - prepare the ACIA for polled 8N1 operation, DTR active
;
; In:       nothing
; Out:      nothing
; Modifies: A, flags
;
; Setting DTR moves the C64U modem from "Offline" to "Ready" (User
; Guide p.160), so an answering C64U can accept calls afterwards.
; ---------------------------------------------------------------------
.proc c64u_init
        sta     ACIA_STATUS             ; programmed reset (value ignored)
        lda     #C64U_ACIA_CONTROL
        sta     ACIA_CONTROL
        lda     #C64U_ACIA_COMMAND
        sta     ACIA_COMMAND
        lda     ACIA_DATA               ; discard any stale received byte
        lda     ACIA_STATUS             ; clear the IRQ flag (bit 7)
        sta     c64u_rx_status
        rts
.endproc

; ---------------------------------------------------------------------
; c64u_status - read the raw ACIA status register
;
; In:       nothing
; Out:      A = status register (ACIA_ST_* bits); N, Z set from A
; Modifies: A, flags
;
; Side effect: reading the status register clears bit 7 (IRQ flag).
; ---------------------------------------------------------------------
.proc c64u_status
        lda     ACIA_STATUS
        rts
.endproc

; ---------------------------------------------------------------------
; c64u_send - transmit one byte (blocking poll)
;
; In:       A = byte to send
; Out:      nothing
; Modifies: flags only (A, X, Y preserved)
;
; Waits until the transmit data register is empty, then writes A.
; Never times out. Poll loop: 9 cycles per iteration.
; ---------------------------------------------------------------------
.proc c64u_send
        pha
wait:   lda     ACIA_STATUS             ; 4
        and     #ACIA_ST_TDRE           ; 2
        beq     wait                    ; 3 (taken)
        pla
        sta     ACIA_DATA
        rts
.endproc

; ---------------------------------------------------------------------
; c64u_receive - fetch one received byte if available (non-blocking)
;
; In:       nothing
; Out:      C = 1: A = received byte
;           C = 0: no byte waiting, A = 0
;           c64u_rx_status = status register value read by this call
;                            (test with ACIA_ST_ERRORS for PE/FE/OVRN)
; Modifies: A, flags (X, Y preserved)
;
; About 21 cycles (excluding JSR/RTS) when no byte is waiting.
; ---------------------------------------------------------------------
.proc c64u_receive
        lda     ACIA_STATUS
        sta     c64u_rx_status
        and     #ACIA_ST_RDRF
        beq     none                    ; A = 0
        lda     ACIA_DATA               ; reading data clears RDRF
        sec
        rts
none:   clc
        rts
.endproc

; ---------------------------------------------------------------------
; c64u_shutdown - set DTR inactive (modem state "Offline", p.160)
;
; In:       nothing
; Out:      nothing
; Modifies: A, flags
;
; Does not hang up an active call; use c64u_modem_hangup first.
; ---------------------------------------------------------------------
.proc c64u_shutdown
        lda     #C64U_ACIA_COMMAND_OFF
        sta     ACIA_COMMAND
        rts
.endproc

.segment "BSS"

; Status register value read by the most recent c64u_receive call.
c64u_rx_status:
        .res    1
