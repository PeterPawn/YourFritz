/***********************************************************************
 *                                                                     *
 * Copyright (C) 2016 P.Hämmerlein (http://www.yourfritz.de)           *
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

#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <inttypes.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/fcntl.h>
#include <sys/mman.h>

#ifdef FREETZ
#include <linux/avm_kernel_config.h>
#else /* FREETZ */
#include "avm_kernel_config.h"
#endif /* FREETZ */

struct memoryMappedFile
{
	unsigned char *		fileName;
	unsigned char *		fileDescription;
	int					fileDescriptor;
	struct stat			fileStat;
	void *				fileBuffer;
	bool				fileMapped;
};

void usage()
{
	fprintf(stderr, "extract_avm_kernel_config - extract (binary copy of) kernel config area from AVM's kernel\n\n");
	fprintf(stderr, "(C) 2016 P. Hämmerlein (http://www.yourfritz.de)\n\n");
	fprintf(stderr, "Licensed under GPLv2, see LICENSE file from source repository.\n\n");
	fprintf(stderr, "Usage:\n\n");
	fprintf(stderr, "extract_avm_kernel_config <unpacked_kernel> <dtb_file>\n");
	fprintf(stderr, "\nThe specified DTB content (a compiled OF device tree BLOB) is");
	fprintf(stderr, "\nsearched in the unpacked kernel and the place, where it's found");
	fprintf(stderr, "\nis assumed to be within the original kernel config area.\n");
	fprintf(stderr, "\nThe output is written to STDOUT, so you've to redirect it to the");
	fprintf(stderr, "\nproper location.\n");
}

bool openMemoryMappedFile(struct memoryMappedFile *file, unsigned char *fileName, unsigned char *fileDescription, int openFlags, int prot, int flags)
{
	bool			result = false;

	file->fileName = fileName;
	file->fileDescription = fileDescription;
	if ((file->fileDescriptor = open(file->fileName, openFlags)) != -1)
	{
		if (fstat(file->fileDescriptor, &file->fileStat) != -1)
		{
			if ((file->fileBuffer = (void *) mmap(NULL, file->fileStat.st_size, prot, flags, file->fileDescriptor, 0)) != MAP_FAILED)
			{
				file->fileMapped = true;
				result = true;
			}
			else
			{
				fprintf(stderr, "Error %d mapping %u bytes of %s file '%s' to memory.\n", errno, (int) file->fileStat.st_size, file->fileName);
				close(file->fileDescriptor);
				file->fileDescriptor = -1;	
			}
		}
		else
		{
			fprintf(stderr, "Error %d getting file stats for '%s'.\n", errno, file->fileName);
			close(file->fileDescriptor);
			file->fileDescriptor = -1;
		}
	}
	else
	{
		fprintf(stderr, "Error %d opening %s file '%s'.\n", errno, file->fileDescription, file->fileName);
	}
	return result;

}

void closeMemoryMappedFile(struct memoryMappedFile *file)
{

	if (file->fileMapped)
	{
		munmap(file->fileBuffer, file->fileStat.st_size);
		file->fileBuffer = NULL;
		file->fileMapped = false;
	}
	if (file->fileDescriptor != -1)
	{
		close(file->fileDescriptor);
		file->fileDescriptor = -1;
	}

}

bool checkConfigArea(struct _avm_kernel_config ** configArea)
{
	/* we could try to check the expected structure of a config area here,
       but let's do this later
	*/
	return true;
}

struct _avm_kernel_config ** findConfigArea(void *dtbLocation)
{
	struct _avm_kernel_config **	configArea = NULL;

	/* previous 4K boundary should be the start of the config area 
	*/
	configArea = (struct _avm_kernel_config **) (((int) dtbLocation >> 12) << 12);
	if (checkConfigArea(configArea)) return configArea;
	return NULL;
}

void * findDTB(void *haystack, size_t haystackSize, void *needle, size_t needleSize)
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
			if (toSearch > 0) /* match found for first uint32 */
			{	
				matchedSoFar = true;
				resetToSearch = --toSearch;
				resetSliding = ++sliding;
				offsetMatched = sizeof(uint32_t);
				if ((needleSize - offsetMatched) > sizeof(uint32_t))
				{
					while (offsetMatched < needleSize)
					{
						if (*(lookFor + (offsetMatched / sizeof(uint32_t))) != *sliding) /* difference found, reset match */
						{
							matchedSoFar = false;
							sliding = resetSliding;
							toSearch = resetToSearch;
							break;
						}
						offsetMatched += sizeof(uint32_t);
						sliding++;
						toSearch--;
						if (toSearch == 0) break; /* end of kernel reached, DTB isn't expected at the very end */	
						if ((needleSize - offsetMatched) < sizeof(uint32_t)) break;
					}
				}
				if (matchedSoFar) /* compare remaining bytes */
				{
					uint8_t *	remHaystack = (uint8_t *) sliding;
					uint8_t *	remNeedle = (uint8_t *) (needle + offsetMatched);
					size_t		remSize = needleSize - offsetMatched;

					while (remSize > 0)
					{
						if (*remHaystack != *remNeedle) /* difference found */
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
					if (remSize == 0) /* match completed */
					{
						location = (void *) resetSliding;
						break;
					} 
				}
			}
		}
	}
	return location;
}

int main(int argc, char * argv[])
{
	int						returnCode = 1;
	struct memoryMappedFile	kernel;
	struct memoryMappedFile	dtb;

	if (argc < 3)
	{
		usage();
		exit(1);
	}
	if (openMemoryMappedFile(&kernel, argv[1], "unpacked kernel", O_RDONLY | O_SYNC, PROT_READ, MAP_SHARED))
	{
		if (openMemoryMappedFile(&dtb, argv[2], "device tree BLOB", O_RDONLY | O_SYNC, PROT_READ, MAP_SHARED))
		{
			void *	dtbLocation = findDTB(kernel.fileBuffer, kernel.fileStat.st_size, dtb.fileBuffer, dtb.fileStat.st_size);
		
			if (dtbLocation != NULL)
			{
				struct _avm_kernel_config * *configArea = findConfigArea(dtbLocation);
				
				if (configArea != NULL)
				{
					ssize_t	written = write(1, (void *) configArea, 64 * 1024);

					if (written == 64 * 1024)
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
			else
			{
				fprintf(stderr, "The device tree BLOB was not found in the unpacked kernel image.\n");
			}
			closeMemoryMappedFile(&dtb);
		}
		closeMemoryMappedFile(&kernel);
	}
	exit(returnCode);
}

