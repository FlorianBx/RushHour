local ADDON_NAME = "RushHour"
local DEFAULT_TARGET_LEVEL = 90

local defaults = {
    triggerQuestID = nil,
    elapsedTime = 0,
    sessionStart = nil,
    hardcoreStartTime = nil,
    isRunning = false,
    isCompleted = false,
    isMinimized = false,
    mode = "casu",
    targetLevel = DEFAULT_TARGET_LEVEL,
    framePosition = nil
}

local RushHourFrame = nil

local function FormatTime(seconds)
    if not seconds or seconds < 0 then
        return "0s"
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if days > 0 then
        return string.format("%dj %dh %dm", days, hours, minutes)
    elseif hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, secs)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

local function Print(msg)
    print("|cff00ccff[RushHour]|r " .. msg)
end

local function GetElapsedTime()
    if RushHourDB.mode == "hardcore" then
        if not RushHourDB.hardcoreStartTime then
            return nil
        end
        if RushHourDB.isCompleted then
            return RushHourDB.elapsedTime
        end
        return time() - RushHourDB.hardcoreStartTime
    else
        if RushHourDB.elapsedTime == 0 and not RushHourDB.sessionStart then
            return nil
        end
        local sessionTime = 0
        if RushHourDB.isRunning and RushHourDB.sessionStart then
            sessionTime = time() - RushHourDB.sessionStart
        end
        return RushHourDB.elapsedTime + sessionTime
    end
end

local function SaveSessionTime()
    if RushHourDB.mode == "casu" and RushHourDB.isRunning and RushHourDB.sessionStart then
        RushHourDB.elapsedTime = RushHourDB.elapsedTime + (time() - RushHourDB.sessionStart)
        RushHourDB.sessionStart = nil
    end
end

local function ResumeSession()
    if RushHourDB.mode == "casu" and RushHourDB.isRunning and not RushHourDB.sessionStart then
        RushHourDB.sessionStart = time()
    end
end

local function UpdateTimerDisplay()
    if not RushHourFrame or not RushHourFrame.timerText then return end

    local elapsed = GetElapsedTime()
    if elapsed then
        RushHourFrame.timerText:SetText("Timer: " .. FormatTime(elapsed))
    else
        RushHourFrame.timerText:SetText("Timer: --")
    end
end

local function UpdateModeButtons()
    if not RushHourFrame then return end

    local green = {0, 1, 0}
    local white = {1, 1, 1}

    if RushHourDB.mode == "casu" then
        RushHourFrame.casuBtn:GetFontString():SetTextColor(unpack(green))
        RushHourFrame.hardcoreBtn:GetFontString():SetTextColor(unpack(white))
    else
        RushHourFrame.casuBtn:GetFontString():SetTextColor(unpack(white))
        RushHourFrame.hardcoreBtn:GetFontString():SetTextColor(unpack(green))
    end
end

local function CheckLevelReached()
    local currentLevel = UnitLevel("player")
    if RushHourDB.isRunning and currentLevel >= RushHourDB.targetLevel then
        if RushHourDB.mode == "hardcore" then
            RushHourDB.elapsedTime = time() - RushHourDB.hardcoreStartTime
        else
            SaveSessionTime()
        end
        RushHourDB.isRunning = false
        RushHourDB.isCompleted = true
        local elapsed = GetElapsedTime()
        Print("Félicitations! Niveau " .. RushHourDB.targetLevel .. " atteint!")
        Print("Temps total: " .. FormatTime(elapsed))
        UpdateTimerDisplay()
        return true
    end
    return false
end

local function StartTimer(fromQuest)
    if RushHourDB.isRunning then
        Print("Timer déjà en cours!")
        return
    end

    if not fromQuest and not RushHourDB.triggerQuestID then
        Print("Configure d'abord une Quest ID!")
        return
    end

    local currentLevel = UnitLevel("player")
    if currentLevel >= RushHourDB.targetLevel then
        Print("Niveau cible déjà atteint! (" .. currentLevel .. "/" .. RushHourDB.targetLevel .. ")")
        return
    end

    RushHourDB.elapsedTime = 0
    RushHourDB.hardcoreStartTime = time()
    RushHourDB.sessionStart = time()
    RushHourDB.isRunning = true
    RushHourDB.isCompleted = false

    local modeText = RushHourDB.mode == "hardcore" and "Hardcore" or "Casu"
    Print("Timer démarré! Mode: " .. modeText .. " | Objectif: niveau " .. RushHourDB.targetLevel)
    UpdateTimerDisplay()
