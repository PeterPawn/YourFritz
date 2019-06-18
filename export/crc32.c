/* simple implementation of CRC32 checksum as short C program */
/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <stdio.h>
#include <inttypes.h>
int main()
{
	const uint32_t polynom=0xEDB88320;
	uint32_t lookupTable[256];
	uint32_t crcValue=0;
	ssize_t readBytes=0;
	uint8_t byte;
	char buffer[256];
	char *input;
	int i;
	int j;
	for (i = 0;i < 256;i++) {
		uint32_t val = (uint32_t) i;
		for (j = 0;j < 8;j++) {
			int isOne=((val & 1) == 1);
			val >>= 1;
			if (isOne) {
				val ^= polynom;
			} 
		}
		lookupTable[i] = val;
	}
	crcValue = ~crcValue;
	do {
		for (input = buffer;input < (buffer+readBytes);input++) {
			byte = *input;
			crcValue = (crcValue >> 8) ^ lookupTable[(crcValue & 255) ^ byte];
		}
		readBytes = read(0, buffer, sizeof(buffer));
	} while (readBytes > 0);
	crcValue = ~crcValue;
	printf("%08X\n",crcValue);
	return 0;
}
