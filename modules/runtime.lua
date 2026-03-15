local _, ns = ...

local Runtime = {}
ns.Runtime = Runtime

local function UpdateRuntime()
    if Runtime.isInEditMode or Runtime.hasSettingsOpened then
        Runtime.stop = true
    else
        Runtime.stop = false
    end
end

Runtime.stop = false
Runtime.isInEditMode = false
Runtime.hasSettingsOpened = false
Runtime.clientSceneActive = false

local viewers = {
    ["BuffIconCooldownViewer"] = BuffIconCooldownViewer,
    ["BuffBarCooldownViewer"] = BuffBarCooldownViewer,
    ["EssentialCooldownViewer"] = EssentialCooldownViewer,
    ["UtilityCooldownViewer"] = UtilityCooldownViewer,
}

function Runtime:IsReady(viewerNameOrFrame)
    local viewer = nil
    if type(viewerNameOrFrame) == "string" then
        viewer = _G[viewerNameOrFrame]
    elseif type(viewerNameOrFrame) == "table" then
        viewer = viewerNameOrFrame
    end
    if not viewer or not viewer.IsInitialized or not EditModeManagerFrame then
        return false
    end

    if EditModeManagerFrame.layoutApplyInProgress or not viewer:IsInitialized() then
        return false
    end

    return true
end

function Runtime:IsAllReady()
    for _, viewer in pairs(viewers) do
        if not self:IsReady(viewer) then
            return false
        end
    end
    return true
end

function Runtime:ShowAll()
    if C_CVar.GetCVar("cooldownViewerEnabled") ~= "1" then
        return
    end
    for _, viewer in pairs(viewers) do
        if viewer then
            local visibleSetting = viewer.visibleSetting
            local forceShow = false
            if visibleSetting == Enum.CooldownViewerVisibleSetting.Always then
                forceShow = true
            elseif visibleSetting == Enum.CooldownViewerVisibleSetting.InCombat then
                forceShow = InCombatLockdown()
            elseif visibleSetting == Enum.CooldownViewerVisibleSetting.Hidden then
                -- Don't show
            end
            if not viewer:IsShown() and forceShow then
                ShowUIPanel(viewer)
            end
        end
    end
end

EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
    if not Runtime:IsAllReady() then
        return
    end
    C_Timer.After(0, function()
        if ns.CooldownStyle then
            ns.CooldownStyle:RefreshHooks()
        end
        Runtime:MarkDirty()
    end)
end)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function(arg1, settingsFrame)
    Runtime.hasSettingsOpened = true
    UpdateRuntime()
    if ns.MiscPanel then
        ns.MiscPanel:EnsureMiscSettingsTab(settingsFrame)
        ns.MiscPanel:RefreshMiscPanel(settingsFrame)
    end
end)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
    Runtime.hasSettingsOpened = false
    UpdateRuntime()
    if not Runtime:IsAllReady() then
        return
    end
    Runtime:MarkDirty()
end)
EventRegistry:RegisterCallback("EditMode.Enter", function()
    Runtime.isInEditMode = true
    UpdateRuntime()
    if not Runtime:IsAllReady() then
        return
    end
    Runtime:MarkDirty()
end)

EventRegistry:RegisterCallback("EditMode.Exit", function()
    Runtime.isInEditMode = false
    UpdateRuntime()
    if not Runtime:IsAllReady() then
        return
    end
    Runtime:MarkDirty()
end)
local EventHandler = {}
EventHandler.events = {}
EventHandler.frame = CreateFrame("FRAME")

EventHandler.events["PLAYER_ENTERING_WORLD"] = function(self, event, ...)
    -- print("Player Entering World")
    if not Runtime:IsAllReady() then
        return
    end
    Runtime:ShowAll()

    -- C_Timer.After(0, function()
    --     if ns.StyledIcons then
    --         ns.StyledIcons:RefreshAll()
    --     end

    --     if ns.CooldownManager then
    --         ns.CooldownManager.ForceRefreshAll()
    --     end
    --     C_Timer.After(0, function()
    --         if ns.CooldownManager then
    --             ns.CooldownManager.ForceRefreshAll()
    --         end
    --     end)
    -- end)
end

-- EventHandler.events["EDIT_MODE_LAYOUTS_UPDATED"] = function(self, event, ...)
-- print("Edit Mode Layouts Updated")
-- if not Runtime:IsAllReady() then
--     return
-- end
-- C_Timer.After(0, function()
--     if ns.StyledIcons then
--         ns.StyledIcons:RefreshAll()
--     end

--     if ns.CooldownManager then
--         ns.CooldownManager.ForceRefreshAll()
--     end
-- end)
-- end

