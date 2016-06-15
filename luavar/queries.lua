#! /bin/luavar

lineno = 0;
rc = 0;

while true do
	local line = io.read("*line");
	if (line == nil) then 
		if (lineno == 0) then
			io.stderr:write("Missing requests\n");
			os.exit(2);
		end
		break; 
	end
	lineno = lineno + 1;
	local varname, query = string.match(line, "(.*)=(.*)");
	if (varname ~= nil and query ~= nil) then
		if (string.find(query, "%(.*%)") == nil) then
			local single_res = box.query(query);
			if (single_res == nil) then 
				print(varname.."=\"***no result***\"");
				rc = 1;
			else
				print(varname.."=\""..single_res.."\"");
			end
		else	
			local columns = {};
			local first, last = string.find(query, "%(.*%)");
			local list = string.sub(query, first + 1, last - 1);
			for col in string.gmatch(list, "[^,]+") do
				table.insert(columns, col);
			end
			if (string.find(query, "listwindow%(.*%)") ~= nil) then
				table.remove(columns, 1);
				table.remove(columns, 1);
			end
			local result = box.multiquery(query);
			local index = 0;
			for i, entry in ipairs(result) do
				for j, value in ipairs(entry) do
					j = j - 1;
					if (j > 0) then
						colname = columns[j];
					else
						colname = "index";
					end
					print(varname.."_"..i.."_"..colname.."=\""..value.."\"");
				end
				index = i;
			end
			print(varname.."_count="..index);
		end
	else
		io.stderr:write("Malformed request at line ",lineno,"\n");
		rc = 127;
-- die folgende Zeile aktivieren (-- am Beginn entfernen), um bei falscher Eingabe die Verarbeitung abzubrechen
--		break;
	end
end

os.exit(rc);
