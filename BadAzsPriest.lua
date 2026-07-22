-- [[ [|cff355E3BB|r]adAzs |cffffffffPriest|r ]]
-- Author:  ThePeregris
-- Version: 2.0 (QuickHeal-style rank engine + party/raid scan + /bapbuff)
-- Target:  Vanilla/Classic WoW (1.12 / LUA 5.0)
-- Requires: BadAzs Core (apenas utilitarios universais: ManualMouseover/Ready/GetMana/Vision/Sustain)
--
-- Referencias analisadas (design, nao codigo portado 1:1):
--   Rinse (Otari98)      -> padrao de mapear tipo de debuff -> spell que remove
--   BadAzsPriest/QuickHeal -> conceito de escolher heal pela gravidade do dano + mana
--   BadAzsPriest/BeneCast  -> conceito de smart-buff no mouseover com tecla modificadora

local BadAzsPriestVersion = "|cffffffff[BadAzsPriest v2.0]|r"

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
        minRankLabel  = "Min rank",
        maxRankLabel  = "Max rank (0 = no limit)",
        healBonusLabel = "Detected +Healing",
        blacklistLabel = "Never-dispel list (comma separated)",
        explainFlash   = "Below this HP%, the target is in danger - Flash Heal is used for its fast cast time, even though it costs more mana per point healed.",
        explainGreater = "Below this HP% (but above the Flash Heal line), Greater Heal is used - slow cast, but the most mana-efficient big heal.",
        explainRenew   = "Below this HP% (but above both lines above), Renew is applied instead - a cheap heal-over-time to top the target off.",
        explainShield  = "If enabled, Power Word: Shield is cast first whenever the target lacks it and isn't under Weakened Soul, before any direct heal lands.",
        explainBuff    = "/bapbuff: buffs/dispels the party (or raid on ALT) automatically. Click here to pick which buff it casts on whoever is missing it.",
        explainDownrank = "Limits which spell ranks Smart Heal is allowed to pick, no matter how small or big the deficit is. Useful to avoid a silly low rank in real content, or overspending mana while leveling.",
        explainBlacklist = "Debuffs listed here are NEVER removed by /bapbuff or the offensive dispel, even if they're a valid Magic/Disease type. Type exact names, separated by commas, then press Enter.",
        cmdHeader     = "Macros",
        cmdList = {
            "/bapheal - Smart Heal (party, or raid on ALT)",
            "/bapbuff - Smart Buff/Dispel/Shield (party, or raid on ALT)",
            "Hold CTRL on /bapbuff - Also Shield Rage users (Warriors)",
            "Enemy targeted: /bapheal heals its target, /bapbuff dispels it",
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
        minRankLabel  = "Rank minimo",
        maxRankLabel  = "Rank maximo (0 = sem limite)",
        healBonusLabel = "+Healing detectado",
        blacklistLabel = "Lista de nunca-dispelar (separado por virgula)",
        explainFlash   = "Abaixo dessa porcentagem de HP, o alvo esta em perigo - Flash Heal e usado pelo cast rapido, mesmo custando mais mana por ponto curado.",
        explainGreater = "Abaixo dessa porcentagem (mas acima da linha do Flash Heal), Greater Heal e usado - cast lento, mas o heal grande mais eficiente em mana.",
        explainRenew   = "Abaixo dessa porcentagem (mas acima das duas linhas acima), Renew e aplicado - um heal ao longo do tempo barato pra completar o alvo.",
        explainShield  = "Se ativado, Power Word: Shield e lancado primeiro sempre que o alvo nao tiver o escudo e nao estiver com Weakened Soul, antes de qualquer heal direto.",
        explainBuff    = "/bapbuff: buffa/dispela a party (ou raid no ALT) automaticamente. Clique aqui pra escolher qual buff ele lanca em quem estiver sem.",
        explainDownrank = "Limita quais ranks o Smart Heal pode escolher, nao importa o tamanho do deficit. Util pra evitar um rank ridiculo em conteudo serio, ou gastar mana demais enquanto levela.",
        explainBlacklist = "Debuffs listados aqui NUNCA sao removidos pelo /bapbuff ou pelo dispel ofensivo, mesmo que sejam Magic/Disease de verdade. Digite os nomes exatos, separados por virgula, e aperte Enter.",
        cmdHeader     = "Macros",
        cmdList = {
            "/bapheal - Smart Heal (party, ou raid no ALT)",
            "/bapbuff - Smart Buff/Dispel/Shield (party, ou raid no ALT)",
            "Segure CTRL no /bapbuff - Tambem da Shield em quem tem Rage",
            "Target inimigo: /bapheal cura o alvo dele, /bapbuff dispela ele",
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
    if not BadAzsPriestDB.DispelBlacklist then BadAzsPriestDB.DispelBlacklist = {} end

    if not BadAzsPriestDB.holy then
        BadAzsPriestDB.holy = { FlashHealBelow = 25, GreaterHealBelow = 55, RenewBelow = 90, UseShield = false, Buff = "Power Word: Fortitude", BuffIndex = 1, MinRank = 1, MaxRank = 0 }
    end
    if not BadAzsPriestDB.disc then
        BadAzsPriestDB.disc = { FlashHealBelow = 20, GreaterHealBelow = 45, RenewBelow = 90, UseShield = true, Buff = "Power Word: Shield", BuffIndex = 4, MinRank = 1, MaxRank = 0 }
    end
    if not BadAzsPriestDB.shadow then
        BadAzsPriestDB.shadow = { FlashHealBelow = 35, GreaterHealBelow = 60, RenewBelow = 90, UseShield = false, Buff = "Power Word: Fortitude", BuffIndex = 1, MinRank = 1, MaxRank = 0 }
    end

    -- Migracao: perfis salvos antes do motor de rank existir nao tem esses campos
    local _, specKey
    for _, specKey in ipairs({ "holy", "disc", "shadow" }) do
        if not BadAzsPriestDB[specKey].MinRank then BadAzsPriestDB[specKey].MinRank = 1 end
        if not BadAzsPriestDB[specKey].MaxRank then BadAzsPriestDB[specKey].MaxRank = 0 end
    end

    DEFAULT_CHAT_FRAME:AddMessage(BadAzsPriestVersion .. " " .. BadAzsP_L[BadAzsPriestDB.Locale].loaded)
end)

-- ==========================================================
-- MOTOR DE HEAL: tabelas de rank + healneed (estilo QuickHeal)
-- Valores de heal/mana por rank vindos direto do QuickHealPriest.lua
-- (BasePriest/QuickHeal no repo de referencia) - nao inventados aqui.
-- ==========================================================
local RANKS_LesserHeal = { {heal=53,mana=0}, {heal=84,mana=45}, {heal=154,mana=75} }
local RANKS_Heal = { {heal=330,mana=155}, {heal=476,mana=205}, {heal=624,mana=255}, {heal=667,mana=305} }
local RANKS_GreaterHeal = { {heal=838,mana=351}, {heal=1066,mana=432}, {heal=1328,mana=517}, {heal=1632,mana=622}, {heal=1768,mana=674} }
local RANKS_FlashHeal = { {heal=225,mana=125}, {heal=297,mana=155}, {heal=319,mana=185}, {heal=387,mana=215}, {heal=498,mana=265}, {heal=618,mana=315}, {heal=769,mana=380} }
local RANKS_Renew = { {heal=45,mana=0}, {heal=100,mana=65}, {heal=175,mana=105}, {heal=245,mana=140}, {heal=270,mana=170}, {heal=340,mana=205}, {heal=435,mana=250}, {heal=555,mana=305}, {heal=690,mana=365}, {heal=825,mana=410} }

CreateFrame("GameTooltip", "BadAzsPriest_TooltipScanner", nil, "GameTooltipTemplate")
BadAzsPriest_TooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Soma o "+X Healing" de cada peca de equipamento, via tooltip-scan
-- (nao existe API direta pra isso em Lua vanilla)
local function BadAzsP_GetHealingBonus()
    local bonus = 0
    local slot
    for slot = 1, 18 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            BadAzsPriest_TooltipScanner:ClearLines()
            BadAzsPriest_TooltipScanner:SetInventoryItem("player", slot)
            local i
            for i = 1, 12 do
                local region = getglobal("BadAzsPriest_TooltipScannerTextLeft"..i)
                if region then
                    local text = region:GetText()
                    if text and string.find(text, "ealing") then
                        local _, _, num = string.find(text, "(%d+)")
                        if num then bonus = bonus + tonumber(num) end
                    end
                end
            end
        end
    end
    return bonus
end

-- Escolhe o rank MINIMO que cobre o healneed, respeitando mana disponivel
-- e limites de downrank (minRank/maxRank, 0 = sem limite maximo)
local function BadAzsP_PickRank(rankTable, healneed, manaLeft, healBonus, minRank, maxRank)
    local n = table.getn(rankTable)
    if not minRank or minRank < 1 then minRank = 1 end
    if not maxRank or maxRank == 0 or maxRank > n then maxRank = n end

    local chosen = nil
    local i
    for i = minRank, maxRank do
        local r = rankTable[i]
        if manaLeft >= r.mana then
            chosen = i
            if healneed <= (r.heal + healBonus) then break end
        end
    end
    return chosen
end

-- Decide o TIPO de heal pelos sliders do perfil (igual antes) e o RANK pelo
-- healneed real (novo - antes sempre castava rank maximo)
local function BadAzsP_ChooseHealRank(healType, healneed, manaLeft, healBonus, profile)
    local minRank, maxRank = profile.MinRank or 1, profile.MaxRank or 0
    local table_ = RANKS_FlashHeal
    if healType == "Greater Heal" then table_ = RANKS_GreaterHeal
    elseif healType == "Renew" then table_ = RANKS_Renew
    elseif healType == "Lesser Heal" then table_ = RANKS_LesserHeal end

    local rank = BadAzsP_PickRank(table_, healneed, manaLeft, healBonus, minRank, maxRank)
    if not rank then return nil end
    return healType .. "(Rank " .. rank .. ")"
end

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
-- Varre uma lista de units, retorna quem tem o MAIOR deficit de HP (mais ferido).
-- Ignora quem ja esta morto ou fora de alcance de dados (sem HP valido).
local function BadAzsP_FindMostWoundedIn(units)
    local bestUnit, bestDeficit = nil, -1
    local i
    for i = 1, table.getn(units) do
        local u = units[i]
        if UnitExists(u) and not UnitIsDead(u) then
            local hp, hmax = UnitHealth(u), UnitHealthMax(u)
            if hmax and hmax > 0 then
                local deficit = 100 - ((hp / hmax) * 100)
                if deficit > bestDeficit then
                    bestDeficit = deficit
                    bestUnit = u
                end
            end
        end
    end
    return bestUnit, bestDeficit
end

local BadAzsP_PartyUnits = { "player", "party1", "party2", "party3", "party4" }
local BadAzsP_RaidUnits = { "player" }
do
    local i
    for i = 1, 40 do table.insert(BadAzsP_RaidUnits, "raid"..i) end
end

-- useRaid = true varre a raid inteira, senao so a party
local function BadAzsP_FindMostWounded(useRaid)
    if useRaid then return BadAzsP_FindMostWoundedIn(BadAzsP_RaidUnits) end
    return BadAzsP_FindMostWoundedIn(BadAzsP_PartyUnits)
end

function BadAzsP_SmartHeal(useRaid)
    if BadAzs_Sustain then BadAzs_Sustain() end

    local spec = BadAzsP_DetectSpec()
    local profile = BadAzsPriestDB[spec]

    local unit, deficit

    -- Target atual e inimigo: cura quem ELE esta atacando, nao varre grupo
    if UnitExists("target") and UnitIsEnemy("player", "target") and UnitExists("targettarget") then
        local hp, hmax = UnitHealth("targettarget"), UnitHealthMax("targettarget")
        if hmax and hmax > 0 and not UnitIsDead("targettarget") then
            unit = "targettarget"
            deficit = 100 - ((hp / hmax) * 100)
        end
    end

    if not unit then
        unit, deficit = BadAzsP_FindMostWounded(useRaid)
    end

    if not unit or deficit <= 0 then return end -- ninguem precisa de cura

    local pct = 100 - deficit
    local hmax = UnitHealthMax(unit)
    local healneed = hmax * (deficit / 100)
    local manaLeft = UnitMana("player")
    local healBonus = BadAzsP_GetHealingBonus()

    local spellToCast = nil

    if profile.UseShield and pct <= 90
       and not BadAzsP_UnitHasBuff(unit, "PowerWordShield")
       and not BadAzsP_UnitHasDebuff(unit, "Ability_Priest_WeakenedSoul") then
        spellToCast = "Power Word: Shield"
    elseif pct <= profile.FlashHealBelow then
        spellToCast = BadAzsP_ChooseHealRank("Flash Heal", healneed, manaLeft, healBonus, profile)
    elseif pct <= profile.GreaterHealBelow then
        spellToCast = BadAzsP_ChooseHealRank("Greater Heal", healneed, manaLeft, healBonus, profile)
    elseif pct <= profile.RenewBelow then
        spellToCast = BadAzsP_ChooseHealRank("Renew", healneed, manaLeft, healBonus, profile)
    end

    if not spellToCast then return end -- tipo indicado mas sem rank que cubra a mana disponivel

    if unit == "player" then
        CastSpellByName(spellToCast, 1)
    else
        -- troca de alvo, casta, volta pro alvo anterior
        TargetUnit(unit)
        CastSpellByName(spellToCast)
        TargetLastTarget()
    end
end

-- ALT = mesma logica, varrendo a RAID em vez da party
function BadAzsP_Heal()
    BadAzsP_SmartHeal(IsAltKeyDown())
end

SLASH_BAPHEAL1 = "/bapheal"
SlashCmdList["BAPHEAL"] = BadAzsP_Heal

-- ==========================================================
-- SMART BUFF / DISPEL / SHIELD (/bapbuff)
-- ==========================================================

-- Pega o NOME real de um buff/debuff via tooltip-scan (nao confiar em
-- textura adivinhada - nomes de buff configuraveis pelo usuario no painel)
local function BadAzsP_GetBuffName(unit, i)
    BadAzsPriest_TooltipScanner:ClearLines()
    BadAzsPriest_TooltipScanner:SetUnitBuff(unit, i)
    local region = getglobal("BadAzsPriest_TooltipScannerTextLeft1")
    return region and region:GetText() or nil
end

local function BadAzsP_GetDebuffName(unit, i)
    BadAzsPriest_TooltipScanner:ClearLines()
    BadAzsPriest_TooltipScanner:SetUnitDebuff(unit, i)
    local region = getglobal("BadAzsPriest_TooltipScannerTextLeft1")
    return region and region:GetText() or nil
end

local function BadAzsP_UnitHasBuffNamed(unit, spellName)
    local i = 1
    while UnitBuff(unit, i) do
        if BadAzsP_GetBuffName(unit, i) == spellName then return true end
        i = i + 1
    end
    return false
end

-- Primeiro debuff do unit que NAO esta na blacklist (nome, nao texture)
local function BadAzsP_FirstDispellableDebuff(unit)
    local i = 1
    while UnitDebuff(unit, i) do
        local name = BadAzsP_GetDebuffName(unit, i)
        if name and not BadAzsP_IsDispelBlacklisted(name) then
            return name
        end
        i = i + 1
    end
    return nil
end

-- Rage = recurso do Warrior. Shield reduz a geracao de rage deles (absorve
-- o dano que geraria rage), entao por padrao NAO shieldamos Warriors, a
-- menos que CTRL esteja segurado (override manual explicito).
local function BadAzsP_UnitHasRage(unit)
    local class = UnitClass(unit)
    return class == "Warrior"
end

function BadAzsP_IsDispelBlacklisted(name)
    local list = BadAzsPriestDB.DispelBlacklist
    if not list then return false end
    local i
    for i = 1, table.getn(list) do
        if list[i] == name then return true end
    end
    return false
end

-- Split/Join de string separada por virgula pra editar a blacklist via
-- EditBox (Lua 5.0 nao tem string.gmatch, entao faz na mao com string.find)
local function BadAzsP_SplitList(str)
    local result = {}
    local pos = 1
    while true do
        local commaPos = string.find(str, ",", pos, true)
        local piece
        if commaPos then
            piece = string.sub(str, pos, commaPos - 1)
            pos = commaPos + 1
        else
            piece = string.sub(str, pos)
        end
        local _, _, trimmed = string.find(piece, "^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(result, trimmed)
        end
        if not commaPos then break end
    end
    return result
end

local function BadAzsP_JoinList(list)
    local str = ""
    local i
    for i = 1, table.getn(list) do
        if i > 1 then str = str .. ", " end
        str = str .. list[i]
    end
    return str
end

local function BadAzsP_CastOn(unit, spell, extraOnSelf)
    if unit == "player" then
        CastSpellByName(spell, extraOnSelf and 1 or nil)
    else
        TargetUnit(unit)
        CastSpellByName(spell)
        TargetLastTarget()
    end
end

function BadAzsP_SmartBuff(useRaid)
    local spec = BadAzsP_DetectSpec()
    local profile = BadAzsPriestDB[spec]

    -- Target inimigo: dispel ofensivo (remove um buff magico do inimigo)
    if UnitExists("target") and UnitIsEnemy("player", "target") then
        CastSpellByName("Dispel Magic")
        return
    end

    local units = useRaid and BadAzsP_RaidUnits or BadAzsP_PartyUnits
    local i

    -- 1) Dispel tem prioridade: primeiro que tiver debuff nao-blacklistado
    -- NOTA v1: so tenta Dispel Magic (nao classificamos Disease separado
    -- ainda - ver limitacoes no resumo). O jogo recusa sozinho se o debuff
    -- nao for do tipo certo, entao isso e seguro de tentar.
    for i = 1, table.getn(units) do
        local u = units[i]
        if UnitExists(u) and not UnitIsDead(u) then
            local debuffName = BadAzsP_FirstDispellableDebuff(u)
            if debuffName then
                BadAzsP_CastOn(u, "Dispel Magic", true)
                return
            end
        end
    end

    -- 2) Shield: quem nao tem, pulando quem usa Rage a menos que CTRL
    if profile.UseShield then
        for i = 1, table.getn(units) do
            local u = units[i]
            if UnitExists(u) and not UnitIsDead(u) then
                local hasShield = BadAzsP_UnitHasBuff(u, "PowerWordShield")
                local weakened = BadAzsP_UnitHasDebuff(u, "Ability_Priest_WeakenedSoul")
                local skipRage = BadAzsP_UnitHasRage(u) and not IsControlKeyDown()
                if not hasShield and not weakened and not skipRage then
                    BadAzsP_CastOn(u, "Power Word: Shield", true)
                    return
                end
            end
        end
    end

    -- 3) Buff: quem nao tem o buff configurado no perfil ativo
    for i = 1, table.getn(units) do
        local u = units[i]
        if UnitExists(u) and not UnitIsDead(u) then
            if not BadAzsP_UnitHasBuffNamed(u, profile.Buff) then
                BadAzsP_CastOn(u, profile.Buff, true)
                return
            end
        end
    end
