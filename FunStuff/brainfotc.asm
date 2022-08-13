; -----------------------------------------------------------------------------
; Implementation of the Brain F--k compiler in 6502 assembly.
;
; The goal of the challege is to create another Turing tarpit using the least
; number of instructions. But this time using the inherent simplicity of the
; Brain f--k VM to enforce it. Since Brain f--k is Turing complete you can (in
; theory) compute any problem with just the instructions required to write it.
;
; This version of the Brain f--k compiler compiles programs into 6502 machine
; code. When executed the machine code uses the underlying hardware as the code
; threading mechanism. Eliminating function calls creates a faster Brain f--k
; impementation than the prior versions. Optimizations further increase the
; speed.
;
; Derived from prior version by Martin Heermance <mheermance@gmail.com>
;
; Phil Dennis <pjdennis@gmail.com>
; -----------------------------------------------------------------------------

;
; Aliases
;

; Character set (ASCII)
.alias AscLT	$3C	; Character aliases for brain f commands.
.alias AscGT	$3E
.alias AscQues	$3F
.alias AscPlus	$2B
.alias AscComma $2C
.alias AscMinus	$2D
.alias AscDot	$2E
.alias AscLB	$5B
.alias AscRB	$5D

.alias StateDefault	$00
.alias StateModCell	$01
.alias StateModDptr	$02

.alias cellsSize [cellsEnd - cells]
.alias codeSize [codeEnd - code]

;
; Data segments
;
.data ZPDATA
.org $0080		; we'll need to use ZP addressing
.space dptr 2		; word to hold the data pointer.
.space iptr 2		; word to hold the instruction pointer.
.space temp 2		; word to hold popped PC for code generation.
.space fixup 2		; word to hold popped PC to fixup forward branch.
.space cptr 2		; word to hold pointer for code to copy.
.space ccnt 1		; byte to hold count of code to copy.
.space state 1		; current parser state
.space cellDelta 1	; cell delta
.space dptrDelta 2	; dptr delta

.data BSS
.org $0300		; page 3 is used for uninitialized data.
.space cells 1024	; cells is currently 1K
.space cellsEnd 0

.space code 24576	; code buffer is currently 24K
.space codeEnd 0

.text

;
; Macros
;

.macro decw
        lda _1
        bne _over
        dec _1+1
_over:  dec _1
.macend

.macro incw
        inc _1
        bne _over
        inc _1+1
_over:
.macend

.macro addwbi		; add word and byte immediate
	clc
	lda _1
	adc #_2
	sta _1
	bcc _over
	inc _1+1
_over:
.macend

.macro emitCode
	lda #<_1
	sta cptr
	lda #>_1
	sta cptr + 1
	lda #_2 - _1
	sta ccnt
	jsr copyCode
.macend

.org $8000
.outfile "brainfotc.rom"
.advance $8000

;
; Functions
;
main:
	; Set the instruction pointer to the classic hello world program.
	;lda #<helloWorld
	;sta iptr
	;lda #>helloWorld
	;sta iptr+1
	;jsr runProgram

	; set the instruction pointer to the Sierpinski triangle program.
	lda #<sierpinski
	sta iptr
	lda #>sierpinski
	sta iptr+1
	jsr runProgram

	; set the instruction pointer to the Golden ratio program.
	;lda #<golden
	;sta iptr
	;lda #>golden
	;sta iptr+1
	;jsr runProgram
	brk

runProgram:
	jsr compile	; translate source into executable code
	jmp code	; directly execute the code

; compile scans the characters and produces a machine code stream.
compile:
.scope
	lda #<code	; use dptr as the index into the code
	sta dptr
	lda #>code
	sta dptr+1
	
	lda #StateDefault
	sta state
	lda #0
	sta cellDelta
	sta dptrDelta
	sta dptrDelta + 1

	; All programs start with memory cell initialization.
	`emitCode initCells,initCellsEnd

_while:	lda (iptr)
	bne _incCell

	jsr stateToDefault
	`emitCode endProgram,endProgramEnd
	rts

_incCell:
	cmp #AscPlus
	bne _decCell
	
	lda state
	cmp #StateModCell
	beq +
	jsr stateToDefault
	lda #StateModCell
	sta state
*	inc cellDelta
	jmp _next

_decCell:
	cmp #AscMinus
	bne _decDptr

	cmp #StateModCell
	beq +
	jsr stateToDefault
	lda #StateModCell
	sta state
*	dec cellDelta
	jmp _next

_decDptr:
	cmp #AscLT
	bne _incDptr

	lda state
	cmp #StateModDptr
	beq +
	jsr stateToDefault
	lda #StateModDptr
	sta state
