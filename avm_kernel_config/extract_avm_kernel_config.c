// vim: set tabstop=4 syntax=c :
/* SPDX-License-Identifier: GPL-2.0-or-later */
/***********************************************************************
 *                                                                     *
 *                                                                     *
 * Copyright (C) 2016-2017 P.Hämmerlein (http://www.yourfritz.de)      *
 *                                                                     *
 * This program is free software; you can redistribute it and/or       *
 * modify it under the terms of the GNU General Public License         *
 * as published by the Free Software Foundation; either version 2      *
 * of the License, or (at your option) any later version.              *
 *                                                                     *
 * This program is distributed in the hope that it will be useful,     *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of      *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       *
 * GNU General Public License for more details.                        *
 *                                                                     *
 * You should have received a copy of the GNU General Public License   *
 * along with this program, please look for the file COPYING.          *
 *                                                                     *
 ***********************************************************************/

#include "avm_kernel_config_helpers.h"
#include <libfdt.h>

void usage()
{
	fprintf(stderr, "extract_avm_kernel_config - extract (binary copy of) kernel config area from AVM's kernel\n\n");
	fprintf(stderr, "(C) 2016-2017 P. Hämmerlein (http://www.yourfritz.de)\n\n");
	fprintf(stderr, "Licensed under GPLv2, see LICENSE file from source repository.\n\n");
	fprintf(stderr, "Usage:\n\n");
	fprintf(stderr, "extract_avm_kernel_config [ -s <size in KByte> ] <unpacked_kernel> [<dtb_file>]\n");
	fprintf(stderr, "\nThe specified DTB content (a compiled OF device tree BLOB) is");
	fprintf(stderr, "\nsearched in the unpacked kernel and the place, where it's found");
	fprintf(stderr, "\nis assumed to be within the original kernel config area.\n");
	fprintf(stderr, "\nIf the DTB file is omitted, the kernel will be searched");
	fprintf(stderr, "\nfor the FDT signature (0xD00DFEED in BE) and some checks");
	fprintf(stderr, "\nare performed to guess the correct location.\n");
	fprintf(stderr, "\nThe output is written to STDOUT, so you've to redirect it to the");
	fprintf(stderr, "\nproper location.\n");
	fprintf(stderr, "\nTo support different models with changing sizes of the embedded");
	fprintf(stderr, "\nconfiguration area, a default size of 64 KB for this area is used,");
	fprintf(stderr, "\nwhich may be overwritten with the -s option.\n");
}

bool checkConfigArea(struct _avm_kernel_config ** configArea, size_t configSize)
{
	bool			swapNeeded = false;

	if (!detectInputEndianess(configArea, configSize, &swapNeeded)) return false;
	return true;
}

struct _avm_kernel_config ** findConfigArea(void *dtbLocation, size_t size)
{
	struct _avm_kernel_config **	configArea = NULL;

	// previous 4K boundary should be the start of the config area 
	configArea = (struct _avm_kernel_config **) (((int) dtbLocation >> 12) << 12);

	if (checkConfigArea(configArea, size)) return configArea;

	return NULL;
}

void * findDeviceTreeImage(void *haystack, size_t haystackSize, void *needle, size_t needleSize)
{
	void *		location = NULL;
	size_t		toSearch = haystackSize / sizeof(uint32_t);
	size_t		offsetMatched = 0;
	bool		matchedSoFar = false;
	uint32_t *	resetSliding;
	size_t		resetToSearch;

	if (toSearch > 0)
	{
		uint32_t *	sliding = haystack;
		uint32_t *	lookFor = needle;
		
		while (toSearch > 0)
		{
			while (*sliding != *lookFor)
			{
				toSearch--;
				sliding++;
				if (toSearch == 0) break;
			}

			if (toSearch > 0) // match found for first uint32
			{	
				matchedSoFar = true;
				resetToSearch = --toSearch;
				resetSliding = ++sliding;
				offsetMatched = sizeof(uint32_t);

				if ((needleSize - offsetMatched) > sizeof(uint32_t))
				{
					while (offsetMatched < needleSize)
					{
						if (*(lookFor + (offsetMatched / sizeof(uint32_t))) != *sliding) // difference found, reset match
						{
							matchedSoFar = false;
							sliding = resetSliding;
							toSearch = resetToSearch;
							break;
						}

						offsetMatched += sizeof(uint32_t);
						sliding++;
						toSearch--;

						if (toSearch == 0) break; // end of kernel reached, DTB isn't expected at the very end
						if ((needleSize - offsetMatched) < sizeof(uint32_t)) break;
					}
				}

				if (matchedSoFar) // compare remaining bytes
				{
					uint8_t *	remHaystack = (uint8_t *) sliding;
					uint8_t *	remNeedle = (uint8_t *) (needle + offsetMatched);
					size_t		remSize = needleSize - offsetMatched;

					while (remSize > 0)
					{
						if (*remHaystack != *remNeedle) // difference found
						{
							matchedSoFar = false;
							sliding = resetSliding;
							toSearch = resetToSearch;
							break;
						}

						remHaystack++;
						remNeedle++;
						remSize--;
					}

					if (remSize == 0) // match completed
					{
						location = (void *) --resetSliding;
						break;
					} 
				}
			}
		}
	}

	return location;
}

