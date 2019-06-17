#! /bin/bash
[ -z "$TARGET_BRANDING" ] && printf "TARGET_BRANDING value is not set.\a\n" 1>&2 && exit 1

TargetDir="${TARGET_DIR:+$TARGET_DIR/}"

JsFile="usr/www/$TARGET_BRANDING/system/reboot.js"
LuaFile="usr/www/$TARGET_BRANDING/system/reboot.lua"

check_version()
{
	local major=$(expr "$1" : "0*\([1-9]*[0-9]\)")
	local minor=$(expr "$2" : "0*\([1-9]*[0-9]\)")
	local wanted_major=$(expr "$3" : "0*\([1-9]*[0-9]\)")
	local wanted_minor=$(expr "$4" : "0*\([1-9]*[0-9]\)")

	[ $major -lt $wanted_major ] && return 0
	[ $major -gt $wanted_major ] && return 1
	[ $minor -lt $wanted_minor ] && return 0
	return 1
}

if [ "$TARGET_SYSTEM_VERSION" = "autodetect" ]; then
	[ -z "$TARGET_SYSTEM_VERSION_DETECTOR" ] && printf "TARGET_SYSTEM_VERSION_DETECTOR value is not set.\a\n" 1>&2 && exit 1
	TARGET_SYSTEM_VERSION="$($TARGET_SYSTEM_VERSION_DETECTOR $TARGET_DIR -m | sed -n -e 's|^Version="\(.*\)"|\1|p')"
	printf "Autodetection of target system version: %s\n" "$TARGET_SYSTEM_VERSION" 1>&2
fi

[ -z "$TARGET_SYSTEM_VERSION" ] && printf "TARGET_SYSTEM_VERSION value is not set.\a\n" 1>&2 && exit 1
major=$(( $(expr "$TARGET_SYSTEM_VERSION" : "[0-9]*\.0*\([1-9]*[0-9]\)\.[0-9]*") + 0 ))
minor=$(( $(expr "$TARGET_SYSTEM_VERSION" : "[0-9]*\.[0-9]*\.0*\([1-9]*[0-9]\)") + 0 ))
[ "$major" -eq 0 ] && [ "$minor" -eq 0 ] && printf "TARGET_SYSTEM_VERSION value is invalid.\a\n" 1>&2 && exit 1

