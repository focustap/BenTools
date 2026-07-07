local addonName, ns = ...

ns.QueueRinger = {}

local frame = CreateFrame("Frame")
local BRIDGE_PREFIX = "[BenTools:QueueRinger]"
local POPUP_WIDTH = 320
local POPUP_HEIGHT = 92
local POPUP_BEACON_WIDTH = 132
local POPUP_BEACON_HEIGHT = 18
local BEACON_COLORS = {
    { 0.97, 0.45, 0.18 },
    { 0.14, 0.83, 0.93 },
    { 0.67, 0.33, 0.97 },
    { 0.99, 0.82, 0.25 },
    { 0.96, 0.29, 0.53 },
}

local function Debug(message)
    local config = ns.db and ns.db.queueRinger
    if config and config.debug then
        ns.Utils:Print(BRIDGE_PREFIX .. " " .. tostring(message))
    end
end

local function Print(message)
    ns.Utils:Print(BRIDGE_PREFIX .. " " .. tostring(message))
end

local function GetPlayerRealmName()
    local realm = _G.GetRealmName and _G.GetRealmName() or ""
    return realm or ""
end

local function GetCharacterName()
    local name = UnitName and UnitName("player") or UNKNOWNOBJECT
    return name or UNKNOWNOBJECT
end

local function GetUnixTime()
    if GetServerTime then
        return GetServerTime()
    end
    return time()
end

local function StartsWith(text, prefix)
    return type(text) == "string" and text:sub(1, #prefix) == prefix
end

local function ClearMatchingKeys(store, prefix)
    for key in pairs(store) do
        if StartsWith(key, prefix) then
            store[key] = nil
        end
    end
end

local function CreateLine(parent, layer, width, height, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetSize(width, height)
    texture:SetColorTexture(r, g, b, a or 1)
    return texture
end

function ns.QueueRinger:EnsureConfig()
    if not self.activeSignatures then
        self.activeSignatures = {}
    end

    local config = ns.db and ns.db.queueRinger
    if not config then
        return
    end

    if config.bridgeMethod ~= "SCREEN_BEACON" then
        config.bridgeMethod = "SCREEN_BEACON"
    end
    if config.popupDuration == nil then
        config.popupDuration = 20
    end
    if config.showPopup == nil then
        config.showPopup = true
    end
    if config.notifyPremade == nil then
        config.notifyPremade = true
    end
    if config.notifyReadyCheck == nil then
        config.notifyReadyCheck = true
    end
end

function ns.QueueRinger:EnsurePopup()
    if self.popup then
        return self.popup
    end

    local popup = CreateFrame("Frame", "BenToolsQueueRingerPopup", UIParent)
    popup:SetSize(POPUP_WIDTH, POPUP_HEIGHT)
    popup:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -120)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetToplevel(true)
    popup:SetFrameLevel(5000)
    popup:Hide()

    local bg = popup:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.06, 0.11, 0.94)
    popup.bg = bg

    local shadow = popup:CreateTexture(nil, "BORDER")
    shadow:SetPoint("TOPLEFT", -8, 8)
    shadow:SetPoint("BOTTOMRIGHT", 8, -8)
    shadow:SetColorTexture(0, 0, 0, 0.28)

    local borderTop = CreateLine(popup, "BORDER", POPUP_WIDTH, 1, 0.30, 0.33, 0.42, 1)
    borderTop:SetPoint("TOP")
    local borderBottom = CreateLine(popup, "BORDER", POPUP_WIDTH, 1, 0.30, 0.33, 0.42, 1)
    borderBottom:SetPoint("BOTTOM")
    local borderLeft = CreateLine(popup, "BORDER", 1, POPUP_HEIGHT, 0.30, 0.33, 0.42, 1)
    borderLeft:SetPoint("LEFT")
    local borderRight = CreateLine(popup, "BORDER", 1, POPUP_HEIGHT, 0.30, 0.33, 0.42, 1)
    borderRight:SetPoint("RIGHT")

    local glow = popup:CreateTexture(nil, "ARTWORK")
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(0.10, 0.67, 0.95, 0.10)
    popup.glow = glow

    local topAccent = CreateLine(popup, "ARTWORK", POPUP_WIDTH - 2, 3, 0.10, 0.67, 0.95, 0.85)
    topAccent:SetPoint("TOP", 0, -1)
    local bottomAccent = CreateLine(popup, "ARTWORK", POPUP_WIDTH - 2, 2, 0.96, 0.29, 0.53, 0.80)
    bottomAccent:SetPoint("BOTTOM", 0, 1)

    local beaconFrame = CreateFrame("Frame", nil, popup)
    beaconFrame:SetSize(POPUP_BEACON_WIDTH, POPUP_BEACON_HEIGHT)
    beaconFrame:SetPoint("TOPLEFT", 18, -16)

    local beaconBg = beaconFrame:CreateTexture(nil, "BACKGROUND")
    beaconBg:SetAllPoints()
    beaconBg:SetColorTexture(0.02, 0.03, 0.06, 1)

    local blockWidth = 20
    local spacing = 4
    for index, color in ipairs(BEACON_COLORS) do
        local block = beaconFrame:CreateTexture(nil, "ARTWORK")
        block:SetSize(blockWidth, 10)
        block:SetPoint("LEFT", (index - 1) * (blockWidth + spacing) + 8, 0)
        block:SetColorTexture(color[1], color[2], color[3], 1)
    end

    local tag = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tag:SetPoint("TOPLEFT", beaconFrame, "BOTTOMLEFT", 0, -6)
    tag:SetTextColor(0.69, 0.78, 0.95)
    tag:SetText("BENTOOLS QUEUE RINGER")
    popup.tag = tag

    local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -42)
    title:SetPoint("TOPRIGHT", -18, -42)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1.0, 0.93, 0.70)
    popup.title = title

    local queueType = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    queueType:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    queueType:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -8)
    queueType:SetJustifyH("LEFT")
    queueType:SetTextColor(0.95, 0.97, 1.0)
    popup.queueType = queueType

    local subtitle = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("BOTTOMLEFT", 18, 12)
    subtitle:SetPoint("BOTTOMRIGHT", -18, 12)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.70, 0.76, 0.88)
    popup.subtitle = subtitle

    popup:SetScript("OnUpdate", function(self)
        local pulse = 0.12 + (math.sin(GetTime() * 4.0) + 1) * 0.09
        self.glow:SetAlpha(pulse)
    end)

    self.popup = popup
    return popup
