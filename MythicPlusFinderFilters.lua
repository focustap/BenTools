local addonName, ns = ...

ns.MythicPlusFinderFilters = {}

local filtersAPI = ns.MythicPlusFinderFilters
local DUNGEON_CATEGORY_ID = LE_LFG_CATEGORY_DUNGEON or 2
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local ROLE_CAPS = {
    TANK = 1,
    HEALER = 1,
    DAMAGER = 3,
}
local ROLE_LABELS = {
    TANK = "Tank",
    HEALER = "Healer",
    DAMAGER = "DPS",
}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function CleanDungeonName(name)
    name = tostring(name or "")
    name = name:gsub("^Mythic Keystone:%s*", "")
    name = name:gsub("^Mythic %+:%s*", "")
    return name
end

function filtersAPI:GetCaps()
    return ROLE_CAPS
end

function filtersAPI:GetRoleLabel(role)
    return ROLE_LABELS[role] or tostring(role or "")
end

function filtersAPI:GetPartySize()
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    if members <= 0 then
        return 1
    end
    return members
end

function filtersAPI:GetRoleState(filters, role)
    filters.composition = filters.composition or {}
    return filters.composition[role] or "ANY"
end

function filtersAPI:SetRoleState(filters, role, state)
    filters.composition = filters.composition or {}
    filters.composition[role] = state
end

function filtersAPI:GetSelectedRole(filters)
    return (filters and filters.selectedRole) or "HEALER"
end

function filtersAPI:SetSelectedRole(filters, role)
    filters.selectedRole = role
end

function filtersAPI:ValidateFilters(filters)
    filters.allowedMin = Clamp(filters.allowedMin or 2, 2, 40)
    filters.allowedMax = Clamp(filters.allowedMax or filters.allowedMin, filters.allowedMin, 40)
    filters.preferredMin = Clamp(filters.preferredMin or filters.allowedMin, filters.allowedMin, filters.allowedMax)
    filters.preferredMax = Clamp(filters.preferredMax or filters.allowedMax, filters.preferredMin, filters.allowedMax)
    filters.minGroupSize = Clamp(filters.minGroupSize or 0, 0, 4)
    filters.leaderScoreMin = math.max(0, tonumber(filters.leaderScoreMin) or 0)
    filters.ageMaxMinutes = Clamp(filters.ageMaxMinutes or 0, 0, 15)
    filters.desiredActiveApplications = Clamp(filters.desiredActiveApplications or 5, 1, 10)
    if filters.allowUnknownKeyLevel == nil then
        filters.allowUnknownKeyLevel = true
    end
    filters.selectedDungeons = type(filters.selectedDungeons) == "table" and filters.selectedDungeons or {}
    filters.composition = type(filters.composition) == "table" and filters.composition or {}

    local selectedRole = self:GetSelectedRole(filters)
    for _, role in ipairs(ROLE_ORDER) do
        if role == selectedRole then
            filters.composition[role] = "OPEN"
        else
            local state = filters.composition[role]
            if state ~= "ANY" and state ~= "PREFERRED" and state ~= "REQUIRED" then
                filters.composition[role] = "ANY"
            end
        end
    end

    return filters
end

function filtersAPI:GetActivityDungeonPool()
    local pool = {}
    if not C_LFGList or not C_LFGList.GetAvailableActivities or not C_LFGList.GetActivityInfoTable then
        return pool
    end

    local activities = C_LFGList.GetAvailableActivities(DUNGEON_CATEGORY_ID)
    for _, activityID in ipairs(activities or {}) do
        local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
        if ok and type(info) == "table" then
            local name = CleanDungeonName(info.fullName or info.shortName or info.name)
            if info.isMythicPlusActivity and name ~= "" then
                pool[name] = true
            elseif name:find("Mythic Keystone", 1, true) then
                pool[name] = true
            end
        end
    end

    return pool
end

function filtersAPI:RefreshDungeonPool(results)
    local pool = self:GetActivityDungeonPool()
    for _, result in ipairs(results or {}) do
        if result.dungeonName and result.dungeonName ~= "" then
            pool[result.dungeonName] = true
        end
    end

    local names = {}
    for name in pairs(pool) do
        table.insert(names, name)
    end
    table.sort(names)
    self.cachedDungeonNames = names
    return names
end

function filtersAPI:IsDungeonSelected(filters, dungeonName)
    local selected = filters.selectedDungeons or {}
    local anySelected = false
    for _, enabled in pairs(selected) do
        if enabled then
            anySelected = true
            break
        end
    end
    if not anySelected then
        return true
    end
    return selected[dungeonName] == true
end

function filtersAPI:SetAllDungeonsSelected(filters, enabled)
    filters.selectedDungeons = filters.selectedDungeons or {}
    for _, name in ipairs(self.cachedDungeonNames or {}) do
        filters.selectedDungeons[name] = enabled and true or nil
    end
end

function filtersAPI:ToggleDungeon(filters, dungeonName)
    filters.selectedDungeons = filters.selectedDungeons or {}
    filters.selectedDungeons[dungeonName] = not filters.selectedDungeons[dungeonName] or nil
end

function filtersAPI:PassesHardFilters(result, filters, appState)
    if not result then
        return false, "Listing unavailable"
    end

    if filters.hideDelisted and result.isDelisted then
        return false, "Delisted"
    end

    if appState and (appState.status == "applied" or appState.status == "invited") and not appState.pendingStatus then
        result.applicationLocked = true
        return false, "Already applied"
    end

    if result.keyLevel then
        if result.keyLevel < filters.allowedMin or result.keyLevel > filters.allowedMax then
            return false, "Outside allowed key range"
        end
    elseif filters.allowUnknownKeyLevel == false then
        return false, "Key level unavailable"
    end

    if not self:IsDungeonSelected(filters, result.dungeonName) then
        return false, "Dungeon not selected"
    end

    if result.numMembers < filters.minGroupSize then
        return false, "Group too small"
    end

    if filters.leaderScoreMin > 0 and result.leaderScore < filters.leaderScoreMin then
        return false, "Leader score below minimum"
    end

    if filters.ageMaxMinutes > 0 and result.ageSeconds > (filters.ageMaxMinutes * 60) then
        return false, "Listing too old"
    end

    local selectedRole = self:GetSelectedRole(filters)
    if (result.openSlots[selectedRole] or 0) <= 0 then
        return false, self:GetRoleLabel(selectedRole) .. " slot filled"
    end

    if result.openSlotsTotal < self:GetPartySize() then
        return false, "Not enough total party slots"
    end

    for _, role in ipairs(ROLE_ORDER) do
        if role ~= selectedRole and self:GetRoleState(filters, role) == "REQUIRED" and (result.roleCounts[role] or 0) <= 0 then
            return false, self:GetRoleLabel(role) .. " required"
        end
    end

    return true
end