getJsPatchText_0708()
{
cat <<'EndOfPatch'
/^TableCalls/i \
function onChangeLinuxFsStart(e){var s=jsl.evtTarget(e).id.substr("uiLinux_fs_start-".length);if(!s)return;jsl.show(s+"_branding");jsl.hide((s=="running"?"alternative":"running")+"_branding")}\
function buildBootmanager(data){function gv(src,id){var r=src.filter(function(e){return e.id===id});if(r.length>0)return r[0].value};function nl(frag,cnt=1){while(cnt--){html2.add(frag,html2.br())}};var m=data.filter(function(d){return d.name==="messages"})[0].obj;var v=data.filter(function(d){return d.name==="values"})[0].obj;var r=html2.fragment();html2.add(r,html2.h3({},gv(m,"headline")));nl(r);var ct=html2.span();var at=html2.span();var cs=gv(v,"current_switch_value");html2.add(ct,html2.strong({style:gv(m,"style_caption")},gv(m,"currsys")));html2.add(ct,html2.printf(gv(m,"switchvalue"),cs));nl(ct,2);html2.add(ct,html2.printf(gv(m,"version"),gv(v,"active_version"),gv(v,"active_date")));if(gv(v,"active_modified_at")){nl(ct);html2.add(ct,html2.printf(gv(m,"modified"),gv(v,"active_modified_at"),gv(v,"active_modified_by")))}nl(ct,2);html2.add(at,html2.strong({style:gv(m,"style_caption")},gv(m,"altsys")));html2.add(at,html2.printf(gv(m,"switchvalue"),cs?((parseInt(cs)+1)%2).toString():"0"));nl(at,2);var inactive=gv(v,"inactive_version");if(inactive!="missing"){if(inactive.length>0){html2.add(at,html2.printf(gv(m,"version"),gv(v,"inactive_version"),gv(v,"inactive_date")));if(gv(v,"inactive_modified_at")){nl(at);html2.add(at,html2.printf(gv(m,"modified"),gv(v,"inactive_modified_at"),gv(v,"inactive_modified_by")))}}else{gv(m,"altinv").split("\\n").forEach(function(l){html2.add(at,l);nl(at)})}}else{html2.add(at,gv(m,"altmiss"))}nl(at,2);var radios=html2.radios({name:'linux_fs_start',selected:(gv(v,"system_is_switched")=="true"?'alternative':'running'),attr:{disabled:(inactive=="missing"?true:false),onClick:onChangeLinuxFsStart},options:[{value:'running',text:ct},{value:'alternative',text:at,}]});html2.add(r,radios);html2.add(r,html2.h4({},gv(m,"brndhead")));var cb=gv(v,"switch_branding_support");if(cb=="false"){html2.add(r,html2.span({},gv(m,"brndunsupp")));html2.add(r,html2.hiddenInput({name:"alternative_branding",value:gv(v,"current_branding")}))}else{var rb=html2.span({id:"running_branding",style:(gv(v,"system_is_switched")=="true"?'display: none':'')});if(cb=="both_fixed"||cb=="running_fixed"){html2.add(rb,html2.printf(gv(m,"brndcurrfixed"),html2.strong({},gv(v,"current_branding"))));html2.add(r,html2.hiddenInput({name:"running_branding",value:gv(v,"current_branding")}))}else{if(gv(v,"active_brandings").split(" ").length>1){html2.add(rb,html2.printf(gv(m,"brndmulti"),html2.strong({},gv(v,"current_branding"))));nl(rb);var sb=html2.selectBox({id:"uiRunningBranding",name:"running_branding"});gv(v,"active_brandings").split(" ").forEach(function(o){sb.options.add(html2.option({value:o,selected:gv(v,"current_branding")==o?true:false},o))});html2.add(rb,html2.label({for:"uiRunningBranding",style:gv(m,"style_sblbl")},gv(m,"brndset")));html2.add(rb,sb)}else{html2.add(rb,html2.printf(gv(m,"brndcurrsingle"),html2.strong({},gv(v,"current_branding"))));html2.add(r,html2.hiddenInput({name:"running_branding",value:gv(v,"current_branding")}))}}html2.add(r,rb);var ab=html2.span({id:"alternative_branding",style:(gv(v,"system_is_switched")=="true"?'':'display: none')});if(inactive!="missing"){if(inactive.length>0){if(cb=="both_fixed"||cb=="alternative_fixed"){html2.add(ab,html2.printf(gv(m,"brndaltfixed"),html2.strong({},gv(v,"inactive_brandings"))));html2.add(r,html2.hiddenInput({name:"alternative_branding",value:gv(v,"alternative_branding")}))}else{if(gv(v,"inactive_brandings").split(" ").length>1){html2.add(ab,html2.printf(gv(m,"brndmulti"),html2.strong({},gv(v,"current_branding"))));nl(ab);var asb=html2.selectBox({id:"uiAlternativeBranding",name:"alternative_branding",style:gv(m,"style_selbrand")});gv(v,"inactive_brandings").split(" ").forEach(function(o){asb.options.add(html2.option({value:o,selected:gv(v,"current_branding")==o?true:false},o))});if(asb.selectedOptions.length==0){asb.options.forEach(function(o){if(o.value==gv(v,"current_branding"))o.selected=true})}html2.add(ab,html2.label({for:"uiAlternativeBranding",style:gv(m,"style_sblbl")},gv(m,"brndset")));html2.add(ab,asb)}else{html2.add(ab,html2.printf(gv(m,"brndaltsingle"),html2.strong({},gv(v,"inactive_brandings"))));if(gv(v,"inactive_brandings")==gv(v,"current_branding")){html2.add(ab,gv(m,"brndaltnochg"))}else{html2.add(ab,html2.printf(gv(m,"brndaltset"),html2.strong({},gv(v,"current_branding"))));nl(ab);html2.add(ab,html2.printf(gv(m,"brndaltnew"),html2.strong({},gv(v,"inactive_brandings"))))}html2.add(r,html2.hiddenInput({name:"alternative_branding",value:gv(v,"inactive_brandings")}))}}}else{html2.add(ab,gv(m,"brndaltinv"))}}html2.add(r,ab)}return r}
/^if(data.actions)/i \
if(data.bootmanager){html2.add(content,buildBootmanager(data.bootmanager));}
EndOfPatch
}
getLuaPatchText_0708()
{
cat <<'EndOfPatch'
/^local function data_actions()/i \
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
end\
table.insert(messages, { id = "style_caption", value = "padding-right: 8px;" })\
table.insert(messages, { id = "style_sblbl", value = "padding-right: 8px;" })\
-- end of messages\
local bootmanager = {}\
table.insert(bootmanager, { name = "values", obj = values })\
table.insert(bootmanager, { name = "messages", obj = messages })\
return bootmanager\
end

/^data.actions = data_actions()/a \
data.bootmanager = data_bootmanager()

/^local savecookie = {}/a \
if box.post.linux_fs_start then\
local linux_fs_start = string.gsub(box.post.linux_fs_start, "'", "")\
local branding = box.post[linux_fs_start.."_branding"] ~= nil and string.gsub(box.post[linux_fs_start.."_branding"], "'", "") or ""\
os.execute("/usr/bin/gui_bootmanager switch_to '"..linux_fs_start.."' '"..branding.."'")\
end
EndOfPatch
}
getLuaPatchText_pre0708()
{
cat <<'EndOfPatch'
/^local savecookie = {}/a \
if box.post.linux_fs_start then\
local linux_fs_start = string.gsub(box.post.linux_fs_start, "'", "")\
local branding = box.post[linux_fs_start.."_branding"] ~= nil and string.gsub(box.post[linux_fs_start.."_branding"], "'", "") or ""\
os.execute("/usr/bin/gui_bootmanager switch_to '"..linux_fs_start.."' '"..branding.."'")\
end

/^<form action=.*>/a \
<div id="managed_reboot" class="reboot_managed">\
<?lua\
pipe = io.popen("/usr/bin/gui_bootmanager html_display")\
line = pipe:read("*a")\
pipe:close()\
box.out(line)\
?>\
</div>
EndOfPatch
}
if check_version $major $minor 7 8; then
	printf "      Patching file '%s' ...\n" "$LuaFile" 1>&2
	getLuaPatchText_pre0708 > "$TMP/gui_bootmanager_0_6_tmp"
	sed -f "$TMP/gui_bootmanager_0_6_tmp" -i "$TargetDir$LuaFile"
	rm "$TMP/gui_bootmanager_0_6_tmp"
else
	printf "      Patching file '%s' ...\n" "$JsFile" 1>&2
	getJsPatchText_0708 > $TMP/gui_bootmanager_0_6_tmp
	sed -f "$TMP/gui_bootmanager_0_6_tmp" -i "$TargetDir$JsFile"
	printf "      Patching file '%s' ...\n" "$LuaFile" 1>&2
	getLuaPatchText_0708 > $TMP/gui_bootmanager_0_6_tmp
	sed -f "$TMP/gui_bootmanager_0_6_tmp" -i "$TargetDir$LuaFile"
	rm "$TMP/gui_bootmanager_0_6_tmp"
fi
