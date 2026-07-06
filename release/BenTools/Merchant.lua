local addonName, ns = ...

ns.Merchant = {}

local frame = CreateFrame("Frame")
local sellQueue = {}
local selling = false
local soldStacks = 0
local soldItems = 0
local soldValue = 0

local function SellNext()
    if not selling then
        return
    end
    if not ns.Utils:IsMerchantOpen() then
        ns.Utils:Print("Selling stopped because the merchant window closed.")
        selling = false
        return
    end

    local item = table.remove(sellQueue, 1)
    if not item then
        selling = false
        ns.Utils:Print(string.format("Sold %d items for %s.", soldItems, ns.Utils:FormatMoney(soldValue)))
        ns.Merchant:Refresh()
        return
    end

    local current = ns.Rules:GetItemData(item.bag, item.slot)
    if current and current.itemID == item.itemID then
        local shouldSell = ns.Rules:ShouldSellItem(current)
        if shouldSell then
            C_Container.UseContainerItem(item.bag, item.slot)
            soldStacks = soldStacks + 1
            soldItems = soldItems + current.stackCount
            soldValue = soldValue + (current.sellPrice * current.stackCount)
        end
    end

    C_Timer.After(0.18, SellNext)
end

local function ConfirmAndSell()
    local profile = ns.db.profile
    if profile.confirmLargeSales and ns.Merchant.currentScan and ns.Merchant.currentScan.totalValue >= profile.confirmGoldThreshold then
        StaticPopupDialogs.BENTOOLS_CONFIRM_SELL = {
            text = "Sell marked items for " .. ns.Utils:FormatMoney(ns.Merchant.currentScan.totalValue) .. "?",
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                ns.Merchant:SellCurrentScan()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("BENTOOLS_CONFIRM_SELL")
    else
        ns.Merchant:SellCurrentScan()
    end
end

function ns.Merchant:CreateButton()
    if self.button then
        return
    end

    local button = CreateFrame("Button", "BenToolsMerchantButton", MerchantFrame, "UIPanelButtonTemplate")
    button:SetSize(260, 24)
    button:SetText("Sell Marked Items")
    button:SetScript("OnClick", ConfirmAndSell)
    self.button = button
end

function ns.Merchant:AttachButton()
    self:CreateButton()
    if not self.button then
        return
    end

    self.button:SetParent(MerchantFrame)
    self.button:ClearAllPoints()
    self.button:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 8, -28)
end

function ns.Merchant:Refresh()
    if not ns.Utils:IsMerchantOpen() then
        return
    end

    self:AttachButton()
    self.currentScan = ns.Scanner:ScanBags()
    local count = self.currentScan.itemCount
    local value = self.currentScan.totalValue
    self.button:SetText(string.format("Sell Marked Items (%d stacks, %s)", count, ns.Utils:FormatMoney(value)))
    self.button:SetEnabled(count > 0 and not selling)
    self.button:Show()
end

function ns.Merchant:SellCurrentScan()
    if selling then
        return
    end
    if not ns.Utils:IsMerchantOpen() then
        ns.Utils:Print("Open a merchant before selling.")
        return
    end

    local scan = self.currentScan or ns.Scanner:ScanBags()
    if scan.itemCount == 0 then
        ns.Utils:Print("No matching items to sell.")
        return
    end

    wipe(sellQueue)
    for _, item in ipairs(scan.items) do
        table.insert(sellQueue, {
            bag = item.bag,
            slot = item.slot,
            itemID = item.itemID,
        })
    end

    selling = true
    soldStacks = 0
    soldItems = 0
    soldValue = 0
    self.button:SetEnabled(false)
    SellNext()
end

function ns.Merchant:OnMerchantShow()
    self:AttachButton()
    self:Refresh()
    C_Timer.After(0, function()
        ns.Merchant:Refresh()
    end)
end

function ns.Merchant:OnMerchantClosed()
    selling = false
    wipe(sellQueue)
    if self.button then
        self.button:Hide()
    end
end

frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        ns.Merchant:OnMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
        ns.Merchant:OnMerchantClosed()
    elseif event == "BAG_UPDATE_DELAYED" and ns.Utils:IsMerchantOpen() then
        ns.Merchant:Refresh()
    end
end)
