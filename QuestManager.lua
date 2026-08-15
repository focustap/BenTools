local addonName, ns = ...

ns.QuestManager = {}

local QM = ns.QuestManager

local EXPANSIONS = {
    { key = "midnight", name = "Midnight", constants = { "LE_EXPANSION_MIDNIGHT" }, fallbackID = 11 },
    { key = "warWithin", name = "The War Within", constants = { "LE_EXPANSION_WAR_WITHIN", "LE_EXPANSION_THE_WAR_WITHIN" }, fallbackID = 10 },
    { key = "dragonflight", name = "Dragonflight", constants = { "LE_EXPANSION_DRAGONFLIGHT" }, fallbackID = 9 },
    { key = "shadowlands", name = "Shadowlands", constants = { "LE_EXPANSION_SHADOWLANDS" }, fallbackID = 8 },
    { key = "bfa", name = "Battle for Azeroth", constants = { "LE_EXPANSION_BATTLE_FOR_AZEROTH" }, fallbackID = 7 },
    { key = "legion", name = "Legion", constants = { "LE_EXPANSION_LEGION" }, fallbackID = 6 },
    { key = "wod", name = "Warlords of Draenor", constants = { "LE_EXPANSION_WARLORDS_OF_DRAENOR" }, fallbackID = 5 },
    { key = "mop", name = "Mists of Pandaria", constants = { "LE_EXPANSION_MISTS_OF_PANDARIA" }, fallbackID = 4 },
    { key = "cataclysm", name = "Cataclysm", constants = { "LE_EXPANSION_CATACLYSM" }, fallbackID = 3 },
    { key = "wrath", name = "Wrath of the Lich King", constants = { "LE_EXPANSION_WRATH_OF_THE_LICH_KING" }, fallbackID = 2 },
    { key = "tbc", name = "The Burning Crusade", constants = { "LE_EXPANSION_BURNING_CRUSADE" }, fallbackID = 1 },
    { key = "classic", name = "Classic", constants = { "LE_EXPANSION_CLASSIC" }, fallbackID = 0 },
    { key = "unknown", name = "Unknown / Other", unknown = true },
}

local EXPANSION_BY_ID = {}
local HEADER_HEIGHT = 24
local ROW_HEIGHT = 24
local LIST_WIDTH = 758
local FILTER_ALL = "all"

local function ResolveExpansionIDs()
    wipe(EXPANSION_BY_ID)

    for _, expansion in ipairs(EXPANSIONS) do
        if not expansion.unknown then
            local id
            for _, constant in ipairs(expansion.constants) do
                if type(_G[constant]) == "number" then
                    id = _G[constant]
                    break
                end
            end
            if id == nil then
                id = expansion.fallbackID
            end
            expansion.id = id
            EXPANSION_BY_ID[id] = expansion
        end
    end
end

