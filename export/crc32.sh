#! /bin/sh
crc32() (
	poly() { eval l=\$poly_$(( ( $2 & 255 ) ^ ( 0$1 & 255 ) )); printf -- "%u\n" "$(( ( ( $2 & 0xFFFFFFFF ) >> 8 ) ^ l ))"; }
	crc() { i=1; c=-1; while read -r p l _; do while [ "$p" -gt "$i" ]; do c=$(poly 0 "$c"); i=$(( i + 1 )); done; c=$(poly "$l" "$c"); i=$(( i + 1 )); done; c=$(( ~c )); printf -- "%08x\n" "$(( c & 0xFFFFFFFF ))"; }
	i=0; while [ $i -lt 256 ]; do r=$i; j=0; while [ $j -lt 8 ]; do [ $(( r & 1 )) -eq 1 ] && r=$(( ( ( r >> 1 ) & 0x7FFFFFFF ) ^ 0xEDB88320 )) || r=$(( ( r >> 1 ) & 0x7FFFFFFF )); j=$(( j + 1 )); done; eval poly_$i=$r; i=$(( i + 1 )); done;
	cmp -l -- - /dev/zero 2>/dev/null | crc
)
crc32
