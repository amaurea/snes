progs/basic.smc: progs/basic.link progs/basic.obj
	wlalink -R -v2 $< $@

%.obj: %.asm
	wla-65816 -v2 -o $@ $^
