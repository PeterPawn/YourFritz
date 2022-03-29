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
	sbo() ( # swap byte order
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
	b2d() ( # binary to decimal - input has to be in BE order
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
	get_fdt32_le() ( get_data "$1" 4 "$2" | sbo | b2d; )
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
	indent() { printf -- "%s" "$(expr "$indent_template" : "\( \{$(( $1 * 4 ))\}\).*")"; }
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
			if [ "$v" -lt 0 ]; then
				printf -- "0x"
				printf -- "%02x" $(( ( v >> 24 ) & 0xFF ))
				printf -- "%06x" $(( v & 0xFFFFFF ))
			else
				printf -- "0x%08x" "$v"
			fi
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
		printf -- "%sfitdump.sh%s - dissect a FIT image into .its and blob files\n\n" "${__yf_ansi_bold__}" "${__yf_ansi_reset__}"

		printf -- "Usage: %s [ options ] <fit-image>\n\n" "$0"
		printf -- "Options:\n\n"
		printf -- "-d or --debug      - show extra information (on STDERR) while reading FDT structure\n"
		printf -- "-i or --no-its     - do not create an .its file as output\n"
		printf -- "-n or --native     - input file is expected to use the format defined by 'U-boot' project\n"
		printf -- "-f or --filesystem - create a filesystem structure from FIT image properties\n"
		printf -- "-c or --copy       - copy source file to a temporary location prior to processing\n"
		printf -- "-m or --measure    - measure execution time using /proc/timer-list and write log data to\n"
		printf -- "                     a file named 'fitdump.measure' in the output directory\n"
		printf -- "\n"
	}
	nsecs() { [ -f "$timer" ] && sed -n -e "s|^now at \([0-9]*\).*|\1|p" "$timer" || printf -- "0\n"; }
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
		[ "$measr" -eq 1 ] && [ "$start" -gt 0 ] && printf -- "measured time %s for: %s\n" "$(format_duration "$end" "$start")" "$*" 1>&3
		return $r
	}
	duration() {
		now=$(nsecs)
		[ "$measr" -eq 1 ] && [ "$now" -gt 0 ] && printf -- "overall duration: %s: %s\n" "$(format_duration "$now" "$script_start")" "$*" 1>&3
	}
	cd_msg() {
		cwd="$(pwd)"
		cwd="${cwd#"$dump_dir"/}"
		if [ -z "$1" ]; then
			msg "Change directory to: %s/..\n" "$cwd"
			cd "$(pwd)/.." || return
		else
			msg "Change directory to: %s/%s\n" "$cwd" "$1"
			cd "$(pwd)/$name" || return
		fi
	}
	entry() (
		img="$1"
		offset="$2"
		parent="$3"
		level="$4"
		filesystem_found=0
		ramdisk_found=0
		kernel_found=0
		cfg_found=0
		type_found=""
		data_found=""
		data=$(get_fdt32_be "$img" "$offset")
		# shellcheck disable=SC2050
		while [ 1 -eq 1 ]; do
			duration "fdt data read"
			case "$data" in
				("$fdt_begin_node")
					name_off="$(( offset + fdt32_size ))"
					eval "$(measure get_string "$img" $name_off "name")"
					[ -z "$name" ] && name="/"
					msg "Begin node at offset 0x%08x, name=%s, level=%u\n" "$offset" "$name" "$level"
					offset=$(fdt32_align $(( offset + fdt32_size + ${#name} + 1 )) )
					out "%s%s {\n" "$(indent "$level")" "$name" 1>&4
					[ "$dirs" = "1" ] && printf -- "%s\n" "$name" >>"$properties_order_list" && mkdir "$name" 2>"$null" && cd_msg "$name"
					if [ "$name" = "$configurations_name" ]; then
						msg "%sConfigurations node starts here%s\n" "$__yf_ansi_yellow__" "$__yf_ansi_reset__"
						[ -n "$fs_node_name" ] && msg "%sLook for kernel image used with:%s %s\n" "$__yf_ansi_yellow__" "$__yf_ansi_reset__" "$fs_node_name"
						[ -n "$rd_node_name" ] && msg "%sLook for kernel image used with:%s %s\n" "$__yf_ansi_yellow__" "$__yf_ansi_reset__" "$rd_node_name"
						cfg=1
					elif [ "$cfg" = "1" ]; then
						cfg_name="$name"
						krnl_node=""
						msg "%sNew configuration:%s %s\n" "$__yf_ansi_yellow__" "$__yf_ansi_reset__" "$cfg_name"
					fi
					eval "$(entry "$img" "$offset" "$name" "$(( level + 1 ))" 5>&1)"
					[ "$dirs" = "1" ] && cd_msg
					;;
				("$fdt_end_node")
					msg "End node at offset 0x%08x\n" "$offset"
					offset=$(( offset + fdt32_size ))
					out "%s};\n" "$(indent "$(( level - 1 ))")" 1>&4
					{
						[ -n "$fs_node_name" ] && printf -- "fs_node_name=\"%s\" fs_image=\"%s\" fs_size=%u " "$fs_node_name" "$fs_image" "$fs_size"
						[ -n "$rd_node_name" ] && printf -- "rd_node_name=\"%s\" rd_image=\"%s\" rd_size=%u " "$rd_node_name" "$rd_image" "$rd_size"
						[ -n "$kernel_image" ] && printf -- "kernel_image=\"%s\" " "$kernel_image"
						printf -- "offset=%u files=%u" "$offset" "$files"
					} 1>&5
					if [ "$filesystem_found" = "1" ] && [ "$type_found" = "$filesystem_type" ] && [ -n "$data_found" ]; then
						msg "%sFilesystem image:%s %s - size=%u\n" "$__yf_ansi_bright_green__" "$__yf_ansi_reset__" "$data_found" "$data_size"
						printf -- " fs_size=%u fs_image=\"%s\" fs_node_name=\"%s\"" "$data_size" "$data_found" "$parent" 1>&5
					fi
					if [ "$ramdisk_found" = "1" ]; then
						msg "%sRamdisk image:%s %s - size=%u, prev_size=%u\n" "$__yf_ansi_yellow__" "$__yf_ansi_reset__" "$data_found" "$data_size" "$rd_size"
						if [ "$fs_size" -eq 0 ] && [ "$rd_size" -lt "$data_size" ]; then
							msg "%sNew ramdisk image selected:%s %s\n" "$__yf_ansi_bright_green__" "$__yf_ansi_reset__" "$data_found"
							printf -- " rd_size=%u rd_image=\"%s\" rd_node_name=\"%s\"" "$data_size" "$data_found" "$parent" 1>&5
						fi
					fi
					if [ -n "$data_found" ]; then
						[ "$kernel_found" = "1" ] && msg "%sKernel image:%s %s\n" "$__yf_ansi_yellow__" "$__yf_ansi_reset__" "$data_found"
						printf -- "%03u=%s\n" "$files" "$parent" >>"$image_file_list"
					fi
					if [ "$cfg_found" -eq 1 ]; then
						msg "%sConfiguration using '%s' found:%s %s\n" "$__yf_ansi_bright_green__" "$fs_node_name" "$__yf_ansi_reset__" "$parent"
						msg "%sKernel entry name:%s %s\n" "$__yf_ansi_bright_green__" "$__yf_ansi_reset__" "$krnl_node"
						kernel_image_number="$(sed -n -e "s|^\([0-9]\{3\}\)=$krnl_node\$|\1|p" "$image_file_list")"
						kernel_image="$(printf_ss "$image_file_mask" "$kernel_image_number")"
						printf -- " kernel_image=\"%s\" " "$kernel_image" 1>&5
					fi
					exit 0
					;;
				("$fdt_prop")
					value_size="$(get_fdt32_be "$img" $(( offset + fdt32_size )))"
					name_off="$(( fdt_start + fdt_off_dt_strings + $(get_fdt32_be "$img" $(( offset + ( 2 * fdt32_size ) )) ) ))"
					eval "$(measure get_string "$img" $name_off "name")"
					msg "Property node at offset 0x%08x, value size=%u, name=%s\n" "$offset" "$value_size" "$name"
					out "%s%s" "$(indent "$level")" "$name" 1>&4
					data_offset=$(( offset + 3 * fdt32_size ))
					[ "$dirs" = "1" ] && printf -- "%s\n" "$name" >>"$properties_order_list"
					eol=0
					if [ "$value_size" -gt 512 ]; then
						files=$(( files + 1 ))
						file="$(printf_ss "$image_file_mask\n" "$files")"
						out " = " 1>&4
						out "/incbin/(\"%s\"); // size: %u, offset=0x%08x\n" "$file" "$value_size" "$data_offset" 1>&4
						eol=1
						#measure get_file "$img" "$data_offset" "$value_size" >"$dump_dir/$file"
						#msg "Created BLOB file '%s' with %u bytes of data from offset 0x%08x\n" "$file" "$value_size" "$data_offset"
						[ "$dirs" = "1" ] && cp "$dump_dir/$file" "$name" 2>"$null"
						[ "$name" = "$data_name" ] && data_found="$file" && data_size="$value_size"
					elif measure is_printable_string "$img" "$data_offset" "$value_size"; then
						eval "$(measure get_string "$img" $(( offset + 3 * fdt32_size )) "str")"
						if [ -n "$str" ]; then
							out " = " 1>&4
							out "\"%s\"" "$str" 1>&4
						fi
						if [ "$dirs" = "1" ]; then
							get_data "$img" "$value_size" "$data_offset" >"$name"
						fi
						if [ "$cfg" -eq 1 ] && [ "$cfg_found" -eq 0 ]; then
							if [ "$name" = "$kernel_cfg_name" ]; then
								krnl_node="$str"
							elif [ -n "$fs_node_name" ] && [ "$name" = "$fs_cfg_name" ] && [ "$fs_node_name" = "$str" ]; then
								cfg_found=1
							elif [ -n "$rd_node_name" ] && [ "$name" = "$rd_cfg_name" ] && [ "$rd_node_name" = "$str" ]; then
								cfg_found=1
							fi
						else
							if [ "$name" = "$filesystem_indicator" ]; then
								# filesystem entries with 'avm,kernel-args = [...]mtdparts_ext=[...]' are for the frontend
								if [ -n "$(expr "$str" : ".*\($filesystem_indicator_marker\).*")" ]; then
									filesystem_found=1
									fs_size="$data_size"
								fi
							elif [ "$name" = "$type_name" ]; then
								type_found="$str"
								if [ "$type_found" = "$ramdisk_type" ]; then
									ramdisk_found=1
								elif [ "$type_found" = "$kernel_type" ]; then
									kernel_found=1
								fi
							fi
						fi
					elif [ $(( value_size % 4 )) -eq 0 ]; then
						out " = " 1>&4
						out "<%s>" "$(measure get_hex32 "$img" "$data_offset" "$value_size")" 1>&4
						if [ "$level" -eq 1 ] && [ "$name" = "$timestamp_name" ]; then
							out "; // %s\n" "$(date -u -d @"$(get_fdt32_be "$img" "$data_offset" 4)")" 1>&4
							eol=1
						fi
						if [ "$dirs" = "1" ]; then
							get_data "$img" "$value_size" "$data_offset" >"$name"
						fi
					else
						out " = " 1>&4
						out "[%s]" "$(measure get_hex8 "$img" "$data_offset" "$value_size")" 1>&4
						if [ "$dirs" = "1" ]; then
							get_data "$img" "$value_size" "$data_offset" >"$name"
						fi
					fi
					[ "$eol" = "0" ] && out ";\n" 1>&4
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
		{
			[ -n "$fs_node_name" ] && printf -- "fs_node_name=\"%s\" fs_image=\"%s\" fs_size=%u " "$fs_node_name" "$fs_image" "$fs_size"
			[ -n "$rd_node_name" ] && printf -- "rd_node_name=\"%s\" rd_image=\"%s\" rd_size=%u " "$rd_node_name" "$rd_image" "$rd_size"
			[ -n "$kernel_image" ] && printf -- "kernel_image=\"%s\" " "$kernel_image"
			printf -- "offset=%u files=%u\n" "$offset" "$files"
		} 1>&5
	)
	get_real_name() (
		if command -v realpath 2>"$null" 1>&2; then
			realpath "$1" 2>"$null"
		elif command -v readlink 2>"$null" 1>&2; then
			readlink -f "$1" 2>"$null"
		else
			p="$1"
			l="$(ls -dl "$p")"
			t="${l#*" $p -> "}"
			d="$(pwd)"
			# shellcheck disable=SC2164
			cd "${p%/*}" 2>"$null"
			# shellcheck disable=SC2164
			cd -P "${t%/*}" 2>"$null"
			r="$(pwd)/${t##*/}"
			# shellcheck disable=SC2164
			cd "$d" 2>"$null"
			printf -- "%s\n" "$r"
		fi
	)
	# shellcheck disable=SC2015
	dev_info() ( [ -z "$2" ] && udevadm info -q all -n "$1" || { udevadm info -q all -n "$1" | sed -n -e "s|^E: $2=\(.*\)|\1|p"; } )
	mtd_type() ( [ "$(dev_info "$1" DEVTYPE)" = "mtd" ] && cat "/sys$(dev_info "$1" DEVPATH)/type" && exit 0 || exit 1; )
	nand_pagesize() ( [ "$(dev_info "$1" DEVTYPE)" = "mtd" ] && [ "$(mtd_type "$1")" = "nand" ] && cat "/sys$(dev_info "$1" DEVPATH)/subpagesize" && exit 0 || exit 1; )
	copy_image() (
		! command -v udevadm 2>"$null" 1>&2 && printf -- "Missing 'udevadm' utility.\a\n" 1>&2 && exit 1
		[ -f "$1" ] && type="file" || type="$(dev_info "$1" DEVTYPE)"
		[ "$type" = "mtd" ] && type="$(mtd_type "$1")"
		msg "Input data source type: %s%s%s\n" "$__yf_ansi_bright_green__" "$type" "$__yf_ansi_reset__"
		case "$type" in
			("file"|"partition"|"nor")
				dd if="$1" of="$2" bs="$3" count=1 2>"$null"
				;;
			("nand")
				! command -v nanddump 2>"null" 1>&2 && printf -- "Missing 'nanddump' utility.\a\n" 1>&2 && exit 1
				pagesize="$(nand_pagesize "$1")"
				"$(command -v nanddump 2>"$null")" --bb skipbad "$1" 2>"$null" | dd of="$2" bs="$pagesize" count="$(( $3 / pagesize + 1 ))" 2>"$null" && dd if="$null" of="$2" bs="$3" seek=1 2>"$null"
				;;
			(*)
				printf -- "Unable to detect device type of FIT image source (%s) or this type (%s) is unsupported.\a\n" "$1" "$([ -z "$type" ] && printf -- "(unknown)" || printf "%s\n" "$type")" 1>&2
				exit 1
				;;
		esac
	)

	null="/dev/null"
	zeros="/dev/zero"
	timer="/proc/timer-list"
	dump_dir="./fit-dump"
	image_dir_name="image"
	its_name="image.its"
	its_file="$dump_dir/$its_name"
	image_file_mask="image_%03u.bin"
	image_file_list=".image_number_to_node_name"
	properties_order_list=".order"
	files=0
	native=0
	tmpcopy=0
	measr=0
	dirs=0
	indent_template="$(dd if=$zeros bs=256 count=1 2>"$null" | tr '\000' ' ')"

	filesystem_indicator="avm,kernel-args"
	filesystem_indicator_marker="mtdparts_ext="
	data_name="data"
	configurations_name="configurations"
	kernel_cfg_name="kernel"
	fs_cfg_name="squashFS"
	rd_cfg_name="ramdisk"
	timestamp_name="timestamp"
	type_name="type"
	filesystem_type="filesystem"
	ramdisk_type="ramdisk"
	kernel_type="kernel"
	fs_image_name="filesystem.image"
	rd_image_name="ramdisk.image"
	kernel_image_name="kernel.image"

	debug=0
	while [ "$(expr "$1" : "\(.\).*")" = "-" ]; do
		[ "$1" = "--" ] && shift && break

		if [ "$1" = "-d" ] || [ "$1" = "--debug" ]; then
			debug=1
			shift
		elif [ "$1" = "-n" ] || [ "$1" = "--native" ]; then
			native=1
			shift
		elif [ "$1" = "-c" ] || [ "$1" = "--copy" ]; then
			tmpcopy=1
			shift
		elif [ "$1" = "-f" ] || [ "$1" = "--filesystem" ]; then
			dirs=1
			shift
		elif [ "$1" = "-i" ] || [ "$1" = "--no-its" ]; then
			its_file="$null"
			shift
		elif [ "$1" = "-m" ] || [ "$1" = "--measure" ]; then
			[ "$(nsecs)" = "0" ] && printf -- "Missing '%s', time measurements aren't available.\a\n" "$timer" 1>&2 || measr=1
			shift
		elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
			usage
			exit 0
		else
			printf -- "Unknown option: %s\a\n" "$1" 1>&2 && exit 1
		fi
	done

	[ "$tmpcopy" = 1 ] && [ "$native" = 1 ] && printf "Input data with native format and copying file to temporary storage can't be used together.\a\n" 1>&2 && exit 1

	fdt_begin_node=1
	fdt_end_node=2
	fdt_prop=3
	fdt_nop=4
	fdt_end=9
	fdt32_size=4

	script_start=$(nsecs)

	if [ -d "$dump_dir" ]; then
		printf -- "Subdirectory '%s' does exist already. Remove it, before calling this script.\a\n" "$dump_dir" 1>&2
		exit 1
	fi
	! mkdir "$dump_dir" && printf -- "Error creating subdirectory '%s', do you have write access?\a\n" "$dump_dir" 1>&2 && exit 1

	[ -z "$1" ] && printf -- "Missing input source parameter.\a\n" 1>&2 && exit 1
	img="$(get_real_name "$1")"
	dump_dir="$(get_real_name "$dump_dir")"
	cd "$dump_dir" || exit 1

	its_file="$dump_dir/$its_name"
	[ -f "$its_file" ] && rm -f "$its_file" 2>"$null"
	if [ "$debug" -eq 1 ] && [ -t 2 ]; then
		exec 1>"$null"
	fi

	[ "$measr" -eq 1 ] && exec 3<>"$dump_dir/fitdump.measure"

	duration "measure log initialized"

	msg "File: %s%s%s\n" "$__yf_ansi_bright_green__" "$img" "$__yf_ansi_reset__"

	offset=0
	if ! [ "$native" = "1" ]; then
		magic="$(measure dd if="$img" bs=4 count=1 2>"$null" | b2d)"
		if ! [ "$magic" = "218164734" ]; then
			printf "Invalid magic value (0x%08x) found at offset 0x%02x.\a\n" "$magic" "0" 1>&2
			exit 1
		fi
		msg "Magic value at offset 0x%02x: 0x%08x %s\n" "$offset" "$(dd if="$img" bs=4 count=1 2>"$null" | sbo | b2d)" "LE"

		offset=$(( offset + fdt32_size ))
		payload_size="$(get_fdt32_le "$img" "$offset")"
		msg "Overall length of data at offset 0x%02x: 0x%08x - dec.: %u %s\n" "$offset" "$payload_size" "$payload_size" "LE"

		duration "signature and data size read"

		if ! [ -f "$img" ] || [ "$tmpcopy" = "1" ]; then
			tmpdir="${TMP:-$TMPDIR}"
			[ -z "$tmpdir" ] && tmpdir="/tmp"
			tmpimg="$tmpdir/fit-image-$$"
			copy_image "$img" "$tmpimg" "$(( payload_size + 64 + 8 + 8 ))" || exit 1
			trap '[ -f "$tmpimg" ] && rm -f "$tmpimg" 2>/dev/null' EXIT
			img="$tmpimg"
			duration "image copied to tmpfs"
		fi

		offset=$(( offset + fdt32_size ))
		size=64
		msg "Data at offset 0x%02x, size %u:\n" "$offset" "$size"
		[ "$debug" -eq 1 ] && measure get_data "$img" "$size" "$offset" | hexdump -C | sed -n -e "1,$(( size / 16 ))p" 1>&2
		offset=$(( offset + size ))
		fdt_magic="$(get_hex32 "$img" "$offset" 4)"
	else
		# get_data at offset 0 isn't supported due to computations and divide by zero errors
		fdt_magic="$(get_hex32 "$img" 0 4)"
		payload_size=0
	fi

	msg "FDT magic at offset 0x%02x: %s %s\n" "$offset" "$fdt_magic" "(BE)"
	! [ "$fdt_magic" = "0xd00dfeed" ] && msg "Invalid FDT magic found.\a\n" && exit 1
	fdt_start=$offset
	out "/dts-v1/;\n"
	out "// magic:\t\t%s\n" "$fdt_magic"

	offset=$(( offset + fdt32_size ))
	fdt_totalsize="$(get_fdt32_be "$img" "$offset")"
	msg "FDT total size at offset 0x%02x: 0x%08x (dec.: %u) %s\n" "$offset" "$fdt_totalsize" "$fdt_totalsize" "(BE)"
	out "// totalsize:\t\t0x%x (%u)\n" "$fdt_totalsize" "$fdt_totalsize"

	if ! [ "$native" = "1" ] && [ "$fdt_totalsize" -ne "$payload_size" ]; then
		printf "Payload size (%u = %#x) at offset 0x%02x doesn't match FDT data size at offset 0x%02x (%u = %#x), processing aborted.\a\n" "$payload_size" "$payload_size" "4" "$offset" "$fdt_totalsize" "$fdt_totalsize" 1>&2
		exit 1
	fi

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

	fs_image=""
	rd_image=""
	kernel_image=""
	fs_size=0
	rd_size=0
	fs_node_name=""
	rd_node_name=""

	: >"$image_file_list"
	image_file_list="$(get_real_name "$image_file_list")"
	cfg=0

	exec 4>&1
	offset=$(( fdt_start + fdt_off_dt_struct ))
	# shellcheck disable=SC2164
	[ "$dirs" = "1" ] && mkdir -p "$dump_dir/$image_dir_name" 2>"$null" && cd "$dump_dir/$image_dir_name"
	eval "$(entry "$img" "$offset" "-" 0 5>&1)"

	# restore CWD to '$dump_dir'
	[ "$dirs" = "1" ] && cd_msg

	if [ "$debug" = "1" ]; then
		msg "Image number to node name translations:\n"
		sed -n -e "s|=| -> |p" "$image_file_list" 1>&2
	fi
	[ -f "$image_file_list" ] && rm "$image_file_list" 2>"$null"

	if [ -n "$fs_image" ]; then
		ln -s "$fs_image" "$fs_image_name" 2>"$null" && msg "%sLinked '%s' to '%s'%s\n" "$__yf_ansi_bright_green__" "$fs_image_name" "$fs_image" "$__yf_ansi_reset__"
	elif [ -n "$rd_image" ]; then
		ln -s "$rd_image" "$rd_image_name" 2>"$null" && msg "%sLinked '%s' to '%s'%s\n" "$__yf_ansi_bright_green__" "$rd_image_name" "$rd_image" "$__yf_ansi_reset__"
	fi
	if [ -n "$kernel_image" ]; then
		ln -s "$kernel_image" "$kernel_image_name" 2>"$null" && msg "%sLinked '%s' to '%s'%s\n" "$__yf_ansi_bright_green__" "$kernel_image_name" "$kernel_image" "$__yf_ansi_reset__"
	fi

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
