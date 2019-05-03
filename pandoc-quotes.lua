--- Replaces plain quotation marks with typographic ones.
--
-- @script pandoc-quotes.lua
-- @release 0.1.5
-- @author Odin Kroeger
-- @copyright 2018 Odin Kroeger
-- @license MIT
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.


-- Constants
-- =========

-- The name of this script.
local NAME = 'pandoc-quotes.lua'

-- The version of this script.
local VERSION = '0.1.5'

-- The default language for quotation marks.
local DEFAULT_LANG = 'en-US'


-- Shorthands
-- ==========

local concat = table.concat
local insert = table.insert
local unpack = table.unpack

local text = require 'text'
local sub = text.sub

local stringify = pandoc.utils.stringify
local Str = pandoc.Str


-- Initialisation
-- ==============

-- The path seperator of the operating system
local PATH_SEP = sub(package.config, 1, 1)

--- Splits a file's path into its directory and its filename part.
--
-- @tparam string path The path to the file.
-- @treturn string The file's path.
-- @treturn string The file's name.
do
    local split_expr = '(.-)[\\' .. PATH_SEP .. ']([^\\' .. PATH_SEP .. ']-)$'
    function split_path (path)
        return path:match(split_expr)
    end
end

-- The directory the script is located in.
local SCRIPT_DIR = split_path(PANDOC_SCRIPT_FILE) or '.'

-- The search path for 'quot-marks.yaml'.
local QUOT_MARKS_PATH = {SCRIPT_DIR .. PATH_SEP .. NAME .. '-' .. VERSION, 
    SCRIPT_DIR, PANDOC_STATE.user_data_dir}


-- Functions
-- =========

--- Prints warnings to STDERR.
--
-- @tparam string ... Strings to be written to STDERR.
--
-- Prefixes messages with 'pandoc-quotes.lua: ' and appends a linefeed.
function warn (...)
    io.stderr:write(NAME, ': ', concat({...}), '\n')
end


--- Reads a YAML file and returns it as pandoc.Meta block.
--
-- @tparam string fname The name of the file.
-- @treturn pandoc.Meta The data or `nil` if an error occurred.
-- @treturn string An error message if an error occurred.
-- @treturn number An error number if applicable.
function read_yaml_file (fname)
    local f, err, errno = io.open(fname, 'r')
    if not f then return nil, err, errno end
    local yaml, err = f:read('a')
    if not yaml then return nil, err end
    local ok, err = f:close()
    if not ok then return nil, err end
    return pandoc.read('---\n' .. yaml .. '\n...\n').meta
end


--- Reads quotation marks from a `quot-marks` metadata field.
--
-- @tparam pandoc.MetaValue The content of a metadata field.
--  Must be either of type pandoc.MetaInlines or pandoc.MetaList.
-- @treturn {ldquo=Str,rdquo=Str,lsquo=Str,rsquo=Str} 
--  A table of quotation marks or `nil` if an error occurred.
-- @treturn string An error message if an error occurred.
function get_marks_from_field (field)
    local i = nil
    if field.t == 'MetaInlines' then
        i = function(j) 
            local marks = stringify(field)
            return Str(sub(marks, j, j))
        end
    elseif field.t == 'MetaList' then
        i = function(j) 
            return Str(stringify(field[j]))
        end
    else
        return nil, 'neither a string nor a list.'
    end
    return {ldquo = i(1), rdquo = i(2), lsquo = i(3), rsquo = i(4)}
end


