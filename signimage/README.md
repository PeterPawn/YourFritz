# sign / verify TAR archives like AVM's components do it

This folder contains some scripts to demonstrate the process of signing firmware images in the reading of AVM.

Such signed images are TAR archives (the old format with "ustar" headers and without GNU extension or PaxHeaders)
and they contain an extra member `./var/signature` with the output of a call to `RSA_sign()` for the original archive
with two empty placeholder blocks (a 512 byte) instead of this signature file.

The sample scripts and their purposes:

`yf_genkey`

create an own key pair to sign images - AVM uses 1024 bit RSA keys, this script may be used to create larger keys, which can't
be verified with the AVM components

`yf_sign`

add a signature file to a specified TAR archive and stream the result to STDOUT

`avm_pubkey_to_pkcs8`

convert a public key file in AVM reading (one line with modulus as hexadecimal character string and another one with the public
exponent) into a well-formed PKCS8 structure in a PEM file, ready to be used by OpenSSL functions

`yf_check_signature`

verify the signature of a signed image, the script accepts a list of possible public keys (in various formats) and tries to
decode the signature file, until the right key was found or the end of list is reached

`yf_signimage.conf`

contains some definitions for the location and file name conventions of personal key files involved in this process; this file
will be included by the others to setup key file locations - read comments carefully, in most cases no permanent changes should
be needed, even if it's called the 'configuration file' now ... in any case it should be possible to limit own changes to the
settings within this file, so please do not change the other scripts until it's really inevitable

---

`FirmwareImage.ps1`

If you prefer to use a Windows system for these tasks or if you want to check out a really great solution for cross-platform automation (with PowerShell Core 6.0 on Linux or Mac OS X), you should have a glance on this file.

It contains some PowerShell classes (therefore you need at least PowerShell version 5 on Windows, which is available in the WMF 5.1 package from Microsoft for all version since Windows 7) and may help you to perform the same tasks as above:

- creating/storing/loading keys,
- signing an image file,
- verifying a signature
- extracting a bootable image (to be loaded via EVA) from a firmware file

from a PowerShell command prompt.

These classes have been tested with PowerShell Core 6.0, too - they also work on Linux (openSUSE Tumbleweed was used here) with PowerShell Core 6.0.2 (<https://github.com/PowerShell/PowerShell>).

To use these classes, simply "source" this file with

```Powershell
. FirmwareImage.ps1
```

(it's a period followed by a space and the file name) and create objects from the contained classes.

If you want to create a new key for image signing and save it to the file `image_signing.key` (in the current directory), protected by password `firmware_signing`, you would enter the following:

```Powershell
[SigningKey]::new().toRSAPrivateKeyFile("$pwd\image_signing.key", "firmware_signing")
```

To load this key from file again and extract/store the public key as a file (with the same base-name) with PEM encoding and as another one with AVM's format of an ASC file, simply enter:

```Powershell
[SigningKey]::FromRSAPrivateKeyFile("$pwd\image_signing.key", "firmware_signing").toRSAPublicKeyFile("$pwd\image_signing.pem")
[SigningKey]::FromRSAPrivateKeyFile("$pwd\image_signing.key", "firmware_signing").toASCFile("$pwd\image_signing.asc")
```

Finally, if you want to sign your own firmware image file `my_firmware.image` with this key and store the signed image file as `my_upload.image`, you may call it like this:

```Powershell
[FirmwareImage]::new("$pwd\my_firmware.image").addSignature("$pwd\image_signing.key", "firmware_signing", "$pwd\my_upload.image")
```

If you want to verify the signature of the new file, use:

```Powershell
[FirmwareImage]::new("$pwd\my_upload.image").verifySignature("$pwd\image_signing.asc")
True
```

To verify a firmware image, which was downloaded from an untrusted source, you still need the `.asc` file with AVM's public key, used for this device model.

There's another method to verify an image against one out of a set of possible public keys (usually AVM's firmware contains three different candidates), it uses an array of file names for these keys and returns `True`, if any of the specified keys was usable *and* the verification was successful.

```Powershell
[FirmwareImage]::new("$pwd\my_upload.image").verifySignature([string[]] @("$pwd\avm_firmware_public_key1", "$pwd\avm_firmware_public_key2", "$pwd\avm_firmware_public_key3"))
False
```

In the case above, the file wasn't signed with any of the specified keys or someone later tampered with it.

To retrieve the bootable image from a complete firmware image file, you may use the `getBootableImage` function as follows:

```Powershell
[FirmwareImage]::new("$pwd\original.image").getBootableImage("$pwd\bootable.image")
```

This call extracts a stream with the contained files `./var/tmp/kernel.image` and `./var/tmp/filesystem.image` (any existing TI checksum gets removed) from input file `original.image` as one single stream and writes the result to file `bootable.image`.

The new file may be used to start a FRITZ!Box device from RAM. Please have a look at the `eva_tools` sub-folder to get an impression, how to cope with such a task, using other PowerShell scripts.

---

If you need further information and you're able to read text in German, you can find a longer explanation regarding the signing
process and the use cases of these scripts in the IPPF forum:

<http://www.ip-phone-forum.de/showthread.php?t=286213>