end

function BadAzsP_BuffCmd()
    BadAzsP_SmartBuff(IsAltKeyDown())
end

SLASH_BAPBUFF1 = "/bapbuff"
SlashCmdList["BAPBUFF"] = BadAzsP_BuffCmd

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
    Panel:SetHeight(650)
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
    LeftPage:SetHeight(430)
    LeftPage:SetPoint("TOPLEFT", Panel, "TOPLEFT", 0, -60)
    LeftPage:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local RightPage = CreateFrame("Frame", nil, Panel)
    RightPage:SetWidth(300)
    RightPage:SetHeight(430)
    RightPage:SetPoint("TOPLEFT", Panel, "TOPLEFT", 320, -60)
    RightPage:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
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

    local shieldCheck = CreateFrame("CheckButton", "BadAzsP_"..specKey.."_ShieldCheck", LeftPage, "UICheckButtonTemplate")
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

    local minRankSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_MinRankSlider", LeftPage, "OptionsSliderTemplate")
    minRankSlider:SetPoint("TOP", 0, -250)
    minRankSlider:SetWidth(240)
    minRankSlider:SetMinMaxValues(1, 10)
    minRankSlider:SetValueStep(1)
    getglobal(minRankSlider:GetName().."Low"):SetText("1")
    getglobal(minRankSlider:GetName().."High"):SetText("10")
    minRankSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].MinRank = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].minRankLabel .. ": " .. this:GetValue())
    end)

    local maxRankSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_MaxRankSlider", LeftPage, "OptionsSliderTemplate")
    maxRankSlider:SetPoint("TOP", 0, -294)
    maxRankSlider:SetWidth(240)
    maxRankSlider:SetMinMaxValues(0, 10)
    maxRankSlider:SetValueStep(1)
    getglobal(maxRankSlider:GetName().."Low"):SetText("0")
    getglobal(maxRankSlider:GetName().."High"):SetText("10")
    maxRankSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].MaxRank = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].maxRankLabel .. ": " .. this:GetValue())
    end)

    local healBonusLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healBonusLabel:SetPoint("TOP", 0, -330)

    local blacklistLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blacklistLabel:SetPoint("TOP", 0, -354)
    blacklistLabel:SetWidth(260)

    local blacklistBox = CreateFrame("EditBox", "BadAzsP_"..specKey.."_BlacklistBox", LeftPage, "InputBoxTemplate")
    blacklistBox:SetPoint("TOP", 0, -378)
    blacklistBox:SetWidth(220)
    blacklistBox:SetHeight(20)
    blacklistBox:SetAutoFocus(false)
    blacklistBox:SetScript("OnEnterPressed", function()
        BadAzsPriestDB.DispelBlacklist = BadAzsP_SplitList(this:GetText())
        this:ClearFocus()
        BadAzsP_RefreshPanels()
    end)
    blacklistBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

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

    local explainDownrank = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explainDownrank:SetPoint("TOP", 0, -278)
    explainDownrank:SetWidth(260); explainDownrank:SetJustifyH("LEFT"); explainDownrank:SetSpacing(2)

    local explainBlacklist = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    explainBlacklist:SetPoint("TOP", 0, -340)
    explainBlacklist:SetWidth(260); explainBlacklist:SetJustifyH("LEFT"); explainBlacklist:SetSpacing(2)

    -- ---- RODAPE: COMANDOS ----
    local divider = Panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOP", 0, -478)
    divider:SetWidth(590); divider:SetHeight(1)
    divider:SetTexture(0.5, 0.5, 0.5, 0.5)

    local cmdHeader = Panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdHeader:SetPoint("TOP", 0, -490)

    local cmdText = Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdText:SetPoint("TOP", 0, -510)
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

        minRankSlider:SetValue(profile.MinRank or 1)
        maxRankSlider:SetValue(profile.MaxRank or 0)
        getglobal(minRankSlider:GetName().."Text"):SetText(L.minRankLabel .. ": " .. (profile.MinRank or 1))
        getglobal(maxRankSlider:GetName().."Text"):SetText(L.maxRankLabel .. ": " .. (profile.MaxRank or 0))

        healBonusLabel:SetText(L.healBonusLabel .. ": +" .. BadAzsP_GetHealingBonus())

        blacklistLabel:SetText("|cffffd200" .. L.blacklistLabel .. "|r")
        blacklistBox:SetText(BadAzsP_JoinList(BadAzsPriestDB.DispelBlacklist or {}))

        explainFlash:SetText(L.explainFlash)
        explainGreater:SetText(L.explainGreater)
        explainRenew:SetText(L.explainRenew)
        explainShield:SetText(L.explainShield)
        explainBuff:SetText(L.explainBuff)
        explainDownrank:SetText(L.explainDownrank)
        explainBlacklist:SetText(L.explainBlacklist)

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