end

function ns.QueueRinger:BuildEvent(queueType, source, isTest)
    local config = ns.db.queueRinger
    config.lastEventSerial = (tonumber(config.lastEventSerial) or 0) + 1

    local now = GetUnixTime()
    local eventId = string.format("%d-%d", now, config.lastEventSerial)
    local eventData = {
        eventId = eventId,
        event = "QUEUE_READY",
        queueType = queueType or "Unknown Queue",
        character = GetCharacterName(),
        realm = GetPlayerRealmName(),
        timestamp = now,
        source = source or "UNKNOWN",
        status = "READY",
        test = isTest and true or false,
    }

    config.lastEventId = eventData.eventId
    config.lastQueueType = eventData.queueType
    config.lastEventAt = eventData.timestamp
    return eventData
end

function ns.QueueRinger:ShowPopup(eventData)
    local config = ns.db and ns.db.queueRinger
    if not config or config.showPopup == false then
        return false
    end

    local popup = self:EnsurePopup()
    local title = eventData.test and "Queue Ringer Test" or "Queue Ready"
    local subtitle = eventData.test and "Desktop companion should detect this banner." or "Your queue is ready. Jump back in."

    if eventData.source == "READY_CHECK" then
        title = "Ready Check"
        subtitle = "Your party or raid is waiting on you."
    end

    popup.title:SetText(title)
    popup.queueType:SetText(eventData.queueType or "Unknown Queue")
    popup.subtitle:SetText(subtitle)
    popup:Show()

    self.popupHideToken = (self.popupHideToken or 0) + 1
    local hideToken = self.popupHideToken
    local duration = math.max(5, tonumber(config.popupDuration) or 20)

    if C_Timer and C_Timer.After then
        C_Timer.After(duration, function()
            if ns.QueueRinger.popupHideToken == hideToken and ns.QueueRinger.popup then
                ns.QueueRinger.popup:Hide()
            end
        end)
    end

    return true
end

function ns.QueueRinger:HandleReadyCheck(initiatorName)
    local config = ns.db and ns.db.queueRinger
    if not config or not config.enabled or not config.notifyReadyCheck then
        return
    end

    self:EnsureConfig()

    local label = initiatorName and initiatorName ~= "" and initiatorName or "Party or Raid"
    local queueType = "Ready Check: " .. label
    local signature = string.format("readycheck:%s", tostring(label))
    Debug("READY_CHECK from " .. label)
    self:NotifyReady(signature, queueType, "READY_CHECK", false)
