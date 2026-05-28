----------------------------------------------------------------------
-- MDHelper v1.8
-- Sélectionne un membre du raid/groupe et caste Détournement via :
--   - le bouton flottant (clic gauche)
--   - les boutons "favoris" (un par tank/épinglé, clic gauche)
--   - la macro auto-créée "MDHelper" sur la barre d'action
--   - le keybind dans Options > Touches > MDHelper
----------------------------------------------------------------------

local ADDON_NAME = "MDHelper"
local MISDIRECTION_ID = 34477
local MACRO_NAME = "MDHelper"
local MACRO_ICON = "Ability_Hunter_Misdirection"

-- Fallback localisé si GetSpellInfo échoue
local SPELL_NAMES = {
    enUS = "Misdirection",
    enGB = "Misdirection",
    frFR = "Détournement",
    deDE = "Irreführung",
    esES = "Distracción",
    esMX = "Distracción",
    itIT = "Diversione",
    ptBR = "Engano",
    ruRU = "Отвлечение внимания",
    koKR = "위장",
    zhCN = "误导",
    zhTW = "誤導",
}

MDHelperDB = MDHelperDB or {}

local frame, listFrame, scrollChild, selectedLabel
local floatBtn
local rowButtons = {}
local favSlots = {}
local castButton
local pendingMacroUpdate = false

local MAX_FAV_SLOTS = 10
local refreshFavoriteSlots -- forward decl

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

local function getSpellName()
    local name = GetSpellInfo(MISDIRECTION_ID)
    if name and name ~= "" then return name end
    return SPELL_NAMES[GetLocale()] or "Misdirection"
end

local function classColorStr(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

local function isFavorite(name)
    return name and MDHelperDB.favorites and MDHelperDB.favorites[name] == true
end

local function isTankRole(role, combatRole)
    return role == "MAINTANK" or combatRole == "TANK"
end

local function getRoster()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class, _, online, _, role, _, combatRole = GetRaidRosterInfo(i)
            if name then
                local tank = isTankRole(role, combatRole)
                list[#list + 1] = {
                    name = name, class = class, online = online, unit = "raid" .. i,
                    isTank = tank, isFav = isFavorite(name),
                    pinned = tank or isFavorite(name),
                    order = i,
                }
            end
        end
    elseif IsInGroup() then
        local me = UnitName("player")
        local _, meClass = UnitClass("player")
        local meRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "NONE"
        local meTank = isTankRole(nil, meRole)
        list[#list + 1] = {
            name = me, class = meClass, online = true, unit = "player",
            isTank = meTank, isFav = isFavorite(me),
            pinned = meTank or isFavorite(me), order = 0,
        }
        for i = 1, 4 do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name and name ~= UNKNOWN then
                local _, class = UnitClass(unit)
                local cRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
                local tank = isTankRole(nil, cRole)
                list[#list + 1] = {
                    name = name, class = class,
                    online = UnitIsConnected(unit), unit = unit,
                    isTank = tank, isFav = isFavorite(name),
                    pinned = tank or isFavorite(name), order = i,
                }
            end
        end
    else
        local me = UnitName("player")
        local _, meClass = UnitClass("player")
        list[#list + 1] = {
            name = me, class = meClass, online = true, unit = "player",
            isTank = false, isFav = false, pinned = false, order = 0,
        }
    end

    -- Favoris/tanks en haut, le reste dans l'ordre du raid/groupe
    table.sort(list, function(a, b)
        if a.pinned ~= b.pinned then return a.pinned end
        return (a.order or 999) < (b.order or 999)
    end)
    return list
end

local function getClassForName(name)
    if not name then return nil end
    if UnitName("player") == name then
        local _, c = UnitClass("player")
        return c
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local n, _, _, _, _, class = GetRaidRosterInfo(i)
            if n == name then return class end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if UnitName("party" .. i) == name then
                local _, c = UnitClass("party" .. i)
                return c
            end
        end
    end
    return nil
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
    -- Toutes les clauses ont [help,nodead] : si aucune cible valide
    -- (vivante, amicale) ne matche, le cast ne part pas (MD a un long CD).
    if not target then
        return "/cast [@mouseover,help,nodead][help,nodead] " .. spell
    end
    local unit = findUnitForName(target)
    if unit then
        return "/cast [@mouseover,help,nodead][@" .. unit .. ",help,nodead] " .. spell
    end
    return "/cast [@mouseover,help,nodead][@" .. target .. ",help,nodead] " .. spell
end

local function syncActionBarMacro(body)
    if InCombatLockdown() then return end
    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, MACRO_NAME, MACRO_ICON, body)
    end
