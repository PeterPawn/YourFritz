# Files in this folder

## (this is something like a "grocery store" of scripts for different purposes)

`alive_start.sh` (__target__: FRITZ!OS device)

- send a heartbeat signal (simply a HTTP request) to the server set up in the (first) configured DynDNS account
- needs a method to decode the encrypted credentials for the DynDNS account, you can use <https://github.com/PeterPawn/decoder> for this purpose

`juis_check` (__target__: any Linux system or ```bash``` on Windows 10)

- a POSIX compatible shell script to check AVM's update info service for a newer version
- needs a 'nc' binary or the 'nc' applet from BusyBox, which isn't contained in AVM's original firmware anymore (except for the 6490)

`juischeckupdate` (__target__: any Linux system, but not the Windows 10 ```bash```)

- another script to check for updates
- this one needs a 'bash' shell supporting network access via '/dev/tcp' and no 'nc' implementation is used here

Have a look at this thread regarding checks with this new service:

<http://www.ip-phone-forum.de/showthread.php?t=287657&p=2181096#post2181096>

`resetsigned` (__target__: FRITZ!OS device)

- reset the ```tainted``` flag on a FRITZ!OS device, if it is set … may be called periodically and will only lead to an additional TFFS write access, if it's necessary

`unique_id` (__target__: FRITZ!OS device)

- get a random character string with a specified length (only 0-9 and a-f are contained there) or get a really (globally) unique ID, if ```guid``` is specified as first parameter and kernel's random device provides the needed ```procfs``` entry (```/proc/sys/kernel/random/uuid```)

`waitconnected` (__target__: FRITZ!OS device)

- wait a specified time until the WAN connection of a FRITZ!Box device was established
- if the timeout value is omitted, it checks the state only once and may be used as a detector for an established connection

`waittimeset` (__target__: FRITZ!OS device)

- wait a specified time (or indefinite) until the FRITZ!OS device has gotten a valid date and time
- may be used to delay the start of services, which need a valid date and time (e.g. 'cron' or a service with a (real) certificate check)

`parseJSON` (__target__: any ```bash``` installation, where JSON data was read from a FRITZ!OS device)

- parse the output of 'query.lua' into an array of bash variables for further processing

`prowl` (__target__: any ```bash``` installation)

- send a push message using PROWL (<https://www.prowlapp.com/>) from CLI (bash required)

`rle_decode.c` (__target__: usually cross-build system(s) for FRITZ!OS devices)

- a simple C utility to decode firmware images from AVM's recovery programs, newer versions store them with run-length encoding
