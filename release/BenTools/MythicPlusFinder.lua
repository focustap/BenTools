local addonName, ns = ...

ns.MythicPlusFinder = {}

local finder = ns.MythicPlusFinder
local filtersAPI = ns.MythicPlusFinderFilters
local rankingAPI = ns.MythicPlusFinderRanking
local applicationsAPI = ns.MythicPlusFinderApplications

local frame = CreateFrame("Frame")
local DUNGEON_CATEGORY_ID = LE_LFG_CATEGORY_DUNGEON or 2

finder.ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
finder.GROUP_CAPS = filtersAPI:GetCaps()

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function Lower(value)
    return string.lower(value or "")
end

local function DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = DeepCopy(value)
    end
    return copy
end

local function ParseKeyLevel(text)
    text = tostring(text or "")
    local value = text:match("%+%s*(%d+)")
    if value then
        return tonumber(value)
    end
    value = text:match("[Kk][Ee][Yy]%s*(%d+)")
    if value then
        return tonumber(value)
    end
    return nil
end

function finder:GetRoleIconAtlas(role)
    if role == "TANK" then
        return "groupfinder-icon-role-large-tank"
    elseif role == "HEALER" then
        return "groupfinder-icon-role-large-heal"
    end
    return "groupfinder-icon-role-large-dps"
end

function finder:Debug(message)
    local config = self:GetConfig()
    if config.debug then
        ns.Utils:Print("[M+] " .. tostring(message))
    end
end

function finder:GetConfig()
    return ns.db.mythicPlusFinder
end

function finder:GetFilters()
    return self:GetConfig().filters
end

function finder:GetUIState()
    return self:GetConfig().ui
end

function finder:EnsureDefaults()
    local config = self:GetConfig()
    config.defaultRole = config.defaultRole or "HEALER"
    config.filters.selectedRole = config.filters.selectedRole or config.defaultRole
    filtersAPI:ValidateFilters(config.filters)
    self.applicationStates = self.applicationStates or {}
    self.activeApplications = self.activeApplications or {}
    self.rawResults = self.rawResults or {}
    self.recommendedResults = self.recommendedResults or {}
    self.dungeonPool = self.dungeonPool or {}
end

function finder:GetSelectedRoleFlags()
    local role = filtersAPI:GetSelectedRole(self:GetFilters())
    return role == "TANK", role == "HEALER", role == "DAMAGER"
end

