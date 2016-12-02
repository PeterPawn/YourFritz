# Next vulnerability - usable to inject arbitrary commands - was found

## Synopsis

An insufficiently tested configuration parameter may be used to run arbitrary commands on newer FRITZ!OS versions. 

An attack can only be started from someone with local administrative access or - without any authentication needed - from a device, which has a wired connection to the router (using EVA FTP server) while it's booting.

## Affected versions

- unspecified/unknown first version
- probably every version is affected, which may be configured to send the export file with saved settings with a push-mail, before an update is executed
- latest tested versions: 141.06.63 (6490), 113.06.69-42111 (7490)

## Attack vectors

- any local administrative account (with at least "box_admin_rights = secobj_access_rights_readwrite_from_homenetwork_only") may set the malformed parameter
- an unauthenticated attacker still may modify the stored settings in the TFFS partition, if he gots a wired connection to the booting router (further explained below)
- there's no need for a *direct* connection between the unauthenticated attacker and the router, as long as they're in the same UDP broadcast domain while the FRITZ!Box is starting

## Mitigations

- Do a regular manual check of the affected setting in the graphical user interface.
- Do not connect your FRITZ!Box to any other device, which is possibly already infected (or otherwise may be used as a relay for an attack) - at least disconnect it each time, if the router is restarting. A WLAN connection cannot be used for an attack to the bootloader (WLAN isn't supported in this early startup state), as long as no AP is connected by wire.

## Available fixes

- As far as I know, there's no fix available at the time of this writing.
- If an update for this vulnerability becomes available, this description could(!) be updated (or still may be left unchanged - it's only my discretion), to reflect any changes by the vendor.

## CVE

No CVE ID requested, mitre.org will even not provide IDs for AVM's products any longer.

## Description / Exploitation if the vulnerability

In newer versions AVM has invented one more opportunity to send unattended e-mails (they're using the good genuine-german term "Push Services" for this - but I've no idea, who's the "pusher" and if he really could have an interrelation to drug trafficking here) and one condition triggering such a message is an upcoming firmware update (automatically and unattended or manually from a online source or a provided file).

A "push mail" (let's use this term from now on, like the vendor does) in this place contains an attachment with the saved settings prior to this update and some - more or less important - settings in this "export" file are encrypted.
The password needed to encrypt the file is stored in the settings itself and the user has to set it up, before he may enable sending of this special push mail.

Using this password, an internal command
 
 `/usr/bin/tr069fwupdate configexport "%s" > %s`
 
will be executed, where the first substituted string represents the entered password ... and that's the root of this issue.

Using a malformed password like `my_password$(command_to_execute)`, the embedded command gets executed and the resulting call of `tr069fwupdate` isn't really changed - if the command doesn't write anything to STDOUT (or this is redirected to /dev/null), only `my_password` will be used to encrypt the settings.

An input in the GUI seems to be un-checked in this place, at least I was able to enter a malformed password into the regular user interface and it gets stored in "ar7.cfg". There are many other opportunities to change this value, but the GUI is the only place, where a normal user may verify it. All other occurrences of this setting are encrypted and their real content cannot be viewed.

An unauthorized attacker may read the TFFS content (using an own firmware image to start the router from memory), change the (encrypted) value in the file "ar7.cfg" to the new (unencrypted) value and store the result ... simply using the TFFS driver or even while writing a whole new TFFS image with the malicious content.

If I haven't missed important changes, this vulnerability was added not so long ago ... as long as the password was displayed again for a manual file-based update or it had to be entered there (and wasn't already stored), a changed value could get noticed very early.

But the internal call to `tr069fwupdate` is present much longer (if I search in my archive of original firmware versions) - maybe the input was checked more restrictive in earlier versions. The (hidden) attack is now possible due to additional changes, where the user defines the password one time and in one place (where he usually never looks in again) and therefore a change cannot get noticed.

The vector for an attacker without access to a valid admin account is the same as for any of the other modifications of the stored settings. As long as the bootloader (more accurate the embedded FTP server) may be accessed using an Ethernet cable at boot time without any additional precautions, any compromised device in the same LAN segment may be used to change settings or even the firmware of a FRITZ!Box router.

Because the router usually has an active connection to the internet while the commands are executed (sending the e-mail has to be finished, before "dsld" can be stopped), it's even possible to download malicious code from a "command&control" server.  Any other commands have to wait until the embedded code has finished execution (tr069fwupdate will only continue, after the embedded code exits in any way), so this vulnerability could even be used to change the whole update process and to install a modified version. And because the user expects a new version anyway, he will never realize, that he was hacked during the latest update.

## Timeline

2016-11-25 10:45 - First version published - vendor will be notified by e-mail, pointing to this description.

2016-11-25 15:00 - Vendor assigned incident number #796851 to the report, folder name changed to this number.

2016-12-02 16:41 - I've received another mail from vendor ... the leak has been closed in 113.06.69-42372, which was published today and built yesterday (16:50).
