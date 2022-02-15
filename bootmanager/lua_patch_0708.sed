/^return data$/i \
local function data_bootmanager()\
local bootmanager = {}\
local line\
local values = {}\
local service = io.open("/var/run/bootmanager/output")\
if service then\
for line in service:lines() do\
table.insert(values, { id = line:match("^([^=]-)="), value = line:match("^.-=\\"?(.-)\\"?$") } )\
end\
table.insert(values, { id = "hasService", value = "1" } )\
service:close()\
else\
local pipe = io.popen("/usr/bin/bootmanager get_values")\
for line in pipe:lines() do\
table.insert(values, { id = line:match("^([^=]-)="), value = line:match("^.-=\\"?(.-)\\"?$") } )\
end\
table.insert(values, { id = "hasService", value = "0" } )\
pipe:close()\
end\
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
else\
lang, id, value = line:match("^([^:]-):([^=]-)=(.-)$")\
if lang and id and value then\
if usedLanguage == lang or "any" == lang then\
table.insert(messages, { id = id, value = string.gsub(value, "\\\\n", "\\n"), lang = lang } )\
end\
end\
end\
end\
end\
msgs:close()\
table.insert(bootmanager, {name = "values", obj = values})\
table.insert(bootmanager, {name = "messages", obj = messages})\
return bootmanager\
else\
local empty = {}\
return empty\
end\
end\
data.bootmanager = data_bootmanager()

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
