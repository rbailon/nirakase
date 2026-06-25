Name = "remmina"
NamePretty = "Remmina Connections"
Cache = false
HideFromProviderlist = false
SearchName = true
Icon = "🖥️"

local function ShellEscape(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function parse_remmina_file(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end

	local profile = {
		name = "",
		group = "",
		server = "",
		protocol = "",
		username = "",
	}

	for line in file:lines() do
		-- Remove trailing and leading spaces
		line = line:gsub("^%s*(.-)%s*$", "%1")
		if not line:match("^%[") and line:match("=") then
			local key, val = line:match("^([^=]+)=(.*)$")
			if key and val then
				key = key:gsub("^%s*(.-)%s*$", "%1")
				val = val:gsub("^%s*(.-)%s*$", "%1")
				if profile[key] ~= nil then
					profile[key] = val
				end
			end
		end
	end
	file:close()
	return profile
end

function GetEntries()
	local entries = {}
	local home = os.getenv("HOME")
	local remmina_dir = home .. "/.local/share/remmina"

	-- List all files in the directory
	local handle = io.popen("find -L '" .. remmina_dir .. "' -maxdepth 1 -name '*.remmina' 2>/dev/null")
	if handle then
		for file_path in handle:lines() do
			local profile = parse_remmina_file(file_path)
			if profile then
				-- Fallback name
				local display_name = profile.name
				if not display_name or display_name == "" then
					display_name = file_path:match("([^/]+)%.remmina$") or "Sin Nombre"
				end

				-- Determine protocol icon
				local icon = "remmina"
				local proto = profile.protocol:upper()
				if proto == "RDP" then
					icon = "remmina-rdp"
				elseif proto == "VNC" or proto == "GVNC" then
					icon = "remmina-vnc"
				elseif proto == "SSH" then
					icon = "utilities-terminal"
				elseif proto == "SFTP" then
					icon = "folder-remote"
				end

				-- Format subtext with enriched details
				local details = {}
				if proto ~= "" then
					table.insert(details, proto)
				end
				if profile.username ~= "" and profile.server ~= "" then
					table.insert(details, profile.username .. "@" .. profile.server)
				elseif profile.server ~= "" then
					table.insert(details, profile.server)
				end
				if profile.group ~= "" then
					table.insert(details, "[" .. profile.group .. "]")
				end

				local subtext = table.concat(details, "  •  ")

				table.insert(entries, {
					Text = display_name,
					Subtext = subtext,
					Icon = icon,
					Actions = {
						activate = "remmina -c " .. ShellEscape(file_path) .. " &",
					},
				})
			end
		end
		handle:close()
	end

	return entries
end
