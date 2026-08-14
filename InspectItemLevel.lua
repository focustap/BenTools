local addonName, ns = ...

ns.InspectItemLevel = {}

local INVENTORY_SLOTS = {
    INVSLOT_HEAD,
    INVSLOT_NECK,
    INVSLOT_SHOULDER,
    INVSLOT_CHEST,
    INVSLOT_WAIST,
    INVSLOT_LEGS,
    INVSLOT_FEET,
    INVSLOT_WRIST,
    INVSLOT_HAND,
    INVSLOT_FINGER1,
    INVSLOT_FINGER2,
    INVSLOT_TRINKET1,
    INVSLOT_TRINKET2,
    INVSLOT_BACK,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND,
}

local function GetDetailedLevel(itemLink)
    if not itemLink then
        return nil
    end

    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local level = C_Item.GetDetailedItemLevelInfo(itemLink)
        if level and level > 0 then
            return level
        end
    end

    if GetDetailedItemLevelInfo then
        local level = GetDetailedItemLevelInfo(itemLink)
        if level and level > 0 then
            return level
        end
    end

    return nil
end

local function FormatItemLevel(value)
    if not value then
        return nil
    end

    local text = string.format("%.6f", value)
    text = text:gsub("0+$", "")
    text = text:gsub("%.$", "")
    return text
end

function ns.InspectItemLevel:IsEnabled()
    return ns.db and ns.db.profile and ns.db.profile.inspectItemLevelEnabled
end

function ns.InspectItemLevel:EnsureLabel()
    if self.label or not InspectFrame then
        return
    end

    local anchor = InspectNameText or InspectFrame
    local container = CreateFrame("Frame", nil, InspectFrame)
    container:SetSize(132, 22)
    container:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    container:SetFrameStrata("HIGH")
    container:Hide()

    local background = container:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.55)

    local borderTop = container:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(1, 0.82, 0.1, 0.55)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", container, "CENTER", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetDrawLayer("OVERLAY", 7)
    label:SetTextColor(1, 0.82, 0.1)
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 1)
    label:Hide()

    self.container = container
    self.label = label
end

function ns.InspectItemLevel:SetLabel(text, r, g, b)
    self:EnsureLabel()
    if not self.label or not self.container then
        return
    end

    self.label:SetText(text or "")
    self.label:SetTextColor(r or 1, g or 0.82, b or 0.1)
    if text and text ~= "" and self:IsEnabled() and InspectFrame and InspectFrame:IsShown() then
        self.container:Show()
        self.label:Show()
    else
        self.container:Hide()
        self.label:Hide()
    end
end

function ns.InspectItemLevel:Clear()
    self.pendingGUID = nil
    self.pendingUnit = nil
    self:SetLabel("")
end

function ns.InspectItemLevel:GetInspectUnit()
    if InspectFrame and InspectFrame.unit then
        return InspectFrame.unit
    end
    if UnitExists("target") then
        return "target"
    end
    return nil
end

function ns.InspectItemLevel:ComputeAverageItemLevel(unit)
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local inspectLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
        if inspectLevel and inspectLevel > 0 then
            return inspectLevel, 16
        end
    end

    local total = 0
    local count = 0
    local mainHandLevel = nil
    local offHandLevel = nil

    for _, slot in ipairs(INVENTORY_SLOTS) do
        local itemLink = GetInventoryItemLink(unit, slot)
        local itemLevel = GetDetailedLevel(itemLink)
        if itemLevel then
            total = total + itemLevel
            count = count + 1
            if slot == INVSLOT_MAINHAND then
                mainHandLevel = itemLevel
            elseif slot == INVSLOT_OFFHAND then
                offHandLevel = itemLevel
            end
        end
    end

    if mainHandLevel and not offHandLevel then
        total = total + mainHandLevel
        count = count + 1
    end

    if count == 0 then
        return nil, 0
    end

    return total / count, count
end

