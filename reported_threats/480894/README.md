# Security flaw in "AVM FRITZ!OS" 

## Synopsis

An unauthenticated attacker may add a malformed tarball to persisted device settings and use the further processing of this file to create/overwrite files in the working directory, finally executing arbitrary commands and disclose any data of the owner at any later time. It's hard for the owner to remove this attack code from the device, because the tarball is stored in a place, where even factory reset will never wipe it out.

## Affected version

- unspecified/unknown first version, possibly every version which is customizable with a provider additive configuration
- up to currently released final version(s), latest version tested was 141.06.63 (FRITZ!Box Cable 6490), built 2016-10-27
 
## Attack vectors

- an attacker needs access to a wired Ethernet connection, plugged into a FRITZ!Box device, while it's booting
- there no need for a direct connection between attacker and device, as long as they're in the same UDP broadcast domain
- any already installed settings of the owner get lost, if the attacker doesn't take additional precautions to avoid this

## Mitigations

The problem was fixed in FRITZ!OS version 06.80 (or any later version).

~~None - the problem has to be fixed. This was done already in the public beta branch, see timeline below.~~

~~Unknown - I don't have any good idea beside a fix from vendor, because the problem is located in a closed source component of the firmware.~~

## Available fixes / solutions

Update 2016-11-23: 

The issue was fixed in version 113.06.69.41756 (2016-11-01). The "tar x" call was changed, now the files to extract from the tarball are specified with their name(s) and arbitrary content will not be extracted any longer.

End of updated section. The following text is somewhat older.

~~Not fixed yet, at least as far as I know.~~

The vendor did not commit the vulnerability within 6 weeks after he was notified. 

No further statement/message/response from AVM was received regarding this incident (see timeline below) up to 2016-10-07, when the first hint was given to others, where this vulnerability could be found and that it could help to solve a problem.

Possibly it will be investigated now again by the vendor and a fix will be provided in any future version. 

The solution is as easy as thinkable ... extract only a file from a tarball, if you'll need it later and handle _any_ tarball, if a stranger could access it (don't take candy from any strangers), as untrusted source or check its content comprehensively, **before** you extract all files from it. Or use a patched BusyBox. 

## CVE

No CVE ID requested, mitre.org will even not provide IDs for AVM's products any longer.

## Description / Exploitation of the vulnerability

AVM's FRITZ!OS contains an additional function to allow internet access providers a pre-configuration of some settings, if a (smaller) provider isn't present in a predefined list of providers in stock firmware. These setting usually contain DSL connection parameters like VLAN IDs or the URL of an ACS, if the provider wants to use TR-069 CWMP to configure and manage the CPE in a centralized manner.

These settings are provided in more than one single file, so they're packed into a tarball archive and this file is stored in non-volatile memory - in a special filesystem (more a character device) called TFFS, which was (afaik) created by AVM to provide compression and a transactional layer to NOR flash writes - to assure always valid settings, even if write operations are interrupted after a block was erased and before the new data was written. 

This "filesystem" provides access to the managed data streams using character oriented I/O, each minor ID between 1 and 255 from TFFS major device may be used to access a stream of up to 32 KB of compressed data (zlib deflated). Some of those stream are treated specially - all minor IDs below 100 are not cleared while the device executes the different actions necessary to reset the whole device to factory settings.

