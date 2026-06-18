if Nexus then Nexus:Stop() end

if not game:IsLoaded() then
    task.delay(60, function()
        if NoShutdown then return end

        if not game:IsLoaded() then
            return game:Shutdown()
        end

        local Code = game:GetService'GuiService':GetErrorCode().Value

        if Code >= Enum.ConnectionError.DisconnectErrors.Value then
            return game:Shutdown()
        end
    end)
    
    game.Loaded:Wait()
end

local Nexus = {}
local WSConnect = syn and syn.websocket.connect or
    (Krnl and (function() repeat task.wait() until Krnl.WebSocket and Krnl.WebSocket.connect return Krnl.WebSocket.connect end)()) or
    WebSocket and WebSocket.connect

if not WSConnect then
    if messagebox then
        messagebox(('Nexus encountered an error while launching!\n\n%s'):format('Your exploit (' .. (identifyexecutor and identifyexecutor() or 'UNKNOWN') .. ') is not supported'), 'Roblox Account Manager', 0)
    end
    
    return
end

local TeleportService = game:GetService'TeleportService'
local InputService = game:GetService'UserInputService'
local HttpService = game:GetService'HttpService'
local RunService = game:GetService'RunService'
local GuiService = game:GetService'GuiService'
local Players = game:GetService'Players'
local LocalPlayer = Players.LocalPlayer if not LocalPlayer then repeat LocalPlayer = Players.LocalPlayer task.wait() until LocalPlayer end task.wait(0.5)

local UGS = UserSettings():GetService'UserGameSettings'
local OldVolume = UGS.MasterVolume

LocalPlayer.OnTeleport:Connect(function(State)
    if State == Enum.TeleportState.Started and Nexus.IsConnected then
        Nexus:SetAutoRelaunch(false) -- tell C# not to relaunch while this account is teleporting
        task.wait(0.1)              -- give the message time to send before the socket closes
        Nexus:Stop()                -- websocket doesn't auto-close on teleport so this is required
    end
end)

local Signal = {} do
    Signal.__index = Signal

    function Signal.new()
        local self = setmetatable({ _BindableEvent = Instance.new'BindableEvent' }, Signal)
        
        return self
    end

    function Signal:Connect(Callback)
        assert(typeof(Callback) == 'function', 'function expected, got ' .. typeof(Callback))

        return self._BindableEvent.Event:Connect(Callback)
    end

    function Signal:Fire(...)
        self._BindableEvent:Fire(...)
    end

    function Signal:Wait()
        return self._BindableEvent.Event:Wait()
    end

    function Signal:Disconnect()
        if self._BindableEvent then
            self._BindableEvent:Destroy()
        end
    end
end

