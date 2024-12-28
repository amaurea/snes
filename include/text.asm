; prt_pos must be on the zero page for indirect addressing to work
.RAMSECTION "Printing" SLOT 1 ORG $ff SEMISUBFREE
	prt_pos   dw
	prt_mode  db
	prt_tmp   dw
	prt_nonz  db
	prt_fillc db
.ENDS

.RAMSECTION "TextBuffer" SLOT 1 ORG $800 SEMIFREE
	text_buffer ds $800
.ENDS

.SECTION "Text" SEMIFREE

	chr_space: .ASC " "

	; The character printing part of this should be rewritten to
	; have the string and length in variables in ram instead of
	; all this register juggling.

	; Write a character in the accumulator to the buffer. Overwrites A
	.MACRO putc
		sta (prt_pos)
		inc prt_pos
		lda prt_mode
		sta (prt_pos)
		inc prt_pos
	.ENDM

	; Write a character in the accumulator to the buffer. If it is zero
	; and prt_nonz is false, print prt_fillc instead. If non-zero, set prt_nonz to true.
	lead_putc:
		phx
		php
		sep #$10
		bne +
			; We get here if A is zero. Skip printing if prt_nonz is false
			ldx prt_nonz
			bne ++
			lda prt_fillc ; use fill character instead
			++
			putc
			bra +++
		+ ; we get here if A is non-zero. print, and set prt_nonz to true
		putc
		ldx #$01.b
		stx prt_nonz
		+++
		plp
		plx
		rts

	; Write X copies of the character in A. 8-bit A, 16-bit X
	repc:
		-
		putc
		dex
		bne -
		rts
	
	.MACRO repc ARGS chr, count
		pha
		phx
		php
		sep #$20
		rep #$10
		lda #chr.b
		ldx #count.W
		jsr repc
		plp
		plx
		pla
	.ENDM

	; Print Y characters starting at address in X. Clobbers A,Y,X. A:8bit, XY:16bit
	print:
		; Write current character
		-
		lda     $0000,x
		putc
		inx
		dey
		bne -
		rts

	.MACRO print ARGS src, nbyte
		php
		sep #$20
		rep #$10
		ldx #src.w
		.IF \?2 == ARG_NUMBER
			ldy #nbyte.w
		.ELIF \?2 == ARG_LABEL
			ldy nbyte
		.ELSE
			.FAIL "Unsupported type\n"
		.ENDIF
		jsr print
		plp
	.ENDM

	;.MACRO prints ARGS str
	;	_str: .ASC str
	;	print _str str.length
	;	.UNDEFINE _str
	;.ENDM

	; Number printing. Interesting cases:
	; 1. arbitrary long number at memory location. Similar to print above
	; 2. single byte in accumulator
	; 3. either of these, with skipping of leading zeros
	; In either case, the printing should be big endian. Let's start with the
	; single-byte, no skipping one as a macro

	; number in 8-bit A
	print_hexbyte:
		; save full number so we don't lose the low nibble
		sta prt_tmp
		; print the high nibble
		lsr
		lsr
		lsr
		lsr
		putc
		; print the low nibble
		lda prt_tmp
		and #$0f.b
		putc
		rts

	; To use, put number in 8-bit A, set prt_nonz to zero, and set prt_fillc to
	; the character to replace leading zeros with. This function can be safely
	; chained.
	lead_print_hexbyte:
		; save full number so we don't lose the low nibble
		sta prt_tmp
		; print the high nibble
		lsr
		lsr
		lsr
		lsr
		jsr lead_putc
		; print the low nibble
		lda prt_tmp
		and #$0f.b
		jsr lead_putc
		rts

	; Arbitrary-length version of print_hexbyte.
	; Clobbers A,X,Y. 8-bit A. 16-bit XY. Set X to address of number, Y to its length
	print_hex:
		; start at last byte, so add Y-1 to X
		jsr xplusy
		-
		dex
		dey
		bmi +
		lda $0,x
		jsr print_hexbyte
		bra -
		+
		rts

	.MACRO print_hex ARGS src, nbyte
		php
		rep #$10
		sep #$20
		ldx #src.w
		ldy #nbyte.w
		jsr print_hex
		plp
	.ENDM

	; Arbitrary-length version of lead_print_hexbyte.
	; Clobbers A,X,Y. 8-bit A. 16-bit XY. Set X to address of number, Y to its length
	lead_print_hex:
		stz prt_nonz
		; start at last byte, so add Y-1 to X
		jsr xplusy
		-
		dex
		dey
		bmi +
		lda $0,x
		jsr lead_print_hexbyte
		bra -
		+
		rts

	.MACRO lead_print_hex ARGS src, nbyte
		php
		rep #$10
		sep #$20
		ldx #src.w
		ldy #nbyte.w
		jsr lead_print_hex
		plp
	.ENDM

	; Add y to x, 16-bit. Clobbers A and prt_tmp. Surprisingly complicated!
	; Would it be better to use the stack? Not familiar with ,s adddressing yet
	; Actually, should have just used normal ram. Much simpler.
	xplusy:
		php
		rep #$20
		sty prt_tmp
		txa
		clc
		adc prt_tmp
		tax
		plp
		rts
	
	; Put the cursor's current 16-bit position into A. The lowest
	; 5 bits will be x, the rest will be y
	get_cursor:
		lda prt_pos
		sec
		sbc #text_buffer.w
		lsr
		rts

	; get the cursor x coordinate
	get_cursor_x:
		jsr get_cursor
		and #$001f.w
		rts

	; get the cursor y coordinate
	get_cursor_y:
		jsr get_cursor
		lsr
		lsr
		lsr
		lsr
		lsr
		lsr
		rts

	; Move cursor to the offset given by the 16-bit accumulator
	set_cursor:
		asl
		clc
		adc #text_buffer.w
		sta prt_pos
		rts

	; AND the binary mask in the accumulator with the cursor position
	mask_cursor_pos:
		phx
		tax
		jsr get_cursor
		sta prt_tmp
		txa
		and prt_tmp
		jsr set_cursor
		plx
		rts

	; set cursor x position without changing y. Surprisingly involved!
	set_cursor_x:
		phx
		tax
		lda #$ffe0.w
		jsr mask_cursor_pos
		txa
		jsr move_cursor_x
		plx
		rts

	; set cursor y position without changing x
	set_cursor_y:
		phx
		tax
		lda #$001f.w
		jsr mask_cursor_pos
		txa
		jsr move_cursor_y
		plx
		rts

	; Set cursor to the beginning of the given line. Faster way of doing
	; set_cursor_x(0), set_cursor_y(A)
	set_cursor_yleft:
		asl
		asl
		asl
		asl
		asl
		jsr set_cursor
		rts

	; Move cursor by the number of places given by the 16-bit accumulator
	move_cursor:
	move_cursor_x:
		asl
		clc
		adc prt_pos
		sta prt_pos
		rts

	move_cursor_y:
		asl
		asl
		asl
		asl
		asl
		jsr move_cursor
		rts

	; Move by this amount in y, and set x to 0
	move_cursor_yleft:
		sta $1234
		jsr move_cursor_y
		lda #$ffe0.w
		jsr mask_cursor_pos
		rts

	.MACRO set_cursor ARGS arg
		funAw set_cursor arg
	.ENDM
	.MACRO set_cursor_x ARGS arg
		funAw set_cursor_x arg
	.ENDM
	.MACRO set_cursor_y ARGS arg
		funAw set_cursor_y arg
	.ENDM
	.MACRO set_cursor_yleft ARGS arg
		funAw set_cursor_yleft arg
	.ENDM
	.MACRO move_cursor ARGS arg
		funAw move_cursor arg
	.ENDM
	.MACRO move_cursor_x ARGS arg
		funAw move_cursor_x arg
	.ENDM
	.MACRO move_cursor_y ARGS arg
		funAw move_cursor_y arg
	.ENDM
	.MACRO move_cursor_yleft ARGS arg
		funAw move_cursor_yleft arg
	.ENDM

	.MACRO set_print_mode ARGS mode
		pha
		php
		sep #$20
		lda #mode.b
		sta prt_mode
		plp
		pla
	.ENDM

	; Macro for alling a function that takes 16-bit A as argument
	.MACRO funAw ARGS fun, arg
		php
		rep #$30
		.IF \?2 == ARG_NUMBER
			lda #arg.w
		.ELIF \?2 == ARG_LABEL
			lda arg
		.ELSE
			.FAIL "Unsupported type\n"
		.ENDIF
		jsr fun
		plp
	.ENDM

	.MACRO mkstr ARGS label, str
		#label: .ASC str
		#label_size: str.length
	.ENDM

.ENDS
