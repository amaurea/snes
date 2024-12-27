; Our work variables should be on the direct page
.RAMSECTION "Sorting" SLOT 1 ORG $ff SEMISUBFREE
	srt_ptr    dw ; pointer to array to sort
	srt_nbyte  dw ; length of this array, in bytes
	srt_step   dw ; which step in the sorting progress we're at
	sift_start dw ; start offset of array to sift
	sift_end   dw ; end   offset of array to sift
	sift_root  dw ; offset of currently sifted sub-tree
	swap_tmpw  dw ; temporary word used when swapping values
.ENDS

; 16-bit heap sort
.SECTION "Sort" SEMIFREE
	; replace offset A with the offset of its parent
	.MACRO iparent_words
		lsr
		dea
		lsr
		asl
	.ENDM
	; replace offset A with the offset of its first child
	.MACRO ichild_words
		ina
		asl
	.ENDM

	.MACRO set_srt_step ARGS state
		php
		rep #$20
		lda #state
		sta srt_step
		plp
	.ENDM

	; Call with 16-bit AXY. A contains array start, X the number of *bytes*,
	; so 2x the number of elements!
	; Let's do a straightforward implementation with indirect indexing first

	.MACRO heap_sort_words ARGS addr nbyte
		php
		rep #$30
		lda #addr
		ldx #nbyte
		jsr heap_sort_words
		plp
	.ENDM

	heap_sort_words:
		.16BIT
		; we will do indirect accesses through this variable
		; indices will be byte indices!
		sta srt_ptr
		stx srt_nbyte
		set_srt_step 0
		jsr arr2heap_words
		set_srt_step 1
		jsr heap2sort_words
		set_srt_step 2
		rts

	; Called with srt_ptr set to the array ptr and srt_nbyte set to its size in bytes
	; Leaves the array a heap
	arr2heap_words:
		.16BIT
		; start = one before first leaf node
		lda srt_nbyte
		sta sift_end
		dea
		dea
		iparent_words
		- ; Loop while start >= 0
		; sift down [start:]
		sta sift_start
		jsr sift_down_words
		; update zero flag for A
		sec
		sbc #$02.w
		bcs -
		+
		rts

	; called with srt_ptr pointing to a heap with size srt_nbyte
	heap2sort_words:
		.16BIT
		ldy srt_nbyte ; Y = end_index*2
		-
		cpy #$4.w     ; while end_index > 1 (end_index >= 2)
		bcc +
			dey         ; end_index -= 1
			dey
			; swap a[end] with a[0]
			lda (srt_ptr),y
			tax
			lda (srt_ptr)
			sta (srt_ptr),y
			txa
			sta (srt_ptr)
			; sift down [:end]
			stz sift_start
			sty sift_end
			jsr sift_down_words
		bra -
		+
		rts

	; Helper function for arr2heap and heap2sort. Restores the
	; heap condition. Call with sift_start and sift_end set.
	; Preserves PAXY
	sift_down_words:
		.16BIT
		pha
		phx
		phy
		php
		; We will have X as the main offset and Y as the secondary offset
		; in most of this
		ldx sift_start
		-
		; sift_root = current sub-tree root
		stx sift_root
		; X = index of first child
		txa
		ichild_words
		tax
		cpx sift_end
		bcs +; exit if we've run out of elements
			; Value of first child. Can't do indirect lookups with x, so temporarily use y
			txy
			lda (srt_ptr),y
			; Does the second child exist?
			iny
			iny
			cpy sift_end
			bcs ++
				; Yes. Compare its value to the first child. NB! Unsigned!
				cmp (srt_ptr),y
				bcs ++
					; second child is bigger, so use it instead
					lda (srt_ptr),y
					tyx
			++
			; Ok, X now has the offset of the biggest child, and A it value.
			; Is that bigger than our root?
			ldy sift_root
			cmp (srt_ptr),y
			bcc + ; skip if child < root. Unnecessary but harmless swap if equal
				; root was smaller, so swap them
				sta swap_tmpw
				lda (srt_ptr),y ; load root value
				txy
				sta (srt_ptr),y ; store it in child
				ldy sift_root
				lda swap_tmpw   ; load old child value
				sta (srt_ptr),y ; store it in root
				; next iteration we sift down from the location of child, so
				; it becomes our new root. This happens at the top of the root
				bra -
			+
			; If we get here, root has the biggst element, so we have
			; fulfilled the heap criterion
			plp
			ply
			plx
			pla
			rts

; A >= B: carry set
; A  < B: carry cleared

.ENDS