*	`decw dptrDelta
	jmp _next

_incDptr:
	cmp #AscGT
	bne _outputCell

	lda state
	cmp #StateModDptr
	beq +
	jsr stateToDefault
	lda #StateModDptr
	sta state
*	`incw dptrDelta
	jmp _next

_outputCell:
	pha
	jsr stateToDefault
	pla

	cmp #AscDot
	bne _inputCell

	`emitCode outputCell,outputCellEnd
	jmp _next

_inputCell:
	cmp #AscComma
	bne _leftBracket

	`emitCode incCell,inputCellEnd
	jmp _next

_leftBracket:
	cmp #AscLB
	bne _rightBracket

	lda dptr+1	; push current PC for later.
	pha
	lda dptr
	pha

	`emitCode branchForward,branchForwardEnd	
	jmp _next

_rightBracket:
	cmp #AscRB
	bne _debugOut

	pla		; get the return PC off the stack
	sta fixup
	sta temp
	pla
	sta fixup+1
	sta temp+1
	
	`addwbi fixup, branchForwardJumpInstruction - branchForward + 1
	
	lda dptr	; fixup jump address for left bracket
	sta (fixup)
	`incw fixup
	lda dptr+1
	sta (fixup)

	`emitCode branchBackward,branchBackwardJumpInstruction + 1
	
	lda temp	; store backwards jump address
	sta (dptr)
	`incw dptr
	lda temp+1
	sta (dptr)
	`incw dptr

	jmp _next

_debugOut:
	cmp #AscQues
	bne _ignoreInput

	`emitCode debugOut,debugOutEnd
	jmp _next

_ignoreInput:		;  All other characters are ignored.

_next:	`incw iptr
	jmp _while
.scend

stateToDefault:
.scope
	lda state
	cmp #StateDefault
	bne _stateModCell	

	rts

_stateModCell:
.scope
	cmp #StateModCell
	bne _stateModDptr
	
	lda cellDelta
	cmp #$01
	bne _decrement
	`emitCode incCell,incCellEnd
	jmp _done
	
_decrement:
	cmp #$ff
	bne _add
	`emitCode decCell,decCellEnd
	jmp _done

_add:
	`emitCode modCell, modCellAdd+1
	lda cellDelta
	sta (dptr)
	`incw dptr
	`emitCode modCellAdd+2,modCellEnd
	
_done:
	lda #0
	sta cellDelta
	lda #StateDefault
	sta state
	rts
.scend

_stateModDptr:
.scope
	lda dptrDelta+1
	bne _decrement
	lda dptrDelta
	cmp #$01
	bne _addByte
	`emitCode incDptr,incDptrEnd
	jmp _done

_addByte:
	`emitCode addDptrByte,addDptrByteAdd+1
	lda dptrDelta
	sta (dptr)
	`incw dptr
	`emitCode addDptrByteAdd+2,addDptrByteEnd
	jmp _done

_decrement:
	lda dptrDelta
	cmp #$ff
	bne _add
	lda dptrDelta+1
	bne _add
	`emitCode decDptr,decDptrEnd
	jmp _done

_add:
	`emitCode modDptr,modDptrAddLow+1
	lda dptrDelta
	sta (dptr)
	`incw dptr
	`emitCode modDptrAddLow+2,modDptrAddHigh+1
	lda dptrDelta+1
	sta (dptr)
	`incw dptr
	`emitCode modDptrAddHigh+2,modDptrEnd

_done:
	lda #0
	sta dptrDelta
	sta dptrDelta + 1
	lda #StateDefault
	sta state
	rts
.scend
.scend

copyCode:
_loop:
	lda (cptr)
	sta (dptr)
	`incw cptr
	`incw dptr
	dec ccnt
	bne _loop
	
	rts

;
; These secions of code function as the threaded code to execute programs.
;

initCells:
	lda #<cells
	sta dptr
	lda #>cells
	sta dptr+1
.scope
_loop:
	lda #$00
	sta (dptr)
	`incw dptr
	lda dptr+1
	cmp #>cellsEnd
	bne _loop

	; set the dptr back to the start of the cells.
	lda #<cells
	sta dptr
	lda #>cells
	sta dptr+1
.scend
initCellsEnd:

incCell:
	lda (dptr)
	inc
	sta (dptr)
incCellEnd:

decCell:
	lda (dptr)
	dec
	sta (dptr)
decCellEnd:

modCell:
	clc
	lda (dptr)
