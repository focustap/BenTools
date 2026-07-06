local addonName, ns = ...

ns.AutoQueue = {}

local frame = CreateFrame("Frame")
local DUNGEON_CATEGORY_ID = LE_LFG_CATEGORY_DUNGEON or 2

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function Lower(value)
    return string.lower(value or "")
end

local function ParseLevelRange(value)
    value = Trim(value)
    if value == "" then
        return nil, nil
    end

    local minLevel, maxLevel = value:match("^(%d+)%s*[-:]%s*(%d+)$")
    if minLevel and maxLevel then
        minLevel = tonumber(minLevel)
        maxLevel = tonumber(maxLevel)
        if minLevel > maxLevel then
            minLevel, maxLevel = maxLevel, minLevel
        end
        return minLevel, maxLevel
    end

    local level = tonumber(value:match("^(%d+)$"))
    return level, level
end

local function GetPlayerRoleFlags()
    local role = GetSpecializationRole and GetSpecialization() and GetSpecializationRole(GetSpecialization()) or "DAMAGER"
    return role == "TANK", role == "HEALER", role == "DAMAGER"
end

local function GetPartyApplicantSize()
    local members = GetNumGroupMembers and GetNumGroupMembers() or 0
    if members <= 0 then
        return 1
    end
    return members
end

local function GetSearchMemberRoleCounts(resultID, numMembers)
    local tanks, healers, damage = 0, 0, 0
    if not C_LFGList.GetSearchResultMemberInfo then
        return tanks, healers, damage
    end

    for index = 1, numMembers or 0 do
        local role = C_LFGList.GetSearchResultMemberInfo(resultID, index)
        if role == "TANK" then
            tanks = tanks + 1
        elseif role == "HEALER" then
            healers = healers + 1
        elseif role == "DAMAGER" then
            damage = damage + 1
        end
    end

    return tanks, healers, damage
end

local GetResultText

local function ToSafeString(value)
    if value == nil then
        return ""
    end

    local ok, text = pcall(tostring, value)
    return ok and text or ""
end

