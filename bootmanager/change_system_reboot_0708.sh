#! /bin/sh
[ -z "$1" ] && printf "Missing name of file as parameter, the file will be changed in place.\n" 1>&2 && exit 1
! [ -f "$1" ] && printf "File '%s' not found.\n" "$1" 1>&2 && exit 1
sed -e "
/^local function on_load()/i\\
local function data_bootmanager()\\
local values = {}\\
local pipe = io.popen(\"/usr/bin/gui_bootmanager get_values\")\\
local line\\
for line in pipe:lines() do\\
table.insert(values, { name = line:match(\"^([^=]-)=\"), value = line:match(\"^.-=(.*)\") } )\\
end\\
pipe:close()\\
return values\\
end
/^data.actions = data_actions()/a\\
data.bootmanager = data_bootmanager()
/^local savecookie/a\\
if box.post.linux_fs_start then\\
local linux_fs_start = string.gsub(box.post.linux_fs_start, \"'\", \"\")\\
local branding = box.post[linux_fs_start..\"_branding\"] ~= nil and string.gsub(box.post[linux_fs_start..\"_branding\"], \"'\", \"\") or \"\"\\
os.execute(\"/usr/bin/gui_bootmanager switch_to '\"..linux_fs_start..\"' '\"..branding..\"'\")\\
end
" -i "$1"
