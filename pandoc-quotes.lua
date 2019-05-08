--- Replaces plain quotation marks with typographic ones.
--
-- # AUTHOR
--
-- Copyright 2019 Odin Kroeger
--
--
-- # LICENSE
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
--
--
-- @script pandoc-quotes.lua
-- @release 0.1.8b
-- @author Odin Kroeger
-- @copyright 2018 Odin Kroeger
-- @license MIT


-- # INITIALISATION

local pandoc_quotes = {}

local pairs = pairs
local require = require

local stderr = io.stderr
local format = string.format
local concat = table.concat
local insert = table.insert
local unpack = table.unpack

local stringify = pandoc.utils.stringify
local Str = pandoc.Str

local _ENV = pandoc_quotes

local text = require 'text'
local sub = text.sub


-- # CONSTANTS

--- The name of this script.
NAME = 'pandoc-quotes.lua'


--- A list of mappings from RFC 5646-ish language codes to quotation marks.
-- 
-- I have adopted the list below from:
-- <https://en.wikipedia.org/w/index.php?title=Quotation_mark&oldid=836731669>
-- 
-- I tried to come up with reasonable defaults for secondary quotes for
-- language that, according to the Wikipedia, don't have any.
--
-- Adding languages:
--
-- Add an ordered pair, where the first item is an RFC 5646 language
-- code (though only the language and country tags are supported) and the
-- second item is a list of quotation marks, in the following order:
-- primary left, primary right, secondary left, secondary right.
--
-- You have to list four quotation marks, even if the langauge you add does
-- not use secondary quotation marks. Just come up with something that makes
-- sense. This is because a user may, rightly, find that just because their
-- language does not 'officially' have secondary quotation marks, they
-- are going to use them anyway. And they should get a reasonable result,
-- not a runtime error.
--
-- The order in which languages are listed is meaningless. If you define 
-- variants for a language that is spoken in different countries, also
-- define a 'default' for the language alone, without the country tag.
QUOT_MARKS_BY_LANG = {
    bo = {'「', '」', '『', '』'},
    bs = {'”', '”', '’', '’'},
    cn = {'「', '」', '『', '』'},
    cs = {'„', '“', '‚', '‘'},
    cy = {'‘', '’', '“', '”'},
    da = {'»', '«', '›', '‹'},
    de = {'„', '“', '‚', '‘'},
    ['de-CH'] = {'«', '»', '‹', '›'},
    el = {'«', '»', '“', '”'},
    en = {'“', '”', '‘', '’'},
    ['en-US'] = {'“', '”', '‘', '’'},
    ['en-GB'] = {'‘', '’', '“', '”'},
    ['en-UK'] = {'‘', '’', '“', '”'},
    ['en-CA'] = {'“', '”', '‘', '’'},
    eo = {'“', '”', '‘', '’'},
    es = {'«', '»', '“', '”'},
    et = {'„', '“', '‚', '‘'},
    fi = {'”', '”', '’', '’'},
    fil = {'“', '”', '‘', '’'},
    fa = {'«', '»', '‹', '›'},
    fr = {'«', '»', '‹', '›'},
    ga = {'“', '”', '‘', '’'},
    gd = {'‘', '’', '“', '”'},
    gl = {'«', '»', '‹', '›'},
    he = {'“', '”', '‘', '’'},
    hi = {'“', '”', '‘', '’'},
    hu = {'„', '”', '»', '«'},
    hr = {'„', '“', '‚', '‘'},
    ia = {'“', '”', '‘', '’'},
    id = {'“', '”', '‘', '’'},
    is = {'„', '“', '‚', '‘'},
    it = {'«', '»', '“', '”'},
    ['it-CH'] = {'«', '»', '‹', '›'},
    ja = {'「', '」', '『', '』'},
    jbo = {'lu', 'li\'u', 'lu', 'li\'u'},
    ka = {'„', '“', '‚', '‘'},
    khb = {'《', '》', '〈', '〉'},
    kk = {'«', '»', '‹', '›'},
    km = {'«', '»', '‹', '›'},
    ko = {'《', '》', '〈', '〉'},
    ['ko-KR'] = {'“', '”', '‘', '’'},
    lt = {'„', '“', '‚', '‘'},
    lv = {'„', '“', '‚', '‘'},
    lo = {'«', '»', '‹', '›'},
    nl = {'„', '”', '‚', '’'},
    mk = {'„', '“', '’', '‘'},
    mn = {'«', '»', '‹', '›'},
    mt = {'“', '”', '‘', '’'},
    no = {'«', '»', '«', '»'},
    pl = {'„', '”', '»', '«'},
    ps = {'«', '»', '‹', '›'},
    pt = {'«', '»', '“', '”'},
    ['pt-BR'] = {'“', '”', '‘', '’'},
    rm = {'«', '»', '‹', '›'},
    ro = {'„', '”', '»', '«'},
    ru = {'«', '»', '“', '”'},
    sk = {'„', '“', '‚', '‘'},
    sl = {'„', '“', '‚', '‘'},
    sq = {'„', '“', '‚', '‘'},
    sr = {'„', '“', '’', '’'},
    sv = {'”', '”', '’', '’'},
    tdd = {'「', '」', '『', '』'},
    ti = {'«', '»', '‹', '›'},
    th = {'“', '”', '‘', '’'},
    thi = {'「', '」', '『', '』'},
    tr = {'«', '»', '‹', '›'},
    ug = {'«', '»', '‹', '›'},
    uk = {'«', '»', '„', '“'},
    uz = {'«', '»', '„', '“'},
    vi = {'“', '”', '‘', '’'},
    wen = {'„', '“', '‚', '‘'}
}


