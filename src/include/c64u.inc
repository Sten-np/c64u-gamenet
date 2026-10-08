; =====================================================================
; c64u.inc - C64 Ultimate communication interface constants
; =====================================================================
;
; C64 ULTIMATE-SPECIFIC. A stock C64 has no device at these addresses.
; INTERNAL to the C64U communication layer (src/c64u/). Game code and
; the future public GameNet API must not include this file.
;
; Sources (details and open questions: docs/c64u-communication.md):
;   [UG]  C64U User Guide, 1st ed. (docs/reference/), ch. 12,
;         printed pp. 157-160: MOS 6551 ACIA emulation, mapping
;         "DE00/NMI", hardware mode "SwiftLink", AT commands.
;   [WDC] W65C51N datasheet (WDC, 2024), pp. 11-15: register bits.
;         EXTERNAL reference - bit meanings as emulated by the C64U
;         are NOT verified yet (Open Questions 1 and 2).
;   [CMP] COMPUTE! #10 "Experimenting with the 6551 ACIA": register
;         offsets 0-3, TDRE=$10, RDRF=$08. EXTERNAL reference.

.ifndef C64U_INC
C64U_INC = 1

; ---------------------------------------------------------------------
; ACIA (6551) registers
; ---------------------------------------------------------------------

; Base address for the C64U Modems setting "ACIA (6551) Mapping" =
; "DE00/NMI" [UG p.157]. Change only together with that setting.
ACIA_BASE           = $DE00

; Register offsets [CMP], [WDC].
ACIA_DATA           = ACIA_BASE + 0 ; R: receive data   W: transmit data
ACIA_STATUS         = ACIA_BASE + 1 ; R: status         W: programmed reset
ACIA_COMMAND        = ACIA_BASE + 2 ; R/W: command register
ACIA_CONTROL        = ACIA_BASE + 3 ; R/W: control register

; ---------------------------------------------------------------------
; Status register bits [WDC p.11]
; ---------------------------------------------------------------------

ACIA_ST_PE          = %00000001     ; parity error
ACIA_ST_FE          = %00000010     ; framing error
ACIA_ST_OVRN        = %00000100     ; overrun (byte lost)
ACIA_ST_RDRF        = %00001000     ; receive data register full
ACIA_ST_TDRE        = %00010000     ; transmit data register empty
ACIA_ST_DCD         = %00100000     ; DCD line: 0 = carrier detected
ACIA_ST_DSR         = %01000000     ; DSR line: 0 = data set ready
ACIA_ST_IRQ         = %10000000     ; interrupt occurred (cleared on read)

ACIA_ST_ERRORS      = ACIA_ST_PE | ACIA_ST_FE | ACIA_ST_OVRN

; ---------------------------------------------------------------------
; Command register bits [WDC pp.14-15]
; ---------------------------------------------------------------------

ACIA_CMD_DTR        = %00000001     ; 1 = DTR active (terminal ready)
ACIA_CMD_RX_IRQ_OFF = %00000010     ; 1 = receiver interrupt disabled
ACIA_CMD_RTS_ON     = %00001000     ; bits 3-2 = 10: RTS low, TX IRQ off
; Bit 4 (echo) and bits 7-5 (parity) are left 0: no echo, no parity.

; ---------------------------------------------------------------------
; Control register bits [WDC pp.11-12]
; ---------------------------------------------------------------------

ACIA_CTL_BAUD_19200 = %00001111     ; bits 3-0: rate code 19,200
ACIA_CTL_RX_BAUDGEN = %00010000     ; receiver clock = baud generator
ACIA_CTL_8BITS      = %00000000     ; bits 6-5 = 00: 8 data bits
; Bit 7 = 0: one stop bit.

; ---------------------------------------------------------------------
; Values used by the communication layer (docs/c64u-communication.md)
; ---------------------------------------------------------------------

; 8N1, internal clock, rate code 19,200 (the only rate shown in
; [UG p.158]; whether the emulation uses it is Open Question 3).
C64U_ACIA_CONTROL   = ACIA_CTL_8BITS | ACIA_CTL_RX_BAUDGEN | ACIA_CTL_BAUD_19200

; DTR active (modem state "Ready", [UG p.160]), polled operation:
; receiver and transmitter interrupts disabled, so no NMI is requested
; (NMI behaviour is undocumented - Open Question 6).
C64U_ACIA_COMMAND   = ACIA_CMD_DTR | ACIA_CMD_RX_IRQ_OFF | ACIA_CMD_RTS_ON

; DTR inactive -> modem state "Offline" [UG p.160]. Interrupts off.
C64U_ACIA_COMMAND_OFF = ACIA_CMD_RX_IRQ_OFF

; ---------------------------------------------------------------------
; Modem command characters [UG pp.158-159]
; ---------------------------------------------------------------------

MODEM_CR            = $0D           ; command terminator (RETURN)
MODEM_ESCAPE_CHAR   = '+'           ; default escape character (S2)

; ---------------------------------------------------------------------
; Timing (approximate; see c64u_delay in src/c64u/modem.s)
; ---------------------------------------------------------------------

; Guard time around "+++" in units of c64u_delay (~10 ms each).
; [UG p.159]: at least S12 jiffies (default 50 = 1 s) after "+++".
MODEM_GUARD_UNITS   = 150           ; ~1.5 s

.endif
