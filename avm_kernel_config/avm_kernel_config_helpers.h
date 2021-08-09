// vim: set tabstop=4 syntax=c :
// SPDX-License-Identifier: GPL-2.0-or-later
#ifndef AVM_KERNEL_CONFIG_HELPERS_H
#define AVM_KERNEL_CONFIG_HELPERS_H

#ifdef FREETZ
#include <linux/avm_kernel_config.h>
#else // FREETZ
// ensure the uapi version gets included first
#include "linux/include/uapi/avm/enh/fw_info.h"
#include "linux/include/uapi/linux/avm_kernel_config.h"
#endif // FREETZ

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <stdbool.h>
#include <inttypes.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/mman.h>

struct memoryMappedFile
{
	const char *		fileName;
	const char *		fileDescription;
	int					fileDescriptor;
	struct stat			fileStat;
	void *				fileBuffer;
	bool				fileMapped;
};

bool openMemoryMappedFile(struct memoryMappedFile *file, const char *fileName, const char *fileDescription, int openFlags, int prot, int flags);
void closeMemoryMappedFile(struct memoryMappedFile *file);
bool detectInputEndianess(struct _avm_kernel_config * *configArea, size_t configSize, bool *swapNeeded);
void swapEndianess(bool needed, uint32_t *ptr);

#endif
