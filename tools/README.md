## Files in this folder

`alive_start.sh`

- send a heartbeat signal (simply a HTTP request) to the server set up in the (first) configured DynDNS account
- needs a method to decode the encrypted credentials for the DynDNS account

`juis_check`

- a POSIX compatible shell script to check AVM's update info service for a newer version
- needs a 'nc' binary or the 'nc' applet from BusyBox, which isn't contained in AVM's original firmware anymore (except for the 6490)

`juischeckupdate`

- another script to check for updates
- this one needs a 'bash' shell supporting network access via '/dev/tcp' and no 'nc' implementation is used here

Have a look at this thread regarding checks with this new service:

http://www.ip-phone-forum.de/showthread.php?t=287657&p=2181096#post2181096

`parseJSON`

- parse the output of 'query.lua' into an array of bash variables for further processing

`prowl`

- send a push message using PROWL (https://www.prowlapp.com/) from CLI (bash required)

`rle_decode.c`

- a simple C utility to decode firmware images from AVM's recovery programs, newer versions store them with run-length encoding
