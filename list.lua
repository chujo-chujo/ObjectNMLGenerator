list_objects = iup.list{
	dropdown = "NO",
	editbox = "NO",
	rastersize = "180x200",
	expand = "YES",
	action = function(self, text, index) update_object_properties_widgets(index) return iup.DEFAULT end,
}
function list_objects:k_any(key)
	if key == iup.K_DEL and settings.ask_remove_object.state == "ON" then
		btn_remove.action()
	end
end

local btn_shift_up = iup.button{
	image = img_icon_up,
	rastersize = "x35",
	expand = "HORIZONTAL",
	action = function()
		local new_index = shift_item(table_of_objects, tonumber(list_objects.value), "up")
		update_object_list()
		if new_index then list_objects.value = new_index end
	end
}

local btn_shift_down = iup.button{
	image = img_icon_down,
	rastersize = "x35",
	expand = "HORIZONTAL",
	action = function()
		local new_index = shift_item(table_of_objects, tonumber(list_objects.value), "down")
		update_object_list()
		if new_index then list_objects.value = new_index end
	end
}

btn_remove = iup.button{
	title=" Remove object",
	image = img_icon_minus,
	rastersize = "x35",
	expand = "HORIZONTAL"
}
function btn_remove.action()
	if settings.ask_remove_object.state == "ON" then
		local response = iup.Alarm(
			"Remove object", 
			"Are you sure?", 
			"Yes", "Cancel", nil)
		if response ~= 1 then
			return iup.DEFAULT
		end
	end
	
	remove_from_table_of_objects()
	reset_widgets.properties()
	return iup.DEFAULT
end

frame_list = iup.frame{
	iup.vbox{
		list_objects,
		iup.hbox{
			btn_shift_up,
			btn_shift_down,
			margin = "0x0",
		},
		btn_remove,
		expand = "YES",
		gap = "5",
	},
	title = " List of objects ",
	margin = "10x10",
	expand = "YES"
}