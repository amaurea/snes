.PHONY: all tools progs clean tidy

prog_bins = progs/basic.smc
tool_bins = tools/img2bitplanes
resource_bins = resources/letters_4bit.chr

all: tools progs resources
progs: $(prog_bins)
tools: $(tool_bins)
resources: $(resource_bins)

progs/basic.smc: progs/basic.link progs/basic.obj
	wlalink -R -v2 $< $@

tools/%: tools/%.cpp
	g++ -g -o $@ $^

%.obj: %.asm
	wla-65816 -v2 -o $@ $^

%_2bit.chr: %.png tools/img2bitplanes
	tools/img2bitplanes -b 2 $< $@
%_4bit.chr: %.png tools/img2bitplanes
	tools/img2bitplanes -b 4 $< $@

clean: tidy
	rm -rf $(prog_bins) $(tool_bins) $(resource_bins)

tidy:
	rm -rf progs/*.obj libs/*.obj
