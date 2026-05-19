local RESOURCE = GetCurrentResourceName()

--- Prefer ox_target when both are running (same pattern as common qb/ox bridges).
---@return 'ox_target'|'qb-target'|nil
function GetFarmingTargetResource()
    if GetResourceState('ox_target') == 'started' then
        return 'ox_target'
    end
    if GetResourceState('qb-target') == 'started' then
        return 'qb-target'
    end
    return nil
end

local entityTargetSystem = {}

---@param options table[]
---@return table[]
local function cloneOptionsForOx(options)
    local oxOpts = {}
    for i, opt in ipairs(options) do
        local o = {}
        for k, v in pairs(opt) do
            o[k] = v
        end
        if not o.name then
            local labelPart = (o.label or 'opt'):gsub('%s+', '_')
            o.name = ('%s_%s_%s'):format(RESOURCE, labelPart, i)
        end
        oxOpts[i] = o
    end
    return oxOpts
end

---@param options table[]
---@return table[], number
local function optionsToQbTarget(options)
    local distance = 2.5
    local qbOpts = {}
    for _, opt in ipairs(options) do
        if opt.distance and opt.distance > distance then
            distance = opt.distance
        end
        local q = {
            icon = opt.icon,
            label = opt.label,
        }
        if opt.onSelect then
            local cb = opt.onSelect
            q.action = function(data)
                cb(data)
            end
        end
        qbOpts[#qbOpts + 1] = q
    end
    return qbOpts, distance
end

---@param entity number
---@param options table[] ox-style options (onSelect; optional name per option)
---@return boolean
function FarmingTargetAddLocalEntity(entity, options)
    if not entity or not DoesEntityExist(entity) then
        return false
    end
    local sys = GetFarmingTargetResource()
    if not sys then
        return false
    end
    entityTargetSystem[entity] = sys
    if sys == 'ox_target' then
        local oxOpts = cloneOptionsForOx(options)
        exports.ox_target:addLocalEntity(entity, oxOpts)
    else
        local qbOpts, dist = optionsToQbTarget(options)
        exports['qb-target']:AddTargetEntity(entity, {
            options = qbOpts,
            distance = dist,
        })
    end
    return true
end

---@param entity number
---@param options table[] same shape as used for add (name for ox, label for qb)
function FarmingTargetRemoveLocalEntity(entity, options)
    if not entity or entity == 0 then return end
    if not options or not options[1] then return end
    local sys = entityTargetSystem[entity] or GetFarmingTargetResource()
    entityTargetSystem[entity] = nil
    if sys == 'ox_target' and GetResourceState('ox_target') == 'started' then
        local names = {}
        for i, opt in ipairs(options) do
            local labelPart = (opt.label or 'opt'):gsub('%s+', '_')
            names[i] = opt.name or ('%s_%s_%s'):format(RESOURCE, labelPart, i)
        end
        exports.ox_target:removeLocalEntity(entity, names)
    elseif sys == 'qb-target' and GetResourceState('qb-target') == 'started' then
        local labels = {}
        for _, opt in ipairs(options) do
            labels[#labels + 1] = opt.label
        end
        exports['qb-target']:RemoveTargetEntity(entity, labels)
    end
end
