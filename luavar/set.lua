#! /bin/luavar
-- SPDX-License-Identifier: GPL-2.0-or-later

lineno = 0;
rc = 0;
cmtable = {};

while true do
	local line = io.read("*line");
	if (line == nil) then
		if (lineno == 0) then
			io.stderr:write("Missing set statements\n");
			os.exit(2);
		else
			break;
		end
	end
	lineno = lineno + 1;
	local varname, value = string.match(line, "(.*)=(.*)");
	if (varname ~= nil and value ~= nil) then
		table.insert(cmtable, { ["name"] = varname, ["value"] = value } );
	else
		io.stderr:write("Malformed set statement at line ",lineno,"\n");
		os.exit(127);
	end
end

err = 0;
message = "";
err, message = box.set_config(cmtable);
if (err == 0) then
	io.stderr:write("OK\n");
	rc = 0;
else
	if (string.len(message) > 0) then	
		io.stderr:write(message,"\n");
	else
		io.stderr:write("error\n");
	end
	rc = 1;
end

os.exit(rc);
