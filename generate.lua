text_nml = iup.text{
	rastersize = "x25",
	value = settings.last_export_filename,
	expand = "HORIZONTAL"
}
local text_nml_centered = iup.vbox{
	iup.fill{},
	text_nml,
	iup.fill{},
	expand = "YES",
	margin = "0x0"
}

local btn_generate = iup.button{
	title = "Generate NML   ",
	image = img_icon_NML,
	rastersize = "180x35",
}
iup.SetAttribute(btn_generate, "FONTSTYLE", "BOLD")

function btn_generate:action(from_compile)
	if helpers.trim(text_nml.value) == "" then
		return 0
	end

	if check_empty_header() then return 0 end
	local status = update_table_with_header()
	if not status then
		return 0
	end

	local from_compile = from_compile or false

	filename_nml = text_nml.value
	if not filename_nml:lower():match("%.nml$") then
		filename_nml = filename_nml .. ".nml"
	end

	if settings.ask_overwrite_nml.state == "ON" then
		if helpers.file_exists("../" .. filename_nml) then
			local response = show_message("WARNING",
				"Warning", '  File "' .. filename_nml ..'" already exists.\n  Do you want to overwrite it?', "OKCANCEL")
			if response == 2 then
				return 0
			end
		end
	end

	-- Check if the "gfx" folder exists
	if not helpers.dir_exists("../gfx") then
		helpers.make_dir("../gfx")
		show_message("INFORMATION", "Warning",
			"  Couldn't find the GFX folder.\n\n" .. 
			"  All used sprites have to be in the GFX folder next to the .NML file\n" ..
			"  and the LANG folder to be successfully compiled.", "OK")
	end

	local NML, LANG = nml:generate_nml()

	local ok, err = pcall(nml.write_NML_to_file, filename_nml, NML, LANG)
	if not ok then
		show_message("ERROR", "Error", "Export canceled.\nERROR:\n" .. err, "OK")
		return 0
	else
		if not helpers.file_exists("../gfx/ground.png") then
			local im_image = create_image.ground_png()
			im.FileImageSave("../gfx/ground.png", "PNG", im_image)
		end
		if not helpers.file_exists("../gfx/empty_pixel.png") then
			local im_image = create_image.empty_png()
			im.FileImageSave("../gfx/empty_pixel.png", "PNG", im_image)
		end
		if not from_compile then
			show_message("INFORMATION", "", "  NML export successful!", "OK")
		end
	end

	if settings.toggle_last_export_filename.state == "ON" then
		settings.last_export_filename = filename_nml
	end

	return iup.DEFAULT
end

local btn_compile = iup.button{
	title = "Generate && Compile   ",
	image = img_icon_compile,
	rastersize = "180x35",
}
iup.SetAttribute(btn_compile, "FONTSTYLE", "BOLD")

function btn_compile.action()
	if not is_nmlc() then
		return iup.DEFAULT
	end

	-- Multiline text to show console output
	local console = iup.text{
		multiline = "YES",
		readonly  = "YES",
		expand    = "YES",
		scrollbar = "YES",
		value     = "Compiling your code, please wait...",
		font      = "Courier, 10",
	}

	local label_console = iup.label{title = "NMLC output:"}
	iup.SetAttribute(label_console, "FONTSTYLE", "BOLD")

	local btn_console_close = iup.button{
		image = img_icon_close,
		title = " Close (ESC)",
		rastersize = "220x30",
	}
	function btn_console_close.action() return iup.CLOSE end
	iup.SetAttribute(btn_console_close, "FONTSTYLE", "BOLD")
	
	local x = iup.GetAttribute(dlg, "X")
	local height = 450
	local dlg_width, dlg_height = string.match(iup.GetAttribute(dlg, "RASTERSIZE"), "(%d+)x(%d+)")
	local y = iup.GetAttribute(dlg, "Y") + dlg_height - height

	local dlg_console = iup.dialog{
		iup.vbox{
			iup.hbox{
				label_console,
				iup.fill{},
				btn_console_close,
				margin = "10x0",
				alignment = "ACENTER",
			},
			console,
			margin = "10x10",
			gap = "10",
		},
		border  = "YES",
		maxbox  = "NO",
		minbox  = "NO",
		menubox = "NO",
		resize  = "NO",
		title   = nil,
		background   = "209 210 222",
		-- background   = "193 194 212",
		rastersize   = dlg_width .. "x" .. height,
		parentdialog = iup.GetDialog(dlg),
	}
	function dlg_console:k_any(key)
		if key == iup.K_cQ or key == iup.K_ESC then
			return iup.CLOSE
		end
	end

	dlg_console:showxy(x, y)

	-- Perform NML generation (use "action" from "Genrate" button)
	local status = btn_generate:action(true)
	if status == 0 then
		show_message("ERROR", "Error", "  NML export unsuccessful,\n  compilation canceled.", "OK")
		console.value = "Compilation has been canceled."
		dlg_console:popup(x, y)
		return iup.DEFAULT
	end

	-- Capture CLI stdout + stderr from NMLC compiler
	-- (" 2>&1" send standard error to where ever standard output is being redirected)
	local cmd = "cd .. && nmlc -c " .. filename_nml
	local pipe = io.popen(cmd .. " 2>&1")
	local output = pipe:read("*all")
	pipe:close()
	console.value = output

	dlg_console:popup(x, y)
end

local label_save_as = iup.label{title = "Save as:"}
iup.SetAttribute(label_save_as, "FONTSIZE", "8")
local label_save_as_centered = iup.vbox{
	iup.fill{},
	label_save_as,
	iup.fill{rastersize = "x8"},
	expand = "YES",
	margin = "0x0"
}

hbox_generate = iup.frame{
	iup.hbox{
		-- iup.label{title = "Save as:"},
		label_save_as_centered,
		text_nml_centered,
		btn_generate,
		btn_compile,
		alignment = "ACENTER"
	},
	title = " Export ",
	margin = "12x5",
	expand = "YES",
	gap = "10",
}