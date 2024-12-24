; Start with our header. We'll use LoRom, which is common, simple,
; and not any worse than HiRom. We won't include the ram in the memorymap,
; at least not for now, since I'm not sure how it would work with all the
; ram mirroring and stuff

; Our memory map. We only have one rom slot, which is mapped to $8000.
.MEMORYMAP
	SLOTSIZE $8000
	DEFAULTSLOT 0
	SLOT 0 $8000
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

.COMPUTESNESCHECKSUM

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

; This struct is used as a workaround for me not finding a way
; to indicate how big a ram section should be
.STRUCT array
	dummy: db
.ENDST

.INCLUDE "init.asm"
.INCLUDE "copy.asm"
.INCLUDE "text.asm"

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
		jmp MainLoop

	; Vertical blanking. This should update the graphics ram,
	; but not do much else since there's not much time here.
	VBlankHandler:
		jsr VBlank
		rti
.ENDS

; Reserve space for the stack. This won't prevent the stack from
; overflowing, but will at least prevent wla from putting other
; stuff there
.RAMSECTION "Stack" SLOT 1 ORG $1eff FORCE
	stack instanceof array size $100
.ENDS

.RAMSECTION "WorkRam" SLOT 1 ORG $1fff SEMISUBFREE
	frame dw
	num   dw
.ENDS

.SECTION "MainSection" SEMIFREE
	InitGame:
		; Set graphics mode 1 (2 16-color BG, 1 4-color BG). This is a
		; common and straightforward mode. Currently this enables the
		; screen. Should separate that that for later, so I can still
		; write to vram for the later graphics trasfers
		jsr InitMode1
		; Set up vram
		; 1. Copy letters to BG3 chr
		vram_upload $9000 letters_chr :letters_chr $2000 0
		;; 2. Copy tilemap to BG3 tiles
		;vram_upload $800 greeting    :greeting    $800 0
		;vram_upload $0800 greeting    :greeting     $10 0
		; 3. Copy palettes to cgram
		cgram_upload $00 textpals :textpals $0010 0

		; Try printing
		rep #$20
		lda #text_buffer
		sta prt_pos
		sep #$20
		lda #$04
		sta prt_mode
		print greeting 12 ;greeting.length

		;lda #$12
		;jsr print_hexbyte

		;lda #asc(' ')
		;putc
		;print_hex prt_pos 2
		;lda #asc(' ')
		;putc
		;print_hex prt_pos 2
		;lda #asc(' ')
		;putc
		;print_hex prt_pos 2

		;rep #$30
		;lda #$1234
		;sta num
		;print_hex num, 4

		; only bg 3 for now
		lda #%00000100
		sta $212c

		jsr EnableScreen


		; Initialize variables
		rep #$20
		stz frame

		rts

	VBlank:
		; Update tilemap based on ram version
		vram_upload $800 text_buffer :text_buffer _sizeof_text_buffer 0
		rep #$20
		inc frame

		rts

	MainLoop:

		sep #$20
		; Set palette to palette 1
		lda #$00
		sta prt_mode

		; Set cursor to start of second row
		set_cursor $20
		; Print frame and frame number
		print str_frame _sizeof_str_frame
		lead_print_hex frame _sizeof_frame

		; Wait for VBlank to finish
		lda frame
		-
		cmp frame
		beq -

		bra MainLoop

.ENDS

.SECTION "DataSection" SEMIFREE
	letters_chr: .INCBIN "letters_2bit.chr"
	greeting: .ASC "Hello World!"
	str_frame: .ASC "Frame "
	;greeting: .DB ASC('H'), $00, ASC('e'), $00, ASC('l'), $00, ASC('l'), $00, ASC('o'), $00, ASC(' '), $00, ASC('W'), $00, ASC('o'), $00, ASC('r'), $00, ASC('l'), $00, ASC('d'), $00, ASC('!'), $00
	;greeting: .DW $0000, $0001, $0002, $0003, $0004, $0005, $0006, $0007, $0008, $0009, $000a, $000b, $000c, $000d, $000e, $000f
	;greeting: .REPEAT $400
	;	.DB $01, $40
	;.ENDR

	textpals:
		; Palette 1: black text white border, and a light blue background
		.DB %11100111,%01111100 $00,$00, $ff,$ff, $00,$00
		; Palette 2: black text red border
		.DB $00,$00, $00,$00, $00,$1f, $00,$00
.ENDS
