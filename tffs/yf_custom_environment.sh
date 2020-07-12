#! /bin/true
__yf_custom_environment()
{
	___yf_ce_busybox="${YF_CUSTOM_BUSYBOX:-/bin/busybox}"
	[ -x "$___yf_ce_busybox" ] || return 1

	for ___yf_ce_cmd in mount sed mknod expr wc grep cat rm mkdir true; do $___yf_ce_busybox --list | $___yf_ce_grep grep -q "^$___yf_ce_cmd\$" || return 1; done

	___yf_ce_dev=/dev
	___yf_ce_proc=/proc
	___yf_ce_devices=/devices
	___yf_ce_mounts=/mounts
	___yf_ce_urlader=/sys/urlader
	___yf_ce_environment=/environment
	___yf_ce_target="${YF_CUSTOM_ENVIRONMENT_TARGET:-$___yf_ce_proc$___yf_ce_urlader$___yf_ce_environment}"
	___yf_ce_source="$___yf_ce_dev/custom_env.tffs"
	___yf_ce_tffs_minor="${YF_CUSTOM_ENVIRONMENT_TFFS_MINOR:-80}"

	for ___yf_ce_dir in "$___yf_ce_proc"; do [ -d "$___yf_ce_dir" ] || $___yf_ce_busybox mkdir -p "$___yf_ce_dir"; done

	[ -f "$___yf_ce_proc$___yf_ce_mounts" ] || $___yf_ce_busybox mount -t proc procfs "$___yf_ce_proc"
	[ -f "$___yf_ce_proc$___yf_ce_mounts" ] || return 1

	for ___yf_ce_file in "$___yf_ce_target" "$___yf_ce_proc$___yf_ce_devices"; do [ -f "$___yf_ce_file" ] || return 1; done

	[ -n "$($___yf_ce_busybox expr "$___yf_ce_tffs_minor" : ".*\([^0-9]\).*")" ] && return 1
	[ "$___yf_ce_tffs_minor" -gt 255 ] && return 1
	[ "$___yf_ce_tffs_minor" -lt 30 ] && return 1

	___yf_ce_tffs_major="$($___yf_ce_busybox sed -n -e "s|^[ ]*\([0-9 ]*\)[ \t]\+tffs\$|\1|p" "$___yf_ce_proc$___yf_ce_devices")"
	[ -z "$___yf_ce_tffs_major" ] && return 1
	$___yf_ce_busybox mknod "$___yf_ce_source" c $___yf_ce_tffs_major $___yf_ce_tffs_minor || return 1
	[ "$( ( $___yf_ce_busybox wc -c "$___yf_ce_source" || printf "0") | $___yf_ce_busybox sed -n -e "s|^\([0-9]*\).*\$|\1|p")" -lt 2 ] && ( $___yf_ce_busybox rm "$___yf_ce_source" || true ) && return 1
		
	$___yf_ce_busybox cat "$___yf_ce_source" |\
	while read ___yf_ce_name ___yf_ce_value; do
		___yf_ce_current="$($___yf_ce_busybox sed -n -e "s|^$___yf_ce_name[ \t]*\(.*\)\$|\1|p" "$___yf_ce_target")"
		[ "${#___yf_ce_current}" -ne "${#___yf_ce_value}" ] || ! [ "$___yf_ce_current" = "$___yf_ce_value" ] && printf "%s %s\n" "$___yf_ce_name" "$___yf_ce_value" > "$___yf_ce_target"
	done

	$___yf_ce_busybox rm "$___yf_ce_source"
}

__yf_custom_environment
for ___yf_v in $(set | ${YF_CUSTOM_BUSYBOX:-/bin/busybox} sed -n -e "s|^\(___yf_ce_[^=]*\)=.*\$|\1|p") __yf_custom_environment; do unset $___yf_v; done
unset ___yf_v
