local addonName, ns = ...

ns.Repair = {}

local frame = CreateFrame("Frame")
local EQUIPPED_SLOTS = {
    1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
}

local function GetThreshold()
    local profile = ns.db and ns.db.profile
    local threshold = profile and tonumber(profile.repairReminderThreshold) or 50
    threshold = math.floor(threshold)
    if threshold < 1 then
        threshold = 1
    elseif threshold > 100 then
        threshold = 100
    end
    return threshold
end

local function EnsurePopup()
    if StaticPopupDialogs.BENTOOLS_REPAIR_REMINDER then
        return
    end

    StaticPopupDialogs.BENTOOLS_REPAIR_REMINDER = {
        text = "Your equipment durability is %d%%.\nYou should repair soon.",
        button1 = OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = STATICPOPUP_NUMDIALOGS,
    }
end

function ns.Repair:GetDurabilityPercent()
    local currentTotal = 0
    local maxTotal = 0

    for _, slotID in ipairs(EQUIPPED_SLOTS) do
        local current, maximum = GetInventoryItemDurability(slotID)
        if current and maximum and maximum > 0 then
            currentTotal = currentTotal + current
            maxTotal = maxTotal + maximum
        end
    end

    if maxTotal <= 0 then
        return nil
    end

    return math.floor(((currentTotal / maxTotal) * 100) + 0.5)
end

function ns.Repair:HideReminder()
    StaticPopup_Hide("BENTOOLS_REPAIR_REMINDER")
    self.popup = nil
end

function ns.Repair:ShowReminder(percent)
    if InCombatLockdown() or UnitAffectingCombat("player") then
        self.pendingCombatCheck = true
        return false
    end

    if self.popup and self.popup:IsShown() then
        return false
    end

    EnsurePopup()
    self.popup = StaticPopup_Show("BENTOOLS_REPAIR_REMINDER", percent)
    return self.popup ~= nil
end

function ns.Repair:EnterCombat()
    local popupWasVisible = self.popup and self.popup:IsShown()
    self:HideReminder()

    if popupWasVisible then
        self.alertShown = false
        self.pendingCombatCheck = true
    end
end

function ns.Repair:Evaluate()
    local profile = ns.db and ns.db.profile
    if not profile or not profile.enabled or not profile.repairReminderEnabled then
        self:HideReminder()
        self.alertShown = false
        self.pendingCombatCheck = false
        self.lastPercent = nil
        return
    end

    if InCombatLockdown() or UnitAffectingCombat("player") then
        self.pendingCombatCheck = true
        self:EnterCombat()
        return
    end

    local percent = self:GetDurabilityPercent()
    if not percent then
        return
    end

    local threshold = GetThreshold()
    if percent <= threshold then
        if not self.alertShown and self:ShowReminder(percent) then
            self.alertShown = true
        end
    else
        self:HideReminder()
        self.alertShown = false
    end

    self.lastPercent = percent
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(2, function()
            ns.Repair:Evaluate()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.Repair:EnterCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.Repair.pendingCombatCheck then
            ns.Repair.pendingCombatCheck = false
            ns.Repair:Evaluate()
        end
    else
        ns.Repair:Evaluate()
    end
end)
