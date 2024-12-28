.PHONY: all tools progs clean tidy
.SUFFIXES:

prog_bins = progs/basic.smc progs/advent1_16.smc progs/advent1_32.smc
tool_bins = tools/img2bitplanes tools/nums2bin_16 tools/nums2bin_32
resource_bins = resources/letters_2bit.chr resources/letters_4bit.chr resources/advent1_nums_16.bin resources/advent1_nums_32.bin

all: tools progs resources
progs: $(prog_bins)
tools: $(tool_bins)
resources: $(resource_bins)

progs/%.smc: progs/%.link progs/%.obj
	wlalink -R -v $< $@
progs/%.link:
	echo -e "[objects]\n$*.obj" > $@

progs/basic.obj: include/init.asm include/copy.asm include/text.asm resources/letters_2bit.chr
progs/advent1_16.obj: include/init.asm include/copy.asm include/text.asm include/sort.asm include/decimal.asm resources/letters_2bit.chr resources/advent1_nums_16.bin
progs/advent1_32.obj: include/init.asm include/copy.asm include/text.asm include/sort.asm include/decimal.asm resources/letters_2bit.chr resources/advent1_nums_32.bin

%.obj: %.asm
	wla-65816 -v -I include -I resources -o $@ $<

tools/%: tools/%.cpp
	g++ -g -o $@ $^

%_2bit.chr: %.png tools/img2bitplanes
	tools/img2bitplanes -b 2 $< $@
%_4bit.chr: %.png tools/img2bitplanes
	tools/img2bitplanes -b 4 $< $@
%_nums_16.bin: %_nums.txt tools/nums2bin_16
	tools/nums2bin_16 $< $@
%_nums_32.bin: %_nums.txt tools/nums2bin_32
	tools/nums2bin_32 $< $@

clean: tidy
	rm -rf $(prog_bins) $(tool_bins) $(resource_bins)

tidy:
	rm -rf progs/*.obj libs/*.obj include/*.lst stderr.txt stdout.txt
