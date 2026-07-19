# [B]adAzs Priest

**Battle Analysis Driven Assistant Zmart System** <br>
*Vanilla / Classic WoW Edition – Core Attack API*
<a href="https://www.paypal.com/donate/?hosted_button_id=VLAFP6ZT8ATGU">
  <img src="https://github.com/ThePeregris/MainAssets/blob/main/Donate_PayPal.png" alt="Tips Appreciated!" align="right" width="120" height="75">
</a>
<br><br><br>
<hr>

Addon de cura para Priest, feito para **Vanilla/Classic WoW (cliente 1.12 / Lua 5.0)**.
Cobre as três specs de talento (**Holy**, **Discipline**, **Shadow**) com um painel próprio pra cada uma, Smart Heal automático e smart buff no mouseover. Integra com o [BadAzs Core](../BadAzsCore).

## Requisitos

- **BadAzs Core** (obrigatório) — fornece `BadAzs_Sustain()` (poções/bandagens) e `BadAzs_ManualMouseover()` (usado pelo Smart Heal/Buff), além do roteador `/badazs`.

## Instalação

Copie a pasta inteira para `Interface/AddOns/`, mantendo o nome:

```
AddOns/
  BadAzsPriest/
    BadAzsPriest.toc
    BadAzsPriest.lua
```

Confirme na tela de personagem (botão **AddOns**) que `BadAzs Priest` está habilitado — e que **BadAzs Core** também está.

## Macros

| Comando | O que faz |
|---|---|
| `/bapheal` | Smart Heal — decide a spell certa sozinho (ver abaixo) |
| Segurar **ALT** + `/bapheal` | Lança o Buff configurado em quem estiver no mouseover |
| `/badazs priest holy` | Abre o painel Holy |
| `/badazs priest disc` | Abre o painel Discipline |
| `/badazs priest shadow` | Abre o painel Shadow |
| `/badazs priest` (sem spec) | Mostra no chat a lista dos três comandos acima |

## Detecção automática de spec

O addon não pergunta qual spec você está jogando: ele soma os pontos investidos nas três árvores de talento (`GetTalentTabInfo`) e usa o perfil da árvore com mais pontos — mesma filosofia do "detecta pela arma equipada" do Warrior. Cada painel configura os limiares daquela spec; o `/bapheal` sempre aplica o perfil da spec **realmente ativa** no seu personagem.

## Smart Heal — como a spell é escolhida

Ordem de prioridade de alvo: **mouseover** amigável → **target** amigável → **você mesmo**.

Com o alvo definido, decide a spell pelo % de HP que falta, comparando com os limiares do painel:

1. **Power Word: Shield** — se ativado no perfil, o alvo não tem o escudo, e não está com `Weakened Soul`.
2. **Flash Heal** — se o HP está abaixo do limiar "urgente" (cast rápido, gasta mais mana por ponto curado).
3. **Greater Heal** — se está abaixo do limiar "déficit grande" (cast lento, heal grande mais eficiente).
4. **Renew** — se está abaixo do limiar "completar" (HoT barato pra só topar a vida).
5. Nada, se o alvo já está com a vida cheia.

## Smart Buff (ALT)

Segurando ALT, `/bapheal` lança o buff configurado no painel em quem estiver no mouseover. Clique no botão de buff do painel pra ciclar entre:

`Power Word: Fortitude` → `Divine Spirit` → `Shadow Protection` → `Power Word: Shield`

## Painel de configuração

Formato de "livro": página esquerda com os controles, página direita com a explicação de cada um. Um painel independente por spec (`holy`, `disc`, `shadow`), cada um com:

- Sliders de HP% pra Flash Heal, Greater Heal e Renew.
- Checkbox "Usar Power Word: Shield primeiro".
- Botão de ciclo do Buff do ALT.
- Botão de idioma (`EN`/`PT`) — troca o idioma dos três painéis de uma vez.

## SavedVariables

Um sub-perfil por spec, todos em `BadAzsPriestDB`:

- `BadAzsPriestDB.holy` / `.disc` / `.shadow` — cada um com `{ FlashHealBelow, GreaterHealBelow, RenewBelow, UseShield, Buff, BuffIndex }`
- `BadAzsPriestDB.Locale` — `"EN"` ou `"PT"` (compartilhado pelos três painéis)

## Arquitetura interna

Self-sufficient desde o primeiro release: as checagens de combate (`Ready`, buff/debuff genérico por unidade) vivem dentro do próprio addon, não no Core. O Core só é usado para:

- `BadAzs_Sustain()` — poções de vida/mana, healthstone, bandagem (chamado automaticamente dentro do Smart Heal).
- `BadAzs_ManualMouseover()` — utilitário genérico de castar em quem está no mouseover sem perder o target atual.
- Roteador `/badazs` — cada spec se registra em `BadAzs_PanelRegistry` sob uma chave própria (`"priest holy"`, `"priest disc"`, `"priest shadow"`).

## O que ficou de fora (por enquanto)

Baseado na análise de dois addons de referência ([Rinse](https://github.com/Otari98/Rinse) e o material do repositório `BadAzsPriest` original), duas features não entraram nessa primeira versão por escolha:

- **Dispel automático** (padrão do Rinse — varre o grupo por debuffs removíveis por tipo). A base já existe (`BadAzsP_UnitHasDebuff` genérico por unidade), falta só a lista de prioridade e o mapeamento tipo→spell.
- **Rotação de dano Shadow** (Mind Flay/Smite). O painel Shadow hoje só ajusta os limiares de auto-cura, sem rotação de DPS própria.

## Changelog

- **v1.0** — Primeiro release: Smart Heal, Smart Buff, detecção automática de spec por talentos, três painéis independentes, localização EN/PT.
