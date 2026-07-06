local addonName, ns = ...

ns.Settings = {}

local y
local alwaysLines = {}
local neverLines = {}

local function AddLabel(parent, text, x, offsetY)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, offsetY)
    label:SetText(text)
    return label
end

local function AddCheckbox(parent, text, key, x)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x or 16, y)
    checkbox.Text:SetText(text)
    checkbox:SetChecked(ns.db.profile[key])
    checkbox:SetScript("OnClick", function(self)
        ns.db.profile[key] = self:GetChecked() and true or false
        if ns.Merchant and ns.Utils:IsMerchantOpen() then
            ns.Merchant:Refresh()
        end
    end)
    y = y - 30
    return checkbox
end

local function AddTableCheckbox(parent, text, store, key, x, onChange)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", x or 16, y)
    checkbox.Text:SetText(text)
    checkbox:SetChecked(store[key])
    checkbox:SetScript("OnClick", function(self)
        store[key] = self:GetChecked() and true or false
        if onChange then
            onChange(self)
        end
    end)
    y = y - 30
    return checkbox
end

local function AddButton(parent, text, width, x, offsetY, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 140, 22)
    button:SetPoint("TOPLEFT", x or 16, offsetY)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function AddEditBox(parent, label, key, x)
    AddLabel(parent, label, x or 16, y - 5)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(90, 24)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetPoint("TOPLEFT", (x or 16) + 230, y)
    box:SetText(tostring(ns.db.profile[key] or 0))
    box:SetCursorPosition(0)
    box:SetScript("OnEnterPressed", function(self)
        ns.db.profile[key] = tonumber(self:GetText()) or ns.db.profile[key]
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        ns.db.profile[key] = tonumber(self:GetText()) or ns.db.profile[key]
        self:SetText(tostring(ns.db.profile[key]))
    end)
    y = y - 30
    return box
end

local function AddGoldEditBox(parent, label, key, x)
    AddLabel(parent, label, x or 16, y - 5)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(90, 24)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetPoint("TOPLEFT", (x or 16) + 230, y)
    box:SetText(tostring(math.floor((ns.db.profile[key] or 0) / 10000)))
    box:SetCursorPosition(0)
    box:SetScript("OnEnterPressed", function(self)
        ns.db.profile[key] = (tonumber(self:GetText()) or 0) * 10000
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        ns.db.profile[key] = (tonumber(self:GetText()) or 0) * 10000
        self:SetText(tostring(math.floor((ns.db.profile[key] or 0) / 10000)))
    end)
    y = y - 30
    return box
end

