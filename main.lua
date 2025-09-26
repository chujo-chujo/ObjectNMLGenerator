--[[
ObjectNMLGenerator, v1.1.0 (2025-09-26)
Author: chujo
License: CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0/)

You may use, modify, and distribute this script for non-commercial purposes only (attribution required).
Any modifications or derivative works must be licensed under the same terms.

This Lua module defines and initializes UI components such as buttons, labels, etc.,
and includes functions that interact with the main application logic.

The code is divided into separate files to improve readability:
- toolbar.lua
- header.lua
- list.lua

Additional functionality is modularized in:
- nml.lua
- helpers.lua
- chuyaml.lua
- create_image.lua
- settings.lua
-----------------------------------------------------------------------------------------------------------]]

require("iuplua")
require("iupluacontrols")
require("iupluaim")
local im = require("imlua")

nml = require("nml")
helpers = require("helpers")
local yaml = require("chuyaml")
local create_image = require("create_image")



---------------------------------------------
-- GLOBAL VARIABLES
---------------------------------------------
-- Default path is one level up from '_files'
local script_path = debug.getinfo(1, "S").source:match("@(.*\\)")
default_path = script_path:match("^(.*[\\/])[^\\/]+[\\/]$")
-- local current_path = arg[0]:match("(.+[\\/])")
config = require("settings")
config.load_settings()

table_of_objects = {}
-- TABLE STORING ALL DEFINITIONS OF OBJECTS FOLLOWS THIS STRUCTURE:
-- table_of_objects = {
-- 	[1] = {
-- 		file = "...",
-- 		name = "...",
-- 		classname = "..."
-- 	},
-- 	[2] = {
-- 		file = "...",
-- 		name = "...",
-- 		classname = "..."
-- 	},
-- 	-- and so on
-- }

table_with_header = {}
-- TABLE STORING GRF BLOCK INFO FOLLOWS THIS STRUCTURE:
-- table_with_header = {
-- 	header = {
-- 		grfid = "LOIP";
-- 		version = 0;
-- 		min_comp_version = 0;
-- 		grf_name = "Lorem Ipsum";
-- 		grf_url = "https://";
-- 		grf_desc = "Lorem ipsum";
-- 	}
-- }

preview_dialog = nil
preview_label = nil



---------------------------------------------
-- FUNCTIONS
---------------------------------------------
function close_app()
	if settings.ask_exit.state == "ON" then
		local response = show_message(
			"QUESTION",
			"", 
			"  Are you sure you want to exit?", 
			"OKCANCEL")
		if response == 1 then
			config.save_settings()
			return true
		else
			return false
		end
	else
		config.save_settings()
		return true
	end
end

reset_widgets = {
	header = function()
		table_with_header = {}
		text_grfid.value = ""
		text_version.value = 0
		text_min_comp_version.value = 0
		text_grf_name.value = ""
		text_grf_url.value = ""
		text_grf_desc.value = ""
	end,

	list = function()
		table_of_objects = {}
		list_objects.removeitem = "ALL"
	end,

	properties = function()
		text_file.value = ""
		text_width.value = ""
		text_height.value = ""
		text_bpp.value = ""

		toggle_snow.value = "OFF"
		text_file_snow.value = ""
		text_file_snow.active = "NO"
		btn_file_snow.active = "NO"

		list_ground.value = 1
		text_ground.value = "ground.png"
		text_ground.active = "YES"
		btn_ground.active = "YES"

		text_name.value = ""

		text_X_dimension.value = "1"
		text_Y_dimension.value = "1"
		rad_views.value = rad_btn_1

		text_class.value = ""
		text_classname.value = ""
	end,

	ALL = function()
		reset_widgets.header()
		reset_widgets.list()
		reset_widgets.properties()
	end
}

function update_header_widgets()
	text_grfid.value = table_with_header["header"].grfid
	text_version.value = table_with_header["header"].version
	text_min_comp_version.value = table_with_header["header"].min_comp_version
	text_grf_name.value = table_with_header["header"].grf_name
	text_grf_url.value = table_with_header["header"].grf_url
	text_grf_desc.value = table_with_header["header"].grf_desc
