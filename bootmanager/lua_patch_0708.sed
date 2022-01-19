/^return data$/i \
local function data_bootmanager()\
local values = {}\
local pipe = io.popen("/usr/bin/gui_bootmanager get_values")\
local line\
for line in pipe:lines() do\
table.insert(values, { id = line:match("^([^=]-)="), value = line:match("^.-=\\"?(.-)\\"?$") } )\
end\
pipe:close()\
local messages = {}\
--\
-- ToDo: consider to separate the message tables from rest of code, best in an extra file\
--\
if config.language == "de" then\
table.insert(messages, { id = "headline", value = "Folgende Systeme stehen auf dieser FRITZ!Box zur Auswahl bei einem Neustart:" })\
table.insert(messages, { id = "currsys", value = "das aktuell laufende System" })\
table.insert(messages, { id = "altsys", value = "das derzeit inaktive System" })\
table.insert(messages, { id = "switchvalue", value = "(linux_fs_start=%1%switch%)" })\
table.insert(messages, { id = "version", value = "Version %1%version% vom %2%date%" })\
table.insert(messages, { id = "modified", value = "zuletzt modifiziert am %1%date% durch \\"%2%framework%\\"" })\
table.insert(messages, { id = "altinv", value = "Das System in den alternativen Partitionen kann nicht identifiziert werden.\\nEs verwendet entweder ein unbekanntes Dateisystem oder es könnte auch beschädigt sein.\\nEine Umschaltung auf dieses System sollte nur ausgeführt werden, wenn man sich wirklich sehr sicher ist, was man da tut." })\
table.insert(messages, { id = "altmiss", value = "Die derzeit inaktiven Partitionen enthalten kein gültiges System." })\
table.insert(messages, { id = "brndhead", value = "Branding ändern" })\
table.insert(messages, { id = "brndunsupp", value = "Bei diesem Gerät ist keine dauerhafte Änderung der Firmware-Version möglich." })\
table.insert(messages, { id = "brndcurrfixed", value = "Die Firmware-Version des aktuell laufenden Systems ist fest auf \\"%1%fixed%\\" eingestellt und kann nicht geändert werden." })\
table.insert(messages, { id = "brndcurrsingle", value = "Das oben ausgewählte System unterstützt nur die Firmware-Version \\"%1%current%\\", diese ist im Moment auch eingestellt." })\
table.insert(messages, { id = "brndmulti", value = "Das oben ausgewählte System unterstützt mehrere Firmware-Versionen, im Moment ist \\"%1%current%\\" eingestellt." })\
table.insert(messages, { id = "brndset", value = "Beim nächsten Start wird folgender Wert gesetzt und bis zur nächsten Änderung verwendet:" })\
table.insert(messages, { id = "brndaltinv", value = "Da das alternative System nicht identifiziert werden konnte, ist auch keine Information über dort enthaltene Firmware-Versionen verfügbar." })\
table.insert(messages, { id = "brndaltfixed", value = "Die Firmware-Version des derzeit nicht aktiven Systems ist fest auf \\"%1%fixed%\\" eingestellt und kann nicht geändert werden." })\
table.insert(messages, { id = "brndaltsingle", value = "Das oben ausgewählte System unterstützt nur die Firmware-Version \\"%1%alternative%\\"" })\
table.insert(messages, { id = "brndaltnochg", value = ", diese ist im Moment auch eingestellt." })\
table.insert(messages, { id = "brndaltset", value = ", im Moment ist jedoch \\"%1%current%\\" eingestellt." })\
table.insert(messages, { id = "brndaltnew", value = "Bei der Umschaltung des zu verwendenden Systems wird daher auch gleichzeitig dieser Wert auf \\"%1%alternative%\\" geändert." })\
table.insert(messages, { id = "nodata", value = "Fehler im Boot-Manager: Es wurden keine Daten für die Anzeige erzeugt." })\
else\
table.insert(messages, { id = "headline", value = "The following systems are available to be booted on this device next time:" })\
table.insert(messages, { id = "currsys", value = "the currently running system" })\
table.insert(messages, { id = "altsys", value = "the alternative system" })\
table.insert(messages, { id = "switchvalue", value = "(linux_fs_start=%1%switch%)" })\
table.insert(messages, { id = "version", value = "version %1%version% built on %2%date%" })\
table.insert(messages, { id = "modified", value = "last modified on %1%date% using \\"%2%framework%\\"" })\
table.insert(messages, { id = "altinv", value = "Unable to identify the installed system in the alternative partitions.\\nIt may use an unknown filesystem format, it may have been damaged, it's simply missing or it has been deleted otherwise.\\nSwitching to this system may prevent your device from starting correctly.\\nYou should be really sure, what you are doing in this case." })\
table.insert(messages, { id = "altmiss", value = "The alternative partitions do not contain any valid system." })\
table.insert(messages, { id = "brndhead", value = "Change branding" })\
table.insert(messages, { id = "brndunsupp", value = "Unable to change the branding permanently on this device." })\
table.insert(messages, { id = "brndcurrfixed", value = "Branding of currently running system was set to a fixed value of \\"%1%fixed%\\" and can not be changed." })\
table.insert(messages, { id = "brndcurrsingle", value = "The system selected above supports only the single OEM name \\"%1%current%\\" and this is also the current one." })\
table.insert(messages, { id = "brndmulti", value = "The system selected above supports different OEM names, currently the value \\"%1%current%\\" is set." })\
table.insert(messages, { id = "brndset", value = "Restarting the device now, will set this name to the following value (until it's changed once more):" })\
table.insert(messages, { id = "brndaltinv", value = "Due to problems identifying the installed alternative system, there's no idea, which values are supported by this system and the value remains unchanged." })\
table.insert(messages, { id = "brndaltfixed", value = "Branding of installed alternative system was set to a fixed value of \\"%1%fixed%\\" and can not be changed." })\
table.insert(messages, { id = "brndaltsingle", value = "The system selected above supports only the single OEM name \\"%1%alternative\\"" })\
table.insert(messages, { id = "brndaltnochg", value = " and this is also the current one." })\
table.insert(messages, { id = "brndaltset", value = ", but currently \\"%1%current%\\" is set." })\
table.insert(messages, { id = "brndaltnew", value = "Restarting the device now, will set the OEM name value to \\"%1%alternative%\\" without any further questions." })\
table.insert(messages, { id = "nodata", value = "Error from boot-manager script: No data to display." })\
end\
table.insert(messages, { id = "style_caption", value = "padding-right: 8px;" })\
table.insert(messages, { id = "style_sblbl", value = "padding-right: 8px;" })\
-- end of messages\
local bootmanager = {}\
table.insert(bootmanager, { name = "values", obj = values })\
table.insert(bootmanager, { name = "messages", obj = messages })\
return bootmanager\
end\
\
data.bootmanager = data_bootmanager()

/^local savecookie = {}/a \
if box.post.linux_fs_start then\
local linux_fs_start = string.gsub(box.post.linux_fs_start, "'", "")\
local branding = box.post[linux_fs_start.."_branding"] ~= nil and string.gsub(box.post[linux_fs_start.."_branding"], "'", "") or ""\
os.execute("/usr/bin/gui_bootmanager switch_to '"..linux_fs_start.."' '"..branding.."'")\
end
