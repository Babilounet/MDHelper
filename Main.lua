----------------------------------------------------------------------
-- MDHelper v1.2
-- Sélectionne un membre du raid/groupe et caste Détournement via un
-- bouton bindable ou la macro auto-créée "MDHelper".
----------------------------------------------------------------------

local ADDON_NAME = "MDHelper"
local MISDIRECTION_ID = 34477
local MACRO_NAME = "MDHelper"
local MACRO_ICON = "Ability_Hunter_Misdirection"

MDHelperDB = MDHelperDB or {}

local frame, listFrame, scrollChild, selectedLabel
local floatBtn
local rowButtons = {}
local castButton
local pendingMacroUpdate = false

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function getSpellName()
    local name = GetSpellInfo(MISDIRECTION_ID)
    return name or "Misdirection"
end

local function classColorStr(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

local function getRoster()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class, _, online = GetRaidRosterInfo(i)
            if name then
                list[#list + 1] = {
                    name = name,
                    class = class,
                    online = online,
                    unit = "raid" .. i,
                }
            end
        end
    elseif IsInGroup() then
        local me = UnitName("player")
        local _, meClass = UnitClass("player")
        list[#list + 1] = {name = me, class = meClass, online = true, unit = "player"}
        for i = 1, 4 do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name and name ~= UNKNOWN then
                local _, class = UnitClass(unit)
                list[#list + 1] = {
                    name = name,
                    class = class,
                    online = UnitIsConnected(unit),
                    unit = unit,
                }
            end
        end
    else
        local me = UnitName("player")
        local _, meClass = UnitClass("player")
        list[#list + 1] = {name = me, class = meClass, online = true, unit = "player"}
    end
    return list
end

----------------------------------------------------------------------
-- Secure cast button
----------------------------------------------------------------------

local function findUnitForName(name)
    if not name then return nil end
    if UnitName("player") == name then return "player" end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if UnitName("raid" .. i) == name then return "raid" .. i end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if UnitName("party" .. i) == name then return "party" .. i end
        end
    end
    return nil
end

local function buildMacroText()
    local spell = getSpellName()
    local target = MDHelperDB.selected
    if not target then
        return "/cast [help,nodead][@target] " .. spell
    end
    local unit = findUnitForName(target)
    -- Unit ID en priorité (fiable cross-realm), fallback par nom
    if unit then
        return "/cast [@" .. unit .. ",help,nodead][@" .. unit .. "][@" .. target .. "] " .. spell
    end
    return "/cast [@" .. target .. ",help,nodead][@" .. target .. "] " .. spell
end

local function updateMacroText()
    if not castButton then return end
    if InCombatLockdown() then
        pendingMacroUpdate = true
        return
    end
    castButton:SetAttribute("macrotext", buildMacroText())
end

local function createCastButton()
    castButton = CreateFrame("Button", "MDHelperCastButton", UIParent, "SecureActionButtonTemplate")
    castButton:SetAttribute("type", "macro")
    castButton:RegisterForClicks("AnyUp", "AnyDown")
    castButton:Hide()
    updateMacroText()
end

----------------------------------------------------------------------
-- Macro auto-creation
----------------------------------------------------------------------

local function createOrUpdateMacro(silent)
    if InCombatLockdown() then
        if not silent then
            print("|cffff0000MDHelper:|r impossible de créer la macro en combat.")
        end
        return false
    end
    local body = "/click MDHelperCastButton"
    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, MACRO_NAME, MACRO_ICON, body)
        if not silent then
            print("|cff00ff00MDHelper:|r macro \"" .. MACRO_NAME .. "\" mise à jour.")
        end
        return true
    end
    -- Tente macro générale (slot 1..120), sinon macro perso (121..138)
    local newIdx = CreateMacro(MACRO_NAME, MACRO_ICON, body, nil)
    if not newIdx then
        newIdx = CreateMacro(MACRO_NAME, MACRO_ICON, body, 1)
    end
    if newIdx then
        if not silent then
            print("|cff00ff00MDHelper:|r macro \"" .. MACRO_NAME .. "\" créée. Glisse-la sur ta barre d'action.")
        end
        return true
    else
        if not silent then
            print("|cffff0000MDHelper:|r impossible de créer la macro (slots pleins).")
        end
        return false
    end
end

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------

local function updateSelectedLabel()
    if not selectedLabel then return end
    local sel = MDHelperDB.selected
    if sel then
        selectedLabel:SetText("Cible : |cffffcc00" .. sel .. "|r")
    else
        selectedLabel:SetText("Cible : |cff888888(aucune)|r")
    end
end

local function updateFloatingButton()
    if not floatBtn then return end
    local sel = MDHelperDB.selected
    if sel then
        floatBtn.text:SetText("|cffffcc00" .. sel .. "|r")
    else
        floatBtn.text:SetText("|cff888888(aucune)|r")
    end
    if MDHelperDB.hideFloat then
        floatBtn:Hide()
    elseif IsInGroup() then
        floatBtn:Show()
    else
        floatBtn:Hide()
    end
end

local function refreshList()
    if not frame or not frame:IsShown() then return end

    local roster = getRoster()

    for _, btn in ipairs(rowButtons) do
        btn:Hide()
    end

    for i, member in ipairs(roster) do
        local btn = rowButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, scrollChild)
            btn:SetSize(180, 20)
            btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetColorTexture(0, 0, 0, 0)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", 6, 0)
            btn.text:SetJustifyH("LEFT")

            btn.check = btn:CreateTexture(nil, "OVERLAY")
            btn.check:SetSize(14, 14)
            btn.check:SetPoint("RIGHT", -4, 0)
            btn.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            btn.check:Hide()

            btn:SetScript("OnClick", function(self)
                MDHelperDB.selected = self.memberName
                updateMacroText()
                updateSelectedLabel()
                updateFloatingButton()
                refreshList()
            end)

            rowButtons[i] = btn
        end

        btn.memberName = member.name
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        btn:Show()

        local color = classColorStr(member.class)
        local label = color .. member.name .. "|r"
        if not member.online then
            label = label .. " |cff888888(hors-ligne)|r"
        end
        btn.text:SetText(label)

        if member.name == MDHelperDB.selected then
            btn.check:Show()
            btn.bg:SetColorTexture(1, 0.8, 0, 0.2)
        else
            btn.check:Hide()
            btn.bg:SetColorTexture(0, 0, 0, 0)
        end
    end

    scrollChild:SetHeight(math.max(1, #roster) * 20)
end

local function createUI()
    frame = CreateFrame("Frame", "MDHelper_Frame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(220, 360)
    frame:SetPoint(
        MDHelperDB.framePoint or "CENTER",
        UIParent,
        MDHelperDB.framePoint or "CENTER",
        MDHelperDB.frameX or 0,
        MDHelperDB.frameY or 0
    )
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        MDHelperDB.framePoint = point
        MDHelperDB.frameX = x
        MDHelperDB.frameY = y
    end)
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
    frame.title:SetText("MDHelper")

    selectedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectedLabel:SetPoint("TOPLEFT", 12, -28)
    selectedLabel:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", "MDHelper_Scroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -50)
    scroll:SetPoint("BOTTOMRIGHT", -30, 80)

    scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(180, 1)
    scroll:SetScrollChild(scrollChild)
    listFrame = scrollChild

    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(90, 22)
    clearBtn:SetPoint("BOTTOMLEFT", 10, 52)
    clearBtn:SetText("Effacer")
    clearBtn:SetScript("OnClick", function()
        MDHelperDB.selected = nil
        updateMacroText()
        updateSelectedLabel()
        updateFloatingButton()
        refreshList()
    end)

    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", -10, 52)
    refreshBtn:SetText("Rafraîchir")
    refreshBtn:SetScript("OnClick", refreshList)

    local macroBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    macroBtn:SetSize(190, 22)
    macroBtn:SetPoint("BOTTOM", 0, 28)
    macroBtn:SetText("Créer/Mettre à jour la macro")
    macroBtn:SetScript("OnClick", function() createOrUpdateMacro(false) end)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOM", 0, 10)
    help:SetText("Bind via Options > Touches > MDHelper")
    help:SetJustifyH("CENTER")

    frame:SetScript("OnShow", function()
        updateSelectedLabel()
        refreshList()
    end)
end

local function createFloatingButton()
    floatBtn = CreateFrame("Button", "MDHelper_FloatBtn", UIParent, "BackdropTemplate")
    floatBtn:SetSize(150, 28)
    floatBtn:SetFrameStrata("MEDIUM")
    floatBtn:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    floatBtn:SetMovable(true)
    floatBtn:EnableMouse(true)
    floatBtn:RegisterForDrag("LeftButton")
    floatBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    floatBtn:SetClampedToScreen(true)

    floatBtn.icon = floatBtn:CreateTexture(nil, "ARTWORK")
    floatBtn.icon:SetSize(18, 18)
    floatBtn.icon:SetPoint("LEFT", 6, 0)
    floatBtn.icon:SetTexture("Interface\\Icons\\Ability_Hunter_Misdirection")
    floatBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    floatBtn.label = floatBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    floatBtn.label:SetPoint("TOPLEFT", floatBtn.icon, "TOPRIGHT", 4, 0)
    floatBtn.label:SetText("MD")
    floatBtn.label:SetTextColor(1, 0.82, 0)

    floatBtn.text = floatBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    floatBtn.text:SetPoint("BOTTOMLEFT", floatBtn.icon, "BOTTOMRIGHT", 4, 0)
    floatBtn.text:SetPoint("RIGHT", -6, 0)
    floatBtn.text:SetJustifyH("LEFT")

    floatBtn:SetScript("OnDragStart", function(self) self:StartMoving() end)
    floatBtn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        MDHelperDB.floatPoint = point
        MDHelperDB.floatX = x
        MDHelperDB.floatY = y
    end)

    floatBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if MDHelperDB.selected then
                MDHelperDB.selected = nil
                updateMacroText()
                updateSelectedLabel()
                updateFloatingButton()
                if frame:IsShown() then refreshList() end
                print("|cff00ff00MDHelper:|r cible effacée.")
            end
        else
            if frame:IsShown() then frame:Hide() else frame:Show() end
        end
    end)

    floatBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("MDHelper")
        GameTooltip:AddLine("Clic gauche : ouvrir la liste", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : effacer la cible", 1, 1, 1)
        GameTooltip:AddLine("Glisser : déplacer", 1, 1, 1)
        GameTooltip:Show()
    end)
    floatBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local pt = MDHelperDB.floatPoint or "CENTER"
    floatBtn:ClearAllPoints()
    floatBtn:SetPoint(pt, UIParent, pt, MDHelperDB.floatX or 0, MDHelperDB.floatY or 200)
    floatBtn:Hide()
