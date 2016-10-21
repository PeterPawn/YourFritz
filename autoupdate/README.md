## Proof of concept

Add an option for automatic updates during system reboot to '/var/post_install' - this script is called, while a FRITZ!OS based
device is preparing to restart.

This version may be controlled by the presence or absence of named files on the internal NAS storage. It may be used to detect
and download a newer firmware version from vendor and to modify this firmware prior to its installation. The "branding" (a special
value in the bootloader environment) may be auto-adjusted to a value supported in the new firmware, if necessary.

There's a writing (in German) in an IPPF thread regarding the files in this subfolder:

http://www.ip-phone-forum.de/showthread.php?t=286994&p=2186357
