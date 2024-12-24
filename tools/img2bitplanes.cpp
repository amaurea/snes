#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <memory>
#include <vector>
#include <stdexcept>
#include <algorithm>
#define STB_IMAGE_IMPLEMENTATION
#include <stb/stb_image.h>

using std::vector;
using std::runtime_error;
typedef unsigned char byte;
typedef uint32_t color;
void file_closer(FILE * f) { if(f) fclose(f); }
typedef std::unique_ptr<byte,decltype(&free)> byte_ptr;
typedef std::unique_ptr<FILE,decltype(&file_closer)> file_ptr;
file_ptr open_file(const char * fname, const char * mode) { return file_ptr(fopen(fname, mode), &file_closer); }

void get_tile(color * data, int i0, int stride, int nmax, color * tile) {
	for(int y = 0; y < 8; y++)
	for(int x = 0; x < 8; x++) {
		if(y*8+x >= nmax) return;
		tile[y*8+x] = data[i0+y*stride+x];
	}
}
bool all_zero(const vector<color> & ptile) {
	for(color c : ptile) if(c != 0) return false;
	return true;
}
bool find_palette_index(const vector<color> & palette, const vector<color> & ctile, vector<byte> & idxtile) {
	// Palette is probably very short, so linear search is fine
	for(int i = 0; i < ctile.size(); i++) {
		int j;
		for(j = 0; j < palette.size() && ctile[i] != palette[j]; j++);
		if(j >= palette.size())
			return false;
		idxtile[i] = j;
	}
	return true;
}
vector<byte> idx2bitplane(const vector<byte> & idxtile, int nbit) {
	int nbyte = idxtile.size() * nbit / 8;
	vector<byte> bitplane;
	bitplane.reserve(nbyte);
	for(int bitpair = 0; bitpair < nbit/2; bitpair++) {
		for(int y = 0; y < 8; y++) {
			byte row[2] = {0,0};
			for(int x = 0; x < 8; x++) {
				byte v  = idxtile[8*y+x];
				row[0] |= (v>>(bitpair*2+0) & 1) << (7-x);
				row[1] |= (v>>(bitpair*2+1) & 1) << (7-x);
			}
			bitplane.push_back(row[0]);
			bitplane.push_back(row[1]);
		}
	}
	return bitplane;
}
uint16_t color2snes(color & col) {
	uint8_t * rgba = (uint8_t*)&col;
	uint16_t snescol = (uint16_t)rgba[3] >> 3;
	snescol <<= 5;
	snescol  |= rgba[1] >> 3;
	snescol <<= 5;
	snescol  |= rgba[0] >> 3;
	return snescol;
}

int img2bitplanes(int nx, int ny, color * data, int nbit, FILE * ocfile, FILE * opfile) {
	int ncolor = 1 << nbit;
	vector<color> ctile(8*8), ptile(ncolor);
	vector<byte>  idxtile(8*8);
	// Find the number of character columns
	int ntx = nx / 8 / 2;
	int nty = ny / 8;
	if(ntx*8*2 != nx) throw runtime_error("Image must contain a whole number of columns (x multiple of 2*8");
	if(nty*8   != ny) throw runtime_error("Image must contain a whole number of rows (y multiple of 8");
	vector<vector<color>> palettes;
	// Loop over tiles
	for(int ty = 0; ty < nty; ty++) {
		int y = ty*8;
		for(int tx = 0; tx < ntx; tx++) {
			int x = tx*8;
			// Get tile character and palette data
			get_tile(data, (y*nx+x),       nx, 8*8,    &ctile[0]);
			get_tile(data, (y*nx+x+ntx*8), nx, ncolor, &ptile[0]);
			// Get the current tile's palette
			if(all_zero(ptile)) {
				if(palettes.empty()) throw runtime_error("Can't reuse palette when none is defined\n");
			} else palettes.push_back(ptile);
			const vector<color> & palette = palettes.back();
			// Go from rgba to indexed mode
			if(!find_palette_index(palette, ctile, idxtile)) throw runtime_error("Color not found in palette\n");
			// Go from indices to bitplanes
			vector<byte> bitplane = idx2bitplane(idxtile, nbit);
			// And output
			fwrite(&bitplane[0], 1, bitplane.size(), ocfile);
		}
	}
	// Output unique palettes for now
	if(opfile) {
		std::sort(palettes.begin(), palettes.end());
		auto last = std::unique(palettes.begin(), palettes.end());
		for(auto it = palettes.begin(); it != last; it++) {
			for(color c: *it) {
				uint16_t snescol = color2snes(c);
				fwrite(&snescol, 2, 1, opfile);
			}
		}
	}
	return 0;
}

void help() { fprintf(stderr, "Usage: png2bitplanes [-b nbit] [-p opalette] iimg obitplanes\n"); exit(1); }

int main(int argc, char ** argv)
{
	char * ifname = NULL, * pfname = NULL, * ofname = NULL;
	int nbit = 4;
	// Parse our arguments
	int narg = 0;
	for(int i = 1; i < argc; i++) {
		if(!strcmp(argv[i], "-p") || !strcmp(argv[i], "--palettefile")) {
			if(i >= argc) help();
			pfname = argv[++i];
		} else if(!strcmp(argv[i], "-b") || !strcmp(argv[i], "--nbit")) {
			if(i >= argc) help();
			nbit = atoi(argv[++i]);
		} else if(*argv[i] == '-') help();
		else {
			switch(narg++) {
				case 0: ifname = argv[i]; break;
				case 1: ofname = argv[i]; break;
				default: help(); break;
			}
		}
	}
	if(narg != 2) help();

	// Load our image. We will have it converted to rgba
	int x,y,n;
	byte_ptr data(stbi_load(ifname, &x, &y, &n, 4), &free);
	if(!data)  { fprintf(stderr, "Error reading image '%s': %s\n", ifname, stbi_failure_reason()); return 1; }
	file_ptr bpfile = open_file(ofname, "wb");
	if(!bpfile){ perror(ofname); return 1; }
	file_ptr pfile(NULL, &file_closer);
	if(pfname) {
		pfile = open_file(pfname, "wb");
		if(!pfile){ perror(pfname); return 1; }
	}
	return img2bitplanes(x,y,(color*)data.get(),nbit,bpfile.get(),pfile.get());
}