end

local function StopTimer()
    if not RushHourDB.isRunning then
        Print("Aucun timer en cours.")
        return
    end

    SaveSessionTime()
    RushHourDB.isRunning = false
    local elapsed = GetElapsedTime()
    Print("Timer en pause. Temps: " .. FormatTime(elapsed))
    UpdateTimerDisplay()
end

local function ResetTimer()
    RushHourDB.elapsedTime = 0
    RushHourDB.sessionStart = nil
    RushHourDB.hardcoreStartTime = nil
    RushHourDB.isRunning = false
    RushHourDB.isCompleted = false
    Print("Timer remis à zéro.")
    UpdateTimerDisplay()
end

local function SetMode(mode)
    if RushHourDB.isRunning then
        Print("Impossible de changer de mode pendant un timer!")
        return
    end
    RushHourDB.mode = mode
    UpdateModeButtons()
    Print("Mode: " .. (mode == "hardcore" and "Hardcore (temps réel)" or "Casu (temps de jeu)"))
end

local function SetMinimized(minimized)
    if not RushHourFrame then return end

    RushHourDB.isMinimized = minimized

    if minimized then
        RushHourFrame:SetSize(180, 70)
        RushHourFrame.timerText:ClearAllPoints()
        RushHourFrame.timerText:SetPoint("CENTER", RushHourFrame, "CENTER", 0, -5)

        for _, element in ipairs(RushHourFrame.fullViewElements) do
            element:Hide()
        end
        RushHourFrame.minimizeBtn.text:SetText("+")
    else
        RushHourFrame:SetSize(280, 230)
        RushHourFrame.timerText:ClearAllPoints()
        RushHourFrame.timerText:SetPoint("TOPLEFT", RushHourFrame.separator, "BOTTOMLEFT", 5, -15)

        for _, element in ipairs(RushHourFrame.fullViewElements) do
            element:Show()
        end
        RushHourFrame.minimizeBtn.text:SetText("-")
    end
end

local function ToggleMinimize()
    SetMinimized(not RushHourDB.isMinimized)
end

