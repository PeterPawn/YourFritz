#! /bin/sh
[ -t 1 ] && exec 1>./900-patchkernel_source
diff -u /dev/null ./yf_patchkernel.c | sed -e '1s|.*|--- /dev/null|' -e '2s|.*|+++ linux-3.10/drivers/net/yf_patchkernel.c|'
