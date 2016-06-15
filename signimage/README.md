## sign / verify TAR archives like AVM's components do it
This folder contains some scripts to demonstrate the process of signing firmware images in the reading of AVM.

Such signed images are TAR archives (the old format with "ustar" headers and without GNU extension or PaxHeaders)
and they contain an extra member `./var/signature` with the output of a call to RSA_sign() for the original archive
with two empty placeholder blocks (a 512 byte) instead of this signature file.

The sample scripts and their purposes:

`generate_signing_key`

create an own key pair to sign images - AVM uses 1024 bit RSA keys, this script may be used to create larger keys, which can't
be verified with the AVM components

`sign_image`

add a signature file to a specified TAR archive and stream the result to STDOUT

`avm_pubkey_to_pkcs8`

convert a public key file in AVM reading (one line with modulus as hexadecimal character string and another one with the public
exponent) into a well-formed PKCS8 structure in a PEM file, ready to be used by OpenSSL functions

`check_signed_image`

verify the signature of a signed image, the script accepts a list of possible public keys (in various formats) and tries to
decode the signature file, until the right key was found or the end of list is reached

`image_signing_files.inc`

contains some definitions for the location and file name conventions for key files involved in this process, this file will 
be included by the others to setup key file locations - has to be edited to reflect your own preferences

If you need further information and you're able to read text in German, you can find a longer explanation regarding the signing
process and the use cases of these scripts in the IPPF forum:

http://www.ip-phone-forum.de/showthread.php?t=286213
