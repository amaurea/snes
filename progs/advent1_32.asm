; Start with our header. We'll use LoRom, which is common, simple,
; and not any worse than HiRom. We won't include the ram in the memorymap,
; at least not for now, since I'm not sure how it would work with all the
; ram mirroring and stuff

; Our memory map. We only have one rom slot, which is mapped to $8000.
.MEMORYMAP
	SLOTSIZE $8000
	DEFAULTSLOT 0
	SLOT 0 $8000
	SLOTSIZE $10000
	SLOT 1 $0000
.ENDME
.ROMBANKSIZE $8000 ; Each bank is 32 kB
.ROMBANKS 1        ; Total of 1*32 = 32 kB in size. Adjust if needed.

; The SNES header. Mainly sets our rom type and name
.SNESHEADER
	ID   "SNES"
	NAME "Advent1              " ; should be exactly 21 chr long
	LOROM
	SLOWROM           ; Normal rom read speed
	ROMSIZE       $05 ; 1<<ROMSIZE kB, So 8=256kB, 9=512kB, A=1MB, B=2MB, C=4MB
	SRAMSIZE      $00 ; No SRAM for now
	CARTRIDGETYPE $00 ; Would be $02 if we want SRAM
	COUNTRY       $01 ; 1=US, 0=Japan
	LICENSEECODE  $00
	VERSION       $00 ; 0=1.00, 1=1.01, etc.
.ENDSNES

; Meaning of character strings
.ASCTABLE
MAP '0' TO '9' =  0
MAP 'A' TO 'Z' = 10
MAP 'a' TO 'z' = 36
MAP '.' = 62
MAP ',' = 63
MAP '!' = 64
MAP '?' = 65
MAP ' ' = 69
.ENDA

; Our interrupt vectors. The snes starts in emulation mode and jumps to the RESET
; interrupt where we will put our initialization. During this we will switch to
; native mode, so the native interrupts are the ones that matter for all but RESET.

.SNESEMUVECTOR
	RESET  Start ; Label where execution starts
	NMI    EmptyHandler
	IRQBRK EmptyHandler
	COP    EmptyHandler
	ABORT  EmptyHandler
.ENDEMUVECTOR

.SNESNATIVEVECTOR
	NMI    VBlankHandler ; Jump here when VBlank happens
	IRQ    EmptyHandler
	BRK    EmptyHandler
	COP    EmptyHandler
	ABORT  EmptyHandler
.ENDNATIVEVECTOR

; Beginning of our code, starting from the start of bank 0
.BANK 0
.ORG 0

.INCLUDE "init.asm"
.INCLUDE "copy.asm"
.INCLUDE "text.asm"
.INCLUDE "sort.asm"
.INCLUDE "decimal.asm"

; Our empty handler. We force it to start at $0000 in the rom since that's the default
; interrupt target. Given this, we could ommit all unused interrupts in the vector
; tables, above, but we'll leave them there now to be tidy.
.SECTION "InterruptVectors" FORCE
	; Handler to ignore irrelevant interrupts
	EmptyHandler:
		rti

	Start:
		InitCPU      ; CPU mode and stack
		jsr InitSnes ; Configure hardware to generic starting condition
		jsr InitGame ; Game-specific initialization
		jmp Main

	; Vertical blanking. This should update the graphics ram,
	; but not do much else since there's not much time here.
	VBlankHandler:
		jsr VBlank
		rti
.ENDS

; Reserve space for the stack. This won't prevent the stack from
; overflowing, but will at least prevent wla from putting other
; stuff there
.RAMSECTION "Stack" SLOT 1 ORG $1f00 FORCE
	stack ds $100
.ENDS
; Reserve unmapped ram
.RAMSECTION "Reserved" SLOT 1 ORG $2000 FORCE
	io      ds $4000
	nothing ds $2000
	rommirr ds $8000
.ENDS

.RAMSECTION "WorkRam" SLOT 1 ORG $1fff SEMISUBFREE
	frame       dw
	status      dw
	prev_frame  dw
	prev_status dw
	prev_srt_step dw
	cur_line      dw
	frame_diff    dw
	diffsum       ds 4
	diffwork      ds 4
	diffsum_arr1   dw
	diffsum_arr2   dw
	diffsum_arr1_h dw ; used to access high word
	diffsum_arr2_h dw ; used to access high word
.ENDS

