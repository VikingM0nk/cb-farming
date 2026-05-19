local vendorPed
local marketBlip
--- Every farmers-market ped handle we ever created (avoids losing refs on overlapping spawns).
local vendorPedHandles = {}
--- Cancels in-flight spawns when a newer spawn is requested.
local vendorSpawnGen = 0

local MARKET_TARGET_OPTIONS = {
    { name = 'cb_farming_market', label = 'Sell produce' },
}

local function removeVendor()
    for _, ped in ipairs(vendorPedHandles) do
        if ped and DoesEntityExist(ped) then
            FarmingTargetRemoveLocalEntity(ped, MARKET_TARGET_OPTIONS)
            DeleteEntity(ped)
        end
    end
    vendorPedHandles = {}
    vendorPed = nil
    if marketBlip then
        RemoveBlip(marketBlip)
        marketBlip = nil
    end
end

local function openSellMenu()
    local stock = lib.callback.await('cb-farming:server:GetMarketStock', false)
    if not stock or #stock == 0 then
        Notify('Farmers Market', 'You have nothing to sell here.', 'inform')
        return
    end
    local options = {}
    for _, row in ipairs(stock) do
        options[#options + 1] = {
            title = row.label,
            description = ('$%s each · You have %s'):format(row.price, row.count),
            onSelect = function()
                local input = lib.inputDialog(('Sell %s'):format(row.label), {
                    {
                        type = 'number',
                        label = 'How many?',
                        default = row.count,
                        min = 1,
                        max = row.count,
                        required = true,
                    },
                })
                if not input then return end
                local amt = math.floor(tonumber(input[1]) or 0)
                if amt < 1 then return end
                local ok, info = lib.callback.await('cb-farming:server:SellHarvest', false, row.item, amt)
                if ok then
                    Notify('Farmers Market', ('Sold %s ×%s for $%s.'):format(row.label, amt, info), 'success')
                else
                    Notify('Farmers Market', tostring(info or 'Sale failed.'), 'error')
                end
            end,
        }
    end
    lib.registerContext({
        id = 'cb_farming_market_sell',
        title = 'Farmers Market',
        options = options,
    })
    lib.showContext('cb_farming_market_sell')
end

local function spawnVendor()
    if not Config.FarmersMarket or not Config.FarmersMarket.enabled then return end

    vendorSpawnGen = vendorSpawnGen + 1
    local gen = vendorSpawnGen

    -- Always tear down immediately so overlapping triggers cannot stack peds.
    removeVendor()

    CreateThread(function()
        local cfg = Config.FarmersMarket.ped
        local model = cfg.model
        lib.requestModel(model, 5000)

        if gen ~= vendorSpawnGen then return end
        if not HasModelLoaded(model) then
            lib.print.error('[cb-farming] Farmers market ped model failed to load')
            return
        end

        local ped = CreatePed(5, model, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w, false, true)

        if gen ~= vendorSpawnGen then
            if DoesEntityExist(ped) then
                FarmingTargetRemoveLocalEntity(ped, MARKET_TARGET_OPTIONS)
                DeleteEntity(ped)
            end
            SetModelAsNoLongerNeeded(model)
            return
        end

        vendorPed = ped
        vendorPedHandles[#vendorPedHandles + 1] = ped

        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetPedCanRagdoll(ped, false)
        SetModelAsNoLongerNeeded(model)
        if cfg.scenario and cfg.scenario ~= '' then
            TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
        end
        if not FarmingTargetAddLocalEntity(ped, {
            {
                name = 'cb_farming_market',
                label = 'Sell produce',
                icon = 'fa-solid fa-basket-shopping',
                distance = 2.5,
                onSelect = function()
                    openSellMenu()
                end,
            },
        }) then
            lib.print.warn('[cb-farming] No target resource (ox_target / qb-target); farmers market ped has no interaction.')
        end
        local blipCfg = Config.FarmersMarket.blip
        if blipCfg and blipCfg.enabled then
            marketBlip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
            SetBlipSprite(marketBlip, blipCfg.sprite or 52)
            SetBlipDisplay(marketBlip, 4)
            SetBlipScale(marketBlip, blipCfg.scale or 0.75)
            SetBlipColour(marketBlip, blipCfg.color or 2)
            SetBlipAsShortRange(marketBlip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(blipCfg.label or 'Farmers Market')
            EndTextCommandSetBlipName(marketBlip)
        end
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    spawnVendor()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    removeVendor()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeVendor()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetTimeout(2500, function()
        if LocalPlayer.state and LocalPlayer.state.isLoggedIn then
            spawnVendor()
        end
    end)
end)
