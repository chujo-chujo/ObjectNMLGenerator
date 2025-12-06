--[[
This module manages user preferences and application settings, providing both
persistent storage and a graphical interface for configuration.

Main Components:
- Helper Functions:
	* value_to_number(value): Converts "0"/"1" string values to numbers.
	* toggle_to_num(state): Converts toggle state ("ON"/"OFF") to numeric (1/0).
	* num_to_toggle(num): Converts numeric values back to toggle state strings.
- config.load_settings():
	Loads saved settings from "settings.ini" into the global `settings` table.
- save_settings():
	Updates the `settings` table from UI toggle states and writes them to
	"settings.ini".
- UI Elements:
	Defines toggle controls for preferences (e.g., confirm dialogs, remembering
	last used folder/filename) using the IUP GUI toolkit.
- config.dlg_settings:
	Main settings dialog window containing all toggles and OK/Cancel buttons,
	with keyboard shortcuts for closing or saving.
]]

local config = {}


---------------------------------------------
-- GLOBAL VARIABLES
---------------------------------------------
-- Default settings, overriden if 'settings.ini' is loaded:
settings = {
	last_used_folder = default_path,
	last_export_filename = "generated.nml",

	menu_path_to_openttd = os.getenv("USERPROFILE") .. "\\Documents\\OpenTTD\\newgrf",
	menu_copy_to_openttd = "OFF",
	menu_last_check_update = "1970-01-01",
	menu_auto_check_update = "ON",

	show_preview_file = {
		index = 1,
		state = "OFF",
		label = '  Show "File" preview on hover',
	},
	show_preview_snow = {
		index = 2,
		state = "OFF",
		label = '  Show "Snow" preview on hover',
	},
	show_preview_ground = {
		index = 3,
		state = "OFF",
		label = '  Show "Ground" preview on hover',
	},
	toggle_last_used_folder = {
		index = 4,
		state = "ON",
		label = "  Remember last used folder",
	},
	toggle_last_export_filename = {
		index = 5,
		state = "ON",
		label = "  Remember last export filename",
	},
	ask_exit = {
		index = 6,
		state = "ON",
		label = "  Confirm before closing",
	},
	ask_overwrite_object = {
		index = 7,
		state = "ON",
		label = "  Confirm before object overwrite",
	},
	ask_remove_object = {
		index = 8,
		state = "ON",
		label = "  Confirm object removal",
	},
	ask_reset = {
		index = 9,
		state = "ON",
		label = "  Confirm before resetting values",
	},
	ask_open = {
		index = 10,
		state = "ON",
		label = "  Confirm before opening YAML file",
	},
	ask_overwrite_nml = {
		index = 11,
		state = "ON",
		label = "  Confirm overwriting NML file",
	},
	warn_empty_header = {
		index = 12,
		state = "ON",
		label = "  Warn about missing GRF block fields",
	},
}

local table_of_toggles = {}



---------------------------------------------
-- FUNCTIONS
---------------------------------------------
function value_to_number(value)
	if value == "0" or value == "1" then
		return tonumber(value)
	else
		return value
	end
end

function toggle_to_num(state)
	if state == "OFF" then
		return 0
	else
		return 1
	end
end

function num_to_toggle(num)
	if num == 0 then
		return "OFF"
	else
		return "ON"
	end
end

function config.load_settings()
	-- Reads settings from file
	local file, err = io.open("settings.ini", "r")
	if not file then
		return
	end
	-- Update "settings" variable
	for line in file:lines() do
		local key, value = line:match("^%s*(.-)%s*=%s*(.-)%s*$")
		if key and value then
			if (value == "ON" or value == "OFF") and not helpers.startswith(key, "menu_") then
				settings[key].state = value
			else
				settings[key] = value
			end
		end
	end

	file:close()
end

function config.save_settings()
	-- Update "settings" variable and write to file
	local file = io.open("settings.ini", "w")
	if file then
		-- Reset "last_used" values, if their toggles 'OFF'
		if settings.toggle_last_used_folder.state == "OFF" then
			settings.last_used_folder = default_path
		end
		if settings.toggle_last_export_filename.state == "OFF" then
			settings.last_export_filename = "generated.nml"
		end

		-- Sort keys alphabetically
		local keys = {}
		for k, _ in pairs(settings) do
			keys[#keys + 1] = k
		end
		table.sort(keys)

		-- for k, v in pairs(settings) do
		for _, k in ipairs(keys) do
			v = settings[k]
			-- If not 'table', then save strings of "last_used" directly
			if type(v) ~= "table" then
				file:write(string.format("%s=%s\n", k, v))
			end
			if type(v) == "table" then
				-- If toggles are defined (Settings GUI was opened), iterate over and pair their values,
				-- else save just 'settings' directly
				if #table_of_toggles > 0 then
					for i = 1, #table_of_toggles do
						if v.index == i then
							v.state = table_of_toggles[i].value
							file:write(string.format("%s=%s\n", k, v.state))
						end
					end
				else
					file:write(string.format("%s=%s\n", k, v.state))
				end
			end
		end
		file:close()
	end
	return iup.DEFAULT
end



---------------------------------------------
-- GUI SETUP
---------------------------------------------
function config.build_settings_gui()
	local hbox_margin = "x6"

	for _, v in pairs(settings) do
		if v.index then
			table_of_toggles[v.index] = iup.toggle{title = v.label, value = v.state}
		end
	end

	local btn_OK = iup.button{
		title = "OK",
		rastersize = "50x35",
		expand = "HORIZONTAL",
		action = function()
			config.save_settings()
			return iup.CLOSE
		end
	}
	iup.SetAttribute(btn_OK, "FONTSTYLE", "Bold")
	local btn_Cancel = iup.button{
		title = "Cancel",
		rastersize = "50x35",
		expand = "HORIZONTAL",
		action = function()
			return iup.CLOSE
		end
	}
	local hbox_buttons = iup.hbox{
		btn_OK,
		iup.fill{rastersize = "10x", expand = "HORIZONTAL"},
		btn_Cancel,
		margin = hbox_margin
	}

	local vbox_settings = iup.vbox{}
	for _, v in ipairs(table_of_toggles) do
		vbox_settings:append(iup.hbox{v, margin = hbox_margin})
	end
	vbox_settings:append(iup.fill{rastersize = "x10"})
	vbox_settings:append(iup.label{separator = "HORIZONTAL", expand = "HORIZONTAL"})
	vbox_settings:append(iup.fill{rastersize = "x5"})
	vbox_settings:append(hbox_buttons)
	vbox_settings.margin = "20x10"

	local img_favicon = iup.LoadImage("gui/icon(48x48).png")
	dlg_settings = iup.dialog{
		vbox_settings,
		title = "Settings",
		resize = "NO",
		maxbox = "NO",
		icon = img_favicon,
		parentdialog = iup.GetDialog(dlg),
	}
	function dlg_settings:k_any(key)
		if key == iup.K_cQ then
			return iup.CLOSE
		elseif key == iup.K_ESC then
			return iup.CLOSE
		elseif key == iup.K_CR then
			config.save_settings()
			return iup.CLOSE
		end
	end

	dlg_settings:popup(iup.CENTERPARENT, iup.CENTERPARENT)
end


return config