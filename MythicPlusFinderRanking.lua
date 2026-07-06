local addonName, ns = ...

ns.MythicPlusFinderRanking = {}

local ranking = ns.MythicPlusFinderRanking
local filtersAPI = ns.MythicPlusFinderFilters
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }

ranking.DEFAULT_WEIGHTS = {
    selectedRoleOpen = 24,
    requiredRolePresent = 16,
    preferredRolePresent = 8,
    preferredKeyRange = 14,
    allowedKeyRange = 4,
    nearFullGroup = 12,
    strongLeader = 12,
    freshListing = 10,
    exactPartyFit = 6,
}

local function AddReason(reasons, points, text)
    table.insert(reasons, {
        points = points,
        text = text,
    })
end

function ranking:Evaluate(result, filters)
    local weights = self.DEFAULT_WEIGHTS
    local score = 0
    local reasons = {}
    local selectedRole = filtersAPI:GetSelectedRole(filters)

    if (result.openSlots[selectedRole] or 0) > 0 then
        score = score + weights.selectedRoleOpen
        AddReason(reasons, weights.selectedRoleOpen, filtersAPI:GetRoleLabel(selectedRole) .. " slot is open")
    end

    for _, role in ipairs(ROLE_ORDER) do
        if role ~= selectedRole then
            local state = filtersAPI:GetRoleState(filters, role)
            local count = result.roleCounts[role] or 0
            if state == "REQUIRED" and count > 0 then
                score = score + weights.requiredRolePresent
                AddReason(reasons, weights.requiredRolePresent, filtersAPI:GetRoleLabel(role) .. " already present")
            elseif state == "PREFERRED" and count > 0 then
                score = score + weights.preferredRolePresent
                AddReason(reasons, weights.preferredRolePresent, filtersAPI:GetRoleLabel(role) .. " present")
            end
        end
    end

    if result.keyLevel then
        if result.keyLevel >= filters.preferredMin and result.keyLevel <= filters.preferredMax then
            score = score + weights.preferredKeyRange
            AddReason(reasons, weights.preferredKeyRange, "Key level is in preferred range")
        else
            score = score + weights.allowedKeyRange
            AddReason(reasons, weights.allowedKeyRange, "Key level is in allowed range")
        end
    else
        AddReason(reasons, 0, "Key level is hidden by the client")
    end

    if filters.preferFullGroups and result.numMembers >= 4 then
        score = score + weights.nearFullGroup
        AddReason(reasons, weights.nearFullGroup, "Group is nearly full")
    elseif filters.preferFullGroups and result.numMembers >= 3 then
        local partial = math.floor(weights.nearFullGroup / 2)
        score = score + partial
        AddReason(reasons, partial, "Group is filling up")
    end

    if filters.preferStrongerLeader and result.leaderScore > 0 then
        local leaderBonus = math.min(weights.strongLeader, math.floor(result.leaderScore / 250))
        if leaderBonus > 0 then
            score = score + leaderBonus
            AddReason(reasons, leaderBonus, "Leader score is strong")
        end
    end

    if filters.preferFresh and result.ageSeconds <= 180 then
        score = score + weights.freshListing
        AddReason(reasons, weights.freshListing, "Listing is fresh")
    elseif filters.preferFresh and result.ageSeconds <= 420 then
        local freshPartial = math.floor(weights.freshListing / 2)
        score = score + freshPartial
        AddReason(reasons, freshPartial, "Listing is reasonably fresh")
    end

    if result.openSlotsTotal == filtersAPI:GetPartySize() then
        score = score + weights.exactPartyFit
        AddReason(reasons, weights.exactPartyFit, "Open slots fit your party size exactly")
    end

    if result.applicationLocked then
        AddReason(reasons, 0, "Already applied")
    end

    return {
        eligible = true,
        score = score,
        reasons = reasons,
    }
end
