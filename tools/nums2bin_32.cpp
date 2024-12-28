#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

int main(int argc, char ** argv) {
	if(argc != 3) { fprintf(stderr, "Usage ifile.txt ofile.bin\n"); return 1; }
	const char * ifname = argv[1], * ofname = argv[2];
	FILE * ifile = fopen(ifname, "r");
	if(!ifile) { fprintf(stderr, "Error opening %s for reading\n", ifname); return 1; }
	FILE * ofile = fopen(ofname, "wb");
	if(!ofile) { fprintf(stderr, "Error opening %s for writing\n", ofname); return 1; }

	uint32_t num = 0;
	int n = 0;
	while(fscanf(ifile, "%d", &num)==1) {
		fwrite(&num, sizeof(num), 1, ofile);
		n++;
	}
	printf("Successfully converted %d elements\n", n);
	return 0;
}