local function GetQuestExpansionGroup(questID)
    if C_QuestLog and C_QuestLog.GetQuestExpansion and questID then
        local ok, expansionID = pcall(C_QuestLog.GetQuestExpansion, questID)
        if ok and EXPANSION_BY_ID[expansionID] then
            return EXPANSION_BY_ID[expansionID]
        end
    end

    if _G.GetQuestExpansion and questID then
        local ok, expansionID = pcall(_G.GetQuestExpansion, questID)
        if ok and EXPANSION_BY_ID[expansionID] then
            return EXPANSION_BY_ID[expansionID]
        end
    end

    return EXPANSIONS[#EXPANSIONS]
end

local function IsPseudoQuestRow(info)
    if not info or info.isHeader or info.isBounty or info.isTask or not info.questID or info.questID == 0 then
        return true
    end

    local title = info.title or ""
    if title:match("^Level %d+$") or title == "Tracking Quest" then
        return true
    end

    return false
end

local function GetQuestInfo(index)
    if not C_QuestLog or not C_QuestLog.GetInfo then
        return nil
    end

    local ok, info = pcall(C_QuestLog.GetInfo, index)
    if ok and type(info) == "table" then
        return info
    end
    return nil
end

local function IsComplete(questID)
    if C_QuestLog and C_QuestLog.IsComplete and questID then
        local ok, complete = pcall(C_QuestLog.IsComplete, questID)
        return ok and complete == true
    end
    return false
end

local function GetFrequency(info, questID)
    if info and info.frequency ~= nil then
        return info.frequency
    end

    if C_QuestLog and C_QuestLog.GetQuestFrequency and questID then
        local ok, frequency = pcall(C_QuestLog.GetQuestFrequency, questID)
        if ok then
            return frequency
        end
    end
    return nil
end

local function FrequencyName(frequency)
    local daily = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily or 1
    local weekly = Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly or 2

    if frequency == daily then
        return "Daily"
    elseif frequency == weekly then
        return "Weekly"
    end
    return nil
end

local function QuestClassificationName(classification)
    local questClassification = Enum and Enum.QuestClassification
    if questClassification then
        if classification == questClassification.Campaign then
            return "Campaign"
        elseif classification == questClassification.Legendary then
            return "Legendary"
        elseif classification == questClassification.Important then
            return "Important"
        end
    end

    if classification == 3 then
        return "Campaign"
    elseif classification == 2 then
        return "Legendary"
    elseif classification == 1 then
        return "Important"
    end
    return nil
end

local function GetCampaignID(questID)
    if C_CampaignInfo and C_CampaignInfo.GetCampaignID and questID then
        local ok, campaignID = pcall(C_CampaignInfo.GetCampaignID, questID)
        if ok and type(campaignID) == "number" and campaignID > 0 then
            return campaignID
        end
    end
    return nil
end

local function GetQuestType(info, questID)
    local classificationName = QuestClassificationName(info and info.questClassification)
    if classificationName then
        return classificationName, classificationName ~= "Campaign"
    end

    if GetCampaignID(questID) then
        return "Campaign", false
    end

    local frequencyName = FrequencyName(GetFrequency(info, questID))
    if frequencyName then
        return frequencyName, false
    end

    if info and info.isTask then
        return "Task", false
    elseif info and info.isBounty then
        return "Bounty", false
    elseif IsComplete(questID) then
        return "Complete", false
    end

    return "Quest", false
end

local function IsProtectedQuest(quest)
    return quest.isCampaign or quest.type == "Important" or quest.type == "Legendary" or quest.type == "Bounty" or quest.type == "Task"
end

local function MatchesFilter(quest, filter)
    if filter == FILTER_ALL then
        return true
    elseif filter == "campaign" then
        return quest.isCampaign
    elseif filter == "daily" then
        return quest.type == "Daily"
    elseif filter == "weekly" then
        return quest.type == "Weekly"
    elseif filter == "complete" then
        return quest.isComplete
    elseif filter == "side" then
        return not quest.isCampaign and quest.type ~= "Daily" and quest.type ~= "Weekly" and quest.type ~= "Important" and quest.type ~= "Legendary"
    end

    return true
end

local function QuestIsVisible(quest)
    local search = QM.searchText or ""
    if search ~= "" and not string.find(string.lower(quest.title or ""), search, 1, true) then
        return false
    end

    return MatchesFilter(quest, QM.filter or FILTER_ALL)
end

local function CreateLineTexture(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 118, 24)
    button:SetText(text)
    return button
end

local function CreateCheckbox(parent)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    if not checkbox.Text then
        checkbox.Text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
    end
    return checkbox
end

local function ClearRowPool(pool)
    if not pool then
        return
    end

    for _, row in ipairs(pool) do
        row:Hide()
    end
end

function QM:GetConfig()
    ns.db.questManager = ns.db.questManager or {}
    ns.db.questManager.collapsed = ns.db.questManager.collapsed or {}
    return ns.db.questManager
end

function QM:BuildQuestData()
    local groups = {}
    local byID = {}

    for _, expansion in ipairs(EXPANSIONS) do
        groups[expansion.key] = {
            expansion = expansion,
            quests = {},
            visibleQuests = {},
        }
    end

    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        self.groups = groups
        self.questByID = byID
        return
    end

    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, count do
        local info = GetQuestInfo(index)
        if info and not IsPseudoQuestRow(info) then
            local expansion = GetQuestExpansionGroup(info.questID)
            local questType, classificationProtected = GetQuestType(info, info.questID)
            local quest = {
                questID = info.questID,
                index = index,
                title = info.title or (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(info.questID)) or ("Quest " .. tostring(info.questID)),
                level = info.level or info.difficultyLevel,
                expansion = expansion,
                type = questType,
                isCampaign = questType == "Campaign" or classificationProtected,
                isComplete = IsComplete(info.questID),
                rawInfo = info,
            }

            table.insert(groups[expansion.key].quests, quest)
            byID[quest.questID] = quest
        end
    end

    for _, group in pairs(groups) do
        table.sort(group.quests, function(left, right)
            return string.lower(left.title or "") < string.lower(right.title or "")
        end)
    end

    self.groups = groups
    self.questByID = byID
end

function QM:DebugExpansionData()
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        ns.Utils:Print("Quest log APIs are not available.")
        return
    end

    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    for index = 1, count do
        local info = GetQuestInfo(index)
        if info and not IsPseudoQuestRow(info) then
            local cValue = "n/a"
            local globalValue = "n/a"
            if C_QuestLog.GetQuestExpansion then
                local ok, value = pcall(C_QuestLog.GetQuestExpansion, info.questID)
                cValue = ok and tostring(value) or "error"
            end
            if _G.GetQuestExpansion then
                local ok, value = pcall(_G.GetQuestExpansion, info.questID)
                globalValue = ok and tostring(value) or "error"
            end
            ns.Utils:Print(string.format("Quest %d: %s | C=%s global=%s", info.questID, info.title or "?", cValue, globalValue))
        end
    end
end

function QM:GetSelectedCount()
    local count = 0
    for questID in pairs(self.selected or {}) do
        if self.questByID and self.questByID[questID] then
            count = count + 1
        end
    end
    return count
end

function QM:SetQuestSelected(quest, selected)
    if not quest then
        return
    end

    if selected and (quest.type == "Bounty" or quest.type == "Task") then
        return
    end

    if selected and IsProtectedQuest(quest) and not self:GetConfig().includeCampaign then
        return
    end

    self.selected[quest.questID] = selected and true or nil
end

function QM:SetExpansionSelected(expansionKey, selected)
    local group = self.groups and self.groups[expansionKey]
    if not group then
        return
    end

    for _, quest in ipairs(group.visibleQuests) do
        self:SetQuestSelected(quest, selected)
    end
end

function QM:SetAllVisibleSelected(selected)
    for _, expansion in ipairs(EXPANSIONS) do
        self:SetExpansionSelected(expansion.key, selected)
    end
end

function QM:PruneSelection()
    for questID in pairs(self.selected) do
        local quest = self.questByID and self.questByID[questID]
        if not quest or quest.type == "Bounty" or quest.type == "Task" or (IsProtectedQuest(quest) and not self:GetConfig().includeCampaign) then
            self.selected[questID] = nil
        end
    end
end

function QM:UpdateStatus()
    if not self.statusText then
        return
    end

    local selected = self:GetSelectedCount()
    if selected == 1 then
        self.statusText:SetText("1 quest selected.")
    else
        self.statusText:SetText(string.format("%d quests selected.", selected))
    end

    if self.abandonButton then
        self.abandonButton:SetEnabled(selected > 0 and not self.abandoning)
    end
end

function QM:CreateHeaderRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(LIST_WIDTH, HEADER_HEIGHT)

    row.bg = CreateLineTexture(row, 0.05, 0.05, 0.05, 0.9)
    row.bg:SetAllPoints()

    row.toggle = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.toggle:SetPoint("LEFT", 6, 0)
    row.toggle:SetWidth(18)

    row.checkbox = CreateCheckbox(row)
    row.checkbox:SetPoint("LEFT", 24, 0)

    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.title:SetPoint("LEFT", 54, 0)
    row.title:SetPoint("RIGHT", -10, 0)
    row.title:SetJustifyH("LEFT")

    row.checkbox:SetScript("OnClick", function(check)
        QM:SetExpansionSelected(row.expansionKey, check:GetChecked())
        QM:RefreshDisplay()
    end)

    row:SetScript("OnClick", function()
        local config = QM:GetConfig()
        config.collapsed[row.expansionKey] = not config.collapsed[row.expansionKey] or nil
        QM:RefreshDisplay()
    end)

    return row
end

function QM:CreateQuestRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)

    row.bg = CreateLineTexture(row, 0, 0, 0, 0.35)
    row.bg:SetAllPoints()

    row.checkbox = CreateCheckbox(row)
    row.checkbox:SetPoint("LEFT", 34, 0)

    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.title:SetPoint("LEFT", 64, 0)
    row.title:SetWidth(418)
    row.title:SetJustifyH("LEFT")

    row.level = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.level:SetPoint("LEFT", row.title, "RIGHT", 8, 0)
    row.level:SetWidth(48)
    row.level:SetJustifyH("CENTER")

    row.expansion = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.expansion:SetPoint("LEFT", row.level, "RIGHT", 8, 0)
    row.expansion:SetWidth(150)
    row.expansion:SetJustifyH("LEFT")

    row.kind = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.kind:SetPoint("RIGHT", -12, 0)
    row.kind:SetWidth(92)
    row.kind:SetJustifyH("RIGHT")

    row.checkbox:SetScript("OnClick", function(check)
        QM:SetQuestSelected(row.quest, check:GetChecked())
        QM:RefreshDisplay()
    end)

    row:SetScript("OnClick", function()
        if not row.checkbox:IsEnabled() then
            return
        end
        QM:SetQuestSelected(row.quest, not QM.selected[row.quest.questID])
        QM:RefreshDisplay()
    end)

    return row
