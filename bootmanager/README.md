# Files in this folder

`bootmanager`

It's a meanwhile outdated shell script to switch the active operating system on a FRITZ!Box device from command line. This one was able to manage different sets of settings for each system.

`gui_bootmanager`

It's a shell script, intended to be called on a FRITZ!Box device with VR9/GRX500/Puma6 chipset, which has the ability to switch between two different installed operating systems. It's at the same time an attempt to equalize the special needs of each of these models, how to manage the installed filesystem images in SquashFS format.

It provides different modes of operation:

- generate the HTML and JS code needed to include its functions into vendor's restart page
- generate a list of current settings, which may be used by the caller to implement an own user interface
- switch the active system version and branding in a secure and reusable manner

German and English messages are included in the script, the default language is ```en``` and it will be switched by the environment setting from FRITZ!OS (```Language``` variable) to ```de```, if this value is present in the calling system.

The code checks, if any of the present systems was modified by a supported framework (```YourFritz```, ```Freetz``` or ```modfs```) and shows the date and time of last update, if it detects any of these frameworks. Finally, it's simply looking for the various version files and uses the file date and time of them to display the values.

To install it to your own firmware image, best copy it to location ```/usr/bin/gui_bootmanager``` and set the wanted attributes and owner/group ID. The other files from here expect it there ... if you put it elsewhere, you probably have to change the location in other files, too.

`patch_system_reboot_lua.patch`

It's a minimalistic unified ```diff``` file with the short code to be integrated, if you want:

- to display the current and alternative system properties and
- to switch the active system to the alternative one on reboot

from the original Lua page by AVM in the last recent OS versions.

There were no important changes from version 06.5x up to 07.00 in the code from the file to change (```usr/www/$OEM/system/reboot.lua```). Therefore the same patch should work for all versions in this range.

If you want to apply it somewhere, change the name of file to be patched at the beginning of this ```diff``` output somehow or use a filter (e.g. a ```sed``` call like this:

```shell
sed -e 's|$TARGET_BRANDING|avm|g' patch_system_reboot_lua.patch | patch -p0
```

) to specify the subdirectory, wherein the Lua file should be changed.

If your firmware image contains more than a single *branding*, you'll probably need to apply the patch to more than one sub-tree below ```/usr/www```.

`change_system_reboot_lua.sh`

An alternative approach to change the original file - it uses the ```sed``` command to add the needed lines to the specified file (the name of file is the first and only parameter).

Due to the *limited anchor code* for the changes, this manner may still work, if a line of the above provided ```diff``` file will no longer match the original code.

At the same time this limitation forecloses any protection against double invocation for the same file.