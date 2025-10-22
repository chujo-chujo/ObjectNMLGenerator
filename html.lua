--[[
This module provides functionality for exporting project data into HTML (.html)
or Markdown (.md) files, suitable for distribution or documentation. It dynamically
generates formatted content based on metadata and object definitions stored
within the app (not the YAML files!).

The generated output includes general NewGRF information (name, version, etc.)
and detailed listings of individual objects grouped by class, 
each with dimensions, snow variant, color depth, and preview images.

Main public function:
- html.create_file(type)
	Creates either an HTML or Markdown export file from the current project data.
	- If type == "HTML", converts the Markdown to an HTML file, embeds all images, 
	  and applies predefined styling.
	- If type == "MD", writes the generated Markdown content to disk.

Supporting internal functions:
- header_to_md()
	Constructs the Markdown-formatted header section containing general project 
	metadata and statistics.
- reorder_table_of_objects(table_of_objects)
	Reorganizes raw object data into a hierarchical table grouped by class.
- objects_to_md(objects_data)
	Converts structured object data into Markdown sections with image previews and 
	object attributes.
- md_to_file(md_string, filename)
	Writes Markdown text to a file with the specified name.
]]


---------------------------------------------
-- LOCAL UTILITY FUNCTIONS
---------------------------------------------

local function header_to_md()
	local string_grfid = text_grfid.value
	local string_version = text_version.value
	local string_min_comp_version = text_min_comp_version.value
	local string_grf_name = text_grf_name.value
	local string_grf_desc = text_grf_desc.value
	local string_url = text_grf_url.value

	-- Replace NewGRF newlines with HTML newlines
	string_grf_desc = string_grf_desc:gsub("{}", "<br>"):gsub("\n", "<br>"):gsub("{%a+}", "")

	-- Calculate the number of "objects" (it's actually "views")
	local total_objects = 0
	for _, obj in ipairs(table_of_objects) do
		total_objects = total_objects + tonumber(obj.views)
	end

	local header_string = string.format("# %s\n%s\n\n%s\n%s\n%s\n%s\n\n",
		string_grf_name .. "\n",
		string_grf_desc .. "\n",
		"- **Grfid:** " .. string_grfid,
		"- **Version:** " .. string_version,
		"- **Min. comp. version:** " .. string_min_comp_version,
		"- **Number of objects:** " .. tostring(total_objects),
		"- **www:** [](" .. string_url .. ")"
	)

	return header_string
end

function reorder_table_of_objects(table_of_objects)
	-- Loads data from 'table_of_objects' and reorders them to be grouped by classes, i.e.:
	-- {
	--   class = "...",
	--   classname = "...",
	--   data = { {...}, {...} }
	-- }

	local result = {}
	local lookup = {}

	for _, object in ipairs(table_of_objects) do
		local class_key = object.class
		local classname = object.classname

		-- If class is new, create new class key
		if not lookup[class_key] then
			local class_entry = {
				class = class_key,
				classname = classname,
				data = {}
				}
			table.insert(result, class_entry)
			lookup[class_key] = class_entry
		end

		-- Add table of properties to the class key
		local entry = {
			name = object.name,
			filename = object.file,
			Xdim = object.Xdim,
			Ydim = object.Ydim,
			bpp = object.bpp,
			views = object.views,
			snow = object.snow
		}

		table.insert(lookup[class_key].data, entry)
	end

	return result
end

local function objects_to_md(objects_data)
	-- Translates object data (grouped by classes!) into MD formatted strings
	local objects_string = {}

	for _, class_key in ipairs(objects_data) do
		table.insert(objects_string, string.format('## %s (%s)\n\n', class_key.classname, class_key.class))
		for _, data in ipairs(class_key.data) do
			-- Dimensions string based on views
			local dimensions = ""
			if tonumber(data.views) == 4 then
				dimensions = data.Xdim .. "×" .. data.Ydim .. ", " .. data.Ydim .. "×" .. data.Xdim .. ", " .. data.Xdim .. "×" .. data.Ydim .. ", " .. data.Ydim .. "×" .. data.Xdim
			elseif tonumber(data.views) == 2 then
				dimensions = data.Xdim .. "×" .. data.Ydim .. ", " .. data.Ydim .. "×" .. data.Xdim
			elseif tonumber(data.views) == 1 then
				dimensions = data.Xdim .. "×" .. data.Ydim
			end

			-- Snow string (Yes/No)
			local snow = tostring(data.snow) == "ON" and "Yes" or "No"

			table.insert(objects_string, string.format('### %s\n%s\n%s\n%s\n%s\n%s\n\n',
				data.name .. "\n",
				'<img style="margin-left: 1em;" src="gfx/' .. data.filename .. '" alt="' .. data.name .. '"/>\n',
				'- **Filename:** ' .. data.filename,
				'- **Dimensions:** ' .. dimensions,
				'- **Snow variant:** ' .. snow,
				'- **Color depth:** ' .. data.bpp .. ' bpp'
				))
		end
	end

	return table.concat(objects_string)
end

local function md_to_file(md_string, filename)
	local md_file, err = io.open(filename .. ".md", "w")
	if not md_file then
		iup.Message("Sum Ting Wong", err)
		return
	end
	md_file:write(md_string)
	md_file:close()
end


---------------------------------------------
-- PUBLIC FUNCTION
---------------------------------------------
local html = {}

function html.create_file(type)
	-- If type == "HTML" -> creates a temp MD file from object data, translates MD into HTML, deletes the temp file
	-- If type == "MD"   -> creates an MD file from object data
	local table_md_strings = {}

	table.insert(table_md_strings, header_to_md())
	table.insert(table_md_strings, objects_to_md(reorder_table_of_objects(table_of_objects)))

	-- Go up one level in directory tree
	local cwd = lfs.currentdir()
	lfs.chdir("..")

	-- local output_filename = helpers.generate_random_string(6)
	local string_grf_name = text_grf_name.value
	local output_filename = helpers.windows_safe_filename(string_grf_name)
	md_to_file(table.concat(table_md_strings), output_filename)

	if type == "HTML" then
		local cmd = '_files\\bin\\lua54 _files\\lib\\markdown.lua --title "' .. string_grf_name .. '" --style _files\\lib\\grf.css --inline-style "' .. output_filename .. '.md"'
		local pipe = io.popen(cmd .. " 2>&1")
		local output = pipe:read("*all")
		pipe:close()

		os.remove(output_filename .. ".md")

		if not helpers.file_exists(output_filename .. ".html") then
			show_message("ERROR", "Error", "  Could not create " .. output_filename .. ".html", "OK")
			return iup.DEFAULT
		end

		-- Embed images into HTML
		inliner = require("_files.lib.html_img_inliner")
		local new_html = inliner.inline_images_in_html(output_filename .. ".html")
		local out, err = io.open(output_filename .. ".html", "w")
		if not out then
			iup.Message("Sum Ting Wong", err)
			return
		end
	    out:write(new_html)
	    out:close()

		if helpers.file_exists(output_filename .. ".html") then
			show_message("INFORMATION", "Export successful", '  File "' .. output_filename .. '.html" has been successfully created.', "OK")
		end

	elseif type == "MD" then
		show_message("INFORMATION", "Export successful", '  File "' .. output_filename .. '.md" has been successfully created.', "OK")
	end

	-- Return CWD back into "_files"
	lfs.chdir(cwd)
end

return html