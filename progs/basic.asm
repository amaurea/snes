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
	SLOWROM ; Normal rom read speed

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
	IRQ    IRQHandler    ; Jump here when VBlank ends
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

	; SNES initialization
	Start:
		sei  ; disable IRQ
		clc  ; set to native mode
		xce
		rep #$18   ; binary mode (decimal mode off), X/Y 16 bit
		ldx #$1fff ; set stack at $1fff
		txs
		jsr InitSnes ; Configure hardware to generic starting condition
		jsr InitGame ; Game-specific initialization
		jmp MainLoop

	; Vertical blanking. This should update the graphics ram,
	; but not do much else since there's not much time here.
	VBlankHandler:
		jsr VBlank
		rti

	IRQHandler:
		jsr VBlankEnd
		rti

.ENDS

.SECTION "InitSnes" SEMIFREE
	InitSnes:
		sep #$30    ; X,Y,A are 8 bit numbers
		lda #$8F    ; screen off, full brightness
		sta $2100   ; brightness + screen enable register·
		stz $2101   ; Sprite register (size + address in VRAM)·
		stz $2102   ; Sprite registers (address of sprite memory [OAM])
		stz $2103   ;    ""                       ""
		stz $2105   ; Mode 0, = Graphic mode register
		stz $2106   ; noplanes, no mosaic, = Mosaic register
		stz $2107   ; Plane 0 map VRAM location
		stz $2108   ; Plane 1 map VRAM location
		stz $2109   ; Plane 2 map VRAM location
		stz $210A   ; Plane 3 map VRAM location
		stz $210B   ; Plane 0+1 Tile data location
		stz $210C   ; Plane 2+3 Tile data location
		stz $210D   ; Plane 0 scroll x (first 8 bits)
		stz $210D   ; Plane 0 scroll x (last 3 bits) #$0 - #$07ff
		stz $210E   ; Plane 0 scroll y (first 8 bits)
		stz $210E   ; Plane 0 scroll y (last 3 bits) #$0 - #$07ff
		stz $210F   ; Plane 1 scroll x (first 8 bits)
		stz $210F   ; Plane 1 scroll x (last 3 bits) #$0 - #$07ff
		stz $2110   ; Plane 1 scroll y (first 8 bits)
		stz $2110   ; Plane 1 scroll y (last 3 bits) #$0 - #$07ff
		stz $2111   ; Plane 2 scroll x (first 8 bits)
		stz $2111   ; Plane 2 scroll x (last 3 bits) #$0 - #$07ff
		stz $2112   ; Plane 2 scroll y (first 8 bits)
		stz $2112   ; Plane 2 scroll y (last 3 bits) #$0 - #$07ff
		stz $2113   ; Plane 3 scroll x (first 8 bits)
		stz $2113   ; Plane 3 scroll x (last 3 bits) #$0 - #$07ff
		stz $2114   ; Plane 3 scroll y (first 8 bits)
		stz $2114   ; Plane 3 scroll y (last 3 bits) #$0 - #$07ff
		lda #$80    ; increase VRAM address after writing to $2119
		sta $2115   ; VRAM address increment register
		stz $2116   ; VRAM address low
		stz $2117   ; VRAM address high
		stz $211A   ; Initial Mode 7 setting register
		stz $211B   ; Mode 7 matrix parameter A register (low)
		lda #$01
		sta $211B   ; Mode 7 matrix parameter A register (high)
		stz $211C   ; Mode 7 matrix parameter B register (low)
		stz $211C   ; Mode 7 matrix parameter B register (high)
		stz $211D   ; Mode 7 matrix parameter C register (low)
		stz $211D   ; Mode 7 matrix parameter C register (high)
		stz $211E   ; Mode 7 matrix parameter D register (low)
		sta $211E   ; Mode 7 matrix parameter D register (high)
		stz $211F   ; Mode 7 center position X register (low)
		stz $211F   ; Mode 7 center position X register (high)
		stz $2120   ; Mode 7 center position Y register (low)
		stz $2120   ; Mode 7 center position Y register (high)
		stz $2121   ; Color number register ($0-ff)
		stz $2123   ; BG1 & BG2 Window mask setting register
		stz $2124   ; BG3 & BG4 Window mask setting register
		stz $2125   ; OBJ & Color Window mask setting register
		stz $2126   ; Window 1 left position register
		stz $2127   ; Window 2 left position register
		stz $2128   ; Window 3 left position register
		stz $2129   ; Window 4 left position register
		stz $212A   ; BG1, BG2, BG3, BG4 Window Logic register
		stz $212B   ; OBJ, Color Window Logic Register (or,and,xor,xnor)
		sta $212C   ; Main Screen designation (planes, sprites enable)
		stz $212D   ; Sub Screen designation
		stz $212E   ; Window mask for Main Screen
		stz $212F   ; Window mask for Sub Screen
		lda #$30
		sta $2130   ; Color addition & screen addition init setting
		stz $2131   ; Add/Sub sub designation for screen, sprite, color
		lda #$E0
		sta $2132   ; color data for addition/subtraction
		stz $2133   ; Screen setting (interlace x,y/enable SFX data)
		stz $4200   ; Enable V-blank, interrupt, Joypad register
		lda #$FF
		sta $4201   ; Programmable I/O port
		stz $4202   ; Multiplicand A
		stz $4203   ; Multiplier B
		stz $4204   ; Multiplier C
		stz $4205   ; Multiplicand C
		stz $4206   ; Divisor B
		stz $4207   ; Horizontal Count Timer
		stz $4208   ; Horizontal Count Timer MSB (most significant bit)
		stz $4209   ; Vertical Count Timer
		stz $420A   ; Vertical Count Timer MSB
		stz $420B   ; General DMA enable (bits 0-7)
		stz $420C   ; Horizontal DMA (HDMA) enable (bits 0-7)
		stz $420D   ; Access cycle designation (slow/fast rom)
		cli         ; Enable interrupts
		rts
