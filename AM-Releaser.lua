local USER_KEY = "RH-P4UVG-O2C5Q-67KCY" -- Sold

repeat task.wait() until game:GetService("Players").LocalPlayer
repeat task.wait() until game:IsLoaded()

-- CONFIG
local API_URL = "https://rh-script-loader.dxbjamie.workers.dev/"  -- trailing slash matters for some HTTP stacks
local DEBUG = true  -- Set false in production to hide diagnostic output

local SCRIPTS_TO_LOAD = {
    "AMReleaserGUI.lua",
}

local HttpService = game:GetService("HttpService")

-- ─── HWID generation (unchanged) ────────────────────────────────────────────
local function getHWID()
    local hwid = ""

    pcall(function()
        if gethwid then hwid = hwid .. tostring(gethwid())
        elseif get_hwid then hwid = hwid .. tostring(get_hwid())
        elseif getexecutorhwid then hwid = hwid .. tostring(getexecutorhwid())
        end
    end)

    pcall(function()
        hwid = hwid .. tostring(game:GetService("RbxAnalyticsService"):GetClientId())
    end)

    pcall(function()
        if identifyexecutor then
            local name = identifyexecutor()
            hwid = hwid .. tostring(name)
        end
    end)

    if hwid == "" then
        hwid = "FALLBACK-" .. tostring(os.time())
    end

    local hash = 0
    for i = 1, #hwid do
        hash = (hash * 31 + string.byte(hwid, i)) % 2147483647
    end

    return "HWID-" .. tostring(hash)
end

local HWID = getHWID()

-- ─── URL building with safe encoding ───────────────────────────────────────
-- Roblox's HttpService:UrlEncode is overzealous — it encodes "-" and other
-- safe characters, which can break server-side string matching.
-- We only encode characters that genuinely need encoding.
local function safeEncode(s)
    s = tostring(s)
    -- Encode anything that isn't alphanumeric, dash, underscore, dot, or tilde
    -- (these are RFC 3986 "unreserved" characters and never need encoding)
    return (s:gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function buildUrl(params)
    local parts = {}
    for k, v in pairs(params) do
        table.insert(parts, safeEncode(k) .. "=" .. safeEncode(v))
    end
    return API_URL .. "?" .. table.concat(parts, "&")
end

-- ─── HTTP layer with multi-executor fallback ────────────────────────────────
-- Returns: { Success = bool, StatusCode = num, Body = string } OR nil + error
local function httpGet(url)
    local errors = {}

    -- Try 1: executor's request() — most common, works on most paid executors
    local httpFn = request
        or http_request
        or (syn and syn.request)
        or (fluxus and fluxus.request)
        or (http and http.request)

    if httpFn then
        local ok, resp = pcall(httpFn, {
            Url = url,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "Mozilla/5.0 (RobloxLoader)",
                ["Cache-Control"] = "no-cache"
            }
        })

        if ok and resp then
            -- Some executors use StatusCode, some Status, some StatusMessage
            local code = resp.StatusCode or resp.Status or 0
            local body = resp.Body or ""
            local success = resp.Success
            -- If Success flag missing, infer from status code
            if success == nil then success = (code >= 200 and code < 300) end

            return {
                Success = success,
                StatusCode = code,
                Body = body
            }
        else
            table.insert(errors, "request() failed: " .. tostring(resp))
        end
    else
        table.insert(errors, "no executor request() function found")
    end

    -- Try 2: HttpService:RequestAsync (server-side normally, but some executors patch it)
    local ok, resp = pcall(function()
        return HttpService:RequestAsync({ Url = url, Method = "GET" })
    end)
    if ok and resp then
        return {
            Success = resp.Success,
            StatusCode = resp.StatusCode,
            Body = resp.Body or ""
        }
    else
        table.insert(errors, "RequestAsync failed: " .. tostring(resp))
    end

    -- Try 3: HttpGet — works almost everywhere because it routes via Roblox's HTTP
    -- Trade-off: returns body only, no status code, throws on non-200
    local ok2, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok2 and body then
        return {
            Success = true,
            StatusCode = 200,  -- assumed
            Body = body
        }
    else
        table.insert(errors, "HttpGet failed: " .. tostring(body))
    end

    return nil, table.concat(errors, " | ")
end

