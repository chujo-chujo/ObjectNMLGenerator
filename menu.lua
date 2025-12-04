-- TODO: Implement menu settings into the settings file or a separate storage?
local menu_settings = {}

local function create_menu(menu_string)
	local function trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
	-- 4 spaces = 1 tab
	menu_string = menu_string:gsub("    ", "\t")

	-- Split into lines
	local lines = {}
	for line in menu_string:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	-- Parse attributes inside {...}
	local function parse_attributes(attr_str)
		local attrs = {}
		attr_str = trim(attr_str)

		-- split by commas not inside quotes or parentheses
		local parts = {}
		local chunk, depth, quote = "", 0, nil
		for c in attr_str:gmatch(".") do
			if quote then
				chunk = chunk .. c
				if c == quote then quote = nil end
			elseif c == '"' or c == "'" then
				quote = c; chunk = chunk .. c
			elseif c == "(" then
				depth = depth + 1; chunk = chunk .. c
			elseif c == ")" then
				depth = depth - 1; chunk = chunk .. c
			elseif c == "," and depth == 0 then
				table.insert(parts, trim(chunk)); chunk = ""
			else
				chunk = chunk .. c
			end
		end
		if chunk ~= "" then table.insert(parts, trim(chunk)) end

		for _, pair in ipairs(parts) do
			local key, val = pair:match("^([%w_]+)%s*=%s*(.+)$")
			if key and val then
				val = trim(val)

				-- Quoted string
				if val:match('^".*"$') or val:match("^'.*'$") then
					attrs[key] = load("return " .. val)()

				-- Function call with args
				elseif val:match("^[%w_]+%s*%b()$") then
					local funcname, arglist = val:match("([%w_]+)%s*(%b())")
					local f = _G[funcname]
					if type(f) ~= "function" then
						error("Unknown function '" .. tostring(funcname) .. "' in attribute " .. key)
					end
					-- turn arguments into table constructor
					local inner = "return {" .. arglist:sub(2, -2) .. "}"
					local chunk, err = load(inner)
					if not chunk then
						error("Invalid argument list for " .. funcname .. ": " .. err)
					end
					attrs[key] = function()
						local ok, t = pcall(chunk)
						if not ok then error("Error evaluating args for " .. funcname .. ": " .. t) end
						return f(table.unpack(t))
					end

				-- Bare variable name
				elseif val:match("^[%w_]+$") then
					attrs[key] = _G[val]

				-- Anything else evaluate as Lua expression
				else
					local chunk = load("return " .. val)
					if chunk then
						local ok, result = pcall(chunk)
						attrs[key] = ok and result or val
					else
						attrs[key] = val
					end
				end
			end
		end
		return attrs
	end

	-- Parse lines into a structured tree
	local root = {level = -1, items = {} }
	local stack = {root}

	for _, raw_line in ipairs(lines) do
		if trim(raw_line) ~= "" then
			local level = select(2, raw_line:find("^\t*")) or 0
			local line = trim(raw_line)

			-- Extract attributes if present
			local title, attr_str = line:match("^(.-)%s*{%s*(.-)%s*}$")
			local attrs = {}
			if attr_str then
				title = trim(title)
				attrs = parse_attributes(attr_str)
			else
				title = line
			end

			local node = {level = level, title = title, attrs = attrs, items = {} }

			-- Adjust stack based on indentation
			while #stack > 0 and level <= stack[#stack].level do
				table.remove(stack)
			end
			table.insert(stack[#stack].items, node)
			table.insert(stack, node)
		end
	end

	-- Recursively build IUP structure
	local function build_items(nodes)
		local items = {}
		for _, node in ipairs(nodes) do
			if node.title == "SEPARATOR" then
				table.insert(items, iup.separator{})
			elseif #node.items > 0 then
				table.insert(items, iup.submenu{
					title = node.title,
					iup.menu(build_items(node.items))
				})
			else
				-- Convert escaped \t into a real tab character (IUP uses it for right alignment)
				local fixed_title = node.title:gsub("\\t", "\t")

				local item_attrs = {title = fixed_title}
				for k, v in pairs(node.attrs or {}) do item_attrs[k] = v end
				table.insert(items, iup.item(item_attrs))
			end
		end
		return items
	end

	return iup.menu(build_items(root.items))
end

function test_compiler()
	-- Go up one directory level to use NMLC
	local cwd = lfs.currentdir()
	lfs.chdir("..")

	if not is_nmlc() then
		lfs.chdir(cwd)
		return iup.DEFAULT
	else
		local cmd = "nmlc --version"
		local pipe = io.popen(cmd .. " 2>&1")
		local output = pipe:read("*all")
		pipe:close()

		local version = output:match("^(.-)\r?\n")
		local nmlc_path = output:match("nmlc:%s*(.-)\r?\n")

		show_message("INFORMATION", "NMLC", "  NML Compiler found!\n\n  Version: " .. version .. "\n  nmlc path: " .. nmlc_path .. ".exe", "OK")
	end
	
	-- Return CWD into "_files"
	lfs.chdir(cwd)
end

function check_updates()
	local label_checking_updates = iup.label{title = "Checking for updates..."}
	local msg_checking_updates = iup.dialog{
		iup.vbox{
			iup.fill{},
			iup.hbox{
				iup.fill{},
				label_checking_updates,
				iup.fill{},
			},
			iup.fill{},
		},
		parentdialog = iup.GetDialog(dlg),
		title = "",
		rastersize = "200x100",
		menubox = "NO",
		resize = "NO",
	}
	iup.SetAttribute(label_checking_updates, "FONTSTYLE", "Bold")
	msg_checking_updates:showxy(iup.CENTERPARENT, iup.CENTERPARENT)

	-- Create a hidden temporary dialog holding "iup.webbrowser" to extract the version number of the latest release
	-- To realize the web browser widget, a dialog needs to be realized; to realize the dialog without showing it, "iup.Map()" needs to be called
	local url = "https://github.com/chujo-chujo/ObjectNMLGenerator/releases/latest"
	local webbrowser = iup.webbrowser{}
	local webbrowser_dlg = iup.dialog{webbrowser, size = "0x0", visible = "NO"}

	webbrowser.value = url
	webbrowser.completed_cb = function(self, url)
		-- Called when a page successfully completed
		local regex = "<title>.*v(%d+%.%d+%.%d+).*"
		local version = self.html:match(regex)
		iup.Destroy(msg_checking_updates)

		if version ~= CURRENT_VERSION then
			local response = show_message(
				"QUESTION",
				"", 
				"  A newer version has been found.\n\n  Your version: " .. CURRENT_VERSION .. "\n  Latest release: " .. version .. "\n\n  Would you like to download it now?", 
				"OKCANCEL")
			if response == 1 then
				-- Windows
				if package.config:sub(1,1) == "\\" then
					os.execute('start "" "' .. url .. '"')
				-- macOS
				elseif io.popen("uname"):read("*l") == "Darwin" then
					os.execute('open "' .. url .. '"')
				-- Linux / BSD
				else
					os.execute('xdg-open "' .. url .. '"')
				end
				return iup.DEFAULT
			else
				return iup.DEFAULT
			end
		else
			show_message("INFORMATION", "", "  You are using the latest version (" .. CURRENT_VERSION .. ").", "OK")			
		end
		iup.Destroy(webbrowser_dlg)
	end

	webbrowser_dlg:map()
end

menu_string = [[
&Project
	&New\tCtrl+N {titleimage = img_icon_new_mini, action = new_list}
	&Open...\tCtrl+O {titleimage = img_icon_open_mini, action = open_file(nil)}
	&Save As...\tCtrl+S {titleimage = img_icon_save_mini, action = save_list}
	SEPARATOR
	Export
		As &HTML {titleimage = img_icon_html_mini, action = export_html("HTML")}
		As &MD {titleimage = img_icon_md_mini, action = export_html("MD")}
	SEPARATOR
	&Quit\tCtrl+Q, Esc {titleimage = img_icon_close, action = close_app}
&Compiler
	&Test compiler {titleimage = img_icon_test_compiler, action = test_compiler}
	Set &path to the OpenTTD "newgrf" folder... {active = "NO"}
	&Copy GRF after compiling? {autotoggle = "YES", value = "ON", active = "NO"}
Pr&eferences
	&Settings... {titleimage = img_icon_settings_mini, action = show_settings}
	SEPARATOR
	&Icons
		&Default {value = "ON", name = "toggle"}
		&Muted {active = "NO"}
&Help
	&Check for updates {titleimage = img_icon_update_mini, action = check_updates}
	Check for updates automatically (once a month)? {autotoggle = "YES", value = "OFF", active = "NO"}
	SEPARATOR
	&Manual {titleimage = img_icon_help_mini, action = show_help}
]]

menu_bar = create_menu(menu_string)

-- Add "WIP" tag to not yet functional items
function mark_wip_items(menu_bar)
	local child = iup.GetChild(menu_bar, 0)
	local i = 0
	while child do
		local child_type = iup.GetClassName(child)
		if child_type == "item" and child.active == "NO" and not child.title:find("^%[WIP%]%s") then
			child.title = "[WIP] " .. child.title
		elseif child_type == "submenu" then
			-- Recursively handle submenus
			local submenu = iup.GetChild(child, 0)
			if submenu then mark_wip_items(submenu) end
		end
		i = i + 1
		child = iup.GetChild(menu_bar, i)
	end
end
mark_wip_items(menu_bar)

-- Set the parent menu of named toggle items as a radiobutton menu
for _, name in ipairs{"toggle"} do
	local found_toggle = iup.GetDialogChild(menu_bar, name)
	if found_toggle then iup.GetParent(found_toggle).radio = "YES" end
end

