/^return data$/i \
local function data_bm()\
local bm = {}\
local empty = {}\
local function bm_values()\
local values = {}\
local data = io.open("/var/run/bootmanager/output")\
if not data then\
data = io.popen("/usr/bin/bootmanager get_values")\
hasServ = false\
if not data then\
return empty\
end\
else\
hasServ = true\
end\
values["hasService"] = hasServ\
for line in data:lines() do\
local id, value\
id, value = line:match('^([^=]-)="?(.-)"?$')\
if value == "true" or value == "false" then\
value = ( value == "true" )\
end\
values[id] = value\
end\
data:close()\
return values\
end\
local function bm_msgs()\
local messages = {}\
local clang = config.language\
local msgs = io.open("/usr/bin/bootmanager.msg")\
if msgs then\
local lang, id, value, usedLanguage\
local languagesChecked = false\
for line in msgs:lines() do\
if line:sub(1, 1) ~= "#" then\
if line:match("^[Ll]anguages (%l%l)%s?(.-)$") and not languagesChecked then\
local deflang, addlangs, lng\
languagesChecked = true\
deflang, addlangs = line:match("^[Ll]anguages (%l%l)(.-)$")\
if deflang ~= clang then\
for lng in addlangs:gmatch(" ?(%l%l ?)") do\
if lng:match("^%s-(.-)%s-$") == clang then\
usedLanguage = clang\
break\
end\
end\
if not usedLanguage then\
usedLanguage = deflang\
end\
else\
usedLanguage = clang\
end\
messages["usedLanguage"] = usedLanguage\
else\
lang, id, value = line:match("^([^:]-):([^=]-)=(.-)$")\
if lang and id and value then\
if usedLanguage == lang or "any" == lang then\
messages[id] = string.gsub(value, "\\\\n", "\\n")\
end\
end\
end\
end\
end\
msgs:close()\
else\
messages = empty\
end\
return messages\
end\
bm["values"] = bm_values()\
bm["localized"] = bm_msgs()\
return bm\
end\
data.bm = data_bm()

/^local savecookie *= *{}/a \
if box.post.linux_fs_start then\
local linux_fs_start = string.gsub(box.post.linux_fs_start, "'", "")\
local branding = box.post[linux_fs_start.."_branding"] ~= nil and string.gsub(box.post[linux_fs_start.."_branding"], "'", "") or ""\
local service = io.open("/var/run/bootmanager/input","w")\
if service then\
service:write("switch_to "..linux_fs_start.." "..branding.."\\n")\
service:close()\
else\
os.execute("/usr/bin/bootmanager switch_to '"..linux_fs_start.."' '"..branding.."'")\
end\
end