end

function update_object_list()
	-- Remove all previous items
	list_objects.removeitem = "ALL"
	-- Fill the object list with items
	for i = 1, #table_of_objects do
		list_objects[i] = i .. ": [" .. table_of_objects[i].class .. "] " .. table_of_objects[i].file
	end
end

function update_object_properties_widgets(index)
	subtable = table_of_objects[index]
	if subtable then
		text_file.value = subtable.file
		text_width.value = subtable.image_width
		text_height.value = subtable.image_height
		text_bpp.value = subtable.bpp

		toggle_snow.value = subtable.snow
		if subtable.snow ~= "ON" then
			text_file_snow.active = "NO"
			btn_file_snow.active = "NO"
		else
			text_file_snow.active = "YES"
			btn_file_snow.active = "YES"
		end
		text_file_snow.value = subtable.file_snow
		text_file_snow.bpp = subtable.bpp_snow

		list_ground.value = subtable.ground
		if tostring(subtable.ground) ~= "1" then
			text_ground.active = "NO"
			btn_ground.active = "NO"
		else
			text_ground.active = "YES"
			btn_ground.active = "YES"
		end
		text_ground.value = subtable.file_ground

		text_name.value = subtable.name
		text_X_dimension.value = subtable.Xdim
		text_Y_dimension.value = subtable.Ydim
		rad_views.value = rad_btn_map[helpers.trim(tostring(subtable.views))]
		text_class.value = subtable.class
		text_classname.value = subtable.classname
	end
end

function new_list()
	if settings.ask_reset.state == "ON" then
		local response = show_message("QUESTION", "Are you sure?", "  This will reset all fields.\n  Do you want to continue?", "OKCANCEL")
		if response == 1 then
			reset_widgets.ALL()
		end
	else
		reset_widgets.ALL()
	end
end

function open_file(filepath)
	if settings.ask_open.state == "ON" and #table_of_objects ~= 0 then
		local response = show_message("QUESTION", "Are you sure?", "  Opening a list will cause the loss of current data.\n  Do you want to continue?", "OKCANCEL")
		if response ~= 1 then
			return iup.DEFAULT
		end
	end

	if not filepath then
		-- Get default filepath = one level up from this script
		local file_dlg = iup.filedlg{
			dialogtype = "OPEN",
			directory  = settings.last_used_folder or default_path,
			filter     = "*.yaml",
			filterinfo = "YAML (*.yaml)",
		}
		file_dlg:popup(iup.ANYWHERE, iup.ANYWHERE)
		if file_dlg.status ~= "-1" then
			filepath = file_dlg.value
			if settings.toggle_last_used_folder.state == "ON" then
				settings.last_used_folder = helpers.get_directory(file_dlg.value)
			end
		else
			return iup.DEFAULT
		end
	end

	-- Load data as a multiline string
	local yaml_file, err = io.open(filepath, "r")
	if not yaml_file then
		show_message("ERROR", "Error", "  Could not open file: " .. filepath .. "\n  Error: " .. err, "OK")
		return
	end

	reset_widgets.ALL()
	local config_string = yaml_file:read("*all")
	yaml_file:close()
	table_of_objects = yaml.parse(config_string)
	table_with_header["header"] = table_of_objects["header"]
	table_of_objects["header"] = nil

	-- Update the header
	-- Convert one line string back to multiline newlines
	table_with_header["header"].grf_desc = tostring(table_with_header["header"].grf_desc):gsub("\\n", "\n")
	update_header_widgets()
	update_object_list()
end