end

function ns.QueueRinger:HandleReadyCheckFinished()
    self:EnsureConfig()
    ClearMatchingKeys(self.activeSignatures, "readycheck:")
end

function ns.QueueRinger:NotifyReady(signature, queueType, source, isTest)
    local config = ns.db and ns.db.queueRinger
    if not config or not config.enabled then
        return false
    end

    self:EnsureConfig()
    if signature and self.activeSignatures[signature] then
        Debug("Duplicate queue event ignored for " .. signature)
        return false
    end

    if signature then
        self.activeSignatures[signature] = true
    end

    local eventData = self:BuildEvent(queueType, source, isTest)
    local shown = self:ShowPopup(eventData)
    if shown then
        Print("Queue banner shown for " .. eventData.queueType .. ".")
    else
        Print("Queue event detected, but popup banners are disabled.")
    end
    return shown
end

function ns.QueueRinger:CreateTestEvent()
    local config = ns.db and ns.db.queueRinger
    if not config or not config.enabled then
        Print("Queue Ringer is disabled.")
        return
    end

    local queueType = "Queue Ringer Test"
    self:NotifyReady("test:" .. GetUnixTime(), queueType, "TEST", true)
end

function ns.QueueRinger:HandleProposalShow()
    local config = ns.db and ns.db.queueRinger
    if not config or not config.enabled or not config.notifyLFG or not GetLFGProposal then
        return
    end

    local proposalExists, proposalID, proposalTypeID, subtypeID, queueName = GetLFGProposal()
    if not proposalExists then
        return
    end

    if self.currentLFGProposalID and self.currentLFGProposalID ~= proposalID then
        ClearMatchingKeys(self.activeSignatures, "lfg:")
    end

    local queueType = queueName or "Dungeon/Raid Finder"
    local signature = string.format("lfg:%s:%s:%s:%s", tostring(proposalID), tostring(proposalTypeID), tostring(subtypeID), tostring(queueType))
    if self.currentLFGProposalID == proposalID and self.activeSignatures[signature] then
        Debug("Duplicate LFG proposal ignored for proposalID " .. tostring(proposalID))
        return
    end

    self.currentLFGProposalID = proposalID
    Debug("State transition WAITING -> READY for " .. queueType)
    self:NotifyReady(signature, queueType, "LFG_PROPOSAL_SHOW", false)
end

function ns.QueueRinger:HandleProposalClosed()
    self:EnsureConfig()
    ClearMatchingKeys(self.activeSignatures, "lfg:")
    self.currentLFGProposalID = nil
end

function ns.QueueRinger:HandleBattlefieldStatus()
    local config = ns.db and ns.db.queueRinger
    if not config or not config.enabled or not config.notifyPvP or not GetBattlefieldStatus then
        return
    end

    self:EnsureConfig()

    local maxQueues = GetMaxBattlefieldID and GetMaxBattlefieldID() or 2
    for queueID = 1, maxQueues do
        local status, queueName = GetBattlefieldStatus(queueID)
        if status == "confirm" then
            local queueType = queueName or "PvP Queue"
            local expiration = GetBattlefieldPortExpiration and GetBattlefieldPortExpiration(queueID) or 0
            local signature = string.format("pvp:%d:%s:%s", queueID, tostring(queueType), tostring(expiration))
            Debug("State transition WAITING -> READY for " .. queueType)
            self:NotifyReady(signature, queueType, "UPDATE_BATTLEFIELD_STATUS", false)
        else
            ClearMatchingKeys(self.activeSignatures, "pvp:" .. tostring(queueID) .. ":")
        end
    end
end

function ns.QueueRinger:HandlePremadeApplicationStatus(searchResultID, newStatus, oldStatus, groupName)
    local config = ns.db and ns.db.queueRinger
    if not config or not config.enabled or not config.notifyPremade then
        return
    end

    self:EnsureConfig()

    if newStatus == "invited" then
        local label = groupName
        if not label or label == "" then
            label = "Premade Group"
        end

        local queueType = "Premade Invite: " .. label
        local signature = string.format("premade:%s:%s:%s", tostring(searchResultID), tostring(newStatus), tostring(label))
        Debug("Premade application status " .. tostring(oldStatus) .. " -> " .. tostring(newStatus) .. " for " .. label)
        self:NotifyReady(signature, queueType, "LFG_LIST_APPLICATION_STATUS_UPDATED", false)
    elseif oldStatus == "invited" or newStatus == "inviteaccepted" or newStatus == "invitedeclined" or newStatus == "cancelled" or newStatus == "declined" then
        ClearMatchingKeys(self.activeSignatures, "premade:" .. tostring(searchResultID) .. ":")
    end