end

local function updateMacroText()
    if InCombatLockdown() then
        pendingMacroUpdate = true
        return
    end
    local body = buildMacroText()
    if castButton then castButton:SetAttribute("macrotext", body) end
    if floatBtn then floatBtn:SetAttribute("macrotext1", body) end
    -- Action-bar macro executes /cast directly, no need for /click
    syncActionBarMacro(body)
end

local function createCastButton()
    castButton = CreateFrame("Button", "MDHelperCastButton", UIParent, "SecureActionButtonTemplate")
    castButton:SetAttribute("type", "macro")
    castButton:RegisterForClicks("AnyUp", "AnyDown")
    -- Visible mais invisible : /click sur un bouton Hide()'d est unreliable en TBC 2.5.5
    castButton:SetSize(1, 1)
    castButton:SetPoint("CENTER", UIParent, "CENTER")
    castButton:SetAlpha(0)
    castButton:EnableMouse(false)
    updateMacroText()
end

----------------------------------------------------------------------
-- Macro auto-creation
----------------------------------------------------------------------

local function createOrUpdateMacro(silent)
    if InCombatLockdown() then
        if not silent then
            print("|cffff0000MDHelper:|r cannot create macro during combat.")
        end
        return false
    end
    local body = buildMacroText()
    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, MACRO_NAME, MACRO_ICON, body)
        if not silent then
            print("|cff00ff00MDHelper:|r macro \"" .. MACRO_NAME .. "\" updated.")
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
            print("|cff00ff00MDHelper:|r macro \"" .. MACRO_NAME .. "\" created. Drag it onto your action bar.")
        end
        return true
    else
        if not silent then
            print("|cffff0000MDHelper:|r cannot create macro (slots full).")
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
        selectedLabel:SetText("Target: |cffffcc00" .. sel .. "|r")
    else
        selectedLabel:SetText("Target: |cff888888(none)|r")
    end
end

local function updateFloatingButton()
    if not floatBtn then return end
    -- Texte (non protégé) : toujours OK
    local sel = MDHelperDB.selected
    if sel then
        local color = classColorStr(getClassForName(sel))
        floatBtn.text:SetText(color .. sel .. "|r")
    else
        floatBtn.text:SetText("|cff888888(none)|r")
    end
    -- Visibilité (protégée car secure button) : hors combat seulement
    if InCombatLockdown() then return end
    if MDHelperDB.hideFloat then
        floatBtn:Hide()
    else
        floatBtn:Show()
    end
end

local MAX_ROWS = 40
local refreshList -- forward decl

local function createRowButton(i)
    -- Bouton non-sécurisé : juste pour sélectionner / épingler. Le cast en
    -- combat passe par le keybind global avec @mouseover (voir buildMacroText).
    local btn = CreateFrame("Button", nil, scrollChild)
    btn:SetSize(180, 20)
    btn:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    btn:Hide()

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0, 0, 0, 0)

    btn.pin = btn:CreateTexture(nil, "OVERLAY")
    btn.pin:SetSize(12, 12)
    btn.pin:SetPoint("LEFT", 4, 0)
    btn.pin:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    btn.pin:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("LEFT", 20, 0)
    btn.text:SetJustifyH("LEFT")

    btn.check = btn:CreateTexture(nil, "OVERLAY")
    btn.check:SetSize(14, 14)
    btn.check:SetPoint("RIGHT", -4, 0)
    btn.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    btn.check:Hide()

    btn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MDHelperDB.favorites = MDHelperDB.favorites or {}
            if MDHelperDB.favorites[self.memberName] then
                MDHelperDB.favorites[self.memberName] = nil
            else
                MDHelperDB.favorites[self.memberName] = true
            end
            refreshList()
            refreshFavoriteSlots()
        else
            MDHelperDB.selected = self.memberName
            updateMacroText()
            updateSelectedLabel()
            updateFloatingButton()
            refreshList()
        end
    end)

    return btn
