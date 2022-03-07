#! /bin/sh
# vim: set tabstop=4 syntax=sh :
# SPDX-License-Identifier: GPL-2.0-or-later
find_filesystem_in_fit_image()
(
	printf_ss() {
		mask="$1"
		shift
		# shellcheck disable=SC2059
		printf -- "$mask" "$@"
	}
	msg() { [ "$debug" -eq 1 ] || return; printf_ss "$@" 1>&2; }
	tbo() (
		tbo_ro()
		{
			v1=0; v2=0; v3=0; v4=0
			while read -r p _ rt; do
				[ "$p" -gt 5 ] && exit 1
				[ "$p" -eq 5 ] && [ "$rt" -ne 0377 ] && exit 1
				if [ "$p" -eq 5 ]; then
					for i in $v4 $v3 $v2 $v1; do
						printf -- "%b" "\0$(printf -- "%o" "$i")"
					done
					exit 0
				fi
				eval "v$p"=$(( 0$rt ))
			done
			exit 1
		}
		if [ "$(dd if=/proc/self/exe bs=1 count=1 skip=5 2>"$null" | b2d)" -eq 1 ]; then
			( cat; printf -- "%b" "\377" ) | cmp -l -- "$zeros" - 2>"$null" | tbo_ro
		else
			cat - 2>"$null"
		fi
	)
	b2d() (
		b2d_ro()
		{
			i=1; l=0; v=0; s=-8; ff=0
			while read -r p _ rt; do
				if [ "$ff" -eq 1 ]; then
					v=$(( v * 256 ))
					ff=255
					v=$(( v + ff ))
					i=$(( i + 1 ))
					ff=0
				fi
				while [ "$i" -lt "$p" ]; do
					v=$(( v * 256 ))
					i=$(( i + 1 ))
				done
				if [ "$rt" = 377 ] && [ $ff -eq 0 ]; then
					ff=1
					continue
				fi
				v=$(( v * 256 ))
				rt=$(( 0$rt ))
				v=$(( v + rt ))
				i=$(( p + 1 ))
			done
			printf -- "%d" $v
		}
		( cat; printf -- "%b" "\377" ) | cmp -l -- "$zeros" - 2>"$null" | b2d_ro
		return 0
	)
	str() (
		strlen()
		{
			s=1
			while read -r p l _; do
				[ "$p" -ne "$s" ] && printf -- "%u\n" "$(( s - 1 ))" && return
				s=$(( s + 1 ))
			done
			printf -- "%u\n" "$(( s - 1 ))"
		}
		l="$(dd if="$1" bs=1 skip="$2" 2>"$null" | cmp -l -- - "$zeros" 2>"$null" | strlen)"
		[ -n "$l" ] && dd if="$1" bs=1 skip="$2" count="$l" 2>"$null"
	)
	get_data() (
		dd if="$1" bs=1 count="$2" skip="$3" 2>"$null"
	)
	fdt32_align() { [ $(( $1 % 4 )) -gt 0 ] && printf -- "%u\n" $(( ( $1 + fdt32_size ) & ~3 )) || printf -- "%u\n" "$1"; }
	get_fdt32_be() (
		dd if="$1" bs=4 count=1 skip=$(( $2 / 4 )) 2>"$null" | b2d
	)
	get_fdt32_cpu() (
		dd if="$1" bs=4 count=1 skip=$(( $2 / 4 )) 2>"$null" | tbo | b2d
	)
	get_string() {
		n="$(printf -- "__fdt_string_%u" "$2")"
		f="$(set | sed -n -e "s|^\($n=\).*|\1|p")"
		if [ -z "$f" ]; then
			v="$(str "$1" "$2")"
			printf -- "%s=\"%s\"\n%s=\"\$%s\"\n" "$n" "$v" "$3" "$n"
		else
			v="$(set | sed -n -e "s|^$n=\(['\"]\?\)\(.*\)\1|\2|p")"
			printf -- "%s=\"\$%s\"\n" "$3" "$n"
		fi
	}
	is_printable_string() (
		i=0
		while [ $i -lt "$3" ]; do
			c="$(dd if="$1" bs=1 skip=$(( $2 + i )) count=1 2>"$null" | b2d)"
			i=$(( i + 1 ))
			if [ "$i" -eq "$3" ] && [ "$c" -eq 0 ]; then
				[ "$i" -eq 1 ] && return 1 || return 0
			fi
			[ "$c" -lt 32 ] && return 1
			[ "$c" -gt 126 ] && return 1
		done
		return 0
	)
	usage() {
		exec 1>&2
		printf -- "fit-findfs.sh - find filesystem entries in a FIT image\n\n"
		printf -- "Usage: %s [ -d | --debug ] <fit-image>\n\n" "$0"
	}

	null="/dev/null"
	zeros="/dev/zero"
	type_name="type"
	filesystem_type="filesystem"

	filesystem_offset=0
	filesystem_size=0

	debug=0
	while [ "$(expr "$1" : "\(.\).*")" = "-" ]; do
		[ "$1" = "--" ] && shift && break

		if [ "$1" = "-d" ] || [ "$1" = "--debug" ]; then
			debug=1
			shift
		fi
	done

	fdt_begin_node=1
	fdt_end_node=2
	fdt_prop=3
	fdt_nop=4
	fdt_end=9
	fdt32_size=4

	[ "$(dd if=/proc/self/exe bs=1 count=1 skip=5 2>"$null" | b2d)" -eq 1 ] && end="(LE)" || end="(BE)"

	img="$1"
	[ -f "$img" ] && fsize=$(( $(wc -c <"$img" 2>"$null" || printf -- "0") )) || fsize=0
	[ "$fsize" -eq 0 ] && usage && exit 1
	msg "File: %s, size=%u\n" "$img" "$(wc -c < "$img" 2>"$null")"

	[ "$(dd if="$img" bs=4 count=1 2>"$null" | b2d)" = "218164734" ] || exit 1
	offset=0
	msg "Signature at offset 0x%02x: 0x%08x %s\n" "$offset" "$(get_fdt32_cpu "$img" "$offset")" "$end"

	offset=$(( offset + fdt32_size ))
	payload_size="$(get_fdt32_cpu "$img" "$offset")"
	msg "Overall length of data at offset 0x%02x: 0x%08x - dec.: %u %s\n" "$offset" "$payload_size" "$payload_size" "$end"

	offset=$(( offset + fdt32_size ))
	size=64
	msg "Data at offset 0x%02x, size %u:\n" "$offset" "$size"
	[ "$debug" -eq 1 ] && get_data "$img" "$size" "$offset" | hexdump -C | sed -n -e "1,$(( size / 16 ))p" 1>&2

	offset=$(( offset + size ))
	fdt_magic="$(get_fdt32_be "$img" "$offset")"
	msg "FDT magic at offset 0x%02x: 0x%08x %s\n" "$offset" "$fdt_magic" "(BE)"
	[ "$fdt_magic" -ne 3490578157 ] && msg "Invalid FDT magic found.\n" && exit 1
	fdt_start=$offset

	offset=$(( offset + fdt32_size ))
	fdt_totalsize="$(get_fdt32_be "$img" "$offset")"
	msg "FDT total size at offset 0x%02x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_totalsize" "$fdt_totalsize" "(BE)"

	offset=$(( offset + fdt32_size ))
	fdt_off_dt_struct="$(get_fdt32_be "$img" "$offset")"
	msg "FDT structure offset: 0x%08x (dec.: %u) %s\n" "$fdt_off_dt_struct" "$fdt_off_dt_struct" "(BE)"

	offset=$(( offset + fdt32_size ))
	fdt_off_dt_strings="$(get_fdt32_be "$img" "$offset")"
	msg "FDT strings offset: 0x%08x (dec.: %u) %s\n" "$fdt_off_dt_strings" "$fdt_off_dt_strings" "(BE)"

	offset=$(( offset + fdt32_size ))
	fdt_off_mem_rsvmap="$(get_fdt32_be "$img" "$offset")"
	msg "FDT memory reserve map offset: 0x%08x (dec.: %u) %s\n" "$fdt_off_mem_rsvmap" "$fdt_off_mem_rsvmap" "(BE)"

	offset=$(( offset + fdt32_size ))
	fdt_version="$(get_fdt32_be "$img" "$offset")"
	msg "FDT version at offset 0x%04x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_version" "$fdt_version" "(BE)"

	offset=$(( offset + fdt32_size ))
	fdt_last_comp_version="$(get_fdt32_be "$img" "$offset")"
	msg "FDT last compatible version at offset 0x%04x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_last_comp_version" "$fdt_last_comp_version" "(BE)"

	if [ "$fdt_version" -ge 2 ]; then
		offset=$(( offset + fdt32_size ))
		fdt_boot_cpuid_phys="$(get_fdt32_be "$img" "$offset")"
		msg "FDT physical CPU ID while booting at offset 0x%04x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_boot_cpuid_phys" "$fdt_boot_cpuid_phys" "(BE)"

		if [ "$fdt_version" -ge 2 ]; then
			offset=$(( offset + fdt32_size ))
			fdt_size_dt_strings="$(get_fdt32_be "$img" "$offset")"
			msg "FDT size of strings block: 0x%08x (dec.: %u) %s\n" "$fdt_size_dt_strings" "$fdt_size_dt_strings" "(BE)"

			if [ "$fdt_version" -ge 17 ]; then
				offset=$(( offset + fdt32_size ))
				fdt_size_dt_struct="$(get_fdt32_be "$img" "$offset")"
				msg "FDT size of structure block: 0x%08x (dec.: %u) %s\n" "$fdt_size_dt_struct" "$fdt_size_dt_struct" "(BE)"
			fi
		fi
	fi

	offset=$(( fdt_start + fdt_off_dt_struct ))
	data=$(get_fdt32_be "$img" "$offset")
	# shellcheck disable=SC2050
	while [ 1 -eq 1 ]; do
		case "$data" in
			("$fdt_begin_node")
				name_off="$(( offset + fdt32_size ))"
				eval "$(get_string "$img" $name_off "name")"
				[ -z "$name" ] && name="/"
				msg "Begin node at offset 0x%08x, name=%s\n" "$offset" "$name"
				offset=$(fdt32_align $(( offset + fdt32_size + ${#name} + 1 )) )
				;;
			("$fdt_end_node")
				msg "End node at offset 0x%08x\n" "$offset"
				offset=$(( offset + fdt32_size ))
				;;
			("$fdt_prop")
				value_size="$(get_fdt32_be "$img" $(( offset + fdt32_size )))"
				name_off="$(( fdt_start + fdt_off_dt_strings + $(get_fdt32_be "$img" $(( offset + ( 2 * fdt32_size ) )) ) ))"
				eval "$(get_string "$img" $name_off "name")"
				msg "Property node at offset 0x%08x, value size=%u, name=%s\n" "$offset" "$value_size" "$name"
				data_offset=$(( offset + 3 * fdt32_size ))
				if [ "$value_size" -gt 512 ]; then
					last_blob_offset="$data_offset"
					last_blob_size="$value_size"
					msg "Found BLOB with %u bytes of data at offset 0x%08x\n" "$value_size" "$data_offset"
				elif is_printable_string "$img" "$data_offset" "$value_size"; then
					eval "$(get_string "$img" $(( offset + 3 * fdt32_size )) "str")"
					if [ -n "$str" ]; then
						if [ "$name" = "$type_name" ] && [ "$str" = "$filesystem_type" ]; then
							# assume 'data' entry was processed already
							if [ "$last_blob_size" -gt "$filesystem_size" ]; then
								filesystem_offset="$last_blob_offset"
								filesystem_size="$last_blob_size"
							fi
						fi
					fi
				fi
				offset=$(fdt32_align $(( data_offset + value_size )) )
				;;
			("$fdt_nop")
				offset=$(( offset + fdt32_size ))
				;;
			("$fdt_end")
				msg "FDT end found at offset 0x%08x\n" "$offset"
				offset=$(( offset + fdt32_size ))
				break
				;;
		esac
		data=$(get_fdt32_be "$img" "$offset")
	done
	printf -- "filesystem_offset=%u filesystem_size=%u\n" "$filesystem_offset" "$filesystem_size"
)

find_filesystem_in_fit_image "$@"
