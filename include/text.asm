; prt_pos must be on the zero page for indirect addressing to work
.RAMSECTION "Printing" SLOT 1 ORG $ff SEMISUBFREE
	prt_pos  dw
	prt_mode db
.ENDS

.RAMSECTION "TextBuffer" SLOT 1 ORG $800 SEMIFREE
	text_buffer instanceof array size $800
.ENDS

.SECTION "Text" SEMIFREE

	; Print Y characters starting at address in X. Clobbers A,Y,X. A:8bit, XY:16bit
	print:
		; Write current character
		-
		lda     $0000,x
		sta     (prt_pos)
		inc     prt_pos
		; Write associated tile mode
		lda     prt_mode
		sta     (prt_pos)
		inc     prt_pos
		inx
		dey
		bne -
		rts

	.MACRO print ARGS src, nbyte
		php
		sep #$20
		rep #$10
		ldx.w #src
		ldy.w #nbyte
		jsr print
		plp
	.ENDM

.ENDS
