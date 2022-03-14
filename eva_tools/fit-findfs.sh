#! /bin/sh
# vim: set tabstop=4 syntax=sh :
# SPDX-License-Identifier: GPL-2.0-or-later
find_filesystem_in_fit_image()
(
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
	get_data() ( dd if="$1" bs="$3" count=$(( ( $2 / $3 ) + 1 )) skip=1 2>"$null" | dd bs=1 count="$2" 2>"$null"; )
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
		l="$(get_data "$1" 256 "$2" | cmp -l -- - "$zeros" 2>"$null" | strlen)"
		[ -n "$l" ] && get_data "$1" "$l" "$2"
	)
	fdt32_align() { [ $(( $1 % 4 )) -gt 0 ] && printf -- "%u\n" $(( ( $1 + fdt32_size ) & ~3 )) || printf -- "%u\n" "$1"; }
	get_fdt32_be() ( get_data "$1" 4 "$2" | b2d; )
	get_fdt32_cpu() ( get_data "$1" 4 "$2" | tbo | b2d; )
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
		ro() {
			i=0
			while read -r p l _; do
				i=$(( i + 1 ))
				[ "$p" -gt "$i" ] && [ "$i" -eq 1 ] && return 1
				[ "$l" -lt 040 ] && return 1
				[ "$l" -gt 0176 ] && return 1
			done
			[ "$i" -eq 0 ] && [ "$1" -eq 1 ] && return 1;
			[ "$i" -lt $(( $1 - 1 )) ] && return 1
			return 0
		}
		get_data "$1" "$3" "$2" | cmp -l -- - "$zeros" 2>"$null" | ro "$3"
		return $?
	)
	usage() {
		exec 1>&2
		printf -- "fit-findfs.sh - find filesystem entries in a FIT image\n\n"
		printf -- "Usage: %s [ -c | --force-copy ] <fit-image>\n\n" "$0"
	}

	null="/dev/null"
	zeros="/dev/zero"
	type_name="type"
	filesystem_type="filesystem"

	filesystem_offset=0
	filesystem_size=0

	fdt_begin_node=1
	fdt_end_node=2
	fdt_prop=3
	fdt_nop=4
	fdt_end=9
	fdt32_size=4

	[ "$(dd if=/proc/self/exe bs=1 count=1 skip=5 2>"$null" | b2d)" -eq 1 ] && end="(LE)" || end="(BE)"

	force_tmpcopy=0
	while [ "$(expr "$1" : "\(.\).*")" = "-" ]; do
		[ "$1" = "--" ] && shift && break

		if [ "$1" = "-f" ] || [ "$1" = "--force-copy" ]; then
			force_tmpcopy=1
			shift
		else
			printf "Unknown option: %s\a\n" "$1" 1>&2 && exit 1
		fi
	done

	img="$1"
	[ "$(dd if="$img" bs=4 count=1 2>"$null" | b2d)" = "218164734" ] || exit 1

	offset=$(( offset + fdt32_size ))
	payload_size="$(get_fdt32_cpu "$img" "$offset")"

	if ! [ -f "$img" ] || [ "$force_tmpcopy" -eq 1 ]; then
		tmpdir="${TMP:-$TMPDIR}"
		[ -z "$tmpdir" ] && tmpdir="/tmp"
		tmpimg="$tmpdir/fit-image-$$"
		# slower copying with 1M blocks, but it needs less buffer space for 'dd' - it's a one-time action
		dd if="$img" of="$tmpimg" bs=$(( 1024 * 1024 )) count=$(( ( payload_size + 64 + 8 ) / ( 1024 * 1024 ) + 1 )) 2>$null || exit 1
		trap '[ -f "$tmpimg" ] && rm -f "$tmpimg" 2>/dev/null' EXIT
		img="$tmpimg"
	fi

	offset=$(( offset + fdt32_size + 64 ))
	fdt_magic="$(get_fdt32_be "$img" "$offset")"

	[ "$fdt_magic" -ne 3490578157 ] && printf "Invalid FDT magic found.\a\n" 1>&2 && exit 1

	fdt_start=$offset
	offset=$(( offset + fdt32_size ))

	fdt_totalsize="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

	fdt_off_dt_struct="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

	fdt_off_dt_strings="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

#	fdt_off_mem_rsvmap="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

	fdt_version="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

	fdt_last_comp_version="$(get_fdt32_be "$img" "$offset")"

	if [ "$fdt_version" -ge 2 ]; then
		offset=$(( offset + fdt32_size ))
#		fdt_boot_cpuid_phys="$(get_fdt32_be "$img" "$offset")"

		if [ "$fdt_version" -ge 2 ]; then
			offset=$(( offset + fdt32_size ))
#			fdt_size_dt_strings="$(get_fdt32_be "$img" "$offset")"

			if [ "$fdt_version" -ge 17 ]; then
				offset=$(( offset + fdt32_size ))
#				fdt_size_dt_struct="$(get_fdt32_be "$img" "$offset")"
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
				offset=$(fdt32_align $(( offset + fdt32_size + ${#name} + 1 )) )
				;;
			("$fdt_end_node")
				offset=$(( offset + fdt32_size ))
				;;
			("$fdt_prop")
				value_size="$(get_fdt32_be "$img" $(( offset + fdt32_size )))"
				name_off="$(( fdt_start + fdt_off_dt_strings + $(get_fdt32_be "$img" $(( offset + ( 2 * fdt32_size ) )) ) ))"
				eval "$(get_string "$img" $name_off "name")"
				data_offset=$(( offset + 3 * fdt32_size ))
				if [ "$value_size" -gt 512 ]; then
					last_blob_offset="$data_offset"
					last_blob_size="$value_size"
				elif is_printable_string "$img" "$data_offset" "$value_size"; then
					eval "$(get_string "$img" $(( offset + 3 * fdt32_size )) "str")"
					if [ -n "$str" ]; then
						if [ "$name" = "$type_name" ] && [ "$str" = "$filesystem_type" ]; then
							# assume 'data' entry was processed already, should be re-implemented with recursion for nodes
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
				offset=$(( offset + fdt32_size ))
				break
				;;
		esac
		data=$(get_fdt32_be "$img" "$offset")
	done

	printf -- "filesystem_offset=%u filesystem_size=%u\n" "$filesystem_offset" "$filesystem_size"

)

find_filesystem_in_fit_image "$@"
