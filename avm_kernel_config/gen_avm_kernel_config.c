// vi: set tabstop=4 syntax=c :                                       
/***********************************************************************
 *                                                                     *
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

#include "avm_kernel_config_helpers.h"

void usage()
{

	fprintf(stderr, "gen_avm_kernel_config - generate a kernel config source file\n\n");
	fprintf(stderr, "(C) 2016 P. Hämmerlein (http://www.yourfritz.de)\n\n");
	fprintf(stderr, "Licensed under GPLv2, see LICENSE file from source repository.\n\n");
	fprintf(stderr, "Usage:\n\n");
	fprintf(stderr, "gen_avm_kernel_config <binary_config_area_file>\n");
	fprintf(stderr, "\nThe configuration area dump is read and an assembler source file");
	fprintf(stderr, "\nis created from its content. This file may later be compiled into");
	fprintf(stderr, "\nan object file ready to be included into an own kernel while");
	fprintf(stderr, "\nlinking it.\n");
	fprintf(stderr, "\nThe output is written to STDOUT, so you've to redirect it to the");
	fprintf(stderr, "\nproper location.\n");

}

bool relocateConfigArea(struct _avm_kernel_config * *configArea, size_t configSize)
{
	bool						swapNeeded;
	uint32_t     		 		kernelOffset;
	uint32_t					configBase;
	struct _avm_kernel_config *	entry;

	//	- the configuration area is aligned on a 4K boundary and the first 32 bit contain a
	//	  pointer to an 'struct _avm_kernel_config' array
	//	- we take the first 32 bit value from the dump and align this pointer to 4K to get
	//	  the start address of the area in the linked kernel

	if (!detectInputEndianess(configArea, configSize, &swapNeeded)) return false;

	configBase = (uint32_t) configArea;
	swapEndianess(swapNeeded, (uint32_t *) configArea);

	kernelOffset = (uint32_t) *((uint32_t *) configArea) & 0xFFFFF000;

	entry = (struct _avm_kernel_config *) (*((uint32_t *) configArea) - kernelOffset + configBase);
	*configArea = entry;

	if (entry == NULL) return false;

	swapEndianess(swapNeeded, &entry->tag);

	while (entry->tag <= avm_kernel_config_tags_last)
	{
		if (entry->config == NULL) break;

		swapEndianess(swapNeeded, (uint32_t *) &entry->config);
		entry->config = (void *) ((uint32_t) entry->config - kernelOffset + configBase);

		if ((int) entry->tag == avm_kernel_config_tags_modulememory)
		{	
			// only _kernel_modulmemory_config entries need relocation of members
			struct _kernel_modulmemory_config *	module = (struct _kernel_modulmemory_config *) entry->config;
			
			while (module->name != NULL)
			{	
				swapEndianess(swapNeeded, (uint32_t *) &module->name);
				module->name = (char *) ((uint32_t) module->name - kernelOffset + configBase);
				swapEndianess(swapNeeded, &module->size);

				module++;
			}
		}

		entry++;
		swapEndianess(swapNeeded, &entry->tag);
	}

	return true;
}

void processDeviceTrees(struct _avm_kernel_config * *configArea)
{
	struct _avm_kernel_config *	entry = *configArea;

	if (entry == NULL) return;

	fprintf(stdout, "\n"); // empty line as optical delimiter in front of DTB dump

	while (entry->tag <= avm_kernel_config_tags_last)
	{
		if (entry->config == NULL) return;

		if (entry->tag >= avm_kernel_config_tags_device_tree_subrev_0 && entry->tag <= avm_kernel_config_tags_device_tree_subrev_last)
		{
			unsigned int 	subRev = entry->tag - avm_kernel_config_tags_device_tree_subrev_0;
			uint32_t		dtbSize = *(((uint32_t *) entry->config) + 1);
			uint32_t		i;

			fprintf(stdout, ".L_avm_device_tree_subrev_%u:\n", subRev);
			fprintf(stdout, "\tAVM_DEVICE_TREE_BLOB\t%u\n", subRev);

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
			// the 'dtc' compiler always emits this value in 'big endian' (using ASM_EMIT_BELONG
			// in 'flattree.c' - see there)
			swapEndianess(true, &dtbSize);
#endif

			register uint8_t *	source = (uint8_t *) entry->config;
			while (dtbSize > 0) 
			{
				i = (dtbSize > 16 ? 16 : dtbSize);
				dtbSize -= i;
	
				fprintf(stdout, "\t.byte\t");
				while (i--) fprintf(stdout, "0x%02x%c", *(source++), (i ? ',' : '\n'));
			}
		}

		entry++;
	}
}

void processVersionInfo(struct _avm_kernel_config * *configArea)
{
	struct _avm_kernel_config *	entry = *configArea;

	if (entry == NULL) return;

	while (entry->tag <= avm_kernel_config_tags_last)
	{
		if (entry->config == NULL) return;

		if (entry->tag == avm_kernel_config_tags_version_info)
		{
			struct _avm_kernel_version_info *	version = (struct _avm_kernel_version_info *) entry->config;
		
			fprintf(stdout, "\n\tAVM_VERSION_INFO\t\"%s\", \"%s\", \"%s\"\n", version->buildnumber, version->svnversion, version->firmwarestring);
		}

		entry++;
	}

}

void processModuleMemoryEntries(struct _avm_kernel_config * *configArea)
{
	struct _avm_kernel_config *	entry = *configArea;

	if (entry == NULL) return;

	while (entry->tag <= avm_kernel_config_tags_last)
	{
		if (entry->config == NULL) return;

		if (entry->tag == avm_kernel_config_tags_modulememory)
		{
			struct _kernel_modulmemory_config *	module = (struct _kernel_modulmemory_config *) entry->config;
			int									mod_no = 0;
				
			fprintf(stdout, "\n.L_avm_module_memory:\n");
			while (module->name != NULL)
			{
				fprintf(stdout, "\tAVM_MODULE_MEMORY\t%u, \"%s\", %u\n", ++mod_no, module->name, module->size);
				module++;
			}
			fprintf(stdout, "\tAVM_MODULE_MEMORY\t0\n");
		}

		entry++;
	}

}

bool hasModuleMemory(struct _avm_kernel_config * *configArea)
{
	struct _avm_kernel_config *	entry = *configArea;

	if (entry == NULL) return false;

	while (entry->tag <= avm_kernel_config_tags_last)
	{
		if (entry->config == NULL) return false;
		if (entry->tag == avm_kernel_config_tags_modulememory) return true;
		entry++;
	}

	return false;
}

bool hasVersionInfo(struct _avm_kernel_config * *configArea)
{
	struct _avm_kernel_config *	entry = *configArea;

	if (entry == NULL) return false;

	while (entry->tag <= avm_kernel_config_tags_last)
	{
		if (entry->config == NULL) return false;
		if (entry->tag == avm_kernel_config_tags_version_info) return true;
		entry++;
	}

	return false;
}

bool hasDeviceTree(struct _avm_kernel_config * *configArea, int i)
{
	struct _avm_kernel_config *	entry = *configArea;

	if (entry == NULL) return false;

	while (entry->tag <= avm_kernel_config_tags_last)
	{
		if (entry->config == NULL) return false;
		if ((int) entry->tag == (avm_kernel_config_tags_device_tree_subrev_0 + i)) return true;
		entry++;
	}

	return false;
}

int processConfigArea(struct _avm_kernel_config * *configArea)
{
	bool	outputModuleMemory = hasModuleMemory(configArea);
	bool	outputVersionInfo = hasVersionInfo(configArea);
	bool	outputDeviceTrees = false;
	
	fprintf(stdout, "#include \"avm_kernel_config_macros.h\"\n\n");

	fprintf(stdout, "\tAVM_KERNEL_CONFIG_START\n\n");
	fprintf(stdout, "\tAVM_KERNEL_CONFIG_PTR\n\n");
	fprintf(stdout, ".L_avm_kernel_config_entries:\n");

	if (outputModuleMemory) fprintf(stdout, "\tAVM_KERNEL_CONFIG_ENTRY\t%u, \"module_memory\"\n", avm_kernel_config_tags_modulememory);

	if (outputVersionInfo) fprintf(stdout, "\tAVM_KERNEL_CONFIG_ENTRY\t%u, \"version_info\"\n", avm_kernel_config_tags_version_info);

	// device tree for subrevision 0 is the fallback entry and may be expected 
	// as 'always present', if FDTs exist at all
	if (hasDeviceTree(configArea, 0))
	{
		outputDeviceTrees = true;
		fprintf(stdout, "\tAVM_KERNEL_CONFIG_ENTRY\t%u, \"device_tree_subrev_0\"\n", avm_kernel_config_tags_device_tree_subrev_0);
	}

	fprintf(stdout, "\tAVM_KERNEL_CONFIG_ENTRY\t0\n");

	if (outputDeviceTrees) processDeviceTrees(configArea);
	if (outputVersionInfo) processVersionInfo(configArea);
	if (outputModuleMemory) processModuleMemoryEntries(configArea);

	fprintf(stdout, "\n\tAVM_KERNEL_CONFIG_END\n\n");

	return 0;
}

int main(int argc, char * argv[])
{
	int						returnCode = 1;
	struct memoryMappedFile	input;

	if (argc < 2)
	{
		usage();
		exit(1);
	}

	if (openMemoryMappedFile(&input, argv[1], "input", O_RDONLY | O_SYNC, PROT_WRITE, MAP_PRIVATE))
	{
		struct _avm_kernel_config **	configArea = (struct _avm_kernel_config **) input.fileBuffer;
		size_t							configSize = input.fileStat.st_size;
		
		if (relocateConfigArea(configArea, configSize))
		{
			returnCode = processConfigArea(configArea);
		}
		else
		{
			fprintf(stderr, "Unable to identify and relocate the specified config area dump file, may be it's empty.\n"); 
			returnCode = 1;
		}
		closeMemoryMappedFile(&input);
	}

	exit(returnCode);
}

