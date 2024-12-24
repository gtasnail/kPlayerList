
local Scaleform = {}
Scaleform.__index = Scaleform

local defaultPage = 1
local ppPage = 16
local cardSoundSet = "HUD_FRONTEND_DEFAULT_SOUNDSET"
local openSound = "LEADER_BOARD"
local closeSound = "BACK"
local navSound = "NAV_UP_DOWN"


local cardScaleform = nil
local playerListOpen = false
local playerListCurPage = defaultPage
local playerListMaxPage = 0
local playerList = {}

local avatarDuis = {}
function Scaleform.new(handle)
    local self = setmetatable({}, Scaleform)
    self.handle = handle
    return self
end

function Scaleform:isLoaded()
    return HasScaleformMovieLoaded(self.handle)
end

function Scaleform:callFunction(functionName, ...)
    BeginScaleformMovieMethod(self.handle, functionName)
    local args = {...}
    for _, arg in ipairs(args) do
        local argType = type(arg)
        if argType == "string" then
            ScaleformMovieMethodAddParamTextureNameString(arg)
        elseif argType == "boolean" then
            ScaleformMovieMethodAddParamBool(arg)
        elseif argType == "number" then
            if math.floor(arg) == arg then
                ScaleformMovieMethodAddParamInt(arg)
            else
                ScaleformMovieMethodAddParamFloat(arg)
            end
        end
    end
    EndScaleformMovieMethod()
end

function Scaleform:render(x, y, width, height)-- wrapper! yipee
    DrawScaleformMovie(self.handle, x, y, width, height, 255, 255, 255, 255, 0)
end

function Scaleform:dispose()
    SetScaleformMovieAsNoLongerNeeded(self.handle) -- remove from memory
    self.handle = 0
end

function Scaleform.request(scaleformName)
    local handle = RequestScaleformMovie(scaleformName)
    local self = Scaleform.new(handle)
    
    local timeout = 1000
    while not self:isLoaded() and timeout > 0 do
        Wait(0)
        timeout = timeout - 1
    end
    
    return self
end

local function RegisterDiscordAvatar(userId, avatarHash)
    if not userId or not avatarHash then return "CHAR_DEFAULT" end

    if avatarDuis[userId] then
        return avatarDuis[userId].txd
    end
    local url = string.format("https://cdn.discordapp.com/avatars/%s/%s.png", userId, avatarHash)
    local dui = CreateDui(url, 64, 64)
    local txd = CreateRuntimeTxd('discord_' .. userId)
    local duiHandle = GetDuiHandle(dui)
    CreateRuntimeTextureFromDuiHandle(txd, 'avatar', duiHandle)
    
    avatarDuis[userId] = {
        dui = dui,
        txd = 'discord_' .. userId,
        txt = 'avatar',
        url = url
    }
    
    return 'discord_' .. userId
end

local function CleanupAvatars()
    for userId, data in pairs(avatarDuis) do
        if data.dui then
            DestroyDui(data.dui)
        end
    end
    avatarDuis = {}
end

local function paginate(array, pageSize, pageNumber)
    local startIndex = (pageNumber - 1) * pageSize + 1
    local endIndex = startIndex + pageSize - 1
    local result = {}
    
    for i = startIndex, math.min(endIndex, #array) do
        table.insert(result, array[i])
    end
    
    return result
end

local function updateTitle()
    if not cardScaleform then return end
    cardScaleform:callFunction("SET_TITLE", string.format("Players (%d)", #playerList), string.format("Page %d/%d", playerListCurPage, playerListMaxPage))
end

local function sanitizeName(name)
    return string.gsub(name, "[<>~^]", "")
end

local function updateCard()
    if not cardScaleform then return end

    for i = 0, ppPage - 1 do
        cardScaleform:callFunction("SET_DATA_SLOT_EMPTY", i)
    end

    local players = paginate(playerList, ppPage, playerListCurPage)
    for i, player in ipairs(players) do
        local avatarTxd = "CHAR_DEFAULT"
        if player.discordId and player.avatarHash then
            avatarTxd = RegisterDiscordAvatar(player.discordId, player.avatarHash)
        end
        
        cardScaleform:callFunction("SET_DATA_SLOT", 
            i - 1,
            "",
            string.format("%s (%d)", sanitizeName(player.name), player.serverId),
            player.color or 116,
            0,
            "",
            "",
            player.tag or "",
            2,
            avatarTxd,
            "avatar",
            ""
        )
    end

    cardScaleform:callFunction("DISPLAY_VIEW")
end

RegisterNetEvent('playerlist:updateList')
AddEventHandler('playerlist:updateList', function(newList)
    playerList = newList
    playerListMaxPage = math.ceil(#playerList / ppPage)
    if playerListOpen then
        updateTitle()
        updateCard()
    end
end)


local renderLoop = nil
RegisterCommand('+playerlist', function()
    
    playerListCurPage = defaultPage
    
    if playerListOpen then
        if cardScaleform then
            cardScaleform:dispose()
            cardScaleform = nil
        end
        CleanupAvatars()
        PlaySoundFrontend(-1, closeSound, cardSoundSet, true)
        
        if renderLoop then
            renderLoop:remove()
            renderLoop = nil
        end
    else
        TriggerServerEvent('playerlist:requestUpdate')
        playerListMaxPage = math.ceil(#playerList / ppPage)
        
        cardScaleform = Scaleform.request("mp_mm_card_freemode")
        updateTitle()
        updateCard()
        
        PlaySoundFrontend(-1, openSound, cardSoundSet, true)
        renderLoop = CreateThread(function()
            while playerListOpen and cardScaleform do
                PushScaleformMovieFunction(cardScaleform.handle, "SET_BACKGROUND_COLOUR")
                PushScaleformMovieFunctionParameterInt(0)
                PushScaleformMovieFunctionParameterInt(0)
                PushScaleformMovieFunctionParameterInt(0)
                PushScaleformMovieFunctionParameterInt(80)
                PopScaleformMovieFunctionVoid()
                
                SetScriptGfxAlign(76, 84)
                cardScaleform:render(0.122, 0.3, 0.28, 0.6)
                ResetScriptGfxAlign()
                
                Wait(0)
            end
        end)
    end
    
    playerListOpen = not playerListOpen
end)

RegisterCommand('+playerlist_pageup', function()
    if not playerListOpen then return end
    
    playerListCurPage = playerListCurPage + 1
    if playerListCurPage > playerListMaxPage then
        playerListCurPage = defaultPage
    end
    
    updateTitle()
    updateCard()
    PlaySoundFrontend(-1, navSound, cardSoundSet, true)
end)

RegisterCommand('+playerlist_pagedown', function()
    if not playerListOpen then return end
    
    playerListCurPage = playerListCurPage - 1
    if playerListCurPage <= 0 then
        playerListCurPage = playerListMaxPage
    end
    
    updateTitle()
    updateCard()
    PlaySoundFrontend(-1, navSound, cardSoundSet, true)
end)

RegisterKeyMapping('+playerlist', 'Toggle Player List', 'keyboard', 'Z')
RegisterKeyMapping('+playerlist_pageup', 'Player List Page Up', 'keyboard', 'PRIOR')
RegisterKeyMapping('+playerlist_pagedown', 'Player List Page Down', 'keyboard', 'NEXT')

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CleanupAvatars()
end)

