--[[
A utility module providing a collection of helper functions for file and directory operations,
table inspection and manipulation, string parsing, numeric rounding, etc.
Designed for use in Lua applications requiring simple I/O checks and utility operations.

Functions included:
- dir_exists(path): Check if a directory exists (platform-specific).
- make_dir(path): Create a directory (non-recursive on Windows, recursive on Unix).
- print_table(tbl[, indent]): Recursively pretty-print table contents.
- get_stem(path): Extract the base filename without extension or path.
- get_parent(path): Returns the parent directory path of the given file OR directory path
- get_directory(path): Returns the directory path, whether the input is a directory or a file path
- file_exists(path): Check whether a file exists.
- slice_table(tbl, first, last): Return a sublist of the table from index 'first' to 'last'.
- round(num, numDecimalPlaces): Round a number to the specified number of decimal places.
- trim(str): Trim whitespace from both ends of a string.
- split(inputstr, separator): Split a string into a table using the given separator.
- startswith(str, prefix[, start_index]): Check if a string begins with a specified prefix (optional starting index).
- str_to_bool(str): Convert boolean-like strings into proper boolean values.
- contains_any(tbl, values): Check a table for membership of any item from a list.
- enumerate(table): Returns a pair of variables 'index', 'table[index]' (similar to Python)
- generate_random_string(length): Generate a random string of 'length' characters, chosen from [a-zA-Z0-9].
- windows_safe_filename(string): Replace characters not allowed in Windows filenames: \ / : * ? " < > | and trailing dots and spaces.
- sleep(seconds): Creates an empty loop until a specified time in seconds has passed.
]]

local helpers = {}

local is_windows = package.config:sub(1,1) == '\\'
-- Check if a directory exists
function helpers.dir_exists(path)
    local cmd = is_windows
        and ('if exist "' .. path .. '\\" (echo true)')
        or ('[ -d "' .. path .. '" ] && echo true')
    local pipe = io.popen(cmd)
    if not pipe then return false end
    local result = pipe:read("*a")
    pipe:close()
    return result:match("true") ~= nil
end

-- Create a directory (non-recursive on Windows, recursive on Unix)
function helpers.make_dir(path)
    local cmd = is_windows
        and ('mkdir "' .. path .. '"')
        or ('mkdir -p "' .. path .. '"')
    os.execute(cmd)
end

-- Pretty-print contents of a table
function helpers.print_table(tbl, indent)
    indent = indent or 0
    local tab_size = "  "
    local formatting = string.rep(tab_size, indent)

    -- Function to check if a table is array-like
    local function is_array(t)
        local i = 0
        for _ in pairs(t) do
            i = i + 1
            if t[i] == nil then return false end
        end
        return true
    end

    -- Non-table values are printed directly
    if type(tbl) ~= "table" then
        print(formatting .. tostring(tbl))
        return
    end

    -- Format output as an 'array'
    if is_array(tbl) then
        io.write(formatting .. "{")
        for i, v in ipairs(tbl) do
            if type(v) == "table" then
                print()
                helpers.print_table(v, indent + 1)
            else
                io.write(tostring(v))
            end
            if i < #tbl then io.write(", ") end
        end
        print("}")
    -- or format output as a 'dictionary'
    else
        print(formatting .. "{")
        for k, v in pairs(tbl) do
            io.write(formatting .. tab_size .. tostring(k) .. " = ")
            if type(v) == "table" then
                print()
                helpers.print_table(v, indent + 2)
            else
                print(tostring(v))
            end
        end
        print(formatting .. "}")
    end
end

-- Get a filename without an extension and path
function helpers.get_stem(path)
    return path:match("([^\\/]-)%.?[^%.\\/]*$") or path
end

-- Get parent folder of given path
function helpers.get_parent(path)
    return path:match("^(.*)[/\\][^/\\]+$")
end

-- Get the directory path: if 'path' ends with a filename (has an extension) -> returns its parent;
-- otherwise returns the path itself (without a trailing slash)
function helpers.get_directory(path)
    local p = path:gsub("[/\\]+$", "") -- strip trailing slashes
    if p:match("[/\\][^/\\]+%.[^/\\]+$") then
        return p:match("^(.*)[/\\][^/\\]+$") or p
    else
        return p
    end
end

-- Check whether a file exists, returns true | false
function helpers.file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() end
    return f ~= nil
end

-- Perform slicing of a table, returns a new table
function helpers.slice_table(tbl, first, last)
    local result = {}
    for i = first, last do
        table.insert(result, tbl[i])
    end
    return result
end

-- Round to the given number of decimal places
function helpers.round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

-- Trim whitespace from both ends of a string
function helpers.trim(str)
    return str:match("^%s*(.-)%s*$")
end

-- Output a table with each value of string 'inputstr' split by a 'separator'
function helpers.split(inputstr, separator)
    if separator == nil then
        separator = ","     -- Default to comma if no separator entered
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. separator .. "]+)") do
        table.insert(t, trim(str))
    end
    return t
end

-- Return 'true' if string starts with specified value (at optional starting index)
function helpers.startswith(str, prefix, start_index)
    start_index  = start_index  or 1
    local end_index = start_index + #prefix - 1

    return str:sub(start_index, end_index) == prefix
end

-- Convert boolean-like strings into proper boolean values
function helpers.str_to_bool(str)
    if str == "false" or str == "FALSE" or str == "False" then
        return false
    else
        return true
    end
end

-- Returns 'true', if any one value from 'values' is present in 'tbl'
function helpers.contains_any(tbl, values)
    for _, v in ipairs(tbl) do
        for _, target in ipairs(values) do
            if string.upper(v) == string.upper(target) then
                return true
            end
        end
    end
    return false
end

-- Mimics Python's enumerate: adds a counter to an array-like table,
-- doesn't stop at 'nil' and returns two vars: 'index', 'table[index]'
function helpers.enumerate(table)
    local i = 0
    return function()
        i = i + 1
        if i <= #table then
            return i, table[i]
        end
    end
end

-- Returns a random string made of [a-zA-Z0-9] of given 'length'
function helpers.generate_random_string(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = {}
    for i = 1, length do
        local index = math.random(1, tonumber(#chars))
        table.insert(result, chars:sub(index, index))
    end
    
    return table.concat(result)
end

-- Returns a "sanitized" string safe for use as a Windows filename
function helpers.windows_safe_filename(name)
    local safe = name:gsub('[\\/:*?"<>|]', '_')
    safe = safe:gsub('[%. ]+$', '')

    -- Replace reserved filenames
    local reserved = {
        "CON", "PRN", "AUX", "NUL",
        "COM[1-9]", "LPT[1-9]"
    }
    for _, pattern in ipairs(reserved) do
        if safe:match('^' .. pattern .. '$') then
            safe = '_' .. safe
            break
        end
    end

    return safe
end

-- Pauses script for 'seconds' (int, float)
function helpers.sleep(seconds)
    local t0 = os.clock()
    while os.clock() - t0 <= seconds do
        -- Nothing
    end
end


return helpers