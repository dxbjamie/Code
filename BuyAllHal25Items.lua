--Buy Hal 2025 Items
repeat wait(0.01) until game.Players.LocalPlayer ~= nil
if not game.Loaded then  game.Loaded:Wait() end --wait for game to fully load
wait(180)
---loadstring(game:HttpGet("https://pastebin.com/raw/Cn25rnPi"))()
--loadstring(game:HttpGet"https://drive.google.com/uc?id=1cOwY1kpj1E819fID-FTpyMBCuRsURNZj"))()
--https://drive.google.com/uc?id=1cOwY1kpj1E819fID-FTpyMBCuRsURNZj

--Remote Descrambler


warn("[DEBUG] LOADING UNHASHER V-1")
local hashTable = {}

for i, v in pairs(getgc()) do
    if type(v) == "function" and debug.getinfo(v).name == "get_remote_from_cache" then
        wait(0.5)
        local info = debug.getinfo(v)
        local upvalues = debug.getupvalues(v)
        
        local functionName = info.name
        local hash = ""

        if next(upvalues) ~= nil and type(upvalues[1]) == "table" then
            local remoteTable = upvalues[1]
            
            hashTable[functionName] = {}

            for key, value in pairs(remoteTable) do
                hashTable[functionName][key] = value
            end
        end
    end
end

local remotes = {}
local hashes = {}


for functionName, tableContents in pairs(hashTable) do
    for key, value in pairs(tableContents) do
        remotes[value] = key
        hashes[key] = value
    end
end

local apiFolder = game:GetService("ReplicatedStorage").API
for _, remoteTable in pairs(apiFolder:GetDescendants()) do
    if remoteTable:IsA("RemoteEvent") or remoteTable:IsA("RemoteFunction") then
        local originalName = remotes[remoteTable]
        if originalName then
            remoteTable.Name = originalName
        end
    end
end

for _, remoteTable in pairs(apiFolder:GetDescendants()) do
    if remoteTable:IsA("RemoteEvent") or remoteTable:IsA("RemoteFunction") then
       
    end
end
warn("Loaded")

wait(10)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("pets", "halloween_2025_ghostly_cat",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("pets", "halloween_2025_dj_snooze",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("pet_accessories", "halloween_2025_ghostly_opera_glasses",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("pet_accessories", "halloween_2025_swamp_mist_wings",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("pet_accessories", "halloween_2025_keyboard_necklace",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("pet_accessories", "halloween_2025_spiderweb_coffin_backpack",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("transport", "halloween_2025_keyboard_skateboard",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("transport", "halloween_2025_lava_dragon_bike",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("strollers", "halloween_2025_scarebear_stroller",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("pets", "halloween_2025_slimingo",{})
wait(1)
game:GetService("ReplicatedStorage").API["ShopAPI/BuyItem"]:InvokeServer("gifts", "halloween_2025_sticker_pack",{})