local function CleanListingText(text)
    text = ToSafeString(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", " ")
    text = text:gsub("[%z\1-\31]", " ")
    return text
end

local function ParseListedKeyRange(text)
    text = CleanListingText(text)

    local minLevel, maxLevel = text:match("%+%s*(%d+)%s*[-]%s*(%d+)")
    if minLevel and maxLevel then
        minLevel = tonumber(minLevel)
        maxLevel = tonumber(maxLevel)
        if minLevel and maxLevel then
            if minLevel > maxLevel then
                minLevel, maxLevel = maxLevel, minLevel
            end
            return minLevel, maxLevel
        end
    end

    local plusLevel = text:match("%+%s*(%d+)")
    if plusLevel then
        plusLevel = tonumber(plusLevel)
        return plusLevel, plusLevel
    end

    local keyMin, keyMax = text:match("[Kk][Ee][Yy]%s*(%d+)%s*[-]%s*(%d+)")
    if keyMin and keyMax then
        keyMin = tonumber(keyMin)
        keyMax = tonumber(keyMax)
        if keyMin and keyMax then
            if keyMin > keyMax then
                keyMin, keyMax = keyMax, keyMin
            end
            return keyMin, keyMax
        end
    end

    local keyLevel = text:match("[Kk][Ee][Yy]%s*(%d+)")
    if keyLevel then
        keyLevel = tonumber(keyLevel)
        return keyLevel, keyLevel
    end

    return nil, nil
end

local function ParseResultKeyRange(info)
    if not info then
        return nil, nil
    end

    local minLevel, maxLevel = ParseListedKeyRange(info.name)
    if minLevel then
        return minLevel, maxLevel
    end

    minLevel, maxLevel = ParseListedKeyRange(info.comment)
    if minLevel then
        return minLevel, maxLevel
    end

    return ParseListedKeyRange(GetResultText(info))
end

local function GetActivityName(activityID)
    if not activityID then
        return ""
    end

    if C_LFGList.GetActivityFullName then
        local ok, name = pcall(C_LFGList.GetActivityFullName, activityID)
        if ok and name then
            return name
        end
    end

    if C_LFGList.GetActivityInfoTable then
        local ok, info = pcall(C_LFGList.GetActivityInfoTable, activityID)
        if ok and type(info) == "table" then
            return info.fullName or info.shortName or info.name or ""
        end
    end

    return ""
end

local function AddTextPart(parts, value)
    if value ~= nil and value ~= "" then
        table.insert(parts, ToSafeString(value))
    end
end

local function AddActivityText(parts, info)
    AddTextPart(parts, info.activityName)
    AddTextPart(parts, info.fullName)
    AddTextPart(parts, info.shortName)

    if info.activityID then
        AddTextPart(parts, GetActivityName(info.activityID))
    end

    if type(info.activityIDs) == "table" then
        for _, activityID in ipairs(info.activityIDs) do
            AddTextPart(parts, GetActivityName(activityID))
        end
    end
end

GetResultText = function(info)
    local parts = {}
    AddTextPart(parts, info.name)
    AddTextPart(parts, info.comment)
    AddActivityText(parts, info)
    return table.concat(parts, " ")
end

local function GetDisplayActivityName(info)
    local parts = {}
    AddActivityText(parts, info)
    return parts[1] or "Mythic+"
end

local function UpdateStatus(text)
    if ns.AutoQueue.statusText then
        ns.AutoQueue.statusText:SetText(text)
    end
end

local function UpdateTargetBoxes()
    local popup = ns.AutoQueue.popup
    if not popup or not ns.db or not ns.db.autoQueue then
        return
    end

    local config = ns.db.autoQueue
    popup.dungeonBox:SetText(config.dungeon or "")
    popup.rangeBox:SetText(config.minLevel == config.maxLevel and tostring(config.minLevel) or string.format("%d-%d", config.minLevel, config.maxLevel))
end

local function GetFinderSearchText()
    local searchBox = LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel.SearchBox
    if searchBox and searchBox.GetText then
        return Trim(searchBox:GetText())
    end
    return ""
end

local function ImportFinderSearchText()
    local text = GetFinderSearchText()
    if text == "" or not ns.db or not ns.db.autoQueue then
        return
    end

    local minLevel, maxLevel = ParseLevelRange(text)
    if minLevel then
        ns.db.autoQueue.minLevel = minLevel
        ns.db.autoQueue.maxLevel = maxLevel
    elseif ns.db.autoQueue.dungeon == "" then
        ns.db.autoQueue.dungeon = text
    end
end

local function GetBestCandidateText(candidate)
    if not candidate then
        return "No match cached."
    end

    local info = candidate.info
    local levelText = candidate.levelHidden and "hidden key" or candidate.levelText or ("+" .. candidate.level)
    return string.format(
        "%s %s - %s (%d/5)",
        levelText,
        GetDisplayActivityName(info),
        info.name or "Untitled",
        info.numMembers or 0
    )
end

local function RefreshPopup()
    local popup = ns.AutoQueue.popup
    if not popup then
        return
    end

    UpdateTargetBoxes()
    popup.bestText:SetText(GetBestCandidateText(ns.AutoQueue.bestCandidate))
end

local function CreatePopup()
    if ns.AutoQueue.popup then
        return ns.AutoQueue.popup
    end

    local popup = CreateFrame("Frame", "BenToolsAutoQueuePopup", UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(360, 230)
    popup:SetPoint("CENTER")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.title:SetPoint("TOPLEFT", 12, -6)
    popup.title:SetText("BenTools Mythic+ Queue")

    local dungeonLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dungeonLabel:SetPoint("TOPLEFT", 18, -42)
    dungeonLabel:SetText("Dungeon")

    local dungeonBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    dungeonBox:SetSize(150, 24)
    dungeonBox:SetAutoFocus(false)
    dungeonBox:SetPoint("TOPLEFT", 90, -36)
    popup.dungeonBox = dungeonBox

    local rangeLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeLabel:SetPoint("TOPLEFT", 18, -74)
    rangeLabel:SetText("Key")

    local rangeBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    rangeBox:SetSize(80, 24)
    rangeBox:SetAutoFocus(false)
    rangeBox:SetPoint("TOPLEFT", 90, -68)
    popup.rangeBox = rangeBox

    local saveButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    saveButton:SetSize(78, 24)
    saveButton:SetPoint("LEFT", rangeBox, "RIGHT", 12, 0)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        ns.AutoQueue:SetTarget(dungeonBox:GetText(), rangeBox:GetText())
        RefreshPopup()
    end)

    local scanButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    scanButton:SetSize(96, 26)
    scanButton:SetPoint("TOPLEFT", 18, -108)
    scanButton:SetText("Scan")
    scanButton:SetScript("OnClick", function()
        if ns.AutoQueue:SetTarget(dungeonBox:GetText(), rangeBox:GetText()) then
            ns.AutoQueue:Search()
        end
    end)

    local applyButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    applyButton:SetSize(96, 26)
    applyButton:SetPoint("LEFT", scanButton, "RIGHT", 12, 0)
    applyButton:SetText("Apply")
    applyButton:SetScript("OnClick", function()
        ns.AutoQueue:ApplyBest()
        RefreshPopup()
    end)

    local refreshButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    refreshButton:SetSize(96, 26)
    refreshButton:SetPoint("LEFT", applyButton, "RIGHT", 12, 0)
    refreshButton:SetText("Status")
    refreshButton:SetScript("OnClick", function()
        ns.AutoQueue:PrintStatus()
        RefreshPopup()
    end)

    local bestLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bestLabel:SetPoint("TOPLEFT", 18, -148)
    bestLabel:SetText("Best match")

    local bestText = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bestText:SetPoint("TOPLEFT", 18, -170)
    bestText:SetWidth(320)
    bestText:SetJustifyH("LEFT")
    bestText:SetText("No match cached.")
    popup.bestText = bestText

    local statusText = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 18, 16)
    statusText:SetWidth(320)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("Use any, ara, halls, etc. Key can be 10 or 10-11.")
    popup.statusText = statusText
    ns.AutoQueue.statusText = statusText

    ns.AutoQueue.popup = popup
    return popup
