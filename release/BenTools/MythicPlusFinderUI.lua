local addonName, ns = ...

ns.MythicPlusFinderUI = {}
ns.MythicPlusFinder.UI = ns.MythicPlusFinderUI

local ui = ns.MythicPlusFinderUI
local finder = ns.MythicPlusFinder
local filtersAPI = ns.MythicPlusFinderFilters
local applicationsAPI = ns.MythicPlusFinderApplications

local MAX_VISIBLE_RESULTS = 5
local MAX_VISIBLE_DUNGEONS = 6
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local COMPOSITION_STATES = { "ANY", "PREFERRED", "REQUIRED" }

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

local function CreatePanel(parent, width, height, x, y)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", x, y)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.06, 0.10, 0.92)
    frame.bg = bg

    local border = frame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT")
    border:SetPoint("BOTTOMRIGHT")
    border:SetColorTexture(0, 0, 0, 0)
    frame.border = border

    local top = frame:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", 0, 0)
    top:SetHeight(1)
    top:SetColorTexture(0.23, 0.29, 0.40, 1)
    local bottom = frame:CreateTexture(nil, "ARTWORK")
    bottom:SetPoint("BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    bottom:SetColorTexture(0.23, 0.29, 0.40, 1)
    local left = frame:CreateTexture(nil, "ARTWORK")
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    left:SetColorTexture(0.23, 0.29, 0.40, 1)
    local right = frame:CreateTexture(nil, "ARTWORK")
    right:SetPoint("TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
    right:SetColorTexture(0.23, 0.29, 0.40, 1)

    return frame
end

local function CreateSectionTitle(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", x, y)
    label:SetTextColor(1.00, 0.93, 0.48)
    label:SetText(text)
    return label
end

local function CreateLabel(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function CreateButton(parent, text, width, height, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateEditBox(parent, width, height, x, y, numeric)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, height)
    box:SetPoint("TOPLEFT", x, y)
    box:SetAutoFocus(false)
    if numeric then
        box:SetNumeric(true)
    end
    return box
end

local function BindNumericCommit(box)
    box:SetScript("OnEnterPressed", function(self)
        ui:CommitNumericFilters()
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function()
        ui:CommitNumericFilters()
    end)
end

local function CreateCheck(parent, text, x, y, onClick)
    local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("LEFT", button, "RIGHT", 4, 0)
    button.text:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function ui:SaveFrameState()
    local state = finder:GetUIState()
    local width = Clamp(self.frame:GetWidth(), 980, 1440)
    local height = Clamp(self.frame:GetHeight(), 820, 980)
    self.frame:SetSize(width, height)
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    state.point = point or "CENTER"
    state.relativePoint = relativePoint or "CENTER"
    state.x = x or 0
    state.y = y or 40
    state.width = width
    state.height = height
end

function ui:RestoreFrameState()
    local state = finder:GetUIState()
    self.frame:SetSize(Clamp(state.width or 1120, 980, 1440), Clamp(state.height or 820, 820, 980))
    self.frame:ClearAllPoints()
    self.frame:SetPoint(state.point or "CENTER", UIParent, state.relativePoint or "CENTER", state.x or 0, state.y or 40)
    self.frame:SetClampedToScreen(true)
end

function ui:SetSearchState(state)
    self.searchState = state
end

function ui:RefreshPresetList()
    return
end

function ui:SyncControlsFromFilters()
    local filters = finder:GetFilters()
    self.allowedMinBox:SetText(tostring(filters.allowedMin or ""))
    self.allowedMaxBox:SetText(tostring(filters.allowedMax or ""))
    self.preferredMinBox:SetText(tostring(filters.preferredMin or ""))
    self.preferredMaxBox:SetText(tostring(filters.preferredMax or ""))
    self.scoreMinBox:SetText(tostring(filters.leaderScoreMin or 0))
    self.desiredAppsBox:SetText(tostring(filters.desiredActiveApplications or 5))
    for role, button in pairs(self.roleButtons) do
        button:SetChecked(role == (filters.selectedRole or "HEALER"))
    end
    self.ageButton:SetText((filters.ageMaxMinutes or 0) == 0 and "Any age" or ("Max " .. tostring(filters.ageMaxMinutes) .. "m"))
    self.groupSizeButton:SetText((filters.minGroupSize or 0) == 0 and "Any size" or ("At least " .. tostring(filters.minGroupSize)))
    self.preferFreshCheck:SetChecked(filters.preferFresh)
    self.preferFullCheck:SetChecked(filters.preferFullGroups)
    self.preferLeaderCheck:SetChecked(filters.preferStrongerLeader)
    self.hideDelistedCheck:SetChecked(filters.hideDelisted)
    self.presetNameBox:SetText(finder:GetUIState().selectedPresetName or "")
    self:RefreshCompositionButtons()
    self:RefreshDungeonList()
end

function ui:CommitNumericFilters()
    local filters = finder:GetFilters()
    filters.allowedMin = tonumber(self.allowedMinBox:GetText()) or filters.allowedMin
    filters.allowedMax = tonumber(self.allowedMaxBox:GetText()) or filters.allowedMax
    filters.preferredMin = tonumber(self.preferredMinBox:GetText()) or filters.preferredMin
    filters.preferredMax = tonumber(self.preferredMaxBox:GetText()) or filters.preferredMax
    filters.leaderScoreMin = tonumber(self.scoreMinBox:GetText()) or filters.leaderScoreMin
    filters.desiredActiveApplications = tonumber(self.desiredAppsBox:GetText()) or filters.desiredActiveApplications
    filtersAPI:ValidateFilters(filters)
    self:SyncControlsFromFilters()
    finder:RebuildRecommendations()
end

function ui:CycleGroupSize()
    local filters = finder:GetFilters()
    local nextValue = ((filters.minGroupSize or 0) + 1) % 5
    filters.minGroupSize = nextValue
    self.groupSizeButton:SetText(nextValue == 0 and "Any size" or ("At least " .. tostring(nextValue)))
    finder:RebuildRecommendations()
end

function ui:CycleAgeLimit()
    local filters = finder:GetFilters()
    local current = filters.ageMaxMinutes or 0
    local nextMap = {
        [0] = 5,
        [5] = 10,
        [10] = 15,
        [15] = 0,
    }
    filters.ageMaxMinutes = nextMap[current] or 0
    self.ageButton:SetText(filters.ageMaxMinutes == 0 and "Any age" or ("Max " .. tostring(filters.ageMaxMinutes) .. "m"))
    finder:RebuildRecommendations()
end

function ui:RefreshCompositionButtons()
    local filters = finder:GetFilters()
    for _, role in ipairs(ROLE_ORDER) do
        local button = self.compositionButtons[role]
        if role == filters.selectedRole then
            button:SetText("Open Slot")
            button:Disable()
        else
            button:Enable()
            local state = filtersAPI:GetRoleState(filters, role)
            if state == "REQUIRED" then
                button:SetText("Required")
            elseif state == "PREFERRED" then
                button:SetText("Preferred")
            else
                button:SetText("Any")
            end
        end
    end
end

function ui:CycleComposition(role)
    local filters = finder:GetFilters()
    if role == filters.selectedRole then
        return
    end
    local current = filtersAPI:GetRoleState(filters, role)
    local nextState = "ANY"
    for index, value in ipairs(COMPOSITION_STATES) do
        if value == current then
            nextState = COMPOSITION_STATES[(index % #COMPOSITION_STATES) + 1]
            break
        end
    end
    filtersAPI:SetRoleState(filters, role, nextState)
    self:RefreshCompositionButtons()
    finder:RebuildRecommendations()
end

function ui:RefreshDungeonList()
    local names = finder.dungeonPool or filtersAPI.cachedDungeonNames or {}
    FauxScrollFrame_Update(self.dungeonScroll, #names, MAX_VISIBLE_DUNGEONS, 18)
    local offset = FauxScrollFrame_GetOffset(self.dungeonScroll) or 0
    for index, row in ipairs(self.dungeonRows) do
        local dungeonName = names[index + offset]
        if dungeonName then
            row.dungeonName = dungeonName
            row.text:SetText(dungeonName)
            row:SetChecked(filtersAPI:IsDungeonSelected(finder:GetFilters(), dungeonName))
            row:Show()
        else
            row.dungeonName = nil
            row:Hide()
        end
    end
end

function ui:RefreshResults()
    local results = finder.recommendedResults or {}
    local config = finder:GetConfig()
    local rawCount = #(finder.rawResults or {})
    FauxScrollFrame_Update(self.resultsScroll, #results, MAX_VISIBLE_RESULTS, 112)
    local offset = FauxScrollFrame_GetOffset(self.resultsScroll) or 0

    for index, card in ipairs(self.resultCards) do
        local result = results[index + offset]
        if result then
            card.resultID = result.resultID
            card.keyBadge:SetText(result.keyLevel and ("+" .. tostring(result.keyLevel)) or "?")
            card.title:SetText(result.dungeonName or "Unknown Dungeon")
            card.subtitle:SetText(string.format("Leader: %s   Score: %d   Members: %d/5   Age: %s", result.leaderName or UNKNOWN, result.leaderScore or 0, result.numMembers or 0, finder:FormatAge(result.ageSeconds or 0)))
            card.scoreBadge:SetText(tostring(result.matchScore or 0))
            card.scoreFrame:SetShown(config.showMatchScore ~= false)
            card.status:SetText(result.applicationLocked and "Applied" or "Ready")
            card.applyButton:SetEnabled(not result.applicationLocked)
            for _, role in ipairs(ROLE_ORDER) do
                local widget = card.roles[role]
                widget.text:SetText(string.format("%s %d/%d", filtersAPI:GetRoleLabel(role), result.roleCounts[role] or 0, finder.GROUP_CAPS[role] or 0))
                if (result.openSlots[role] or 0) > 0 then
                    widget.text:SetTextColor(0.58, 0.95, 0.72)
                else
                    widget.text:SetTextColor(0.78, 0.78, 0.82)
                end
            end
            card:Show()
        else
            card.resultID = nil
            card:Hide()
        end
    end

    if #results == 0 then
        local stateText = {
            searching = "Searching Mythic+ listings...",
            blocked = "Search blocked. Open Premade Groups > Dungeons first.",
            error = "Search failed. Check the Group Finder state and try again.",
            cooldown = "Search cooling down for a second.",
        }
        if rawCount > 0 then
            self.emptyText:SetText("No groups matched your current filters.\n\nTry widening the key range, lowering composition requirements, or allowing smaller/older groups.")
        else
            self.emptyText:SetText(stateText[self.searchState] or "Set your filters, then press Refresh Search.")
        end
        self.emptyText:Show()
    else
        self.emptyText:Hide()
    end
end

function ui:RefreshSelectedResult()
    local selectedID = finder:GetUIState().selectedResultID
    local result = selectedID and finder:GetResultByID(selectedID) or nil
    if not result then
        result = (finder.recommendedResults or {})[1]
        finder:GetUIState().selectedResultID = result and result.resultID or nil
    end
    if not result then
        self.detailTitle:SetText("No selection")
        self.detailBody:SetText("Run a search, then select a result card to inspect the fit score and apply plan.")
        self.applyNextButton:Disable()
        return
    end

    self.detailTitle:SetText(string.format("%s %s", finder:FormatKeyLabel(result.keyLevel), result.dungeonName or "Unknown"))
    local lines = {
        string.format("Leader: %s", result.leaderName or UNKNOWN),
        string.format("Leader score: %d", result.leaderScore or 0),
        string.format("Members: %d/5", result.numMembers or 0),
        string.format("Age: %s", finder:FormatAge(result.ageSeconds or 0)),
        "Why it scores well:",
    }
    for _, reason in ipairs(result.matchReasons or {}) do
        table.insert(lines, string.format("+%d %s", reason.points or 0, reason.text or ""))
    end
    self.detailBody:SetText(table.concat(lines, "\n"))
    self.applyNextButton:SetEnabled(applicationsAPI:GetNextEligiblePlanEntry() ~= nil)
end

function ui:RefreshPlan()
    local lines = {}
    local count = 0
    for _, result in ipairs(finder.recommendedResults or {}) do
        if not result.applicationLocked then
            count = count + 1
            lines[#lines + 1] = string.format("%d. %s %s  [Score %d]", count, finder:FormatKeyLabel(result.keyLevel), result.dungeonName or "Unknown", result.matchScore or 0)
            if count >= 5 then
                break
            end
        end
    end
    self.planBody:SetText(#lines > 0 and table.concat(lines, "\n") or "No eligible application plan in the current results.")
end

function ui:RefreshApplications()
    local lines = {}
    for index, state in ipairs(finder.activeApplications or {}) do
        lines[#lines + 1] = string.format("%d. %s  [%s]", index, state.groupName or "Unknown Group", applicationsAPI:GetStatusText(state))
        if index >= 5 then
            break
        end
    end
    self.appsBody:SetText(#lines > 0 and table.concat(lines, "\n") or "No active Mythic+ applications.")
end

function ui:RefreshStatus()
    self.statusText:SetText(finder:GetStatusText())
end

function ui:Refresh()
    if not self.frame then
        return
    end
    self:SyncControlsFromFilters()
    self:RefreshPresetList()
    self:RefreshResults()
    self:RefreshSelectedResult()
    self:RefreshPlan()
    self:RefreshApplications()
    self:RefreshStatus()
end

function ui:Open()
    if not self.frame then
        self:Initialize()
    end
    if not self.frame then
        ns.Utils:Print("[M+] Finder frame could not be created.")
        return
    end
    self:RestoreFrameState()
    if not self.frame:GetPoint(1) then
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
    self.frame:Show()
    if self.frame.Raise then
        self.frame:Raise()
    end
    self:Refresh()
end

function ui:CreateResultCards()
    self.resultCards = {}
    for index = 1, MAX_VISIBLE_RESULTS do
        local card = CreatePanel(self.resultsPanel, 510, 104, 14, -34 - ((index - 1) * 112))
        card:SetScript("OnMouseDown", function()
            finder:GetUIState().selectedResultID = card.resultID
            ui:RefreshSelectedResult()
        end)

        local keyBadgeBg = card:CreateTexture(nil, "ARTWORK")
        keyBadgeBg:SetPoint("TOPLEFT", 12, -12)
        keyBadgeBg:SetSize(52, 32)
        keyBadgeBg:SetColorTexture(0.08, 0.45, 0.70, 0.95)

        local keyBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        keyBadge:SetPoint("CENTER", keyBadgeBg)
        keyBadge:SetTextColor(1, 1, 1)
        card.keyBadge = keyBadge

        local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 78, -12)
        title:SetWidth(290)
        title:SetJustifyH("LEFT")
        card.title = title

        local subtitle = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOPLEFT", 78, -36)
        subtitle:SetWidth(310)
        subtitle:SetJustifyH("LEFT")
        card.subtitle = subtitle

        local roles = {}
        for roleIndex, role in ipairs(ROLE_ORDER) do
            local holder = CreateFrame("Frame", nil, card)
            holder:SetSize(130, 20)
            holder:SetPoint("TOPLEFT", 78, -60 - ((roleIndex - 1) * 14))
            local icon = holder:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT")
            icon:SetSize(14, 14)
            icon:SetAtlas(finder:GetRoleIconAtlas(role), true)
            local text = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            text:SetJustifyH("LEFT")
            holder.text = text
            roles[role] = holder
        end
        card.roles = roles

        local scoreFrame = CreateFrame("Frame", nil, card)
        scoreFrame:SetPoint("TOPRIGHT", -82, -12)
        scoreFrame:SetSize(54, 28)
        local scoreBg = scoreFrame:CreateTexture(nil, "ARTWORK")
        scoreBg:SetAllPoints()
        scoreBg:SetColorTexture(0.20, 0.23, 0.33, 1)
        scoreFrame.bg = scoreBg

        local scoreBadge = scoreFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        scoreBadge:SetPoint("CENTER", scoreFrame)
        card.scoreBadge = scoreBadge
        card.scoreFrame = scoreFrame

        scoreFrame:EnableMouse(true)
        scoreFrame:SetScript("OnEnter", function()
            if finder:GetConfig().showScoreExplanation == false then
                return
            end
            local result = finder:GetResultByID(card.resultID)
            if not result then
                return
            end
            GameTooltip:SetOwner(scoreFrame, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Match Score", 1, 0.93, 0.48)
            GameTooltip:AddLine(tostring(result.matchScore or 0), 0.9, 0.95, 1)
            for _, reason in ipairs(result.matchReasons or {}) do
                GameTooltip:AddLine(string.format("+%d %s", reason.points or 0, reason.text or ""), 0.82, 0.86, 0.98, true)
            end
            GameTooltip:Show()
        end)
        scoreFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        local status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPRIGHT", -20, -48)
        card.status = status

        local applyButton = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        applyButton:SetSize(90, 24)
        applyButton:SetPoint("BOTTOMRIGHT", -16, 12)
        applyButton:SetText("Apply")
        applyButton:SetScript("OnClick", function()
            if card.resultID then
                finder:ApplyToResult(card.resultID)
            end
        end)
        card.applyButton = applyButton

        self.resultCards[index] = card
    end
end

function ui:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "BenToolsMythicPlusFinderFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ui:SaveFrameState()
    end)
    frame:SetScript("OnSizeChanged", function()
        ui:SaveFrameState()
    end)
    frame:SetScript("OnShow", function()
        ui:Refresh()
    end)
    table.insert(UISpecialFrames, frame:GetName())

    frame.TitleText:SetText("BenTools Mythic+ Finder")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    local refreshButton = CreateButton(frame, "Refresh Search", 116, 24, 760, -32, function()
        ui:CommitNumericFilters()
        finder:Search()
    end)
    self.refreshButton = refreshButton

    CreateButton(frame, "Blizzard Finder", 110, 24, 884, -32, function()
        if not LFGListFrame then
            UIParentLoadAddOn("Blizzard_GroupFinder")
        end
        if LFGListFrame then
            if ToggleLFDParentFrame then
                ToggleLFDParentFrame()
            elseif PVEFrame_ToggleFrame then
                PVEFrame_ToggleFrame("GroupFinderFrame", nil)
            end
            if PVEFrame_ShowFrame then
                PVEFrame_ShowFrame("GroupFinderFrame")
            end
        end
    end)

    self.sidebar = CreatePanel(frame, 260, 726, 14, -60)
    self.resultsPanel = CreatePanel(frame, 540, 726, 286, -60)
    self.detailPanel = CreatePanel(frame, 264, 726, 838, -60)

    CreateSectionTitle(self.sidebar, "Filters", 14, -12)
    CreateSectionTitle(self.resultsPanel, "Best Matches", 14, -12)
    CreateSectionTitle(self.detailPanel, "Details", 14, -12)

    CreateLabel(self.sidebar, "Allowed key range", 16, -40)
    self.allowedMinBox = CreateEditBox(self.sidebar, 48, 22, 16, -58, true)
    self.allowedMaxBox = CreateEditBox(self.sidebar, 48, 22, 76, -58, true)
    self.preferredMinBox = CreateEditBox(self.sidebar, 48, 22, 148, -58, true)
    self.preferredMaxBox = CreateEditBox(self.sidebar, 48, 22, 208, -58, true)
    BindNumericCommit(self.allowedMinBox)
    BindNumericCommit(self.allowedMaxBox)
    BindNumericCommit(self.preferredMinBox)
    BindNumericCommit(self.preferredMaxBox)
    CreateLabel(self.sidebar, "Pref", 148, -42)

    CreateLabel(self.sidebar, "Apply as", 16, -94)
    self.roleButtons = {}
    for index, role in ipairs(ROLE_ORDER) do
        local roleButton = CreateFrame("CheckButton", nil, self.sidebar, "UICheckButtonTemplate")
        roleButton:SetPoint("TOPLEFT", 16 + ((index - 1) * 76), -112)
        roleButton.text = roleButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        roleButton.text:SetPoint("LEFT", roleButton, "RIGHT", 2, 0)
        roleButton.text:SetText(filtersAPI:GetRoleLabel(role))
        roleButton:SetScript("OnClick", function()
            finder:GetFilters().selectedRole = role
            filtersAPI:ValidateFilters(finder:GetFilters())
            for otherRole, button in pairs(ui.roleButtons) do
                button:SetChecked(otherRole == role)
            end
            ui:RefreshCompositionButtons()
            finder:RebuildRecommendations()
        end)
        self.roleButtons[role] = roleButton
    end

    CreateLabel(self.sidebar, "Composition", 16, -146)
    self.compositionButtons = {}
    for index, role in ipairs(ROLE_ORDER) do
        CreateLabel(self.sidebar, filtersAPI:GetRoleLabel(role), 16, -168 - ((index - 1) * 28))
        local button = CreateButton(self.sidebar, "Any", 120, 22, 112, -162 - ((index - 1) * 28), function()
            ui:CycleComposition(role)
        end)
        self.compositionButtons[role] = button
    end

    CreateLabel(self.sidebar, "Group size", 16, -252)
    self.groupSizeButton = CreateButton(self.sidebar, "Any size", 120, 22, 112, -246, function()
        ui:CycleGroupSize()
    end)

    CreateLabel(self.sidebar, "Leader score", 16, -282)
    self.scoreMinBox = CreateEditBox(self.sidebar, 72, 22, 112, -276, true)
    BindNumericCommit(self.scoreMinBox)

    CreateLabel(self.sidebar, "Listing age", 16, -312)
    self.ageButton = CreateButton(self.sidebar, "Any age", 120, 22, 112, -306, function()
        ui:CycleAgeLimit()
    end)

    CreateLabel(self.sidebar, "Desired apps", 16, -342)
    self.desiredAppsBox = CreateEditBox(self.sidebar, 48, 22, 112, -336, true)
    BindNumericCommit(self.desiredAppsBox)

    self.preferFreshCheck = CreateCheck(self.sidebar, "Prefer fresh", 16, -372, function(selfButton)
        finder:GetFilters().preferFresh = selfButton:GetChecked() and true or false
        finder:RebuildRecommendations()
    end)
    self.preferFullCheck = CreateCheck(self.sidebar, "Prefer fuller groups", 16, -396, function(selfButton)
        finder:GetFilters().preferFullGroups = selfButton:GetChecked() and true or false
        finder:RebuildRecommendations()
    end)
    self.preferLeaderCheck = CreateCheck(self.sidebar, "Prefer stronger leaders", 16, -420, function(selfButton)
        finder:GetFilters().preferStrongerLeader = selfButton:GetChecked() and true or false
        finder:RebuildRecommendations()
    end)
    self.hideDelistedCheck = CreateCheck(self.sidebar, "Hide delisted", 16, -444, function(selfButton)
        finder:GetFilters().hideDelisted = selfButton:GetChecked() and true or false
        finder:RebuildRecommendations()
    end)

    CreateSectionTitle(self.sidebar, "Dungeons", 14, -472)
    CreateButton(self.sidebar, "All", 44, 20, 16, -494, function()
        filtersAPI:SetAllDungeonsSelected(finder:GetFilters(), true)
        ui:RefreshDungeonList()
        finder:RebuildRecommendations()
    end)
    CreateButton(self.sidebar, "Clear", 54, 20, 66, -494, function()
        filtersAPI:SetAllDungeonsSelected(finder:GetFilters(), false)
        ui:RefreshDungeonList()
        finder:RebuildRecommendations()
    end)

    self.dungeonRows = {}
    for index = 1, MAX_VISIBLE_DUNGEONS do
        local row = CreateCheck(self.sidebar, "", 16, -520 - ((index - 1) * 18), function(selfButton)
            if selfButton.dungeonName then
                finder:GetFilters().selectedDungeons[selfButton.dungeonName] = selfButton:GetChecked() and true or nil
                finder:RebuildRecommendations()
            end
        end)
        self.dungeonRows[index] = row
    end
    self.dungeonScroll = CreateFrame("ScrollFrame", nil, self.sidebar, "FauxScrollFrameTemplate")
    self.dungeonScroll:SetPoint("TOPLEFT", 232, -520)
    self.dungeonScroll:SetSize(16, 146)
    self.dungeonScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, 18, function()
            ui:RefreshDungeonList()
        end)
    end)

    CreateSectionTitle(self.sidebar, "Presets", 14, -630)
    self.presetNameBox = CreateEditBox(self.sidebar, 136, 22, 16, -652, false)
    CreateButton(self.sidebar, "Save", 44, 22, 160, -652, function()
        local name = ui.presetNameBox:GetText()
        if finder:SaveCurrentPreset(name) then
            finder:GetUIState().selectedPresetName = name
        end
    end)
    CreateButton(self.sidebar, "Load", 44, 22, 208, -652, function()
        local name = ui.presetNameBox:GetText()
        if finder:LoadPreset(name) then
            ui:Refresh()
        end
    end)
    CreateButton(self.sidebar, "Delete", 60, 22, 16, -680, function()
        if finder:DeletePreset(ui.presetNameBox:GetText()) then
            ui.presetNameBox:SetText("")
        end
    end)
    CreateButton(self.sidebar, "Rename", 70, 22, 82, -680, function()
        local selected = finder:GetUIState().selectedPresetName or ""
        local newName = ui.presetNameBox:GetText()
        if finder:RenamePreset(selected, newName) then
            finder:GetUIState().selectedPresetName = newName
        end
    end)

    self:CreateResultCards()

    self.resultsScroll = CreateFrame("ScrollFrame", nil, self.resultsPanel, "FauxScrollFrameTemplate")
    self.resultsScroll:SetPoint("TOPLEFT", 522, -34)
    self.resultsScroll:SetSize(16, 620)
    self.resultsScroll:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, 112, function()
            ui:RefreshResults()
        end)
    end)

    self.emptyText = CreateLabel(self.resultsPanel, "", 18, -52)
    self.emptyText:SetWidth(490)
    self.emptyText:SetJustifyH("LEFT")

    self.detailTitle = CreateLabel(self.detailPanel, "No selection", 16, -42, "GameFontNormalLarge")
    self.detailTitle:SetWidth(220)
    self.detailTitle:SetJustifyH("LEFT")
    self.detailBody = CreateLabel(self.detailPanel, "", 16, -70)
    self.detailBody:SetWidth(228)
    self.detailBody:SetJustifyH("LEFT")

    self.applyNextButton = CreateButton(self.detailPanel, "Apply Next Best", 132, 24, 16, -240, function()
        applicationsAPI:ApplyNextBest()
    end)

    CreateSectionTitle(self.detailPanel, "Application Plan", 14, -278)
    self.planBody = CreateLabel(self.detailPanel, "", 16, -304)
    self.planBody:SetWidth(228)
    self.planBody:SetJustifyH("LEFT")
    if self.planBody.SetSpacing then
        self.planBody:SetSpacing(2)
    end

    CreateSectionTitle(self.detailPanel, "Active Applications", 14, -428)
    self.appsBody = CreateLabel(self.detailPanel, "", 16, -454)
    self.appsBody:SetWidth(228)
    self.appsBody:SetJustifyH("LEFT")
    if self.appsBody.SetSpacing then
        self.appsBody:SetSpacing(2)
    end

    self.statusText = CreateLabel(frame, "", 18, -794)
    self.statusText:SetWidth(1070)
    self.statusText:SetTextColor(0.73, 0.79, 0.91)

    local resize = CreateFrame("Button", nil, frame)
    resize:SetPoint("BOTTOMRIGHT")
    resize:SetSize(16, 16)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        ui:SaveFrameState()
    end)

    self.frame = frame
    self:RestoreFrameState()
    self:SetSearchState("idle")

    frame:SetScript("OnUpdate", function(_, elapsed)
        ui.ageTicker = (ui.ageTicker or 0) + elapsed
        if ui.ageTicker >= 1 then
            ui.ageTicker = 0
            if ui.frame:IsShown() then
                ui:RefreshResults()
                ui:RefreshSelectedResult()
                ui:RefreshStatus()
            end
        end
    end)

    frame:Hide()
end
