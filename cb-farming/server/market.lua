local sellCooldown = {}

local function onSellCooldown(src, seconds)
    local now = os.time()
    local last = sellCooldown[src]
    if last and (now - last) < seconds then return true end
    sellCooldown[src] = now
    return false
end

local function isSellableItem(item)
    local price = Config.FarmersMarket.prices[item]
    return price ~= nil and price > 0
end

local function nearVendor(src)
    local pedCoords = Config.FarmersMarket.ped.coords
    local vendor = vector3(pedCoords.x, pedCoords.y, pedCoords.z)
    return #(GetPlayerCoords(src) - vendor) <= (Config.FarmersMarket.sellZoneRadius or 4.0)
end

lib.callback.register('cb-farming:server:GetMarketStock', function(src)
    if not Config.FarmersMarket.enabled then return {} end
    local rows = {}
    for item, price in pairs(Config.FarmersMarket.prices) do
        if price > 0 then
            local count = GetItemCount(src, item)
            if count > 0 then
                rows[#rows + 1] = {
                    item = item,
                    count = count,
                    price = price,
                    label = GetItemLabel(item),
                }
            end
        end
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    return rows
end)

lib.callback.register('cb-farming:server:SellHarvest', function(src, item, amount)
    if not Config.FarmersMarket.enabled then
        return false, 'Market is closed.'
    end
    if type(item) ~= 'string' or not isSellableItem(item) then
        return false, 'That item cannot be sold here.'
    end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then
        return false, 'Invalid amount.'
    end
    if not HasItem(src, item, amount) then
        return false, 'You do not have enough of that item.'
    end
    if onSellCooldown(src, 1) then
        return false, 'Please wait a moment.'
    end
    local unit = Config.FarmersMarket.prices[item]
    local total = unit * amount
    RemoveItem(src, item, amount)
    AddMoney(src, total, Config.FarmersMarket.payAccount)
    return true, total
end)

AddEventHandler('playerDropped', function()
    sellCooldown[source] = nil
end)
