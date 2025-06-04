qtRollDB = qtRollDB or {}
-- create the options panel
local panel = CreateFrame("Frame", "qtRollConfigPanel", UIParent)
panel.name = "qtRoll"

-- title
local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff00bfffqt|r|cffff7d0aRoll|r Settings")

-- separator line
local sep = panel:CreateTexture(nil, "ARTWORK")
sep:SetTexture("Interface\\Common\\UI-Divider")
sep:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -44)
sep:SetHeight(2)

-- option definitions
local options = {
    { key = "enabled",
      text = "Enable qtRoll Addon",
      tooltip = "Toggle the entire qtRoll addon on or off.",
      default = 1,
      col = 1 },
    { key = "debugMode",
      text = "Enable Debug Mode",
      tooltip = "Print extra debugging info to your chat frame.",
      default = 0,
      col = 1 },
    { key = "autoNeed",
      text = "Auto Need (Attunable)",
      tooltip = "Automatically Need attunable items\n(without any progression).",
      default = 1,
      col = 1 },
    { key = "needOnNewAffixOnly",
      text = "Need New Affixes Only",
      tooltip =
        "Only Need attunable items if they have\n"
      .. "  any unlearned affixes.\n\n"
      .. "Requires Auto Need to be enabled.",
      default = 1,
      col = 1,
      depends = "autoNeed" },
    { key = "autoGreed",
      text = "Auto Greed (BoE)",
      tooltip = "Automatically Greed on all BoE items.",
      default = 1,
      col = 1 },
    { key = "autoPass",
      text = "Auto Pass (BoP)",
      tooltip = "Automatically Pass on BoP items\nthat can’t be attuned.",
      default = 1,
      col = 1 },
    { key = "needOnToken",
      text = "Auto Need (Class Tokens)",
      tooltip = "Automatically Need class tokens\nwhen they show up.",
      default = 1,
      col = 1 },
    { key = "needOnWeakerForge",
      text = "Auto Need (Weaker Forge)",
      tooltip = "Only Need items whose Titan-forge bonus\n"
      .. "    is strictly higher than yours.",
      default = 1,
      col = 1 },
    { key = "greedOnResource",
      text = "Auto Greed (Resources)",
      tooltip = "Automatically Greed on crafting resources.",
      default = 1,
      col = 2 },
    { key = "greedOnLockbox",
      text = "Auto Greed (Lockboxes)",
      tooltip = "Automatically Greed on lockboxes.",
      default = 1,
      col = 2 },
    { key = "greedOnRecipe",
      text = "Auto Greed (Unknown Recipes)",
      tooltip = "Automatically Greed on recipes you\nhaven’t learned yet.",
      default = 1,
      col = 2 },
}

-- dynamically create all CheckButtons
local buttons = {}
local last = { [1] = nil, [2] = nil }
local startY, rowH = -60, -28
local colX = { [1] = 16, [2] = 280 }
for _, opt in ipairs(options) do
    local btn = CreateFrame(
        "CheckButton",
        "qtRollOpt_" .. opt.key,
        panel,
        "InterfaceOptionsCheckButtonTemplate"
    )
    -- position
    if not last[opt.col] then
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT",
                     colX[opt.col], startY)
    else
        btn:SetPoint("TOPLEFT", last[opt.col], "BOTTOMLEFT",
                     0, rowH)
    end
    last[opt.col] = btn

    -- label
    local txt = _G[btn:GetName() .. "Text"]
    txt:SetText(opt.text)
    txt:SetWidth(opt.col == 1 and 200 or 220)

    -- tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(opt.text, 1, 1, 1)
        GameTooltip:AddLine(opt.tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    buttons[opt.key] = btn
end

-- save all settings
local function SaveSettings()
  _G.qtRollDB = _G.qtRollDB or {}
  for _, opt in ipairs(options) do
    _G.qtRollDB[opt.key] = buttons[opt.key]:GetChecked() and 1 or 0
  end
end

-- refresh (and default-fill) all
local function RefreshSettings()
    _G.qtRollDB = _G.qtRollDB or {}
    for _, opt in ipairs(options) do
      if _G.qtRollDB[opt.key] == nil then
        _G.qtRollDB[opt.key] = opt.default
      end
      buttons[opt.key]:SetChecked(_G.qtRollDB[opt.key] == 1)
    end
    -- disable dependent
    local autoNeedOn = qtRollDB.autoNeed == 1
    if autoNeedOn then
      buttons.needOnNewAffixOnly:Enable()
    else
      buttons.needOnNewAffixOnly:Disable()
    end
end

-- defaults handler
function panel.default()
    qtRollDB = {}
    for _, opt in ipairs(options) do
        qtRollDB[opt.key] = opt.default
    end
    RefreshSettings()
end

-- Blizzard will call these at the right times:
panel.okay    = SaveSettings
panel.refresh = RefreshSettings

InterfaceOptions_AddCategory(panel)

-- on ADDON_LOADED we know our saved-vars are in place,
-- so fill any nil values with our `options[].default`.
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(self, evt, name)
  if name == "qtRoll" then
    RefreshSettings()
    self:UnregisterEvent("ADDON_LOADED")
  end
end)