local addonName, ns = ...

ns.Core = {}

local frame = CreateFrame("Frame")

function ns.Core:OpenSettings()
    if ns.Settings and ns.Settings.categoryID and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.Settings.categoryID)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                Settings.OpenToCategory(ns.Settings.categoryID)
            end)
        end
    end
end

function ns.Core:RunAutoSellScan()
    ns.Scanner:PrintScan()
    if ns.MainWindow then
        ns.MainWindow:Refresh()
    end
end

function ns.Core:OpenMythicPlusFinder()
    if not ns.MythicPlusFinder then
        ns.Utils:Print("[M+] Finder module did not load.")
        return
    end

    ns.MythicPlusFinder:EnsureDefaults()

    if not ns.MythicPlusFinder.UI then
        ns.Utils:Print("[M+] Finder UI did not load.")
        return
    end

    if ns.MythicPlusFinder.UI.Initialize and not ns.MythicPlusFinder.UI.frame then
        ns.MythicPlusFinder.UI:Initialize()
    end

    if ns.MythicPlusFinder.UI.Open then
        ns.MythicPlusFinder.UI:Open()
    else
        ns.Utils:Print("[M+] Finder UI is missing its Open method.")
    end
end

function ns.Core:RunSellPreview()
    self:RunAutoSellScan()
end

function ns.Core:ShowRuleList(whichList)
    if whichList == "always" or whichList == nil then
        ns.Utils:Print("Always Sell:")
        local any = false
        for itemID in pairs(ns.db.alwaysSell) do
            any = true
            ns.Utils:Print("  " .. ns.DB:GetItemName(itemID) .. " (" .. itemID .. ")")
        end
        if not any then
            ns.Utils:Print("  none")
        end
    end

    if whichList == "never" or whichList == nil then
        ns.Utils:Print("Never Sell:")
        local any = false
        for itemID in pairs(ns.db.neverSell) do
            any = true
            ns.Utils:Print("  " .. ns.DB:GetItemName(itemID) .. " (" .. itemID .. ")")
        end
        if not any then
            ns.Utils:Print("  none")
        end
    end
end

function ns.Core:ShowAlwaysSellList()
    self:ShowRuleList("always")
end

function ns.Core:ShowNeverSellList()
    self:ShowRuleList("never")
end

function ns.Core:ClearRules()
    ns.DB:ClearRules()
    ns.Utils:Print("Cleared Always Sell and Never Sell lists.")
    if ns.Settings then
        ns.Settings:RefreshLists()
    end
    if ns.MainWindow then
        ns.MainWindow:Refresh()
    end
end

function ns.Core:MarkMouseoverNever()
    local itemLink = ns.Utils:GetMouseoverItemLink()
    local itemID = ns.Utils:GetItemIDFromLink(itemLink)
    if not itemID then
        ns.Utils:Print("Mouse over an item first.")
        return
    end

    local itemName = ns.Utils:GetSafeItemName(itemLink) or ns.DB:GetItemName(itemID)
    ns.DB:SetNeverSell(itemID, itemName, true)
    ns.Utils:Print((itemLink or itemName or ("item:" .. tostring(itemID))) .. " added to Never Sell.")
    if ns.Settings then
        ns.Settings:RefreshLists()
    end
    if ns.Merchant and ns.Utils:IsMerchantOpen() then
        ns.Merchant:Refresh()
    end
end

function ns.Core:ShowQueueStatus()
    if ns.QueueRinger then
        ns.QueueRinger:PrintStatus()
    end
    if ns.MainWindow then
        ns.MainWindow:Refresh()
    end
end

function ns.Core:TestQueueNotification()
    if ns.QueueRinger then
        ns.QueueRinger:CreateTestEvent()
    end
    if ns.MainWindow then
        ns.MainWindow:Refresh()
    end
end

function ns.Core:ToggleQueueEnabled()
    if ns.QueueRinger and ns.db and ns.db.queueRinger then
        ns.QueueRinger:SetEnabled(not ns.db.queueRinger.enabled)
    end
    if ns.MainWindow then
        ns.MainWindow:Refresh()
    end
end

function ns.Core:ToggleQueueDebug()
    if ns.QueueRinger then
        ns.QueueRinger:ToggleDebug()
    end
    if ns.MainWindow then
        ns.MainWindow:Refresh()
    end
end

function ns.Core:ShowVersionStatus()
    local version = "unknown"
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata(addonName, "Version") or version
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata(addonName, "Version") or version
    end
    ns.Utils:Print("BenTools version " .. tostring(version or "unknown") .. ".")
    ns.Utils:Print("Auto Sell: " .. ((ns.db and ns.db.profile and ns.db.profile.enabled) and "enabled" or "disabled"))
    if ns.QueueRinger and ns.db and ns.db.queueRinger then
        ns.Utils:Print("Queue Ringer: " .. (ns.db.queueRinger.enabled and "enabled" or "disabled"))
        ns.Utils:Print("Premade Invites: " .. (ns.db.queueRinger.notifyPremade and "enabled" or "disabled"))
        ns.Utils:Print("Ready Checks: " .. (ns.db.queueRinger.notifyReadyCheck and "enabled" or "disabled"))
    end
    if ns.db and ns.db.profile then
        ns.Utils:Print("Repair Reminder: " .. (ns.db.profile.repairReminderEnabled and "enabled" or "disabled"))
        ns.Utils:Print("Repair Threshold: " .. tostring(ns.db.profile.repairReminderThreshold or 50) .. "%")
    end
end

function ns.Core:OpenMainWindow()
    if ns.MainWindow then
        ns.MainWindow:Open()
    end