void * locateDeviceTreeSignature(void *kernelBuffer, size_t kernelSize)
{
	void *		location = NULL;
	uint32_t	signature = 0xD00DFEED;
	uint32_t *	ptr = (uint32_t *) kernelBuffer;	
	
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
	// the DTB signature is store in 'big endian' => swap needed, if we're running on 'little endian' machine
	swapEndianess(true, &signature);
#endif

	while ((void *) ptr < (kernelBuffer + kernelSize))
	{
		if (*ptr == signature) // possibly found the tree
		{
			if (fdt_check_header((void *) ptr) == 0)
			{
				location = ptr;
				break;
			}
		}
		ptr++;
	}

	return location;
}

int main(int argc, char * argv[])
{
	int						returnCode = 1;
	struct memoryMappedFile	kernel;
	struct memoryMappedFile	dtb;
	void *					dtbLocation = NULL;
	ssize_t					size = 64 * 1024;
	int						i = 1;
	int						paramCount = argc;

	/* no reason to use a getopt implementation for our simple calling convention */
	if (paramCount > i)
	{
		char *				sizeString = NULL;

		if (strcmp(argv[i], "-s") == 0)
		{
			if (paramCount > i + 1)
			{
				sizeString = argv[i + 1];
				i += 2;
				paramCount -= 2;
			}
			else
			{
				fprintf(stderr, "Missing numeric value after option '-s'.\n");
				exit(2);
			}
		}
		else if (strncmp(argv[i], "--size=", 7) == 0)
		{
			sizeString = strchr(argv[i], '=');
			sizeString++; /* skip equal sign */
			i += 1;
			paramCount -= 1;
		}

		if (sizeString != NULL)
		{
			int				newSize;

			newSize = atoi(sizeString);
			if (newSize == 0)
			{
				fprintf(stderr, "Missing or invalid numeric value for size option.\n");
				exit(2);
			}
			if (newSize < 16 || newSize > 1024)
			{
				fprintf(stderr, "Size value should be between 16 and 1024 - change source files, if your size is really valid.\n");
				exit(2);
			}
			if ((newSize & 0x0F) > 0)
			{
				fprintf(stderr, "Size value should be a multiple of 16 - change source files, if your size is really valid.\n");
				exit(2);
			}
			size = newSize * 1024;
		}
	}

	if (paramCount < 2)
	{
		usage();
		exit(1);
	}

	if (openMemoryMappedFile(&kernel, argv[i], "unpacked kernel", O_RDONLY | O_SYNC, PROT_READ, MAP_SHARED))
	{
		if (paramCount > 2)
		{
			if (openMemoryMappedFile(&dtb, argv[i + 1], "device tree BLOB", O_RDONLY | O_SYNC, PROT_READ, MAP_SHARED))
			{
				if (fdt_check_header(dtb.fileBuffer) == 0)
				{
					if ((dtbLocation = findDeviceTreeImage(kernel.fileBuffer, kernel.fileStat.st_size, dtb.fileBuffer, dtb.fileStat.st_size)) == NULL)
					{
						fprintf(stderr, "The specified device tree BLOB was not found in the kernel image.\n");
					}
				}
				else
				{
					fprintf(stderr, "The specified device tree BLOB file '%s' seems to be invalid.\n", dtb.fileName);
				}
			}
			closeMemoryMappedFile(&dtb);
		}
		else
		{
			if ((dtbLocation = locateDeviceTreeSignature(kernel.fileBuffer, kernel.fileStat.st_size)) == NULL)
			{
				fprintf(stderr, "Unable to locate the config area in the specified kernel image.\n");
			}
		}
		
		if (dtbLocation != NULL)
		{
			struct _avm_kernel_config * *configArea = findConfigArea(dtbLocation, size);
			
			if (configArea != NULL)
			{
				ssize_t	written = write(1, (void *) configArea, size);

				if (written == size)
				{
					returnCode = 0;
				}
				else
				{
					fprintf(stderr, "Error %d writing config area content.\n", errno);
				}
			}
			else
			{
				fprintf(stderr, "Unexpected config area content found, extraction aborted.\n");
			}
		}
		closeMemoryMappedFile(&kernel);
	}

	exit(returnCode);
}

