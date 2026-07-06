local addonName, ns = ...

ns.MythicPlusFinderApplications = {}

local applications = ns.MythicPlusFinderApplications

local function GetNow()
    if GetServerTime then
        return GetServerTime()
    end
    return time()
end

function applications:Refresh()
    local finder = ns.MythicPlusFinder
    if not finder then
        return
    end

    finder.applicationStates = finder.applicationStates or {}
    finder.activeApplications = {}

    local seen = {}
    for _, resultID in ipairs((C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplications()) or {}) do
        seen[resultID] = true
        local searchInfo = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(resultID)
        local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo and C_LFGList.GetApplicationInfo(resultID)
        local state = finder.applicationStates[resultID] or {
            firstSeenAt = GetNow(),
        }

        state.resultID = resultID
        state.updatedAt = GetNow()
        state.status = appStatus or state.status or "unknown"
        state.pendingStatus = pendingStatus
        state.groupName = searchInfo and (searchInfo.name or searchInfo.leaderName) or state.groupName
        state.isDelisted = searchInfo and searchInfo.isDelisted or false

        finder.applicationStates[resultID] = state

        if state.status == "applied" or state.status == "invited" or pendingStatus then
            table.insert(finder.activeApplications, state)
        end
    end

    for resultID, state in pairs(finder.applicationStates) do
        if not seen[resultID] and (state.status == "applied" or state.status == "invited" or state.pendingStatus) then
            state.status = "expired"
            state.pendingStatus = nil
            state.updatedAt = GetNow()
        end
    end

    table.sort(finder.activeApplications, function(left, right)
        return (left.updatedAt or 0) > (right.updatedAt or 0)
    end)
end

function applications:GetState(resultID)
    local finder = ns.MythicPlusFinder
    return finder and finder.applicationStates and finder.applicationStates[resultID]
end

function applications:GetStatusText(state)
    if not state then
        return "Not applied"
    end
    if state.pendingStatus then
        return "Pending: " .. tostring(state.pendingStatus)
    end
    local labels = {
        requested = "Requested",
        applied = "Applied",
        invited = "Invited",
        declined = "Declined",
        cancelled = "Cancelled",
        inviteaccepted = "Invite accepted",
        invitedeclined = "Invite declined",
        expired = "Expired",
    }
    return labels[state.status] or tostring(state.status or "Unknown")
end

function applications:GetNextEligiblePlanEntry()
    local finder = ns.MythicPlusFinder
    if not finder then
        return nil
    end

    for _, result in ipairs(finder.recommendedResults or {}) do
        if not result.applicationLocked then
            local state = self:GetState(result.resultID)
            if not state or (state.status ~= "applied" and state.status ~= "invited" and not state.pendingStatus) then
                return result
            end
        end
    end
    return nil
end

function applications:ApplyNextBest()
    local entry = self:GetNextEligiblePlanEntry()
    if not entry then
        ns.Utils:Print("[M+] No more eligible recommendations in the current result set.")
        return false
    end
    return ns.MythicPlusFinder:ApplyToResult(entry.resultID)
end
