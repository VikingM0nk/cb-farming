Framework = 'qb-core'
UsingOxInventory = false

if GetResourceState('qbx_core') == 'started' then
    Framework = 'qbox'
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    Framework = 'qb-core'
end

if GetResourceState('ox_inventory') == 'started' then
    UsingOxInventory = true
end

CreateThread(function()
    lib.versionCheck('CoolBrad-Scripts/cb-farming')
end)

local picked = {}
---@param limit integer Cooldown for netevents
---@return boolean OnCooldown If the player is on cooldown from triggering the event
function OnCooldown(limit)
    local time = os.time()
    if picked[source] and time - picked[source] < limit then return true end
    picked[source] = time
    return false
end

function GetPlayer(target)
    if Framework == "qb-core" then
        return QBCore.Functions.GetPlayer(target)

    elseif Framework == "qbox" then
        return exports.qbx_core:GetPlayer(target)
    end
end

function GetPlayerCoords(target)
    local playerPed = GetPlayerPed(target)
    return GetEntityCoords(playerPed)
end

---@param name string
---@return {citizenid: string, grade: integer}[]
function FetchPlayersInGang(name)
    return MySQL.query.await("SELECT citizenid, grade FROM player_groups WHERE `group` = ? AND `type` = 'gang'", {name})
end

function GetPlayers()
    if Framework == "qb-core" then
        return QBCore.Functions.GetPlayers()

    elseif Framework == "qbox" then
        local sources = {}
        local players = exports.qbx_core:GetQBPlayers()
        for k in pairs(players) do
            sources[#sources+1] = k
        end
        return sources
    end
end

function HasItem(source, item, amount)
    if UsingOxInventory then
        local itemCount = exports.ox_inventory:Search(source, 'count', item)
        if not itemCount then return false end
        return itemCount >= amount
    end
    local Player = GetPlayer(source)
    if not Player then return false end
    return Player.Functions.HasItem(item, amount)
end

function RemoveItem(source, item, amount)
    if UsingOxInventory then
        exports.ox_inventory:RemoveItem(source, item, amount)
        return
    end
    local Player = GetPlayer(source)
    if Player then
        Player.Functions.RemoveItem(item, amount)
    end
end

---@param source number
---@param item string
---@return integer
function GetItemCount(source, item)
    if UsingOxInventory then
        return exports.ox_inventory:Search(source, 'count', item) or 0
    end
    local Player = GetPlayer(source)
    if not Player then return 0 end
    local data = Player.Functions.GetItemByName(item)
    if not data then return 0 end
    return data.amount or data.count or 0
end

---@param source number
---@param amount number
---@param account? string qb money type, default cash
function AddMoney(source, amount, account)
    account = account or 'cash'
    local Player = GetPlayer(source)
    if not Player or amount <= 0 then return end
    Player.Functions.AddMoney(account, math.floor(amount + 0.5))
end

function AddItem(source, item, amount)
    if not UsingOxInventory then
        local Player = GetPlayer(source)
        if not Player then return false end
        Player.Functions.AddItem(item, amount)
        return true
    elseif UsingOxInventory then
        local canCarryItem = exports.ox_inventory:CanCarryItem(source, item, amount)
        if canCarryItem then
            exports.ox_inventory:AddItem(source, item, amount)
            return true
        else
            TriggerClientEvent('cb-farming:client:NotEnoughSpace', source)
            return false
        end
    end
end

function GetItemLabel(item)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:Items(item).label
    else
        return QBCore.Shared.Items[item].label
    end
end

function GetItemImage(item)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:Items(item).client.image
    else
        return "nui://" .. Config.InventoryImage .. QBCore.Shared.Items[item].image
    end
end