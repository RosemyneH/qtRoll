qtRollDB = qtRollDB or {}

local panel = CreateFrame("Frame", "qtRollSettingsPanel", UIParent)
panel.name = "qtRoll"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff00bfffqt|r|cffff7d0aRoll|r Settings")

local col1_x, col1_y = 16, -50
local col2_x, col2_y = 200, -50
local row_h, label_w = -28, 180
local second_col_label_w = 220


local enableAddon = CreateFrame(
    "CheckButton",
    "qtRollEnableAddon",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
enableAddon:SetPoint("TOPLEFT", panel, "TOPLEFT", col1_x, col1_y)
qtRollEnableAddonText:SetText("Enable qtRoll Addon")
qtRollEnableAddonText:SetWidth(label_w)

local debugMode = CreateFrame(
    "CheckButton",
    "qtRollDebugMode",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
debugMode:SetPoint("TOPLEFT", enableAddon, "BOTTOMLEFT", 0, row_h)
qtRollDebugModeText:SetText("Enable Debug Mode")
qtRollDebugModeText:SetWidth(label_w)


local autoNeed = CreateFrame(
    "CheckButton",
    "qtRollAutoNeed",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
autoNeed:SetPoint("TOPLEFT", debugMode, "BOTTOMLEFT", 0, row_h)
qtRollAutoNeedText:SetText("Auto Need (Attunable, No Progress)")
qtRollAutoNeedText:SetWidth(label_w)

local autoGreed = CreateFrame(
    "CheckButton",
    "qtRollAutoGreed",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
autoGreed:SetPoint("TOPLEFT", autoNeed, "BOTTOMLEFT", 0, row_h)
qtRollAutoGreedText:SetText("Auto Greed (BoE)")
qtRollAutoGreedText:SetWidth(label_w)

local autoPass = CreateFrame(
    "CheckButton",
    "qtRollAutoPass",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
autoPass:SetPoint("TOPLEFT", autoGreed, "BOTTOMLEFT", 0, row_h)
qtRollAutoPassText:SetText("Auto Pass (BoP, Not Attunable)")
qtRollAutoPassText:SetWidth(label_w)

local needOnToken = CreateFrame(
    "CheckButton",
    "qtRollNeedOnToken",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
needOnToken:SetPoint("TOPLEFT", autoPass, "BOTTOMLEFT", 0, row_h)
qtRollNeedOnTokenText:SetText("Auto Need (Class Tokens)")
qtRollNeedOnTokenText:SetWidth(label_w)

local needOnWeakerForge = CreateFrame(
    "CheckButton",
    "qtRollNeedOnWeakerForge",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
needOnWeakerForge:SetPoint("TOPLEFT", needOnToken, "BOTTOMLEFT", 0, row_h)
qtRollNeedOnWeakerForgeText:SetText("Auto Need (Stronger Titanforge)")
qtRollNeedOnWeakerForgeText:SetWidth(label_w)


local greedOnResource = CreateFrame(
    "CheckButton",
    "qtRollGreedOnResource",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
greedOnResource:SetPoint("TOPLEFT", panel, "TOPLEFT", col2_x, col2_y)
qtRollGreedOnResourceText:SetText("Auto Greed (Resources)")
qtRollGreedOnResourceText:SetWidth(second_col_label_w)


local greedOnLockbox = CreateFrame(
    "CheckButton",
    "qtRollGreedOnLockbox",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
greedOnLockbox:SetPoint(
    "TOPLEFT",
    greedOnResource,
    "BOTTOMLEFT",
    0,
    row_h
)
qtRollGreedOnLockboxText:SetText("Auto Greed (Lockboxes)")
qtRollGreedOnLockboxText:SetWidth(second_col_label_w)

local greedOnRecipe = CreateFrame(
    "CheckButton",
    "qtRollGreedOnRecipe",
    panel,
    "InterfaceOptionsCheckButtonTemplate"
)
greedOnRecipe:SetPoint(
    "TOPLEFT",
    greedOnLockbox,
    "BOTTOMLEFT",
    0,
    row_h
)
qtRollGreedOnRecipeText:SetText("Auto Greed (Unknown Recipes)")
qtRollGreedOnRecipeText:SetWidth(second_col_label_w)

local function SaveSettings()
    qtRollDB.enabled = enableAddon:GetChecked() and 1 or 0
    qtRollDB.autoNeed = autoNeed:GetChecked() and 1 or 0
    qtRollDB.autoGreed = autoGreed:GetChecked() and 1 or 0
    qtRollDB.autoPass = autoPass:GetChecked() and 1 or 0
    qtRollDB.debugMode = debugMode:GetChecked() and 1 or 0
    qtRollDB.greedOnResource = greedOnResource:GetChecked() and 1 or 0
    qtRollDB.greedOnLockbox = greedOnLockbox:GetChecked() and 1 or 0
    qtRollDB.greedOnRecipe = greedOnRecipe:GetChecked() and 1 or 0
    qtRollDB.needOnToken = needOnToken:GetChecked() and 1 or 0
    qtRollDB.needOnWeakerForge = needOnWeakerForge:GetChecked() and 1 or 0
end

for _, btn in ipairs({
    enableAddon,
    autoNeed,
    autoGreed,
    autoPass,
    debugMode,
    greedOnResource,
    greedOnLockbox,
    greedOnRecipe,
    needOnToken,
    needOnWeakerForge
}) do
    btn:SetScript("OnClick", SaveSettings)
end

panel:SetScript("OnShow", function()
    qtRollDB = qtRollDB or {}
    if qtRollDB.enabled == nil then qtRollDB.enabled = 1 end
    if qtRollDB.autoNeed == nil then qtRollDB.autoNeed = 0 end
    if qtRollDB.autoGreed == nil then qtRollDB.autoGreed = 0 end
    if qtRollDB.autoPass == nil then qtRollDB.autoPass = 0 end
    if qtRollDB.debugMode == nil then qtRollDB.debugMode = 0 end
    if qtRollDB.greedOnResource == nil then qtRollDB.greedOnResource = 0 end
    if qtRollDB.greedOnLockbox == nil then qtRollDB.greedOnLockbox = 0 end
    if qtRollDB.greedOnRecipe == nil then qtRollDB.greedOnRecipe = 1 end
    if qtRollDB.needOnToken == nil then qtRollDB.needOnToken = 0 end
    if qtRollDB.needOnWeakerForge == nil then qtRollDB.needOnWeakerForge = 0 end
    if qtRollDB.autoNeedCustomList == nil then qtRollDB.autoNeedCustomList = {} end

    enableAddon:SetChecked(qtRollDB.enabled == 1)
    autoNeed:SetChecked(qtRollDB.autoNeed == 1)
    autoGreed:SetChecked(qtRollDB.autoGreed == 1)
    autoPass:SetChecked(qtRollDB.autoPass == 1)
    debugMode:SetChecked(qtRollDB.debugMode == 1)
    greedOnResource:SetChecked(qtRollDB.greedOnResource == 1)
    greedOnLockbox:SetChecked(qtRollDB.greedOnLockbox == 1)
    greedOnRecipe:SetChecked(qtRollDB.greedOnRecipe == 1)
    needOnToken:SetChecked(qtRollDB.needOnToken == 1)
    needOnWeakerForge:SetChecked(qtRollDB.needOnWeakerForge == 1)
end)

InterfaceOptions_AddCategory(panel)