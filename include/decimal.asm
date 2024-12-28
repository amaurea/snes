; Our work variables should be on the direct page
.RAMSECTION "DecimalRam" SLOT 1 ORG $ff SEMISUBFREE
	dec_bin ds 4
	dec_dec ds 6
.ENDS

.SECTION "Decimal"

	; Based on a post by bitwise (Andrew Jacobs)

	; Convert 2 bytes of binary data into 3 bytes of decimal data.
	; Call with dec_bin filled with the values
	bin2dec_16:
		pha
		phx
		php
		sep #$30
		; zero-initialize output
		stz dec_dec+0
		stz dec_dec+1
		stz dec_dec+2
		; Go to decimal mode
		sed
		; loop over our 16 bits
		ldx #16
		-
		asl dec_bin+0
		rol dec_bin+1
		lda dec_dec+0
		adc dec_dec+0
		sta dec_dec+0
		lda dec_dec+1
		adc dec_dec+1
		sta dec_dec+1
		lda dec_dec+2
		adc dec_dec+2
		sta dec_dec+2
		dex
		bne -
		plp
		plx
		pla
		rts

	; Convert 4 bytes of binary data into 6 bytes of decimal data.
	; Call with dec_bin filled with the values
	bin2dec_32:
		pha
		phx
		php
		sep #$30
		; zero-initialize output
		stz dec_dec+0
		stz dec_dec+1
		stz dec_dec+2
		stz dec_dec+3
		stz dec_dec+4
		stz dec_dec+5
		; Go to decimal mode
		sed
		; loop over our 32 bits
		ldx #32
		-
		asl dec_bin+0
		rol dec_bin+1
		rol dec_bin+2
		rol dec_bin+3
		lda dec_dec+0
		adc dec_dec+0
		sta dec_dec+0
		lda dec_dec+1
		adc dec_dec+1
		sta dec_dec+1
		lda dec_dec+2
		adc dec_dec+2
		sta dec_dec+2
		lda dec_dec+3
		adc dec_dec+3
		sta dec_dec+3
		lda dec_dec+4
		adc dec_dec+4
		sta dec_dec+4
		lda dec_dec+5
		adc dec_dec+5
		sta dec_dec+5
		dex
		bne -
		plp
		plx
		pla
		rts

.ENDS
