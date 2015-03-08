--[[
  @file
  Lua port of PHP serialization functions.

  Port based on PHPSerialize and PHPUnserialize by Scott Hurring
  http://hurring.com/scott/code/python/serialize/v0.4

  @version v0.1 BETA
  @author Fernando P. García; fernando at develcuy dot com
  @copyright Copyright (c) 2009 Fernando P. García
  @license http://opensource.org/licenses/gpl-license.php GNU Public License

  $Id$
]]

local _serialize_key, _read_chars, _read_until, _unknown_type

function _serialize_key(data)
  --[[
  Serialize a key, which follows different rules than when
  serializing values.  Many thanks to Todd DeLuca for pointing
  out that keys are serialized differently than values!

  From http://us2.php.net/manual/en/language.types.array.php
  A key may be either an integer or a string.
  If a key is the standard representation of an integer, it will be
  interpreted as such (i.e. "8" will be interpreted as int 8,
  while "08" will be interpreted as "08").
  Floats in key are truncated to integer.
  ]]

  -- Integer, Long, Float
  if type(data) == 'number' then
    return 'i:' .. tonumber(data) .. ';'

  -- Boolean => integer
  elseif type(data) == 'boolean' then
    if data then
      return 'i:1;'
    else
      return 'i:0;'
    end

  -- String => string or String => int (if string looks like int)
  elseif type(data) == 'string' then
    if tonumber(data) == nil then
      return 's:' .. string.len(data) .. ':"' .. data .. '";'
    else
      return 'i:' .. tonumber(data) .. ';'
    end

  -- None / NULL => empty string
  elseif type(data) == 'nil' then
    return 's:0:"";'

  -- I dont know how to serialize this
  else
    error('Unknown / Unhandled key  type (' .. type(data) .. ')!')
  end
end

function serialize(data)
  --[[
  Serialize a value.
  ]]

  local i, out, key, value

  -- Numbers
  if type(data) == 'number' then
    -- Integer => integer
    if  math.floor(data) == data then
      return 'i:' .. data .. ';'
    -- Float, Long => double
    else
      return 'd:' .. data .. ';'
    end

  -- String => string or String => int (if string looks like int)
  -- Thanks to Todd DeLuca for noticing that PHP strings that
  -- look like integers are serialized as ints by PHP
  elseif type(data) == 'string' then
    if tonumber(data) == nil then
      return 's:' .. string.len(data) .. ':"' .. data .. '";'
    else
      return 'i:' .. tonumber(data) .. ';'
    end

  -- Nil / NULL
  elseif type(data) == 'nil' then
    return 'N;'

  -- Tuple and List => array
  -- The 'a' array type is the only kind of list supported by PHP.
  -- array keys are automagically numbered up from 0
  elseif type(data) == 'table' then
    i = 0
    out = {}
    -- All arrays must have keys
    for key, value in pairs(data) do
      table.insert(out, _serialize_key(key))
      table.insert(out, serialize(value))
      i = i + 1
    end
    return 'a:' .. i .. ':{' .. table.concat(out) .. '}'

  -- Boolean => bool
  elseif type(data) == 'boolean' then
    if data then
      return 'b:1;'
    else
      return 'b:0;'
    end

  --~ TODO:
  --~ -- Table + Functions => stdClass
  --~ elseif type(data) == 'function' then

  --~ # I dont know how to serialize this
  else
   error('Unknown / Unhandled data type (' .. type(data) .. ')!')
  end
end

function _read_until(data, offset, stopchar)
  --[[
  Read from data[offset] until you encounter some char 'stopchar'.
  ]]

  local buf = {}
  local char = string.sub(data, offset + 1, offset + 1)
  local i = 2
  while not (char == stopchar) do
    -- Consumed all the characters and havent found ';'
    if i + offset > string.len(data) then
      error('Invalid')
    end
    table.insert(buf, char)
    char = string.sub(data, offset + i, offset + i)
    i = i + 1
  end
  -- (chars_read, data)
  return i - 2, table.concat(buf)
end

function _read_chars(data, offset, length)
  --[[
  Read 'length' number of chars from data[offset].
  ]]

  local buf = {}, char
  -- Account for the starting quote char
  -- offset += 1
  for i = 0, length -1 do
    char = string.sub(data, offset + i, offset + i)
    table.insert(buf, char)
  end

  -- (chars_read, data)
  return length, table.concat(buf)
