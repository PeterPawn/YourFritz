#! /bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
TargetDir="${TARGET_DIR:+$TARGET_DIR/}"
[ -z "$TMP" ] && TMP=$TMPDIR
[ -z "$TMP" ] && printf "No TMPDIR or TMP setting found at environment, set it to a writable location.\a\n" 1>&2 && exit 1

AddFile_Name="${TargetDir}etc/init.d/yf_change_oem.sh"
AddFile_Content()
{
	cat << 'EOT'
#! /bin/true
command -v __yf_cmdline
__yf_unset_cmdline=$?
if [ $__yf_unset_cmdline -ne 0 ]; then
__yf_cmdline()
(
	___kvset="$(grep -ao "[ ]\?$1=[^ ]*" /proc/cmdline | sed -n -e 1p)"
	[ ${#___kvset} -eq 0 ] && return 1
	___value="$(expr "$___kvset" : "[ ]*$1=\(.*\)")"
	printf "%s\n" "$___value"
)
fi
__yf_cmdline "[Oo][Ee][Mm]" >/dev/null 2>&1 && for ___brand in $(for ___d in /etc/default.$CONFIG_PRODUKT/*; do printf "%s " "${___d#/etc/default*/}"; done); do [ "$___brand" = "$(__yf_cmdline "[Oo][Ee][Mm]")" ] && OEM=$___brand && break; done
[ $__yf_unset_cmdline -ne 0 ] && unset __yf_cmdline
unset __yf_unset_cmdline
unset ___brand
EOT
}

AddToFile_Name="${TargetDir}etc/init.d/rc.conf"
AddToFile_Marker="# YF_CHANGE_OEM"
AddToFile_Control()
{
	cat << EOT
/^[ \t]*export OEM\$/i\\
$AddToFile_Marker\\
[ -f /etc/init.d/yf_change_oem.sh ] && . /etc/init.d/yf_change_oem.sh
EOT
}

if ! grep -q "^$AddToFile_Marker\$" "$AddToFile_Name" 2>/dev/null; then
	AddToFile_Control > "$TMP/add_change_oem.sed"
	sed -f "$TMP/add_change_oem.sed" "$AddToFile_Name" > "$AddToFile_Name.new" && mv "$AddToFile_Name.new" "$AddToFile_Name"
	rm "$TMP/add_change_oem.sed" 2>/dev/null
	AddFile_Content > "$AddFile_Name"
fi
