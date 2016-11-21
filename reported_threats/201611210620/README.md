## One more weak spot in AVM's FRITZ!OS

Again a security flaw was found, which may be used to inject arbitrary commands into the running OS.

An attacker needs only a valid administrator account or the predefined GUI password from bootloader environment, if the password wasn't changed by the owner during first-time installation or after a factory-reset.

With knowledge of needed credentials, the attack may be run from any host on the LAN side ... if the attacker wants to check/use the "webgui_pass" value, he needs a wired connection while the FRITZ!Box device is restarting.

The flaw was found while analyzing 141.06.63 for "FRITZ!Box Cable 6490", but other models are affected too.

The vendor was not notified yet. If the threat is still present in the next final release, it will be reported to the vendor.
