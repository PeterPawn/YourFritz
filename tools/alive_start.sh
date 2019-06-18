#! /bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
interval=300
scriptname=/var/alive.sh
logname=alive
cfgvar()
{
	local n="$1" i p="$2" v
	v="$(echo -e "$n" | ar7cfgctl -w 2>/dev/null)"
	i=$(expr index "$v" '\$\$\$\$')
	if [ $i -gt 0 ]; then
		v="$(echo "$v" | decoder decode_secrets)"
	fi
	if ! test -z "$p"; then
		p="${p//\[/\\[}"
		p="${p//\"/\\"}"
		p="${p//\./\\.}"
		p="${p//\$/\\\$}"
		v="$(echo "$v" | sed -n -e "s|$p||p")"
	fi
	echo "$v" | sed -n -e 's|^\([^ ]*\) = \(\".*\"\)|\1=\2|p'
}
eval $(cfgvar "ddns.accounts.ddnsprovider" "ddns.accounts.")
if [ "$ddnsprovider" == "<userdefined>" ]; then
	server="$(cfgvar "ddns.types[userdefined].url" | sed -n -e 's|ddns\.types\[userdefined\]\.url="\([^/]*\).*|\1|p')"
else
	eval $(cfgvar "ddns.provider[$ddnsprovider].server" "ddns.provider[$ddnsprovider].")
fi
eval $(cfgvar "ddns.accounts.username\nddns.accounts.passwd" "ddns.accounts.")
if [ ${#username} -gt 0 -a ${#passwd} -gt 0 -a ${#server} -gt 0 ]; then
	url="http://$username:$passwd@$server/alive"
	cat >$scriptname <<-EOS
	#! /bin/sh
	res="\$(wget -qO - $url)"
	rc=\$?
	RAND=\$(echo "\$(date +%s)" | md5sum | sed -n -e "s/\([0-9a-f]\{6\}\).*/\1/p")
	delay -d $interval LV\$RAND $scriptname
	echo "result was : \$res, return code was : \$rc, next id is : LV\$RAND" | showshringbuf -i $logname
EOS
	chmod 500 $scriptname
	delay -d 60 ALIVESTRT $scriptname
else
	delay -d 3600 ALIVEGEN $0
fi