end

function ns.Core:ToggleMainWindow()
    if ns.MainWindow then
        ns.MainWindow:Toggle()
    end
end

function ns.Core:PrintHelp()
    ns.Utils:Print("/bt help - Show commands")
    ns.Utils:Print("/bt - Open or close the BenTools control panel")
    ns.Utils:Print("/bt settings - Open BenTools settings")
    ns.Utils:Print("/bt queue status - Show Queue Ringer status")
    ns.Utils:Print("/bt queue test - Test Queue Ringer notification")
    ns.Utils:Print("/bt queue on - Enable Queue Ringer")
    ns.Utils:Print("/bt queue off - Disable Queue Ringer")
    ns.Utils:Print("/bt queue debug - Toggle Queue Ringer debug")
    ns.Utils:Print("/bt mplus - Open the Mythic+ Finder")
    ns.Utils:Print("/bt mythic - Mythic+ Finder alias")
    ns.Utils:Print("/bt finder - Mythic+ Finder alias")
    ns.Utils:Print("/bt mplus search - Refresh Mythic+ search results")
    ns.Utils:Print("/bt mplus status - Show Mythic+ Finder status")
    ns.Utils:Print("/bt mplus dump - Dump live Mythic+ search result diagnostics")
    ns.Utils:Print("/bt mplus debug - Toggle Mythic+ Finder debug")
    ns.Utils:Print("/bt autosell scan - Scan bags for items matching Auto Sell rules")
    ns.Utils:Print("/bt autosell list - Show Always Sell and Never Sell lists")
    ns.Utils:Print("/bt autosell clear - Clear Always Sell and Never Sell lists")
    ns.Utils:Print("/bt autosell never - Mark the currently moused-over bag item as Never Sell")
    ns.Utils:Print("/bt scan - Auto Sell scan shortcut")
    ns.Utils:Print("/bt queue help - Show Queue Ringer commands")
    ns.Utils:Print("Alt-right-click a bag item to toggle Always Sell; Ctrl-Alt-right-click toggles Never Sell.")
end

local function HandleAutoSellSlash(message)
    message = (message or ""):match("^%s*(.-)%s*$"):lower()
    if message == "" or message == "scan" or message == "preview" then
        ns.Core:RunAutoSellScan()
    elseif message == "list" then
        ns.Core:ShowRuleList()
    elseif message == "always" then
        ns.Core:ShowAlwaysSellList()
    elseif message == "neverlist" then
        ns.Core:ShowNeverSellList()
    elseif message == "never" then
        ns.Core:MarkMouseoverNever()
    elseif message == "clear" then
        ns.Core:ClearRules()
    else
        ns.Utils:Print("Unknown Auto Sell command. Use /bt help.")
    end
end

local function SlashHandler(message)
    local rawMessage = (message or ""):match("^%s*(.-)%s*$")
    message = rawMessage:lower()

    if message == "" then
        ns.Core:ToggleMainWindow()
    elseif message == "help" then
        ns.Core:PrintHelp()
    elseif message:match("^queue") then
        if ns.QueueRinger then
            ns.QueueRinger:HandleSlash(rawMessage:gsub("^%s*[Qq][Uu][Ee][Uu][Ee]%s*", ""))
        end
        if ns.MainWindow then
            ns.MainWindow:Refresh()
        end
    elseif message:match("^mplus") then
        if ns.MythicPlusFinder then
            ns.MythicPlusFinder:HandleSlash(rawMessage:gsub("^%s*[Mm][Pp][Ll][Uu][Ss]%s*", ""))
        end
    elseif message:match("^mythic") then
        if ns.MythicPlusFinder then
            ns.MythicPlusFinder:HandleSlash(rawMessage:gsub("^%s*[Mm][Yy][Tt][Hh][Ii][Cc]%s*", ""))
        end
    elseif message:match("^finder") then
        if ns.MythicPlusFinder then
            ns.MythicPlusFinder:HandleSlash(rawMessage:gsub("^%s*[Ff][Ii][Nn][Dd][Ee][Rr]%s*", ""))
        end
    elseif message:match("^autosell") then
        HandleAutoSellSlash(rawMessage:gsub("^%s*[Aa][Uu][Tt][Oo][Ss][Ee][Ll][Ll]%s*", ""))
    elseif message == "list" then
        ns.Core:ShowRuleList()
    elseif message == "always" then
        ns.Core:ShowAlwaysSellList()
    elseif message == "neverlist" then
        ns.Core:ShowNeverSellList()
    elseif message == "never" then
        ns.Core:MarkMouseoverNever()
    elseif message == "clear" then
        ns.Core:ClearRules()
    elseif message == "scan" or message == "preview" then
        ns.Core:RunAutoSellScan()
    elseif message == "config" or message == "settings" then
        ns.Core:OpenSettings()
    else
        ns.Utils:Print("Unknown command. Use /bt help.")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        ns.DB:Initialize()
        ns.Settings:Initialize()
        ns.ContextMenu:Initialize()
        if ns.MainWindow then
            ns.MainWindow:Create()
        end
        SLASH_BENTOOLS1 = "/bentools"
        SLASH_BENTOOLS2 = "/bt"
        SlashCmdList.BENTOOLS = SlashHandler
        ns.Utils:Print("Loaded. Use /bt or /bt help.")
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if ns.Merchant and ns.Utils:IsMerchantOpen() then
            ns.Merchant:Refresh()
        end
        if ns.Settings then
            ns.Settings:RefreshLists()
        end
        if ns.MainWindow then
            ns.MainWindow:Refresh()
        end
    end
end)
