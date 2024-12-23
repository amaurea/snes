.INCLUDE "init.asm"
.INCLUDE "copy.asm"

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

.RAMSECTION "WorkRam" SLOT 1 ORG $1fff SEMISUBFREE
	idlecount      dw
	budget_vblank  dw
	budget_main    dw
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
		vram_upload $3000 letters_chr :letters_chr $1000 0

		; Set a background color for testing purposes
		stz $2121
		lda #$0f
		sta $2122
		lda #$ff
		sta $2122

		jsr EnableScreen

		rts

	VBlank:
		; Put video updating DMAs here
		rts

	MainLoop:
		; Loop forever
		bra MainLoop

.ENDS

.SECTION "DataSection" SEMIFREE
	letters_chr: .INCBIN "letters_2bit.chr"
.ENDS
