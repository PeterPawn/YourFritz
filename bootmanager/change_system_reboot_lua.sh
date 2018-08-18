#! /bin/sh
[ -z "$1" ] && printf "Missing name of file as parameter, the file will be changed in place.\n" 1>&2 && exit 1
! [ -f "$1" ] && printf "File '%s' not found.\n" "$1" 1>&2 && exit 1
sed -e "
/^local savecookie/a\\
if box.post.linux_fs_start then\\
local linux_fs_start = string.gsub(box.post.linux_fs_start, \"'\", \"\")\\
local branding = string.gsub(box.post[linux_fs_start..\"_branding\"], \"'\", \"\")\\
os.execute(\"/usr/bin/gui_bootmanager switch_to '\"..linux_fs_start..\"' '\"..branding..\"'\")\\
end
/^<form action/a\\
<div id=\"managed_reboot\" class=\"reboot_managed\">\\
<?lua\\
pipe = io.popen(\"/usr/bin/gui_bootmanager html_display\")\\
line = pipe:read(\"*a\")\\
pipe:close()\\
box.out(line)\\
?>\\
</div>
" -i "$1"
