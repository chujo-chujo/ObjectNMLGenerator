--[[
This module provides functionality for generating NML (NewGRF Meta Language) code 
for OpenTTD object sets. It automates the creation of spritesets, spritelayouts, 
switch statements, and object definitions based on configuration data.

Main Components:
- Templates:
	Contains reusable string templates for NML headers, spritesets, layouts, 
	and item definitions, as well as a language template for GRF strings.
- nml:generate_nml() -> NML: string, LANG: string
	Generates NML code and accompanying language strings from object 
	definitions, handling different object sizes, multiple views, snow 
	variations, and ground sprites.
	Returns multiline strings 'NML' and 'LANG'.
- nml.write_NML_to_file(filename: string, NML: string, LANG: string):
	Writes the generated NML code and language strings to output files, 
	creating the required '.nml' and '.lng' files for use in OpenTTD.
]]

local nml = {}

---------------------------------------------
-- TEMPLATES
---------------------------------------------
nml.header = [[grf {
	grfid: "EDIT_GRFID";
	name: string(STR_GRF_NAME);
	desc: string(STR_GRF_DESC);
	url:  string(STR_GRF_URL);
	version: EDIT_VERSION;
	min_compatible_version: EDIT_COMPATIBLE_VERSION;
	param 0 {
		param_remove {
			name:      string(STR_PAR_REMOVE_NAME);
			desc:      string(STR_PAR_REMOVE_DESC);
			type:      bool;
			def_value: 0;
		}
	}
}

// GROUND
spriteset (spriteset_empty, ZOOM_LEVEL_NORMAL, BIT_DEPTH_32BPP, "gfx/empty_pixel.png") {[0, 0, 1, 1, 0, 0]}
]]

nml.spriteset_tmpl = 'spriteset(spriteset_%s_%s_%d_%d%s,%s "gfx/%s") {[ %d, %d, %d, %d, %d, %d ]}'

nml.layout_tmpl_snow = [[spritelayout spritelayout_%s_%s_%d_%d {
	ground { sprite: %s; }
	childsprite { sprite: GROUNDSPRITE_SNOW; hide_sprite: nearby_tile_height(%d,%d) < snowline_height; }
	building { sprite: spriteset_%s_%s_%d_%d(); zextent: 250; }
	building { sprite: spriteset_%s_%s_%d_%d_snow(); hide_sprite: (nearby_tile_height(%d,%d) < snowline_height); zextent: 250; } }]]

nml.layout_tmpl = 'spritelayout spritelayout_%s_%s_%d_%d {\n    ground { sprite: %s; }\n    building { sprite: spriteset_%s_%s_%d_%d(); zextent: 250; } }'

nml.item_tmpl = [[
item (FEAT_OBJECTS, object_%s) {
	property {
		class:                  "%s";
		classname:              string(STR_%s);
		name:                   string(STR_OBJ_%s);
		climates_available:     ALL_CLIMATES;
		size:                   [%d, %d];
		build_cost_multiplier:  2;
		remove_cost_multiplier: 2;
		introduction_date:      0x00000000;
		end_of_life_date:       0xFFFFFFFF;
		object_flags:           param_remove == 0 ? bitmask(OBJ_FLAG_ANYTHING_REMOVE, OBJ_FLAG_ON_WATER) : bitmask(OBJ_FLAG_ON_WATER);
		height:                 8;
		num_views:              %d;
	}
	graphics {
		default:         switch_%s_views;
		purchase:        switch_%s_menu;
	}
}]]

nml.lang = [[##grflangid 0x01

# General GRF strings
STR_GRF_NAME:EDIT_NEWGRF_NAME
STR_GRF_DESC:EDIT_NEWGRF_DESC
STR_GRF_URL:EDIT_NEWGRF_URL

# Parameters
STR_PAR_REMOVE_NAME:Remove only by demolishing
STR_PAR_REMOVE_DESC:{GOLD}If enabled, only the demolish tool can be used to remove an object.

]]