The provider specific data (let's call it a "provider additive" configuration) will be stored under minor ID 29, so it's not removed during factory resets and to protect the tarball from being wiped out, if the owner uses a recovery program from AVM (which stores a fresh firmware image and resets all present settings), a special value addressed with the key "provider" in the bootloader environment will set to any non-empty value. The recovery program checks this setting, before it writes any new data and it will refuse to handle the device, if it finds a value there (empty values are treated "unset").

So these settings aren't removable operating the device from its GUI or using tools provided by the vendor - usually to protect the provider settings.

The tarball is unpacked while the system is starting and if it contains really a provider additive configuration, the files from this configuration are stored in a folder "provider_additive" below the working directory. But unpacking is done using a simple call to `tar xf <filename>`, where `<filename>` is the name of a character device node pointing to minor ID 29 of the TFFS device. If the tarball contains additionals members, those entries will be extracted too.

Because the used BusyBox version is affected by an older problem (http://seclists.org/oss-sec/2015/q4/121), the tarball may contain symlinks and files in an order, where files are stored outside of the target directories. A symbolic link, pointing from a (relative) path to "/var" is extracted first and any following file using this relative path, will be stored below the "/var" directory and its children (the only writable location in an average FRITZ!OS device).

There're multiple files to be targeted as possible victims of this write access - it starts with "/var/post_install", which will be executed on each shutdown (via "/etc/inittab"), proceeding to "/var/env.cache" (see below) and ends with overwriting the file "/var/tmp/inetd.conf". 

Due to the manner, how "inetd.conf" will be modified later by vendor's firmware, any service already present there, will be available from network if inetd is started later. And it looks like "inetd" is always started in FRITZ!OS, even if no services exist in "/etc/inetd.conf" (a symlink, which points to "/var/tmp/inetd.conf"). Writing a line like

`514 stream tcp6 nowait root /bin/sh sh`

to "inetd.conf", opens a "rexec" shell on demand, after "inetd" was started using our "template" file.

If the attacker needs an opportunity to run own commands immediately on the device (only writing files will not execute any command itself), he may add a line to "inetd.conf", which makes "inetd" listening on a frequently used TCP or UDP port, if no other daemon is using the port (UDP ports may be shared).

Any incoming request there starts - only an example - another shell script (using `/bin/sh sh <scriptname>`) and this script could be contained in the same tarball as our template "inetd.conf". Abusing "inetd" in this manner provides an attacker with a recurring RCE opportunity and these files are recreated after each system restart.

Another file, which may be overwritten, is "/var/env.cache". This file contains the output of an earlier executed command

`set | grep -v "IFS="|grep "^[A-Z]"|sed "s/\(.*\)/export \1/" > /var/env.cache`

and will be "sourced" from multiple scripts called by "udevd", if an event has to be handled. Because the tarball is unpacked before the USB stack was started, any USB device already plugged into the device could trigger the execution of commands stored in "/var/env.cache".

The victim of an attack - the FRITZ!Box owner - is (usually) unable to clean the device from the evil tarball. Nor a firmware update neither a factory reset will remove the tarball content and the recovery program from AVM refuses to write anything (if the "provider" variable is set, which can be done from any malware script too). The only way to get rid of the tarball is writing a new TFFS image without it or unset the "provider" variable and run the recovery program.

An attacker from the LAN side of a FRITZ!Box router may add such a malicious tarball to his self-made TFFS image. All data needed to create an image without custom settings, may be read from the device using only a FTP connection at boot time. The recovery program from vendor does it in the same manner, if it's "refreshing" a device. It reads the environment and counter values from the device, prepares a new TFFS image and writes it to the right partitions using the FTP service from EVA (AVM's bootloader). 

If the attack is executed without knowledge of the current settings, it may be detected by the owner ... if he's irritated, why the device loses its settings and does not take it with a shrug and restores his earlier exported settings.

But if a smarter attacker reads the existing settings first and adds only his own payload and rewrites this image, he'll never gets noticed (ok, on most cases). Such a read access needs additional skills and knowledge, but it's really possible - and the victim will never get a chance to detect the changes - but that's another story and another vulnerability on the LAN side of a FRITZ!Box router.

## Timeline

2016-06-14 14:55 - Vendor notified by (encrypted) e-mail to security@avm.de, there was no proof-of-concept exploit, only a verbal description of the (possible) threat (or an idea, how to construct such a threat), which could make it possible (amongst other attacks to DSL devices) to gain root access to a DOCSIS device.

2016-06-16 16:01 - Vendor replied, that the notification was received and the findings will be checked now.

2016-07-12 15:58 - Vendor replied, that the possible threat is still under investigation and I'll get notified, if any news make
this necessary.

2016-07-15 02:22 - Vendor notified, that the new deadline for this incident was set to 2016-07-26 (two weeks extended from the
first one).

2016-07-27 15:00 - No further contact/message from the vendor, so there's no reason to delay publishing this finding furthermore.

2016-10-08 --:-- - First details mentioned on IPPF (http://www.ip-phone-forum.de/showthread.php?t=286994&p=2184758), after 114 days (> 16 weeks, counted from 2016-06-14) without any real response from vendor

2016-10-18 --:-- - The flaw was a first time used to update a FRITZ!Box Cable 6490 (with OEM branding) with retail firmware - this was an intentional action by the owner of the device and not an attack from a stranger.

2016-11-13 02:06 - Still no message/further response from vendor, last contact regarding this case on 2016-06-16

2016-11-13 02:25 - Description published

2016-11-20 04:30 - Problem was probably already fixed with version 113.06.69-41875, released as public beta version at 2016-11-04 (less than 4 weeks after first details were available on IPPF and in less than five months after my first message to vendor)

2016-11-23 08:43 - A delayed response from vendor arrived today in the morning - the problem was fixed with version 113.06.69-41756, released at 2016-11-01 (three weeks ago). Mitigations to protect the owner and the description of available fixes were updated again (see above).

2017-04-19 16:45 - I've done a final check with version 113.06.83 (on a 7490 device) and found the problem solved. Even if this version isn't available yet for the 6490 model, I will close this case here - the chances are good, that the fix will be contained in the next 6490 version too.
