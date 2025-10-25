btn_new  = iup.button{
	flat = "YES",
	action = function() new_list() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "New list (Ctrl+N)"}
btn_open = iup.button{
	flat = "YES",
	action = function() open_file() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Open list (Ctrl+O)"}
btn_save = iup.button{
	flat = "YES",
	action = function() save_list() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Save list as (Ctrl+S)"}
btn_html = iup.button{
	flat = "YES",
	action = function() export_html("HTML") return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Create HTML overview (Ctrl+P)"}
btn_settings = iup.button{
	flat = "YES",
	action = function() show_settings() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Settings (Ctrl+K)"}
btn_help = iup.button{
	flat = "YES",
	action = function() show_help() return iup.DEFAULT end,
	canfocus = "NO",
	tip = "Manual (Ctrl+H, F1)"}

local padding = "2x"

hbox_toolbar = iup.hbox{
	btn_new,
	btn_open,
	btn_save,
	iup.fill{rastersize = padding},
	iup.label{separator = "VERTICAL"},
	iup.fill{rastersize = padding},
	btn_html,
	iup.fill{rastersize = padding},
	iup.label{separator = "VERTICAL"},
	iup.fill{rastersize = padding},
	btn_settings,
	iup.fill{},
	btn_help,
	margin = "5x5",
	gap = 2,
}