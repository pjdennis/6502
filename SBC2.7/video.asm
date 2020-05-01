;----------------------------------------------------------------------
; Output contents of A to the Video Display
;  A is preserved, Flags are changed.
;----------------------------------------------------------------------
VOutput
                bit  Via2PRB		;  read handshake byte (pb7)
                bmi  VOutput		;  if pb7=1, wait for AVR to be ready
                sta  Via2SR		; send to display via shift register
VOutput1
                bit  Via2PRB		; read handshake byte
                bpl  VOutput1		; if pb7=0, wait for AVR to ack
                rts
 
;----------------------------------------------------------------------
; Call this once to initialize the interface
; it sets up Port B, pin 7 and CB1/CB2 for serial mode
; A is changed and Flags are changed.
;----------------------------------------------------------------------
VInitDisp                                             
                sei 			; disable interrupts
                lda  Via2DDRB		; get ddr b
                and  #$7F		; force bit 7=0
                sta  Via2DDRB		; set bit 7 to input
                lda  Via2ACR		; get ACR contents
                and  #$E3		; mask bits 2,3,4
                ora  #$18		; set Shift out under control of PHI2 mode
                sta  Via2ACR		; store to acr
                lda  #$04		; shift register flag in IER
                sta  Via2IER		; disable shift register interrupts
                cli			; Enable Interrupts again
                rts			; done
 