-- # FUNCTIONS

--- Prints warnings to STDERR.
--
-- @tparam string str A string format to be written to STDERR.
-- @tparam string ... Arguments to that format.
--
-- Prefixes messages with `NAME` and ": ". Appends a linefeed.
function warn (str, ...)
    stderr:write(NAME, ': ', format(str, ...), '\n')
end


--- Applies a function to every element of a list.
--
-- @tparam func f The function.
-- @tparam tab list The list.
-- @treturn tab The return values of `f`.
function map (f, list)
    local ret = {}
    for k, v in pairs(list) do ret[k] = f(v) end
    return ret
end


--- Reads quotation marks from a `quot-marks` metadata field.
--
-- @tparam pandoc.MetaValue The content of a metadata field.
--  Must be either of type pandoc.MetaInlines or pandoc.MetaList.
-- @treturn {Str,Str,Str,Str} A table of quotation marks 
--  or `nil` if an error occurred.
-- @treturn string An error message, if applicable.
function get_marks (field)
    local i
    if field.t == 'MetaInlines' then
        local marks = stringify(field)
        i = function(j) return sub(marks, j, j) end
    elseif field.t == 'MetaList' then
        local marks = map(stringify, field)
        i = function(j) return marks[j] end
    else
        return nil, 'neither a string nor a list.'
    end
    return {i(1), i(2), i(3), i(4)}
end


do
    -- Holds the quotation marks for the language of the document.
    -- Common to `configure` and `insert_quot_marks`.
    local QUOT_MARKS = nil

    --- Determines the quotation marks for the document.
    --
    -- Stores them in `QUOT_MARKS`, which it shares with `insert_quot_marks`.
    --
    -- @tparam pandoc.Meta The document's metadata.
    --
    -- Prints errors to STDERR.
    function configure (meta)
        local err_map   = 'metadata field "quot-marks-by-lang": lang "%s": %s'
        local err_marks = 'metadata field "quot-marks": %s'
        local err_lang  = '%s: unknown language.'
        local quot_marks, lang
        if meta['quot-marks-by-lang'] then
            for k, v in pairs(meta['quot-marks-by-lang']) do
                local quot_marks, err = get_marks(v)
                if not quot_marks then warn(err_map, k, err) return end
                QUOT_MARKS_BY_LANG[k] = quot_marks
            end
        end
        if meta['quot-marks'] then
            local err
            quot_marks, err = get_marks(meta['quot-marks'])
            if not quot_marks then warn(err_marks, err) return end
        elseif meta['quot-lang'] then
            lang = stringify(meta['quot-lang'])
        elseif meta['lang'] then
            lang = stringify(meta['lang'])
        end
        if lang then
            for i = 1, 3 do
                if     i == 2 then lang = lang:match('^(%a+)')
                elseif i == 3 then
                    local expr = '^' .. lang .. '-'
                    for k, v in pairs(QUOT_MARKS_BY_LANG) do
                        if k:match(expr) then quot_marks = v break end
                    end
                end
                if     i  < 3 then quot_marks = QUOT_MARKS_BY_LANG[lang] end
                if quot_marks then break end
            end
        end
        if quot_marks then QUOT_MARKS = map(Str, quot_marks) 
        elseif lang then warn(err_lang, lang) end
    end


    do
        local insert = insert
        --- Replaces quoted elements with quoted text.
        --
        -- Uses the quotation marks stored in `QUOT_MARKS`, 
        -- which it shares with `configure`.
        --
        -- @tparam pandoc.Quoted quoted A quoted element.
        -- @treturn {Str,pandoc.Inline,...,Str} A list with the opening quote 
        --  (as `Str`), the content of `quoted`, and the closing quote (as `Str`).
        function insert_quot_marks (quoted)
            if not QUOT_MARKS then return end
            local quote_type = quoted.c[1]
            local inlines    = quoted.c[2]
            local left, right
            if     quote_type == 'DoubleQuote' then left, right = 1, 2
            elseif quote_type == 'SingleQuote' then left, right = 3, 4
            else   error('unknown quote type') end
            insert(inlines, 1, QUOT_MARKS[left])
            insert(inlines,    QUOT_MARKS[right])
            return inlines
        end
    end
end

return {{Meta = configure}, {Quoted = insert_quot_marks}}