function finder:FormatAge(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds < 60 then
        return string.format("%ds", seconds)
    end
    return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
end

function finder:FormatKeyLabel(keyLevel)
    if keyLevel then
        return "+" .. tostring(keyLevel)
    end
    return "? key"
end

function finder:FormatResultLabel(result)
    if not result then
        return "Unknown listing"
    end
    return string.format("%s %s", self:FormatKeyLabel(result.keyLevel), result.dungeonName or result.title or "Unknown")
end

local function SafeScalarString(value)
    local valueType = type(value)
    if value == nil then
        return "nil"
    end
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    if valueType == "string" then
        local ok, text = pcall(tostring, value)
        if not ok then
            return "<unreadable string>"
        end
        if text:find("|K", 1, true) then
            return "<protected string>"
        end
        text = text:gsub("\r", " "):gsub("\n", " ")
        if #text > 120 then
            text = text:sub(1, 117) .. "..."
        end
        return text
    end
    return "<" .. valueType .. ">"
end

local function SortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

function finder:NormalizeResult(resultID)
    if not C_LFGList or not C_LFGList.GetSearchResultInfo then
        return nil
    end

    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info then
        return nil
    end

    local activityID = info.activityID
    if not activityID and type(info.activityIDs) == "table" then
        activityID = info.activityIDs[1]
    end

    local activityInfo = nil
    if activityID and C_LFGList.GetActivityInfoTable then
        local ok, value = pcall(C_LFGList.GetActivityInfoTable, activityID, nil, info.isWarMode)
        if ok and type(value) == "table" then
            activityInfo = value
        end
    end

    local roleCounts = {
        TANK = 0,
        HEALER = 0,
        DAMAGER = 0,
    }

    if C_LFGList.GetSearchResultMemberInfo then
        for index = 1, info.numMembers or 0 do
            local role = C_LFGList.GetSearchResultMemberInfo(resultID, index)
            if roleCounts[role] ~= nil then
                roleCounts[role] = roleCounts[role] + 1
            end
        end
    end

    local openSlots = {
        TANK = math.max(0, 1 - roleCounts.TANK),
        HEALER = math.max(0, 1 - roleCounts.HEALER),
        DAMAGER = math.max(0, 3 - roleCounts.DAMAGER),
    }
    local keyLevel = ParseKeyLevel(info.name)
        or ParseKeyLevel(info.comment)
        or ParseKeyLevel(activityInfo and activityInfo.fullName)
    local dungeonName = (activityInfo and (activityInfo.fullName or activityInfo.shortName or activityInfo.name)) or info.name or "Mythic+"
    dungeonName = tostring(dungeonName):gsub("^Mythic Keystone:%s*", "")
    dungeonName = dungeonName:gsub("%s*%((Mythic Keystone)%)", "")

    local result = {
        resultID = resultID,
        info = info,
        activityID = activityID,
        activityInfo = activityInfo,
        keyLevel = keyLevel,
        dungeonName = dungeonName,
        title = info.name or dungeonName,
        leaderName = info.leaderName or UNKNOWN,
        leaderScore = tonumber(info.leaderOverallDungeonScore) or 0,
        numMembers = tonumber(info.numMembers) or 0,
        ageSeconds = tonumber(info.ageSeconds or info.age) or 0,
        isDelisted = info.isDelisted and true or false,
        roleCounts = roleCounts,
        openSlots = openSlots,
        openSlotsTotal = math.max(0, 5 - (tonumber(info.numMembers) or 0)),
        hasSelf = info.hasSelf and true or false,
        comment = info.comment or "",
        voiceChat = info.voiceChat or "",
        autoAccept = info.autoAccept and true or false,
    }

    return result
end

function finder:RefreshDungeonPool()
    self.dungeonPool = filtersAPI:RefreshDungeonPool(self.rawResults)
    return self.dungeonPool
end

function finder:RefreshApplications()
    applicationsAPI:Refresh()
end

function finder:RebuildRecommendations()
    local config = self:GetConfig()
    local filters = filtersAPI:ValidateFilters(config.filters)
    self:RefreshApplications()

    local recommendations = {}
    local rawCount = #self.rawResults

    for _, result in ipairs(self.rawResults) do
        local appState = applicationsAPI:GetState(result.resultID)
        local passes, reason = filtersAPI:PassesHardFilters(result, filters, appState)
        result.ineligibleReason = passes and nil or reason
        if passes then
            local evaluation = rankingAPI:Evaluate(result, filters)
            result.matchScore = evaluation.score
            result.matchReasons = evaluation.reasons
            table.insert(recommendations, result)
        else
            result.matchScore = 0
            result.matchReasons = { { points = 0, text = reason or "Not eligible" } }
        end
    end

    table.sort(recommendations, function(left, right)
        if left.matchScore ~= right.matchScore then
            return left.matchScore > right.matchScore
        end
        if (left.keyLevel or 0) ~= (right.keyLevel or 0) then
            return (left.keyLevel or 0) > (right.keyLevel or 0)
        end
        if left.numMembers ~= right.numMembers then
            return left.numMembers > right.numMembers
        end
        return left.ageSeconds < right.ageSeconds
    end)

    self.recommendedResults = recommendations
    config.stats.lastRawResultCount = rawCount
    config.stats.lastFilteredCount = #recommendations
    self:RefreshDungeonPool()

    if self.UI and self.UI.frame and self.UI.frame:IsShown() then
        self.UI:Refresh()
    end
end

function finder:Search()
    if not C_LFGList or not C_LFGList.Search then
        ns.Utils:Print("[M+] Premade Group Finder APIs are not available.")
        return false
    end

    self:EnsureDefaults()
    local ui = self:GetUIState()
    if self.searchCooldownUntil and GetTime() < self.searchCooldownUntil then
        if self.UI then
            self.UI:SetSearchState("cooldown")
            self.UI:RefreshStatus()
        end
        return false
    end

    self.searchCooldownUntil = GetTime() + 2
    ui.lastSearchAt = time()
    self.rawResults = {}
    self.recommendedResults = {}

    local ok = pcall(C_LFGList.Search, DUNGEON_CATEGORY_ID, 0, 0, nil, true)
    self:Debug("Search requested")
    if self.UI then
        self.UI:SetSearchState(ok and "searching" or "blocked")
        self.UI:Refresh()
    end
    if not ok then
        ns.Utils:Print("[M+] Search was blocked. Open Premade Groups > Dungeons first, then try again.")
    end
    return ok
end

function finder:RefreshSearchResults()
    if not C_LFGList or not C_LFGList.GetSearchResults then
        return
    end

    local total, results = C_LFGList.GetSearchResults()
    if type(total) == "table" and results == nil then
        results = total
        total = #results
    end
    self.rawResults = {}
    for _, resultID in ipairs(results or {}) do
        local normalized = self:NormalizeResult(resultID)
        if normalized and normalized.activityInfo and normalized.activityInfo.isMythicPlusActivity then
            table.insert(self.rawResults, normalized)
        elseif normalized and normalized.keyLevel then
            table.insert(self.rawResults, normalized)
        end
    end

    self:Debug(string.format("%d raw results", tonumber(total) or #self.rawResults))
    self:RebuildRecommendations()
    if self.UI then
        if #self.rawResults == 0 then
            self.UI:SetSearchState("empty")
        else
            self.UI:SetSearchState("ready")
        end
        self.UI:Refresh()
    end
end

function finder:DumpSearchDiagnostics()
    if not C_LFGList or not C_LFGList.GetSearchResults or not C_LFGList.GetSearchResultInfo then
        ns.Utils:Print("[M+] LFG APIs are not available for diagnostics.")
        return
    end

    local total, results = C_LFGList.GetSearchResults()
    if type(total) == "table" and results == nil then
        results = total
        total = #results
    end

    results = results or {}
    ns.Utils:Print("[M+] === BenTools Mythic+ Search Dump ===")
    ns.Utils:Print("[M+] Search call: C_LFGList.Search(" .. tostring(DUNGEON_CATEGORY_ID) .. ", 0, 0, nil, true)")
    ns.Utils:Print("[M+] Raw result count: " .. tostring(total or #results))

    local filters = self:GetFilters()
    ns.Utils:Print(string.format(
        "[M+] Current filters: allowed +%d-%d, preferred +%d-%d, role %s",
        filters.allowedMin or 0,
        filters.allowedMax or 0,
        filters.preferredMin or 0,
        filters.preferredMax or 0,
        tostring(filters.selectedRole or "UNKNOWN")
    ))

    for index = 1, math.min(10, #results) do
        local resultID = results[index]
        local info = C_LFGList.GetSearchResultInfo(resultID)
        local activityID = info and (info.activityID or (type(info.activityIDs) == "table" and info.activityIDs[1])) or nil
        local activityInfo = nil
        if activityID and C_LFGList.GetActivityInfoTable then
            local ok, value = pcall(C_LFGList.GetActivityInfoTable, activityID, nil, info and info.isWarMode)
            if ok and type(value) == "table" then
                activityInfo = value
            end
        end

        local activityFullName = nil
        if activityID and C_LFGList.GetActivityFullName then
            local ok, value = pcall(C_LFGList.GetActivityFullName, activityID)
            if ok then
                activityFullName = value
            end
        end

        local keystoneForActivity = nil
        if activityID and C_LFGList.GetKeystoneForActivity then
            local ok, value = pcall(C_LFGList.GetKeystoneForActivity, activityID)
            if ok then
                keystoneForActivity = value
            end
        end

        local applicationStatus = nil
        local pendingStatus = nil
        if C_LFGList.GetApplicationInfo then
            local ok, _, appStatus, pending = pcall(C_LFGList.GetApplicationInfo, resultID)
            if ok then
                applicationStatus = appStatus
                pendingStatus = pending
            end
        end

        ns.Utils:Print("[M+] === BenTools M+ Result " .. tostring(index) .. " ===")
        ns.Utils:Print("[M+] searchResultID: " .. tostring(resultID))
        ns.Utils:Print("[M+] activityID: " .. tostring(activityID))
        ns.Utils:Print("[M+] activityFullName: " .. SafeScalarString(activityFullName))
        ns.Utils:Print("[M+] GetKeystoneForActivity: " .. SafeScalarString(keystoneForActivity))
        ns.Utils:Print("[M+] name: " .. SafeScalarString(info and info.name or nil))
        ns.Utils:Print("[M+] comment: " .. SafeScalarString(info and info.comment or nil))
        ns.Utils:Print("[M+] numMembers: " .. SafeScalarString(info and info.numMembers or nil))
        ns.Utils:Print("[M+] age: " .. SafeScalarString(info and (info.ageSeconds or info.age) or nil))
        ns.Utils:Print("[M+] leaderScore: " .. SafeScalarString(info and info.leaderOverallDungeonScore or nil))
        ns.Utils:Print("[M+] requiredScore: " .. SafeScalarString(info and info.requiredDungeonScore or nil))
        ns.Utils:Print("[M+] appStatus: " .. SafeScalarString(applicationStatus))
        ns.Utils:Print("[M+] pendingStatus: " .. SafeScalarString(pendingStatus))

        if activityInfo then
            ns.Utils:Print("[M+] activityInfo.fullName: " .. SafeScalarString(activityInfo.fullName))
            ns.Utils:Print("[M+] activityInfo.shortName: " .. SafeScalarString(activityInfo.shortName))
            ns.Utils:Print("[M+] activityInfo.groupFinderActivityGroupID: " .. SafeScalarString(activityInfo.groupFinderActivityGroupID))
            ns.Utils:Print("[M+] activityInfo.categoryID: " .. SafeScalarString(activityInfo.categoryID))
            ns.Utils:Print("[M+] activityInfo.filters: " .. SafeScalarString(activityInfo.filters))
            ns.Utils:Print("[M+] activityInfo.displayType: " .. SafeScalarString(activityInfo.displayType))
            ns.Utils:Print("[M+] activityInfo.orderIndex: " .. SafeScalarString(activityInfo.orderIndex))
            ns.Utils:Print("[M+] activityInfo.maxNumPlayers: " .. SafeScalarString(activityInfo.maxNumPlayers))
            ns.Utils:Print("[M+] activityInfo.isMythicPlusActivity: " .. SafeScalarString(activityInfo.isMythicPlusActivity))
            ns.Utils:Print("[M+] activityInfo.isMythicActivity: " .. SafeScalarString(activityInfo.isMythicActivity))
            ns.Utils:Print("[M+] activityInfo.useDungeonRoleExpectations: " .. SafeScalarString(activityInfo.useDungeonRoleExpectations))
        end

        if info then
            ns.Utils:Print("[M+] result keys:")
            for _, key in ipairs(SortedKeys(info)) do
                local value = info[key]
                local valueType = type(value)
                if key == "name" or key == "comment" then
                    ns.Utils:Print("[M+]   " .. tostring(key) .. " = " .. valueType .. " (" .. SafeScalarString(value) .. ")")
                elseif valueType == "number" or valueType == "boolean" then
                    ns.Utils:Print("[M+]   " .. tostring(key) .. " = " .. valueType .. " (" .. SafeScalarString(value) .. ")")
                elseif valueType == "table" then
                    ns.Utils:Print("[M+]   " .. tostring(key) .. " = table")
                else
                    ns.Utils:Print("[M+]   " .. tostring(key) .. " = " .. valueType)
                end
            end
        end
    end
end

function finder:GetResultByID(resultID)
    for _, result in ipairs(self.rawResults or {}) do
        if result.resultID == resultID then
            return result
        end
    end
    return nil
end

function finder:RevalidateResult(resultID)
    local refreshed = self:NormalizeResult(resultID)
    if not refreshed then
        return nil, "Listing unavailable"
    end
    local appState = applicationsAPI:GetState(resultID)
    local passes, reason = filtersAPI:PassesHardFilters(refreshed, self:GetFilters(), appState)
    if not passes then
        return nil, reason
    end
    local evaluation = rankingAPI:Evaluate(refreshed, self:GetFilters())
    refreshed.matchScore = evaluation.score
    refreshed.matchReasons = evaluation.reasons
    return refreshed
end

function finder:ApplyToResult(resultID)
    local result, reason = self:RevalidateResult(resultID)
    if not result then
        ns.Utils:Print("[M+] " .. tostring(reason or "Listing is no longer valid."))
        self:RefreshSearchResults()
        return false
    end

    local tank, healer, damage = self:GetSelectedRoleFlags()
    self:Debug("Apply requested for result " .. tostring(resultID))

    local callOk, applied = pcall(C_LFGList.ApplyToGroup, resultID, tank, healer, damage)

    if callOk and applied then
        local state = self.applicationStates[resultID] or {}
        state.resultID = resultID
        state.status = state.status or "requested"
        state.pendingStatus = state.pendingStatus or "requested"
        state.updatedAt = time()
        state.groupName = result.title or result.dungeonName
        state.requestedLabel = self:FormatResultLabel(result)
        self.applicationStates[resultID] = state
        self:RefreshApplications()
        self:RebuildRecommendations()
        ns.Utils:Print("[M+] Apply requested for " .. state.requestedLabel .. ".")
        if C_Timer and C_Timer.After then
            C_Timer.After(0.4, function()
                if ns.MythicPlusFinder then
                    ns.MythicPlusFinder:RefreshApplications()
                    ns.MythicPlusFinder:RebuildRecommendations()
                end
            end)
        end
        return true
    end

    if callOk and not applied then
        ns.Utils:Print("[M+] Direct apply was rejected by the Group Finder API for " .. self:FormatResultLabel(result) .. ". Use Blizzard Finder to sign up manually.")
        return false
    end

    ns.Utils:Print("[M+] Apply was blocked. Blizzard still requires a real click for each application.")
    return false
end

function finder:GetStatusText()
    local filters = self:GetFilters()
    local active = #((self.activeApplications) or {})
    local desired = filters.desiredActiveApplications or 5
    local lastSearchText = "never"
    if self:GetUIState().lastSearchAt and self:GetUIState().lastSearchAt > 0 then
        lastSearchText = self:FormatAge(time() - self:GetUIState().lastSearchAt) .. " ago"
    end
    return string.format(
        "Allowed +%d-%d | %d shown / %d raw | Active applications %d/%d | Last search %s",
        filters.allowedMin or 0,
        filters.allowedMax or 0,
        #(self.recommendedResults or {}),
        #(self.rawResults or {}),
        active,
        desired,
        lastSearchText
    )
end

function finder:PrintStatus()
    ns.Utils:Print("[M+] " .. self:GetStatusText())
    local nextBest = applicationsAPI:GetNextEligiblePlanEntry()
    if nextBest then
        ns.Utils:Print(string.format("[M+] Next best: +%d %s (score %d)", nextBest.keyLevel or 0, nextBest.dungeonName or "Unknown", nextBest.matchScore or 0))
    end
end

finder.BUILT_IN_PRESETS = {
    ["Healer Fast Group"] = {
        selectedRole = "HEALER",
        composition = { TANK = "REQUIRED", HEALER = "OPEN", DAMAGER = "ANY" },
        allowedMin = 8,
        allowedMax = 12,
        preferredMin = 10,
        preferredMax = 11,
        minGroupSize = 2,
        leaderScoreMin = 0,
        ageMaxMinutes = 10,
        preferFullGroups = true,
        preferStrongerLeader = true,
        preferFresh = true,
        desiredActiveApplications = 5,
        selectedDungeons = {},
    },
    ["DPS Tank+Heal"] = {
        selectedRole = "DAMAGER",
        composition = { TANK = "REQUIRED", HEALER = "REQUIRED", DAMAGER = "OPEN" },
        allowedMin = 10,
        allowedMax = 14,
        preferredMin = 11,
        preferredMax = 13,
        minGroupSize = 3,
        leaderScoreMin = 0,
        ageMaxMinutes = 10,
        preferFullGroups = true,
        preferStrongerLeader = true,
        preferFresh = true,
        desiredActiveApplications = 5,
        selectedDungeons = {},
    },
    ["Tank Push Keys"] = {
        selectedRole = "TANK",
        composition = { TANK = "OPEN", HEALER = "PREFERRED", DAMAGER = "ANY" },
        allowedMin = 10,
        allowedMax = 15,
        preferredMin = 12,
        preferredMax = 14,
        minGroupSize = 2,
        leaderScoreMin = 2200,
        ageMaxMinutes = 10,
        preferFullGroups = true,
        preferStrongerLeader = true,
        preferFresh = true,
        desiredActiveApplications = 5,
        selectedDungeons = {},
    },
}

function finder:LoadPreset(name)
    if not name or name == "" then
        return false
    end
    local source = self.BUILT_IN_PRESETS[name] or self:GetConfig().presets[name]
    if not source then
        ns.Utils:Print("[M+] Preset not found: " .. tostring(name))
        return false
    end
    local filters = self:GetFilters()
    for key in pairs(filters) do
        if type(filters[key]) ~= "function" then
            filters[key] = nil
        end
    end
    for key, value in pairs(DeepCopy(source)) do
        filters[key] = value
    end
    filtersAPI:ValidateFilters(filters)
    self:GetUIState().selectedPresetName = name
    self:RebuildRecommendations()
    return true
end

function finder:SaveCurrentPreset(name)
    name = Trim(name)
    if name == "" then
        return false
    end
    self:GetConfig().presets[name] = DeepCopy(self:GetFilters())
    self:GetUIState().selectedPresetName = name
    return true
end

function finder:DeletePreset(name)
    if self:GetConfig().presets[name] then
        self:GetConfig().presets[name] = nil
        if self:GetUIState().selectedPresetName == name then
            self:GetUIState().selectedPresetName = ""
        end
        return true
    end
    return false
end

function finder:RenamePreset(oldName, newName)
    oldName = Trim(oldName)
    newName = Trim(newName)
    if oldName == "" or newName == "" or not self:GetConfig().presets[oldName] then
        return false
    end
    self:GetConfig().presets[newName] = DeepCopy(self:GetConfig().presets[oldName])
    self:GetConfig().presets[oldName] = nil
    self:GetUIState().selectedPresetName = newName
    return true
end

function finder:HandleSlash(message)
    local trimmed = Trim(message)
    local command, rest = trimmed:match("^(%S+)%s*(.-)$")
    command = Lower(command)

    if command == "" or command == "open" or command == "show" then
        if self.UI then
            self.UI:Open()
        end
    elseif command == "search" then
        self:Search()
    elseif command == "status" then
        self:PrintStatus()
    elseif command == "dump" then
        self:DumpSearchDiagnostics()
    elseif command == "debug" then
        self:GetConfig().debug = not self:GetConfig().debug
        ns.Utils:Print("[M+] Debug " .. (self:GetConfig().debug and "enabled." or "disabled."))
    elseif command == "preset" and rest ~= "" then
        if self:LoadPreset(rest) then
            ns.Utils:Print("[M+] Loaded preset: " .. rest)
            if self.UI then
                self.UI:Refresh()
                self.UI:Open()
            end
        end
    else
        if self.UI then
            self.UI:Open()
        end
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
frame:RegisterEvent("LFG_LIST_SEARCH_FAILED")
frame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        finder:EnsureDefaults()
        if finder.UI and finder.UI.Initialize then
            finder.UI:Initialize()
        end
    elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        finder:RefreshSearchResults()
    elseif event == "LFG_LIST_SEARCH_FAILED" then
        if finder.UI then
            finder.UI:SetSearchState("error")
            finder.UI:Refresh()
        end
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local resultID, newStatus, oldStatus, groupName = ...
        local state = finder.applicationStates and finder.applicationStates[resultID]
        if state then
            state.status = newStatus or state.status
            state.pendingStatus = nil
            state.updatedAt = time()
            state.groupName = groupName or state.groupName
            local label = state.requestedLabel or groupName or ("result " .. tostring(resultID))
            if newStatus == "applied" and oldStatus ~= "applied" then
                ns.Utils:Print("[M+] Application confirmed for " .. label .. ".")
            elseif newStatus == "invited" and oldStatus ~= "invited" then
                ns.Utils:Print("[M+] Invite received for " .. label .. ".")
            elseif (newStatus == "declined" or newStatus == "cancelled" or newStatus == "invitedeclined") and oldStatus ~= newStatus then
                ns.Utils:Print("[M+] Application update for " .. label .. ": " .. tostring(newStatus) .. ".")
            end
        end
        finder:RefreshApplications()
        finder:RebuildRecommendations()
    elseif event == "GROUP_ROSTER_UPDATE" then
        finder:RebuildRecommendations()
    end
end)
