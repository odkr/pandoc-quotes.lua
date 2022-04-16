--- Replaces plain quotation marks with typographic ones.
--
-- # SYNOPSIS
--
--      pandoc --lua-filter pandoc-quotes.lua
--
--
-- # DESCRIPTION
--
-- pandoc-quotes.lua is a filter for pandoc that replaces non-typographic
-- quotation marks with typographic ones for languages other than American
-- English.
--
-- You can define which typographic quotation marks to replace plain ones with
-- by setting either a document's quot-marks, quot-lang, or lang
-- metadata field. If none of these is set, pandoc-quotes.lua does nothing.
--
-- You can add your own mapping of a language to quotation marks or override
-- the default ones by setting quot-marks-by-lang.
--
-- ## quot-marks
--
-- A list of four strings, where the first item lists the primary left
-- quotation mark, the second the primary right quotation mark, the third
-- the secondary left quotation mark, and the fourth the secondary right
-- quotation mark.
--
-- For example:
--
-- ```yaml
-- ---
-- quot-marks:
--     - ''
--     - ''
--     - '
--     - '
-- ...
-- ```
--
-- You always have to set all four.
--
-- If each quotation mark consists of one character only,
-- you can write the whole list as a simple string.
--
-- For example:
--
-- ```yaml
-- ---
-- quot-marks: ""''
-- ...
-- ```
--
-- If quot-marks is set, the other fields are ignored.
--
--
-- # quotation-lang
--
-- An RFC 5646-like code for the language the quotation marks of
-- which shall be used (e.g., "pt-BR", "es").
--
-- For example:
--
-- ```yaml
-- ---
-- quot-lang: de-AT
-- ...
-- ```
--
-- Note: Only the language and the country tags of RFC 5646 are supported.
-- For example, "it-CH" (i.e., Italian as spoken in Switzerland) is fine,
-- but "it-756" (also Italian as spoken in Switzerland) will return the
-- quotation marks for "it" (i.e., Italian as spoken in general).
--
-- If quot-marks is set, quot-lang is ignored.
--
--
-- # lang
--
-- The format of lang is the same as for quot-lang. If quot-marks
-- or quot-lang is set, lang is ignored.
--
-- For example:
--
-- ```yaml
-- ---
-- lang: de-AT
-- ...
-- ```
--
--
-- # ADDING LANGS
--
-- You can add quotation marks for unsupported languages, or override the
-- defaults, by setting the metadata field quot-marks-by-lang to a maping
-- of RFC 5646-like language codes (e.g., "pt-BR", "es") to lists of quotation
-- marks, which are given in the same format as for the quot-marks
-- metadata field.
--
-- For example:
--
-- ```yaml
-- ---
-- quot-marks-by-lang:
--     abc-XYZ: ""''
-- lang: abc-XYZ
-- ...
-- ```
--
--
-- # CAVEATS
--
-- pandoc represents documents as abstract syntax trees internally, and
-- quotations are nodes in that tree. However, pandoc-quotes.lua replaces
-- those nodes with their content, adding proper quotation marks. That is,
-- pandoc-quotes.lua pushes quotations from the syntax of a document's
-- representation into its semantics. That being so, you should not
-- use pandoc-quotes.lua with output formats that represent quotes
-- syntactically (e.g., HTML, LaTeX, ConTexT). Moroever, filters running after
-- pandoc-quotes won't recognise quotes. So, it should be the last or
-- one of the last filters you apply.
--
-- Support for quotation marks of different languages is certainly incomplete
-- and likely erroneous. See <https://github.com/odkr/pandoc-quotes.lua> if
-- you'd like to help with this.
--
-- pandoc-quotes.lua is Unicode-agnostic.
--
--
-- # SEE ALSO
--
-- pandoc(1)
--
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
-- @release 0.2a
-- @author Odin Kroeger
-- @copyright 2018, 2020, 2022 Odin Kroeger
-- @license MIT


-- Initialisation
-- ==============

-- luacheck: allow defined top
-- luacheck: globals PANDOC_SCRIPT_FILE PANDOC_STATE PANDOC_VERSION pandoc
-- luacheck: ignore _ENV


-- Metadata
-- --------

-- The name of this script.
local NAME = 'pandoc-quotes.lua'

-- The version of this script.
local VERSION = '0.2a'


