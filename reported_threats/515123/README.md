# Directory traversal attack with firmware images

## Description

On FRITZ!OS based devices, most files from external sources are intended to be TAR archives with a signature from vendor. The manner of this signing algorithm was (re)implemented for the public here:

<https://github.com/PeterPawn/YourFritz/tree/main/signimage>

and it was discussed en detail (in german language) in a thread on IPPF:

<http://www.ip-phone-forum.de/showthread.php?t=286213>

To handle such files from external sources, a pipeline built of three components will be used internally: the 1st stage copies the file from the source (via HTTP or FTP or from a file), the 2nd stage sanitizes malformed member headers and recomputes a hash value for the whole image file and the 3rd stage extracts the files from the - usually sanitized - archive. This all happens at the very same time ... any malformed header (for a member), which passes the "sanitizer stage" unchanged, leads to a write operation on a (possibly) wrong or at least unwanted place in the filesystem.

While inspecting TAR member headers, the 'prefix' field from the POSIX header format (155 bytes, starting at offset 345) was ignored and an attacker could use a value in this field to construct a complete path, which points to an unwanted place.

The "sanitizing process" (firmwarecfg stream) changes each member header, which has unexpected/unwanted content (this means other types than regular files or directories and each name not starting with a "var" (or "./var") component), to the path "var/tmp/ignored_tar_content" ... as a result, the parallel execution of the unpack operation is usually harmless - as long as each malformed header is changed.

Even for accepted members, the name is changed to include an additional sub-directory in the final path ... the real name ```var/post_install``` will be updated to ```var/unpack/post_install``` and this additional directory ```unpack```will be removed in front of the extraction, if it already exists (as a subdirectory of ```/var```).

Using a "prefix" component of

```/var/media/ftp/<usb_device>/```

in a member header, a symbolic link on the USB storage volume (needs a native filesystem there)

```ln -s /var /var/media/ftp/<usb_device>/var/unpack```

and a member name of ```./var/post_install```, an attacker could overwrite the _real_ file ```/var/post_install``` (which will be executed on shutdown or restart) even with a wrongly signed image file. The extraction is already finished, before the signature check fails.

The only challenge (for an external attacker) is the prediction of a valid path to the USB storage volume or the creation of the proper symbolic link in another location. This bug isn't easy exploitable, if the USB subsystem has been stopped already and that's why a file-based update attempt will not work as expected (as long as ```prepare_fwupgrade``` stops the USB stack).

But there are other options ... from ```DoManualUpdate``` via the TR-064 interface (even possible using TR-069 and therefore externally usable) up to intercepting a download request during an online update and replacing the transmitted file with an own version.

A local attacker needs only access to the USB device, the possibility to create the needed symbolic link on an external system and a chance to re-apply the changed USB storage volume to the FRITZ!Box device.

Replacing ```/var/post_install``` is only a simple example, how to replace a file with an own copy for "command injection" - almost every file below ```/var``` may be (over)written here.

## Fix/Solution

The vendor (AVM) has published new firmware versions for most models still in service. It should be no threat anymore in versions >= 06.80.

## Timeline

2016-07-03 20:56 - Vendor notified by (encrypted) e-mail to security@avm.de, Shell-based exploit included.

2016-07-04 15:43 - Vendor received the notification.

2016-07-05 13:21 - Vendor confirmed the finding, an internal fix is available, offered a test version to check the solution. The fix will be published with the next major release(s), expected in 3rd Q of 2016.

2016-07-06 15:06 - Vendor sent a fixed version (32502M) for a 7412 device (after negotiation about the model) to prove/check the solution.

2016-07-12 18:00 - The fix seems to work as expected, publishing this issue (the details) was delayed until 2016-10-01

2017-04-19 12:55 - I've published the final version of this description, the case is about to be closed now.
