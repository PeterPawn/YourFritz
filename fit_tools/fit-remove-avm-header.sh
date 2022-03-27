#! /bin/sh
# vim: set tabstop=4 syntax=sh :
# SPDX-License-Identifier: GPL-2.0-or-later
#######################################################################################################
#                                                                                                     #
# remove AVM's header data from a FIT image with 'AVM flavour'                                        #
#                                                                                                     #
###################################################################################################VER#
#                                                                                                     #
# fit-remove-avm-header, version 0.2                                                                  #
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
# This script takes a FIT image in AVM's own format as first (and only) parameter and writes its data #
# without AVM's header (magic value, payload size and (possibly) signature data) to STDOUT. Data size #
# will be taken from file content (payload size), so input source may be a complete partition, too.   #
#                                                                                                     #
# Use this script to get a 'pure FDT structure', which can processed with other tools from 'dtc'      #
# project (like 'fdtget' or 'fdtput').                                                                #
#                                                                                                     #
#######################################################################################################
#                                                                                                     #
# the whole logic as a sealed sub-function                                                            #
#                                                                                                     #
#######################################################################################################
remove_avm_header()
(
	action_message=""
	printf_ss() {
		mask="$1"
		shift
		# shellcheck disable=SC2059
		printf -- "$mask" "$@"
	}
	result() {
		[ "$dbg" = "1" ] || return 0
		if [ "$1" = "0" ]; then
			color="$__yf_ansi_bright_green__"
		elif [ "$1" = "1" ]; then
			color="$__yf_ansi_bright_red__"
		else
			color="$__yf_ansi_yellow__"
		fi
		shift
		printf -- "%s" "$color" 1>&2
		debug "$@"
		printf -- "%s\n" "$__yf_ansi_reset__" 1>&2
	}
	debug() {
		[ "$dbg" = "1" ] || return 0
		printf_ss "$@" 1>&2
	}
	action() {
		[ "$dbg" = "1" ] || return 0
		action_message="$(printf_ss "$@")"
		debug "$@"
	}
	indent() { i=1; while [ "$i" -lt "${1:-1}" ]; do printf -- ">>"; i=$(( i + 1 )); done; printf -- " "; }
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
	get_fdt32_le() ( get_data "$1" 4 "$2" | sbo | b2d; )
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
		printf -- "%sfit-remove-avm-header.sh%s - remove AVM's header from a FIT image file\n\n" "${__yf_ansi_bold__}" "${__yf_ansi_reset__}"
		printf -- "Usage: %s [ options ] <fit-image>\n\n" "$0"
		printf -- "Options:\n\n"
		printf -- "-d or --debug - show some extra info on STDERR\n"
		printf -- "\n"
		exec 1>&2
	}
	#
	# time-optimized copying of data with offset and known size
	#
	# $1 = input file
	# $2 = start offset
	# $3 = data length to copy
	# $4 = block size to use (best a tradeoff between time and memory used), default is 1 MB
	#
	copy_optimized() (
		lvl=$(( ${5:-0} + 1 ))
		def_bsz=$(( 1024 * 1024 ))
		bsz=$(( ${4:-$def_bsz} ))
		[ $(( bsz & ( bsz - 1 ) )) -gt 0 ] && bsz=$def_bsz
		cnt=$(( $3 ))
		[ $cnt -le 0 ] && return 0
		off=$(( $2 ))
		[ $off -lt 0 ] && return 1
		if [ $cnt -lt $bsz ]; then
			if [ $(( off % bsz )) -ne 0 ]; then
				if [ $bsz -gt 1024 ]; then
					copy_optimized "$1" $off $(( cnt & 1023 )) 1024 $lvl
					cnt=$(( cnt - ( 1024 - off ) ))
					off=1024
					copy_optimized "$1" 1024 $cnt 1024 $lvl
					return 0
				fi
				of=$(( off ))
				s=1
				while [ $(( of & 1 )) -eq 0 ]; do s=$(( s * 2 )); of=$(( of / 2 )); done
				skp=$(( off / s ))
				cnt=$(( cnt / s ))
				r=0
			else
				s=1
				c=$(( cnt & ~1023 ))
				while [ $(( c % 2 )) -eq 0 ] && [ $c -gt 0 ]; do s=$(( s * 2 )); c=$(( c / 2 )); done
				skp=$(( off / s ))
				[ $s -eq 1 ] && r=0 || r=$(( cnt & 1023 ))
				cnt=$(( cnt / s ))
				rb=1024
			fi
			action "%sCopying %u (%#x) data blocks of size %u (%#X) starting at offset %u (%#x) ..." "$(indent "$lvl")" "$cnt" "$cnt" "$s" "$s" "$off" "$off"
			if dd if="$1" bs="$s" skip="$skp" count="$cnt" 2>"$null"; then
				result "0" " OK"
				if [ $r -ne 0 ]; then
					copy_optimized "$1" $(( ( skp + cnt ) * s )) $r $rb $lvl
				fi
			else
				result "1" " failed"
			fi
		else
			if [ $(( off % bsz )) -ne 0 ]; then
				copy_optimized "$1" $off $(( bsz - ( off % bsz ) )) $bsz $lvl
				copy_optimized "$1" $bsz $(( ( cnt - ( bsz - ( off % bsz ) ) ) )) $bsz $lvl
			else
				s=$(( off / bsz ))
				c=$(( cnt / bsz ))
				action "%sCopying %u (%#x) data blocks of size %u (%#X) starting at offset %u (%#x) ..." "$(indent "$lvl")" "$c" "$c" "$bsz" "$bsz" "$off" "$off"
				if dd if="$1" bs="$off" skip="$s" count="$c" 2>"$null"; then
					result "0" " OK"
					if [ $cnt -gt $(( c * bsz )) ]; then
						copy_optimized "$1" $(( ( c + 1 ) * bsz )) $(( cnt - c * bsz )) $bsz $lvl
					fi
				else
					result "1" " failed"
				fi
			fi
		fi
	)

	null="/dev/null"
	zeros="/dev/zero"

	fdt32_size=4

	dbg=0
	while [ "$(expr "$1" : "\(.\).*")" = "-" ]; do
		[ "$1" = "--" ] && shift && break

		if [ "$1" = "-d" ] || [ "$1" = "--debug" ]; then
			dbg=1
			shift
		elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
			usage
			exit 0
		else
			printf -- "Unknown option: %s\a\n" "$1" 1>&2 && exit 1
		fi
	done

	img="$1"
	if [ "$dbg" = "1" ]; then
		__yf_show_version 1>&2
		__yf_show_copyright 1>&2
		debug "\n"
	fi
	debug "Input file: %s%s%s\n" "$__yf_ansi_bright_green__" "$img" "$__yf_ansi_reset__"
	debug "Looking for magic value at offset 0x00 ..."
	if ! [ "$(dd if="$img" bs=4 count=1 2>"$null" | b2d)" = "218164734" ]; then
		debug "$(result 1 " failed")"
		printf -- "Missing magic value (0x0d 0x00 0xed 0xfe) from specified input file '%s'.\a\n" "$img" 1>&2
		exit 1
	else
		debug "$(result 0 " OK")"
	fi

	offset=$(( fdt32_size ))
	payload_size="$(get_fdt32_le "$img" "$offset")"
	debug "FDT payload size at offset 0x04: %s%u%s (%#x)\n" "$__yf_ansi_bright_green__" "$payload_size" "$__yf_ansi_reset__" "$payload_size"

	offset=$(( offset + fdt32_size ))
	size=64
	if [ "$dbg" = "1" ] && command -v hexdump 2>"$null" 1>&2; then
		debug "\nData at offset 0x%02x, size %u:\n\n%s" "$offset" "$size" "$__yf_ansi_yellow__"
		get_data "$img" "$size" "$offset" | hexdump -C | sed -n -e "1,$(( size / 16 ))p" 1>&2
		debug "%s\n" "$__yf_ansi_reset__"
	fi
	offset=$(( offset + size ))

	[ -t 1 ] && printf -- "STDOUT is a terminal device, output suppressed.\a\n" 1>&2 && exit 1

	action "Copying %u (%#x) bytes of data starting from offset %u (%#x) ..." "$payload_size" "$payload_size" "$offset" "$offset"
	[ "$dbg" = "1" ] && result 2 " running"
	if copy_optimized "$img" "$offset" "$payload_size"; then
		[ "$dbg" = "1" ] && debug "$action_message"
		result 0 " OK"
		debug "\n"
		exit 0
	else
		[ "$dbg" = "1" ] && debug "$action_message"
		result 1 " failed"
		debug "\n"
		exit 1
	fi
)
#######################################################################################################
#                                                                                                     #
# invoke sealed function from above                                                                   #
#                                                                                                     #
#######################################################################################################
remove_avm_header "$@"
#######################################################################################################
#                                                                                                     #
# end of script                                                                                       #
#                                                                                                     #
#######################################################################################################