end

function unserialize(data, offset)
  offset = offset or 0

  --[[
  Find the next token and unserialize it.
  Recurse on array.

  offset = raw offset from start of data
  --]]

  local buf, dtype, dataoffset, typeconvert, datalength, chars, readdata, i,
         key, value, keys, properties, otchars, otype, property

  buf = {}
  dtype = string.lower(string.sub(data, offset + 1, offset + 1))

  -- 't:' = 2 chars
  dataoffset = offset + 2
  typeconvert = function(x) return x end
  datalength = 0
  chars = datalength

  -- int or double => Number
  if dtype == 'i' or dtype == 'd' then
    typeconvert = function(x) return tonumber(x) end
    chars, readdata = _read_until(data, dataoffset, ';')
    -- +1 for end semicolon
    dataoffset = dataoffset + chars + 1

  -- bool => Boolean
  elseif dtype == 'b' then
    typeconvert = function(x) return tonumber(x) == 1 end
    chars, readdata = _read_until(data, dataoffset, ';')
    -- +1 for end semicolon
    dataoffset = dataoffset + chars + 1

  -- n => None
  elseif dtype == 'n' then
    readdata = nil

  -- s => String
  elseif dtype == 's' then
    chars, stringlength = _read_until(data, dataoffset, ':')
    -- +2 for colons around length field
    dataoffset = dataoffset + chars + 2

    -- +1 for start quote
    chars, readdata = _read_chars(data, dataoffset + 1, tonumber(stringlength))
    -- +2 for endquote semicolon
    dataoffset = dataoffset + chars + 2

    --[[
    TODO
    review original: if chars != int(stringlength) != int(readdata):
    ]]
    if not (chars == tonumber(stringlength)) then
      error('String length mismatch')
    end

  -- array => Table
  -- If you originally serialized a Tuple or List, it will
  -- be unserialized as a Dict.  PHP doesn't have tuples or lists,
  -- only arrays - so everything has to get converted into an array
  -- when serializing and the original type of the array is lost
  elseif dtype == 'a' then
    readdata = {}

    -- How many keys does this list have?
    chars, keys = _read_until(data, dataoffset, ':')
    -- +2 for colons around length field
    dataoffset = dataoffset + chars + 2

    -- Loop through and fetch this number of key/value pairs
    for i = 0, tonumber(keys) - 1 do
      -- Read the key
      key, ktype, kchars = unserialize(data, dataoffset)
      dataoffset = dataoffset + kchars

      -- Read value of the key
      value, vtype, vchars = unserialize(data, dataoffset)
      -- Cound ending bracket of nested array
      if vtype == 'a' then
        vchars = vchars + 1
      end
      dataoffset = dataoffset + vchars

      -- Set the list element
      readdata[key] = value
    end
  -- object => Table
  elseif dtype == 'o' then
    readdata = {}

    -- How log is the type of this object?
    chars, otchars = _read_until(data, dataoffset, ':')
    dataoffset = dataoffset + chars + 2

    -- Which type is this object?
    otype = string.sub(data, dataoffset + 1, dataoffset + otchars)
    dataoffset = dataoffset + otchars + 2

    if otype == 'stdClass' then
      -- How many properties does this list have?
      chars, properties = _read_until(data, dataoffset, ':')

      -- +2 for colons around length field
      dataoffset = dataoffset + chars + 2

      -- Loop through and fetch this number of key/value pairs
      for i = 0, tonumber(properties) - 1 do
        -- Read the key
        property, ktype, kchars = unserialize(data, dataoffset)
        dataoffset = dataoffset + kchars

        -- Read value of the key
        value, vtype, vchars = unserialize(data, dataoffset)
        -- Cound ending bracket of nested array
        if vtype == 'a' then
          vchars = vchars + 1
        end
        dataoffset = dataoffset + vchars

        -- Set the list element
        readdata[property] = value
      end
    else
      _unknown_type(dtype)
    end
  else
    _unknown_type(dtype)
  end

  --~ return (dtype, dataoffset-offset, typeconvert(readdata))
  return typeconvert(readdata), dtype, dataoffset - offset
end

-- I don't know how to unserialize this
function _unknown_type(type_)
  error('Unknown / Unhandled data type (' .. type_ .. ')!', 2)
end
