#ifndef _INCLUDE_AVM_KERNEL_CONFIG_H_
#define _INCLUDE_AVM_KERNEL_CONFIG_H_

enum _avm_kernel_config_tags {
	avm_kernel_config_tags_undef,
	avm_kernel_config_tags_modulememory,
	avm_kernel_config_tags_version_info,
	avm_kernel_config_tags_hw_config,
	avm_kernel_config_tags_cache_config,
	avm_kernel_config_tags_device_tree_subrev_0,  /* subrev müssen aufeinander folgen */
	avm_kernel_config_tags_device_tree_subrev_1,
	avm_kernel_config_tags_device_tree_subrev_2,
	avm_kernel_config_tags_device_tree_subrev_3,
	avm_kernel_config_tags_device_tree_subrev_4,
	avm_kernel_config_tags_device_tree_subrev_5,
	avm_kernel_config_tags_device_tree_subrev_6,
	avm_kernel_config_tags_device_tree_subrev_7,
	avm_kernel_config_tags_device_tree_subrev_8,
	avm_kernel_config_tags_device_tree_subrev_9,  /* subrev müssen aufeinander folgen */
	avm_kernel_config_tags_device_tree_subrev_last = avm_kernel_config_tags_device_tree_subrev_9,
	avm_kernel_config_tags_avmnet,
	avm_kernel_config_tags_last
};

#define avm_subrev_max \
	(avm_kernel_config_tags_device_tree_subrev_last - \
	 avm_kernel_config_tags_device_tree_subrev_0 + 1)

struct _kernel_modulmemory_config {
	char *name;
	unsigned int size;
};

struct _avm_kernel_config {
	enum _avm_kernel_config_tags tag;
	void *config;
};

struct _avm_kernel_version_info {
    char buildnumber[32];
    char svnversion[32];
    char firmwarestring[128];
};

#endif