-- Libraries
-- ---------

do
    local path_sep = package.config:sub(1, 1)
    local script_dir = PANDOC_SCRIPT_FILE:match('(.*)' .. path_sep)
    local function path_join(...) return table.concat({...}, path_sep) end
    local rocks_dir = path_join('share', 'lua', '5.4', '?.lua')
    package.path = table.concat({package.path,
        path_join(script_dir, rocks_dir),
        path_join(script_dir, NAME .. '-' .. VERSION, rocks_dir)
    }, ';')
end

local pancake = require 'pancake'


-- Custom global environment
-- -------------------------

local M = {}

local assert = assert
local type = type
local setmetatable = setmetatable

local table = table
local utf8 = utf8

local pandoc = pandoc

local _ENV = M


-- Shorthands
-- ----------

local elem_walk = pancake.elem_walk
local insert = table.insert
local remove = table.remove
local tabulate = pancake.tabulate
local update = pancake.update
local xwarn = pancake.xwarn

local List = pandoc.List
local Span = pandoc.Span
local Str = pandoc.Str


--- Constants
-- @section

--- Mapping of RFC 5646-ish language codes to quotation marks.
--
-- Secondary quotation marks need to be given, even if a language
-- doesn't have any.
DB = setmetatable({
    bo          = {'「', '」',    '『', '』'    },
    bs          = {'”',  '”',     '’',  '’'    },
    cn          = {'「', '」',    '『', '』'    },
    cs          = {'„',  '“',     '‚',  '‘'    },
    cy          = {'‘',  '’',     '“',  '”'    },
    da          = {'»',  '«',     '›',  '‹'    },
    de          = {'„',  '“',     '‚',  '‘'    },
    ['de-CH']   = {'«',  '»',     '‹',  '›'    },
    el          = {'«',  '»',     '“',  '”'    },
    en          = {'“',  '”',     '‘',  '’'    },
    ['en-US']   = {'“',  '”',     '‘',  '’'    },
    ['en-GB']   = {'‘',  '’',     '“',  '”'    },
    ['en-UK']   = {'‘',  '’',     '“',  '”'    },
    ['en-CA']   = {'“',  '”',     '‘',  '’'    },
    eo          = {'“',  '”',     '‘',  '’'    },
    es          = {'«',  '»',     '“',  '”'    },
    et          = {'„',  '“',     '‚',  '‘'    },
    fi          = {'”',  '”',     '’',  '’'    },
    fil         = {'“',  '”',     '‘',  '’'    },
    fa          = {'«',  '»',     '‹',  '›'    },
    fr          = {'«',  '»',     '‹',  '›'    },
    ga          = {'“',  '”',     '‘',  '’'    },
    gd          = {'‘',  '’',     '“',  '”'    },
    gl          = {'«',  '»',     '‹',  '›'    },
    he          = {'“',  '”',     '‘',  '’'    },
    hi          = {'“',  '”',     '‘',  '’'    },
    hu          = {'„',  '”',     '»',  '«'    },
    hr          = {'„',  '“',     '‚',  '‘'    },
    ia          = {'“',  '”',     '‘',  '’'    },
    id          = {'“',  '”',     '‘',  '’'    },
    is          = {'„',  '“',     '‚',  '‘'    },
    it          = {'«',  '»',     '“',  '”'    },
    ['it-CH']   = {'«',  '»',     '‹',  '›'    },
    ja          = {'「', '」',     '『',  '』'    },
    jbo         = {'lu', 'li\'u', 'lu', 'li\'u'},
    ka          = {'„',  '“',     '‚',  '‘'    },
    khb         = {'《', '》',     '〈',  '〉'    },
    kk          = {'«',  '»',     '‹',  '›'    },
    km          = {'«',  '»',     '‹',  '›'    },
    ko          = {'《', '》',     '〈',  '〉'    },
    ['ko-KR']   = {'“',  '”',     '‘',  '’'    },
    lt          = {'„',  '“',     '‚',  '‘'    },
    lv          = {'„',  '“',     '‚',  '‘'    },
    lo          = {'«',  '»',     '‹',  '›'    },
    mk          = {'„',  '“',     '’',  '‘'    },
    mn          = {'«',  '»',     '‹',  '›'    },
    mt          = {'“',  '”',     '‘',  '’'    },
    nl          = {'„',  '”',     '‚',  '’'    },
    no          = {'«',  '»',     '«',  '»'    },
    pl          = {'„',  '”',     '»',  '«'    },
    ps          = {'«',  '»',     '‹',  '›'    },
    pt          = {'«',  '»',     '“',  '”'    },
    ['pt-BR']   = {'“',  '”',     '‘',  '’'    },
    rm          = {'«',  '»',     '‹',  '›'    },
    ro          = {'„',  '”',     '«',  '»'    },
    ru          = {'«',  '»',     '“',  '”'    },
    sk          = {'„',  '“',     '‚',  '‘'    },
    sl          = {'„',  '“',     '‚',  '‘'    },
    sq          = {'„',  '“',     '‚',  '‘'    },
    sr          = {'„',  '“',     '’',  '’'    },
    sv          = {'”',  '”',     '’',  '’'    },
    tdd         = {'「', '」',     '『',  '』'    },
    ti          = {'«',  '»',     '‹',  '›'    },
    th          = {'“',  '”',     '‘',  '’'    },
    thi         = {'「', '」',     '『',  '』'    },
    tr          = {'«',  '»',     '‹',  '›'    },
    ug          = {'«',  '»',     '‹',  '›'    },
    uk          = {'«',  '»',     '„',  '“'    },
    uz          = {'«',  '»',     '„',  '“'    },
    vi          = {'“',  '”',     '‘',  '’'    },
    wen         = {'„',  '“',     '‚',  '‘'    },
}, pancake.no_case)


