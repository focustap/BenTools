local addonName, ns = ...

ns.Scanner = {}

function ns.Scanner:ScanBags()
    local results = {
        items = {},
        itemCount = 0,
        stackCount = 0,
        totalValue = 0,
        pending = false,
    }

    local firstBag, lastBag = ns.Utils:GetNormalBagRange()
    for bag = firstBag, lastBag do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemData, pendingReason = ns.Rules:GetItemData(bag, slot)
            if itemData then
                local shouldSell, reason = ns.Rules:ShouldSellItem(itemData)
                ns.Utils:Debug(string.format("%s: %s - %s", itemData.itemName or itemData.itemLink, shouldSell and "SELL" or "KEEP", reason))
                if shouldSell then
                    itemData.reason = reason
                    itemData.stackValue = itemData.sellPrice * itemData.stackCount
                    table.insert(results.items, itemData)
                    results.itemCount = results.itemCount + 1
                    results.stackCount = results.stackCount + itemData.stackCount
                    results.totalValue = results.totalValue + itemData.stackValue
                end
            elseif pendingReason == "Item info not cached" then
                results.pending = true
            end
        end
    end

    return results
end

function ns.Scanner:PrintScan()
    local results = self:ScanBags()
    if results.itemCount == 0 then
        ns.Utils:Print(results.pending and "Nothing matched yet. Some item data is still loading; try again in a moment." or "No matching items found.")
        return
    end

    ns.Utils:Print(string.format("Scan found %d stacks (%d items) worth %s.", results.itemCount, results.stackCount, ns.Utils:FormatMoney(results.totalValue)))
    for _, item in ipairs(results.items) do
        ns.Utils:Print(string.format("%s x%d - %s (%s)", item.itemLink or item.itemName, item.stackCount, ns.Utils:FormatMoney(item.stackValue), item.reason))
    end
end
