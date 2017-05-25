## FIRST AID - bootable images for FRITZ!Box routers

This folder contains an assortment of ready-to-use images for some FRITZ!Box models, they can be used to perform special tasks, if you've access to a starting FRITZ!Box router.

The following images are present at this time:

- skip_auth.image.*model*

This one will reset the authentication mode of the used FRITZ!Box device to "@SkipAuthFromHomenetwork", where you may access the GUI (from the LAN side of the router) without any authentication needed.

- add_user.image.*model*

This image will add a new user account with the name "YourFritz" and the password "YourFritz" to the used FRITZ!Box router. You can use it, if you lost your administrative access to any other user account - simply log-in next time with this new user. Please keep in mind, that the new user has the "access from everywhere" rights and may be used to log-in to the router from the WAN side too, if external access (over HTTPS) is enabled.

- reset_tainted.image.*model*

This image will reset the 'tainted' flag in node 87 of the TFFS device. As a result, the GUI doesn't show a warning anymore and the support file doesn't contain a hint for 'unsupported changes' any longer.

**Please verify the GPG signature(s) with the key from the base of this repository (Fingerprint: 0DF4F707AC58AA38B35AAA0BC04FCE5230311D96), before you use any of the provided images.**

To boot a FRITZ!Box device from such an image, you may use one of the scripts from the "eva_tools" sub-folder - there are proof-of-concepts for (Unix-) shell-based systems and for PowerShell on Microsoft Windows installations.

## WARNING:

Do not use an image to boot a device model, for which the image was not explicitely built. It's simple to create an own image for the correct model ... please look into the 'toolbox' folder of this repository or read the (german) writing regarding this theme under: http://www.ip-phone-forum.de/showthread.php?t=294386