end

local function preCreateRows()
    for i = 1, MAX_ROWS do
        if not rowButtons[i] then
            rowButtons[i] = createRowButton(i)
        end
    end
end

refreshList = function()
    if not frame then return end
    preCreateRows()
    local roster = getRoster()

    for i = 1, MAX_ROWS do
        local btn = rowButtons[i]
        if btn then
            local member = roster[i]
            if member then
                btn.memberName = member.name

                if member.pinned then btn.pin:Show() else btn.pin:Hide() end
                local color = classColorStr(member.class)
                local label = color .. member.name .. "|r"
                if member.isTank then label = label .. " |cff4488ffT|r" end
                if not member.online then label = label .. " |cff888888(offline)|r" end
                btn.text:SetText(label)

                if member.name == MDHelperDB.selected then
                    btn.check:Show()
                    btn.bg:SetColorTexture(1, 0.8, 0, 0.2)
                else
                    btn.check:Hide()
                    btn.bg:SetColorTexture(0, 0, 0, 0)
                end

                btn:Show()
            else
                btn.memberName = nil
                btn.text:SetText("")
                btn.pin:Hide()
                btn.check:Hide()
                btn.bg:SetColorTexture(0, 0, 0, 0)
                btn:Hide()
            end
        end
    end

    if scrollChild then scrollChild:SetHeight(math.max(1, #roster) * 20) end
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
    clearBtn:SetText("Clear")
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
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", refreshList)

    local macroBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    macroBtn:SetSize(190, 22)
    macroBtn:SetPoint("BOTTOM", 0, 28)
    macroBtn:SetText("Create/Update macro")
    macroBtn:SetScript("OnClick", function() createOrUpdateMacro(false) end)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOM", 0, 10)
    help:SetText("Click = select | Right-click = pin\nIn combat: click a pinned slot or hover a raid frame + bind")
    help:SetJustifyH("CENTER")

    frame:SetScript("OnShow", function()
        updateSelectedLabel()
        refreshList()
    end)

    -- ESC ferme la fenêtre
    tinsert(UISpecialFrames, "MDHelper_Frame")
end

local function createFloatingButton()
    -- SecureActionButton + Backdrop : clic gauche caste directement.
    -- À UIParent : pas de taint sur le frame liste.
    floatBtn = CreateFrame("Button", "MDHelper_FloatBtn", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
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
    -- Drag sur MiddleButton (drag sur LeftButton avale le secure click en TBC 2.5.5)
    floatBtn:RegisterForDrag("MiddleButton")
    -- AnyUp + AnyDown nécessaire pour que le secure cast déclenche en TBC 2.5.5
    floatBtn:RegisterForClicks("AnyUp", "AnyDown")
    floatBtn:SetClampedToScreen(true)
    -- type1/macrotext1 : cast uniquement sur clic gauche. Clic droit n'a aucun
    -- type → pas de cast, PreClick s'en occupe (ouvre la liste).
    floatBtn:SetAttribute("type1", "macro")

    floatBtn.icon = floatBtn:CreateTexture(nil, "ARTWORK")
    floatBtn.icon:SetSize(22, 22)
    floatBtn.icon:SetPoint("LEFT", 6, 0)
    floatBtn.icon:SetTexture("Interface\\Icons\\Ability_Hunter_Misdirection")
    floatBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    floatBtn.text = floatBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    floatBtn.text:SetPoint("LEFT", floatBtn.icon, "RIGHT", 8, 0)
    floatBtn.text:SetPoint("RIGHT", -8, 0)
    floatBtn.text:SetJustifyH("LEFT")
    floatBtn.text:SetJustifyV("MIDDLE")

    floatBtn:SetScript("OnDragStart", function(self) self:StartMoving() end)
    floatBtn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        MDHelperDB.floatPoint = point
        MDHelperDB.floatX = x
        MDHelperDB.floatY = y
    end)

    -- NE PAS SetScript("OnClick", ...) : le template SecureActionButtonTemplate
    -- utilise OnClick pour le cast secure. PreClick = hook non-sécurisé (fire
    -- AVANT le cast secure). down filter pour éviter le double-toggle.
    floatBtn:SetScript("PreClick", function(self, button, down)
        if down then return end
        if button == "RightButton" then
            if frame:IsShown() then frame:Hide() else frame:Show() end
        end
    end)

    floatBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("MDHelper")
        GameTooltip:AddLine("Left-click: cast Misdirection", 1, 1, 1)
        GameTooltip:AddLine("Right-click: open/close the list", 1, 1, 1)
        GameTooltip:AddLine("Middle-click + drag: move", 1, 1, 1)
        GameTooltip:Show()
    end)
    floatBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local pt = MDHelperDB.floatPoint or "CENTER"
    floatBtn:ClearAllPoints()
    floatBtn:SetPoint(pt, UIParent, pt, MDHelperDB.floatX or 0, MDHelperDB.floatY or 200)
    floatBtn:Hide()
end

----------------------------------------------------------------------
-- Favorite slot buttons (un par favori + tanks auto)
----------------------------------------------------------------------

local function createFavoriteSlot(i)
    local slot = CreateFrame("Button", "MDHelper_FavSlot" .. i, UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    slot:SetSize(150, 24)
    if i == 1 then
        slot:SetPoint("TOP", floatBtn, "BOTTOM", 0, -2)
    else
        slot:SetPoint("TOP", favSlots[i - 1], "BOTTOM", 0, -1)
    end
    slot:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    slot:RegisterForClicks("AnyUp", "AnyDown")
    slot:SetAttribute("type1", "macro") -- macrotext1 set in refresh
    slot:EnableMouse(true)
    slot:Hide()

    slot.text = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slot.text:SetPoint("LEFT", 10, 0)
    slot.text:SetPoint("RIGHT", -10, 0)
    slot.text:SetJustifyH("LEFT")

    slot:SetScript("PreClick", function(self, button, down)
        if down then return end
        if button == "RightButton" then
            if frame:IsShown() then frame:Hide() else frame:Show() end
        end
    end)

    slot:SetScript("OnEnter", function(self)
        if not self.memberName then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.memberName)
        GameTooltip:AddLine("Left-click: cast Misdirection", 1, 1, 1)
        GameTooltip:AddLine("Right-click: open/close the list", 1, 1, 1)
        GameTooltip:AddLine("(Right-click in the list to unpin)", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return slot
end

local function preCreateFavSlots()
    if InCombatLockdown() then return end
    for i = 1, MAX_FAV_SLOTS do
        if not favSlots[i] then
            favSlots[i] = createFavoriteSlot(i)
        end
    end
end

refreshFavoriteSlots = function()
    if InCombatLockdown() then return end
    preCreateFavSlots()

    -- Favoris effectifs : tanks (auto) + favoris manuels, ordre du roster
    local roster = getRoster()
    local effective = {}
    for _, m in ipairs(roster) do
        if m.pinned and #effective < MAX_FAV_SLOTS then
            effective[#effective + 1] = m
        end
    end

    local spell = getSpellName()
    for i = 1, MAX_FAV_SLOTS do
        local slot = favSlots[i]
        local m = effective[i]
        if m then
            slot.memberName = m.name
            local color = classColorStr(m.class)
            local label = color .. m.name .. "|r"
            if m.isTank then label = label .. " |cff4488ffT|r" end
            slot.text:SetText(label)
            local macroText
            if m.unit then
                macroText = "/cast [@" .. m.unit .. ",help,nodead][@" .. m.name .. ",help,nodead] " .. spell
            else
                macroText = "/cast [@" .. m.name .. ",help,nodead] " .. spell
            end
            slot:SetAttribute("macrotext1", macroText)
            slot:Show()
        else
            slot.memberName = nil
            slot:Hide()
        end
    end
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
        print("|cff00ff00MDHelper:|r target cleared.")
    elseif msg == "macro" then
        createOrUpdateMacro(false)
    elseif msg == "float" then
        MDHelperDB.hideFloat = not MDHelperDB.hideFloat
        updateFloatingButton()
        print("|cff00ff00MDHelper:|r floating button " .. (MDHelperDB.hideFloat and "hidden" or "shown") .. ".")
    elseif msg == "debug" then
        print("|cff00ff00MDHelper debug:|r")
        print("  Locale: " .. GetLocale())
        print("  Spell: " .. getSpellName())
        print("  Selected: " .. tostring(MDHelperDB.selected))
        print("  Current target: " .. (UnitExists("target") and UnitName("target") or "(none)"))
        print("  Resolved unit: " .. tostring(findUnitForName(MDHelperDB.selected)))
        print("  InRaid: " .. tostring(IsInRaid()) .. " | InGroup: " .. tostring(IsInGroup()))
        print("  castButton shown=" .. tostring(castButton and castButton:IsShown()) .. " type=" .. tostring(castButton and castButton:GetAttribute("type")) .. " macrotext=" .. tostring(castButton and castButton:GetAttribute("macrotext")))
        print("  floatBtn shown=" .. tostring(floatBtn and floatBtn:IsShown()) .. " type1=" .. tostring(floatBtn and floatBtn:GetAttribute("type1")) .. " macrotext1=" .. tostring(floatBtn and floatBtn:GetAttribute("macrotext1")))
        local idx = GetMacroIndexByName(MACRO_NAME)
        print("  System macro: " .. tostring(idx) .. (idx and idx > 0 and " (OK)" or " (MISSING)"))
    elseif msg == "show" then
        if frame then frame:Show() end
    elseif msg == "hide" then
        if frame then frame:Hide() end
    elseif msg == "help" or msg == "?" then
        print("|cff00ff00MDHelper:|r commands:")
        print("  /md          : open/close the list")
        print("  /md clear    : clear the selected target")
        print("  /md macro    : (re)create the macro")
        print("  /md float    : show/hide the floating button")
        print("  /md debug    : diagnostic info")
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
        updateMacroText() -- pose le macrotext1 sur floatBtn créé après castButton
        updateFloatingButton()
        refreshFavoriteSlots()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        print("|cff00ff00MDHelper|r loaded. Type |cffffcc00/md|r to open.")

    elseif event == "GROUP_ROSTER_UPDATE" then
        updateMacroText()
        updateFloatingButton()
        refreshList()
        refreshFavoriteSlots()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingMacroUpdate then
            pendingMacroUpdate = false
            updateMacroText()
        end
        refreshList()
        refreshFavoriteSlots()

    elseif event == "PLAYER_ENTERING_WORLD" then
        preCreateRows()  -- pré-crée les 40 secure rows tôt et hors combat
        refreshList()    -- pour que les attributs soient prêts dès le premier combat
        updateMacroText()
        updateFloatingButton()
        refreshFavoriteSlots()
        -- Création auto de la macro tant qu'elle n'existe pas (GetMacroIndexByName retourne 0 si absente)
        if not MDHelperDB.macroAutoCreated then
            C_Timer.After(2, function()
                if InCombatLockdown() then return end
                local idx = GetMacroIndexByName(MACRO_NAME)
                if not idx or idx == 0 then
                    if createOrUpdateMacro(true) then
                        MDHelperDB.macroAutoCreated = true
                        print("|cff00ff00MDHelper:|r macro \"" .. MACRO_NAME .. "\" created. Drag it onto your action bar.")
                    end
                else
                    MDHelperDB.macroAutoCreated = true
                end
            end)
        end
    end
end)