.SECTION "DataSection"
	letters_chr: .INCBIN "letters_2bit.chr" FSIZE letters_size
	advent_data: .INCBIN "advent1_nums_32.bin" FSIZE advent_size2
	.DEFINE advent_size (advent_size2>>1)
	; Define progres report strings
	str_copy:  .ASC "copy    "
	str_copy_size:  .dw "copy    ".length
	str_sort1: .ASC "sort1   "
	str_sort1_size: .dw "sort1   ".length
	str_sort2: .ASC "sort2   "
	str_sort2_size: .dw "sort2   ".length
	str_diffs: .ASC "diffs   "
	str_diffs_size: .dw "diffs   ".length
	str_total: .ASC "total  "
	str_total_size: .dw "total  ".length
	str_result:.ASC "result "
	str_result_size:.dw "result ".length
	str_decimal:.ASC "dec"
	str_decimal_size:.dw "dec".length

	textpals:
		; Palette 1: black text white border, and a light blue background
		.DB %11100111,%01111100 $00,$00, $ff,$ff, $00,$00
		; Palette 2: black text red border
		.DB $00,$00, $00,$00, $00,$1f, $00,$00
.ENDS

; Ram section for our two lists. Depends DataSection
.RAMSECTION "Lists" SLOT 1 ORG $2000 BANK $7e SEMIFREE
	list1 ds advent_size
	list2 ds advent_size
.ENDS

