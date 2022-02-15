/^return data$/i \
local function data_bootmanager()\
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
local msgs = io.open("/usr/bin/bootmanager.msg")\
for line in msgs.lines() do\
table.insert(messages, { id = line:match("^([^=]-)="), value = line:match("^.-=\\"?(.-)\\"?$") } )\
end\
msgs:close()
local bootmanager = {}\
table.insert(bootmanager, { name = "values", obj = values })\
table.insert(bootmanager, { name = "messages", obj = messages })\
return bootmanager\
end\
\
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
