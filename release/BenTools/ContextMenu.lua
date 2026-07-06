local addonName, ns = ...

ns.ContextMenu = {}

local function MarkFromLocation(itemLocation, mode)
    if not itemLocation or not itemLocation.IsBagAndSlot or not itemLocation:IsBagAndSlot() then
        return
    end

    local bag, slot = itemLocation:GetBagAndSlot()
    if not ns.Utils:IsNormalBag(bag) then
        return
    end

    local itemData = ns.Rules:GetItemData(bag, slot)
    if not itemData then
        ns.Utils:Print("Item data is still loading. Try again in a moment.")
        return
    end

    if mode == "always" then
        local newValue = not ns.DB:IsAlwaysSell(itemData.itemID)
        ns.DB:SetAlwaysSell(itemData.itemID, itemData.itemName, newValue)
        ns.Utils:Print(string.format("%s %s Always Sell.", itemData.itemLink, newValue and "added to" or "removed from"))
    elseif mode == "never" then
        local newValue = not ns.DB:IsNeverSell(itemData.itemID)
        ns.DB:SetNeverSell(itemData.itemID, itemData.itemName, newValue)
        ns.Utils:Print(string.format("%s %s Never Sell.", itemData.itemLink, newValue and "added to" or "removed from"))
    end

    if ns.Settings and ns.Settings.RefreshLists then
        ns.Settings:RefreshLists()
    end
    if ns.Merchant and ns.Utils:IsMerchantOpen() then
        ns.Merchant:Refresh()
    end
end

local function MarkFromBagSlot(bag, slot, mode)
    if not ns.Utils:IsNormalBag(bag) then
        return
    end

    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    MarkFromLocation(location, mode)
end

function ns.ContextMenu:Initialize()
    if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnModifiedClick then
        hooksecurefunc(ContainerFrameItemButtonMixin, "OnModifiedClick", function(itemButton, mouseButton)
            if mouseButton ~= "RightButton" or not itemButton.GetBagID or not itemButton.GetID then
                return
            end
            if IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() then
                MarkFromBagSlot(itemButton:GetBagID(), itemButton:GetID(), "always")
            elseif IsAltKeyDown() and IsControlKeyDown() and not IsShiftKeyDown() then
                MarkFromBagSlot(itemButton:GetBagID(), itemButton:GetID(), "never")
            end
        end)
    else
        hooksecurefunc("HandleModifiedItemClick", function(_, itemLocation)
            if IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() then
                MarkFromLocation(itemLocation, "always")
            elseif IsAltKeyDown() and IsControlKeyDown() and not IsShiftKeyDown() then
                MarkFromLocation(itemLocation, "never")
            end
        end)
    end
end
