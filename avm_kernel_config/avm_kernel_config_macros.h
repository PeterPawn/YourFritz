/* vi: set tabstop=4 syntax=asm : */
#ifndef _AVM_KERNEL_CONFIG_MACROS_H
#define _AVM_KERNEL_CONFIG_MACROS_H

#define akc 	10
#define	sakc	11	

	.macro	AVM_KERNEL_CONFIG_START
		.data		akc
.L_avm_kernel_config_first_byte:
	.endm

	.macro	AVM_KERNEL_CONFIG_END
.L_avm_kernel_config_last_byte:
	.endm

	.macro	AVM_KERNEL_CONFIG_PTR
		.data		akc
		.int		.L_avm_kernel_config_entries
		.align		16
	.endm

	.macro	AVM_KERNEL_CONFIG_ENTRY tag, label
		.data		akc
		.int		\tag
		.ifeq		\tag
			.int	0
		.else		
			.int	.L_avm_\label
		.endif
	.endm

	.macro	AVM_VERSION_INFO buildnumber, svnversion, firmwarestring
		.data		akc
		.align		8
.L_avm_version_info:
1:
		.ascii		"\buildnumber"
		.zero		32 - (. - 1b)
2:
		.ascii		"\svnversion"
		.zero		32 - (. - 2b)
3:
		.ascii		"\firmwarestring"
		.zero		128 - (. - 3b)
	.endm

	.macro	AVM_MODULE_MEMORY index, module, size
		.ifeq	\index
			.data		akc
			.int		0
			.int		0
		.else
			.data		sakc
.L_avm_module_memory_\index:
			.asciz		"\module"
			.align		4
			.data		akc
			.int		.L_avm_module_memory_\index
			.int		\size
		.endif
	.endm

	.macro	AVM_DEVICE_TREE_BLOB subrevision
		.data		akc
	.endm

	.macro	AVM_DEVICE_TREE subrevision, filename
		.data		akc
		.int		avm_kernel_config_tags_device_tree_subrev_\subrevision
		.int		._L_avm_device_tree_\subrevision
	.endm

#endif
