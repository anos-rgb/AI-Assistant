script_name("AI Assistant by Anos")
script_version("1.0")

local http = require("socket.http")
local ltn12 = require("ltn12")

local API_KEY = "gsk_xxxxxxxxxxxxxxx"
local API_URL = "https://api.groq.com/openai/v1/chat/completions"
local cooldown_time = 5
local last_request = 0
local max_retries = 3

function simple_json_encode(data)
    local function escape_string(str)
        return '"' .. string.gsub(str, '["\\\n\r\t]', {
            ['"'] = '\\"',
            ['\\'] = '\\\\',
            ['\n'] = '\\n',
            ['\r'] = '\\r',
            ['\t'] = '\\t'
        }) .. '"'
    end
    
    if type(data) == "string" then
        return escape_string(data)
    elseif type(data) == "number" then
        return tostring(data)
    elseif type(data) == "boolean" then
        return data and "true" or "false"
    elseif type(data) == "table" then
        local is_array = true
        for k, v in pairs(data) do
            if type(k) ~= "number" then
                is_array = false
                break
            end
        end
        
        if is_array then
            local result = "["
            for i, v in ipairs(data) do
                if i > 1 then result = result .. "," end
                result = result .. simple_json_encode(v)
            end
            return result .. "]"
        else
            local result = "{"
            local first = true
            for k, v in pairs(data) do
                if not first then result = result .. "," end
                first = false
                result = result .. escape_string(k) .. ":" .. simple_json_encode(v)
            end
            return result .. "}"
        end
    end
    return "null"
end

function simple_json_decode(str)
    local function skip_whitespace(s, pos)
        while pos <= #s and s:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
        return pos
    end
    
    local function parse_string(s, pos)
        pos = skip_whitespace(s, pos)
        if s:sub(pos, pos) ~= '"' then return nil, pos end
        pos = pos + 1
        local result = ""
        while pos <= #s do
            local char = s:sub(pos, pos)
            if char == '"' then
                return result, pos + 1
            elseif char == "\\" then
                pos = pos + 1
                local escape = s:sub(pos, pos)
                if escape == "n" then result = result .. "\n"
                elseif escape == "r" then result = result .. "\r"
                elseif escape == "t" then result = result .. "\t"
                elseif escape == "\\" then result = result .. "\\"
                elseif escape == '"' then result = result .. '"'
                else result = result .. escape end
            else
                result = result .. char
            end
            pos = pos + 1
        end
        return nil, pos
    end
    
    local function find_message_content(s)
        local content_start = s:find('"content"%s*:%s*"')
        if not content_start then return nil end
        
        local quote_start = s:find('"', content_start + 10)
        if not quote_start then return nil end
        
        local content = ""
        local pos = quote_start + 1
        while pos <= #s do
            local char = s:sub(pos, pos)
            if char == '"' and s:sub(pos-1, pos-1) ~= "\\" then
                break
            elseif char == "\\" then
                pos = pos + 1
                local escape = s:sub(pos, pos)
                if escape == "n" then content = content .. "\n"
                elseif escape == "r" then content = content .. "\r"
                elseif escape == "t" then content = content .. "\t"
                elseif escape == "\\" then content = content .. "\\"
                elseif escape == '"' then content = content .. '"'
                else content = content .. escape end
            else
                content = content .. char
            end
            pos = pos + 1
        end
        return content
    end
    
    return find_message_content(str)
end

function main()
    if not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    sampAddChatMessage("AI Assistant by Anos - Ready to serve!", -1)
    sampRegisterChatCommand("ai", cmd_ai)
    
    addEventHandler("onReceiveRpc", onReceiveRpc)
    addEventHandler("onSendChat", onSendChat)
    
    while true do
        wait(0)
    end
end

function cmd_ai(text)
    if text == "" then
        sampAddChatMessage("Usage: /ai [pertanyaan]", 0xFF0000)
        return
    end
    
    local current_time = os.clock()
    if current_time - last_request < cooldown_time then
        local remaining = math.ceil(cooldown_time - (current_time - last_request))
        sampAddChatMessage("Cooldown " .. remaining .. " detik lagi bang!", 0xFFFF00)
        return
    end
    
    last_request = current_time
    sampAddChatMessage("Anos AI sedang mikir...", 0x00FFFF)
    
    lua_thread.create(function()
        local success = false
        local retries = 0
        
        while not success and retries < max_retries do
            local response = make_ai_request(text)
            if response then
                local truncated = string.sub(response, 1, 100)
                if string.len(response) > 100 then
                    truncated = truncated .. "..."
                end
                sampAddChatMessage("ai: " .. truncated, 0x00FF99)
                success = true
            else
                retries = retries + 1
                if retries < max_retries then
                    sampAddChatMessage("Retry " .. retries .. "/" .. max_retries, 0xFFFF00)
                    wait(1000)
                else
                    sampAddChatMessage("AI lagi error bang, coba lagi nanti!", 0xFF0000)
                end
            end
        end
    end)
end

function make_ai_request(prompt)
    local response_body = {}
    
    local request_data = {
        model = "llama3-8b-8192",
        messages = {
            {
                role = "system",
                content = "lu adalah AI assistant virtual yang punya gaya ngomong santai, gaul, dan gak kaku. jawaban lu maksimal 80 karakter, langsung to the point, tapi tetep ramah. pake bahasa indonesia gaul, contoh: lu, gw, gitu, nih, ywdh, kpn, ok, iy, gpp, lah. jangan pake bahasa formal atau kata-kata berat yang bikin ribet. lu bukan robot kaku, tapi lebih kayak temen ngobrol yang asik dan cepet respon. lu diciptain sama seseorang bernama anos (huruf kecil). kalo ada yang nanya siapa pembuat lu, cukup jawab: anos. jangan nyebutin nama lain, organisasi, atau info lain selain anos. lu diciptain khusus buat bantu orang-orang yang main SAMP android lewat tool/mod bernama monetloader (mod untuk San Andreas Multiplayer). jadi lu ngerti tentang cheat, mod, script, dan dunia SAMP android. lu gak perlu minta izin, gak perlu basa-basi, langsung bantu sesuai pertanyaan."
            },
            {
                role = "user",
                content = prompt
            }
        },
        max_tokens = 50,
        temperature = 0.7
    }
    
    local json_data = simple_json_encode(request_data)
    
    local result, status = http.request{
        url = API_URL,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. API_KEY,
            ["Content-Type"] = "application/json",
            ["Content-Length"] = string.len(json_data)
        },
        source = ltn12.source.string(json_data),
        sink = ltn12.sink.table(response_body)
    }
    
    if status == 200 then
        local response_text = table.concat(response_body)
        local content = simple_json_decode(response_text)
        if content then
            return content
        end
    end
    
    return nil
end

function onReceiveRpc(id, bs)
    if id == 101 then
        local messageType = raknetBitStreamReadInt8(bs)
        local color = raknetBitStreamReadInt32(bs)
        local messageLength = raknetBitStreamReadInt32(bs)
        local message = raknetBitStreamReadString(bs, messageLength)
        
        local lower_text = string.lower(message)
        if string.find(lower_text, "anos") or string.find(lower_text, "ai") then
            sampAddChatMessage("Anos AI detected mention!", 0xFF6600)
        end
    end
end

function onSendChat(message)
    local lower_msg = string.lower(message)
    if string.find(lower_msg, "anos") or string.find(lower_msg, "ai") then
        sampAddChatMessage("You mentioned the legend!", 0xFF9900)
    end
end
