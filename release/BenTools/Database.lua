local addonName, ns = ...

ns.addonName = addonName
ns.DB = {}

local defaults = {
    profile = {
        enabled = true,
        debug = false,
        sellGray = true,
        repairReminderEnabled = true,
        repairReminderThreshold = 50,
        equipmentRuleEnabled = false,
        itemLevelThreshold = 500,
        minQuality = 0,
        maxQuality = 2,
        soulboundOnly = false,
        boeOnly = false,
        excludeCrafting = true,
        excludeEquipmentSets = true,
        confirmLargeSales = true,
        confirmGoldThreshold = 1000000,
    },
    autoQueue = {
        dungeon = "",
        minLevel = 2,
        maxLevel = 10,
        requirePartyFit = true,
        allowHiddenKeyLevel = true,
        includeFullGroups = false,
        comment = "",
    },
    queueRinger = {
        enabled = true,
        debug = false,
        notifyLFG = true,
        notifyPvP = true,
        notifyPremade = true,
        notifyReadyCheck = true,
        showPopup = true,
        popupDuration = 20,
        lastEventSerial = 0,
        lastEventId = "",
        lastQueueType = "",
        lastEventAt = 0,
        bridgeMethod = "SCREEN_BEACON",
    },
    mythicPlusFinder = {
        enabled = true,
        debug = false,
        defaultRole = "HEALER",
        showMatchScore = true,
        showScoreExplanation = true,
        compactCards = false,
        filters = {
            allowedMin = 8,
            allowedMax = 12,
            preferredMin = 10,
            preferredMax = 11,
            selectedRole = "HEALER",
            composition = {
                TANK = "REQUIRED",
                HEALER = "ANY",
                DAMAGER = "ANY",
            },
            selectedDungeons = {},
            allowUnknownKeyLevel = true,
            minGroupSize = 0,
            preferFullGroups = true,
            leaderScoreMin = 0,
            preferStrongerLeader = true,
            ageMaxMinutes = 0,
            preferFresh = true,
            desiredActiveApplications = 5,
            hideDelisted = true,
        },
        ui = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 20,
            width = 1120,
            height = 820,
            selectedResultID = nil,
            selectedPresetName = "",
            lastSearchAt = 0,
        },
        presets = {},
        stats = {
            lastRawResultCount = 0,
            lastFilteredCount = 0,
        },
    },
    ui = {
        mainWindow = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 80,
        },
    },
    alwaysSell = {},
    neverSell = {},
    names = {},
}

local function CopyDefaults(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.DB:Initialize()
    if type(BenToolsDB) ~= "table" then
        BenToolsDB = {}
    end
    CopyDefaults(defaults, BenToolsDB)
    ns.db = BenToolsDB
end

function ns.DB:GetProfile()
    return ns.db.profile
end

function ns.DB:SetItemName(itemID, name)
    if itemID and name then
        ns.db.names[tonumber(itemID)] = name
    end
end

function ns.DB:GetItemName(itemID)
    return ns.db.names[tonumber(itemID)] or ("item:" .. tostring(itemID))
end

function ns.DB:IsAlwaysSell(itemID)
    return itemID and ns.db.alwaysSell[tonumber(itemID)] == true
end

function ns.DB:IsNeverSell(itemID)
    return itemID and ns.db.neverSell[tonumber(itemID)] == true
end

function ns.DB:SetAlwaysSell(itemID, name, enabled)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end
    ns.db.alwaysSell[itemID] = enabled and true or nil
    if enabled then
        ns.db.neverSell[itemID] = nil
    end
    self:SetItemName(itemID, name)
end

function ns.DB:SetNeverSell(itemID, name, enabled)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end
    ns.db.neverSell[itemID] = enabled and true or nil
    if enabled then
        ns.db.alwaysSell[itemID] = nil
    end
    self:SetItemName(itemID, name)
end

function ns.DB:ClearRules()
    wipe(ns.db.alwaysSell)
    wipe(ns.db.neverSell)
end
