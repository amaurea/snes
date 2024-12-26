.PHONY: all tools progs clean tidy

prog_bins = progs/basic.smc progs/advent1.smc
tool_bins = tools/img2bitplanes tools/nums2bin
resource_bins = resources/letters_2bit.chr

all: tools progs resources
progs: $(prog_bins)
tools: $(tool_bins)
resources: $(resource_bins)

progs/%.smc: progs/%.link progs/%.obj
	wlalink -R -v $< $@
progs/%.link:
	echo -e "[objects]\n$*.obj" > $@

progs/basic.obj: include/init.asm include/copy.asm include/text.asm resources/letters_2bit.chr
progs/advent1.obj: include/init.asm include/copy.asm include/text.asm include/sort.asm resources/letters_2bit.chr resources/advent1_nums.bin

%.obj: %.asm
	wla-65816 -v -I include -I resources -o $@ $<

tools/%: tools/%.cpp
	g++ -g -o $@ $^

%_2bit.chr: %.png tools/img2bitplanes
	tools/img2bitplanes -b 2 $< $@
%_4bit.chr: %.png tools/img2bitplanes
	tools/img2bitplanes -b 4 $< $@
%_nums.bin: %_nums.txt tools/nums2bin
	tools/nums2bin $< $@

clean: tidy
	rm -rf $(prog_bins) $(tool_bins) $(resource_bins)

tidy:
	rm -rf progs/*.obj libs/*.obj stderr.txt stdout.txt
