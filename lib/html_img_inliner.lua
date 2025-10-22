--[[
This module provides functionality for programmatically embedding image data 
directly into HTML files. It identifies <img> elements within an HTML document, 
reads the corresponding image files from disk, and replaces their 'src' 
attributes with Base64-encoded data URIs. This allows the resulting HTML file 
to be completely self-contained, eliminating external image dependencies.

- html_img_inliner.inline_images_in_html(html_path) -> string
    Reads an HTML file, converts all linked <img> sources to embedded 
    Base64 data URIs, and returns the modified HTML content as a string.

This module is implemented entirely in pure Lua and requires no external 
libraries or dependencies.
]]

---------------------------------------------
-- LOCAL ENCODER FUNCTIONS
---------------------------------------------

-- Pure Lua base64 encoder
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64_encode(data)
    return ((data:gsub('.', function(x) 
        local r,bits='',x:byte()
        for i=8,1,-1 do r=r..(bits%2^i-bits%2^(i-1)>0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end


-- MIME type detection by file extension
local function guess_mime_type(filename)
    local ext = filename:match("^.+(%..+)$")
    if not ext then return "application/octet-stream" end
    ext = ext:lower()
    if ext == ".png" then return "image/png"
    elseif ext == ".jpg" or ext == ".jpeg" then return "image/jpeg"
    elseif ext == ".gif" then return "image/gif"
    elseif ext == ".svg" then return "image/svg+xml"
    else return "application/octet-stream"
    end
end

-- Encode file into data URI
local function encode_file_as_data_uri(filename)
    local f = io.open(filename, "rb")
    if not f then return "" end
    local content = f:read("*all")
    f:close()
    local b64 = base64_encode(content)
    local mime_type = guess_mime_type(filename)

    return string.format("data:%s;base64,%s", mime_type, b64)
end


---------------------------------------------
-- PUBLIC FUNCTION
---------------------------------------------
local html_img_inliner = {}

function html_img_inliner.inline_images_in_html(html_path)
    local f = io.open(html_path, "r")
    local html = f:read("*all")
    f:close()

    local new_html = html:gsub(
        '(<img[^>]-src%s*=%s*["\'])(.-)(["\'])',
        function(prefix, src, suffix)
            if src:match("^data:") then
                return prefix .. src .. suffix
            end
            local data_uri = encode_file_as_data_uri(src)
            return prefix .. data_uri .. suffix
        end
    )

    return new_html
end

return html_img_inliner