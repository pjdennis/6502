;
; Data segments
;
.data ZPDATA
.space bufferReadPos 2	; input buffer read position
.space bufferWritePos 2 ; input buffer write position

.data BSS
.space inputBuffer 256	; whole page buffer for inputting line at a time

.text

; Initialize the input buffer
_initializeInputBuffer:
	lda #<inputBuffer
	sta bufferReadPos
	sta bufferWritePos
	lda #>inputBuffer
	sta bufferReadPos+1
	sta bufferWritePos+1
	rts

; buffer characters until newline and then return all characters
; backspace will remove last character from buffer
; echo characters as they are entered
; ignore additional typed characters once buffer is full
_getchar:
.scope
	lda bufferReadPos
	cmp bufferWritePos
	bne _returnValue	; buffer not empty
_loop:
	jsr _getch
	cmp #8			; backspace
	bne _notBackspace
	; handle backspace
	lda bufferReadPos
	cmp bufferWritePos
	beq _loop		; buffer empty so nothing to do
	dec bufferWritePos	; remove last character from buffer
	lda #8			; delete last character
	jsr _putch
	lda #32
	jsr _putch
	lda #8
	jsr _putch
	jmp _loop		; backspace handled
_notBackspace:
	sta (bufferWritePos)
	cmp #10			; newline
	bne _notNewline
	jsr _putch
	inc bufferWritePos
	jmp _returnValue
_notNewline:
	lda bufferWritePos
	inc
	cmp bufferReadPos
	beq _loop		; ignore input if buffer full
	lda (bufferWritePos)
	jsr _putch
	inc bufferWritePos
	jmp _loop
_returnValue:
	lda (bufferReadPos)
	inc bufferReadPos
	rts
.scend

; conio functions unique to each platform.
.alias _py65_putc	$f001	; Definitions for the py65mon emulator
.alias _py65_getc	$f004

_getch:
.scope
*	lda _py65_getc
	beq -
	cmp #13		; convert CR to LF so as to be compliant on Windows
	bne +
	lda #10
*	rts
.scend

_putch:
.scope
	sta _py65_putc
	rts
.scend