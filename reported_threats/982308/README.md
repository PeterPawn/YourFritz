## One more weak spot in AVM's FRITZ!OS

Again a security flaw was found, which may be used to inject arbitrary commands into the running OS.

An attacker needs only a valid administrator account or the predefined GUI password from bootloader environment, if the password wasn't changed by the owner during first-time installation or after a factory-reset.

With knowledge of needed credentials, the attack may be run from any host on the LAN side ... if the attacker wants to check/use the "webgui_pass" value, he needs a wired connection while the FRITZ!Box device is restarting.

The flaw was found while analyzing 141.06.63 for "FRITZ!Box Cable 6490", but other models are affected too.

The vendor was not notified yet. If the threat is still present in the next final release, it will be reported to the vendor.

Timeline

2017-02-10 03:49 - Vendor notified by e-mail, the flaw wasn't fixed in the newly released version 113.06.80

2017-02-17 16:00 - First reply from vendor: an incident number (#982308) was assigned, the problem was forwarded to the internal development unit and the finding was confirmed. 
                   No comment on whether or when it will be fixed. The 90 days period from my "responsible disclosure" policy was started on 2017-02-10.
                   The name of the subfolder was adjusted to reflect the assigned incident number.

2017-03-17 03:00 - The vendor has published a new version (06.83), which should fix this vulnerability - together with other changes.
                   Although there was no further test (by myself) to check this statement, I decided to publish a script (in
                   PowerShell, but it could be easily adapted to any other language or platform) to show this vulnerability ...
                   look for the file in the directory, where this README.md resides.
                   A comprehensive description regarding this (fixed) vulnerability will be given later.
