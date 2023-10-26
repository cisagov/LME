-- latex-emoji.lua
--
-- @copyright 2020 Takayuki YATO (aka. "ZR")
--   GitHub:   https://github.com/zr-tex8r
--   Twitter:  @zr_tex8r
--   This program is distributed under the MIT License.
--
local filter_name = 'latex-emoji'
---------------------------------------- helpers

--- Show debug log?
local show_log = true
--- The default emoji font
local default_emojifont = 'TwemojiMozilla.ttf'

--- Use bxcoloremoji package?
local bxcoloremoji = false
--- The emoji font to use
local emojifont, emojifontoptions = nil
--- All used codepoints
local ucs_used = {}
--- The number of emoji text spans.
local text_count = 0

local utils = require 'pandoc.utils'
local concat, insert, pack, unpack =
  table.concat, table.insert, table.pack, table.unpack

--- Shows a debug log.
local function log(fmt, ...)
  if not show_log then return end
  io.stderr:write(filter_name..": "..fmt:format(...).."\n")
end

--- Aborts with an error message.
local function abort(fmt, ...)
  error(filter_name..": "..fmt:format(...))
end

--- Returns the Pandoc-or-ordinary type of v.
-- @return A string that says type name.
local function pantype(v)
  local t = type(v)
  return (t == 'table') and v.t or t
end

--- Makes a comma-separated value string.
-- @return A string.
local function clist(...)
  local t, u = pack(...), {}
  for i = 1, t.n do
    local v = (t[i] == nil) and '' or tostring(t[i])
    if v ~= '' then insert(u, v) end
  end
  return concat(u, ',')
end

--- Makes the sorted sequence of all keys of a given table.
-- @return A sequence of strings.
local function keys(t)
  local u = {}
  for k in pairs(t) do insert(u, k) end
  table.sort(u)
  return u
end

--- Converts a singleton sequence to its element.
-- @return The sole element of v if v is a singleton;
--   v if v is not a table; otherwise an error is issued.
local function tosingle(v, l)
  if type(v) ~= 'table' then return v end
  if #v == 1 then return tosingle(v[1], l) end
  abort("multiple values given: %s", l)
end

--- Converts a value to a singleton sequence.
-- @return The empty table if v is nil; v if v is a table;
--   otherwise the singleton of v.
local function toseq(v)
  if v == nil then return {}
  elseif type(v) == 'table' then return v
  else return {v}
  end
end

--- Converts MetaInlines values inside a MetaValue to strings.
-- @return The converted value. (v is not modified.)
local function tostring_meta(v, l)
  if type(v) ~= 'table' then return v end
  if v.t == 'MetaList' or v.t == nil then
    local r = {}
    for k, e in pairs(v) do r[k] = tostring_meta(e, l) end
    return r
  elseif v.t == 'MetaInlines' then
    return utils.stringify(v)
  else abort("cannot stringify: %s", v.t, l)
  end
end

--- Gets the source to go into the header.
-- @return LaTeX source string
local function get_header()
  if not bxcoloremoji or not next(ucs_used) then
    return nil
  end
  return ([[
\usepackage[%s]{bxcoloremoji}
\newcommand*{\panEmoji}{\coloremoji}
]]):format(clist(emojifont, unpack(emojifontoptions)))
end

