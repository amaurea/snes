; Our work variables should be on the direct page
.RAMSECTION "Sorting" SLOT 1 ORG $ff SEMISUBFREE
	srt_base  dw
	srt_nbyte dw
	srt_root  dw
	srt_tmp   dw
	srt_step  dw
	srt_prog  dw
	srt_sift_nbyte dw
.ENDS

; 16-bit heap sort
.SECTION "Sort" SEMIFREE

	; Define strings for the sort state and sort progress
	srt_step_desc0: .ASC "arr2heap "
	srt_step_desc1: .ASC "heap2sort"
	srt_step_desc2: .ASC "done     "
	srt_step_desc: .dw srt_step_desc0, srt_step_desc1, srt_step_desc2
	srt_step_desc_size: .dw 9, 9, 9 ; No automatic way to get this?!

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
		php
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
		sta srt_base
		stx srt_nbyte
		set_srt_step 0
		jsr arr2heap_words
		set_srt_step 1
		jsr heap2sort_words
		set_srt_step 2
		rts

	; Called with srt_base set to the array ptr and srt_nbyte set to its size in bytes
	; Leaves the array a heap
	arr2heap_words:
		.16BIT
		; start = index of first leaf node
		lda srt_nbyte
		dea
		dea
		iparent_words
		ina
		ina
		; Loop while start > 0
		-
		stx srt_prog ; update sort progress variable
		beq +
		dea
		dea ; start = last non-heap node
		jsr sift_down_words
		bra -
		+
		rts

	; called with srt_base pointing to a heap with size srt_nbyte
	heap2sort_words:
		.16BIT
		ldx srt_nbyte ; X = end_index*2
		-
		stx srt_prog  ; update sort progress
		cpx #$2       ; while end_index > 1
		bmi +
			dex         ; end_index -= 1
			dex
			; swap a[end] with a[0]
			lda (srt_base),x
			tay
			lda (srt_base)
			sta (srt_base),x
			tya
			sta (srt_base)
			; sift down for the part of the array we have
			jsr sift_down_words
		bra -
		+
		rts

	; called with A = start, X = nbyte Preserves A
	sift_down_words:
		.16BIT
		pha
		stx srt_sift_nbyte
		-
		sta srt_root
		ichild_words ; A = first child
		cmp srt_sift_nbyte ; nbyte
		bpl +; exit if we've run out of elements
			tax ; first child offset in X
			; Does the second child exist?
			ina
			ina
			cmp srt_sift_nbyte
			bpl ++
				; Yes. Store its value in Y
				tay
				; Load the first child and compare its value to the second child
				lda (srt_base),x
				cmp (srt_base),y
				bpl ++
					; second child is bigger, so use it instead
					tyx
					lda (srt_base),x
			++
			; Ok, X now has the offset of the biggest child, and A it value.
			; Is that bigger than our root?
			ldy srt_root
			cmp (srt_base),y
			bmi +
				; root root was smaller, so swap them
				sta srt_tmp
				lda (srt_base),y
				sta (srt_base),x
				lda srt_tmp
				sta (srt_base),y
				txa
				bra -
			+
			; If we get here, root has the biggst element, so we have
			; fulfilled the heap criterion
			plx
			pla
			rts

.ENDS
