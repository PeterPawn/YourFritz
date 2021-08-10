// vim: set tabstop=4 syntax=c :
/* SPDX-License-Identifier: GPL-2.0-or-later */
/***********************************************************************
 *                                                                     *
 *                                                                     *
 * Copyright (C) 2016-2021 P.Hämmerlein (http://www.yourfritz.de)      *
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

bool openMemoryMappedFile(struct memoryMappedFile *file, const char *fileName, const char *fileDescription, int openFlags, int prot, int flags)
{
	bool			result = false;

	file->fileMapped = false;
	file->fileBuffer = NULL;
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
			else fprintf(stderr, "Error %d mapping %u bytes of %s file '%s' to memory.\n", errno, (int) file->fileStat.st_size, file->fileDescription, file->fileName);
		}
		else fprintf(stderr, "Error %d getting file stats for '%s'.\n", errno, file->fileName);

		if (result == false)
		{
			close(file->fileDescriptor);
			file->fileDescriptor = -1;
		}
	}
	else fprintf(stderr, "Error %d opening %s file '%s'.\n", errno, file->fileDescription, file->fileName);

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

bool detectInputEndianess(struct _avm_kernel_config * *configArea, size_t configSize, bool *swapNeeded)
{
	uint32_t *					arrayStart = NULL;
	uint32_t *					arrayEnd = NULL;
	uint32_t *					ptr = NULL;
	uint32_t *					base = NULL;
	uint32_t					offset;
	uint32_t					tag;
	uint32_t					ptrValue;
	struct _avm_kernel_config *	entry;
	bool						assumeSwapped = false;

	//	- a 32-bit value with more than one byte containing a non-zero value
	//	  should be a pointer in the config area
	//	- a value with only one non-zero byte is usually the tag, tags are
	//	  'enums' and have to be below or equal avm_kernel_config_tags_last
	//	- values without any bit set are expected to be alignments or end of
	//	  array markers
	//	- we'll stop at the second 'end of array' marker, assuming we've
	//	  reached the end of 'struct _avm_kernel_config' array, the tag at
	//	  this array entry should be equal to avm_kernel_config_tags_last
	//	- limit search to first 16 KB (4096 * sizeof(uint32_t)), if the whole
	//	  area is empty

	ptr = (uint32_t *) configArea;

	while (ptr <= ((uint32_t *) configArea) + (4096 * sizeof(uint32_t)))
	{
		if (*ptr == 0)
		{
			if (base == NULL) return false; // no pointer, no content
			else
			{
				if (arrayStart != NULL) // last entry found
				{
					arrayEnd = ptr + 1;
					break;
				}
			}
		}
		else
		{
			if (base == NULL) base = ptr;
			else
			{
				if (arrayStart == NULL) arrayStart = ptr;
			}
		}
		ptr++;
	}

	// if we didn't find one of our pointers, something wents wrong
	if (base == NULL || arrayStart == NULL || arrayEnd == NULL) return false;

	// check avm_kernel_config_tags_last entry first
	entry = (struct _avm_kernel_config *) arrayEnd - 1;
	tag = entry->tag;
	if (tag == 0) return false;

	// set assumption
	assumeSwapped = (tag <= avm_kernel_config_tags_last ? false : true);

	// check other tags
	entry = (struct _avm_kernel_config *) arrayStart;
	do
	{
		tag = entry->tag;
		swapEndianess(assumeSwapped, &tag);
		// invalid value means, our assumption was wrong
		if (tag != 0 && tag > avm_kernel_config_tags_last) return false;
		if (tag == avm_kernel_config_tags_last) break;
		entry++;
	}
	while (entry->config != NULL);

	// now we compute offset in kernel
	ptrValue = *base;
	swapEndianess(assumeSwapped, &ptrValue);
	offset = ptrValue & 0xFFFFF000;

	// first value has to point to the array
	if ((ptrValue - offset) != ((uint32_t) arrayStart - (uint32_t) configArea))
		return false;

	// check each entry->config pointer, if its value is in range
	entry = (struct _avm_kernel_config *) arrayStart;
	do
	{
		ptrValue = (uint32_t) entry->config;
		swapEndianess(assumeSwapped, &ptrValue);

		if (ptrValue <= offset) return false; // points before, impossible
		if (ptrValue - offset > configSize) return false; // points after
		if (tag == avm_kernel_config_tags_last) break;
		entry++;
	}
	while (entry->config != NULL);

	// we may be sure here, that the endianess was detected successful
	*swapNeeded = assumeSwapped;
	return true;
}

void swapEndianess(bool needed, uint32_t *ptr)
{

	if (!needed) return;
	*ptr = 	(*ptr & 0x000000FF) << 24 | \
			(*ptr & 0x0000FF00) << 8 | \
			(*ptr & 0x00FF0000) >> 8 | \
			(*ptr & 0xFF000000) >> 24;

}