modCellAdd:
	adc #0		; placeholder
	sta (dptr)
modCellEnd:

decDptr:
	`decw dptr
decDptrEnd:

incDptr:
	`incw dptr
incDptrEnd:

addDptrByte:
	clc
	lda dptr
addDptrByteAdd:
	adc #0		; placeholder
	sta dptr
	bcc +
	inc dptr+1
*
addDptrByteEnd:

modDptr:
	clc
	lda dptr
modDptrAddLow:
	adc #0		; placeholder
	sta dptr
	lda dptr + 1
modDptrAddHigh:
	adc #0		; placeholder
	sta dptr + 1
modDptrEnd:

outputCell:
	lda (dptr)
	jsr _putch
outputCellEnd:

inputCell:
	jsr _getch
	sta (dptr)
inputCellEnd:

branchForward:
	lda (dptr)
	bne +		; Branch on data cell containing zero
branchForwardJumpInstruction:
	jmp 0		; placeholder
*
branchForwardEnd:

branchBackward:
	lda (dptr)
	beq +		; Branch on data cell containing zero
branchBackwardJumpInstruction:
	jmp 0		; placeholder
*

debugOut:
	brk		; unimplemented for now
debugOutEnd:

endProgram:
	rts		; return to calling program.
endProgramEnd:

helloWorld:
	.byte "++++++++"
	.byte "[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]"
	.byte ">>.>---.+++++++..+++.>>.<-.<.+++."
	.byte "------.--------.>>+.>++."
	.byte 0

; Fibonacci number generator by Daniel B Cristofani
; This program doesn't terminate; you will have to kill it.
fibonacci:
	.byte ">++++++++++>+>+["
	.byte "[+++++[>++++++++<-]>.<++++++[>--------<-]+<<<]>.>>["
        .byte "[-]<[>+<-]>>[<<+>+>-]<[>+<-[>+<-[>+<-[>+<-[>+<-[>+<-"
        .byte "[>+<-[>+<-[>+<-[>[-]>+>+<<<-[>+<-]]]]]]]]]]]+>>>"
	.byte "]<<<"
	.byte "]",0

; Shows an ASCII representation of the Sierpinski triangle
; (c) 2016 Daniel B. Cristofani
sierpinski:
	.byte "++++++++[>+>++++<<-]>++>>+<[-[>>+<<-]+>>]>+["
	.byte "-<<<["
	.byte "->[+[-]+>++>>>-<<]<[<]>>++++++[<<+++++>>-]+<<++.[-]<<"
	.byte "]>.>+[>>]>+"
	.byte "]", 0

; Compute the "golden ratio". Because this number is infinitely long,
; this program doesn't terminate on its own. You will have to kill it.
golden:
	.byte "+>>>>>>>++>+>+>+>++<["
	.byte "  +["
	.byte "    --[++>>--]->--["
	.byte "      +["
	.byte "        +<+[-<<+]++<<[-[->-[>>-]++<[<<]++<<-]+<<]>>>>-<<<<"
	.byte "          <++<-<<++++++[<++++++++>-]<.---<[->.[-]+++++>]>[[-]>>]"
	.byte "          ]+>>--"
	.byte "      ]+<+[-<+<+]++>>"
	.byte "    ]<<<<[[<<]>>[-[+++<<-]+>>-]++[<<]<<<<<+>]"
	.byte "  >[->>[[>>>[>>]+[-[->>+>>>>-[-[+++<<[-]]+>>-]++[<<]]+<<]<-]<]]>>>>>>>"
	.byte "]"

; conio functions unique to each platform.
.alias _py65_putc	$f001	; Definitions for the py65mon emulator
.alias _py65_getc	$f004

_getch:
.scope
*	lda _py65_getc
	beq -
	rts
.scend

_putch:
.scope
	sta _py65_putc
	rts
.scend

; Interrupt handler for RESET button, also boot sequence.
; Note: This doesn't count for the restricted instruction challenge as
; these steps are required to set the hardware to a known state.
.scope
resetv:
	sei		; diable interupts, until interupt vectors are set.
	cld		; clear decimal mode
	ldx #$FF	; reset stack pointer
	txs

	lda #$00	; clear all three registers
	tax
	tay

	pha		; clear all flags
	plp
	jmp main	; go to monitor or main program initialization.
.scend

; redirect the NMI interrupt vector here to be safe, but this 
; should never be reached for py65mon.
irqv:
nmiv:
panic:
	brk

; Interrupt vectors.
.advance $FFFA

.word nmiv		; NMI vector 
.word resetv		; RESET vector
.word irqv		; IRQ vector