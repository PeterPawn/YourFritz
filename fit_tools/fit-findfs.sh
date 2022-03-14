#! /bin/sh
# vim: set tabstop=4 syntax=sh :
# SPDX-License-Identifier: GPL-2.0-or-later
#######################################################################################################
#                                                                                                     #
# search the 'filesystem' entry with the largest data size in a FIT image                             #
#                                                                                                     #
###################################################################################################VER#
#                                                                                                     #
# fit-findfs.sh, version 0.2                                                                          #
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
# This script reads a FIT image in AVM's own format and searches the biggest BLOB of data with type   #
# of 'filesystem'. The assumption is, that this data will be the filesystem used for the FRITZ!OS     #
# main system, providing AVM's user frontend.                                                         #
#                                                                                                     #
# If a filesystem was found, its offset in the FIT file and its data size will be written to STDOUT,  #
# readily prepared to be set as variables using an 'eval' statement.                                  #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# the whole logic as a sealed sub-function                                                            #
#                                                                                                     #
#######################################################################################################
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
		printf -- "%sfit-findfs.sh%s - locate a filesystem BLOB in a FIT image\n\n" "${__yf_ansi_bold__}" "${__yf_ansi_reset__}"
		printf -- "Usage: %s [ options ] <fit-image>\n\n" "$0"
		printf -- "Options:\n\n"
		printf -- "-f or --force-copy - always create and use a copy on temporary storage,\n"
		printf -- "                     even if input is a regular file\n"
		printf -- "\n"
		exec 1>&2
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

	force_tmpcopy=0
	while [ "$(expr "$1" : "\(.\).*")" = "-" ]; do
		[ "$1" = "--" ] && shift && break

		if [ "$1" = "-f" ] || [ "$1" = "--force-copy" ]; then
			force_tmpcopy=1
			shift
		elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
			usage
			exit 0
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
		dd if="$img" of="$tmpimg" bs=$(( 1024 * 1024 )) count=$(( ( payload_size + 64 + 8 ) / ( 1024 * 1024 ) + 1 )) 2>$null || exit 1
		trap '[ -f "$tmpimg" ] && rm -f "$tmpimg" 2>/dev/null' EXIT
		img="$tmpimg"
	fi

	offset=$(( offset + fdt32_size + 64 ))
	fdt_magic="$(get_fdt32_be "$img" "$offset")"

	[ "$fdt_magic" -ne 3490578157 ] && printf "Invalid FDT magic found.\a\n" 1>&2 && exit 1

	fdt_start=$offset
	offset=$(( offset + fdt32_size ))

#	fdt_totalsize="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

	fdt_off_dt_struct="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

	fdt_off_dt_strings="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

#	fdt_off_mem_rsvmap="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

	fdt_version="$(get_fdt32_be "$img" "$offset")"
	offset=$(( offset + fdt32_size ))

#	fdt_last_comp_version="$(get_fdt32_be "$img" "$offset")"

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
#######################################################################################################
#                                                                                                     #
# invoke sealed function from above                                                                   #
#                                                                                                     #
#######################################################################################################
find_filesystem_in_fit_image "$@"
#######################################################################################################
#                                                                                                     #
# end of script                                                                                       #
#                                                                                                     #
#######################################################################################################