nml.groundsprite_map = {
	["2"]  = "GROUNDSPRITE_NORMAL",
	["3"]  = "GROUNDSPRITE_DESERT",
	["4"]  = "GROUNDSPRITE_DESERT_1_2",
	["5"]  = "GROUNDSPRITE_SNOW",
	["6"]  = "GROUNDSPRITE_SNOW_1_4",
	["7"]  = "GROUNDSPRITE_SNOW_2_4",
	["8"]  = "GROUNDSPRITE_SNOW_3_4",
	["9"]  = "GROUNDSPRITE_CONCRETE",
	["10"] = "GROUNDSPRITE_WATER",
	["11"] = "GROUNDSPRITE_CLEARED",
}



---------------------------------------------
-- GENERATE NML
---------------------------------------------

function nml:generate_nml()
	-- Read header config values
	local grfid = table_with_header["header"].grfid
	local version = table_with_header["header"].version
	local min_compatible_version = table_with_header["header"].min_comp_version
	local newgrf_name = table_with_header["header"].grf_name
	local newgrf_desc = table_with_header["header"].grf_desc
	local newgrf_url  = table_with_header["header"].grf_url

	-- REPLACE KEYWORDS IN HEADER
	local NML = {}
	local header = self.header
	header = header:gsub("EDIT_GRFID", grfid)
	header = header:gsub("EDIT_VERSION", version)
	header = header:gsub("EDIT_COMPATIBLE_VERSION", min_compatible_version)
	table.insert(NML, header)

	-- REPLACE KEYWORDS IN LANGUAGE FILE
	local LANG = {}
	local english = self.lang
	english = english:gsub("EDIT_NEWGRF_NAME", newgrf_name)
	newgrf_desc = newgrf_desc:gsub("\n", "{}")
	english = english:gsub("EDIT_NEWGRF_DESC", newgrf_desc)
	english = english:gsub("EDIT_NEWGRF_URL", newgrf_url)
	table.insert(LANG, english)

	-- GENERATE NML FOR OBJECTS
	if not table_of_objects or #table_of_objects == 0 then
		iup.Message("Warning", "No objects have been defined!\nExporting only the header...")
		return table.concat(NML), table.concat(LANG)
	end

	local used_grounds = {}
	local used_classes = {}
	local view_identifiers = { "a", "b", "c", "d" }

	for i = 1, #table_of_objects do
		-- Read object config values
		local filename = tostring(table_of_objects[i].file)
		local image_width = tonumber(table_of_objects[i].image_width)
		local image_height = tonumber(table_of_objects[i].image_height)
		local bpp = tostring(table_of_objects[i].bpp)
		local snow = (table_of_objects[i].snow == "ON") and true or false
		local filename_snow = tostring(table_of_objects[i].file_snow)
		local bpp_snow = tostring(table_of_objects[i].bpp_snow)
		local list_ground_value = tostring(table_of_objects[i].ground)
		local filename_ground = tostring(table_of_objects[i].file_ground)
		local name_of_object = tostring(table_of_objects[i].name)
		local Xdim = tonumber(table_of_objects[i].Xdim)
		local Ydim = tonumber(table_of_objects[i].Ydim)
		local number_of_views = tonumber(table_of_objects[i].views)
		local class = tostring(table_of_objects[i].class)
		local classname = tostring(table_of_objects[i].classname)

		-- Declare result containers
		local name = helpers.get_stem(filename)
		local nml_parts = {}
		local spritesets = { "// " .. name }
		local spritelayouts = {}
		local switch = {}

		-- Set bpp string based on 
		local type_of_image = (bpp == "8") and "" or " ZOOM_LEVEL_NORMAL, BIT_DEPTH_32BPP,"
		local type_of_image_snow = (bpp_snow == "8") and "" or " ZOOM_LEVEL_NORMAL, BIT_DEPTH_32BPP,"

		-- Create a table for possible snow variants - will be looped through
		local input_variants
		if snow then
			input_variants = {
				{ "", type_of_image, filename },
				{ "_snow", type_of_image_snow, filename_snow }
			}
		else
			input_variants = { { "", type_of_image, filename } }
		end

		-- Set up ground - a string from a map if predefined ground sprite, else spriteset (put definition at the end of 'header')
		local name_ground = ""
		local GROUNDSPRITE = ""
		if list_ground_value == "1" then
			name_ground = helpers.get_stem(filename_ground)
			GROUNDSPRITE = "spriteset_" .. name_ground .. "()"
		else
			GROUNDSPRITE = self.groundsprite_map[list_ground_value]
		end
		if list_ground_value == "1" and not used_grounds[filename_ground] then
			local output = {}
			for line in NML[1]:gmatch("([^\n]*)\n?") do
				if line == "" and #output > 0 and output[#output] == "" then
					break
				end
				table.insert(output, line)
				if line:find("// GROUND") then
					table.insert(output, string.format('spriteset (spriteset_%s, ZOOM_LEVEL_NORMAL, BIT_DEPTH_32BPP, "gfx/%s") {[0, 0, 64, 31, -31, 0]}',
						name_ground, filename_ground))
				end
			end
			NML[1] = table.concat(output, "\n")
			used_grounds[filename_ground] = true
		end

		-- Calculate sprite parameters - TODO better error handling, if dimensions don't match loaded image?
		local sprite_width = Xdim * 32 + Ydim * 32
		local padding = (number_of_views > 1) and (image_width - number_of_views * sprite_width) / (number_of_views - 1) or 0
		local yoff = image_height - ((Ydim + Xdim) * 16) + 1
		local menu_offset = (number_of_views == 4) and (-yoff - 16) or -yoff


		-- Choose nmlgen based on num of views, dimensions
		for i = 0, number_of_views - 1 do
			local view_id = view_identifiers[i+1]

			local X_dimension, Y_dimension
			if i == 0 or i == 2 then
				X_dimension, Y_dimension = Xdim, Ydim
			else
				X_dimension, Y_dimension = Ydim, Xdim
			end

			local x_origin = (sprite_width // 2) + X_dimension * 16 - Y_dimension * 16 - 32

			table.insert(switch, string.format(
				"switch(FEAT_OBJECTS, SELF, switch_spritelayout_%s_%s, relative_pos) {",
				name, view_id
			))

			-- Objects 1 x 1
			if X_dimension == 1 and Y_dimension == 1 then
				for _, v in ipairs(input_variants) do
					local string_snow, bpp, path = table.unpack(v)
					table.insert(spritesets, string.format(
						self.spriteset_tmpl, name, view_id, 0, 0, string_snow, bpp, path,
						0+(sprite_width+padding)*i, 0, 64, image_height, -31, -(image_height-31)
					))
				end
				if snow then
					table.insert(spritelayouts, string.format(self.layout_tmpl_snow,
						name, view_id, 0, 0, GROUNDSPRITE, 0, 0,
						name, view_id, 0, 0, name, view_id, 0, 0, 0, 0
					))
				else
					table.insert(spritelayouts, string.format(self.layout_tmpl,
						name, view_id, 0, 0, GROUNDSPRITE, name, view_id, 0, 0
					))
				end
				table.insert(switch, string.format(
					"    relative_coord(%d, %d): spritelayout_%s_%s_%d_%d;",
					0, 0, name, view_id, 0, 0
				))

			-- Objects 1 x N
			elseif X_dimension == 1 then
				for x = 0, X_dimension-1 do
					for y = 0, Y_dimension-1 do
						local imgx = x_origin - x*32 + y*32
						local imgy = x*(32//2) + y*(32//2) - 16 + yoff
						local height = yoff + x*16 + y*16 + 31

						for _, v in ipairs(input_variants) do
							local string_snow, bpp, path = table.unpack(v)
							if x == 0 and y == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, 0, 32, height, -31, -(height-31)
								))
							elseif y == Y_dimension-1 and x == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, 0, 64, height, -31, -(height-31)
								))
							else
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, 0, 32, height, -31, -(height-31)
								))
							end
						end

						if snow then
							table.insert(spritelayouts, string.format(self.layout_tmpl_snow,
								name, view_id, x, y, GROUNDSPRITE, math.max(-8, -x), math.max(-8, -y),
								name, view_id, x, y, name, view_id, x, y, math.max(-8, -x), math.max(-8, -y)
							))
						else
							table.insert(spritelayouts, string.format(self.layout_tmpl,
								name, view_id, x, y, GROUNDSPRITE, name, view_id, x, y
							))
						end
						table.insert(switch, string.format(
							"    relative_coord(%d, %d): spritelayout_%s_%s_%d_%d;",
							x, y, name, view_id, x, y
						))
					end
				end

			-- Objects M x 1
			elseif Y_dimension == 1 then
				for x = 0, X_dimension-1 do
					for y = 0, Y_dimension-1 do
						local imgx = x_origin - x*32 + y*32
						local imgy = x*(32//2) + y*(32//2) - 16 + yoff
						local height = yoff + x*16 + y*16 + 31

						for _, v in ipairs(input_variants) do
							local string_snow, bpp, path = table.unpack(v)
							if x == 0 and y == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+32+(sprite_width+padding)*i, 0, 32, height, 1, -(height-31)
								))
							elseif x == X_dimension-1 and y == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, 0, 64, height, -31, -(height-31)
								))
							else
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+32+(sprite_width+padding)*i, 0, 32, height, 1, -(height-31)
								))
							end
						end

						if snow then
							table.insert(spritelayouts, string.format(self.layout_tmpl_snow,
								name, view_id, x, y, GROUNDSPRITE, math.max(-8, -x), math.max(-8, -y),
								name, view_id, x, y, name, view_id, x, y, math.max(-8, -x), math.max(-8, -y)
							))
						else
							table.insert(spritelayouts, string.format(self.layout_tmpl,
								name, view_id, x, y, GROUNDSPRITE, name, view_id, x, y
							))
						end
						table.insert(switch, string.format(
							"    relative_coord(%d, %d): spritelayout_%s_%s_%d_%d;",
							x, y, name, view_id, x, y
						))
					end
				end

			-- Objects M x N
			else
				for x = 0, X_dimension-1 do
					for y = 0, Y_dimension-1 do
						local imgx = x_origin - x*32 + y*32
						local imgy = x*(32//2) + y*(32//2) - 16 + yoff
						local height = yoff + x*16 + y*16 + 31

						-- Loop for adding snow (if included in "input_variants")
						for _, v in ipairs(input_variants) do
							local string_snow, bpp, path = table.unpack(v)

							-- Left corner
							if x == X_dimension-1 and y == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, 0, 32, height, -31, -(height-31)
								))
							-- Right corner
							elseif y == Y_dimension-1 and x == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i+32, 0, 32, height, 1, -(height-31)
								))
							-- Lowest corner
							elseif x == X_dimension-1 and y == Y_dimension-1 then
								if X_dimension == Y_dimension then
									table.insert(spritesets, string.format(self.spriteset_tmpl,
										name, view_id, x, y, string_snow, bpp, path,
										imgx+(sprite_width+padding)*i, imgy, 64, 47, -31, -16
									))
								else
									table.insert(spritesets, string.format(self.spriteset_tmpl,
										name, view_id, x, y, string_snow, bpp, path,
										imgx+(sprite_width+padding)*i, imgy-16, 64, 63, -31, -32
									))
								end
							-- Top corner
							elseif x == 0 and y == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, 0, 64, height-15, -31, -(height-31)
								))
							-- North-east edge
							elseif x == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i+32, 0, 32, height-31+16, 1, -(height-31)
								))
							-- North-west edge
							elseif y == 0 then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, 0, 32, height-31+16, -31, -(height-31)
								))
							-- South-west edge
							elseif x == X_dimension-1 then
								if X_dimension < Y_dimension and x < y then
									table.insert(spritesets, string.format(self.spriteset_tmpl,
										name, view_id, x, y, string_snow, bpp, path,
										imgx+(sprite_width+padding)*i, imgy-16, 32, 63, -31, -32
									))
								else
									table.insert(spritesets, string.format(self.spriteset_tmpl,
										name, view_id, x, y, string_snow, bpp, path,
										imgx+(sprite_width+padding)*i, imgy, 32, 47, -31, -16
									))
								end
							-- South-east edge
							elseif y == Y_dimension-1 then
								if X_dimension > Y_dimension and x > y then
									table.insert(spritesets, string.format(self.spriteset_tmpl,
										name, view_id, x, y, string_snow, bpp, path,
										imgx+(sprite_width+padding)*i+32, imgy-16, 32, 63, 1, -32
									))
								else
									table.insert(spritesets, string.format(self.spriteset_tmpl,
										name, view_id, x, y, string_snow, bpp, path,
										imgx+(sprite_width+padding)*i+32, imgy, 32, 47, 1, -16
									))
								end
							-- Middle tiles
							elseif y == x then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, imgy, 64, 32, -31, -16
								))
							-- Left of middle tiles
							elseif x > y then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i, imgy, 32, 32, -31, -16
								))
							-- Right of middle tiles
							elseif x < y then
								table.insert(spritesets, string.format(self.spriteset_tmpl,
									name, view_id, x, y, string_snow, bpp, path,
									imgx+(sprite_width+padding)*i+32, imgy, 32, 32, 1, -16
								))
							end
						end

						if snow then
							table.insert(spritelayouts, string.format(self.layout_tmpl_snow,
								name, view_id, x, y, GROUNDSPRITE, math.max(-8, -x), math.max(-8, -y),
								name, view_id, x, y, name, view_id, x, y, math.max(-8, -x), math.max(-8, -y)
							))
						else
							table.insert(spritelayouts, string.format(self.layout_tmpl,
								name, view_id, x, y, GROUNDSPRITE, name, view_id, x, y
							))
						end
						table.insert(switch, string.format(
							"    relative_coord(%d, %d): spritelayout_%s_%s_%d_%d;",
							x, y, name, view_id, x, y
						))
					end
				end
			end

			-- Menu spriteset and spritelayout
			table.insert(spritesets, string.format(
				"spriteset(spriteset_%s_%s_menu,%s \"gfx/%s\") {[ %d, %d, %d, %d, %d, %d ]}",
				name, view_id, type_of_image, filename,
				0+(sprite_width+padding)*i, 0, sprite_width, image_height,
				-sprite_width//2, menu_offset
			))
			table.insert(spritelayouts, string.format(
				"spritelayout spritelayout_%s_%s_menu { ground { sprite: spriteset_empty; } building { sprite: spriteset_%s_%s_menu; } }",
				name, view_id, name, view_id
			))
			table.insert(switch, "}")
		end


		-- Views and menu switches
		local views_switch = { string.format("switch (FEAT_OBJECTS, SELF, switch_%s_views, [view]) {", name) }
		local menu_switch  = { string.format("switch (FEAT_OBJECTS, SELF, switch_%s_menu, [view]) {", name) }

		for i = 0, number_of_views - 1 do
			local view_id = view_identifiers[i+1]
			table.insert(views_switch, string.format("    %d: switch_spritelayout_%s_%s;", i, name, view_id))
			table.insert(menu_switch, string.format("    %d: spritelayout_%s_%s_menu;", i, name, view_id))
		end
		table.insert(views_switch, "}")
		table.insert(menu_switch, "}")

		local item_block = string.format(self.item_tmpl, name, class, class, name, Xdim, Ydim, number_of_views, name, name)

		-- Collect everything
		table.insert(nml_parts, "\n\n\n" ..
			table.concat(spritesets, "\n") .. "\n\n" ..
			table.concat(spritelayouts, "\n") .. "\n\n" ..
			table.concat(switch, "\n") .. "\n\n" ..
			table.concat(views_switch, "\n") .. "\n" ..
			table.concat(menu_switch, "\n") .. "\n\n" .. item_block)

		local result = table.concat(nml_parts, "\n")
		table.insert(NML, result)

		-- LANG
		if used_classes[class] then
			table.insert(LANG, "STR_OBJ_" .. helpers.get_stem(filename) .. ":" .. name_of_object .. "\n")
		else
			table.insert(LANG, "STR_" .. class .. ":" .. classname .. "\n")
			table.insert(LANG, "STR_OBJ_" .. helpers.get_stem(filename) .. ":" .. name_of_object .. "\n")
			used_classes[class] = true
		end
	end

	return table.concat(NML), table.concat(LANG)
end

function nml.write_NML_to_file(filename, NML, LANG)
	if not filename:lower():match("%.nml$") then
		filename = filename .. ".nml"
	end

	local NML_file = io.open("../" .. filename, "w")

	local lang_dir = "../lang"
	if not helpers.dir_exists(lang_dir) then
		helpers.make_dir(lang_dir)
	end
	local LANG_file = io.open(lang_dir .. "/english.lng", "w")

	if NML_file then
		NML_file:write(NML)
		NML_file:close()
	end

	if LANG_file then
		LANG_file:write(LANG)
		LANG_file:close()
	end
end

return nml