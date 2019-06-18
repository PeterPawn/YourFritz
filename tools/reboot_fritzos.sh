#! /bin/bash 
# SPDX-License-Identifier: GPL-2.0-or-later
#####################################################################################
#                                                                                   #
# create the HTTP request                                                           #
#                                                                                   #
#####################################################################################
post_request()
{
	printf "POST /cgi-bin/firmwarecfg HTTP/1.1\r\n"
	printf "User-Agent: handcrafted_request/1 (shell)\r\n"
	printf "Accept: */*\r\n"
	printf "Host: %s\r\n" "$2"
	printf "Connection: Close\r\n"
	printf "%s" "$1"
}
#####################################################################################
#                                                                                   #
# parameters and defaults                                                           #
#                                                                                   #
#####################################################################################
# IP address of FRITZ!Box
host="${2:-192.168.178.1}"
#####################################################################################
#                                                                                   #
# SID has to be the first parameter                                                 #
#                                                                                   #
#####################################################################################
[ -z "$1" ] && echo "Missing SID ..." && exit 1
. $YF_SCRIPT_DIR/multipart_form
td=$(multipart_form new)
multipart_form addfield $td sid $1
multipart_form addfield $td reboot
request="$(multipart_form postdata $td)"
printf "=== request ===\n" 1>&2
printf "%s\n" "$(post_request "$request" "$host")" 1>&2
printf "=== response ===\n" 1>&2
post_request "$request" "$host" | nc -q 1 -C -w 2 $host 80
printf "\n=== end of communication ===\n" 1>&2
multipart_form cleanup "$td"
