#! /bin/false
# vim: set tabstop=4 syntax=sh :
# SPDX-License-Identifier: GPL-2.0-or-later
#
# - set TMP or TMPDIR, TARGET_DIR (default value is '/'), TARGET_SYSTEM_VERSION and optionally TARGET_BRANDING to correct
#   and useful values prior to calling this script
# - if TARGET_BRANDING is missing, all existing brandings are processed at once - but the detection of all values may fail
#   under some circumstances (where structures below /etc are unusual)
# - if TARGET_SYSTEM_VERSION is set to "autodetect", the value TARGET_SYSTEM_VERSION_DETECTOR has to be set to a script (or
#   any other executable), which has to provide a line starting with "Version=..." and containing the detected version
#
# definitions
#
# shellcheck disable=SC2034
JsFile='usr/www/%s/system/reboot.js'
# shellcheck disable=SC2034
LuaFile='usr/www/%s/system/reboot.lua'
#
# patches
#
get_patches()
(
cat <<endofpatches
# Lua file patch for versions prior to 07.08
sed:1:0:0:7:8:\$LuaFile:./lua_patch_pre0708.sed
# Lua file patch for versions starting with 07.08
sed:1:7:8:999:999:\$LuaFile:./lua_patch_0708.sed
# JS file patch for versions starting with 07.08
sed:1:7:8:999:999:\$JsFile:./js_patch_0708.sed
# copy bootmanager HTML generator for versions up to 07.08
cp:0:0:0:7:8:./bootmanager_html:usr/bin/bootmanager_html:0:0:555
# copy bootmanager messages for versions since 07.08
cp:0:7:8:999:999:./bootmanager.msg:usr/bin/bootmanager.msg:0:0:444
# copy bootmanager script for all versions
cp:0:0:0:999:999:./bootmanager:usr/bin/bootmanager:0:0:555
# copy bootmanager_server script for versions since 07.08
cp:0:7:8:999:999:./bootmanager_server:usr/bin/bootmanager_server:0:0:555
# copy bootmanager.service script for versions since 07.08
cp:0:7:8:999:999:./bootmanager.service:lib/systemd/system/bootmanager.service:0:0:555
endofpatches
)
#
# functions
#
compare_version()
(
	major=$(expr "$1" : "0*\([1-9]*[0-9]\)")
	minor=$(expr "$2" : "0*\([1-9]*[0-9]\)")
	wanted_major=$(expr "$3" : "0*\([1-9]*[0-9]\)")
	wanted_minor=$(expr "$4" : "0*\([1-9]*[0-9]\)")

	[ "$major" -lt "$wanted_major" ] && exit 0
	[ "$major" -gt "$wanted_major" ] && exit 1
	[ "$minor" -lt "$wanted_minor" ] && exit 0
	return 1
)
has_to_be_applied()
(
	if [ "$1" -lt "$5" ] || { [ "$1" -eq "$5" ] && [ "$2" -le "$6" ]; }; then
		if [ "$3" -gt "$5" ] || { [ "$3" -eq "$5" ] && [ "$4" -gt "$6" ]; }; then
			exit 0
		else # maximum version is greater or equal to current version
			exit 1
		fi
	else # minimum version greater than current version
		exit 1
	fi
)
get_all_brandings()
(
	for d in "${1}/etc/default."[!0-9]*/*; do
		[ -d "$d" ] && printf "%s " "${d##*/}"
	done
	printf "\n"
)
get_produkt_value()
(
	for d in "${1}etc/default."[!0-9]*; do
		[ -d "$d" ] && printf "%s\n" "${d##*/}"
	done
)
run_sed_for_file()
(
	sed -f "$2" "$1" > "${1}.patched"
	if ! cmp -s "$1" "${1}.patched" 2>/dev/null; then
		mv "${1}.patched" "$1" 2>/dev/null
		exit 0
	else
		rm -f "${1}.patched" 2>/dev/null
		exit 1
	fi
)
run_cp_for_file()
(
	cp -a "$2" "$1" 2>/dev/null || exit 1
	cmp -s "$2" "$1" 2>/dev/null || exit 1
	if [ -n "$5" ]; then
		chmod "$5" "$1" 2>/dev/null || exit 1
	fi
	if [ -n "$3" ] && [ -n "$4" ]; then
		chown "$3" "$1" 2>/dev/null || exit 1
		chgrp "$4" "$1" 2>/dev/null || exit 1
	fi
	exit 0
)
get_target_file_name()
(
	if [ "$(expr "$1" : '.*\(\$\).*')" = '$' ]; then
		# shellcheck disable=SC2059
		printf "$(eval printf "%s" "$1")" "$2"
	else
		printf "%s\n" "$1"
	fi
)
#
# check temporary and target directory
#
[ -z "$TMP" ] && TMP=$TMPDIR
[ -z "$TMP" ] && printf "\033[31;1mNo TMPDIR or TMP setting found at environment, set it to a writable location.\033[0m\a\n" 1>&2 && exit 1
target_dir="${TARGET_DIR:+$TARGET_DIR/}"
#
# detect target system version, if needed
#
if [ "$TARGET_SYSTEM_VERSION" = "autodetect" ]; then
	if [ -z "$TARGET_SYSTEM_VERSION_DETECTOR" ] && [ -x "./extract_version_values" ]; then
		TARGET_SYSTEM_VERSION_DETECTOR="./extract_version_values"
	else
		[ -z "$TARGET_SYSTEM_VERSION_DETECTOR" ] && printf "\033[31;1mTARGET_SYSTEM_VERSION_DETECTOR value is not set.\033[0m\a\n" 1>&2 && exit 1
	fi
	TARGET_SYSTEM_VERSION="$("$TARGET_SYSTEM_VERSION_DETECTOR" "$target_dir" -m | sed -n -e 's|^Version="\(.*\)"|\1|p')"
	printf "\033[34;1mAutodetection of target system version (from '%s'): %s\033[0m\n" "$target_dir" "$TARGET_SYSTEM_VERSION" 1>&2
