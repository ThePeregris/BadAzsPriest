-- [[ [|cff355E3BB|r]adAzs |cffffffffPriest|r ]]
-- Author:  ThePeregris
-- Version: 1.0 (Self-Sufficient + 3 Graphic Panels: Holy / Discipline / Shadow)
-- Target:  Turtle WoW (1.12 / LUA 5.0)
-- Requires: BadAzs Core (apenas utilitarios universais: ManualMouseover/Ready/GetMana/Vision/Sustain)
--
-- Referencias analisadas (design, nao codigo portado 1:1):
--   Rinse (Otari98)      -> padrao de mapear tipo de debuff -> spell que remove
--   BadAzsPriest/QuickHeal -> conceito de escolher heal pela gravidade do dano + mana
--   BadAzsPriest/BeneCast  -> conceito de smart-buff no mouseover com tecla modificadora

local BadAzsPriestVersion = "|cffffffff[BadAzsPriest v1.0]|r"

-- ==========================================================
-- LOCALIZACAO (EN padrao / PT alternativo)
-- ==========================================================
local BadAzsP_L = {
    EN = {
        loaded        = "Loaded. Type /badazs priest holy|disc|shadow to configure.",
        title         = "BadAzs Priest",
        specHoly      = "Holy",
        specDisc      = "Discipline",
        specShadow    = "Shadow",
        specDetected  = "Talent spec detected: ",
        flashLabel    = "HP% - Flash Heal (urgent)",
        greaterLabel  = "HP% - Greater Heal (big deficit)",
        renewLabel    = "HP% - Renew (top off)",
        shieldLabel   = "Use Power Word: Shield first",
        buffLabel     = "ALT Buff (Smart Buff)",
        explainFlash   = "Below this HP%, the target is in danger - Flash Heal is used for its fast cast time, even though it costs more mana per point healed.",
        explainGreater = "Below this HP% (but above the Flash Heal line), Greater Heal is used - slow cast, but the most mana-efficient big heal.",
        explainRenew   = "Below this HP% (but above both lines above), Renew is applied instead - a cheap heal-over-time to top the target off.",
        explainShield  = "If enabled, Power Word: Shield is cast first whenever the target lacks it and isn't under Weakened Soul, before any direct heal lands.",
        explainBuff    = "Hold ALT and mouseover a party member (or yourself) to cast this buff on them. Click the button to cycle which buff is used.",
        cmdHeader     = "Macros",
        cmdList = {
            "/bapheal - Smart Heal (mouseover, else target, else self)",
            "Hold ALT - Cast the Buff below on mouseover",
            "/badazs priest holy - Open Holy panel",
            "/badazs priest disc - Open Discipline panel",
            "/badazs priest shadow - Open Shadow panel"
        }
    },
    PT = {
        loaded        = "Carregado. Digite /badazs priest holy|disc|shadow para configurar.",
        title         = "BadAzs Priest",
        specHoly      = "Holy",
        specDisc      = "Discipline",
        specShadow    = "Shadow",
        specDetected  = "Spec de talento detectada: ",
        flashLabel    = "HP% - Flash Heal (urgente)",
        greaterLabel  = "HP% - Greater Heal (deficit grande)",
        renewLabel    = "HP% - Renew (completar)",
        shieldLabel   = "Usar Power Word: Shield primeiro",
        buffLabel     = "Buff no ALT (Smart Buff)",
        explainFlash   = "Abaixo dessa porcentagem de HP, o alvo esta em perigo - Flash Heal e usado pelo cast rapido, mesmo custando mais mana por ponto curado.",
        explainGreater = "Abaixo dessa porcentagem (mas acima da linha do Flash Heal), Greater Heal e usado - cast lento, mas o heal grande mais eficiente em mana.",
        explainRenew   = "Abaixo dessa porcentagem (mas acima das duas linhas acima), Renew e aplicado - um heal ao longo do tempo barato pra completar o alvo.",
        explainShield  = "Se ativado, Power Word: Shield e lancado primeiro sempre que o alvo nao tiver o escudo e nao estiver com Weakened Soul, antes de qualquer heal direto.",
        explainBuff    = "Segure ALT e passe o mouse num membro do grupo (ou em voce mesmo) pra lancar esse buff nele. Clique no botao pra ciclar qual buff e usado.",
        cmdHeader     = "Macros",
        cmdList = {
            "/bapheal - Smart Heal (mouseover, senao target, senao voce)",
            "Segure ALT - Lanca o Buff abaixo no mouseover",
            "/badazs priest holy - Abre o painel Holy",
            "/badazs priest disc - Abre o painel Discipline",
            "/badazs priest shadow - Abre o painel Shadow"
        }
    }
}

