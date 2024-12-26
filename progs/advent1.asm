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
	NAME "BASIC                " ; should be exactly 21 chr long
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

; Set the data bank register. Surprisingly cumbersome!
.MACRO set_dbr ARGS dbr
	php
	sep #$20
	lda #dbr
	pha
	plb
	plp
.ENDM

; Macro for copying arrays to be sorted from rom to ram.
; The two arrays are interleaved, so it's easiest to just
; make this one-off function here. nbyte is the number of
; bytes for each of the two lists.
.MACRO deinterleave_words ARGS dest1, dest2, src_long, nbyte
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
	beq + ; done once y becomes negative
	dex
	dex
	lda src_long.l,x
	sta dest2,y
	dex
	dex
	lda src_long.l,x
	sta dest1,y
	bra -
	+
.ENDM

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
	frame  dw
	status dw
.ENDS

.SECTION "DataSection"
	letters_chr: .INCBIN "letters_2bit.chr" FSIZE letters_size
	advent_data: .INCBIN "advent1_nums.bin" FSIZE advent_size2
	.DEFINE advent_size (advent_size2>>1)
	; Define progres report strings
	progress_desc0: .ASC "copy "
	progress_desc1: .ASC "sort1"
	progress_desc2: .ASC "sort2"
	progress_desc3: .ASC "diffs"
	progress_desc4: .ASC "done "
	progress_desc: .dw progress_desc0, progress_desc1, progress_desc2, progress_desc3, progress_desc4
	bleh: .db 1, 2, 3, 4, 5, 6, 7, 6, 5, 4, 3, 2, 1
	progress_desc_size: .dw 5,5,5,5,5
	moo: .ASC "Moooo!!"

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

		jsr EnableScreen

		; Initialize variables
		rep #$20
		stz frame
		stz status

		rts

	VBlank:
		; We don't need high ram values here, but we do need the rom
		php
		phb
		pha
		phx
		phy

		set_dbr 0
		; Update frame count
		rep #$20
		inc frame
		; Normally this would be done in the main loop, but we don't have
		; a normal main loop this time
		jsr update_status
		; Update tilemap based on ram version
		vram_upload $800 text_buffer :text_buffer $100 0
		; Return control to normal code

		ply
		plx
		pla
		plb
		plp
		rts

	update_status:
		php
		; Set print mode, currently just palette
		sep #$20
		lda #$00
		sta prt_mode
		; Move to start of line
		set_cursor 0

		; Print our overall status
		rep #$30
		lda status
		asl ; use as word index
		tax
		lda progress_desc_size,x
		tay

		lda progress_desc,x
		tax
		sep #$20
		jsr print

		; If we're currently sorting, then print our sorting stage
		rep #$20
		lda status
		cmp #$1.w
		bmi +
		cmp #$3.w
		bpl +
			print chr_space 1
			rep #$20
			lda srt_step
			asl
			tax
			lda srt_step_desc_size,x
			tay
			lda srt_step_desc,x
			tax
			sep #$20
			jsr print
			;print chr_space 1
			;; Also print our progress inside the step
			;lead_print_hex srt_prog 2
		+
		plp
		rts

	Main:
		; Will be working with high ram here. This means that any
		; rom access will need long pointers or dbr changes
		set_dbr $7e

		rep #$20
		stz status
		stz srt_step
		; 1. Extract interleaved list of values to ram.
		; Need a long pointer for the rom data here
		deinterleave_words list1 list2 advent_data.l advent_size2
		lda #1.w
		sta status
		; 2. Sort the lists
		lda $1234
		heap_sort_words list1 advent_size
		lda #2
		sta status
		;heap_sort_words list2 advent_size
		;lda #3
		; 3. Count differences

		; Done with everything. Loop forever
		--
		bra --

.ENDS