function save_list()
	if check_empty_header() then return	end
	update_table_with_header()
	-- Convert multiline newlines into a one line string
	table_with_header["header"].grf_desc = table_with_header["header"].grf_desc:gsub("\n", "\\n")

	local file_dlg = iup.filedlg{
		dialogtype = "SAVE",
		directory  = settings.last_used_folder or default_path,
		file       = "list_of_objects.yaml",
		filter     = "*.yaml",
		filterinfo = "YAML (*.yaml)",
	}
	file_dlg:popup(iup.ANYWHERE, iup.ANYWHERE)
	if file_dlg.status ~= "-1" then
		filepath = file_dlg.value
		if not filepath:lower():match("%.yaml$") then
			filepath = filepath .. ".yaml"
		end
		if settings.toggle_last_used_folder.state == "ON" then
			settings.last_used_folder = helpers.get_directory(file_dlg.value)
		end
	else
		return iup.DEFAULT
	end

	-- Convert tables to YAML and write into a file
	local yaml_file = io.open(filepath, "w")

	local yaml_string = yaml.to_yaml(table_with_header)
	yaml_file:write(yaml_string .. "\n")
	
	yaml_string = yaml.to_yaml(table_of_objects)
	yaml_file:write(yaml_string)

	yaml_file:close()
end

function update_table_with_header()
	if helpers.trim(text_grf_url.value) ~= "" then
		if not helpers.startswith(text_grf_url.value, "https://") and not helpers.startswith(text_grf_url.value, "http://")  then
			show_message("WARNING", "Invalid URL", '  "NewGRF url" has to start with "https://" or "http://"!', "OK")
			return false
		end
	end
	table_with_header = {
		header = {
			grfid = text_grfid.value,
			version = text_version.value,
			min_comp_version = text_min_comp_version.value,
			grf_name = text_grf_name.value,
			grf_url = helpers.trim(text_grf_url.value),
			grf_desc = text_grf_desc.value
		}
	}
	return true
end

function get_image_info(filepath)
	local image = im.FileImageLoad(filepath, im.IM_UNKNOWN)
	if not image then
		show_message("ERROR", "Error", "  Failed to load image:\n" .. filepath, "OK")
		return nil
	end

	local image_width = image:Width()
	local image_height = image:Height()
	local bpp = "32"
	
	local color_space = image:ColorSpace()
	if color_space == im.MAP then
		bpp = "8"
	elseif color_space == im.RGB and not image:HasAlpha() then
		show_message("WARNING", "Check image color mode", filepath .. "\n is not indexed or is missing the alpha channel.", "OK")
		return {image_width, image_height, bpp}
	elseif color_space ~= im.RGB and color_space ~= im.MAP then
		show_message("WARNING", "Check image color mode", "Sprites can be only RGBA or Indexed.", "OK")
		return {image_width, image_height, bpp}
	end

	return {image_width, image_height, bpp}
end