-- ==========================================================
-- INIT
-- ==========================================================
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loadFrame:SetScript("OnEvent", function()
    if not BadAzsPriestDB then BadAzsPriestDB = {} end
    if not BadAzsPriestDB.Locale then BadAzsPriestDB.Locale = "EN" end

    if not BadAzsPriestDB.holy then
        BadAzsPriestDB.holy = { FlashHealBelow = 25, GreaterHealBelow = 55, RenewBelow = 90, UseShield = false, Buff = "Power Word: Fortitude", BuffIndex = 1 }
    end
    if not BadAzsPriestDB.disc then
        BadAzsPriestDB.disc = { FlashHealBelow = 20, GreaterHealBelow = 45, RenewBelow = 90, UseShield = true, Buff = "Power Word: Shield", BuffIndex = 4 }
    end
    if not BadAzsPriestDB.shadow then
        BadAzsPriestDB.shadow = { FlashHealBelow = 35, GreaterHealBelow = 60, RenewBelow = 90, UseShield = false, Buff = "Power Word: Fortitude", BuffIndex = 1 }
    end

    DEFAULT_CHAT_FRAME:AddMessage(BadAzsPriestVersion .. " " .. BadAzsP_L[BadAzsPriestDB.Locale].loaded)
end)

-- ==========================================================
-- HELPERS (generico por unit - Core so cobre "player"/"target")
-- ==========================================================
local function BadAzsP_UnitHasBuff(unit, texture)
    local i = 1
    while UnitBuff(unit, i) do
        local t = UnitBuff(unit, i)
        if string.find(t, texture) then return true end
        i = i + 1
    end
    return false
end

local function BadAzsP_UnitHasDebuff(unit, texture)
    local i = 1
    while UnitDebuff(unit, i) do
        local t = UnitDebuff(unit, i)
        if string.find(t, texture) then return true end
        i = i + 1
    end
    return false
end

-- Detecta a spec pelos pontos investidos nas 3 arvores de talento
-- (Discipline=1, Holy=2, Shadow=3 na ordem padrao do cliente 1.12)
function BadAzsP_DetectSpec()
    local tabs = { "disc", "holy", "shadow" }
    local best, bestPts = "holy", -1
    local i
    for i = 1, 3 do
        local name, texture, pointsSpent = GetTalentTabInfo(i)
        if pointsSpent and pointsSpent > bestPts then
            bestPts = pointsSpent
            best = tabs[i]
        end
    end
    return best
end

local BuffList = { "Power Word: Fortitude", "Divine Spirit", "Shadow Protection", "Power Word: Shield" }

function BadAzsP_CycleBuff(spec)
    local profile = BadAzsPriestDB[spec]
    profile.BuffIndex = (profile.BuffIndex or 0) + 1
    if profile.BuffIndex > table.getn(BuffList) then profile.BuffIndex = 1 end
    profile.Buff = BuffList[profile.BuffIndex]
    if BadAzsP_RefreshPanels then BadAzsP_RefreshPanels() end
end

