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
# This script reads a FIT image in AVM's own format and searches for the root filesystem of the       #
# frontend OS by AVM.                                                                                 #
#                                                                                                     #
# It uses the same techniques to find a root filesystem, as were implemented in the 'fitdump.sh'      #
# script from project above.                                                                          #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# the whole logic as a sealed sub-function                                                            #
#                                                                                                     #
#######################################################################################################
find_rootfs_in_fit_image()
(
	sbo() (
		sbo_ro()
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
		( cat; printf -- "%b" "\377" ) | cmp -l -- "$zeros" - 2>"$null" | sbo_ro
	)
	b2d() (
		b2d_ro()
		{
			i=1; v=0; ff=0
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
	get_fdt32_le() ( get_data "$1" 4 "$2" | sbo | b2d; )
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
	__yf_ansi_sgr() { printf -- '\033[%sm' "$1"; }
	__yf_ansi_bold__="$(__yf_ansi_sgr 1)"
	__yf_ansi_yellow__="$(__yf_ansi_sgr 33)"
	__yf_ansi_bright_red__="$(__yf_ansi_sgr 91)"
	__yf_ansi_bright_green__="$(__yf_ansi_sgr 92)"
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
		printf -- "\n%s%s%s, " "${__yf_ansi_bold__}" "$(__yf_get_script_lines 'VER' | sed -n -e "2s|^\([^,]*\),.*|\1|p")" "${__yf_ansi_reset__}"
		v_display="$(__yf_get_script_lines 'VER' | sed -n -e "2s|^[^,]*, \(.*\)|\1|p")"
		printf -- "%s\n" "$v_display"
	}
	__yf_show_copyright() { __yf_get_script_lines 'CPY'; }
	usage() {
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
	}
	entry() (
		img="$1"
		offset="$2"
		parent="$3"
		level="$4"
		filesystem_found=0
		ramdisk_found=0
		data=$(get_fdt32_be "$img" "$offset")
		# shellcheck disable=SC2050
		while [ 1 -eq 1 ]; do
			case "$data" in
				("$fdt_begin_node")
					name_off="$(( offset + fdt32_size ))"
					eval "$(get_string "$img" $name_off "name")"
					[ -z "$name" ] && name="/"
					offset=$(fdt32_align $(( offset + fdt32_size + ${#name} + 1 )) )
					eval "$(entry "$img" "$offset" "$name" "$(( level + 1 ))" 5>&1)"
					offset="$next_offset"
					;;
				("$fdt_end_node")
					offset=$(( offset + fdt32_size ))
					{
						[ -n "$fs_node_name" ] && printf -- "fs_node_name=\"%s\" fs_offset=%u fs_size=%u " "$fs_node_name" "$fs_offset" "$fs_size"
						# shellcheck disable=SC2154
						[ -n "$rd_node_name" ] && printf -- "rd_node_name=\"%s\" rd_offset=%u rd_size=%u " "$rd_node_name" "$rd_offset" "$rd_size"
						printf -- "next_offset=%u" "$offset"
					} 1>&5
					if [ "$filesystem_found" = "1" ] && [ "$type_found" = "$filesystem_type" ] && [ -n "$data_found" ]; then
						printf -- " fs_size=%u fs_offset=%u fs_node_name=\"%s\"" "$fs_size" "$fs_offset" "$parent" 1>&5
					fi
					if [ "$ramdisk_found" = "1" ]; then
						if [ "$fs_size" -eq 0 ] && [ "$rd_size" -lt "$new_rd_size" ]; then
							printf -- " rd_size=%u rd_offset=%u rd_node_name=\"%s\"" "$new_rd_size" "$new_rd_offset" "$parent" 1>&5
						fi
					fi
					exit 0
					;;
				("$fdt_prop")
					value_size="$(get_fdt32_be "$img" $(( offset + fdt32_size )))"
					name_off="$(( fdt_start + fdt_off_dt_strings + $(get_fdt32_be "$img" $(( offset + ( 2 * fdt32_size ) )) ) ))"
					eval "$(get_string "$img" $name_off "name")"
					data_offset=$(( offset + 3 * fdt32_size ))
					if [ "$value_size" -gt 512 ]; then
						[ "$name" = "$data_name" ] && file_size="$value_size" && file_offset="$data_offset"
					elif is_printable_string "$img" "$data_offset" "$value_size"; then
						eval "$(get_string "$img" $(( offset + 3 * fdt32_size )) "str")"
						if [ "$name" = "$filesystem_indicator" ]; then
							# filesystem entries with 'avm,kernel-args = [...]mtdparts_ext=[...]' are for the frontend
							# shellcheck disable=SC2154
							if [ -n "$(expr "$str" : ".*\($filesystem_indicator_marker\).*")" ]; then
								filesystem_found=1
								fs_size="$file_size"
								fs_offset="$file_offset"
								fs_node_name="$parent"
							fi
						elif [ "$name" = "$type_name" ]; then
							type_found="$str"
							if [ "$type_found" = "$ramdisk_type" ]; then
								ramdisk_found=1
								new_rd_size="$file_size"
								new_rd_offset="$file_offset"
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
		{
			[ -n "$fs_node_name" ] && printf -- "fs_node_name=\"%s\" fs_offset=%u fs_size=%u " "$fs_node_name" "$fs_offset" "$fs_size"
			[ -n "$rd_node_name" ] && printf -- "rd_node_name=\"%s\" rd_offset=%u rd_size=%u " "$rd_node_name" "$rd_offset" "$rd_size"
			printf -- "next_offset=%u\n" "$offset"
		} 1>&5
	)
	# shellcheck disable=SC2015
	dev_info() ( [ -z "$2" ] && udevadm info -q all -n "$1" || { udevadm info -q all -n "$1" | sed -n -e "s|^E: $2=\(.*\)|\1|p"; } )
	mtd_type() ( [ "$(dev_info "$1" DEVTYPE)" = "mtd" ] && cat "/sys$(dev_info "$1" DEVPATH)/type" && exit 0 || exit 1; )
	nand_pagesize() ( [ "$(dev_info "$1" DEVTYPE)" = "mtd" ] && [ "$(mtd_type "$1")" = "nand" ] && cat "/sys$(dev_info "$1" DEVPATH)/subpagesize" && exit 0 || exit 1; )
	copy_image() (
		case "$1" in
			("file"|"partition"|"nor")
				dd if="$2" bs="$3" count=1 2>"$null"
				;;
			("nand")
				! command -v nanddump 2>"null" 1>&2 && printf -- "Missing 'nanddump' utility.\a\n" 1>&2 && exit 1
				pagesize="$(nand_pagesize "$2")"
				"$(command -v nanddump 2>"$null")" --bb skipbad "$2" 2>"$null" | dd bs="$pagesize" count="$(( $3 / pagesize + 1 ))" 2>"$null" | dd bs="$3" count=1 2>"$null"
				;;
			(*)
				printf -- "Unable to detect device type of FIT image source (%s) or this type (%s) is unsupported.\a\n" "$2" "$1" 1>&2
				exit 1
				;;
		esac
	)

	null="/dev/null"
	zeros="/dev/zero"
	filesystem_indicator="avm,kernel-args"
	filesystem_indicator_marker="mtdparts_ext="
	data_name="data"
	type_name="type"
	filesystem_type="filesystem"
	ramdisk_type="ramdisk"

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

	fdt_begin_node=1
	fdt_end_node=2
	fdt_prop=3
	fdt_nop=4
	fdt_end=9
	fdt32_size=4

	img="$1"
	[ -z "$img" ] && printf -- "Missing input source parameter.\a\n" 1>&2 && exit 1
	! command -v udevadm 2>"$null" 1>&2 && printf -- "Missing 'udevadm' utility.\a\n" 1>&2 && exit 1
	[ -f "$1" ] && devtype="file" || devtype="$(dev_info "$1" DEVTYPE)"
	[ "$devtype" = "mtd" ] && devtype="$(mtd_type "$1")"

	magic="$(dd if="$img" bs=4 count=1 2>"$null" | b2d)"
	if ! [ "$magic" = "218164734" ]; then
		printf "Invalid magic value (0x%08x) found at offset 0x%02x.\a\n" "$magic" "0" 1>&2
		exit 1
	fi

	next_offset=$(( next_offset + fdt32_size ))
	payload_size="$(get_fdt32_le "$img" "$next_offset")"

	if ! [ -f "$img" ] || [ "$force_tmpcopy" -eq 1 ]; then
		tmpdir="${TMP:-$TMPDIR}"
		[ -z "$tmpdir" ] && tmpdir="/tmp"
		tmpimg="$tmpdir/fit-image-$$"
		copy_image "$devtype" "$img" "$(( payload_size + 64 + 8 + 8 ))" >"$tmpimg" || exit 1
		trap '[ -f "$tmpimg" ] && rm -f "$tmpimg" 2>/dev/null' EXIT
		img="$tmpimg"
	fi

	next_offset=$(( next_offset + fdt32_size + 64 ))
	fdt_magic="$(get_fdt32_be "$img" "$next_offset")"

	if { [ "$fdt_magic" -gt 0 ] && [ "$fdt_magic" -ne 3490578157 ]; } || { [ "$fdt_magic" -lt 0 ] && [ "$fdt_magic" -ne -804389139 ]; }; then
		printf "Invalid FDT magic found.\a\n" 1>&2 && exit 1
	fi

	fdt_start=$next_offset
	next_offset=$(( next_offset + fdt32_size ))

	fdt_totalsize="$(get_fdt32_be "$img" "$next_offset")"
	next_offset=$(( next_offset + fdt32_size ))

	[ "$fdt_totalsize" -ne "$payload_size" ] && printf "Data size mismatch in image file.\a\n" 1>&2 && exit 1

	fdt_off_dt_struct="$(get_fdt32_be "$img" "$next_offset")"
	next_offset=$(( next_offset + fdt32_size ))

	fdt_off_dt_strings="$(get_fdt32_be "$img" "$next_offset")"
	next_offset=$(( next_offset + fdt32_size ))

#	fdt_off_mem_rsvmap="$(get_fdt32_be "$img" "$next_offset")"
	next_offset=$(( next_offset + fdt32_size ))

	fdt_version="$(get_fdt32_be "$img" "$next_offset")"
	next_offset=$(( next_offset + fdt32_size ))

#	fdt_last_comp_version="$(get_fdt32_be "$img" "$next_offset")"
	if [ "$fdt_version" -ge 2 ]; then
		next_offset=$(( next_offset + fdt32_size ))
#		fdt_boot_cpuid_phys="$(get_fdt32_be "$img" "$next_offset")"

		if [ "$fdt_version" -ge 2 ]; then
			next_offset=$(( next_offset + fdt32_size ))
#			fdt_size_dt_strings="$(get_fdt32_be "$img" "$next_offset")"

			if [ "$fdt_version" -ge 17 ]; then
				next_offset=$(( next_offset + fdt32_size ))
#				fdt_size_dt_struct="$(get_fdt32_be "$img" "$next_offset")"
			fi
		fi
	fi

	fs_size=0
	fs_offset=0
	rd_size=0
	fs_offset=0
	fs_node_name=""
	rd_node_name=""

	next_offset=$(( fdt_start + fdt_off_dt_struct ))
	eval "$(entry "$img" "$next_offset" "-" 0 5>&1)"

	if [ "$fs_size" -gt 0 ]; then
		printf "rootfs_type=squashfs rootfs_offset=%u rootfs_size=%u\n" "$fs_offset" "$fs_size"
	elif [ "$rd_size" -gt 0 ]; then
		printf "rootfs_type=ramdísk rootfs_offset=%u rootfs_size=%u\n" "$rd_offset" "$rd_size"
	else
		printf "No rootfs candicates found.\a\n" 1>&2 && exit 1
	fi
)
#######################################################################################################
#                                                                                                     #
# invoke sealed function from above                                                                   #
#                                                                                                     #
#######################################################################################################
find_rootfs_in_fit_image "$@"
#######################################################################################################
#                                                                                                     #
# end of script                                                                                       #
#                                                                                                     #
#######################################################################################################
