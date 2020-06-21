#! /bin/true
__yf_custom_environment()
{
	for ___yf_ce_cmd in sed mknod expr wc grep cat rm true; do command -v $___yf_ce_cmd >/dev/null 2>&1 || return 1; done

	___yf_ce_temp=/tmp
	___yf_ce_proc=/proc
	___yf_ce_devices=/devices
	___yf_ce_urlader=/sys/urlader
	___yf_ce_environment=/environment
	___yf_ce_target="${YF_CUSTOM_ENVIRONMENT_TARGET:-$___yf_ce_proc$___yf_ce_urlader$___yf_ce_environment}"
	___yf_ce_source="$___yf_ce_temp/custom_env.tffs"
	___yf_ce_tffs_minor="${YF_CUSTOM_ENVIRONMENT_TFFS_MINOR:-80}"

	for ___yf_ce_dir in "$___yf_ce_proc" "$___yf_ce_temp"; do [ -d "$___yf_ce_dir" ] || return 1; done
	for ___yf_ce_file in "$___yf_ce_target" "$___yf_ce_proc$___yf_ce_devices"; do [ -f "$___yf_ce_file" ] || return 1; done

	[ -n "$(expr "$___yf_ce_tffs_minor" : ".*\([^0-9]\).*")" ] && return 1
	[ "$___yf_ce_tffs_minor" -gt 255 ] && return 1
	[ "$___yf_ce_tffs_minor" -lt 30 ] && return 1

	___yf_ce_tffs_major="$(sed -n -e "s|^[ ]*\([0-9 ]*\)[ \t]\+tffs\$|\1|p" "$___yf_ce_proc$___yf_ce_devices")"
	[ -z "$___yf_ce_tffs_major" ] && return 1
	mknod "$___yf_ce_source" c $___yf_ce_tffs_major $___yf_ce_tffs_minor 2>/dev/null || return 1
	[ "$( ( wc -c "$___yf_ce_source" 2>/dev/null || printf "0") | sed -n -e "s|^\([0-9]*\).*\$|\1|p")" -lt 2 ] && ( rm "$___yf_ce_source" 2>/dev/null || true ) && return 1
		
	cat "$___yf_ce_source" |\
	while read ___yf_ce_name ___yf_ce_value; do
		___yf_ce_current="$(sed -n -e "s|^$___yf_ce_name[ \t]*\(.*\)\$|\1|p" "$___yf_ce_target")"
		if [ "${#___yf_ce_current}" -ne "${#___yf_ce_value}" ] || ! [ "$___yf_ce_current" = "$___yf_ce_value" ]; then
			printf "%s %s\n" "$___yf_ce_name" "$___yf_ce_value" > "$___yf_ce_target" 2>/dev/null
		fi
	done

	rm "$___yf_ce_source" 2>/dev/null
}

__yf_custom_environment
for var in $(set | sed -n -e "s|^\(___yf_ce_[^=]*\)=.*\$|\1|p") __yf_custom_environment; do unset $var; done
