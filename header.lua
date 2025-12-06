local textbox_width = "123x"
text_grfid = iup.text{
	mask = "[A-Z0-9\\]+",
	NC = 12,
	rastersize = textbox_width,
	tip = "Four-byte string\n(can use escaped bytes)"
}
text_version = iup.text{
	mask = "/d+",
	value = "0",
	spin = "YES",
	spinmin = "0",
	spininc = "1",
	rastersize = textbox_width,
}
text_min_comp_version = iup.text{
	mask = "/d+",
	value = "0",
	spin = "YES",
	spinmin = "0",
	spininc = "1",
	rastersize = textbox_width,
}
text_grf_name = iup.text{rastersize = "190x0"}
text_grf_url = iup.text{expand = "HORIZONTAL"}
text_grf_desc = iup.text{rastersize = "x55", multiline = "YES", wordwrap = "YES", expand = "HORIZONTAL"}

btn_random_grfid = iup.flatbutton{
	image = img_icon_random,
	rastersize = "30x25",
	tip = "Generate random Grf ID"
}
function btn_random_grfid:flat_action()
	local grfid = ""
	for i = 1, 4 do
		grfid = grfid .. string.format("\\%02X", math.random(0, 255))
	end
	text_grfid.value = grfid
end


vbox_grf_block = iup.frame{
	iup.vbox{
		iup.hbox{
			iup.hbox{
				iup.label{title = "Grf ID:", tip = "Four-byte string\n(can use escaped bytes)"},
				iup.fill{rastersize = "10"},
				text_grfid,
				iup.fill{rastersize = "5"},
				btn_random_grfid,
				margin = "0x0",
				gap = "0",
				alignment = "ACENTER",
			},
			iup.fill{expand = "HORIZONTAL"},
			iup.label{title = "Version:"},
			text_version,
			iup.fill{expand = "HORIZONTAL"},
			iup.label{title = "Min. comp. version:"},
			text_min_comp_version,
			gap = "10",
			alignment = "ACENTER",
		},
		iup.hbox{
			iup.label{title = "NewGRF name:"},
			text_grf_name,
			iup.label{title = "NewGRF url:"},
			text_grf_url,
			gap = "10",
			alignment = "ACENTER",
		},
		iup.hbox{
			iup.label{title = "NewGRF description:"},
			text_grf_desc,
			gap = "10"
		}
	},
	title = " GRF block ",
	margin = "5x5"
}