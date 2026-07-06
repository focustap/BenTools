local addonName, ns = ...

ns.MainWindow = {}

local BUTTON_WIDTH = 190
local BUTTON_HEIGHT = 24

local function AddSectionTitle(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function AddStatusLine(parent, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(230)
    label:SetJustifyH("LEFT")
    return label
end

local function AddActionButton(parent, text, x, y, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function ClampFrameToScreen(frame)
    if not frame or not frame:IsShown() then
        return
    end

    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then
        return
    end

    local parent = UIParent
    local parentLeft, parentRight = parent:GetLeft() or 0, parent:GetRight() or 0
    local parentTop, parentBottom = parent:GetTop() or 0, parent:GetBottom() or 0

    if right < parentLeft + 40 or left > parentRight - 40 or top < parentBottom + 40 or bottom > parentTop - 40 then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        ns.MainWindow:SavePosition()
    end
end

function ns.MainWindow:SavePosition()
    if not self.frame or not ns.db or not ns.db.ui or not ns.db.ui.mainWindow then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    ns.db.ui.mainWindow.point = point or "CENTER"
    ns.db.ui.mainWindow.relativePoint = relativePoint or "CENTER"
    ns.db.ui.mainWindow.x = x or 0
    ns.db.ui.mainWindow.y = y or 80
end

function ns.MainWindow:RestorePosition()
    if not self.frame then
        return
    end

    local saved = ns.db and ns.db.ui and ns.db.ui.mainWindow
    self.frame:ClearAllPoints()
    if saved then
        self.frame:SetPoint(saved.point or "CENTER", UIParent, saved.relativePoint or "CENTER", saved.x or 0, saved.y or 80)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
    ClampFrameToScreen(self.frame)
end

function ns.MainWindow:Refresh()
    if not self.frame then
        return
    end

    local queueEnabled = ns.db and ns.db.queueRinger and ns.db.queueRinger.enabled
    local queueDebug = ns.db and ns.db.queueRinger and ns.db.queueRinger.debug
    local premadeEnabled = ns.db and ns.db.queueRinger and ns.db.queueRinger.notifyPremade
    local readyCheckEnabled = ns.db and ns.db.queueRinger and ns.db.queueRinger.notifyReadyCheck
    local addonEnabled = ns.db and ns.db.profile and ns.db.profile.enabled
    local repairEnabled = ns.db and ns.db.profile and ns.db.profile.repairReminderEnabled
    local repairThreshold = ns.db and ns.db.profile and ns.db.profile.repairReminderThreshold or 50
    local version = "unknown"
    local mplusEnabled = ns.db and ns.db.mythicPlusFinder and ns.db.mythicPlusFinder.enabled
    local mplusStats = ns.db and ns.db.mythicPlusFinder and ns.db.mythicPlusFinder.stats or {}
    local mplusUI = ns.db and ns.db.mythicPlusFinder and ns.db.mythicPlusFinder.ui or {}
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(addonName, "Version") or version
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata(addonName, "Version") or version
    end

    self.autoSellStatus:SetText("Auto Sell: " .. (addonEnabled and "Enabled" or "Disabled"))
    self.repairStatus:SetText("Repair Reminder: " .. (repairEnabled and ("On at " .. tostring(repairThreshold) .. "%") or "Disabled"))
    self.queueStatus:SetText("Queue Ringer: " .. (queueEnabled and "Enabled" or "Disabled"))
    self.premadeStatus:SetText("Premade Invites: " .. (premadeEnabled and "Enabled" or "Disabled"))
    self.debugStatus:SetText("Ready Checks: " .. (readyCheckEnabled and "Enabled" or "Disabled"))
    self.queueDebugStatus:SetText("Queue Debug: " .. (queueDebug and "On" or "Off"))
    self.mplusStatus:SetText("Mythic+ Finder: " .. (mplusEnabled and "Enabled" or "Disabled"))
    self.mplusSearchStatus:SetText(string.format("Results: %d shown / %d raw", mplusStats.lastFilteredCount or 0, mplusStats.lastRawResultCount or 0))
    if mplusUI.lastSearchAt and mplusUI.lastSearchAt > 0 then
        self.mplusLastSearch:SetText("Last search: " .. tostring(time() - mplusUI.lastSearchAt) .. "s ago")
    else
        self.mplusLastSearch:SetText("Last search: never")
    end
    self.versionStatus:SetText("Version: " .. tostring(version or "unknown"))

    if self.queueToggleButton then
        self.queueToggleButton:SetText(queueEnabled and "Disable Queue Ringer" or "Enable Queue Ringer")
    end
end

function ns.MainWindow:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "BenToolsMainWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(520, 590)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.MainWindow:SavePosition()
        ClampFrameToScreen(self)
    end)
    frame:SetScript("OnShow", function()
        ns.MainWindow:Refresh()
        ClampFrameToScreen(frame)
    end)
    table.insert(UISpecialFrames, frame:GetName())

    frame.TitleText:SetText("BenTools")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 18, -34)
    subtitle:SetText("Button-based command center for Auto Sell and Queue Ringer.")

    AddSectionTitle(frame, "Auto Sell", 18, -62)
    self.autoSellStatus = AddStatusLine(frame, 18, -84)
    self.repairStatus = AddStatusLine(frame, 18, -102)

    AddActionButton(frame, "Scan Bags", 18, -126, function()
        if ns.Core then
            ns.Core:RunAutoSellScan()
        end
    end)
    AddActionButton(frame, "Print Sell Preview", 18, -156, function()
        if ns.Core then
            ns.Core:RunSellPreview()
        end
    end)
    AddActionButton(frame, "Always Sell List", 18, -186, function()
        if ns.Core then
            ns.Core:ShowAlwaysSellList()
        end
    end)
    AddActionButton(frame, "Never Sell List", 18, -216, function()
        if ns.Core then
            ns.Core:ShowNeverSellList()
        end
    end)
    AddActionButton(frame, "Auto Sell Settings", 18, -246, function()
        if ns.Core then
            ns.Core:OpenSettings()
        end
    end)
    AddActionButton(frame, "Repair Reminder Settings", 18, -276, function()
        if ns.Core then
            ns.Core:OpenSettings()
        end
    end)

    AddSectionTitle(frame, "Queue Ringer", 272, -62)
    self.queueStatus = AddStatusLine(frame, 272, -84)
    self.premadeStatus = AddStatusLine(frame, 272, -102)
    self.debugStatus = AddStatusLine(frame, 272, -120)
    self.queueDebugStatus = AddStatusLine(frame, 272, -138)

    AddActionButton(frame, "Queue Status", 272, -162, function()
        if ns.Core then
            ns.Core:ShowQueueStatus()
        end
    end)
    AddActionButton(frame, "Test Queue Notification", 272, -192, function()
        if ns.Core then
            ns.Core:TestQueueNotification()
        end
    end)
    self.queueToggleButton = AddActionButton(frame, "Disable Queue Ringer", 272, -222, function()
        if ns.Core then
            ns.Core:ToggleQueueEnabled()
        end
    end)
    AddActionButton(frame, "Toggle Queue Debug", 272, -252, function()
        if ns.Core then
            ns.Core:ToggleQueueDebug()
        end
    end)
    AddActionButton(frame, "Queue Ringer Settings", 272, -282, function()
        if ns.Core then
            ns.Core:OpenSettings()
        end
    end)

    AddSectionTitle(frame, "Mythic+ Finder", 272, -326)
    self.mplusStatus = AddStatusLine(frame, 272, -348)
    self.mplusSearchStatus = AddStatusLine(frame, 272, -366)
    self.mplusLastSearch = AddStatusLine(frame, 272, -384)
    AddActionButton(frame, "Open Finder", 272, -408, function()
        if ns.Core then
            ns.Core:OpenMythicPlusFinder()
        end
    end)
    AddActionButton(frame, "Refresh Finder Search", 272, -438, function()
        if ns.MythicPlusFinder then
            ns.MythicPlusFinder:Search()
        end
    end)

    AddSectionTitle(frame, "General", 18, -326)
    self.versionStatus = AddStatusLine(frame, 18, -348)
    AddActionButton(frame, "Open BenTools Settings", 18, -372, function()
        if ns.Core then
            ns.Core:OpenSettings()
        end
    end)
    AddActionButton(frame, "Reload UI", 18, -402, function()
        if ReloadUI then
            ReloadUI()
        end
    end)
    AddActionButton(frame, "Show Version / Status", 18, -432, function()
        if ns.Core then
            ns.Core:ShowVersionStatus()
        end
    end)

    self.frame = frame
    self:RestorePosition()
    frame:Hide()
    return frame
end

function ns.MainWindow:Open()
    local frame = self:Create()
    self:RestorePosition()
    frame:Show()
    self:Refresh()
end

function ns.MainWindow:Close()
    if self.frame then
        self.frame:Hide()
    end
end

function ns.MainWindow:Toggle()
    local frame = self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Open()
    end
end
