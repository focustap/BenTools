local addonName, ns = ...

ns.Utils = {}

local COPPER_PER_GOLD = 10000
local COPPER_PER_SILVER = 100

function ns.Utils:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[BenTools]|r " .. tostring(message))
end

function ns.Utils:Debug(message)
    if ns.db and ns.db.profile and ns.db.profile.debug then
        self:Print(message)
    end
end

function ns.Utils:FormatMoney(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / COPPER_PER_GOLD)
    local silver = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local rest = copper % COPPER_PER_SILVER

    if gold > 0 then
        return string.format("%dg %02ds %02dc", gold, silver, rest)
    elseif silver > 0 then
        return string.format("%ds %02dc", silver, rest)
    end
    return string.format("%dc", rest)
end

function ns.Utils:GetItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

function ns.Utils:IsNormalBag(bag)
    local backpack = Enum and Enum.BagIndex and Enum.BagIndex.Backpack or 0
    local normalBags = Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots or 4
    return type(bag) == "number" and bag >= backpack and bag <= normalBags
end

function ns.Utils:GetNormalBagRange()
    local backpack = Enum and Enum.BagIndex and Enum.BagIndex.Backpack or 0
    local normalBags = Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots or 4
    return backpack, normalBags
end

function ns.Utils:GetContainerItemLink(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    return info and info.hyperlink
end

function ns.Utils:GetItemInfoSafe(item)
    if not item then
        return nil
    end
    return C_Item.GetItemInfo(item)
end

function ns.Utils:IsMerchantOpen()
    return MerchantFrame and MerchantFrame:IsShown()
end

function ns.Utils:IsEquipmentSetItem(bag, slot)
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs then
        return false
    end

    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not location or location:IsEquipmentSlot() then
        return false
    end

    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    if type(setIDs) ~= "table" then
        return false
    end

    for _, setID in ipairs(setIDs) do
        local locations = C_EquipmentSet.GetItemLocations(setID)
        if type(locations) == "table" then
            for _, packedLocation in pairs(locations) do
                if type(packedLocation) == "number" and EquipmentManager_UnpackLocation then
                    local player, bank, bags, setSlot, setBag = EquipmentManager_UnpackLocation(packedLocation)
                    if player and bags and not bank and setBag == bag and setSlot == slot then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function ns.Utils:IsItemFavoriteOrProtected(itemData)
    local info = itemData.containerInfo
    if info and info.isLocked then
        return true, "Locked bag slot"
    end

    if C_Item and C_Item.IsItemDataCachedByID and itemData.itemID and not C_Item.IsItemDataCachedByID(itemData.itemID) then
        return true, "Item data not cached"
    end

    return false
end
