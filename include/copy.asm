; Subroutines for transfering data

; Remember that VRAM can only be written to during blanks.

; To copy data to vram:
; * $2115 should be $80, which causes the vram address to increase by 1 word
;  each time we write a word, and disables address remapping. this is already
;  set in SnesInit, and I don't see a reason to change it, so I won't set it
;  again here.
; * Write vram word address to $2116 16-bit
; * Repeatedly write data to $2118 16-bit
;
; To do this with DMA:
; * Choose which channel to use, one of 8. I think these will retain their
;   settings, to one could make a function to configure a DMA, and then
;   fire it off repeatedly with a single instruction
; * Set the transfer pattern by writing to $43n0. For vram, we want
;   $01 = write, increment ram address, +0,+1 write address pattern
; * Set the vram address to $2116 16-bit
; * Set the target address low byte by writing to $43n1. $18 for vram write ($2118)
; * Start DMA transfer by writing to $420b. $00 to enable channel 0, for example.
;
; Since the vram address needs to be set anyway, reusing the settings isn't that
; useful.
;
; Example: BG3 tilemap data at word address $3000-$3800. Would copy like this using
; DMA channel 0:
; * rep #$10
; * sep #$20
; * ldx #dest_address ; #$3000 in our case
; * stx $2116
; * lda #$01
; * sta $4300
; * lda #$18
; * sta $4301
; * ldx #src_address
; * stx $4302
; * stz #4304 ; bank 0 - how to handle generally?
; * ldx #len  ; $1000 in our case ($800 words)
; * stx $4306
; * lda #$01
; * sta $420b ; do the transfer

; What would it look like with reuse?
; * rep #$10
; * ldx #dest_address
; * stx $2116
; * sep #$10
; * ldx #$01
; * stx $420b
; So it's about half the length

; Making a subroutine for this doesn't make sense, since setting up the
; arguments would be as much work as just doing the DMA call manually.
; Better as a macro, since it can take arguments

; Clobbers X. 8/16-bit mode preserved
.MACRO vram_upload ARGS dest, src, bank, nbyte, slot
	php
	; First do the 16-bit stuff
	rep #$10
	ldx #dest  ; vram destination
	stx $2116
	ldx #src   ; ram  src address
	stx $4302 + $10*slot
	ldx #nbyte ; nbyte to transfer
	stx $4305 + $10*slot
	; Then the 8-bit stuff
	sep #$10
	ldx #$01   ; DMA mode. write, advance, +0,+1 write
	stx $4300
	ldx #$18   ; specify write to vram
	stx $4301 + $10*slot
	ldx #bank  ; ram  src bank
	stx $4304 + $10*slot
	ldx #$00 | (1<<slot) ; do the transfer
	stx $420b
	plp
.ENDM
