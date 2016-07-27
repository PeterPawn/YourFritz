This incident was related to an automatic "take over" of an unconfigured FRITZ!Box device by an attacker using the TELNET
daemon in combination with GUI support to export and import data even in an unconfigured device to modify settings just 
before the authorized user could set any password to protect the settings.

- has been defused by a general denial of the TELNET service in stock firmware
- further mitigated by adding a pre-configured GUI password to some devices (but afaik not to every new model), which prevents
  an unauthorized (automated) access to the GUI superficial, but due to the possibility to read this value from the device using
  the bootloader of a starting box (it was readable with "GETENV" FTP command), this was not really a solution and increases the 
  expenses only a very little bit
