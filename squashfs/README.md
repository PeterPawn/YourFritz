### Modifications for SquashFS 4.3 tools

While investigating the opportunities to unpack, modify and repack a SquashFS image from the “Windows Bash” (that means the Ubuntu subsystem on Windows 10 x64 systems), I found once more, that the emulated syscall for ‘mknod’ does not implement the creation of “special files” (character and block device inodes) and even if it would do this, the creation of such an inode requires superuser access rights.

Both preconditions usually are not met while unpacking - but the 'mksquashfs' utility provides an option (-pf) to create device inodes within a new image using another way.

While unpacking an existing image, the ‘unsquashfs’ utility should create such a file with “pseudo file definitions” and not try, to create real device nodes ... this will always fail on Windows or emit an error message even on a Linux system, if the caller was not the superuser.

Because some inode properties (date/time info) are lost this way, I’d like to implement an additional option in the future, which takes all file attributes from another file, that was built by an earlier call of 'unsquashfs' with ‘-lls’ or ‘-linfo’ option.

If such an option exists, it doesn’t matter any longer, whether the "underlying" filesystem supports Linux attributes at all … it would only be used to store “real file content” and all metadata for these files are taken from (or managed by) this “list file”.

This would allow a version of 'squashfs-tools' running on a native Windows installation without the subsystem emulation, where a Windows filesystem is used to store the unpacked files.

So I would like to add and/or change some code, modifying the (original) SquashFS tools … the first step was the separation of listing output (on STDOUT) from other messages during an "unsquashfs" call (which are directed to STDERR now). 

This is done with the first patch ‘020-definite_streams_for_displayed_text.patch’. To get a "list file" as mentioned above, the caller may redirect STDOUT to a file.

The second patch adds a new option ‘-no-dev’ to the ‘unsquashfs’ utility. If it’s specified, the creation of special inodes is skipped without error messages.

To save the special files from an image to a pseudo definition file, a second option ‘-pseudo’ was implemented, which implies ‘-no-dev’ and writes one line for each character or block device into a specified file.

This file may later be used to re-create these devices in a ‘mksquashfs’ call, while they are not really present in the filesystem directory.

I've decided to patch the original code instead of the Freetz version ... the new behavior may be useful for "normal" SquashFS images too and is not a special use-case for a FRITZ!OS image. As result, some Freetz patches have to be recreated, but this is "by intention" and will be done later.
