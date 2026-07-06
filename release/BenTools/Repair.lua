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
end

function ns.Repair:ShowReminder(percent)
    EnsurePopup()
    StaticPopup_Show("BENTOOLS_REPAIR_REMINDER", percent)
end

function ns.Repair:Evaluate(source)
    local profile = ns.db and ns.db.profile
    if not profile or not profile.enabled or not profile.repairReminderEnabled then
        self:HideReminder()
        self.alertShown = false
        return
    end

    local percent = self:GetDurabilityPercent()
    if not percent then
        return
    end

    local threshold = GetThreshold()
    if percent <= threshold then
        if not self.alertShown or self.lastPercent ~= percent or source == "MERCHANT_SHOW" then
            self:ShowReminder(percent)
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
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(2, function()
            ns.Repair:Evaluate(event)
        end)
    else
        ns.Repair:Evaluate(event)
    end
end)