end

local function ShowPopup()
    ImportFinderSearchText()
    local popup = CreatePopup()
    RefreshPopup()
    popup:Show()
end

local function AttachGroupFinderButton()
    if ns.AutoQueue.finderButton or not LFGListFrame then
        return
    end

    local parent = LFGListFrame.SearchPanel or LFGListFrame
    local button = CreateFrame("Button", "BenToolsAutoQueueFinderButton", parent, "UIPanelButtonTemplate")
    button:SetSize(82, 22)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -48, -28)
    button:SetText("BenTools")
    button:SetScript("OnClick", ShowPopup)
    ns.AutoQueue.finderButton = button
end

local function ResultMatchesConfig(resultID, info, config)
    if not info or info.isDelisted or info.hasSelf then
        return false, "Unavailable"
    end

    if not config.includeFullGroups and (info.numMembers or 0) >= 5 then
        return false, "Full group"
    end

    local partySize = GetPartyApplicantSize()
    if config.requirePartyFit and ((info.numMembers or 0) + partySize > 5) then
        return false, "Not enough open party slots"
    end

    local text = GetResultText(info)
    local dungeon = Lower(config.dungeon)
    if dungeon ~= "" and dungeon ~= "any" and not Lower(text):find(dungeon, 1, true) then
        return false, "Different dungeon"
    end

    local listedMin, listedMax = ParseResultKeyRange(info)
    if not listedMin then
        if config.allowHiddenKeyLevel then
            return true, config.minLevel, true
        end
        return false, "Could not read key level"
    end

    local displayText = listedMin == listedMax and ("+" .. listedMin) or string.format("+%d-%d", listedMin, listedMax)
    if listedMax < config.minLevel or listedMin > config.maxLevel then
        return false, "Outside key range"
    end

    local wantsTank, wantsHealer, wantsDamage = GetPlayerRoleFlags()
    local tanks, healers, damage = GetSearchMemberRoleCounts(resultID, info.numMembers)
    if wantsTank and tanks >= 1 then
        return false, "Tank spot appears filled"
    elseif wantsHealer and healers >= 1 then
        return false, "Healer spot appears filled"
    elseif wantsDamage and damage >= 3 then
        return false, "DPS spots appear filled"
    end

    return true, listedMin, false, displayText
end

local function PrintCandidate(prefix, candidate)
    if not candidate then
        ns.Utils:Print(prefix .. " none")
        return
    end

    local info = candidate.info
    local levelText = candidate.levelHidden and "hidden key" or candidate.levelText or ("+" .. candidate.level)
    ns.Utils:Print(string.format(
        "%s %s %s - %s (%d/5)",
        prefix,
        levelText,
        GetDisplayActivityName(info),
        info.name or "Untitled",
        info.numMembers or 0
    ))
end

function ns.AutoQueue:PrintHelp()
    ns.Utils:Print("/bt queue - Open the Mythic+ queue popup")
    ns.Utils:Print("/bt queue set <dungeon|any> <level|min-max> - Set Mythic+ target")
    ns.Utils:Print("/bt queue scan - Search for matching Mythic+ listings")
    ns.Utils:Print("/bt queue apply - Apply to the best cached match")
    ns.Utils:Print("/bt queue status - Show current target and best match")
end

function ns.AutoQueue:SetTarget(dungeon, rangeText)
    local minLevel, maxLevel = ParseLevelRange(rangeText)
    if not minLevel then
        local text = "Use a key level or range, like 10 or 10-11."
        ns.Utils:Print(text)
        UpdateStatus(text)
        return false
    end

    local config = ns.db.autoQueue
    config.dungeon = Trim(dungeon)
    config.minLevel = minLevel
    config.maxLevel = maxLevel
    self.bestCandidate = nil
    local text = string.format("Mythic+ target set to %s +%d-%d.", config.dungeon ~= "" and config.dungeon or "any", minLevel, maxLevel)
    ns.Utils:Print(text)
    UpdateStatus(text)
    return true
