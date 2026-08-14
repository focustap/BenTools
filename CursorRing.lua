local addonName, ns = ...

ns.CursorRing = {}

local RING_SIZE = 40
local TEXTURE_PATH = "Interface\\Minimap\\Ping\\ping4"

function ns.CursorRing:UpdatePosition()
    if not self.frame then
        return
    end

    local x, y = GetCursorPosition()
    if not x or not y or (x == 0 and y == 0) then
        self.frame:Hide()
        return
    end

    local scale = UIParent:GetEffectiveScale()
    x = x / scale
    y = y / scale

    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x - (RING_SIZE / 2), y - (RING_SIZE / 2))
    self.frame:Show()
end

function ns.CursorRing:Refresh()
    if not self.frame then
        return
    end

    local enabled = ns.db and ns.db.profile and ns.db.profile.cursorRingEnabled
    if enabled then
        self.frame:SetScript("OnUpdate", function()
            ns.CursorRing:UpdatePosition()
        end)
        self:UpdatePosition()
    else
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
end

function ns.CursorRing:SetEnabled(enabled)
    if not ns.db or not ns.db.profile then
        return
    end

    ns.db.profile.cursorRingEnabled = enabled and true or false
    self:Refresh()
    ns.Utils:Print("Cursor ring " .. (ns.db.profile.cursorRingEnabled and "enabled." or "disabled."))
end

function ns.CursorRing:Toggle()
    self:SetEnabled(not (ns.db and ns.db.profile and ns.db.profile.cursorRingEnabled))
end

function ns.CursorRing:Initialize()
    if self.frame then
        self:Refresh()
        return
    end

    local frame = CreateFrame("Frame", "BenToolsCursorRingFrame", UIParent)
    frame:SetSize(RING_SIZE, RING_SIZE)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetToplevel(true)
    frame:EnableMouse(false)
    frame:Hide()

    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetTexture(TEXTURE_PATH)
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(1, 0.82, 0.1, 0.9)

    self.frame = frame
    self.texture = texture
    self:Refresh()
end