-- ==========================================================
-- SMART HEAL
-- Prioridade de unidade: mouseover (se amigavel) > target (se amigavel) > player
-- Prioridade de spell: Shield (se habilitado) > Flash > Greater > Renew
-- ==========================================================
function BadAzsP_SmartHeal()
    if BadAzs_Sustain then BadAzs_Sustain() end

    local spec = BadAzsP_DetectSpec()
    local profile = BadAzsPriestDB[spec]

    local unit = "player"
    if UnitExists("mouseover") and UnitIsVisible("mouseover") and not UnitIsEnemy("player", "mouseover") then
        unit = "mouseover"
    elseif UnitExists("target") and UnitIsFriend("player", "target") then
        unit = "target"
    end

    local hp, hmax = UnitHealth(unit), UnitHealthMax(unit)
    if not hmax or hmax == 0 then return end
    local pct = (hp / hmax) * 100
    if pct >= 100 then return end

    local spell = nil

    if profile.UseShield and pct <= 90
       and not BadAzsP_UnitHasBuff(unit, "PowerWordShield")
       and not BadAzsP_UnitHasDebuff(unit, "Ability_Priest_WeakenedSoul") then
        spell = "Power Word: Shield"
    elseif pct <= profile.FlashHealBelow then
        spell = "Flash Heal"
    elseif pct <= profile.GreaterHealBelow then
        spell = "Greater Heal"
    elseif pct <= profile.RenewBelow then
        spell = "Renew"
    end

    if not spell then return end

    if unit == "mouseover" then
        BadAzs_ManualMouseover(spell, false)
    elseif unit == "target" then
        CastSpellByName(spell)
    else
        CastSpellByName(spell, 1)
    end
end

function BadAzsP_Heal()
    if IsAltKeyDown() then
        local spec = BadAzsP_DetectSpec()
        local profile = BadAzsPriestDB[spec]
        BadAzs_ManualMouseover(profile.Buff, false)
        return
    end
    BadAzsP_SmartHeal()
end

SLASH_BAPHEAL1 = "/bapheal"
SlashCmdList["BAPHEAL"] = BadAzsP_Heal

-- ==========================================================
-- FABRICA DE PAINEL (formato de livro) - uma instancia por spec
-- ==========================================================
local RefreshFns = {}

function BadAzsP_RefreshPanels()
    local i
    for i = 1, table.getn(RefreshFns) do
        RefreshFns[i]()
    end
end