end

function ns.AutoQueue:PrintStatus()
    local config = ns.db.autoQueue
    ns.Utils:Print(string.format("Mythic+ target: %s +%d-%d.", config.dungeon ~= "" and config.dungeon or "any", config.minLevel, config.maxLevel))
    PrintCandidate("Best cached match:", self.bestCandidate)
end

function ns.AutoQueue:Search()
    if not C_LFGList or not C_LFGList.Search then
        ns.Utils:Print("Premade Group Finder APIs are not available.")
        return
    end

    self.bestCandidate = nil
    local ok = pcall(C_LFGList.Search, DUNGEON_CATEGORY_ID, 0, 0, nil, true)
    if ok then
        local text = "Searching Premade Groups for matching Mythic+ listings..."
        ns.Utils:Print(text)
        UpdateStatus(text)
    else
        local text = "Search was blocked. Open Premade Groups > Dungeons, then scan again."
        ns.Utils:Print(text)
        UpdateStatus(text)
    end
end

function ns.AutoQueue:ProcessResults()
    local total, results = C_LFGList.GetSearchResults()
    local config = ns.db.autoQueue
    local matches = {}
    local rejectCounts = {}

    for _, resultID in ipairs(results or {}) do
        local info = C_LFGList.GetSearchResultInfo(resultID)
        local matchesConfig, value, levelHidden, levelText = ResultMatchesConfig(resultID, info, config)
        if matchesConfig then
            table.insert(matches, {
                resultID = resultID,
                info = info,
                level = value,
                levelHidden = levelHidden,
                levelText = levelText,
            })
        else
            rejectCounts[value or "Rejected"] = (rejectCounts[value or "Rejected"] or 0) + 1
        end
    end

    table.sort(matches, function(left, right)
        if left.levelHidden ~= right.levelHidden then
            return not left.levelHidden
        end
        if left.level == right.level then
            return (left.info.numMembers or 0) > (right.info.numMembers or 0)
        end
        return left.level < right.level
    end)

    self.bestCandidate = matches[1]
    local summary = string.format("Checked %d listings; %d matched.", total or 0, #matches)
    ns.Utils:Print(summary)
    UpdateStatus(summary)
    PrintCandidate("Best match:", self.bestCandidate)
    RefreshPopup()

    if self.bestCandidate and self.bestCandidate.levelHidden then
        ns.Utils:Print("Best match key level is hidden by the client; verify the row before applying.")
    end

    if #matches == 0 then
        local reasons = {}
        for reason, count in pairs(rejectCounts) do
            table.insert(reasons, string.format("%s: %d", reason, count))
        end
        table.sort(reasons)
        if #reasons > 0 then
            ns.Utils:Print("No-match reasons: " .. table.concat(reasons, "; "))
        end
    end
end

function ns.AutoQueue:ApplyBest()
    local candidate = self.bestCandidate
    if not candidate then
        ns.Utils:Print("No cached match. Run /bt queue scan first.")
        return
    end

    local tank, healer, damage = GetPlayerRoleFlags()
    local comment = ns.db.autoQueue.comment or ""
    local ok = pcall(C_LFGList.ApplyToGroup, candidate.resultID, comment, tank, healer, damage)
    if not ok then
        ok = pcall(C_LFGList.ApplyToGroup, candidate.resultID, tank, healer, damage)
    end

    if ok then
        PrintCandidate("Applied to:", candidate)
        self.bestCandidate = nil
        UpdateStatus("Applied to selected match.")
    else
        local text = "Apply was blocked. Try the Apply button again from a fresh click."
        ns.Utils:Print(text)
        UpdateStatus(text)
    end
end

function ns.AutoQueue:HandleSlash(message)
    message = Trim(message)
    local command, rest = message:match("^(%S+)%s*(.-)$")
    command = Lower(command)

    if command == "" or command == "open" or command == "show" then
        ShowPopup()
    elseif command == "help" then
        self:PrintHelp()
    elseif command == "set" then
        local dungeon, rangeText = rest:match("^(.-)%s+(%d+%s*[-:]?%s*%d*)$")
        self:SetTarget(dungeon or "", rangeText or "")
    elseif command == "scan" or command == "search" then
        self:Search()
    elseif command == "apply" then
        self:ApplyBest()
    elseif command == "status" then
        self:PrintStatus()
    else
        self:PrintHelp()
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" and ns.db and ns.db.autoQueue then
        ns.AutoQueue:ProcessResults()
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(1, AttachGroupFinderButton)
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_GroupFinder" then
        AttachGroupFinderButton()
    end
end)
