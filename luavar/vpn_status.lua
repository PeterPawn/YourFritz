#! /bin/luavar
-- SPDX-License-Identifier: GPL-2.0-or-later
--
-- Another simple example, how AVM's Lua variable interface can be used
--
-- This script reads the new state and the name of a defined VPN connection
-- from STDIN, tries to find the VPN connection with the specified name and
-- reports the current state and any changes (if needed) to the caller as
-- a single line of shell variable assignments, which may simply be 
-- 'eval'uated by the caller to get the results into own variables
--
local rc = 0;
local setstate;

local line = io.read("*line");
if (line == nil) then 
	rc = 1
end

local newstate, connection = string.match(line, "(.) (.*)");
if (connection == nil) then
	io.stderr:write("Missing connection name after new state value.\n\n");
	rc = 1;
end

if (newstate == "?") then
	setstate = 0;
else
	setstate = 1;
	if (newstate ~= "0" and newstate ~= "1") then
		rc = 1;
	end
end

if (rc == 1) then
	io.stderr:write("Usage:\n\techo \"state connection\" | vpn_connection.lua\n\n");
	io.stderr:write("Valid 'state' values are: 0 (deactivated), 1 (activated), ? (no change, query only)\n\n");
	io.stderr:write("'connection' has to be the name of an existing VPN connection.\n");
	os.exit(rc);
end

local columns = {};
local query = "vpn:settings/connection/list(name,activated)";
local result = box.multiquery(query);
for i, entry in ipairs(result) do
	if (entry[2] == connection) then
		local oldstate = entry[3];
		local name = entry[1];
		local output = "VPN_INDEX='"..name.."'\nVPN_NAME='"..connection.."'\nVPN_OLDSTATE="..oldstate;
		if (setstate == 1) then
			output = output.."\nVPN_NEWSTATE="..newstate;
			if (oldstate ~= newstate) then
				local cmtable = {};
				table.insert(cmtable, { ["name"] = "vpn:settings/"..name.."/activated", ["value"] = newstate } );
				local err = 0;
				local message = "";
				err, message = box.set_config(cmtable);
				output = output.."\nVPN_RESULT="..err;
				if (err ~= 0 and string.len(message) > 0) then
					output = output.."\nVPN_MESSAGE='"..message.."'";
				end
			end
		end
		print(output);
		os.exit(0);
	end
end

io.stderr:write("A VPN connection with name '"..connection.."' does not exist.\n");
os.exit(1);