function ns.InspectItemLevel:UpdateFromInspect(unit)
    if not self:IsEnabled() then
        self:SetLabel("")
        return
    end

    local average, count = self:ComputeAverageItemLevel(unit)
    if not average then
        self:SetLabel("iLvl: waiting for inspect...", 0.9, 0.9, 0.9)
        return
    end

    self.lastAverage = average
    self.lastUnit = unit
    self:SetLabel("iLvl: " .. (FormatItemLevel(average) or tostring(average)), 1, 0.82, 0.1)
    if ns.db and ns.db.profile and ns.db.profile.debug then
        ns.Utils:Debug(string.format("Inspect iLvl for %s: %s from %d slots", UnitName(unit) or unit, FormatItemLevel(average) or tostring(average), count))
    end
end

function ns.InspectItemLevel:RequestInspect(unit)
    if not self:IsEnabled() then
        self:SetLabel("")
        return
    end

    if not unit or not UnitExists(unit) or not CanInspect(unit, false) then
        self:SetLabel("iLvl: inspect unavailable", 0.9, 0.35, 0.35)
        return
    end

    self.pendingUnit = unit
    self.pendingGUID = UnitGUID(unit)
    self:SetLabel("iLvl: scanning...", 0.9, 0.9, 0.9)
    NotifyInspect(unit)
end

function ns.InspectItemLevel:Refresh()
    self:EnsureHooks()
    self:EnsureLabel()
    if not self:IsEnabled() then
        self:Clear()
        return
    end

    if InspectFrame and InspectFrame:IsShown() then
        self:RequestInspect(self:GetInspectUnit())
    end
end

function ns.InspectItemLevel:RefreshSoon(delay)
    if not C_Timer or not C_Timer.After then
        self:Refresh()
        return
    end

    C_Timer.After(delay or 0, function()
        if ns.InspectItemLevel then
            ns.InspectItemLevel:Refresh()
        end
    end)
end

function ns.InspectItemLevel:HookInspectFrame()
    if self.hookedInspectFrame or not InspectFrame then
        return
    end

    self.hookedInspectFrame = true
    self:EnsureLabel()

    InspectFrame:HookScript("OnShow", function()
        ns.InspectItemLevel:RefreshSoon(0.05)
    end)

    InspectFrame:HookScript("OnHide", function()
        ClearInspectPlayer()
        ns.InspectItemLevel:Clear()
    end)

    if InspectPaperDollItemsFrame then
        InspectPaperDollItemsFrame:HookScript("OnShow", function()
            ns.InspectItemLevel:RefreshSoon(0.05)
        end)
    end

    if InspectFrame_SetUnit then
        hooksecurefunc("InspectFrame_SetUnit", function()
            ns.InspectItemLevel:RefreshSoon(0.05)
        end)
    end
end

function ns.InspectItemLevel:EnsureHooks()
    if not self.hookedInspectFrame and InspectFrame then
        self:HookInspectFrame()
    end
end

function ns.InspectItemLevel:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("INSPECT_READY")
    frame:SetScript("OnEvent", function(_, event, arg1)
        ns.InspectItemLevel:EnsureHooks()

        if event == "ADDON_LOADED" then
            ns.InspectItemLevel:EnsureHooks()
        elseif event == "INSPECT_READY" then
            if not ns.InspectItemLevel:IsEnabled() then
                return
            end

            local unit = ns.InspectItemLevel:GetInspectUnit()
            if not unit or not UnitExists(unit) then
                ns.InspectItemLevel:SetLabel("iLvl: inspect lost", 0.9, 0.35, 0.35)
                return
            end

            if ns.InspectItemLevel.pendingGUID and arg1 and ns.InspectItemLevel.pendingGUID ~= arg1 then
                return
            end

            ns.InspectItemLevel:UpdateFromInspect(unit)
        end
    end)

    self.frame = frame

    if IsAddOnLoaded and IsAddOnLoaded("Blizzard_InspectUI") then
        self:HookInspectFrame()
    end
end

function ns.InspectItemLevel:SetEnabled(enabled)
    if not ns.db or not ns.db.profile then
        return
    end

    ns.db.profile.inspectItemLevelEnabled = enabled and true or false
    self:Refresh()
    ns.Utils:Print("Inspect item level " .. (ns.db.profile.inspectItemLevelEnabled and "enabled." or "disabled."))
end

function ns.InspectItemLevel:Toggle()
    self:SetEnabled(not self:IsEnabled())
end
