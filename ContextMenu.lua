local addonName, ns = ...

ns.ContextMenu = {}

local function MarkFromItemLink(itemLink, mode)
    local itemID = ns.Utils:GetItemIDFromLink(itemLink)
    if not itemID then
        return false
    end

    local itemName = ns.Utils:GetSafeItemName(itemLink) or ns.DB:GetItemName(itemID)
    local itemText = itemLink or itemName or ("item:" .. tostring(itemID))

    if mode == "always" then
        local newValue = not ns.DB:IsAlwaysSell(itemID)
        ns.DB:SetAlwaysSell(itemID, itemName, newValue)
        ns.Utils:Print(string.format("%s %s Always Sell.", itemText, newValue and "added to" or "removed from"))
    elseif mode == "never" then
        local newValue = not ns.DB:IsNeverSell(itemID)
        ns.DB:SetNeverSell(itemID, itemName, newValue)
        ns.Utils:Print(string.format("%s %s Never Sell.", itemText, newValue and "added to" or "removed from"))
    else
        return false
    end

    if ns.Settings and ns.Settings.RefreshLists then
        ns.Settings:RefreshLists()
    end
    if ns.Merchant and ns.Utils:IsMerchantOpen() then
        ns.Merchant:Refresh()
    end
    return true
end

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

local function TryMarkButton(itemButton, mode)
    if itemButton and itemButton.GetItemLocation then
        local location = itemButton:GetItemLocation()
        if location and location.IsBagAndSlot and location:IsBagAndSlot() then
            MarkFromLocation(location, mode)
            return true
        end
    end

    if itemButton and itemButton.GetBagID and itemButton.GetID then
        local bag = itemButton:GetBagID()
        local slot = itemButton:GetID()
        if ns.Utils:IsNormalBag(bag) then
            MarkFromBagSlot(bag, slot, mode)
            return true
        end
    end

    local itemLink = ns.Utils:GetMouseoverItemLink()
    if itemLink then
        return MarkFromItemLink(itemLink, mode)
    end

    return false
end

function ns.ContextMenu:Initialize()
    if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnModifiedClick then
        hooksecurefunc(ContainerFrameItemButtonMixin, "OnModifiedClick", function(itemButton, mouseButton)
            if mouseButton ~= "RightButton" then
                return
            end
            if IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() then
                TryMarkButton(itemButton, "always")
            elseif IsAltKeyDown() and IsControlKeyDown() and not IsShiftKeyDown() then
                TryMarkButton(itemButton, "never")
            end
        end)
    else
        hooksecurefunc("HandleModifiedItemClick", function(_, itemLocation)
            if IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() then
                if itemLocation and itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
                    MarkFromLocation(itemLocation, "always")
                else
                    local itemLink = ns.Utils:GetMouseoverItemLink()
                    if itemLink then
                        MarkFromItemLink(itemLink, "always")
                    end
                end
            elseif IsAltKeyDown() and IsControlKeyDown() and not IsShiftKeyDown() then
                if itemLocation and itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot() then
                    MarkFromLocation(itemLocation, "never")
                else
                    local itemLink = ns.Utils:GetMouseoverItemLink()
                    if itemLink then
                        MarkFromItemLink(itemLink, "never")
                    end
                end
            end
        end)
    end
end