--- Gets the source to go into the head of body.
-- @return LaTeX source string
local function get_prologue()
  if bxcoloremoji or not next(ucs_used) then
    return nil
  end
  local fname = emojifont or default_emojifont
  local fopts = clist('Renderer=HarfBuzz', unpack(emojifontoptions));
  local ucs = keys(ucs_used)
  for i = 1, #ucs do
    ucs[i] = ('"%X'):format(ucs[i])
  end
  local dcrsrc = concat(ucs, ',\n')
  return ([[
\makeatletter
\ifnum0\ifdefined\directlua\directlua{
    if ("\luaescapestring{\luatexbanner}"):match("LuaHBTeX") then tex.write("1") end
    }\fi>\z@ %% LuaHBTeX is ok
  \setfontface\p@emoji@font{%s}[%s]
\else
  \@latex@error{You must install a new TeX system (TeX Live 2020)\MessageBreak
    and then use 'lualatex' engine to print emoji}
   {The compilation will be aborted.}
  \let\p@emoji@font\relax
\fi
\ifdefined\ltjdefcharrange
\ltjdefcharrange{208}{
%s}
\ltjsetparameter{jacharrange={-208}}
\fi
\newcommand*{\panEmoji}[1]{{\p@emoji@font#1}}
\makeatother
]]):format(fname, fopts, dcrsrc)
end

--- For debug.
local function inspect(v)
  local t = type(v)
  if t == 'userdata' or t == 'function' or t == 'nil' then return t
  elseif t == 'table' then
    local u, tag = {}, (v.t or 'table')
    if tag == 'Str' then return tag..'{'..v.text..'}' end
    for i = 1, #v do u[i] = inspect(v[i]) end
    return tag..'{'..concat(u, ';')..'}'
  else return tostring(v)
  end
end

---------------------------------------- phase 'readmeta'

--- For Meta elements.
local function readmeta_Meta (meta)
  -- bxcoloremoji
  if meta.bxcoloremoji == nil then
    bxcoloremoji = false
  elseif type(meta.bxcoloremoji) == 'boolean' then
    bxcoloremoji = meta.bxcoloremoji
  else
    abort("not a boolean value: bxcoloremoji")
  end
  --log('bxcoloremoji = %s', bxcoloremoji)
  -- emojifont
  emojifont = tostring_meta(meta.emojifont, "emojifont")
  emojifont = tosingle(emojifont, "emojifont")
  --log('emojifont = %s', emojifont)
  -- emojifontoptions
  emojifontoptions = tostring_meta(meta.emojifontoptions, "emojifontoptions")
  emojifontoptions = toseq(emojifontoptions)
  for i in ipairs(emojifontoptions) do
    emojifontoptions[i] = tosingle(emojifontoptions[i], "emojifontoptions element")
    --log('emojifontoptions = %s', emojifontoptions[i])
  end
end

---------------------------------------- phase 'mainproc'

--- For Span element.
local function mainproc_Span(span)
  if span.classes:includes('emoji', 1) then
    text_count = text_count + 1
    local str = utils.stringify(span.content)
    for p, uc in utf8.codes(str) do
      if not ucs_used[uc] and uc >= 0x100 then
        --log("emoji character: U+%04X", uc)
        ucs_used[uc] = true
      end
    end
    insert(span.content, 1, pandoc.RawInline('latex', [[\panEmoji{]]))
    insert(span.content, pandoc.RawInline('latex', [[}]]))
    return span.content
  end
end

--- For Meta elements.
local function mainproc_Meta(meta)
  local src = get_header()
  if src then
    local headers = meta['header-includes']
    if headers == nil then
      headers = pandoc.MetaList({})
    elseif pantype(headers) == 'MetaList' then
      abort("unexpected metavalue type: header-includes")
    end
    insert(headers, pandoc.MetaBlocks{pandoc.RawBlock('latex', src)})
    meta['header-includes'] = headers
    --log("header successfully appended")
    return meta
  end
end

--- For the whole document.
local function mainproc_Pandoc(doc)
  --log("number of emoji spans: %s", text_count)
  local src = get_prologue()
  if src then
    insert(doc.blocks, 1, pandoc.RawBlock('latex', src))
    --log("prologue successfully inserted")
    return doc
  end
end

---------------------------------------- the filter
if FORMAT == 'latex' then
  return {
    {-- phase 'readmeta'
      Meta = readmeta_Meta;
    };
    {-- phase 'mainproc'
      Span = mainproc_Span;
      Meta = mainproc_Meta;
      Pandoc = mainproc_Pandoc;
    };
  }
else
  log("format '%s' in not supported", FORMAT)
end
---------------------------------------- done