local function AddQualityDropdown(parent, label, key, x)
    AddLabel(parent, label, x or 16, y - 5)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", (x or 16) + 200, y + 5)

    local function SetValue(value)
        ns.db.profile[key] = value
        UIDropDownMenu_SetText(dropdown, _G["ITEM_QUALITY" .. value .. "_DESC"] or tostring(value))
    end

    UIDropDownMenu_Initialize(dropdown, function()
        for quality = 0, 5 do
            local info = UIDropDownMenu_CreateInfo()
            info.text = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
            info.value = quality
            info.func = function()
                SetValue(quality)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(dropdown, 130)
    SetValue(ns.db.profile[key])
    y = y - 34
    return dropdown
end

local function AddRoleDropdown(parent, label, store, key, x)
    AddLabel(parent, label, x or 16, y - 5)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", (x or 16) + 200, y + 5)

    local function SetValue(value)
        store[key] = value
        local labels = {
            TANK = "Tank",
            HEALER = "Healer",
            DAMAGER = "DPS",
        }
        UIDropDownMenu_SetText(dropdown, labels[value] or tostring(value))
    end

    UIDropDownMenu_Initialize(dropdown, function()
        for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = ({ TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" })[role]
            info.func = function()
                SetValue(role)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(dropdown, 120)
    SetValue(store[key])
    y = y - 34
    return dropdown
end

local function ClearLines(lines)
    for _, line in ipairs(lines) do
        line:Hide()
    end
    wipe(lines)
end

local function AddRuleLine(parent, lines, itemID, listName, x, offsetY)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(470, 22)
    row:SetPoint("TOPLEFT", x, offsetY)

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT")
    text:SetWidth(350)
    text:SetJustifyH("LEFT")
    text:SetText(ns.DB:GetItemName(itemID) .. " (" .. itemID .. ")")

    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(70, 20)
    remove:SetPoint("RIGHT")
    remove:SetText("Remove")
    remove:SetScript("OnClick", function()
        if listName == "always" then
            ns.DB:SetAlwaysSell(itemID, nil, false)
        else
            ns.DB:SetNeverSell(itemID, nil, false)
        end
        ns.Settings:RefreshLists()
    end)

    table.insert(lines, row)
end

function ns.Settings:RefreshLists()
    if not self.panel or not self.content then
        return
    end

    ClearLines(alwaysLines)
    ClearLines(neverLines)

    local offset = self.alwaysStartY
    for itemID in pairs(ns.db.alwaysSell) do
        AddRuleLine(self.content, alwaysLines, itemID, "always", 395, offset)
        offset = offset - 24
    end

    offset = self.neverStartY
    for itemID in pairs(ns.db.neverSell) do
        AddRuleLine(self.content, neverLines, itemID, "never", 395, offset)
        offset = offset - 24
    end
end

function ns.Settings:Initialize()
    local panel = CreateFrame("Frame")
    panel.name = "BenTools"
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end
    panel:SetClipsChildren(true)
    self.panel = panel

    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)
    self.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(760, 1460)
    scrollFrame:SetScrollChild(content)
    self.content = content

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BenTools")

    y = -50
    AddCheckbox(content, "Enable addon", "enabled")
    AddCheckbox(content, "Debug output", "debug")
    AddCheckbox(content, "Automatically sell gray items", "sellGray")
    AddCheckbox(content, "Repair reminder popup", "repairReminderEnabled")
    AddEditBox(content, "Repair reminder threshold (%)", "repairReminderThreshold")
    AddCheckbox(content, "Enable equipment item-level rule", "equipmentRuleEnabled")
    AddEditBox(content, "Item-level threshold", "itemLevelThreshold")
    AddQualityDropdown(content, "Minimum quality", "minQuality")
    AddQualityDropdown(content, "Maximum quality", "maxQuality")
    AddCheckbox(content, "Soulbound-only equipment rule", "soulboundOnly")
    AddCheckbox(content, "BoE-only equipment rule", "boeOnly")
    AddCheckbox(content, "Exclude crafting materials", "excludeCrafting")
    AddCheckbox(content, "Exclude equipment-set items", "excludeEquipmentSets")
    AddCheckbox(content, "Confirmation before large sales", "confirmLargeSales")
    AddGoldEditBox(content, "Gold-value confirmation threshold", "confirmGoldThreshold")

    AddLabel(content, "Queue Ringer", 16, y - 4)
    y = y - 28
    AddTableCheckbox(content, "Enable Queue Ringer", ns.db.queueRinger, "enabled")
    AddTableCheckbox(content, "Notify for Dungeon Finder / Raid Finder", ns.db.queueRinger, "notifyLFG")
    AddTableCheckbox(content, "Notify for Battlegrounds / Rated PvP", ns.db.queueRinger, "notifyPvP")
    AddTableCheckbox(content, "Notify for Premade Group invites", ns.db.queueRinger, "notifyPremade")
    AddTableCheckbox(content, "Notify for Ready Checks", ns.db.queueRinger, "notifyReadyCheck")
    AddTableCheckbox(content, "Show Queue Ringer popup banner", ns.db.queueRinger, "showPopup")
    AddTableCheckbox(content, "Queue Ringer debug output", ns.db.queueRinger, "debug")
    AddLabel(content, "Popup duration (seconds)", 16, y - 5)
    local popupDurationBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    popupDurationBox:SetSize(90, 24)
    popupDurationBox:SetAutoFocus(false)
    popupDurationBox:SetNumeric(true)
    popupDurationBox:SetPoint("TOPLEFT", 246, y)
    popupDurationBox:SetText(tostring(ns.db.queueRinger.popupDuration or 20))
    popupDurationBox:SetCursorPosition(0)
    popupDurationBox:SetScript("OnEnterPressed", function(self)
        ns.db.queueRinger.popupDuration = math.max(5, tonumber(self:GetText()) or ns.db.queueRinger.popupDuration or 20)
        self:SetText(tostring(ns.db.queueRinger.popupDuration))
        self:ClearFocus()
    end)
    popupDurationBox:SetScript("OnEditFocusLost", function(self)
        ns.db.queueRinger.popupDuration = math.max(5, tonumber(self:GetText()) or ns.db.queueRinger.popupDuration or 20)
        self:SetText(tostring(ns.db.queueRinger.popupDuration))
    end)
    y = y - 30
    AddButton(content, "Send Local Test Event", 160, 16, y, function()
        if ns.QueueRinger then
            ns.QueueRinger:CreateTestEvent()
        end
    end)
    y = y - 34

    AddLabel(content, "Mythic+ Finder", 16, y - 4)
    y = y - 28
    AddTableCheckbox(content, "Enable Mythic+ Finder", ns.db.mythicPlusFinder, "enabled")
    AddTableCheckbox(content, "Show match score on cards", ns.db.mythicPlusFinder, "showMatchScore")
    AddTableCheckbox(content, "Show score explanation tooltips", ns.db.mythicPlusFinder, "showScoreExplanation")
    AddTableCheckbox(content, "Use compact result cards", ns.db.mythicPlusFinder, "compactCards")
    AddTableCheckbox(content, "Mythic+ Finder debug output", ns.db.mythicPlusFinder, "debug")
    AddRoleDropdown(content, "Default role", ns.db.mythicPlusFinder, "defaultRole")
    AddButton(content, "Open Mythic+ Finder", 160, 16, y, function()
        if ns.MythicPlusFinder and ns.MythicPlusFinder.UI then
            ns.MythicPlusFinder.UI:Open()
        end
    end)
    y = y - 34

    AddLabel(content, "Always Sell Items", 395, -50)
    AddLabel(content, "Never Sell Items", 395, -300)
    self.alwaysStartY = -75
    self.neverStartY = -325

    local note = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 20)
    note:SetWidth(700)
    note:SetJustifyH("LEFT")
    note:SetText("Bag marking: Alt-right-click toggles Always Sell. Ctrl-Alt-right-click toggles Never Sell. Queue Ringer shows a bright top-right banner that the desktop companion watches for phone alerts. Mythic+ Finder keeps its active filters in the Finder window and only uses settings for module-wide defaults. Repair reminders can use a higher threshold than the default Blizzard warning. Never Sell overrides every rule.")

    local category, layout = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
    Settings.RegisterAddOnCategory(category)
    self.category = category
    self.categoryID = category.GetID and category:GetID() or nil
    self.layout = layout

    self:RefreshLists()
end
