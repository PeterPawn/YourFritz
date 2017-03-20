// vi: set tabstop=4 syntax=c :
#ifndef AVM_KERNEL_CONFIG_HELPERS_H
#define AVM_KERNEL_CONFIG_HELPERS_H

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
#else // FREETZ
#include "linux/include/uapi/linux/avm_kernel_config.h"
#endif // FREETZ

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
