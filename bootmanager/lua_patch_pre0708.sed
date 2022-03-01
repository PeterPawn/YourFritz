/^local savecookie = {}/a \
if box.post.linux_fs_start then\
local linux_fs_start = string.gsub(box.post.linux_fs_start, "'", "")\
local branding = box.post[linux_fs_start.."_branding"] ~= nil and string.gsub(box.post[linux_fs_start.."_branding"], "'", "") or ""\
os.execute("/usr/bin/bootmanager switch_to '"..linux_fs_start.."' '"..branding.."'")\
end

/^<form action=.*>/a \
<div id="managed_reboot" class="reboot_managed">\
<?lua\
pipe = io.popen("/usr/bin/bootmanager_html")\
line = pipe:read("*a")\
pipe:close()\
box.out(line)\
?>\
</div>
