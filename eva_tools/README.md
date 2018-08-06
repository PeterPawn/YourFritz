# Files in this folder

`EVA-Discover.ps1`

- Powershell script to detect a booting FRITZ!Box device in your network and set up an IPv4 address for FTP access to EVA

`EVA-FTP-Client.ps1`

- Powershell script to access the FTP service provided by the bootloader (EVA) of a FRITZ!Box (and some other) device(s)
- this may be customized to run a predefined command/action sequence or you may specify a script block with the requested actions while calling it
- the following actions are predefined:
  - `GetEnvironmentFile [ "env" | "count" ]`
  - `GetEnvironmentValue <name>`
  - `SetEnvironmentValue <name> [ <value> ]`
  - `RebootTheDevice`
  - `SwitchSystem`
  - `BootDeviceFromImage <image_file>`
  - `UploadFlashFile <flash_file> <target_partition>`
  - or you may use lower-level functions to create your own actions

`eva_discover`

- shell script to detect a starting FRITZ!OS device in your network
- BusyBox 'ash' compatible syntax
- 'socat' utility (<http://www.dest-unreach.org/socat/>) is needed for network access
- command line parameter utilization is incomplete yet

`eva_get_environment`
`eva_store_tffs`
`eva_switch_system`
`eva_to_memory`

- these scripts are more or less only proofs of concept, how to access the FTP server in the bootloader from a limited environment like another FRITZ!OS instance
- they are usable with BusyBox 'ash' and 'nc' applets
- there's usually no usage screen and only very limited support for error detection and notification
- an image needed for `eva_to_memory` may be created from a "normal" image (tarball) with the `image2ram` script

`prepare_jffs2_image`

- simple script to create a JFFS2 image from predefined content
- intended to be used on a FRITZ!Box device, because the geometry of the partition to create is read from /proc/mtd

`build_in_memory_image`

- very incomplete script to create an (universal) in-memory image from vendor's firmware
- the resulting image does not contain closed-source components, so it may be shared without copyright violations, 'cause only redistributable parts from the original firmware are used

## Other sources of information

If you need help using these files to access the FTP server of AVM's EVA loader, have a look at this thread:

https://www.ip-phone-forum.de/threads/wie-verwende-ich-denn-nun-die-skript-dateien-aus-yourfritz-eva_tools.298591/