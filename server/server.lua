local discordAvatars = {}
local lastDiscordUpdate = {}

local function fetchDiscordData(discordId)
    if not Config.DiscordBotToken then return nil end
    
    if lastDiscordUpdate[discordId] and 
       (os.time() - lastDiscordUpdate[discordId]) < (Config.RefreshTime / 1000) then
        return discordAvatars[discordId]
    end
    
    local endpoint = string.format("https://discord.com/api/v10/users/%s", discordId)
    PerformHttpRequest(endpoint, function(errorCode, resultData, resultHeaders)
        if errorCode == 200 and resultData then
            local data = json.decode(resultData)
            if data and data.avatar then
                discordAvatars[discordId] = data.avatar
                lastDiscordUpdate[discordId] = os.time()
            end
        end
    end, "GET", "", {
        ["Authorization"] = string.format("Bot %s", Config.DiscordBotToken)
    })
    
    return discordAvatars[discordId]
end

local function getDiscordId(source)
    local identifier = GetPlayerIdentifierByType(source, "discord")
    if string.find(identifier, "discord:") then
        return string.gsub(identifier, "discord:", "")
    end
    return nil
end

local function getPlayerList()
    local players = {}

    for _, player in ipairs(GetPlayers()) do
        local discordId = getDiscordId(player)
        local avatarHash = nil
        
        if discordId then
            avatarHash = fetchDiscordData(discordId)
        end
        
        table.insert(players, {
            serverId = tonumber(player),
            name = GetPlayerName(player),
            color = Player(player).state.PlayerListColor or Config.DefaultColor,
            tag = ".(." .. (Player(player).state.PlayerListTag or ""),
            discordId = discordId,
            avatarHash = avatarHash
        })
    end
    

--[[
    for i = 1, 10200 do
        table.insert(players, {
            serverId = i,
            name = "Debug",
            color = math.random(1,200),
            tag = "",
            discordId = nil,
            avatarHash = nil
        })
    end
    ]]
    
    -- Sort all players by server ID
    table.sort(players, function(a, b)
        return a.serverId < b.serverId
    end)
    
    return players
end


RegisterNetEvent('playerlist:requestUpdate') -- primitive, i know.
AddEventHandler('playerlist:requestUpdate', function()
    local source = source
    TriggerClientEvent('playerlist:updateList', source, getPlayerList())
end)

AddEventHandler('playerJoining', function()
    local players = getPlayerList()
    TriggerClientEvent('playerlist:updateList', -1, players)
end)

AddEventHandler('playerDropped', function()
    local players = getPlayerList()
    TriggerClientEvent('playerlist:updateList', -1, players)
end)

exports('setPlayerListColor', function(player, color)
    if not player then return end
    Player(player).state.PlayerListColor = color
    local players = getPlayerList()
    TriggerClientEvent('playerlist:updateList', -1, players)
end)

exports('setPlayerListTag', function(player, tag)
    if not player then return end
    Player(player).state.PlayerListTag = tag
    local players = getPlayerList()
    TriggerClientEvent('playerlist:updateList', -1, players)
end)




CreateThread(function()
    while true do
        local players = getPlayerList()
        TriggerClientEvent('playerlist:updateList', -1, players)
        Wait(Config.RefreshTime)
    end
end)

 
--[[ COMMANDS YOU CAN USE TO TEST IF YOU WANT :)
RegisterCommand('setcolour', function(source, args, rawCommand)
    local player = tonumber(args[1])
    local color = tonumber(args[2])
    exports['kPlayerList']:setPlayerListColor(player, color) 
end)

RegisterCommand('settag', function(source, args, rawCommand)
    local player = tonumber(args[1])
    local tag = args[2]
    exports['kPlayerList']:setPlayerListTag(player, tag) 
end)
]]