-- EventHandler.events["TRAIT_CONFIG_UPDATED"] = function(self, event, ...)
--     print("Trait Config Updated")
-- if not Runtime:IsAllReady() then
--     return
-- end
-- C_Timer.After(0, function()
--     if ns.StyledIcons then
--         ns.StyledIcons:RefreshAll()
--     end

--     if ns.CooldownManager then
--         ns.CooldownManager.ForceRefreshAll()
--     end
-- end)
-- end
-- EventHandler.events["PLAYER_SPECIALIZATION_CHANGED"] = function(self, event, ...)
-- print("Player Specialization Changed")
-- if not Runtime:IsAllReady() then
--     return
-- end
-- if ns.StyledIcons then
--     ns.StyledIcons:RefreshAll()
-- end

-- if ns.CooldownManager then
--     ns.CooldownManager.ForceRefreshAll()
-- end
-- end
EventHandler.events["UPDATE_SHAPESHIFT_FORM"] = function(self, event, ...)
    if not Runtime:IsAllReady() then
        return
    end
    Runtime:MarkDirty()
end

EventHandler.events["PLAYER_REGEN_DISABLED"] = function(self, event, ...)
    if not Runtime:IsAllReady() then
        return
    end
    Runtime:MarkDirty()
end

EventHandler.events["PLAYER_REGEN_ENABLED"] = function(self, event, ...)
    if not Runtime:IsAllReady() then
        return
    end
    Runtime:MarkDirty()
end

EventHandler.events["SPELL_UPDATE_COOLDOWN"] = function(self, event, spellId)
    if not Runtime:IsAllReady() then
        return
    end

    if ns.CooldownManager then
        ns.CooldownManager.UpdateUtilityDimming()
    end
end
C_Timer.NewTicker(1, function()
    if not Runtime:IsAllReady() then
        return
    end

    if ns.CooldownManager then
        ns.CooldownManager.UpdateUtilityDimming()
    end
end)

EventHandler.events["CLIENT_SCENE_OPENED"] = function(self, event, ...)
    local sceneType = ...
    Runtime.clientSceneActive = (sceneType == 1)
end
EventHandler.events["CLIENT_SCENE_CLOSED"] = function(self, event, ...)
    Runtime.clientSceneActive = false
end

for event, handler in pairs(EventHandler.events) do
    EventHandler.frame:RegisterEvent(event)
end

EventHandler.frame:SetScript("OnEvent", function(self, event, ...)
    EventHandler.events[event](self, event, ...)
end)

-- Use a periodic ticker to detect layout changes instead of hooksecurefunc,
-- which would taint the secure execution path.
Runtime._dirty = { icons = true, bars = true, essential = true, utility = true }
Runtime._lastLayoutSerial = {}

local viewerChecks = {
    { viewer = BuffIconCooldownViewer, key = "icons", styledKey = "BuffIcons", viewerName = "BuffIconCooldownViewer" },
    { viewer = BuffBarCooldownViewer, key = "bars" },
    { viewer = EssentialCooldownViewer, key = "essential", styledKey = "Essential", viewerName = "EssentialCooldownViewer" },
    { viewer = UtilityCooldownViewer, key = "utility", styledKey = "Utility", viewerName = "UtilityCooldownViewer" },
}

local function GetViewerLayoutSerial(viewer)
    if not viewer or not viewer.GetChildren then return 0 end
    local children = { viewer:GetChildren() }
    local count = 0
    for _, child in ipairs(children) do
        if child:IsShown() then
            count = count + 1
        end
    end
    local w = math.floor((viewer:GetWidth() or 0) * 10)
    local h = math.floor((viewer:GetHeight() or 0) * 10)
    return count * 100000 + w * 100 + h
end

local function CheckAndApplyUpdates()
    if not Runtime:IsAllReady() or Runtime.hasSettingsOpened or InCombatLockdown() then
        return
    end

    for _, info in ipairs(viewerChecks) do
        local serial = GetViewerLayoutSerial(info.viewer)
        local changed = serial ~= (Runtime._lastLayoutSerial[info.key] or -1)

        if changed or Runtime._dirty[info.key] then
            Runtime._lastLayoutSerial[info.key] = serial
            Runtime._dirty[info.key] = false

            if Runtime:IsReady(info.viewer) then
                if info.styledKey then
                    if ns.StyledIcons then ns.StyledIcons:RefreshViewer(info.styledKey) end
                    if ns.CooldownFont then ns.CooldownFont:RefreshViewer(info.viewerName) end
                    if ns.Swipe then ns.Swipe:RefreshViewer(info.viewerName) end
                end
                if ns.CooldownManager then
                    ns.CooldownManager.ForceRefresh({ [info.key] = true })
                end
            end
        end
    end
end

function Runtime:MarkDirty()
    for key in pairs(self._dirty) do
        self._dirty[key] = true
    end
end

C_Timer.NewTicker(0.2, CheckAndApplyUpdates)