function add_to_table_of_objects()
	if check_empty_obj_properties() then
		show_message("WARNING", "", "  All fields of the object's properties must be filled in.", "OK")
		return
	end

	local found = false
	local index = 0
	local filename = text_file.value
	for i = 1, #table_of_objects do
		if filename == table_of_objects[i]["file"] then
			found = true
			index = i
			break
		end
	end	

	local data = {
		file = text_file.value,
		image_width = text_width.value,
		image_height = text_height.value,
		bpp = text_bpp.value,

		snow = toggle_snow.value,
		file_snow = text_file_snow.value or nil,
		bpp_snow = text_file_snow.bpp or nil,

		ground = list_ground.value,
		file_ground = text_ground.value or nil,
		
		name = text_name.value,
		Xdim = text_X_dimension.value,
		Ydim = text_Y_dimension.value,
		views = rad_views.value.title,
		class = text_class.value,
		classname = text_classname.value
	}

	if found then
		local response = nil
		if settings.ask_overwrite_object.state ==  "ON" then
			response = show_message("QUESTION", "Existing Object", 
				"  '" .. filename .. "' is already assigned to an object.\n  Do you want to overwrite the object?", 
				"OKCANCEL")
		else
			response = 1
		end
		if response == 1 then
			table_of_objects[index] = data
		else
			return iup.DEFAULT
		end
	else
		table_of_objects[#table_of_objects+1] = data
	end
end

function check_empty_obj_properties()
	if	text_file.value == "" or
		(toggle_snow.value == "ON" and text_file_snow.value == "") or
		(list_ground.value == "1" and text_ground.value == "") or
		text_name.value == "" or
		text_class.value == "" or
		text_classname.value == "" then
		return true
	else
		return false
	end
end

function check_empty_header()
	if 	text_grfid.value == "" or
		text_version.value == "" or
		text_min_comp_version.value == "" or
		text_grf_name.value == "" or
		text_grf_desc.value == "" then
		if settings.warn_empty_header.state == "ON" then
			local response = iup.Alarm(
				"Missing field",
				"All fields in the 'GRF block' (except URL) must be filled in for the NML code to work.\n\n" .. 
				"Do you still want to continue?",
				"Continue anyway", "Cancel", nil)
			if response == 1 then
				return false
			else
				return true
			end
		else
			return true
		end
	else
		return false
	end
end

function show_help()
	local url = default_path .. "Manual.html"
	if not helpers.file_exists(url) then
		local response = show_message("QUESTION", "Help", "  The manual could not be found locally.\n  Would you like to open the online version?", "OKCANCEL")
		if response == 1 then
			url = "https://chujo-chujo.github.io/ObjectNMLGenerator/"
		else
			return iup.DEFAULT
		end
	end

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
end

function show_settings()
	config.build_settings_gui()
	return iup.DEFAULT
end

function remove_from_table_of_objects()
	local index = tonumber(list_objects.value)
	if index > 0 then
		table.remove(table_of_objects, index)
		update_object_list()
	end
end

function shift_item(tbl, index, direction)
	if table_of_objects == nil or #table_of_objects == 0 then
		return false
	end
	local length = #tbl

	if type(index) ~= "number" or index < 1 or index > length then
		return false
	end
	if direction ~= "up" and direction ~= "down" then
		return false
	end

	-- Determine target index (no wrapping)
	local target = (direction == "up") and (index - 1) or (index + 1)
	if target < 1 or target > length then
		return false
	end

	-- Swap items
	tbl[index], tbl[target] = tbl[target], tbl[index]
	return target
end

function enable_preview(self, text_widget, setting)
	function display_preview(self, text_widget)
		local img = nil

		if text_widget.value then
			img = iup.LoadImage(default_path .. "gfx\\" .. text_widget.value)
		else
			return
		end
		if img then
			local x_coordinate = iup.GetAttribute(self, "X")
			local y_coordinate = iup.GetAttribute(self, "Y")
			local width, _ = string.match(iup.GetAttribute(self, "RASTERSIZE"), "(%d+)x(%d+)")

			preview_label = iup.label{image = img}
			preview_dialog = iup.dialog{
				preview_label,
				border  = "NO",
				maxbox  = "NO",
				minbox  = "NO",
				menubox = "NO",
				resize  = "NO",
				title   = nil,
				parentdialog = iup.GetDialog(dlg),
				startfocus = dlg,
			}
			preview_dialog:showxy(x_coordinate + width + 70, y_coordinate - 5)
		end
	end

	self.button_cb = function(self, button, pressed, x, y, status)
		if (button == iup.BUTTON1 or button == iup.BUTTON3) and setting.state == "OFF" then
			if pressed == 1 then
				display_preview(self, text_widget)
			else
				if preview_dialog then
					preview_dialog:hide()
				end
			end
		end
	end

	self.enterwindow_cb = function(self)
		if setting.state == "ON" then
			display_preview(self, text_widget)
		end
	end

	self.leavewindow_cb = function(self)
		if preview_dialog then
			preview_dialog:hide()
		end
	end
end

function show_message(type, title, text, buttons)
	-- Wrapper function to display "iup.messagedlg"
	-- returns the number (as type NUMBER 1, 2 or 3) of the pressed button
	local msg = iup.messagedlg{
		dialogtype = type,
		title = title,
		value = text,
		buttons = buttons
	}
	msg:popup(iup.ANYWHERE, iup.ANYWHERE)
	return tonumber(msg.buttonresponse)
end



---------------------------------------------
-- GUI SETUP
---------------------------------------------
function build_gui()
	-------------------------------------------------------
	-- ICONS

	img_favicon    = iup.LoadImage("gui/icon(48x48).png")
	img_nmlc       = iup.LoadImage("gui/nmlc.exe.png")
	img_icon_new   = iup.LoadImage("gui/icon_new.png")
	img_icon_open  = iup.LoadImage("gui/icon_open.png")
	img_icon_save  = iup.LoadImage("gui/icon_save.png")
	img_icon_up    = iup.LoadImage("gui/icon_up.png")
	img_icon_down  = iup.LoadImage("gui/icon_down.png")
	img_icon_plus  = iup.LoadImage("gui/icon_plus.png")
	img_icon_minus = iup.LoadImage("gui/icon_minus.png")
	img_icon_NML   = iup.LoadImage("gui/icon_generate2.png")
	img_icon_NML_3 = iup.LoadImage("gui/icon_generate3.png")
	img_icon_help  = iup.LoadImage("gui/icon_help.png")
	img_preview    = iup.LoadImage("gui/eye_small2.png")
	img_icon_close = iup.LoadImage("gui/close.png")
	img_icon_compile  = iup.LoadImage("gui/icon_compile2.png")
	img_icon_settings = iup.LoadImage("gui/icon_settings.png")



	-------------------------------------------------------
	-- TOOLBAR

	require("toolbar")



	-------------------------------------------------------
	-- GRF BLOCK

	require("header")



	-------------------------------------------------------
	-- LIST OF OBJECTS

	require("list")
	


	-------------------------------------------------------
	-- OBJECT PROPERTIES

	-- List of ground tiles
	local ground = {
		"Custom...",
		"Grass",
		"Desert",
		"Desert 1/2",
		"Snow",
		"Snow 1/4",
		"Snow 2/4",
		"Snow 3/4",
		"Concrete",
		"Water",
		"Cleared"
	}
	-- Create a restoring map, associate label with value
	ground_map = {}
	for i, item in ipairs(ground) do ground_map[item] = i end

	list_ground = iup.list{
		dropdown = "YES",
		value = 1,
		visible_items = 12
	}
	for i, item in ipairs(ground) do list_ground[i] = item end

	function list_ground:action()
		if self.value ~= "1" then
			text_ground.active = "NO"
			btn_ground.active = "NO"
		else
			text_ground.active = "YES"
			btn_ground.active = "YES"
		end
	end

	-- Radio buttons for Number of views
	local rad_btn_1_title = "  1  "
	local rad_btn_2_title = "  2  "
	local rad_btn_4_title = "  4  "
	rad_btn_1 = iup.toggle{title=rad_btn_1_title}
	rad_btn_2 = iup.toggle{title=rad_btn_2_title}
	rad_btn_4 = iup.toggle{title=rad_btn_4_title}
	-- Create a restoring map, associate label with radiobuttons
	rad_btn_map = {
		[helpers.trim(rad_btn_1_title)] = rad_btn_1,
		[helpers.trim(rad_btn_2_title)] = rad_btn_2,
		[helpers.trim(rad_btn_4_title)] = rad_btn_4
	}
	rad_views = iup.radio{iup.hbox{rad_btn_1, rad_btn_2, rad_btn_4, gap = "10px"}, value=rad_btn_1}

	text_file      = iup.text{expand = "HORIZONTAL"}
	text_width     = iup.text{rastersize = "54x"}
	text_height    = iup.text{rastersize = "54x"}
	text_bpp       = iup.text{rastersize = "54x"}
	toggle_snow    = iup.toggle{title = "  Snow:", rastersize = "80x"}
	text_file_snow = iup.text{active = "NO", expand = "HORIZONTAL"}
	text_ground    = iup.text{expand = "HORIZONTAL", value = "ground.png"}
	text_name      = iup.text{expand = "HORIZONTAL"}
	text_class     = iup.text{expand = "HORIZONTAL", mask = "[A-Z0-9]+", NC = 4, tip = "String of 4 characters\n(allowed characters are A-Z, 0-9)"}
	text_classname = iup.text{expand = "HORIZONTAL"}
	text_X_dimension = iup.text{
		maskint = "1:15",
		value = "1",
		spin = "YES",
		spinmin = "1",
		spinmax = "15",
		spininc = "1",
		rastersize = "55x"
	}
	text_Y_dimension = iup.text{
		maskint = "1:15",
		value = "1",
		spin = "YES",
		spinmin = "1",
		spinmax = "15",
		spininc = "1",
		rastersize = "55x"
	}

	local label_preview_file = iup.label{image = img_preview}
	local label_preview_snow = iup.label{image = img_preview}
	local label_preview_ground = iup.label{image = img_preview}
	enable_preview(label_preview_file, text_file, settings.show_preview_file)
	enable_preview(label_preview_snow, text_file_snow, settings.show_preview_snow)
	enable_preview(label_preview_ground, text_ground, settings.show_preview_ground)

	-- File button and file dialog logic
	local current_path = debug.getinfo(1, "S").source:match("@(.*\\)")
	local gfx_path = current_path .. "../gfx"

	local btn_file = iup.button{title = "Browse..."}
	function btn_file.action()
		local file_dlg = iup.filedlg{
			dialogtype = "OPEN",
			directory  = settings.last_used_folder or gfx_path,
			filter     = "*.png", 
			filterinfo = "PNG (*.png)",
		}
		file_dlg:popup(iup.ANYWHERE, iup.ANYWHERE)
		if file_dlg.status ~= "-1" then
			text_file.full_path = file_dlg.value
			local filename, extension = file_dlg.value:match("([^/\\]+)%.([^.\\/]+)$")
			text_file.value = filename .. "." .. extension
			
			local data = get_image_info(text_file.full_path)
			if data then
				text_width.value = helpers.round(data[1])
				text_height.value = helpers.round(data[2])
				text_bpp.value = data[3]
			end
			if settings.toggle_last_used_folder.state == "ON" then
				settings.last_used_folder = helpers.get_directory(file_dlg.value)
			end
		end
		return iup.DEFAULT
	end

	btn_file_snow = iup.button{title = "Browse...", active = "NO"}
	function btn_file_snow.action()
		local file_dlg = iup.filedlg{
			dialogtype = "OPEN",
			directory  = settings.last_used_folder or gfx_path,
			filter     = "*.png", 
			filterinfo = "PNG (*.png)",
		}
		file_dlg:popup(iup.ANYWHERE, iup.ANYWHERE)
		if file_dlg.status ~= "-1" then
			text_file_snow.full_path = file_dlg.value
			local filename, extension = file_dlg.value:match("([^/\\]+)%.([^.\\/]+)$")
			text_file_snow.value = filename .. "." .. extension
			
			local data = get_image_info(text_file_snow.full_path)
			if data then
				text_file_snow.bpp = data[3]
			end

			if settings.toggle_last_used_folder.state == "ON" then
				settings.last_used_folder = helpers.get_directory(file_dlg.value)
			end
		end
		return iup.DEFAULT
	end

	btn_ground = iup.button{title = "Browse..."}
	function btn_ground.action()
		local file_dlg = iup.filedlg{
			dialogtype = "OPEN",
			directory  = settings.last_used_folder or gfx_path,
			filter     = "*.png", 
			filterinfo = "PNG (*.png)",
		}
		file_dlg:popup(iup.ANYWHERE, iup.ANYWHERE)
		if file_dlg.status ~= "-1" then
			local filename, extension = file_dlg.value:match("([^/\\]+)%.([^.\\/]+)$")
			text_ground.value = filename .. "." .. extension
			if settings.toggle_last_used_folder.state == "ON" then
				settings.last_used_folder = file_dlg.value
			end
		end
		return iup.DEFAULT
	end

	function toggle_snow:action()
		if self.value == "ON" then
			text_file_snow.active = "YES"
			btn_file_snow.active = "YES"
		else
			text_file_snow.value = ""
			text_file_snow.active = "NO"
			btn_file_snow.active = "NO"
		end
	end


	local btn_add_object = iup.button{
		title=" Add object     ",
		image = img_icon_plus,
		rastersize = "x35",
		expand = "HORIZONTAL"
	}
	iup.SetAttribute(btn_add_object, "FONTSTYLE", "Bold")
	function btn_add_object.action()
		add_to_table_of_objects()
		update_object_list()
		return iup.DEFAULT
	end

	local frame_properties = iup.frame{
		iup.vbox{
			iup.hbox{
				iup.label{title="File:", rastersize="80x"},
				text_file,
				label_preview_file,
				btn_file,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				iup.label{title="W - H - bpp:", rastersize="80x"},
				text_width,
				iup.label{title="  -  "},
				text_height, iup.label{title="  -  "},
				text_bpp,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				toggle_snow,
				text_file_snow,
				label_preview_snow,
				btn_file_snow,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				iup.label{title="Ground:", rastersize="80x"},
				list_ground,
				text_ground,
				label_preview_ground,
				btn_ground,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				iup.label{title="Name:", rastersize="80x"},
				text_name,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				iup.label{title="Dimensions:", rastersize="80x"},
				text_X_dimension, iup.label{title="    x    "},
				text_Y_dimension,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				iup.label{title="Views:", rastersize="80x"},
				rad_views,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				iup.label{title="Class:", rastersize="80x", tip="String of 4 characters\n(allowed characters are A-Z, 0-9)"},
				text_class,
				alignment="ACENTER"
			},
			iup.fill{},
			iup.hbox{
				iup.label{title="Classname:", rastersize="80x"},
				text_classname,
				alignment="ACENTER"
			},
			iup.hbox{btn_add_object},
			expand = "YES",
			gap = "0",
		},
		title = " Object properties ",
		margin = "6x4",
		-- gap = "0",
		expand = "YES",
	}

	hbox_objects = iup.hbox{
		frame_list,
		frame_properties,
		margin = "0x10",
		gap = "10",
		expand = "YES"
	}



	-------------------------------------------------------
	-- GENERATE

	require("generate")
	


	-------------------------------------------------------
	-- MAIN DIALOG WINDOW
	
	-- root frame of dlg
	vbox_main = iup.vbox{
		hbox_toolbar,
		vbox_grf_block,
		hbox_objects,
		hbox_generate,
		iup.fill{rastersize = "x10"},
		nmargin = "10x0",
	}

	dlg = iup.dialog{
		vbox_main,
		title = "Object NML for Those Who'd Rather Not",
		rastersize = "720x694",
		resize = "YES",
		maxbox = "NO",
		icon = img_favicon,
		dropfilestarget = "YES",
		dropfiles_cb = function(self, filepath, num, x, y) open_file(filepath) return iup.DEFAULT end,
		close_cb = function() if close_app() then return iup.CLOSE else return iup.IGNORE end end
	}

	function dlg:k_any(key)
		if key == iup.K_cQ or key == iup.K_ESC then
			if close_app() then return iup.CLOSE else return iup.IGNORE end
		elseif key == iup.K_cO then
			open_file()
			return iup.DEFAULT
		elseif key == iup.K_cN then
			new_list()
			return iup.DEFAULT
		elseif key == iup.K_cS then
			save_list()
			return iup.DEFAULT
		elseif key == iup.K_cK then
			show_settings()
		elseif key == iup.K_cH or key == iup.K_F1 then
			show_help()
			return iup.DEFAULT
		end
	end

	dlg:showxy(80, 30)

	if iup.MainLoopLevel() == 0 then
		iup.MainLoop()
		iup.Close()
	end
end


do
	build_gui()
end