local function CreateConfigFrame()
    if RushHourFrame then return RushHourFrame end

    local frame = CreateFrame("Frame", "RushHourConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(280, 230)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        RushHourDB.framePosition = { x = x, y = y }
    end)
    frame:SetClampedToScreen(true)

    frame.TitleBg:SetHeight(30)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOPLEFT", frame.TitleBg, "TOPLEFT", 5, -3)
    frame.title:SetText("RushHour")

    local minimizeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    minimizeBtn:SetSize(24, 24)
    minimizeBtn:SetPoint("RIGHT", frame.CloseButton, "LEFT", 4, 0)
    minimizeBtn:SetScript("OnClick", ToggleMinimize)
    minimizeBtn:GetNormalTexture():SetAlpha(0)
    minimizeBtn:GetPushedTexture():SetAlpha(0)
    local minText = minimizeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    minText:SetPoint("CENTER", 0, 0)
    minText:SetText("-")
    minimizeBtn.text = minText
    frame.minimizeBtn = minimizeBtn

    frame.fullViewElements = {}

    tinsert(UISpecialFrames, "RushHourConfigFrame")

    local modeWidth = 115
    local modeSpacing = 10
    local modeStartX = (280 - (modeWidth * 2) - modeSpacing) / 2

    local casuBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    casuBtn:SetSize(modeWidth, 22)
    casuBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", modeStartX, -30)
    casuBtn:SetText("Casu")
    casuBtn:SetScript("OnClick", function() SetMode("casu") end)
    frame.casuBtn = casuBtn
    tinsert(frame.fullViewElements, casuBtn)

    local hardcoreBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    hardcoreBtn:SetSize(modeWidth, 22)
    hardcoreBtn:SetPoint("LEFT", casuBtn, "RIGHT", modeSpacing, 0)
    hardcoreBtn:SetText("Hardcore")
    hardcoreBtn:SetScript("OnClick", function() SetMode("hardcore") end)
    frame.hardcoreBtn = hardcoreBtn
    tinsert(frame.fullViewElements, hardcoreBtn)

    local questLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    questLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -70)
    questLabel:SetText("Quest ID:")
    tinsert(frame.fullViewElements, questLabel)

    local questInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    questInput:SetSize(150, 20)
    questInput:SetPoint("LEFT", questLabel, "RIGHT", 10, 0)
    questInput:SetAutoFocus(false)
    questInput:SetNumeric(true)
    local function SaveQuestInput()
        local id = tonumber(questInput:GetText())
        if id then
            RushHourDB.triggerQuestID = id
        end
    end
    questInput:SetScript("OnEnterPressed", function(self)
        SaveQuestInput()
        self:ClearFocus()
    end)
    questInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    questInput:SetScript("OnEditFocusLost", SaveQuestInput)
    frame.questInput = questInput
    tinsert(frame.fullViewElements, questInput)

    local levelLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelLabel:SetPoint("TOPLEFT", questLabel, "BOTTOMLEFT", 0, -15)
    levelLabel:SetText("Niveau:")
    tinsert(frame.fullViewElements, levelLabel)

    local levelInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    levelInput:SetSize(150, 20)
    levelInput:SetPoint("LEFT", levelLabel, "RIGHT", 22, 0)
    levelInput:SetAutoFocus(false)
    levelInput:SetNumeric(true)
    local function SaveLevelInput()
        local lvl = tonumber(levelInput:GetText())
        if lvl and lvl >= 1 then
            RushHourDB.targetLevel = lvl
        else
            RushHourDB.targetLevel = DEFAULT_TARGET_LEVEL
            levelInput:SetText(tostring(DEFAULT_TARGET_LEVEL))
        end
        CheckLevelReached()
    end
    levelInput:SetScript("OnEnterPressed", function(self)
        SaveLevelInput()
        self:ClearFocus()
    end)
    levelInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    levelInput:SetScript("OnEditFocusLost", SaveLevelInput)
    frame.levelInput = levelInput
    tinsert(frame.fullViewElements, levelInput)

    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", -5, -10)
    separator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -125)
    separator:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    frame.separator = separator
    tinsert(frame.fullViewElements, separator)

    local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timerText:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 5, -15)
    timerText:SetText("Timer: --")
    frame.timerText = timerText

    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(80, 25)
    resetBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", ResetTimer)
    tinsert(frame.fullViewElements, resetBtn)

    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= 1 then
            elapsed = 0
            if RushHourDB.isRunning then
                UpdateTimerDisplay()
            end
        end
    end)

    frame:Hide()
    RushHourFrame = frame
    return frame
end

local function ToggleConfigFrame()
    local frame = CreateConfigFrame()

    if frame:IsShown() then
        frame:Hide()
    else
        if RushHourDB.triggerQuestID then
            frame.questInput:SetText(tostring(RushHourDB.triggerQuestID))
        else
            frame.questInput:SetText("")
        end
        frame.levelInput:SetText(tostring(RushHourDB.targetLevel))

        if RushHourDB.framePosition then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", RushHourDB.framePosition.x, RushHourDB.framePosition.y)
        end

        UpdateModeButtons()
        UpdateTimerDisplay()
        SetMinimized(RushHourDB.isMinimized)
        frame:Show()
    end
end

local function SlashHandler(msg)
    ToggleConfigFrame()
end

SLASH_RUSHOUR1 = "/rh"
SLASH_RUSHOUR2 = "/rushour"
SlashCmdList["RUSHOUR"] = SlashHandler

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            if not RushHourDB then
                RushHourDB = {}
            end
            for k, v in pairs(defaults) do
                if RushHourDB[k] == nil then
                    RushHourDB[k] = v
                end
            end

            if RushHourDB.isRunning then
                ResumeSession()
                local modeText = RushHourDB.mode == "hardcore" and "Hardcore" or "Casu"
                Print("Timer repris (" .. modeText .. ") - Temps: " .. FormatTime(GetElapsedTime()))
            elseif RushHourDB.isCompleted then
                Print("Objectif atteint! Temps final: " .. FormatTime(GetElapsedTime()))
            end
        end

    elseif event == "QUEST_ACCEPTED" then
        local questID = ...
        if RushHourDB.triggerQuestID and questID == RushHourDB.triggerQuestID then
            StartTimer(true)
        end

    elseif event == "PLAYER_LEVEL_UP" then
        CheckLevelReached()

    elseif event == "PLAYER_LOGOUT" then
        SaveSessionTime()
    end
end)