do -- Nexus
    local BTN_CLICK = 'ButtonClicked:'

    Nexus.Connected = Signal.new()
    Nexus.Disconnected = Signal.new()
    Nexus.MessageReceived = Signal.new()

    Nexus.Commands = {}
    Nexus.Connections = {}

    Nexus.ShutdownTime = 45
    Nexus.ShutdownOnTeleportError = true

    function Nexus:Send(Command, Payload)
        assert(self.Socket ~= nil, 'websocket is nil')
        assert(self.IsConnected, 'websocket not connected')
        assert(typeof(Command) == 'string', 'Command must be a string, got ' .. typeof(Command))

        if Payload then
            assert(typeof(Payload) == 'table', 'Payload must be a table, got ' .. typeof(Payload))
        end

        local Message = HttpService:JSONEncode {
            Name = Command,
            Payload = Payload
        }

        self.Socket:Send(Message)
    end

    function Nexus:SetAutoRelaunch(Enabled)
        self:Send('SetAutoRelaunch', { Content = Enabled and 'true' or 'false' })
    end
    
    function Nexus:SetPlaceId(PlaceId)
        self:Send('SetPlaceId', { Content = PlaceId })
    end
    
    function Nexus:SetJobId(JobId)
        self:Send('SetJobId', { Content = JobId })
    end

    function Nexus:Echo(Message)
        self:Send('Echo', { Content = Message })
    end

    function Nexus:Log(...)
        local T = {}

        for Index, Value in pairs{ ... } do
            table.insert(T, tostring(Value))
        end

        self:Send('Log', {
            Content = table.concat(T, ' ')
        })
    end

    function Nexus:CreateElement(ElementType, Name, Content, Size, Margins, Table)
        assert(typeof(Name) == 'string', 'string expected on argument #1, got ' .. typeof(Name))
        assert(typeof(Content) == 'string', 'string expected on argument #2, got ' .. typeof(Content))

        assert(Name:find'%W' == nil, 'argument #1 cannot contain whitespace')

        if Size then assert(typeof(Size) == 'table' and #Size == 2, 'table with 2 arguments expected on argument #3, got ' .. typeof(Size)) end
        if Margins then assert(typeof(Margins) == 'table' and #Margins == 4, 'table with 4 arguments expected on argument #4, got ' .. typeof(Margins)) end
        
        local Payload = {
            Name = Name,
            Content = Content,
            Size = Size and table.concat(Size, ','),
            Margin = Margins and table.concat(Margins, ',')
        }

        if Table then
            for Index, Value in pairs(Table) do
                Payload[Index] = Value
            end
        end

        self:Send(ElementType, Payload)
    end

    function Nexus:CreateButton(...)
        return self:CreateElement('CreateButton', ...)
    end

    function Nexus:CreateTextBox(...)
        return self:CreateElement('CreateTextBox', ...)
    end

    function Nexus:CreateNumeric(Name, Value, DecimalPlaces, Increment, Size, Margins)
        return self:CreateElement('CreateNumeric', Name, tostring(Value), Size, Margins, { DecimalPlaces = DecimalPlaces, Increment = Increment })
    end

    function Nexus:CreateLabel(...)
        return self:CreateElement('CreateLabel', ...)
    end

    function Nexus:NewLine(...)
        return self:Send('NewLine')
    end

    function Nexus:GetText(Name)
        return self:WaitForMessage('ElementText:', 'GetText', { Name = Name })
    end

    function Nexus:SetRelaunch(Seconds)
        self:Send('SetRelaunch', { Seconds = Seconds })
    end

    function Nexus:WaitForMessage(Header, Message, Payload)
        if Message then
            task.defer(self.Send, self, Message, Payload)
        end

        local Message

        while true do
            Message = self.MessageReceived:Wait()

            if Message:sub(1, #Header) == Header then
                break
            end
        end

        return Message:sub(#Header + 1)
    end

    function Nexus:Connect(Host, Bypass)
        if not Bypass and self.IsConnected then return 'Ignoring connection request, Nexus is already connected' end

        while true do
            for Index, Connection in pairs(self.Connections) do
                Connection:Disconnect()
            end
        
            table.clear(self.Connections)

            if self.IsConnected then
                self.IsConnected = false
                self.Socket = nil
                self.Disconnected:Fire()
            end

            if self.Terminated then break end

            if not Host then
                Host = 'localhost:5242'
            end

            local Success, Socket = pcall(WSConnect, ('ws://%s/Nexus?name=%s&id=%s&jobId=%s'):format(Host, LocalPlayer.Name, LocalPlayer.UserId, game.JobId))

            if not Success then task.wait(12) continue end

            self.Socket = Socket
            self.IsConnected = true

            table.insert(self.Connections, Socket.OnMessage:Connect(function(Message)
                self.MessageReceived:Fire(Message)
            end))

            table.insert(self.Connections, Socket.OnClose:Connect(function()
                self.IsConnected = false
                self.Disconnected:Fire()
            end))

            self.Connected:Fire()

            while self.IsConnected do
                local Success, Error = pcall(self.Send, self, 'ping')

                if not Success or self.Terminated then
                    break
                end

                task.wait(1)
            end
        end
    end

    function Nexus:Stop()
        self.IsConnected = false
        self.Terminated = true
        self.Disconnected:Fire()

        if self.Socket then
            pcall(function() self.Socket:Close() end)
        end
    end

    function Nexus:AddCommand(Name, Function)
        self.Commands[Name] = Function
    end

    function Nexus:RemoveCommand(Name)
        self.Commands[Name] = nil
    end

    function Nexus:OnButtonClick(Name, Function)
        self:AddCommand('ButtonClicked:' .. Name, Function)
    end

    Nexus.MessageReceived:Connect(function(Message)
        local S = Message:find(' ')

        if S then
            local Command, Message = Message:sub(1, S - 1):lower(), Message:sub(S + 1)

            if Nexus.Commands[Command] then
                local Success, Error = pcall(Nexus.Commands[Command], Message)

                if not Success and Error then
                    Nexus:Log(('Error with command `%s`: %s'):format(Command, Error))
                end
            end
        elseif Nexus.Commands[Message] then
            local Success, Error = pcall(Nexus.Commands[Message], Message)

            if not Success and Error then
                Nexus:Log(('Error with command `%s`: %s'):format(Message, Error))
            end
        end
    end)
end

do -- Default Commands
    Nexus:AddCommand('execute', function(Message)
        local Function, Error = loadstring(Message)
        
        if Function then
            local Env = getfenv(Function)
            
            Env.Player = LocalPlayer
            Env.print = function(...)
                local T = {}

                for Index, Value in pairs{ ... } do
                    table.insert(T, tostring(Value))
                end

                Nexus:Log(table.concat(T, ' '))
            end

            if newcclosure then Env.print = newcclosure(Env.print) end

            local S, E = pcall(Function)

            if not S then
                Nexus:Log(E)
            end
        else
            Nexus:Log(Error)
        end
    end)

    Nexus:AddCommand('teleport', function(Message)
        local S = Message:find(' ')
        local PlaceId, JobId = S and Message:sub(1, S - 1) or Message, S and Message:sub(S + 1)
        
        if JobId then
            TeleportService:TeleportToPlaceInstance(tonumber(PlaceId), JobId)
        else
            TeleportService:Teleport(tonumber(PlaceId))
        end
    end)

    Nexus:AddCommand('rejoin', function(Message)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end)

    Nexus:AddCommand('mute', function()
        if (UGS.MasterVolume - OldVolume) > 0.01 then
            OldVolume = UGS.MasterVolume
        end

        UGS.MasterVolume = 0
    end)

    Nexus:AddCommand('unmute', function()
        UGS.MasterVolume = OldVolume
    end)

    Nexus:AddCommand('performance', function(Message)
        if _PERF then return end
        
        _PERF = true
        _TARGETFPS = 8

        if Message and tonumber(Message) then
            _TARGETFPS = tonumber(Message)
        end

        local OldLevel = settings().Rendering.QualityLevel

        RunService:Set3dRenderingEnabled(false)
        settings().Rendering.QualityLevel = 1

        InputService.WindowFocused:Connect(function()
            RunService:Set3dRenderingEnabled(true)
            settings().Rendering.QualityLevel = OldLevel
            setfpscap(60)
        end)

        InputService.WindowFocusReleased:Connect(function()
            OldLevel = settings().Rendering.QualityLevel

            RunService:Set3dRenderingEnabled(false)
            settings().Rendering.QualityLevel = 1
            setfpscap(_TARGETFPS)
        end)

        setfpscap(_TARGETFPS)
    end)
end

do -- Connections
    GuiService.ErrorMessageChanged:Connect(function()
        if NoShutdown then return end

        local Code = GuiService:GetErrorCode().Value

        if Code >= Enum.ConnectionError.DisconnectErrors.Value then
            if not Nexus.ShutdownOnTeleportError and Code > Enum.ConnectionError.PlacelaunchOtherError.Value then
                return
            end
            
            task.delay(Nexus.ShutdownTime, game.Shutdown, game)
        end
    end)
end

local GEnv = getgenv()
GEnv.Nexus = Nexus
GEnv.performance = Nexus.Commands.performance -- fix the sirmeme error so that people stop being annoying saying "omg performance() doesnt work" (https://youtu.be/vVfg9ym2MNs?t=389)

-- After every reconnect (including after a teleport lands in the new place),
-- re-enable auto-relaunch. The Nexus script runs fresh in the new place, so
-- this fires as the new session connects — restoring the normal relaunch state.
Nexus.Connected:Connect(function()
    Nexus:SetAutoRelaunch(true)
end)

-- Watch for Roblox captcha overlays. Scans CoreGui and PlayerGui every 5 seconds.
-- Detects multiple variants:
--   "Start Puzzle"          — FunCaptcha arrow/image challenge
--   "Verification"          — older bot-verification overlay
--   "Verifying you're not a bot" — accompanying label for the above
--   "Security" + "Verify"/"Verifying" — Roblox's newer in-experience security overlay
-- Sends CaptchaDetected to C# so Account Control can shut down and relaunch
-- this account if "Auto Close on Captcha" is enabled in its settings.
-- Specific, unambiguous captcha strings — safe to match in any GUI (CoreGui or PlayerGui).
local function isCaptchaText(text)
    return text == 'Start Puzzle'
        or text == 'Verification'
        or text:find("Verifying you") ~= nil
        or text:find("not a bot") ~= nil
end

-- Roblox's newer "Security / Verify" overlay uses short, generic button text ('Verify',
-- 'Verifying') under a 'Security' header. These short words can also appear in game-placed UI,
-- so only treat them as a captcha when found in CoreGui — where Roblox renders its own security
-- overlays — never in PlayerGui. This avoids false kills from a game's own "Verify" button.
local function isSecurityOverlayText(text)
    return text == 'Verify'
        or text == 'Verifying'
        or text == 'Security'
end

task.spawn(function()
    repeat task.wait() until Nexus.IsConnected

    while task.wait(5) do
        if not Nexus.IsConnected then continue end

        local ok, found = pcall(function()
            -- Check both CoreGui (system overlays) and PlayerGui (game-placed UIs).
            local coreGui = game:GetService('CoreGui')
            local roots = { coreGui }
            local ok2, pg = pcall(function() return LocalPlayer:WaitForChild('PlayerGui', 0) end)
            if ok2 and pg then table.insert(roots, pg) end

            for _, root in ipairs(roots) do
                local isCoreGui = (root == coreGui)
                for _, v in ipairs(root:GetDescendants()) do
                    if v:IsA('TextButton') or v:IsA('TextLabel') then
                        -- Specific strings match in any GUI; the generic "Security/Verify" overlay
                        -- terms only count in CoreGui to avoid false positives from game UI.
                        if isCaptchaText(v.Text) or (isCoreGui and isSecurityOverlayText(v.Text)) then
                            return true
                        end
                    end
                end
            end
            return false
        end)

        if ok and found then
            Nexus:Log('Captcha overlay detected — notifying Account Control')
            Nexus:Send('CaptchaDetected', { Content = 'true' })
            break -- only send once; C# will shut the game down if the setting is on
        end
    end
end)

if not Nexus_Version then
    Nexus:Connect()
end
