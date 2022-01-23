/^return data$/i \
local function data_bootmanager()\
local values = {}\
local messages = {}\
local line\
local pipe = io.popen("/usr/bin/gui_bootmanager get_values")\
for line in pipe:lines() do\
table.insert(values, { id = line:match("^([^=]-)="), value = line:match("^.-=\\"?(.-)\\"?$") } )\
end\
pipe:close()\
local msgs = io.open("/usr/bin/gui_bootmanager.msg")\
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

/^local savecookie = {}/a \
if box.post.linux_fs_start then\
local linux_fs_start = string.gsub(box.post.linux_fs_start, "'", "")\
local branding = box.post[linux_fs_start.."_branding"] ~= nil and string.gsub(box.post[linux_fs_start.."_branding"], "'", "") or ""\
os.execute("/usr/bin/gui_bootmanager switch_to '"..linux_fs_start.."' '"..branding.."'")\
end