.ENDS

;; Our work RAM
;.ENUM $0000
;	idlecount_low  dw
;	idlecount_high dw
;.ENDE

.RAMSECTION "WorkRam" SLOT 1 ORG $1fff SEMISUBFREE
	idlecount      dw
	budget_vblank  dw
	budget_main    dw
.ENDS

.SECTION "MainSection" SEMIFREE
	InitGame:
		; Set graphics mode 1 (2 16-color BG, 1 4-color BG). This is a
		; common and straightforward mode
		sep #$30
		lda #$21
		sta $2105

		; Enable only background 1 for now
		lda #%00000001
		sta $212c

		; Set up where in graphics ram things will be stored. Should probably
		; put this in variables.

		; Backgrounds consist of tilemaps and tiles. Each tilemap is 32x32,
		; with each entry being a 2-byte word. So the whole thing is $20*$20*$2 = $800.
		; Bytes big. But VRAM Is addressed in units of words, not bytes, so a
		; tilemap takes up only $400 words. A background can use 1x1, 1x2, 2x1 or 2x2
		; tilemaps which must be contiguous. So at most a background's tilemaps can
		; take up $400*4 = $1000 words. Tilemaps can only be placed at $400 word alignment
		;
		; The tile (chr) data. These are 16x16 blocks of 8x8 pixels. Each block is stored
		; in bitplane format. A 16-color BG's tiles are 4 bit per pixel, so a tile takes
		; up $8*$8/2 = $20 bytes. The whole tilemap is therefore $10*$10*$20 = $2000 bytes.
		; This is vram $1000 words. Tile data can only be placed at $1000 word alignment.
		; BG3 is only 2-bits, so it takes $800 words. But alignment is unchanged.

		lda #$00  ; BG1 tile map at vram $0000. 1x1 tilemaps
		sta $2107
		lda #$04  ; BG2 tile map at vram $0400. 1x1 tilemaps
		sta $2108
		lda #$08  ; BG3 tile map at vram $0800. 1x1 tilemaps
		sta $2109

		lda #$21  ; BG1 at $1000, BG2 at $2000
		sta $210b
		lda #$03  ; BG3 at $3000

		lda #%00001111  ; Turn on screen and set brightness to 15 (100%).
		sta $2100

		; Set a background color for testing purposes
		stz $2121
		lda #$ff
		sta $2122
		lda #$ff
		sta $2122

		lda #$80   ; Turn on the vblank NMI
		sta $4200

		rts

	VBlank:
		; Put video updating DMAs here
		
		; Before returning, copy out the idle counter value and store it as the
		; remaining budget for the main period.
		rep #$20
		lda idlecount
		sta budget_main
		; This will effectively reset idlecount due to the inc in MainLoop
		lda #$ffff
		sta idlecount
		rts

	VBlankEnd:
		; VBlank just ended (we reached scanline 0). Record spare time left in vblank
		; and disable IRQ until next time
		rep #$20
		lda idlecount
		sta budget_vblank
		; This will effectively reset idlecount due to the inc in MainLoop
		lda #$ffff
		sta idlecount
		; Disable IRQ
		sep #$20
		lda #$80
		sta $4200
		rts

	MainLoop:
		; do main work here



		; Idle loop and counting

		rep #$20
		stz idlecount
		; loop while counting until counter is reset externally by the vblank handler
		; This counts how much time we had to spare in the main section
		- inc idlecount
		bne -
		; Enable IRQ and start counting again. The IRQ will fire when vblank ends and then
		; diable itself. This counts how much time we had to spare in the vblank section.
		stz $4209  ; IRQ on scanline 0, just after the end of vblank
		sep #$20
		lda #$a0
		sta $4200
		- inc idlecount
		bne -
		; jump back to the top (main work)
		bra MainLoop

.ENDS