fi
[ -z "$TARGET_SYSTEM_VERSION" ] && printf "TARGET_SYSTEM_VERSION value is not set.\a\n" 1>&2 && exit 1
major=$(( $(expr "$TARGET_SYSTEM_VERSION" : "[0-9]*\.0*\([1-9]*[0-9]\)\.[0-9]*") + 0 ))
minor=$(( $(expr "$TARGET_SYSTEM_VERSION" : "[0-9]*\.[0-9]*\.0*\([1-9]*[0-9]\)") + 0 ))
[ "$major" -eq 0 ] && [ "$minor" -eq 0 ] && printf "\033[31;1mTARGET_SYSTEM_VERSION value is invalid.\033[0m\a\n" 1>&2 && exit 1
target_produkt="$(get_produkt_value "$target_dir")"
#
# process patch files for target version
#
i=0
problems="$(get_patches | while read -r line; do
	i=$(( i + 1 ))
	[ "$(expr "$line" : "\(.\).*")" = "#" ] && continue
	oifs="$IFS"
	IFS=":"
	# shellcheck disable=SC2086
	set -- $line
	IFS="$oifs"
	per_branding="$2"
	from_major="$3"
	from_minor="$4"
	to_major="$5"
	to_minor="$6"
	if ! has_to_be_applied "$from_major" "$from_minor" "$to_major" "$to_minor" "$major" "$minor"; then
		printf "\033[33;1mAction from line %u of patch definitions skipped due to version settings: not below %02u.%02u, but below %02u.%02u ('%s' for '%s').\033[0m\n" "$i" "$from_major" "$from_minor" "$to_major" "$to_minor" "$1" "$7" 1>&2
		continue
	fi
	case "$1" in
		('sed')
			command_file="$8"
			if [ "$per_branding" = "1" ]; then
				target_file_mask="$7"
				if [ -z "$TARGET_BRANDING" ]; then
					for branding in $(get_all_brandings "$target_dir"); do
						target_file="$(get_target_file_name "$target_file_mask" "$branding")"
						if run_sed_for_file "$target_dir$target_file" "$command_file"; then
							printf "\033[32;1mAction ('%s' with commands from file '%s') from line %u of patch definitions applied to '%s'.\033[0m\n" "$1" "$command_file" "$i" "$target_dir$target_file" 1>&2
						else
							printf "\033[31;1mAction ('%s' with commands from file '%s') from line %u of patch definitions failed on '%s'.\033[0m\a\n" "$1" "$command_file" "$i" "$target_dir$target_file" 1>&2
							printf "problem on line %u\n" "$i"
						fi
					done
				else
					target_file="$(get_target_file_name "$target_file_mask" "$TARGET_BRANDING")"
					if run_sed_for_file "$target_dir$target_file" "$command_file"; then
						printf "\033[32;1mAction ('%s' with commands from file '%s') from line %u of patch definitions applied to '%s'.\033[0m\n" "$1" "$command_file" "$i" "$target_dir$target_file" 1>&2
					else
						printf "\033[32;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions succeeded.\033[0m\n" "$1" "$command_file" "$i" "$target_dir$target_file" 1>&2
						printf "problem on line %u\n" "$i"
					fi
				fi
			else
				target_file="$7"
				if run_sed_for_file "$target_dir$target_file" "$command_file"; then
					printf "\033[32;1mAction ('%s' with commands from file '%s') from line %u of patch definitions applied to '%s'.\033[0m\n" "$1" "$command_file" "$i" "$target_dir$target_file" 1>&2
				else
					printf "\033[32;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions succeeded.\033[0m\n" "$1" "$command_file" "$i" "$target_dir$target_file" 1>&2
					printf "problem on line %u\n" "$i"
				fi
			fi
			;;
		('cp')
			source_file="$7"
			if [ "$per_branding" = "1" ]; then
				target_file_mask="$8"
				if [ -z "$TARGET_BRANDING" ]; then
					for branding in $(get_all_brandings "$target_dir"); do
						target_file="$(get_target_file_name "$target_file_mask" "$branding")"
						if run_cp_for_file "$target_dir$target_file" "$source_file" "$9" "${10}" "${11}"; then
							printf "\033[32;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions succeeded.\033[0m\n" "$1" "$source_file" "$target_dir$target_file" "$i" 1>&2
						else
							printf "\033[31;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions failed.\033[0m\a\n" "$1" "$source_file" "$target_dir$target_file" "$i" 1>&2
							printf "problem on line %u\n" "$i"
						fi
					done
				else
					target_file="$(get_target_file_name "$target_file_mask" "$TARGET_BRANDING")"
					if run_cp_for_file "$target_dir$target_file" "$source_file" "$9" "${10}" "${11}"; then
						printf "\033[32;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions succeeded.\033[0m\n" "$1" "$source_file" "$target_dir$target_file" "$i" 1>&2
					else
						printf "\033[31;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions failed.\033[0m\a\n" "$1" "$source_file" "$target_dir$target_file" "$i" 1>&2
						printf "problem on line %u\n" "$i"
					fi
				fi
			else
				target_file="$8"
				if run_cp_for_file "$target_dir$target_file" "$source_file" "$9" "${10}" "${11}"; then
					printf "\033[32;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions succeeded.\033[0m\n" "$1" "$source_file" "$target_dir$target_file" "$i" 1>&2
				else
					printf "\033[31;1mAction ('%s' of file '%s' as '%s') from line %u of patch definitions failed.\033[0m\a\n" "$1" "$source_file" "$target_dir$target_file" "$i" 1>&2
					printf "problem on line %u\n" "$i"
				fi
			fi
			;;
		(*)
			printf "\033[37;1mUnknown operation '%s' on line %u of patch definitions.\033[0m\a\n" "$1" "$i" 1>&2
			printf "problem on line %u\n" "$i"
			;;
	esac
done | wc -l)"
[ "$problems" -gt 0 ] && rc=1 || rc=0
#
# all done here
#
exit "$rc"
