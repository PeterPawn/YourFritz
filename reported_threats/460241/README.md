#Security flaw in "AVM FRITZ!OS" 

## Synopsis

An authorized user with write access to the NAS base directory may overwrite the hash database used for the outbound firewall of the integrated child lock feature.

## Affected versions

- unspecified/unknown first version, obviously every version storing the database in a location, which is reachable using NAS functions
- up to currently released beta version(s), latest version tested was 113.06.69-41896 for FRITZ!Box 7490, built on 2016-11-10
 
## Attack vectors

- an attack needs authorized write access to the NAS base directory of a running FRITZ!Box device
- the FRITZ!Box device has to provide a Samba service for NAS access
- an update of the BPjM hashes database has to be stored in the FRITZ directory below NAS root directory

## Mitigations

Do not grant write access rights for the NAS base directory or even all volumes to any person (child, teenager or even adult), if you want to ensure the integrity of the blacklist feature for the outbound firewall based on the BPjM database.

## Available fixes / solutions

Not fixed until the time of this writing. 

The vendor confirmed the vulnerability (see timeline below) and announced a fix for the next major release, expected in Q3 2016. 

No attempt to fix it really is visible so far.

## CVE

No CVE ID requested, mitre.org will even not provide IDs for AVM's products any longer.

## Description / Exploitation of the vulnerability

Some times ago AVM's FRITZ!OS started storing the database for the BPjM blacklist feature in the FRITZ directory below the NAS base directory on these models, if a persistent storage is available there. Whether older models without internal storage are also affected, is unknown - newer models (and the older 7390) are equipped with NAND flash and they use it to store the current version of the mentioned database. But not all models provide the NAS feature, it's missing on low-budget devices.

The BPjM database is a simple list of hash values for URIs, known to provide unsuitable HTTP content for children and teenagers. It's maintained by a German governmental institution and usually updated once per month. 

The FRITZ!OS firmware contains the database available at date of its release (or at least the previous one). If the router may access the internet, it tries to download an update for the database and merges the present database and this update. The result is stored using the path `/var/InternerSpeicher/FRITZ/bpjm.data`, but this place is below the NAS base directory `/var/media/ftp` - `/var/InternerSpeicher` is only a symbolic link pointing to it. If no BPjM based limitations for internet access are set, the list will not be updated.

Each database entry has a fixed length and the whole file is protected against changes by a CRC32 value stored in front of the hash entries. A closed-source daemon (contfiltd) is used to check each URI received from a limited client, whether it matches an entry in the blocked list. The exact match algorithm doesn't matter here. This daemon keeps the database file opened, while he's running.

If an attacker tries to modify the database file using FTP or FRITZ!NAS (a GUI based file-manager) service, this usually creates a new file first, removes the old one and renames the new file to the original name. Such an attempt will be noticed by `contfiltd` and the modified file will not be used anymore and sooner or later replaced with a fresh and valid copy.

But Samba access provides a way to change a file "in place". If a file is opened read/write, the write pointer may be set to any position within the file and the next output data is written there. The inode number of the file will not get changed and this way a modification isn't detected anymore, as long as a valid file is the result - this means especially, the attacker has to compute a new CRC32 value for the hash entries.

Changing the stored hash in any entry will render the whole entry useless, because it will not match the hashed address anymore.

A Windows-based proof-of-concept (using PowerShell) exploiting this vulnerability is available as `FakeBPjMList.ps1`. It fills the whole database with empty entries (all zeroes) and computes and stores a new CRC32 value. After this changes, sites may accessed with unsuitable content originally blocked by the list.

The obviously causes for this possibility to attack the integrity of the outbound firewall are the unnecessary write access to the database and the very weak protection of its integrity with a CRC32 checksum. This checksum is taken from the original file and not an idea of the FRITZ!Box vendor.

The cheapest and simplest solution is denying access to this file for every NAS user ... there's no reason to access it from outside of the router.

## Timeline

2016-06-02 23:45 - Vendor notified by (encrypted) e-mail to security@avm.de, PowerShell-based exploit included.

2016-06-03 16:16 - Vendor attested *receiving* the notification (and only this).

2016-06-20 12:33 - Vendor contacted again due to missing confirmation or refusal, deadline announced on 2016-06-24 18:00

2016-06-24 15:25 - Vendor confirmed the findings, a corrected version will be available with the next major release, planned to be published in 3rd quarter of 2016.
                   
2016-06-24 18:00 - Publication deferred until 2016-10-01.

2016-11-10 --:-- - No visible attempts to fix the flaw, no further notice from vendor about a postponed release of the next major version, which was announced in Q3 2016.

2016-11-17 08:00 - Meanwhile Q4 2016 has reached its "half-time" and it's time to publish the description and an exploit, because there's obviously no attempt so far, to fix the problem.
