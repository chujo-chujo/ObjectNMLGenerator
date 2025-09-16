local btn_new  = iup.button{
	image = img_icon_new,
	flat = "YES",
	action = function() new_list() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "New list (Ctrl+N)"}
local btn_open = iup.button{
	image = img_icon_open,
	flat = "YES",
	action = function() open_file() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Open list (Ctrl+O)"}
local btn_save = iup.button{
	image = img_icon_save,
	flat = "YES",
	action = function() save_list() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Save list as (Ctrl+S)"}
local btn_settings = iup.button{
	image = img_icon_settings,
	flat = "YES",
	action = function() show_settings() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Settings (Ctrl+K)"}
local btn_help = iup.button{
	image = img_icon_help,
	flat = "YES",
	action = function() show_help() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Manual (Ctrl+H, F1)"}

hbox_toolbar = iup.hbox{
	btn_new,
	btn_open,
	btn_save,
	iup.label{separator = "VERTICAL"},
	btn_settings,
	iup.fill{},
	btn_help,
	margin = "5x5",
	gap = 2,
}