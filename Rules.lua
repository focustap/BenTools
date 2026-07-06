local addonName, ns = ...

ns.Rules = {}

local EQUIPMENT_CLASSES = {
    [Enum.ItemClass.Armor] = true,
    [Enum.ItemClass.Weapon] = true,
}

local SAFE_EQUIP_LOCS = {
    INVTYPE_AMMO = false,
    INVTYPE_BAG = false,
    INVTYPE_QUIVER = false,
    INVTYPE_TABARD = false,
}

local function QualityInRange(quality, profile)
    quality = tonumber(quality)
    if not quality then
        return false
    end
    return quality >= profile.minQuality and quality <= profile.maxQuality
end

local function IsRelevantEquipment(itemData)
    if not itemData.itemLink then
        return false
    end

    local classID = select(12, C_Item.GetItemInfo(itemData.itemLink))
    local equipLoc = select(9, C_Item.GetItemInfo(itemData.itemLink))
    if not EQUIPMENT_CLASSES[classID] or not equipLoc or equipLoc == "" then
        return false
    end
    if SAFE_EQUIP_LOCS[equipLoc] == false then
        return false
    end
    return C_Item.IsEquippableItem(itemData.itemLink) and true or false
end

local function IsCraftingMaterial(itemData)
    if not itemData.itemLink then
        return false
    end
    if C_Item.IsCraftingReagent and C_Item.IsCraftingReagent(itemData.itemLink) then
        return true
    end

    local classID = select(12, C_Item.GetItemInfo(itemData.itemLink))
    return classID == Enum.ItemClass.Tradegoods
end

local function IsBoE(itemData)
    if itemData.isBound then
        return false
    end
    if not itemData.itemLink or not C_TooltipInfo or not C_TooltipInfo.GetBagItem then
        return false
    end

    local tooltip = C_TooltipInfo.GetBagItem(itemData.bag, itemData.slot)
    if tooltip and type(tooltip.lines) == "table" then
        for _, line in ipairs(tooltip.lines) do
            local text = line.leftText
            if text == ITEM_BIND_ON_EQUIP or text == ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP or text == ITEM_BIND_TO_BNETACCOUNT_UNTIL_EQUIP then
                return true
            end
        end
    end
    return false
end

function ns.Rules:GetItemData(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.itemID then
        return nil, "Empty slot"
    end

    local itemLink = info.hyperlink
    if not itemLink then
        return nil, "Item info not cached"
    end

    local name, _, quality, itemLevel, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink)
    if not name then
        return nil, "Item info not cached"
    end

    local item = Item:CreateFromBagAndSlot(bag, slot)
    local currentItemLevel = item and item.GetCurrentItemLevel and item:GetCurrentItemLevel() or itemLevel

    local data = {
        bag = bag,
        slot = slot,
        itemID = info.itemID,
        itemName = info.itemName or name,
        itemLink = itemLink,
        stackCount = info.stackCount or 1,
        quality = quality or info.quality,
        itemLevel = currentItemLevel or itemLevel or 0,
        sellPrice = sellPrice or 0,
        hasNoValue = info.hasNoValue,
        isBound = info.isBound,
        containerInfo = info,
    }

    ns.DB:SetItemName(data.itemID, data.itemName)
    return data
end

function ns.Rules:ShouldSellItem(itemData)
    local profile = ns.db.profile
    if not profile.enabled then
        return false, "Addon disabled"
    end
    if not itemData or not itemData.itemID then
        return false, "Missing item data"
    end

    if ns.DB:IsNeverSell(itemData.itemID) then
        return false, "Blocked by Never Sell"
    end

    local protected, reason = ns.Utils:IsItemFavoriteOrProtected(itemData)
    if protected then
        return false, reason
    end

    if itemData.hasNoValue or itemData.sellPrice <= 0 then
        return false, "No vendor value"
    end

    if profile.excludeEquipmentSets and ns.Utils:IsEquipmentSetItem(itemData.bag, itemData.slot) then
        return false, "Protected equipment set item"
    end

    if ns.DB:IsAlwaysSell(itemData.itemID) then
        return true, "Always Sell list"
    end

    if profile.excludeCrafting and IsCraftingMaterial(itemData) then
        return false, "Crafting material"
    end

    if profile.sellGray and itemData.quality == Enum.ItemQuality.Poor then
        return true, "Gray item"
    end

    if profile.equipmentRuleEnabled then
        if not IsRelevantEquipment(itemData) then
            return false, "Not eligible gear"
        end
        if not QualityInRange(itemData.quality, profile) then
            return false, "Quality outside range"
        end
        if profile.soulboundOnly and not itemData.isBound then
            return false, "Not soulbound"
        end
        if profile.boeOnly and not IsBoE(itemData) then
            return false, "Not BoE"
        end
        if itemData.itemLevel < profile.itemLevelThreshold then
            return true, "Equipment below ilvl threshold"
        end
    end

    return false, "No matching rule"
end
