### Modifications for SquashFS 4.3 tools

While investigating the opportunities to unpack, modify and repack a SquashFS image from the "Windows Bash" (that means the Ubuntu subsystem on Windows 10 x64 systems), I found once more, that the syscall for 'mknod' does not implement the creation of "special files" (character and block device inodes) and even if it would do this, the creation of such a file requires root access rights.

Both preconditions usually aren't met while unpacking - but the 'mksquashfs' utility provides an option (-pf) to create device inodes within a new image using another way.

While unpacking an existing image, the 'unsquashfs' utility should create such a file with "pseudo file definition" instead to try, to create real device nodes (which will fail on Windows or emit an error message, if the caller wasn't 'root').

Because some inode properties (date/time info) are lost this way, I'd like to implement an additional option in the future, which takes all file attributes from another file, created from 'unsquashfs' with '-lls' or '-linfo' option.

If such an option exists, it doesn't matter any longer, if the underlaying filesystem supports linux attributes at all ... it would only be used to store "real file content" and all metadata for these files are taken from/managed by the "list file".

This would allow a version of 'squashfs-tools' running on a native Windows installation without the subsystem emulation, where a Windows filesystem is used to store the unpacked files.

So I'd like to add/change some code to/of SquashFS tools ... the first step was the separation of listing output (on STDOUT) from other messages for an unpacking call (which have to go to STDERR now). This is done with the first patch '020-definite_streams_for_displayed_text.patch'.

The second patch adds a new option '-no-dev' to the 'unsquashfs' utility. If it's specified, the creation of special inodes is skipped without error messages.

To save the special files from the image to a pseudo definition file, a second option '-pseudo' was invented, which implies '-no-dev' and writes one line for each character or block device into a specified file.

This file may later be used to re-create these devices in a 'mksquashfs' call without the need, that they really are present in the filesystem directory to pack.
