; prt_pos must be on the zero page for indirect addressing to work
.RAMSECTION "Printing" SLOT 1 ORG $ff SEMISUBFREE
	prt_pos   dw
	prt_mode  db
	prt_tmp   dw
	prt_nonz  db
	prt_fillc db
.ENDS

.RAMSECTION "TextBuffer" SLOT 1 ORG $800 SEMIFREE
	text_buffer instanceof array size $800
.ENDS

.SECTION "Text" SEMIFREE

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
		bne +
			; We get here if A is zero. Skip printing if prt_nonz is false
			lda prt_nonz
			bne ++
			lda prt_fillc ; use fill character instead
			++
			putc
			bra +++
		+ ; we get here if A is non-zero. print, and set prt_nonz to true
		putc
		lda #$01.b
		sta prt_nonz
		+++
		rts

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
		ldy #nbyte.w
		jsr print
		plp
	.ENDM

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

	; Move cursor to the offset given by the 16-bit accumulator
	set_cursor:
		asl
		clc
		adc #text_buffer.w
		sta prt_pos
		rts

	.MACRO set_cursor ARGS pos
		php
		rep #$20
		lda #pos.w
		jsr set_cursor
		plp
	.ENDM

.ENDS