local function BadAzsP_CreatePanel(specKey, accentColor, specNameField)
    local Panel = CreateFrame("Frame", "BadAzsPriest_Panel_"..specKey, UIParent)
    Panel:SetWidth(620)
    Panel:SetHeight(500)
    Panel:SetPoint("CENTER", 0, 0)
    Panel:SetMovable(true)
    Panel:EnableMouse(true)
    Panel:RegisterForDrag("LeftButton")
    Panel:SetScript("OnDragStart", function() this:StartMoving() end)
    Panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    Panel:SetFrameStrata("DIALOG")
    Panel:Hide()

    local LeftPage = CreateFrame("Frame", nil, Panel)
    LeftPage:SetWidth(300)
    LeftPage:SetHeight(280)
    LeftPage:SetPoint("TOPLEFT", Panel, "TOPLEFT", 0, -60)
    LeftPage:SetBackdrop({
        bgFile = "Interface/QuestFrame/QuestBG",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = false, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local RightPage = CreateFrame("Frame", nil, Panel)
    RightPage:SetWidth(300)
    RightPage:SetHeight(280)
    RightPage:SetPoint("TOPLEFT", Panel, "TOPLEFT", 320, -60)
    RightPage:SetBackdrop({
        bgFile = "Interface/QuestFrame/QuestBG",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = false, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = Panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)

    local closeBtn = CreateFrame("Button", nil, Panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local langBtn = CreateFrame("Button", nil, Panel, "UIPanelButtonTemplate")
    langBtn:SetPoint("TOPLEFT", 8, -10)
    langBtn:SetWidth(44); langBtn:SetHeight(20)

    local specLabel = Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    specLabel:SetPoint("TOP", 0, -40)

    -- ---- ESQUERDA: CONTROLES ----
    local flashSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_FlashSlider", LeftPage, "OptionsSliderTemplate")
    flashSlider:SetPoint("TOP", 0, -20)
    flashSlider:SetWidth(240)
    flashSlider:SetMinMaxValues(0, 100)
    flashSlider:SetValueStep(5)
    getglobal(flashSlider:GetName().."Low"):SetText("0")
    getglobal(flashSlider:GetName().."High"):SetText("100")
    flashSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].FlashHealBelow = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].flashLabel .. ": " .. this:GetValue())
    end)

    local greaterSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_GreaterSlider", LeftPage, "OptionsSliderTemplate")
    greaterSlider:SetPoint("TOP", 0, -70)
    greaterSlider:SetWidth(240)
    greaterSlider:SetMinMaxValues(0, 100)
    greaterSlider:SetValueStep(5)
    getglobal(greaterSlider:GetName().."Low"):SetText("0")
    getglobal(greaterSlider:GetName().."High"):SetText("100")
    greaterSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].GreaterHealBelow = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].greaterLabel .. ": " .. this:GetValue())
    end)

    local renewSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_RenewSlider", LeftPage, "OptionsSliderTemplate")
    renewSlider:SetPoint("TOP", 0, -120)
    renewSlider:SetWidth(240)
    renewSlider:SetMinMaxValues(0, 100)
    renewSlider:SetValueStep(5)
    getglobal(renewSlider:GetName().."Low"):SetText("0")
    getglobal(renewSlider:GetName().."High"):SetText("100")
    renewSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].RenewBelow = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].renewLabel .. ": " .. this:GetValue())
    end)

    local shieldCheck = CreateFrame("CheckButton", nil, LeftPage, "UICheckButtonTemplate")
    shieldCheck:SetPoint("TOPLEFT", 20, -170)
    getglobal(shieldCheck:GetName().."Text"):SetText("")
    local shieldLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shieldLabel:SetPoint("LEFT", shieldCheck, "RIGHT", 4, 0)
    shieldLabel:SetJustifyH("LEFT")
    shieldLabel:SetWidth(200)
    shieldCheck:SetScript("OnClick", function()
        BadAzsPriestDB[specKey].UseShield = (this:GetChecked() == 1)
    end)

    local buffBtn = CreateFrame("Button", nil, LeftPage, "UIPanelButtonTemplate")
    buffBtn:SetPoint("TOP", 0, -218)
    buffBtn:SetWidth(240); buffBtn:SetHeight(22)
    buffBtn:SetScript("OnClick", function()
        BadAzsP_CycleBuff(specKey)
    end)
    local buffLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buffLabel:SetPoint("BOTTOM", buffBtn, "TOP", 0, 4)

    -- ---- DIREITA: EXPLICACOES ----
    local explainFlash = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explainFlash:SetPoint("TOP", 0, -14)
    explainFlash:SetWidth(260); explainFlash:SetJustifyH("LEFT"); explainFlash:SetSpacing(2)

    local explainGreater = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explainGreater:SetPoint("TOP", 0, -70)
    explainGreater:SetWidth(260); explainGreater:SetJustifyH("LEFT"); explainGreater:SetSpacing(2)

    local explainRenew = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explainRenew:SetPoint("TOP", 0, -130)
    explainRenew:SetWidth(260); explainRenew:SetJustifyH("LEFT"); explainRenew:SetSpacing(2)

    local explainShield = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explainShield:SetPoint("TOP", 0, -186)
    explainShield:SetWidth(260); explainShield:SetJustifyH("LEFT"); explainShield:SetSpacing(2)

    local explainBuff = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explainBuff:SetPoint("TOP", 0, -234)
    explainBuff:SetWidth(260); explainBuff:SetJustifyH("LEFT"); explainBuff:SetSpacing(2)

    -- ---- RODAPE: COMANDOS ----
    local divider = Panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOP", 0, -348)
    divider:SetWidth(590); divider:SetHeight(1)
    divider:SetTexture(0.5, 0.5, 0.5, 0.5)

    local cmdHeader = Panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdHeader:SetPoint("TOP", 0, -360)

    local cmdText = Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdText:SetPoint("TOP", 0, -380)
    cmdText:SetWidth(560)
    cmdText:SetJustifyH("LEFT")
    cmdText:SetSpacing(3)

    local function Refresh()
        local L = BadAzsP_L[BadAzsPriestDB.Locale]
        local profile = BadAzsPriestDB[specKey]

        title:SetText(accentColor .. L.title .. " - " .. L[specNameField] .. "|r")
        langBtn:SetText(BadAzsPriestDB.Locale)

        local detected = BadAzsP_DetectSpec()
        local detectedName = L.specHoly
        if detected == "disc" then detectedName = L.specDisc
        elseif detected == "shadow" then detectedName = L.specShadow end
        specLabel:SetText(L.specDetected .. accentColor .. detectedName .. "|r")

        flashSlider:SetValue(profile.FlashHealBelow)
        greaterSlider:SetValue(profile.GreaterHealBelow)
        renewSlider:SetValue(profile.RenewBelow)
        getglobal(flashSlider:GetName().."Text"):SetText(L.flashLabel .. ": " .. profile.FlashHealBelow)
        getglobal(greaterSlider:GetName().."Text"):SetText(L.greaterLabel .. ": " .. profile.GreaterHealBelow)
        getglobal(renewSlider:GetName().."Text"):SetText(L.renewLabel .. ": " .. profile.RenewBelow)

        if profile.UseShield then shieldCheck:SetChecked(1) else shieldCheck:SetChecked(nil) end
        shieldLabel:SetText(L.shieldLabel)

        buffLabel:SetText("|cffffd200" .. L.buffLabel .. "|r")
        buffBtn:SetText(profile.Buff)

        explainFlash:SetText(L.explainFlash)
        explainGreater:SetText(L.explainGreater)
        explainRenew:SetText(L.explainRenew)
        explainShield:SetText(L.explainShield)
        explainBuff:SetText(L.explainBuff)

        cmdHeader:SetText("|cffffd200" .. L.cmdHeader .. "|r")
        local lines = ""
        local i
        for i = 1, table.getn(L.cmdList) do
            if i > 1 then lines = lines .. "\n" end
            lines = lines .. L.cmdList[i]
        end
        cmdText:SetText(lines)
    end

    langBtn:SetScript("OnClick", function()
        if BadAzsPriestDB.Locale == "EN" then BadAzsPriestDB.Locale = "PT" else BadAzsPriestDB.Locale = "EN" end
        BadAzsP_RefreshPanels()
    end)

    Panel:SetScript("OnShow", Refresh)
    table.insert(RefreshFns, Refresh)

    BadAzs_PanelRegistry = BadAzs_PanelRegistry or {}
    BadAzs_PanelRegistry["priest "..specKey] = function()
        if Panel:IsShown() then Panel:Hide() else Panel:Show() end
    end
end

BadAzsP_CreatePanel("holy", "|cffffd200", "specHoly")
BadAzsP_CreatePanel("disc", "|cff69ccf0", "specDisc")
BadAzsP_CreatePanel("shadow", "|cff9482c9", "specShadow")

BadAzs_PanelRegistry = BadAzs_PanelRegistry or {}
BadAzs_PanelRegistry["priest"] = function()
    DEFAULT_CHAT_FRAME:AddMessage("|cff355E3B[BadAzs]|r Uso: /badazs priest holy | disc | shadow")
end
