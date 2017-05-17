-- @Author: Administrator
-- @Date:   2016-11-21 19:15:01
-- @Last Modified by:   Administrator
-- @Last Modified time: 2016-11-21 20:32:55

local CLIENT_LANG = select(3, GetVersion())
local JH_CALL_AJAX = {}
local JH_AJAX_TAG  = "JH_AJAX#" -- event CURL_REQUEST_RESULT arg0
local tinsert, tconcat = table.insert, table.concat

local Curl   = {}
Curl.__index = Curl

local function console_log(message)
	Log("[JH] " .. message)
end

local conf_default = {
	charset  = 'utf8',
	type     = 'post',
	data     = {},
	dataType = "text",
	ssl      = false,
	timeout  = 3,
	-- done
	success = function(szContent, dwBufferSize, option)
		console_log("Curl " .. option.url .. " - success")
	end,
	error = function(szContent, dwBufferSize, option)
		console_log("Curl " .. option.url .. " - error")
	end,
}

local function ConvertToUTF8(data)
	if type(data) == "table" then
		local t = {}
		for k, v in pairs(data) do
			if type(k) == "string" then
				t[ConvertToUTF8(k)] = ConvertToUTF8(v)
			else
				t[k] = ConvertToUTF8(v)
			end
		end
		return t
	elseif type(data) == "string" then
		return AnsiToUTF8(data)
	else
		return data
	end
end

local function EncodePostData(data, t, prefix)
	if type(data) == "table" then
		local first = true
		for k, v in pairs(data) do
			if first then
				first = false
			else
				tinsert(t, "&")
			end
			if prefix == "" then
				EncodePostData(v, t, k)
			else
				EncodePostData(v, t, prefix .. "[" .. k .. "]")
			end
		end
	else
		if prefix ~= "" then
			tinsert(t, prefix)
			tinsert(t, "=")
		end
		tinsert(t, data)
	end
end

local function serialize(data)
	local t = {}
	EncodePostData(data, t, "")
	local text = tconcat(t)
	return text
end

-- constructor
function Curl:ctor(option)
	assert(option and option.url)
	local oo = {}
	setmetatable(oo, self)
	setmetatable(option, { __index = conf_default })
	local szKey = GetTickCount() * 100
	while JH_CALL_AJAX[JH_AJAX_TAG .. szKey] do
		szKey = szKey + 1
	end
	szKey = JH_AJAX_TAG .. szKey
	JH_CALL_AJAX[szKey] = option
	local url, data = option.url, option.data
	if option.charset:lower() == "utf8" then
		url  = ConvertToUTF8(url)
		data = ConvertToUTF8(data)
	end
	if string.sub(url, 1, 6) == "https:" then
		option.ssl = true
	end
	if option.type:lower() == "post" then
		CURL_HttpPost(szKey, url, data, option.ssl, option.timeout)
	elseif option.type:lower() == "get" then
		data = serialize(data)
		if not url:find("?") then
			url = url .. "?"
		elseif url:sub(-1) ~= "&" then
			url = url .. "&"
		end
		url = url .. data
		CURL_HttpRqst(szKey, url, option.ssl, option.timeout)
	end
	oo.szKey = szKey
	return oo
end

function Curl:done(success)
	local option = JH_CALL_AJAX[self.szKey]
	if option then
		option.success = success
	end
	return self
end

function Curl:fail(error)
	local option = JH_CALL_AJAX[self.szKey]
	if option then
		option.error = error
	end
	return self
end

function Curl:always(complete)
	local option = JH_CALL_AJAX[self.szKey]
	if option then
		option.complete = complete
	end
	return self
end


JH.RegisterEvent("CURL_REQUEST_RESULT.AJAX", function()
	local szKey        = arg0
	local bSuccess     = arg1
	local szContent    = arg2
	local dwBufferSize = arg3
	if JH_CALL_AJAX[szKey] then
		local option = JH_CALL_AJAX[szKey]
		local fnError = option.error
		local bError = not bSuccess
		if option.complete then
			local status, err = pcall(option.complete, szContent, dwBufferSize, option)
			if not status then
				JH.Debug("CURL # " .. option.url .. ' - complete - PCALL ERROR - ' .. err)
			end
		end
		if bSuccess then
			if option.charset:lower() == "utf8" and szContent ~= nil and CLIENT_LANG == "zhcn" then
				szContent = UTF8ToAnsi(szContent)
			end
			if option.dataType == "json" then
				local result, err = JH.JsonDecode(szContent)
				if result then
					szContent = result
				else
					JH.Debug("CURL # JsonDecode ERROR")
					bError = true
				end
			end
			local status, err = pcall(option.success, szContent, dwBufferSize, option)
			if not status then
				JH.Debug("CURL # " .. option.url .. ' - success - PCALL ERROR - ' .. err)
			end
		end
		if bError then
			local status, err = pcall(fnError, "failed", dwBufferSize, option)
			if not status then
				JH.Debug("CURL # " .. option.url .. ' - error - PCALL ERROR - ' .. err)
			end
		end
		JH_CALL_AJAX[szKey] = nil
	end
end)

JH.Curl = setmetatable({}, { __call = function(me, ...) return Curl:ctor( ... ) end, __newindex = function() end, __metatable = true })

-- function JH.Get()
-- end

-- function JH.Post()
-- end