--- Functions
-- @section

function check_marks (marks)
    if type(marks) == 'string' then
        marks = tabulate(marks:gmatch(utf8.charpattern))
    end
    local n = #marks
    local err
    if     n < 4 then err = 'not enough'
    elseif n > 4 then err = 'too many'
                 else return marks
    end
    return nil, err .. ' quotation marks given.'
end

function check_lang (lang)
    if lang:match '^(%a%a%a?)(%-?%a*)$' then return lang end
    return nil, lang .. ': not a RFC 5646 language code.'
end

local parser = pancake.Options(
    {
        prefix = 'quotation',
        name = 'marks',
        type = 'string|list',
        parse = check_marks
    },
    {
        name = 'quotation_lang',
        parse = check_lang
    },
    {
        name = 'lang',
        parse = check_lang
    }
)

function main (doc)
    local meta = doc.meta
    if not meta then return end

    local opts, err = parser:parse(meta)
    if not opts then
        xwarn('@error', '@plain', err)
        return
    end

    local marks = opts.marks
    local lang = opts.quotation_lang or opts.lang
    local db = update({}, DB)
    if not (marks or lang) then return end

    function lookup (lang)
        local marks = db[lang]
        if marks then return marks end
        lang = assert(lang:match '^%a+')
        local marks = db[lang]
        if marks then return marks end
        for tag, marks in pairs(db) do
            if db:match('^' .. lang .. '-') then
                return marks
            end
        end
    end

    local langs = {lang}
    local i = 1
    doc = elem_walk(doc, {AstElement = function (elem)
        local content = elem.content
        if not content then return end

        local pushed = false
        local attributes = elem.attributes
        if attributes then
            -- luacheck: ignore lang
            local lang = attributes.lang
            if lang then
                i = i + 1
                langs[i] = lang
                pushed = true
            end
        end

        for j = 1, #content do
            local child = content[j]
            local quotetype = child.quotetype
            if quotetype then
                -- luacheck: ignore lang marks
                local lang = langs[i]
                local marks = marks or lookup(lang)
                if marks then
                    -- luacheck: ignore content
                    local content = child.content
                    local l, r
                    if     quotetype == 'DoubleQuote' then l, r = 1, 2
                    elseif quotetype == 'SingleQuote' then l, r = 3, 4
                    else   error(quotetype .. ': unknown quote type.', 0)
                    end
                    -- @todo Add classes.
                    elem.content[j] = Span(List:new{
                        Str(marks[l]),
                        Span(content),
                        Str(marks[r])
                    })
                else
                    xwarn('@error', '${lang}: no quotation marks defined.')
                end
            end
        end

        if pushed then
            remove(langs, i)
            i = i - 1
        end
        return parent
    end})
    return doc
end

return {{Pandoc = main}}