end

function QM:CreateWindow()
    if self.window then
        return
    end

    local frame = CreateFrame("Frame", "BenToolsQuestManagerFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(860, 620)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    self.window = frame

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -6)
    frame.title:SetText("BenTools - Quest Manager")

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(330, 24)
    searchBox:SetPoint("TOPLEFT", 24, -42)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(box)
        self.searchText = string.lower(box:GetText() or "")
        self:RefreshDisplay()
    end)
    searchBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
    end)
    self.searchBox = searchBox

    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", 6, 0)
    placeholder:SetText("Search quests")
    searchBox:SetScript("OnEditFocusGained", function()
        placeholder:Hide()
    end)
    searchBox:SetScript("OnEditFocusLost", function(box)
        if box:GetText() == "" then
            placeholder:Show()
        end
    end)
    searchBox:SetScript("OnTextChanged", function(box)
        placeholder:SetShown((box:GetText() or "") == "" and not box:HasFocus())
        self.searchText = string.lower(box:GetText() or "")
        self:RefreshDisplay()
    end)

    local includeCampaign = CreateCheckbox(frame)
    includeCampaign:SetPoint("TOPLEFT", searchBox, "TOPRIGHT", 36, 4)
    includeCampaign.Text:SetText("Include Campaign Quests")
    includeCampaign:SetScript("OnClick", function(check)
        self:GetConfig().includeCampaign = check:GetChecked() and true or false
        self:PruneSelection()
        self:RefreshDisplay()
    end)
    self.includeCampaign = includeCampaign

    local filter = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
    filter:SetPoint("LEFT", includeCampaign.Text, "RIGHT", 28, -2)
    self.filterDropdown = filter
    local filterOptions = {
        { value = FILTER_ALL, text = "All Types" },
        { value = "campaign", text = "Campaign" },
        { value = "side", text = "Side Quests" },
        { value = "daily", text = "Daily" },
        { value = "weekly", text = "Weekly" },
        { value = "complete", text = "Completed" },
    }
    local function SetFilter(value, text)
        self.filter = value
        UIDropDownMenu_SetText(filter, text)
        if self.content then
            self:RefreshDisplay()
        end
    end
    UIDropDownMenu_Initialize(filter, function()
        for _, option in ipairs(filterOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.func = function()
                SetFilter(option.value, option.text)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(filter, 120)
    SetFilter(FILTER_ALL, "All Types")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 24, -78)
    scrollFrame:SetPoint("BOTTOMRIGHT", -44, 76)
    self.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(LIST_WIDTH, 1)
    scrollFrame:SetScrollChild(content)
    self.content = content
    self.headerRows = {}
    self.questRows = {}

    local selectAll = CreateButton(frame, "Select All", 128)
    selectAll:SetPoint("BOTTOMLEFT", 24, 42)
    selectAll:SetScript("OnClick", function()
        self:SetAllVisibleSelected(true)
        self:RefreshDisplay()
    end)

    local deselectAll = CreateButton(frame, "Deselect All", 128)
    deselectAll:SetPoint("LEFT", selectAll, "RIGHT", 12, 0)
    deselectAll:SetScript("OnClick", function()
        self:SetAllVisibleSelected(false)
        self:RefreshDisplay()
    end)

    local selectExpansion = CreateButton(frame, "Select Expansion", 150)
    selectExpansion:SetPoint("LEFT", deselectAll, "RIGHT", 12, 0)
    local expansionMenu = CreateFrame("Frame", "BenToolsQuestManagerExpansionMenu", frame, "UIDropDownMenuTemplate")
    selectExpansion:SetScript("OnClick", function()
        UIDropDownMenu_Initialize(expansionMenu, function()
            for _, expansion in ipairs(EXPANSIONS) do
                local group = self.groups and self.groups[expansion.key]
                local info = UIDropDownMenu_CreateInfo()
                info.text = string.format("%s (%d)", expansion.name, group and #group.visibleQuests or 0)
                info.disabled = not group or #group.visibleQuests == 0
                info.func = function()
                    self:SetExpansionSelected(expansion.key, true)
                    self:RefreshDisplay()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        ToggleDropDownMenu(1, nil, expansionMenu, selectExpansion, 0, 0)
    end)

    local refresh = CreateButton(frame, "Refresh", 86)
    refresh:SetPoint("LEFT", selectExpansion, "RIGHT", 12, 0)
    refresh:SetScript("OnClick", function()
        self:Refresh()
    end)

    local abandon = CreateButton(frame, "Abandon Selected", 150)
    abandon:SetPoint("BOTTOMRIGHT", -24, 42)
    abandon:SetScript("OnClick", function()
        self:ConfirmAbandonSelected()
    end)
    self.abandonButton = abandon

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    status:SetPoint("BOTTOMLEFT", 28, 16)
    status:SetTextColor(0.2, 1, 0.2)
    self.statusText = status
end

function QM:RefreshDisplay()
    if not self.window then
        return
    end

    self:BuildQuestData()
    self:PruneSelection()
    ClearRowPool(self.headerRows)
    ClearRowPool(self.questRows)

    self.includeCampaign:SetChecked(self:GetConfig().includeCampaign)

    local headerIndex = 0
    local questIndex = 0
    local y = 0

    for _, expansion in ipairs(EXPANSIONS) do
        local group = self.groups[expansion.key]
        wipe(group.visibleQuests)
        for _, quest in ipairs(group.quests) do
            if QuestIsVisible(quest) then
                table.insert(group.visibleQuests, quest)
            end
        end

        headerIndex = headerIndex + 1
        local header = self.headerRows[headerIndex]
        if not header then
            header = self:CreateHeaderRow(self.content)
            self.headerRows[headerIndex] = header
        end

        local collapsed = self:GetConfig().collapsed[expansion.key]
        header.expansionKey = expansion.key
        header:SetPoint("TOPLEFT", 0, -y)
        header.toggle:SetText(collapsed and "+" or "-")
        header.title:SetText(string.format("%s (%d)", expansion.name, #group.visibleQuests))
        local selectableCount = 0
        for _, quest in ipairs(group.visibleQuests) do
            if quest.type ~= "Bounty" and quest.type ~= "Task" and (self:GetConfig().includeCampaign or not IsProtectedQuest(quest)) then
                selectableCount = selectableCount + 1
            end
        end
        header.checkbox:SetEnabled(selectableCount > 0)

        local allSelected = selectableCount > 0
        for _, quest in ipairs(group.visibleQuests) do
            if quest.type ~= "Bounty" and quest.type ~= "Task" and (self:GetConfig().includeCampaign or not IsProtectedQuest(quest)) and not self.selected[quest.questID] then
                allSelected = false
                break
            end
        end
        header.checkbox:SetChecked(allSelected)
        header:Show()
        y = y + HEADER_HEIGHT

        if not collapsed then
            for _, quest in ipairs(group.visibleQuests) do
                questIndex = questIndex + 1
                local row = self.questRows[questIndex]
                if not row then
                    row = self:CreateQuestRow(self.content)
                    self.questRows[questIndex] = row
                end

                local protected = quest.type == "Bounty" or quest.type == "Task" or (IsProtectedQuest(quest) and not self:GetConfig().includeCampaign)
                row.quest = quest
                row:SetPoint("TOPLEFT", 0, -y)
                row.title:SetText(quest.title)
                row.level:SetText(quest.level and quest.level > 0 and tostring(quest.level) or "-")
                row.expansion:SetText(quest.expansion.name)
                if quest.type == "Bounty" or quest.type == "Task" then
                    row.kind:SetText("System")
                else
                    row.kind:SetText(quest.type)
                end
                row.checkbox:SetEnabled(not protected)
                row.checkbox:SetChecked(self.selected[quest.questID] == true)
                row.title:SetTextColor(protected and 0.55 or 1, protected and 0.55 or 1, protected and 0.55 or 1)
                row:Show()
                y = y + ROW_HEIGHT
            end
        end
    end

    self.content:SetHeight(math.max(y, 1))
    self:UpdateStatus()
end

function QM:Refresh()
    if self.window and self.window:IsShown() then
        self:RefreshDisplay()
    end
end

function QM:ScheduleRefresh()
    if self.refreshPending then
        return
    end
    self.refreshPending = true
    C_Timer.After(0.1, function()
        QM.refreshPending = nil
        QM:Refresh()
    end)
end

function QM:GetSelectedQuests()
    local quests = {}
    for questID in pairs(self.selected) do
        local quest = self.questByID and self.questByID[questID]
        if quest and quest.type ~= "Bounty" and quest.type ~= "Task" and (self:GetConfig().includeCampaign or not IsProtectedQuest(quest)) then
            table.insert(quests, quest)
        end
    end
    table.sort(quests, function(left, right)
        if left.expansion.key == right.expansion.key then
            return string.lower(left.title) < string.lower(right.title)
        end
        return (left.expansion.id or 99) > (right.expansion.id or 99)
    end)
    return quests
end

function QM:GetAbandonSummary(quests)
    local counts = {}
    for _, quest in ipairs(quests) do
        counts[quest.expansion.name] = (counts[quest.expansion.name] or 0) + 1
    end

    local lines = {}
    for _, expansion in ipairs(EXPANSIONS) do
        local count = counts[expansion.name]
        if count then
            table.insert(lines, string.format("%s: %d", expansion.name, count))
        end
    end

    return table.concat(lines, "\n")
end

function QM:ConfirmAbandonSelected()
    local quests = self:GetSelectedQuests()
    if #quests == 0 then
        ns.Utils:Print("No quests selected.")
        return
    end

    StaticPopupDialogs.BENTOOLS_CONFIRM_ABANDON_QUESTS = {
        text = string.format("Abandon %d selected quests?\n\n%s", #quests, self:GetAbandonSummary(quests)),
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            QM:StartAbandon(quests)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("BENTOOLS_CONFIRM_ABANDON_QUESTS")
end

function QM:StartAbandon(quests)
    if self.abandoning then
        return
    end

    self.abandoning = true
    self.abandonQueue = {}
    for _, quest in ipairs(quests) do
        table.insert(self.abandonQueue, quest.questID)
    end
    self.requestedCount = 0
    self.failedCount = 0
    self:UpdateStatus()
    self:AbandonNext()
end

function QM:AbandonNext()
    if not self.abandoning then
        return
    end

    local questID = table.remove(self.abandonQueue, 1)
    if not questID then
        self.abandoning = false
        ns.Utils:Print(string.format("Quest cleanup complete: %d abandon requests sent, %d API errors.", self.requestedCount or 0, self.failedCount or 0))
        self:RefreshDisplay()
        return
    end

    local quest = self.questByID and self.questByID[questID]
    if not quest then
        self.failedCount = self.failedCount + 1
        C_Timer.After(0.05, function()
            QM:AbandonNext()
        end)
        return
    end

    local ok = false
    if C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest then
        -- Blizzard's abandon flow is quest-specific: select the quest, mark it as the abandon target, then request abandon.
        ok = pcall(function()
            C_QuestLog.SetSelectedQuest(questID)
            C_QuestLog.SetAbandonQuest()
            C_QuestLog.AbandonQuest()
        end)
    end

    if not ok then
        self.failedCount = self.failedCount + 1
        ns.Utils:Print("Could not abandon: " .. (quest.title or tostring(questID)))
        C_Timer.After(0.15, function()
            QM:AbandonNext()
        end)
        return
    end

    self.selected[questID] = nil
    self.requestedCount = self.requestedCount + 1

    C_Timer.After(0.25, function()
        QM:AbandonNext()
    end)
end

function QM:Open()
    self:CreateWindow()
    self.window:Show()
    self:RefreshDisplay()
end

function QM:CreateSettingsPanel()
    if self.settingsPanel or not Settings or not ns.Settings or not ns.Settings.category then
        return
    end

    local panel = CreateFrame("Frame")
    panel.name = "Quest Manager"
    self.settingsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Quest Manager")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 16, -50)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText("View accepted quests by expansion, select old quests, and safely abandon selected quests after confirmation.")

    local openButton = CreateButton(panel, "Open Quest Manager", 180)
    openButton:SetPoint("TOPLEFT", 16, -92)
    openButton:SetScript("OnClick", function()
        self:Open()
    end)

    if Settings.RegisterCanvasLayoutSubcategory then
        local category = Settings.RegisterCanvasLayoutSubcategory(ns.Settings.category, panel, "Quest Manager")
        category.ID = "BenTools_QuestManager"
        self.category = category
    end
end

function QM:Initialize()
    self.selected = self.selected or {}
    self.searchText = ""
    self.filter = FILTER_ALL
    ResolveExpansionIDs()
    self:GetConfig()
    self:CreateSettingsPanel()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("QUEST_REMOVED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        self:ScheduleRefresh()
    end)
    self.eventFrame = eventFrame
end