--- Reads quotation mark lookup tables.
--
-- Searches for files called `quot-marks.yaml` in every directory listed in
-- the global variables `QUOT_MARKS_PATH`. A `quot-marks.yaml` file is a YAML
-- file that maps RFC 5646-ish language codes to quotation marks. See the one
-- that ships with this script for the syntax and further details. Definitions
-- in files parsed later override those in files parsed earlier.
--
-- @treturn {[string]=tab} A mapping of RFC 5646-ish language codes to
--  tables of quotation marks as returned by `get_marks_from_field`
--  or `nil` if an error occurred.
-- @treturn string An error message if an error occurred.
function read_lookup_tables ()
    local ret = {}
    for i, dir in ipairs(QUOT_MARKS_PATH) do
        local fname = dir .. PATH_SEP .. 'quot-marks.yaml'
        local data, err, errno = read_yaml_file(fname)
        if data then
            for lang, field in pairs(data) do
                local marks, err = get_marks_from_field(field)
                if marks == nil then return nil, err end
                ret[lang] = marks
            end
        elseif not errno or errno ~= 2 then
            return nil, err
        end
    end 
    return ret
end


do
    local marks_map = nil

    -- Retrieves quotation marks by language.
    --
    -- Quotation marks are defined in `quot-marks.yaml` files.
    -- See `read_lookup_tables` for details.
    --
    -- @tparam string lang An RFC 5646-ish language code.
    -- @treturn {ldquo=Str,rdquo=Str,lsquo=Str,rsquo=Str} 
    --  A table of quotation marks or `nil` if an error occurred.
    -- @treturn string An error message if an error occurred.
    function get_marks_by_language (lang)
        if not marks_map then marks_map = read_lookup_tables() end
        if not lang:match('^%a+%-?%a*$') then
            return nil, lang .. ': not an RFC 5646-like language code.'
        end
        if marks_map[lang] then return marks_map[lang] end
        lang = lang:match('(%a+)%-?')
        if marks_map[lang] then return marks_map[lang] end
        local pattern = '^' .. lang .. '%-'
        for k, v in pairs(marks_map) do 
            if k:match(pattern) then return v end
        end
        if not marks_map[DEFAULT_LANG] then 
            return nil, DEFAULT_LANG .. ': is missing.'
        end
        return marks_map[DEFAULT_LANG]
    end
end

do
    -- A variable common to `configure` and `insert_quotation_marks`
    -- that holds the quotation marks for the language of the document.
    local MARKS = nil

    --- Determines the language of the document.
    --
    -- Stores it in `MARKS`, which is shared with `insert_quotation_marks`.
    --
    -- @tparam pandoc.Meta The document's metadata.
    --
    -- Prints errors to STDERR.
    function configure (meta)
        local lang = DEFAULT_LANG
        if meta['quot-marks'] then
            MARKS, err = get_marks_from_field(meta['quot-marks'])
            if not MARKS then 
                warn('metadata field "quoation-marks": ', err)
                return
            end
        elseif meta['quot-lang'] then
            lang = stringify(meta['quot-lang'])
        elseif meta['lang'] then
            lang = stringify(meta['lang'])
        end
        MARKS, err = get_marks_by_language(lang)
        if not MARKS or not MARKS.ldquo then 
            warn(err) 
        end
    end


    --- Replaces pandoc.Quoted elements with quoted text.
    --
    -- Uses the quotioatn marks stored in `MARKS`, 
    -- which is shared with `configure`.
    --
    -- @tparam pandoc.Quoted quoted A quoted element.
    -- @treturn {pandoc.Inline} A list with the opening quote (as `Str`),
    --  the content of `quoted`, and the closing quote (as `Str`).
    function insert_quotation_marks (quoted)
        if not MARKS or not MARKS.ldquo then return end
        local quote_type = quoted.c[1]
        local inlines = quoted.c[2]
        if quote_type == 'DoubleQuote' then
            insert(inlines, 1, MARKS.ldquo)
            insert(inlines, MARKS.rdquo)
        elseif quote_type == 'SingleQuote' then
            insert(inlines, 1, MARKS.lsquo)
            insert(inlines, MARKS.rsquo)
        else
            warn(quote_type, ': unknown quote type.')
            return
        end
        return inlines
    end
end

return {{Meta = configure}, {Quoted = insert_quotation_marks}}