-- ─── API calls ──────────────────────────────────────────────────────────────
local function checkKeyStatus()
    local url = buildUrl({
        key = USER_KEY,
        hwid = HWID,
        check = "true"
    })

    if DEBUG then
        warn("[LOADER:DEBUG] URL: " .. url)
    end

    local resp, err = httpGet(url)
    if not resp then
        if DEBUG then warn("[LOADER:DEBUG] checkKeyStatus transport: " .. tostring(err)) end
        return nil
    end

    if DEBUG then
        warn("[LOADER:DEBUG] HTTP " .. tostring(resp.StatusCode) ..
             " | body length " .. tostring(#resp.Body))
    end

    if not resp.Success then
        if DEBUG then warn("[LOADER:DEBUG] body preview: " .. resp.Body:sub(1, 200)) end
        return nil
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(resp.Body)
    end)

    if not ok then
        if DEBUG then warn("[LOADER:DEBUG] JSON decode failed. Body: " .. resp.Body:sub(1, 200)) end
        return nil
    end

    return data
end

local function loadScript(fileName)
    local url = buildUrl({
        key = USER_KEY,
        hwid = HWID,
        file = fileName
    })

    local resp, err = httpGet(url)
    if not resp then
        return nil, "request_failed: " .. tostring(err)
    end

    if resp.Success then
        return resp.Body, "success"
    end

    if resp.StatusCode == 403 then
        local body = resp.Body or ""
        if body:find("expired") then
            return nil, "key_expired"
        elseif body:find("not allocated") then
            return nil, "key_not_allocated"
        elseif body:find("another device") or body:find("device limit") or body:find("already in use") then
            return nil, "hwid_mismatch"
        else
            return nil, "invalid_key"
        end
    elseif resp.StatusCode == 404 then
        return nil, "not_found"
    else
        return nil, "error_" .. tostring(resp.StatusCode)
    end
end

-- ─── UI / flow (largely unchanged) ──────────────────────────────────────────
print("")
print("╔════════════════════════════════════════╗")
print("║         AM Item Releaser LOADER        ║")
print("╚════════════════════════════════════════╝")
print("")
print("[LOADER] Validating key...")
print("[LOADER] Device ID: " .. HWID)

if DEBUG then
    -- Report which HTTP function was detected
    local fn = (request and "request")
        or (http_request and "http_request")
        or (syn and syn.request and "syn.request")
        or (fluxus and fluxus.request and "fluxus.request")
        or "none (will fall back to HttpGet)"
    print("[LOADER:DEBUG] HTTP function: " .. fn)
    local execName = "unknown"
    pcall(function() if identifyexecutor then execName = (identifyexecutor()) end end)
    print("[LOADER:DEBUG] Executor: " .. tostring(execName))
end

local keyStatus = checkKeyStatus()

if not keyStatus then
    warn("")
    warn("╔════════════════════════════════════════╗")
    warn("║   ✗ CONNECTION ERROR                   ║")
    warn("╚════════════════════════════════════════╝")
    warn("")
    warn("Could not connect to server.")
    warn("Please check your internet connection.")
    if DEBUG then
        warn("Send the [LOADER:DEBUG] lines above to support.")
    end
    return
end

if not keyStatus.valid then
    warn("")
    warn("╔════════════════════════════════════════╗")
    if keyStatus.reason == "key_expired" then
        warn("║   ✗ KEY EXPIRED                        ║")
        warn("╚════════════════════════════════════════╝")
        warn("")
        warn("Your key expired on: " .. (keyStatus.expiredOn or "Unknown"))
        warn("First activated: " .. (keyStatus.firstUsed or "Unknown"))
    elseif keyStatus.reason == "key_not_allocated" then
        warn("║   ✗ KEY NOT ACTIVATED                  ║")
        warn("╚════════════════════════════════════════╝")
        warn("")
        warn("This key has not been assigned yet.")
    elseif keyStatus.reason == "hwid_mismatch" or keyStatus.reason == "hwid_limit_reached" then
        warn("║   ✗ DEVICE LIMIT REACHED               ║")
        warn("╚════════════════════════════════════════╝")
        warn("")
        if keyStatus.maxHwids then
            warn("This key is already active on " .. tostring(keyStatus.maxHwids) .. " device(s).")
        else
            warn("This key is locked to another device.")
        end
    else
        warn("║   ✗ INVALID KEY                        ║")
        warn("╚════════════════════════════════════════╝")
    end
    warn("")
    warn("Your key: " .. USER_KEY)
    warn("Please contact support for help.")
    return
end

print("")
print("╔════════════════════════════════════════╗")
print("║   ✓ KEY ACCEPTED - WELCOME!            ║")
print("╚════════════════════════════════════════╝")
print("")
print("   License Type: " .. keyStatus.level)
print("   Device Lock: " .. (keyStatus.hwid or "Active"))

if keyStatus.expiry == "Never" then
    print("   Status: LIFETIME ACCESS")
    print("   Expires: Never")
else
    print("   Activated: " .. (keyStatus.firstUsed or "Today"))
    print("   Expires: " .. keyStatus.expiry)
    print("")

    local daysLeft = tonumber(keyStatus.daysLeft) or 0
    if daysLeft > 30 then
        print("   ★ " .. daysLeft .. " DAYS REMAINING")
    elseif daysLeft > 7 then
        print("   ⚠ " .. daysLeft .. " DAYS REMAINING")
    else
        warn("   ⚠ WARNING: Only " .. daysLeft .. " days left!")
        warn("   Consider renewing your key soon.")
    end
end

print("")
print("════════════════════════════════════════")
print("")

local loaded = 0
local failed = 0

for i, scriptName in ipairs(SCRIPTS_TO_LOAD) do
    print("[LOADER] Loading " .. i .. "/" .. #SCRIPTS_TO_LOAD .. ": " .. scriptName)

    local content, status = loadScript(scriptName)

    if content then
        local func, err = loadstring(content)
        if func then
            local runSuccess, runErr = pcall(func)
            if runSuccess then
                print("   ✓ Loaded:", scriptName)
                loaded = loaded + 1
            else
                warn("   ✗ Runtime error:", runErr)
                failed = failed + 1
            end
        else
            warn("   ✗ Syntax error:", err)
            failed = failed + 1
        end
    else
        warn("   ✗ Failed:", status)
        failed = failed + 1
    end
    task.wait(3)
end

print("")
print("╔════════════════════════════════════════╗")
print("║   LOADING COMPLETE                     ║")
print("║   Loaded: " .. loaded .. " | Failed: " .. failed ..
      string.rep(" ", math.max(0, 24 - #tostring(loaded) - #tostring(failed))) .. "║")
print("╚════════════════════════════════════════╝")