end

function ns.QueueRinger:PrintStatus()
    local config = ns.db and ns.db.queueRinger
    if not config then
        Print("Queue Ringer has not been initialized yet.")
        return
    end

    self:EnsureConfig()

    Print("Enabled: " .. (config.enabled and "yes" or "no"))
    Print("Bridge: " .. tostring(config.bridgeMethod or "unknown"))
    Print("Premade invites: " .. (config.notifyPremade and "on" or "off"))
    Print("Ready checks: " .. (config.notifyReadyCheck and "on" or "off"))
    Print("Popup banner: " .. (config.showPopup == false and "off" or "on"))
    Print("Popup visible: " .. ((self.popup and self.popup:IsShown()) and "yes" or "no"))
    Print("Last event ID: " .. (config.lastEventId ~= "" and config.lastEventId or "none"))
    Print("Last queue type: " .. (config.lastQueueType ~= "" and config.lastQueueType or "none"))
    Print("Debug: " .. (config.debug and "on" or "off"))
end

function ns.QueueRinger:PrintHelp()
    Print("/bt queue - Show Queue Ringer status")
    Print("/bt queue status - Show module and bridge state")
    Print("/bt queue test - Show a local Queue Ringer test banner")
    Print("/bt queue on - Enable Queue Ringer")
    Print("/bt queue off - Disable Queue Ringer")
    Print("/bt queue debug - Toggle Queue Ringer debug logging")
end

function ns.QueueRinger:SetEnabled(enabled)
    local config = ns.db and ns.db.queueRinger
    if not config then
        return
    end

    config.enabled = enabled and true or false
    if not config.enabled and self.popup then
        self.popup:Hide()
    end
    Print("Queue Ringer " .. (config.enabled and "enabled." or "disabled."))
end

function ns.QueueRinger:ToggleDebug()
    local config = ns.db and ns.db.queueRinger
    if not config then
        return
    end

    config.debug = not config.debug
    Print("Queue Ringer debug " .. (config.debug and "enabled." or "disabled."))
end

function ns.QueueRinger:HandleSlash(message)
    local config = ns.db and ns.db.queueRinger
    if not config then
        return
    end

    message = (message or ""):match("^%s*(.-)%s*$"):lower()
    if message == "" or message == "status" then
        self:PrintStatus()
    elseif message == "help" then
        self:PrintHelp()
    elseif message == "test" or message == "preview" then
        self:CreateTestEvent()
    elseif message == "on" then
        self:SetEnabled(true)
    elseif message == "off" then
        self:SetEnabled(false)
    elseif message == "debug" then
        self:ToggleDebug()
    else
        self:PrintHelp()
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("LFG_PROPOSAL_SHOW")
frame:RegisterEvent("LFG_PROPOSAL_FAILED")
frame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
frame:RegisterEvent("READY_CHECK")
frame:RegisterEvent("READY_CHECK_FINISHED")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        ns.QueueRinger:EnsureConfig()
        ns.QueueRinger:EnsurePopup()
    elseif event == "LFG_PROPOSAL_SHOW" then
        Debug("LFG_PROPOSAL_SHOW")
        ns.QueueRinger:HandleProposalShow()
    elseif event == "LFG_PROPOSAL_FAILED" or event == "LFG_PROPOSAL_SUCCEEDED" then
        Debug(event)
        ns.QueueRinger:HandleProposalClosed()
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local searchResultID, newStatus, oldStatus, groupName = ...
        Debug("LFG_LIST_APPLICATION_STATUS_UPDATED " .. tostring(oldStatus) .. " -> " .. tostring(newStatus) .. " (" .. tostring(groupName) .. ")")
        ns.QueueRinger:HandlePremadeApplicationStatus(searchResultID, newStatus, oldStatus, groupName)
    elseif event == "READY_CHECK" then
        local initiatorName = ...
        ns.QueueRinger:HandleReadyCheck(initiatorName)
    elseif event == "READY_CHECK_FINISHED" then
        ns.QueueRinger:HandleReadyCheckFinished()
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        Debug("UPDATE_BATTLEFIELD_STATUS")
        ns.QueueRinger:HandleBattlefieldStatus()
    end
end)
