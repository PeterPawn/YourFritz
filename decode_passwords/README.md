decode_passwords for FRITZ!OS versions > 06.05

Copyright (C) 2014 P.Haemmerlein (http://www.yourfritz.de)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License under
http://www.gnu.org/licenses/gpl-2.0.html
for more details.

There's a small license deviance, if you want to incorporate the script into your
own software, please read the description below to take note of that.

"FRITZ!Box" and "FRITZ!" are registered word marks and "AVM" is a registered
word and figurative mark of:
AVM Computersysteme Vertriebs GmbH, 10559, Berlin, DE.

A registered entry for "FRITZ!OS" could not be found as of that date (09-05-2014),
but perhaps the legal protection of "FRITZ!" is expanded to the term "FRITZ!OS" too.

=======================================================================================

Purpose:
--------
- decode encrypted credentials from a configuration file
- sustitute the former -c switch for {all,usb,wlan}cfgconv utilities

Usage:
------

  decode_passwords < {input_data}

The script is designed as a filter using standard input and standard output. If you
use it as standard input for a command interpreter via a pipe, you can use file
descriptor 3 to provide the data stream to process instead of stdin.

The input data may be any text. Any data looking like an encrypted item as it is
used by AVMs reversible encryption (that is a string starting with four dollar signs
followed only by the characters A to Z and 1 to 6) will be extracted and the script 
will try as hard as possible to decrypt it.

The simplest input contains only one such secret value, but you may let point stdin
of the script to a whole file like /var/flash/ar7.cfg too.

If it's impossible to decode an encrypted value, it will remain unchanged.

The converted input (substitution between encrypted and decrypted data is done
using the 'sed' command) will be written to stdout.

To prevent unexpected behaviour (waiting for input because of an omitted redirection)
the script will refuse to work, if its standard input is attached to a terminal
device. If it's your intention to use it such way, specify 'tty' as 1st argument.

Exit codes:
-----------
    0 - input data (if any) processed
  121 - unable to create a private temporary directory
  122 - the stdin file points to a terminal device and the 'tty' argument is absent
  123 - the specified WLAN key for mimicry seems to be unusual
  124 - the specified MAC address for mimicry seems to be invalid
  125 - the temporary path looks suspicious
  126 - missing 'webdavcfginfo' binary
  127 - invalid arguments specified, usage help will be shown

Lean and mean version:
----------------------
There's a tradeoff between a well-documented script with embedded comments and the
requirement for some purposes (a.e. the ruKernelTool utility) to write the script
to a device using a telnet shell session, execute it one or more times and forget
it afterwards.

To produce such a lean version, you can call the script with the argument
'leanandmean' as first parameter and it will write a version of itself without error
messages or any comments and line indentations to stdout. The pure content will be
put into a short wrapper script like this:

cat >/var/decode_passwords <<-"LEANANDMEAN"
>> script code is placed here <<
LEANANDMEAN
chmod 550 /var/decode_passwords
[ $(md5sum </var/decode_passwords | sed -n -e 's/^\([0-9a-f]*\).*/\1/p') \
(cont)  == 39f69aa3fb14198462c45fe56f7ed4cc ] || \
(cont)  echo "Hash difference found, transmission failed." 1>&2

You can customize the above "wrapper" script with some more arguments. The target
file name at the device may be specified as second parameter, default value is
'/var/decode_passwords' which will write the script to volatile storage at tmpfs.
If you'd prefer to do without the final hash check, you can specify *any* item as
third argument. If its length is greater than zero, no MD5 check will take place
at the wrapper.

And finally you can specify another word (the fourth argument) with 2any content
and its pure presence will remove some additional code (look below for 'mimicry'
explanations) from the lean script version.

At the time of this writing the lean version (without mimicry) uses 90 lines
with 2046 characters (bytes) at the target system and 4 additional lines (+258
bytes) for the default wrapper.

If you compare these values with the "full blown" version (~520 lines and ~19,600
bytes), there's a significant difference. And as long as nobody will really read
the lean version to understand what it's doing, there's no need to transfer so
much useless data to the box.

For that (and only that) purpose you may use the special lean version without any
copyright notice and without the included license reference(s).
If you want to incorporate the lean version of this script into your own software,
you are obligated to bundle the full version with your software too, without any
additional need for the casual user to send a special request for it.

In this case you may bundle the script with your own software without the need
to publish your own source code too, if it's not required by other licenses.

Mimicry of another box:
-----------------------
If you've got the *internal* presentation of any configuration file from another
box (which is out of reach yet - for example due to a hardware failure as the
result of overvoltage) together with the WLAN key printed on the back of that
device *and* its MAC address (could be found at the "urlader environment" or may
be extracted from another computer, which had network access to the device
earlier - but it is send as "serial number" to AVMs DynDNS service and with
every TR-069 INFORM request too), you can try to decrypt the secret data from
that file, if you specify the two values mentioned above as parameters:

decode_passwords wlan_key mac_address < input_file

Currently this has been tested to be interoperable between the following
FRITZ!Box models:
7270v1, 7270v2, 7270v3, 7390, 7490

It does *not work* with a 6360 router, probably the IV for the AES encryption
will use some additional "device specific" data there.

The 'mimicry' will *not work* with an exported configuration file. There is a
realistic possibility to import such a file, if you can fool the configuration
importer (/usr/www/cgi-bin/firmwarecfg or /usr/bin/tr069fwupdate) with a chroot
environment, but that's another story ...

To check the ability of your device to mimicry another one, I've encoded a known
cleartext (username = "ippf@myfritz.net" and password = "1234567890") with a
'faked' WLAN key (1234567890123456) and even a different MAC address value of
'11:22:33:44:55:66'. You can find the sample as (unreachable) shell code around
line 330.

Prerequisites:
--------------
The whole script needs only a busybox with the following commands supported:
  cat, sed, grep, mount/umount, cp, mkdir, date, echo, chroot, expr,
  test (called as [)

It's a matter of course that the 'webdavcfginfo' binary from the original firmware
has to be reachable (and that includes 'executable') too.

If you create the lean and mean version, there are some more depedencies:
  md5sum, chmod

Just for fun:
The (imho) leanest version - with some additional limitations, but using the same
control flow - *could* be:

b=/bin
l=/lib
f=/var/flash
t=/var/$$
m=mount
r=proc
mkdir -p $t$f $t$l $t$b $t/$r
cd $t
cat $*>i
sed -ne's/.*\(\$\$\$\$[A-Z1-6]*\).*/\1/p'<i>p
cat>s<<'Q'
q=\\\\
while read x;do
echo -e "$1$2 {$5=$x;}">$4
o="$($1$3 -p$5)"
o="${o//$q/$q$q}"
o="${o//|/\\|}"
o="${o//&/\\&}"
o="${o//\"/$q\"}"
echo "s|$x|$o|">>c
done<p
Q
$m -o bind $l .$l
$m -o bind $b .$b
$m -t $r . ./$r
chroot . sh s webdav client cfginfo $f/usb.cfg username
sed -fc<i
cd ..
u$m $t/$r $t$b $t$l
rm -r $t

That version needs only 469 bytes on 30 lines and could do the basic job too. And
another benefit: You can specify one or more names of files to decode as arguments,
for example: 'sh micro_decode /var/flash/*.cfg'.

It's only a proof of concept and not intended for distribution from other sources.
Please respect that license limitation.

=======================================================================================

There is a (german) thread regarding this script at

http://www.ip-phone-forum.de/showthread.php?t=276183

Please use this forum, if you've any questions or hints how I could make the script
better.
