#! /bin/sh
if [ -z "$1" ]; then
	printf "Provide the name of proper loader/linker script for your Linux kernel (usally a file named vmlinux.lds.S) as parameter.\n" 1>&2
	exit 1
fi
if [ "$(sed -n -e "/__avm_kernel_config_start = \.;/,/__avm_kernel_config_end = \.;/p" "$1" 2>/dev/null | wc -l)" = "3" ]; then
	sed -n -e "/__avm_kernel_config_start = \.;/,/__avm_kernel_config_end = \.;/p" "$1" | sed -n -e "2s/[ \t]*\. += \([0-9]*\) \* 1024;/\1/p"
	exit 0
else
	printf "Unable to locate avm_kernel_config lines in the provided file or file does not exist.\n" 1>&2
fi
exit 1