end

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------

SLASH_MDHELPER1 = "/md"
SLASH_MDHELPER2 = "/mdhelper"
SlashCmdList["MDHELPER"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "clear" then
        MDHelperDB.selected = nil
        updateMacroText()
        updateSelectedLabel()
        updateFloatingButton()
        if frame and frame:IsShown() then refreshList() end
        print("|cff00ff00MDHelper:|r cible effacée.")
    elseif msg == "macro" then
        createOrUpdateMacro(false)
    elseif msg == "float" then
        MDHelperDB.hideFloat = not MDHelperDB.hideFloat
        updateFloatingButton()
        print("|cff00ff00MDHelper:|r bouton flottant " .. (MDHelperDB.hideFloat and "masqué" or "affiché en groupe/raid") .. ".")
    elseif msg == "debug" then
        print("|cff00ff00MDHelper debug:|r")
        print("  Sort : " .. getSpellName())
        print("  Cible sélectionnée : " .. tostring(MDHelperDB.selected))
        print("  Unit ID résolu : " .. tostring(findUnitForName(MDHelperDB.selected)))
        print("  InRaid : " .. tostring(IsInRaid()) .. " | InGroup : " .. tostring(IsInGroup()))
        print("  Macro : " .. (castButton and castButton:GetAttribute("macrotext") or "(absent)"))
        print("  Macro système existante : " .. tostring(GetMacroIndexByName(MACRO_NAME)))
    elseif msg == "show" then
        if frame then frame:Show() end
    elseif msg == "hide" then
        if frame then frame:Hide() end
    elseif msg == "help" or msg == "?" then
        print("|cff00ff00MDHelper:|r commandes :")
        print("  /md          : ouvrir/fermer la liste")
        print("  /md clear    : effacer la cible")
        print("  /md macro    : (re)créer la macro")
        print("  /md float    : afficher/masquer le bouton flottant")
        print("  /md debug    : diagnostic")
    else
        if frame:IsShown() then frame:Hide() else frame:Show() end
    end
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        createCastButton()
        createUI()
        createFloatingButton()
        updateFloatingButton()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        print("|cff00ff00MDHelper|r chargé. Tape |cffffcc00/md|r pour ouvrir.")

    elseif event == "GROUP_ROSTER_UPDATE" then
        updateMacroText()
        updateFloatingButton()
        if frame and frame:IsShown() then refreshList() end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingMacroUpdate then
            pendingMacroUpdate = false
            updateMacroText()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        updateMacroText()
        updateFloatingButton()
        -- Création auto de la macro la première fois (une seule tentative)
        if not MDHelperDB.macroAutoCreated then
            MDHelperDB.macroAutoCreated = true
            C_Timer.After(2, function()
                if not GetMacroIndexByName(MACRO_NAME) then
                    createOrUpdateMacro(false)
                end
            end)
        end
    end
end)
