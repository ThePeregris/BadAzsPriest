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
        buffLabel     = "Buffs to monitor",
        fortLabel     = "Power Word: Fortitude",
        spiritLabel   = "Divine Spirit",
        shadowProtLabel = "Shadow Protection",
        minRankLabel  = "Min rank",
        maxRankLabel  = "Max rank (0 = no limit)",
        healBonusLabel = "Detected +Healing",
        blacklistLabel = "Never-dispel list (comma separated)",
        explainFlash   = "Below this HP%, the target is in danger - Flash Heal is used for its fast cast time, even though it costs more mana per point healed.",
        explainGreater = "Below this HP% (but above the Flash Heal line), Greater Heal is used - slow cast, but the most mana-efficient big heal.",
        explainRenew   = "Below this HP% (but above both lines above), Renew is applied instead - a cheap heal-over-time to top the target off.",
        explainShield  = "If enabled, Power Word: Shield is cast first whenever the target lacks it and isn't under Weakened Soul, before any direct heal lands.",
        explainBuff    = "Each buff below is applied automatically to whoever in the party (or raid on ALT) is missing it. Shield follows the same list, but skips Rage users (Warriors) unless CTRL is held.",
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
    BR = {
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
        buffLabel     = "Buffs monitorados",
        fortLabel     = "Power Word: Fortitude",
        spiritLabel   = "Divine Spirit",
        shadowProtLabel = "Shadow Protection",
        minRankLabel  = "Rank minimo",
        maxRankLabel  = "Rank maximo (0 = sem limite)",
        healBonusLabel = "+Healing detectado",
        blacklistLabel = "Lista de nunca-dispelar (separado por virgula)",
        explainFlash   = "Abaixo dessa porcentagem de HP, o alvo esta em perigo - Flash Heal e usado pelo cast rapido, mesmo custando mais mana por ponto curado.",
        explainGreater = "Abaixo dessa porcentagem (mas acima da linha do Flash Heal), Greater Heal e usado - cast lento, mas o heal grande mais eficiente em mana.",
        explainRenew   = "Abaixo dessa porcentagem (mas acima das duas linhas acima), Renew e aplicado - um heal ao longo do tempo barato pra completar o alvo.",
        explainShield  = "Se ativado, Power Word: Shield e lancado primeiro sempre que o alvo nao tiver o escudo e nao estiver com Weakened Soul, antes de qualquer heal direto.",
        explainBuff    = "Cada buff abaixo e aplicado automaticamente em quem na party (ou raid no ALT) estiver sem. Shield entra na mesma lista, mas pula quem usa Rage (Warriors) a menos que CTRL esteja segurado.",
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
        BadAzsPriestDB.holy = { FlashHealBelow = 25, GreaterHealBelow = 55, RenewBelow = 90, UseShield = false, MonitorFortitude = true, MonitorSpirit = true, MonitorShadowProt = false, MinRank = 1, MaxRank = 0 }
    end
    if not BadAzsPriestDB.disc then
        BadAzsPriestDB.disc = { FlashHealBelow = 20, GreaterHealBelow = 45, RenewBelow = 90, UseShield = true, MonitorFortitude = true, MonitorSpirit = true, MonitorShadowProt = false, MinRank = 1, MaxRank = 0 }
    end
    if not BadAzsPriestDB.shadow then
        BadAzsPriestDB.shadow = { FlashHealBelow = 35, GreaterHealBelow = 60, RenewBelow = 90, UseShield = false, MonitorFortitude = true, MonitorSpirit = true, MonitorShadowProt = false, MinRank = 1, MaxRank = 0 }
    end

    -- Migracao: perfis salvos antes do motor de rank / checklist de buff existir
    local _, specKey
    for _, specKey in ipairs({ "holy", "disc", "shadow" }) do
        if not BadAzsPriestDB[specKey].MinRank then BadAzsPriestDB[specKey].MinRank = 1 end
        if not BadAzsPriestDB[specKey].MaxRank then BadAzsPriestDB[specKey].MaxRank = 0 end
        if BadAzsPriestDB[specKey].MonitorFortitude == nil then BadAzsPriestDB[specKey].MonitorFortitude = true end
        if BadAzsPriestDB[specKey].MonitorSpirit == nil then BadAzsPriestDB[specKey].MonitorSpirit = true end
        if BadAzsPriestDB[specKey].MonitorShadowProt == nil then BadAzsPriestDB[specKey].MonitorShadowProt = false end
        -- Campos antigos do sistema de ciclo de buff (agora substituido pela checklist)
        BadAzsPriestDB[specKey].Buff = nil
        BadAzsPriestDB[specKey].BuffIndex = nil
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
-- Pega o NOME real de um buff/debuff via tooltip-scan (mais confiavel que
-- adivinhar fragmento de textura - usado pras checagens de Shield/Buff)
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

local function BadAzsP_UnitHasDebuffNamed(unit, spellName)
    local i = 1
    while UnitDebuff(unit, i) do
        if BadAzsP_GetDebuffName(unit, i) == spellName then return true end
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

-- Checklist de buffs monitorados no /bapbuff - cada um tem seu proprio
-- checkbox no painel (flag = campo booleano no perfil da spec ativa).
-- Shield entra na mesma checklist mas com a regra especial de Rage/CTRL.
local BadAzsP_BuffChecklist = {
    { name = "Power Word: Fortitude", flag = "MonitorFortitude" },
    { name = "Divine Spirit", flag = "MonitorSpirit" },
    { name = "Shadow Protection", flag = "MonitorShadowProt" },
    { name = "Power Word: Shield", flag = "UseShield", rageGated = true },
}

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
       and not BadAzsP_UnitHasBuffNamed(unit, "Power Word: Shield")
       and not BadAzsP_UnitHasDebuffNamed(unit, "Weakened Soul") then
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

    -- 2) Checklist de buffs: pra cada buff habilitado (nessa ordem), acha o
    -- primeiro do grupo que ainda nao tem e aplica. Shield tem a regra extra
    -- de Rage/CTRL - pra quem usa Rage, so aplica com CTRL segurado.
    local b
    for b = 1, table.getn(BadAzsP_BuffChecklist) do
        local entry = BadAzsP_BuffChecklist[b]
        if profile[entry.flag] then
            for i = 1, table.getn(units) do
                local u = units[i]
                if UnitExists(u) and not UnitIsDead(u) then
                    local needsIt = not BadAzsP_UnitHasBuffNamed(u, entry.name)
                    if entry.rageGated then
                        local weakened = BadAzsP_UnitHasDebuffNamed(u, "Weakened Soul")
                        local skipRage = BadAzsP_UnitHasRage(u) and not IsControlKeyDown()
                        needsIt = needsIt and not weakened and not skipRage
                    end
                    if needsIt then
                        BadAzsP_CastOn(u, entry.name, true)
                        return
                    end
                end
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
    -- Lua 5.0 tem limite de 32 upvalues por funcao. Com tantos widgets, o
    -- Refresh() abaixo estourava esse limite referenciando cada um como
    -- variavel local separada. Solucao padrao: guardar tudo numa tabela so
    -- (w), que conta como UM upvalue so, nao importa quantos campos tenha.
    local w = {}

    local Panel = CreateFrame("Frame", "BadAzsPriest_Panel_"..specKey, UIParent)
    Panel:SetWidth(620)
    Panel:SetHeight(690)
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
    LeftPage:SetHeight(470)
    LeftPage:SetPoint("TOPLEFT", Panel, "TOPLEFT", 0, -60)
    LeftPage:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local RightPage = CreateFrame("Frame", nil, Panel)
    RightPage:SetWidth(300)
    RightPage:SetHeight(470)
    RightPage:SetPoint("TOPLEFT", Panel, "TOPLEFT", 320, -60)
    RightPage:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    w.title = Panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    w.title:SetPoint("TOP", 0, -16)

    local closeBtn = CreateFrame("Button", nil, Panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    w.langBtn = CreateFrame("Button", nil, Panel, "UIPanelButtonTemplate")
    w.langBtn:SetPoint("TOPLEFT", 8, -10)
    w.langBtn:SetWidth(44); w.langBtn:SetHeight(20)

    w.specLabel = Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    w.specLabel:SetPoint("TOP", 0, -40)

    -- ---- ESQUERDA: CONTROLES ----
    w.flashSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_FlashSlider", LeftPage, "OptionsSliderTemplate")
    w.flashSlider:SetPoint("TOP", 0, -20)
    w.flashSlider:SetWidth(240)
    w.flashSlider:SetMinMaxValues(0, 100)
    w.flashSlider:SetValueStep(5)
    getglobal(w.flashSlider:GetName().."Low"):SetText("0")
    getglobal(w.flashSlider:GetName().."High"):SetText("100")
    w.flashSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].FlashHealBelow = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].flashLabel .. ": " .. this:GetValue())
    end)

    w.greaterSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_GreaterSlider", LeftPage, "OptionsSliderTemplate")
    w.greaterSlider:SetPoint("TOP", 0, -70)
    w.greaterSlider:SetWidth(240)
    w.greaterSlider:SetMinMaxValues(0, 100)
    w.greaterSlider:SetValueStep(5)
    getglobal(w.greaterSlider:GetName().."Low"):SetText("0")
    getglobal(w.greaterSlider:GetName().."High"):SetText("100")
    w.greaterSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].GreaterHealBelow = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].greaterLabel .. ": " .. this:GetValue())
    end)

    w.renewSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_RenewSlider", LeftPage, "OptionsSliderTemplate")
    w.renewSlider:SetPoint("TOP", 0, -120)
    w.renewSlider:SetWidth(240)
    w.renewSlider:SetMinMaxValues(0, 100)
    w.renewSlider:SetValueStep(5)
    getglobal(w.renewSlider:GetName().."Low"):SetText("0")
    getglobal(w.renewSlider:GetName().."High"):SetText("100")
    w.renewSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].RenewBelow = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].renewLabel .. ": " .. this:GetValue())
    end)

    w.shieldCheck = CreateFrame("CheckButton", "BadAzsP_"..specKey.."_ShieldCheck", LeftPage, "UICheckButtonTemplate")
    w.shieldCheck:SetPoint("TOPLEFT", 20, -170)
    getglobal(w.shieldCheck:GetName().."Text"):SetText("")
    w.shieldLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.shieldLabel:SetPoint("LEFT", w.shieldCheck, "RIGHT", 4, 0)
    w.shieldLabel:SetJustifyH("LEFT")
    w.shieldLabel:SetWidth(200)
    w.shieldCheck:SetScript("OnClick", function()
        BadAzsPriestDB[specKey].UseShield = (this:GetChecked() == 1)
    end)

    w.fortCheck = CreateFrame("CheckButton", "BadAzsP_"..specKey.."_FortCheck", LeftPage, "UICheckButtonTemplate")
    w.fortCheck:SetPoint("TOPLEFT", 20, -196)
    getglobal(w.fortCheck:GetName().."Text"):SetText("")
    w.fortLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.fortLabel:SetPoint("LEFT", w.fortCheck, "RIGHT", 4, 0)
    w.fortLabel:SetJustifyH("LEFT"); w.fortLabel:SetWidth(200)
    w.fortCheck:SetScript("OnClick", function()
        BadAzsPriestDB[specKey].MonitorFortitude = (this:GetChecked() == 1)
    end)

    w.spiritCheck = CreateFrame("CheckButton", "BadAzsP_"..specKey.."_SpiritCheck", LeftPage, "UICheckButtonTemplate")
    w.spiritCheck:SetPoint("TOPLEFT", 20, -220)
    getglobal(w.spiritCheck:GetName().."Text"):SetText("")
    w.spiritLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.spiritLabel:SetPoint("LEFT", w.spiritCheck, "RIGHT", 4, 0)
    w.spiritLabel:SetJustifyH("LEFT"); w.spiritLabel:SetWidth(200)
    w.spiritCheck:SetScript("OnClick", function()
        BadAzsPriestDB[specKey].MonitorSpirit = (this:GetChecked() == 1)
    end)

    w.shadowProtCheck = CreateFrame("CheckButton", "BadAzsP_"..specKey.."_ShadowProtCheck", LeftPage, "UICheckButtonTemplate")
    w.shadowProtCheck:SetPoint("TOPLEFT", 20, -244)
    getglobal(w.shadowProtCheck:GetName().."Text"):SetText("")
    w.shadowProtLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.shadowProtLabel:SetPoint("LEFT", w.shadowProtCheck, "RIGHT", 4, 0)
    w.shadowProtLabel:SetJustifyH("LEFT"); w.shadowProtLabel:SetWidth(200)
    w.shadowProtCheck:SetScript("OnClick", function()
        BadAzsPriestDB[specKey].MonitorShadowProt = (this:GetChecked() == 1)
    end)

    w.buffChecklistHeader = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    w.buffChecklistHeader:SetPoint("BOTTOM", w.fortCheck, "TOP", 90, 6)

    w.minRankSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_MinRankSlider", LeftPage, "OptionsSliderTemplate")
    w.minRankSlider:SetPoint("TOP", 0, -280)
    w.minRankSlider:SetWidth(240)
    w.minRankSlider:SetMinMaxValues(1, 10)
    w.minRankSlider:SetValueStep(1)
    getglobal(w.minRankSlider:GetName().."Low"):SetText("1")
    getglobal(w.minRankSlider:GetName().."High"):SetText("10")
    w.minRankSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].MinRank = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].minRankLabel .. ": " .. this:GetValue())
    end)

    w.maxRankSlider = CreateFrame("Slider", "BadAzsP_"..specKey.."_MaxRankSlider", LeftPage, "OptionsSliderTemplate")
    w.maxRankSlider:SetPoint("TOP", 0, -334)
    w.maxRankSlider:SetWidth(240)
    w.maxRankSlider:SetMinMaxValues(0, 10)
    w.maxRankSlider:SetValueStep(1)
    getglobal(w.maxRankSlider:GetName().."Low"):SetText("0")
    getglobal(w.maxRankSlider:GetName().."High"):SetText("10")
    w.maxRankSlider:SetScript("OnValueChanged", function()
        BadAzsPriestDB[specKey].MaxRank = this:GetValue()
        getglobal(this:GetName().."Text"):SetText(BadAzsP_L[BadAzsPriestDB.Locale].maxRankLabel .. ": " .. this:GetValue())
    end)

    w.healBonusLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.healBonusLabel:SetPoint("TOP", 0, -370)

    w.blacklistLabel = LeftPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    w.blacklistLabel:SetPoint("TOP", 0, -394)
    w.blacklistLabel:SetWidth(260)

    w.blacklistBox = CreateFrame("EditBox", "BadAzsP_"..specKey.."_BlacklistBox", LeftPage, "InputBoxTemplate")
    w.blacklistBox:SetPoint("TOP", 0, -418)
    w.blacklistBox:SetWidth(220)
    w.blacklistBox:SetHeight(20)
    w.blacklistBox:SetAutoFocus(false)
    w.blacklistBox:SetScript("OnEnterPressed", function()
        BadAzsPriestDB.DispelBlacklist = BadAzsP_SplitList(this:GetText())
        this:ClearFocus()
        BadAzsP_RefreshPanels()
    end)
    w.blacklistBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    -- ---- DIREITA: EXPLICACOES ----
    w.explainFlash = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.explainFlash:SetPoint("TOP", 0, -14)
    w.explainFlash:SetWidth(260); w.explainFlash:SetJustifyH("LEFT"); w.explainFlash:SetSpacing(2)

    w.explainGreater = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.explainGreater:SetPoint("TOP", 0, -70)
    w.explainGreater:SetWidth(260); w.explainGreater:SetJustifyH("LEFT"); w.explainGreater:SetSpacing(2)

    w.explainRenew = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.explainRenew:SetPoint("TOP", 0, -130)
    w.explainRenew:SetWidth(260); w.explainRenew:SetJustifyH("LEFT"); w.explainRenew:SetSpacing(2)

    w.explainShield = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.explainShield:SetPoint("TOP", 0, -186)
    w.explainShield:SetWidth(260); w.explainShield:SetJustifyH("LEFT"); w.explainShield:SetSpacing(2)

    w.explainBuff = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.explainBuff:SetPoint("TOP", 0, -234)
    w.explainBuff:SetWidth(260); w.explainBuff:SetJustifyH("LEFT"); w.explainBuff:SetSpacing(2)

    w.explainDownrank = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.explainDownrank:SetPoint("TOP", 0, -320)
    w.explainDownrank:SetWidth(260); w.explainDownrank:SetJustifyH("LEFT"); w.explainDownrank:SetSpacing(2)

    w.explainBlacklist = RightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.explainBlacklist:SetPoint("TOP", 0, -390)
    w.explainBlacklist:SetWidth(260); w.explainBlacklist:SetJustifyH("LEFT"); w.explainBlacklist:SetSpacing(2)

    -- ---- RODAPE: COMANDOS ----
    local divider = Panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOP", 0, -518)
    divider:SetWidth(590); divider:SetHeight(1)
    divider:SetTexture(0.5, 0.5, 0.5, 0.5)

    w.cmdHeader = Panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    w.cmdHeader:SetPoint("TOP", 0, -530)

    w.cmdText = Panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    w.cmdText:SetPoint("TOP", 0, -550)
    w.cmdText:SetWidth(560)
    w.cmdText:SetJustifyH("LEFT")
    w.cmdText:SetSpacing(3)

    local function Refresh()
        local L = BadAzsP_L[BadAzsPriestDB.Locale]
        local profile = BadAzsPriestDB[specKey]

        w.title:SetText("|cffffffff" .. L.title .. "|r" .. accentColor .. " - " .. L[specNameField] .. "|r")
        w.langBtn:SetText(BadAzsPriestDB.Locale)

        local detected = BadAzsP_DetectSpec()
        local detectedName = L.specHoly
        if detected == "disc" then detectedName = L.specDisc
        elseif detected == "shadow" then detectedName = L.specShadow end
        w.specLabel:SetText(L.specDetected .. accentColor .. detectedName .. "|r")

        w.flashSlider:SetValue(profile.FlashHealBelow)
        w.greaterSlider:SetValue(profile.GreaterHealBelow)
        w.renewSlider:SetValue(profile.RenewBelow)
        getglobal(w.flashSlider:GetName().."Text"):SetText(L.flashLabel .. ": " .. profile.FlashHealBelow)
        getglobal(w.greaterSlider:GetName().."Text"):SetText(L.greaterLabel .. ": " .. profile.GreaterHealBelow)
        getglobal(w.renewSlider:GetName().."Text"):SetText(L.renewLabel .. ": " .. profile.RenewBelow)

        if profile.UseShield then w.shieldCheck:SetChecked(1) else w.shieldCheck:SetChecked(nil) end
        w.shieldLabel:SetText(L.shieldLabel)

        w.buffChecklistHeader:SetText("|cffffd200" .. L.buffLabel .. "|r")
        w.fortLabel:SetText(L.fortLabel)
        w.spiritLabel:SetText(L.spiritLabel)
        w.shadowProtLabel:SetText(L.shadowProtLabel)
        if profile.MonitorFortitude then w.fortCheck:SetChecked(1) else w.fortCheck:SetChecked(nil) end
        if profile.MonitorSpirit then w.spiritCheck:SetChecked(1) else w.spiritCheck:SetChecked(nil) end
        if profile.MonitorShadowProt then w.shadowProtCheck:SetChecked(1) else w.shadowProtCheck:SetChecked(nil) end

        w.minRankSlider:SetValue(profile.MinRank or 1)
        w.maxRankSlider:SetValue(profile.MaxRank or 0)
        getglobal(w.minRankSlider:GetName().."Text"):SetText(L.minRankLabel .. ": " .. (profile.MinRank or 1))
        getglobal(w.maxRankSlider:GetName().."Text"):SetText(L.maxRankLabel .. ": " .. (profile.MaxRank or 0))

        w.healBonusLabel:SetText(L.healBonusLabel .. ": +" .. BadAzsP_GetHealingBonus())

        w.blacklistLabel:SetText("|cffffd200" .. L.blacklistLabel .. "|r")
        w.blacklistBox:SetText(BadAzsP_JoinList(BadAzsPriestDB.DispelBlacklist or {}))

        w.explainFlash:SetText(L.explainFlash)
        w.explainGreater:SetText(L.explainGreater)
        w.explainRenew:SetText(L.explainRenew)
        w.explainShield:SetText(L.explainShield)
        w.explainBuff:SetText(L.explainBuff)
        w.explainDownrank:SetText(L.explainDownrank)
        w.explainBlacklist:SetText(L.explainBlacklist)

        w.cmdHeader:SetText("|cffffd200" .. L.cmdHeader .. "|r")
        local lines = ""
        local i
        for i = 1, table.getn(L.cmdList) do
            if i > 1 then lines = lines .. "\n" end
            lines = lines .. L.cmdList[i]
        end
        w.cmdText:SetText(lines)
    end

    w.langBtn:SetScript("OnClick", function()
        if BadAzsPriestDB.Locale == "EN" then BadAzsPriestDB.Locale = "BR" else BadAzsPriestDB.Locale = "EN" end
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
