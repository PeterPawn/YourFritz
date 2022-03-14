#! /bin/sh
# vim: set tabstop=4 syntax=sh :
# SPDX-License-Identifier: GPL-2.0-or-later
#######################################################################################################
#                                                                                                     #
# dissect a FIT image with AVM's modified format                                                      #
#                                                                                                     #
###################################################################################################VER#
#                                                                                                     #
# fitdump.sh, version 0.2                                                                             #
#                                                                                                     #
# This script is a part of the YourFritz project from https://github.com/PeterPawn/YourFritz.         #
#                                                                                                     #
###################################################################################################CPY#
#                                                                                                     #
# Copyright (C) 2022 P.Haemmerlein (peterpawn@yourfritz.de)                                           #
#                                                                                                     #
###################################################################################################LIC#
#                                                                                                     #
# This project is free software, you can redistribute it and/or modify it under the terms of the GNU  #
# General Public License as published by the Free Software Foundation; either version 2 of the        #
# License, or (at your option) any later version.                                                     #
#                                                                                                     #
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without   #
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU       #
# General Public License under http://www.gnu.org/licenses/gpl-2.0.html for more details.             #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# This script reads a FIT image in AVM's own format and generates an .its file as source for further  #
# 'mkimage' calls, while all binary data with a length > 512 bytes will be written to separate files, #
# which will be included with '/incbin/' statements.                                                  #
#                                                                                                     #
# All output will be written to a new folder 'fit-dump' in the current working directory, which may   #
# not exist already.                                                                                  #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# the whole logic as a sealed sub-function                                                            #
#                                                                                                     #
#######################################################################################################
dissect_fit_image()
(
	printf_ss() {
		mask="$1"
		shift
		# shellcheck disable=SC2059
		printf -- "$mask" "$@"
	}
	msg() { [ "$debug" -eq 1 ] || return; printf_ss "$@" 1>&2; }
	out() (
		mask="$1"
		shift
		IFS=""
		# shellcheck disable=SC2059
		line="$(printf -- "$mask" "$@")"
		printf -- "%s" "$line"
		printf -- "%s" "$line" >>"$its_file"
		if [ "$(expr "$mask" : ".*\(\\\\n\)\$")" = "\\n" ]; then
			printf -- "\n"
			printf -- "\n" >>"$its_file"
		fi
	)
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
	get_data() (
		measure dd if="$1" bs="$3" count=$(( ( $2 / $3 ) + 1 )) skip=1 2>"$null" | dd bs=1 count="$2" 2>"$null"
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
			duration "$(printf -- "string '%s' cached as '%s'" "$v" "$n")"
		else
			printf -- "%s=\"\$%s\"\n" "$3" "$n"
			duration "$(printf -- "cached string '%s' used" "$n")"
		fi
	}
	indent() { printf -- "%s" "$(expr "$indent_template" : "\( \{$(( curr_indent * 4 ))\}\).*")"; }
	incr_indent() { curr_indent=$(( curr_indent + 1 )); }
	decr_indent() { curr_indent=$(( curr_indent - 1 )); [ $curr_indent -lt 0 ] && curr_indent=0; }
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
	get_hex32() (
		i=0
		while [ "$i" -lt "$3" ]; do
			v=$(get_fdt32_be "$img" $(( $2 + i )) )
			[ "$i" -gt 0 ] && printf -- " "
			printf -- "0x%08x" "$v"
			i=$(( i + fdt32_size ))
		done
	)
	get_hex8() (
		i=0
		while [ "$i" -lt "$3" ]; do
			v="$(get_data "$img" 1 $(( $2 + i )) | b2d)"
			[ "$i" -gt 0 ] && printf -- " "
			printf -- "%02x" "$v"
			i=$(( i + 1 ))
		done
	)
	get_file() (
		off=$2
		wr=$3
		dd if="$1" bs=4 skip=$(( off / 4 )) count=$(( ( 1024 - off % 1024 ) / 4 )) 2>"$null"
		off=$(( off + ( 1024 - off % 1024 ) ))
		wr=$(( wr - ( 1024 - $2 % 1024 ) ))
		[ $wr -le 0 ] && exit
		dd if="$1" bs=1024 skip=$(( off / 1024 )) count=$(( wr / 1024 )) 2>"$null"
		off=$(( off + wr ))
		wr=$(( wr % 1024 ))
		off=$(( off - wr ))
		[ $wr -le 0 ] && exit
		dd if="$1" bs=4 skip=$(( off / 4 )) count=$(( wr / 4 )) 2>"$null"
		off=$(( off + wr ))
		wr=$(( wr % 4 ))
		off=$(( off - wr ))
		[ $wr -le 0 ] && exit
		dd if="$img" bs=1 skip=$(( off )) count=$(( wr )) 2>"$null"
	)
	usage() {
		__yf_ansi_sgr() { printf -- '\033[%sm' "$1"; }
		__yf_ansi_bold__="$(__yf_ansi_sgr 1)"
		__yf_ansi_reset__="$(__yf_ansi_sgr 0)"
		__yf_get_script_lines() {
			sed -n -e "/^#*${1}#\$/,/^#\{20\}.*#\$/p" -- "$0" | \
			sed -e '1d;$d' | \
			sed -e 's|# \(.*\) *#$|\1|' | \
			sed -e 's|^#*#$|--|p' | \
			sed -e '$d' | \
			sed -e 's| *$||'
		}
		__yf_show_script_name() {
			[ -n "$1" ] && printf -- '%s' "$1"
			printf -- '%s' "${0#*/}"
			[ -n "$1" ] && printf -- "%s" "${__yf_ansi_reset__}"
		}
		__yf_show_license() { __yf_get_script_lines 'LIC'; }
		__yf_show_version() {
			printf "\n${__yf_ansi_bold__}%s${__yf_ansi_reset__}, " "$(__yf_get_script_lines 'VER' | sed -n -e "2s|^\([^,]*\),.*|\1|p")"
			v_display="$(__yf_get_script_lines 'VER' | sed -n -e "2s|^[^,]*, \(.*\)|\1|p")"
			printf "%s\n" "$v_display"
		}
		__yf_show_copyright() { __yf_get_script_lines 'CPY'; }

		exec 1>&2
		__yf_show_version
		__yf_show_copyright
		__yf_show_license
		printf -- "\n"
		printf -- "%sfitdump.sh%s - dissect a FIT image into .its and blob files\n\n" "${__yf_ansi_bold__}" "${__yf_ansi_reset__}"

		printf -- "Usage: %s [ options ] <fit-image>\n\n" "$0"
		printf -- "Options:\n\n"
		printf -- "-d or --debug   - show extra information (on STDERR) while reading FDT structure\n"
		printf -- "-n or --no-its  - do not create an .its file as output\n"
		printf -- "-c or --copy    - copy source file to a temporary location prior to processing\n"
		printf -- "-m or --measure - measure execution time using /proc/timer-list and write log data to\n"
		printf -- "                  a file named 'fitdump.measure' in the output directory\n"
		printf -- "\n"
	}
	nsecs() { sed -n -e "s|^now at \([0-9]*\).*|\1|p" /proc/timer_list; }
	format_duration() (
		if [ $(( $1 - $2 )) -gt 1000000000 ]; then
			printf -- "%u." "$(( ( $1 - $2 ) / 1000000000 ))"
			diff=$(( ( $1 - $2 ) % 1000000000 ))
		else
			printf -- "0."
			diff=$(( $1 - $2 ))
		fi
		printf -- "%09u\n" "$diff"
	)
	measure() {
		start="$(nsecs)"
		"$@"
		r=$?
		end=$(nsecs)
		[ "$measr" -eq 1 ] && printf "measured time %s for: %s\n" "$(format_duration "$end" "$start")" "$*" 1>&3
		return $r
	}
	duration() {
		now=$(nsecs)
		[ "$measr" -eq 1 ] && printf "overall duration: %s: %s\n" "$(format_duration "$now" "$script_start")" "$*" 1>&3
	}

	null="/dev/null"
	zeros="/dev/zero"
	dump_dir="./fit-dump"
	its_name="image.its"
	its_file="$its_name"
	image_file_mask="image_%03u.bin"
	files=0
	tmpcopy=0
	measr=0
	curr_indent=0
	indent_template="$(dd if=$zeros bs=256 count=1 2>"$null" | tr '\000' ' ')"

	debug=0
	while [ "$(expr "$1" : "\(.\).*")" = "-" ]; do
		[ "$1" = "--" ] && shift && break

		if [ "$1" = "-d" ] || [ "$1" = "--debug" ]; then
			debug=1
			shift
		elif [ "$1" = "-c" ] || [ "$1" = "--copy" ]; then
			tmpcopy=1
			shift
		elif [ "$1" = "-n" ] || [ "$1" = "--no-its" ]; then
			its_file="$null"
			shift
		elif [ "$1" = "-m" ] || [ "$1" = "--measure" ]; then
			measr=1
			shift
		elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
			usage
			exit 0
		else
			printf "Unknown option: %s\a\n" "$1" 1>&2 && exit 1
		fi
	done

	if [ "$debug" -eq 1 ] && [ -t 2 ]; then
		its_file="$its_name"
		exec 1>"$its_file"
	fi

	fdt_begin_node=1
	fdt_end_node=2
	fdt_prop=3
	fdt_nop=4
	fdt_end=9
	fdt32_size=4

	script_start=$(nsecs)

	if [ -d "$dump_dir" ]; then
		printf "Subdirectory '%s' does exist already. Remove it, before calling this script.\a\n" "$dump_dir" 1>&2
		exit 1
	fi
	! mkdir "$dump_dir" && printf "Error creating subdirectory '%s', do you have write access?\a\n" "$dump_dir" 1>&2 && exit 1

	img="$1"
	if [ "${img#/}" = "${img}" ]; then
		img="../$img"
	fi
	cd "$dump_dir" || exit 1

	[ "$measr" -eq 1 ] && exec 3<>"fitdump.measure"

	duration "measure log initialized"

	[ "$(dd if=/proc/self/exe bs=1 count=1 skip=5 2>"$null" | b2d)" -eq 1 ] && end="(LE)" || end="(BE)"

#	[ -f "$img" ] && fsize=$(( $(wc -c <"$img" 2>"$null" || printf -- "0") )) || fsize=0
#	[ -f "$img" ] && [ "$fsize" -eq 0 ] && usage && exit 1
#	msg "File: %s, size=%u\n" "$1" "$fsize"

#	duration "input size read"

	[ "$(measure dd if="$img" bs=4 count=1 2>"$null" | b2d)" = "218164734" ] || exit 1
	offset=0
	msg "Signature at offset 0x%02x: 0x%08x %s\n" "$offset" "$(dd if="$img" bs=4 count=1 2>"$null" | tbo | b2d)" "$end"

	offset=$(( offset + fdt32_size ))
	payload_size="$(get_fdt32_cpu "$img" "$offset")"
	msg "Overall length of data at offset 0x%02x: 0x%08x - dec.: %u %s\n" "$offset" "$payload_size" "$payload_size" "$end"

	duration "signature and data size read"

	if [ "$tmpcopy" = "1" ]; then
		tmpdir="${TMP:-$TMPDIR}"
		[ -z "$tmpdir" ] && tmpdir="/tmp"
		tmpimg="$tmpdir/fit-image-$$"
		dd if="$img" of="$tmpimg" bs=$(( payload_size + 64 + 8 )) count=1 2>$null
		trap '[ -f "$tmpimg" ] && rm -f "$tmpimg" 2>/dev/null' EXIT
		img="$tmpimg"
		duration "image copied to tmpfs"
	fi

	offset=$(( offset + fdt32_size ))
	size=64
	msg "Data at offset 0x%02x, size %u:\n" "$offset" "$size"
	[ "$debug" -eq 1 ] && measure get_data "$img" "$size" "$offset" | hexdump -C | sed -n -e "1,$(( size / 16 ))p" 1>&2

	[ -f "$its_file" ] && rm -f "$its_file" 2>"$null"
	out "/dts-v1/;\n"

	offset=$(( offset + size ))
	fdt_magic="$(get_fdt32_be "$img" "$offset")"
	msg "FDT magic at offset 0x%02x: 0x%08x %s\n" "$offset" "$fdt_magic" "(BE)"
	[ "$fdt_magic" -ne 3490578157 ] && msg "Invalid FDT magic found.\n" && exit 1
	fdt_start=$offset
	out "// magic:\t\t0x%08x\n" "$fdt_magic"

	offset=$(( offset + fdt32_size ))
	fdt_totalsize="$(get_fdt32_be "$img" "$offset")"
	msg "FDT total size at offset 0x%02x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_totalsize" "$fdt_totalsize" "(BE)"
	out "// totalsize:\t\t0x%x (%u)\n" "$fdt_totalsize" "$fdt_totalsize"

	offset=$(( offset + fdt32_size ))
	fdt_off_dt_struct="$(get_fdt32_be "$img" "$offset")"
	msg "FDT structure offset: 0x%08x (dec.: %u) %s\n" "$fdt_off_dt_struct" "$fdt_off_dt_struct" "(BE)"
	out "// off_dt_struct:\t0x%x\n" "$fdt_off_dt_struct"

	offset=$(( offset + fdt32_size ))
	fdt_off_dt_strings="$(get_fdt32_be "$img" "$offset")"
	msg "FDT strings offset: 0x%08x (dec.: %u) %s\n" "$fdt_off_dt_strings" "$fdt_off_dt_strings" "(BE)"
	out "// off_dt_strings:\t0x%x\n" "$fdt_off_dt_strings"

	offset=$(( offset + fdt32_size ))
	fdt_off_mem_rsvmap="$(get_fdt32_be "$img" "$offset")"
	msg "FDT memory reserve map offset: 0x%08x (dec.: %u) %s\n" "$fdt_off_mem_rsvmap" "$fdt_off_mem_rsvmap" "(BE)"
	out "// off_mem_rsvmap:\t0x%x\n" "$fdt_off_mem_rsvmap"

	offset=$(( offset + fdt32_size ))
	fdt_version="$(get_fdt32_be "$img" "$offset")"
	msg "FDT version at offset 0x%04x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_version" "$fdt_version" "(BE)"
	out "// version:\t\t%u\n" "$fdt_version"

	offset=$(( offset + fdt32_size ))
	fdt_last_comp_version="$(get_fdt32_be "$img" "$offset")"
	msg "FDT last compatible version at offset 0x%04x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_last_comp_version" "$fdt_last_comp_version" "(BE)"
	out "// last_comp_version:\t%u\n" "$fdt_last_comp_version"

	if [ "$fdt_version" -ge 2 ]; then
		offset=$(( offset + fdt32_size ))
		fdt_boot_cpuid_phys="$(get_fdt32_be "$img" "$offset")"
		msg "FDT physical CPU ID while booting at offset 0x%04x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_boot_cpuid_phys" "$fdt_boot_cpuid_phys" "(BE)"
		out "// boot_cpuid_phys:\t0x%x\n" "$fdt_boot_cpuid_phys"

		if [ "$fdt_version" -ge 2 ]; then
			offset=$(( offset + fdt32_size ))
			fdt_size_dt_strings="$(get_fdt32_be "$img" "$offset")"
			msg "FDT size of strings block: 0x%08x (dec.: %u) %s\n" "$fdt_size_dt_strings" "$fdt_size_dt_strings" "(BE)"
			out "// size_dt_strings:\t0x%x\n" "$fdt_size_dt_strings"

			if [ "$fdt_version" -ge 17 ]; then
				offset=$(( offset + fdt32_size ))
				fdt_size_dt_struct="$(get_fdt32_be "$img" "$offset")"
				msg "FDT size of structure block: 0x%08x (dec.: %u) %s\n" "$fdt_size_dt_struct" "$fdt_size_dt_struct" "(BE)"
				out "// size_dt_struct:\t0x%x\n" "$fdt_size_dt_struct"
			fi
		fi
	fi
	out "\n"

	duration "header data read"

	offset=$(( fdt_start + fdt_off_dt_struct ))
	data=$(get_fdt32_be "$img" "$offset")
	# shellcheck disable=SC2050
	while [ 1 -eq 1 ]; do
		duration "fdt data read"
		case "$data" in
			("$fdt_begin_node")
				name_off="$(( offset + fdt32_size ))"
				eval "$(measure get_string "$img" $name_off "name")"
				[ -z "$name" ] && name="/"
				msg "Begin node at offset 0x%08x, name=%s\n" "$offset" "$name"
				offset=$(fdt32_align $(( offset + fdt32_size + ${#name} + 1 )) )
				out "%s%s {\n" "$(indent)" "$name"
				incr_indent
				;;
			("$fdt_end_node")
				msg "End node at offset 0x%08x\n" "$offset"
				offset=$(( offset + fdt32_size ))
				decr_indent
				out "%s};\n" "$(indent)"
				;;
			("$fdt_prop")
				value_size="$(get_fdt32_be "$img" $(( offset + fdt32_size )))"
				name_off="$(( fdt_start + fdt_off_dt_strings + $(get_fdt32_be "$img" $(( offset + ( 2 * fdt32_size ) )) ) ))"
				eval "$(measure get_string "$img" $name_off "name")"
				msg "Property node at offset 0x%08x, value size=%u, name=%s\n" "$offset" "$value_size" "$name"
				out "%s%s" "$(indent)" "$name"
				data_offset=$(( offset + 3 * fdt32_size ))
				eol=0
				if [ "$value_size" -gt 512 ]; then
					files=$(( files + 1 ))
					# shellcheck disable=SC2059
					file="$(printf -- "$image_file_mask\n" "$files")"
					out " = "
					out "/incbin/(\"%s\"); // size: %u\n" "$file" "$value_size"
					eol=1
					measure get_file "$img" "$data_offset" "$value_size" >"$file"
					msg "Created BLOB file '%s' with %u bytes of data from offset 0x%08x\n" "$file" "$value_size" "$data_offset"
				elif measure is_printable_string "$img" "$data_offset" "$value_size"; then
					eval "$(measure get_string "$img" $(( offset + 3 * fdt32_size )) "str")"
					if [ -n "$str" ]; then
						out " = "
						out "\"%s\"" "$str"
					fi
				elif [ $(( value_size % 4 )) -eq 0 ]; then
					out " = "
					out "<%s>" "$(measure get_hex32 "$img" "$data_offset" "$value_size")"
				else
					out " = "
					out "[%s]" "$(measure get_hex8 "$img" "$data_offset" "$value_size")"
				fi
				[ "$eol" = "0" ] && out ";\n"
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
		data=$(measure get_fdt32_be "$img" "$offset")
	done
	duration "processing finished"
)
#######################################################################################################
#                                                                                                     #
# call the sealed function above                                                                      #
#                                                                                                     #
#######################################################################################################
cwd="$(pwd)"
dissect_fit_image "$@"
rc=$?
# shellcheck disable=SC2164
cd "$cwd"
exit $rc
