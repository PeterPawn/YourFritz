#
# supported languages (compared to config.language in Lua), the first entry (en) will be used, if language isn't supported
#
Languages en de
#
# message fragments for english language
#
en:headline=The following systems are available to be booted on this device next time:
en:currsys=the currently running system
en:altsys=the alternative system
en:switchvalue=(linux_fs_start=%1%switch%)
en:version=version %1%version% built on %2%date%
en:modified=last modified on %1%date% using "%2%framework%"
en:altinv=Unable to identify the installed system in the alternative partitions.\nIt may use an unknown filesystem format, it may have been damaged, it's simply missing or it has been deleted otherwise.\nSwitching to this system may prevent your device from starting correctly.\nYou should be really sure, what you are doing in this case.
en:altmiss=The alternative partitions do not contain any valid system.
en:brndhead=Change branding
en:brndunsupp=Unable to change the branding permanently on this device.
en:brndcurrfixed=Branding of currently running system was set to a fixed value of "%1%fixed%" and can not be changed.
en:brndcurrsingle=The system selected above supports only the single OEM name "%1%current%" and this is also the current one.
en:brndmulti=The system selected above supports different OEM names, currently the value "%1%current%" is set.
en:brndset=Restarting the device now, will set this name to the following value (until it's changed once more):
en:brndaltinv=Due to problems identifying the installed alternative system, there's no idea, which values are supported by this system and the value remains unchanged.
en:brndaltfixed=Branding of installed alternative system was set to a fixed value of "%1%fixed%" and can not be changed.
en:brndaltsingle=The system selected above supports only the single OEM name "%1%alternative"
en:brndaltnochg= and this is also the current one.
en:brndaltset=, but currently "%1%current%" is set.
en:brndaltnew=Restarting the device now, will set the OEM name value to "%1%alternative%" without any further questions.
en:nodata=Error from 'bootmanager' script: No data to display.
#
# message fragments for german language
#
de:headline=Folgende Systeme stehen auf dieser FRITZ!Box zur Auswahl bei einem Neustart:
de:currsys=das aktuell laufende System
de:altsys=das derzeit inaktive System
de:switchvalue=(linux_fs_start=%1%switch%)
de:version=Version %1%version% vom %2%date%
de:modified=zuletzt modifiziert am %1%date% durch "%2%framework%"
de:altinv=Das System in den alternativen Partitionen kann nicht identifiziert werden.\nEs verwendet entweder ein unbekanntes Dateisystem oder es könnte auch beschädigt sein.\nEine Umschaltung auf dieses System sollte nur ausgeführt werden, wenn man sich wirklich sehr sicher ist, was man da tut.
de:altmiss=Die derzeit inaktiven Partitionen enthalten kein gültiges System.
de:brndhead=Branding ändern
de:brndunsupp=Bei diesem Gerät ist keine dauerhafte Änderung der Firmware-Version möglich.
de:brndcurrfixed=Die Firmware-Version des aktuell laufenden Systems ist fest auf "%1%fixed%" eingestellt und kann nicht geändert werden.
de:brndcurrsingle=Das oben ausgewählte System unterstützt nur die Firmware-Version "%1%current%", diese ist im Moment auch eingestellt.
de:brndmulti=Das oben ausgewählte System unterstützt mehrere Firmware-Versionen, im Moment ist "%1%current%" eingestellt.
de:brndset=Beim nächsten Start wird folgender Wert gesetzt und bis zur nächsten Änderung verwendet:
de:brndaltinv=Da das alternative System nicht identifiziert werden konnte, ist auch keine Information über dort enthaltene Firmware-Versionen verfügbar.
de:brndaltfixed=Die Firmware-Version des derzeit nicht aktiven Systems ist fest auf "%1%fixed%" eingestellt und kann nicht geändert werden.
de:brndaltsingle=Das oben ausgewählte System unterstützt nur die Firmware-Version "%1%alternative%"
de:brndaltnochg=, diese ist im Moment auch eingestellt.
de:brndaltset=, im Moment ist jedoch "%1%current%" eingestellt.
de:brndaltnew=Bei der Umschaltung des zu verwendenden Systems wird daher auch gleichzeitig dieser Wert auf "%1%alternative%" geändert.
de:nodata=Fehler im Boot-Manager: Es wurden keine Daten für die Anzeige erzeugt.
#
# language independent strings
#
any:style_caption=padding-right: 8px;"
any:style_sblbl=padding-right: 8px;