.SECTION "MainSection"

	; Set the data bank register. Surprisingly cumbersome!
	.MACRO set_dbr ARGS dbr
		php
		sep #$20
		lda #dbr
		pha
		plb
		plp
	.ENDM

	InitGame:
		; Set graphics mode 1 (2 16-color BG, 1 4-color BG). This is a
		; common and straightforward mode. Currently this enables the
		; screen. Should separate that that for later, so I can still
		; write to vram for the later graphics trasfers
		jsr InitMode1
		; Set up vram
		; 1. Copy letters to BG3 chr
		vram_upload $9000 letters_chr :letters_chr letters_size 0
		;; 2. Copy tilemap to BG3 tiles
		;vram_upload $800 moo    :moo    6 0
		;vram_upload $0800 greeting    :greeting     $10 0
		; 3. Copy palettes to cgram
		cgram_upload $00 textpals :textpals $0010 0

		; only bg 3 for now
		sep #$20
		lda #%00000100
		sta $212c

		; Scroll a bit to avoid having the text crammed into the corner
		rep #$20
		lda #$ffbf.w
		sep #$20
		sta $2111
		xba
		sta $2111
		rep #$20
		lda #$ffbf.w
		sep #$20
		sta $2112
		xba
		sta $2112

		jsr EnableScreen

		; Initialize variables
		rep #$20
		stz frame
		stz status
		stz prev_frame
		stz prev_status
		stz prev_srt_step
		stz cur_line
		set_cursor 0

		rts

	VBlank:
		; We don't need high ram values here, but we do need the rom
		phb
		pha
		phx
		phy
		php

		set_dbr 0
		; Update frame count
		rep #$20
		inc frame
		; Normally this would be done in the main loop, but we don't have
		; a normal main loop this time
		jsr update_status
		; Update tilemap based on ram version
		vram_upload $800 text_buffer :text_buffer $800 0
		; Return control to normal code

		plp
		ply
		plx
		pla
		plb
		rts

	update_status:
		php

		; Only print frame diffs for status < 4
		rep #$30
		lda status
		cmp #4.w
		bpl +
		jsr print_framediff
		+
		plp
		rts

	; Macro for copying arrays to be sorted from rom to ram.
	; The two arrays are interleaved, so it's easiest to just
	; make this one-off function here. nbyte is the number of
	; bytes for each of the two lists.
	.MACRO deinterleave_32 ARGS dest1, dest2, src_long, nbyte
		php
		rep #$30
		; x will index source array, y the dest arrays
		lda #nbyte.w
		tay
		asl ; src_long array twice as long
		tax
		-
		dey
		dey
		dey
		dey
		bmi + ; done once y becomes negative
		dex
		dex
		dex
		dex
		lda src_long.l,x
		sta dest2,y
		lda src_long.l+2,x
		sta dest2+2,y
		dex
		dex
		dex
		dex
		lda src_long.l,x
		sta dest1,y
		lda src_long.l+2,x
		sta dest1+2,y
		bra -
		+
	.ENDM

	; Handle 24-bit numbers by replacing inc inc with inc inc inc etc, and by
	; doing the comparisons in two steps - first with the upper 2 bytes, then,
	; if not yet decided, with the low two bytes. This overlaps a bit, but that's
	; harmless.

	print_framediff:
		php
		; Backspace 4 characters, then overwrite them with relative frame count
		move_cursor_x #$fffc.w
		rep #$30
		lda frame
		sec
		sbc prev_frame
		sta frame_diff
		lead_print_hex frame_diff 2
		plp
		rts

	; abs(A) 32-bit. Set diffwork to a 32-bit value
	abs_32:
		; only need to consider high word to find the sign
		lda diffwork+2
		bpl +
		; ok, negative. Flip all the bits, then add one
		lda diffwork
		eor #$ffff.w
		clc
		adc #$1.w
		sta diffwork
		lda diffwork+2
		eor #$ffff.w
		adc #$0.w
		sta diffwork+2
		+
		rts

	; Count the sum of absolute differences of the 32-bit entries in arr1 and arr2,
	; both of which are nbyte long. The result is written to the 32-bit diffsum variable.
	; call with 16-bit AXY. arr1 and arr2 in diffsum_arr1, diffsum_arr2 respectively.
	; nbyte in Y. Clobbers A and Y.
	diffsum_32:
		lda $1235
		stz diffsum
		stz diffsum+2
		; Set up high word access
		lda diffsum_arr1
		ina
		ina
		sta diffsum_arr1_h
		lda diffsum_arr2
		ina
		ina
		sta diffsum_arr2_h
		-
		dey
		dey
		dey
		dey
		; calc diff. Low word first
		lda (diffsum_arr1),y
		sec
		sbc (diffsum_arr2),y
		sta diffwork
		; then high word, using the carry
		lda (diffsum_arr1_h),y
		sbc (diffsum_arr2_h),y
		sta diffwork+2
		; absolute value
		jsr abs_32
		; Add to our tally
		lda diffsum
		clc
		adc diffwork
		sta diffsum
		lda diffsum+2
		adc diffwork+2
		sta diffsum+2
		cpy #$0.w
		bne -
		rts

	.MACRO diffsum_32 ARGS arr1, arr2, nbyte
		pha
		phy
		php
		rep #$30
		lda #arr1.w
		sta diffsum_arr1
		lda #arr2.w
		sta diffsum_arr2
		ldy #nbyte.w
		jsr diffsum_32
		plp
		ply
		pla
	.ENDM

	Main:
		rep #$30
		stz status
		stz srt_step
		stz frame
		set_print_mode 0
		set_cursor 0

		; 1. Extract interleaved list of values to ram.
		; Need a long pointer for the rom data here
		; Oh no! The actual values in the txt file don't fit in 16 bits!
		; We need at least 18 bits. Bleh! We'll ignore that for now
		lda frame
		sta prev_frame
		prints "copy       "
		lda $1234
		set_dbr $7e
		deinterleave_32 list1 list2 advent_data.l advent_size2
		set_dbr $00
		jsr print_framediff

		; 2. Sort the lists
		lda #1.w
		sta status
		lda frame
		sta prev_frame
		move_cursor_yleft 1
		prints "sort1      "
		lda $1234
		set_dbr $7e
		heap_sort_32 list1 advent_size
		set_dbr $00
		jsr print_framediff

		lda #2.w
		sta status
		lda frame
		sta prev_frame
		move_cursor_yleft 1
		lda $1237
		prints "sort2      "
		set_dbr $7e
		heap_sort_32 list2 advent_size
		set_dbr $00
		jsr print_framediff

		; 3. Count differences
		lda #3.w
		sta status
		lda frame
		sta prev_frame
		move_cursor_yleft 1
		prints "diffs      "
		set_dbr $7e
		diffsum_32 list1 list2 advent_size
		set_dbr $00
		jsr print_framediff

		; 4. Print result
		lda $1234
		lda #4.w
		sta status
		lda frame
		sta prev_frame
		move_cursor_yleft 1
		prints "total  "
		lead_print_hex prev_frame 2
		move_cursor_yleft 1
		prints "result "
		lead_print_hex diffsum 4
		; Convert to decimal
		lda $1234
		lda diffsum
		sta dec_bin
		lda diffsum+2
		sta dec_bin+2
		jsr bin2dec_32
		; Print decimal result
		move_cursor_yleft 1
		prints "dec"
		lead_print_hex dec_dec 6

		; These prits were originally done like
		;print str_diffs str_diffs_size
		;repc ASC(' ') 4
		; Less elegant, but more tidy, as it keeps the
		; strings in their own section instead of interleaving
		; them wth the code in the executable, requiring
		; a jump to get past each one


		--
		bra --

.ENDS

