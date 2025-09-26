text_grfid = iup.text{
	mask = "[A-Z0-9\\]+",
	NC = 8,
	expand = "HORIZONTAL",
	tip = "Four-byte string\n(can use escaped bytes)"
}
text_version = iup.text{
	mask = "/d+",
	value = "0",
	spin = "YES",
	spinmin = "0",
	spininc = "1",
	expand = "HORIZONTAL"
}
text_min_comp_version = iup.text{
	mask = "/d+",
	value = "0",
	spin = "YES",
	spinmin = "0",
	spininc = "1",
	expand = "HORIZONTAL"
}
text_grf_name = iup.text{rastersize = "190x0"}
text_grf_url = iup.text{expand = "HORIZONTAL"}
text_grf_desc = iup.text{rastersize = "x55", multiline = "YES", wordwrap = "YES", expand = "HORIZONTAL"}

vbox_grf_block = iup.frame{
	iup.vbox{
		iup.hbox{
			iup.label{title = "Grf ID:", tip = "Four-byte string\n(can use escaped bytes)"},
			text_grfid,
			iup.fill{expand = "HORIZONTAL"},
			iup.label{title = "Version:"},
			text_version,
			iup.fill{expand = "HORIZONTAL"},
			iup.label{title = "Min. comp. version:"},
			text_min_comp_version,
			gap = "10"
		},
		iup.hbox{
			iup.label{title = "NewGRF name:"},
			text_grf_name,
			iup.label{title = "NewGRF url:"},
			text_grf_url,
			gap = "10"
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