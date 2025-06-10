-- qtRoll - Standalone version using custom game API
if qtRollDB == nil then
    qtRollDB = {
        enabled = 1,
        debugMode = 0,
        needOnWeakerForge = 1,
        needOnToken = 1,
        autoNeed = 1,
        autoGreed = 1,
        greedOnLockbox = 1,
        greedOnResource = 1,
        greedOnRecipe = 1,
        autoPass = 1,
        needOnNewAffixOnly = 0,
        autoNeedCustomList = {},
        defaultNeedRoll = {
            47242
        }
    }
else
    if type(qtRollDB.autoNeedCustomList) ~= "table" then
        qtRollDB.autoNeedCustomList = {}
    end

    if type(qtRollDB.defaultNeedRoll) ~= "table" or #qtRollDB.defaultNeedRoll == 0 then
        qtRollDB.defaultNeedRoll = {
            47242
        }
    end
    
    -- Add new settings if they don't exist
    if qtRollDB.needOnNewAffixOnly == nil then
        qtRollDB.needOnNewAffixOnly = 0
      end
      if qtRollDB.greedOnRecipe == nil then
        qtRollDB.greedOnRecipe = 1
      end
    
      -- back-fill *all* of our other defaults in one go
      local __defaults = {
        enabled           = 1,
        debugMode         = 0,
        needOnWeakerForge = 1,
        needOnToken       = 1,
        autoNeed          = 1,
        autoGreed         = 1,
        greedOnLockbox    = 1,
        greedOnResource   = 1,
        autoPass          = 1,
      }
      for k, v in pairs(__defaults) do
        if qtRollDB[k] == nil then
          qtRollDB[k] = v
        end
      end
    end

local FORGE_LEVEL_MAP = {
    BASE = 0,
    TITANFORGED = 1,
    WARFORGED = 2,
    LIGHTFORGED = 3
}

local function qtRollDebug(msg)
    if qtRollDB and qtRollDB.enabled == 1 and qtRollDB.debugMode and qtRollDB.debugMode > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00bfffqt|r|cffff7d0aRoll|r Debug: " .. msg
        )
    end
end

local function GetForgeLevelFromLink(itemLink)
    if not itemLink then return FORGE_LEVEL_MAP.BASE end
    
    if GetItemLinkTitanforge then
        local forgeValue = GetItemLinkTitanforge(itemLink)
        -- Validate the returned value against known FORGE_LEVEL_MAP values
        for _, knownValue in pairs(FORGE_LEVEL_MAP) do
            if forgeValue == knownValue then
                return forgeValue
            end
        end
        qtRollDebug("GetForgeLevelFromLink: GetItemLinkTitanforge returned unexpected value: " .. tostring(forgeValue))
    else
        qtRollDebug("GetForgeLevelFromLink: GetItemLinkTitanforge API not available.")
    end
    return FORGE_LEVEL_MAP.BASE
end

-- Enhanced forge level checking function
local function ShouldNeedForForgeUpgrade(itemLink, itemId)
    if not itemLink or not itemId then return false end
    
    local currentForgeLevel = GetForgeLevelFromLink(itemLink)
    qtRollDebug("ShouldNeedForForgeUpgrade: Checking itemId " .. itemId .. " with forge level " .. currentForgeLevel)
    
    -- Check if we have any attuned variant at this forge level or higher
    if HasAttunedAnyVariantEx then
        -- First check if we already have this exact forge level or higher
        for forgeLevel = currentForgeLevel, FORGE_LEVEL_MAP.LIGHTFORGED do
            if HasAttunedAnyVariantEx(itemId, forgeLevel) then
                qtRollDebug("  Already have attuned variant at forge level " .. forgeLevel .. " (>= " .. currentForgeLevel .. ")")
                return false
            end
        end
        
        -- Now check if we have any lower forge level variants (which would make this an upgrade)
        for forgeLevel = currentForgeLevel - 1, FORGE_LEVEL_MAP.BASE, -1 do
            if HasAttunedAnyVariantEx(itemId, forgeLevel) then
                qtRollDebug("  Found attuned variant at lower forge level " .. forgeLevel .. " - this is an upgrade (" .. forgeLevel .. " → " .. currentForgeLevel .. ")")
                return true
            end
        end
        
        -- No attuned variants found, check if the item is attunable at all
        if CanAttuneItemHelper and CanAttuneItemHelper(itemId) > 0 then
            qtRollDebug("  No attuned variants found, but item is attunable - should need")
            return true
        end
    else
        qtRollDebug("  HasAttunedAnyVariantEx API not available, falling back to bag/equipped scan")
        -- Fallback to the existing bag/equipped scan logic
        local bestForge = nil
        local hasAnyVariant = false
        
        -- Scan bags
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local linkBag = GetContainerItemLink(bag, slot)
                if linkBag then
                    local idBag = tonumber(linkBag:match("item:(%d+)"))
                    if idBag == itemId then
                        hasAnyVariant = true
                        local forgeBag = GetForgeLevelFromLink(linkBag)
                        if not bestForge or forgeBag > bestForge then
                            bestForge = forgeBag
                        end
                    end
                end
            end
        end
        
        -- Scan equipped gear
        for slotID = 1, 19 do
            local linkEq = GetInventoryItemLink("player", slotID)
            if linkEq then
                local idEq = tonumber(linkEq:match("item:(%d+)"))
                if idEq == itemId then
                    hasAnyVariant = true
                    local forgeEq = GetForgeLevelFromLink(linkEq)
                    if not bestForge or forgeEq > bestForge then
                        bestForge = forgeEq
                    end
                end
            end
        end
        
        if hasAnyVariant and bestForge then
            if currentForgeLevel > bestForge then
                qtRollDebug("  Fallback: Found forge upgrade (" .. bestForge .. " → " .. currentForgeLevel .. ")")
                return true
            else
                qtRollDebug("  Fallback: Already have forge level " .. bestForge .. " (>= " .. currentForgeLevel .. ")")
                return false
            end
        end
    end
    
    qtRollDebug("  No forge upgrade needed")
    return false
end

-- Standalone functions to replace SynastriaCoreLib dependency
local function IsAttunable(itemLink)
    if not itemLink then return false end
    
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then return false end
    
    -- Use CanAttuneItemHelper if available
    if CanAttuneItemHelper then
        return CanAttuneItemHelper(itemId) > 0
    end
    
    -- Fallback: check item tags for attunable flag
    if GetItemTagsCustom then
        local itemTags = GetItemTagsCustom(itemId)
        if itemTags then
            -- Check if item has attunable tag (bit 64 based on documentation)
            return bit.band(itemTags, 64) ~= 0
        end
    end
    
    return false
end

local function HasAttuneProgress(itemLink)
    if not itemLink then return false end
    
    if GetItemLinkAttuneProgress then
        local progress = GetItemLinkAttuneProgress(itemLink)
        return progress and progress > 0
    end
    
    return false
end

local function IsMythicItem(itemLink)
    if not itemLink then return false end
    
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then return false end
    
    -- Use GetItemTagsCustom for better mythic detection
    if GetItemTagsCustom then
        local itemTags = GetItemTagsCustom(itemId)
        if itemTags then
            -- Check for mythic bit (0x80 = 128)
            return bit.band(itemTags, 128) ~= 0
        end
    end
    
    -- Fallback to tooltip scanning
    local tt = CreateFrame("GameTooltip", "qtRollMythicItemScannerTooltip", nil, "GameTooltipTemplate")
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:SetHyperlink(itemLink)
    for i = 1, tt:NumLines() do
        local line = _G["qtRollMythicItemScannerTooltipTextLeft" .. i]:GetText()
        if line and string.find(line, "Mythic") then
            tt:Hide()
            return true
        end
    end
    tt:Hide()
    return false
end

-- Replace the current HasNewAffixes function with this improved version
local function ItemQualifiesForAttuneNeed(itemLink, needOnNewAffixOnly)
    if not itemLink then return false end
    
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then return false end
    
    -- Check if player can attune this item
    local canPlayerAttuneThisItem = false
    if CanAttuneItemHelper then
        canPlayerAttuneThisItem = (CanAttuneItemHelper(itemId) == 1)
    else
        qtRollDebug("ItemQualifiesForAttuneNeed: CanAttuneItemHelper API not found for itemId " .. itemId)
        return false
    end
    
    if not canPlayerAttuneThisItem then
        return false
    end
    
    -- Check progress of THIS SPECIFIC VARIANT
    local progress = 0
    if GetItemLinkAttuneProgress then
        progress = GetItemLinkAttuneProgress(itemLink) or 0
        if type(progress) ~= "number" then
            qtRollDebug("ItemQualifiesForAttuneNeed: GetItemLinkAttuneProgress did not return a number for itemLink " .. itemLink .. ". Got: " .. tostring(progress))
            progress = 100  -- Assume fully attuned if we can't get progress
        end
    else
        qtRollDebug("ItemQualifiesForAttuneNeed: GetItemLinkAttuneProgress API not found for itemLink " .. itemLink)
        return false
    end
    
    qtRollDebug("ItemQualifiesForAttuneNeed check for itemLink " .. itemLink .. ": Progress=" .. progress .. ", NeedOnNewAffixOnly=" .. tostring(needOnNewAffixOnly))
    
    -- If this specific variant is already 100% attuned, don't need it
    if progress >= 100 then
        qtRollDebug("  This specific variant already 100% attuned. Does not qualify.")
        return false
    end
    
    -- Get forge level of this specific variant
    local currentForgeLevel = GetForgeLevelFromLink(itemLink)
    
    if needOnNewAffixOnly then
        -- Strict mode: only need if no variant has been attuned OR this is a higher forge level
        local hasAnyVariantBeenAttuned = true
        if HasAttunedAnyVariantOfItem then
            hasAnyVariantBeenAttuned = HasAttunedAnyVariantOfItem(itemId)
        else
            qtRollDebug("ItemQualifiesForAttuneNeed: HasAttunedAnyVariantOfItem API not found for itemId " .. itemId)
            return false  -- Can't determine, so don't need
        end
        
        if not hasAnyVariantBeenAttuned then
            qtRollDebug("  Strict Mode: Qualifies because NO variant of base item ID " .. itemId .. " has been attuned yet.")
            return true
        else
            -- FORGE PRIORITY OVERRIDE: Even in strict mode, allow higher forge levels
            if currentForgeLevel > FORGE_LEVEL_MAP.BASE then
                qtRollDebug("  Strict Mode: FORGE OVERRIDE - Qualifies because this is a higher forge level (" .. currentForgeLevel .. ") even though some variant has been attuned.")
                return true
            else
                qtRollDebug("  Strict Mode: Does NOT qualify because some variant of base item ID " .. itemId .. " has already been attuned and this is only forge level " .. currentForgeLevel .. ".")
                return false
            end
        end
    else
        -- Lenient mode: need if this specific variant has progress < 100%
        qtRollDebug("  Lenient Mode: Qualifies because this specific variant progress < 100%.")
        return true
    end
end

local function ItemExistsInBags(itemId, itemName)
    -- Check bags first
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link_in_bag = GetContainerItemLink(bag, slot)
            if link_in_bag then
                local itemId_in_bag = tonumber(link_in_bag:match("item:(%d+)"))
                if itemId_in_bag then
                    if itemId and itemId_in_bag == itemId then
                        return true, link_in_bag
                    elseif not itemId and itemName then
                        local nameB_custom = GetItemInfoCustom and GetItemInfoCustom(itemId_in_bag) or GetItemInfo(itemId_in_bag)
                        if nameB_custom and nameB_custom == itemName then
                            return true, link_in_bag
                        end
                    end
                end
            end
        end
    end
    
    -- Check equipped gear (slots 1-19)
    for slotID = 1, 19 do
        local link_equipped = GetInventoryItemLink("player", slotID)
        if link_equipped then
            local itemId_equipped = tonumber(link_equipped:match("item:(%d+)"))
            if itemId_equipped then
                if itemId and itemId_equipped == itemId then
                    qtRollDebug("Found duplicate item equipped in slot " .. slotID)
                    return true, link_equipped
                elseif not itemId and itemName then
                    local nameE_custom = GetItemInfoCustom and GetItemInfoCustom(itemId_equipped) or GetItemInfo(itemId_equipped)
                    if nameE_custom and nameE_custom == itemName then
                        qtRollDebug("Found duplicate item (by name) equipped in slot " .. slotID)
                        return true, link_equipped
                    end
                end
            end
        end
    end
    
    return false, nil
end

local function TooltipHasAlreadyKnown(itemLink)
    local tooltip = CreateFrame("GameTooltip", "qtRollAlreadyKnownTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    for i = 2, tooltip:NumLines() do
        local text = _G["qtRollAlreadyKnownTooltipTextLeft" .. i]:GetText()
        if text and (text:find(ITEM_SPELL_KNOWN) or text:find("Already known")) then
            tooltip:Hide()
            return true
        end
    end
    tooltip:Hide()
    return false
end

local function IsToken(itemLink)
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then
        qtRollDebug("IsToken: Could not parse itemID from link: " .. itemLink)
        return false
    end
    local _, _, _, _, _, itemType, itemSubType = GetItemInfoCustom and GetItemInfoCustom(itemId) or GetItemInfo(itemId)
    return itemType == "Miscellaneous" and (
        itemSubType == "Token" or itemSubType == "Reagent" or itemSubType == "Junk"
    )
end

-- Reusable tooltip frame so we don't leak every call
local TokenScanner = CreateFrame("GameTooltip",
  "qtRollTokenTooltip", nil, "GameTooltipTemplate")
TokenScanner:SetOwner(UIParent, "ANCHOR_NONE")

local function TokenIsForPlayer(itemLink)
  local localizedPlayerClassName, _ = UnitClass("player")
  if not localizedPlayerClassName then
      qtRollDebug("TokenIsForPlayer: Could not get localized player class name.")
      return false
  end
  local tooltip = CreateFrame("GameTooltip", "qtRollTokenTooltip", nil, "GameTooltipTemplate")
  tooltip:SetOwner(UIParent, "ANCHOR_NONE")
  tooltip:SetHyperlink(itemLink)
  local foundClass = false
  for i = 2, tooltip:NumLines() do
      local text = _G["qtRollTokenTooltipTextLeft" .. i]:GetText()
      if text and text:find(localizedPlayerClassName, 1, true) then
          foundClass = true
          break
      end
  end
  tooltip:Hide()
  return foundClass
end

local function GetBindingTypeFromTooltip(itemLink)
    local tooltip = CreateFrame("GameTooltip", "qtRollScanTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    local isBoE, isBoP = false, false
    for i = 2, tooltip:NumLines() do
        local text = _G["qtRollScanTooltipTextLeft" .. i]:GetText()
        if text then
            if text:find(ITEM_BIND_ON_EQUIP) or text:find("Binds when equipped") then
                isBoE = true
            elseif text:find(ITEM_BIND_ON_PICKUP) or text:find("Binds when picked up") then
                isBoP = true
            end
        end
    end
    tooltip:Hide()
    return isBoE, isBoP
end

local RESOURCE_TYPES = {
    ["Trade Goods"] = true,
    ["Consumable"] = true,
    ["Gem"] = true,
    ["Reagent"] = true,
    ["Material"] = true,
    ["Other"] = true,
    ["Metal & Stone"] = true,
    ["Herb"] = true,
    ["Elemental"] = true,
    ["Cloth"] = true,
    ["Leather"] = true,
    ["Cooking"] = true,
    ["Enchanting"] = true,
    ["Jewelcrafting"] = true,
    ["Parts"] = true,
    ["Explosives"] = true,
    ["Devices"] = true
}

-- Specific item IDs that should be treated as trade goods/resources
local TRADE_GOODS_ITEMS = {
    [43102] = true,
    [47556] = true,
    [12811] = true,
    [45087] = true,
}

local function IsLockbox(itemLink)
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then
        qtRollDebug("IsLockbox: Could not parse itemID from link: " .. itemLink)
        return false
    end
    local name = GetItemInfoCustom and GetItemInfoCustom(itemId) or GetItemInfo(itemId)
    if name and name:lower():find("lockbox") then
        return true
    end
    return false
end

local function ResolveItemToID(identifier)
    local itemId
    if type(identifier) == "number" then
        local name_check = GetItemInfoCustom and GetItemInfoCustom(identifier) or GetItemInfo(identifier)
        if name_check then
            itemId = identifier
        end
    elseif type(identifier) == "string" then
        local idFromLinkMatch = tonumber(identifier:match("item:(%d+)"))
        if idFromLinkMatch then
            local name_check = GetItemInfoCustom and GetItemInfoCustom(idFromLinkMatch) or GetItemInfo(idFromLinkMatch)
            if name_check then
                return idFromLinkMatch
            end
        end

        local idFromDirectNumberParse = tonumber(identifier)
        if idFromDirectNumberParse then
             local name_check = GetItemInfoCustom and GetItemInfoCustom(idFromDirectNumberParse) or GetItemInfo(idFromDirectNumberParse)
             if name_check then
                 return idFromDirectNumberParse
             end
        end
        
        -- Try to get item info by name
        local _, itemLinkFromCustom = GetItemInfoCustom and GetItemInfoCustom(identifier) or GetItemInfo(identifier)
        if itemLinkFromCustom then
            itemId = tonumber(itemLinkFromCustom:match("item:(%d+)"))
        end
    end
    return itemId
end

-- Main rolling logic
local f = CreateFrame("Frame")
f:RegisterEvent("START_LOOT_ROLL")
f:SetScript("OnEvent", function(self, event, rollID)
    if not qtRollDB or qtRollDB.enabled == 0 then
      return
    end
  
    local itemLink = GetLootRollItemLink(rollID)
    if not itemLink then
      qtRollDebug("START_LOOT_ROLL: invalid itemLink for rollID " ..
        tostring(rollID))
      return
    end
  
    local currentItemId = tonumber(itemLink:match("item:(%d+)"))
    if not currentItemId then
      qtRollDebug("START_LOOT_ROLL: Could not parse itemID from link: " ..
        itemLink)
      return
    end
  
    local itemName, itemLink2, rarity, _, _, itemType, itemSubType =
      (GetItemInfoCustom and GetItemInfoCustom(currentItemId)) or
      GetItemInfo(currentItemId)
    qtRollDB = qtRollDB or {}
  
    if rarity == 5 then
      qtRollDebug("Item is Legendary: " .. (itemLink2 or itemLink) ..
        ". Taking NO ACTION (manual roll).")
      return
    end
  
    local isBoE, isBoP = GetBindingTypeFromTooltip(itemLink)
    local isTok = IsToken(itemLink)
  
    local function DoRoll(choice)
      RollOnLoot(rollID, choice)
      if choice > 0 and isBoP then
        ConfirmLootRoll(rollID, choice)
      end
    end
  
    -- Custom need list
    if currentItemId and qtRollDB.autoNeedCustomList then
      for _, id in ipairs(qtRollDB.autoNeedCustomList) do
        if id == currentItemId then
          qtRollDebug("Need custom list item: " .. (itemLink2 or itemLink))
          DoRoll(1)
          return
        end
      end
    end
  
    -- Default need list
    if currentItemId and qtRollDB.defaultNeedRoll and
      type(qtRollDB.defaultNeedRoll) == "table" then
      for _, id in ipairs(qtRollDB.defaultNeedRoll) do
        if id == currentItemId then
          qtRollDebug("Need default list item: " ..
            (itemLink2 or itemLink))
          DoRoll(1)
          return
        end
      end
    end
  
    -- Already known
    if TooltipHasAlreadyKnown(itemLink) then
      qtRollDebug("Passing known (recipe or item): " ..
        (itemLink2 or itemLink))
      DoRoll(0)
      return
    end
  
    -- Recipe handling
    if itemType == "Recipe" then
      if itemSubType == "Class Books" then
        qtRollDebug("Passing codex class book (recipe): " ..
          (itemLink2 or itemLink))
        DoRoll(0)
        return
      elseif qtRollDB.greedOnRecipe == 1 then
        qtRollDebug("Greed unknown recipe: " .. (itemLink2 or itemLink))
        DoRoll(2)
        return
      else
        qtRollDebug("Recipe handling disabled for non-codex: " ..
          (itemLink2 or itemLink))
      end
    end
  
    local isAtt = IsAttunable(itemLink)
    local hasAttune = HasAttuneProgress(itemLink)
    local isRes = RESOURCE_TYPES[itemType] or RESOURCE_TYPES[itemSubType] or TRADE_GOODS_ITEMS[currentItemId]
    local isLock = IsLockbox(itemLink)
    local isMythic = IsMythicItem(itemLink)
    local currentForge = GetForgeLevelFromLink(itemLink)
  
    local attuneProg = 0
    if GetItemLinkAttuneProgress then
      attuneProg = GetItemLinkAttuneProgress(itemLink) or 0
    end
  
    -- Updated: BoE & fully attuned => GREED, else PASS
    if isAtt and attuneProg >= 100 then
      if isBoE and qtRollDB.autoGreed > 0 then
        qtRollDebug(("Fully attuned BoE (100%%) – GREED: %s")
          :format(itemLink2 or itemLink))
        DoRoll(2)
        return
      else
        qtRollDebug(("Fully attuned (100%%) – PASS: %s")
          :format(itemLink2 or itemLink))
        DoRoll(0)
        return
      end
    end
  
    -- Enhanced BoP duplicate check - but skip for items that should be needed/greeded
    if isBoP and not isTok then
      -- Don't apply duplicate check to items in custom need list
      local isInCustomNeedList = false
      if currentItemId and qtRollDB.autoNeedCustomList then
        for _, id in ipairs(qtRollDB.autoNeedCustomList) do
          if id == currentItemId then
            isInCustomNeedList = true
            break
          end
        end
      end
      
      -- Don't apply duplicate check to items in default need list
      local isInDefaultNeedList = false
      if currentItemId and qtRollDB.defaultNeedRoll then
        for _, id in ipairs(qtRollDB.defaultNeedRoll) do
          if id == currentItemId then
            isInDefaultNeedList = true
            break
          end
        end
      end
      
      -- Don't apply duplicate check to trade goods items
      local isTradeGood = RESOURCE_TYPES[itemType] or RESOURCE_TYPES[itemSubType] or TRADE_GOODS_ITEMS[currentItemId]
      
      -- Don't apply duplicate check to attunable items (let attunement logic handle them)
      local isAttunable = IsAttunable(itemLink)
      
      -- Don't apply duplicate check to class tokens (even if IsToken didn't catch them)
      local isForPlayer = TokenIsForPlayer(itemLink)
      
      if not isInCustomNeedList and not isInDefaultNeedList and not isTradeGood and not isAttunable and not isForPlayer then
        local foundDupe, dupeLink = ItemExistsInBags(currentItemId, itemName)
        if foundDupe then
          if isMythic then
            qtRollDebug("Duplicate mythic BoP; disenchant: " .. (itemLink2 or itemLink))
            DoRoll(3)
            return
          else
            qtRollDebug("Duplicate non-essential BoP; pass: " .. (itemLink2 or itemLink))
            DoRoll(0)
            return
          end
        end
      end
    end
  
    -- 1) BoE + any forge tier (i.e. currentForge > BASE) => NEED
    if isBoE and currentForge > FORGE_LEVEL_MAP.BASE then
        qtRollDebug("Forged BoE – NEED: " .. (itemLink2 or itemLink))
        DoRoll(1)  -- NEED
        return
    end

    -- Check for forge upgrades (both BoE and BoP)
    if IsUsableItem(itemLink) then
        local shouldNeedForForge = ShouldNeedForForgeUpgrade(itemLink, currentItemId)
        if shouldNeedForForge then
            qtRollDebug("Forge upgrade needed – NEED: " .. (itemLink2 or itemLink))
            DoRoll(1)  -- NEED
            return
        end
    end
  
    -- Token need (check both IsToken result and TokenIsForPlayer for broader coverage)
    if qtRollDB.needOnToken == 1 and (isTok or TokenIsForPlayer(itemLink))
    then
      qtRollDebug("Need token for player: " .. (itemLink2 or itemLink))
      DoRoll(1)
      return
    end
  
    -- Attunement need
    if qtRollDB.autoNeed > 0 and isAtt then
        local shouldNeedForAttune = ItemQualifiesForAttuneNeed(itemLink, qtRollDB.needOnNewAffixOnly == 1)
        if shouldNeedForAttune then
            qtRollDebug("Need attunable item: " .. (itemLink2 or itemLink))
            DoRoll(1)
            return
        else
            qtRollDebug("Attunable item does not qualify for need: " .. (itemLink2 or itemLink))
        end
    end
  
    -- Greed checks
    if qtRollDB.autoGreed > 0 and isBoE then
      qtRollDebug("Greed BoE: " .. (itemLink2 or itemLink))
      DoRoll(2)
      return
    elseif qtRollDB.greedOnLockbox > 0 and isLock then
      qtRollDebug("Greed lockbox: " .. (itemLink2 or itemLink))
      DoRoll(2)
      return
    elseif qtRollDB.greedOnResource > 0 and isRes then
      qtRollDebug("Greed resource: " .. (itemLink2 or itemLink))
      DoRoll(2)
      return
    end
  
    -- Mythic BoP disenchant
    if isMythic and isBoP then
      if not isAtt then
        qtRollDebug("Disenchant mythic BoP (not attunable): " ..
          (itemLink2 or itemLink))
        DoRoll(3)
        return
      elseif hasAttune then
        qtRollDebug("Disenchant mythic BoP (has progress): " ..
          (itemLink2 or itemLink))
        DoRoll(3)
        return
      end
    end
  
    -- Auto‐pass BoP not attunable
    if qtRollDB.autoPass > 0 and isBoP and not isAtt and
      itemType ~= "Recipe" then
      qtRollDebug("Pass BoP (not attun) – " .. (itemLink2 or itemLink))
      DoRoll(0)
      return
    elseif rarity and rarity < 4 then
      qtRollDebug("Pass low rarity (rarity=" .. rarity .. "): " ..
        (itemLink2 or itemLink))
      DoRoll(0)
      return
    end
  
    qtRollDebug("No rule matched – default IGNORE: " ..
      (itemLink2 or itemLink))
  end)

SLASH_QTROLL1 = "/qtroll"
SlashCmdList["QTROLL"] = function(msg)
    local args = {}
    for arg_str in msg:gmatch("%S+") do table.insert(args, arg_str) end
    local command = args[1] and args[1]:lower() or ""
    local fullItemInput = msg:match("^%s*%S+%s+(.+)$") 

    qtRollDB = qtRollDB or {} 
    qtRollDB.autoNeedCustomList = qtRollDB.autoNeedCustomList or {} 

    if command == "debug" then
        qtRollDB.debugMode = (qtRollDB.debugMode == 1) and 0 or 1
        DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Debug messages " .. (qtRollDB.debugMode == 1 and "enabled." or "disabled."))
    elseif command == "" then 
        qtRollDB.enabled = (qtRollDB.enabled == 1) and 0 or 1
        DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Addon " .. (qtRollDB.enabled == 1 and "enabled." or "disabled."))
    elseif command == "needadd" then
        if not fullItemInput then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Usage: /qtroll needadd <itemLink|itemID|itemName>")
            return
        end
        local itemId = ResolveItemToID(fullItemInput)
        if itemId then
            local found = false
            for _, existingId in ipairs(qtRollDB.autoNeedCustomList) do
                if existingId == itemId then
                    found = true
                    break
                end
            end
            local _, itemLink_add = GetItemInfoCustom and GetItemInfoCustom(itemId) or GetItemInfo(itemId)
            if not found then
                table.insert(qtRollDB.autoNeedCustomList, itemId)
                DEFAULT_CHAT_FRAME:AddMessage(("|cff00bfffqt|r|cffff7d0aRoll|r: Added %s to custom need list."):format(itemLink_add or "item:"..itemId))
            else
                DEFAULT_CHAT_FRAME:AddMessage(("|cff00bfffqt|r|cffff7d0aRoll|r: %s is already in the custom need list."):format(itemLink_add or "item:"..itemId))
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage(("|cff00bfffqt|r|cffff7d0aRoll|r: Item not found: %s"):format(fullItemInput))
        end
    elseif command == "needremove" then
        if not fullItemInput then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Usage: /qtroll needremove <itemLink|itemID|itemName|listIndex>")
            return
        end
        local itemIdToRemove
        local removed = false
        local itemRemovedDisplay = fullItemInput 
        local listIndex = tonumber(fullItemInput)
        if listIndex and qtRollDB.autoNeedCustomList[listIndex] then
            itemIdToRemove = qtRollDB.autoNeedCustomList[listIndex]
            local _, itemLink_rem = GetItemInfoCustom and GetItemInfoCustom(itemIdToRemove) or GetItemInfo(itemIdToRemove)
            itemRemovedDisplay = itemLink_rem or "item:"..itemIdToRemove
            table.remove(qtRollDB.autoNeedCustomList, listIndex)
            removed = true
        else
            itemIdToRemove = ResolveItemToID(fullItemInput)
            if itemIdToRemove then
                local _, itemLink_rem = GetItemInfoCustom and GetItemInfoCustom(itemIdToRemove) or GetItemInfo(itemIdToRemove)
                itemRemovedDisplay = itemLink_rem or "item:"..itemIdToRemove 
                for i = #qtRollDB.autoNeedCustomList, 1, -1 do
                    if qtRollDB.autoNeedCustomList[i] == itemIdToRemove then
                        table.remove(qtRollDB.autoNeedCustomList, i)
                        removed = true
                        break 
                    end
                end
            end
        end

        if removed then
            DEFAULT_CHAT_FRAME:AddMessage(("|cff00bfffqt|r|cffff7d0aRoll|r: Removed %s from custom need list."):format(itemRemovedDisplay))
        else
            DEFAULT_CHAT_FRAME:AddMessage(("|cff00bfffqt|r|cffff7d0aRoll|r: Item not found in custom need list or invalid identifier: %s"):format(fullItemInput))
        end
    elseif command == "needlist" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r Custom Auto-Need List:")
        if #qtRollDB.autoNeedCustomList == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("  List is empty.")
        else
            for i, itemId_list in ipairs(qtRollDB.autoNeedCustomList) do
                local name, link = GetItemInfoCustom and GetItemInfoCustom(itemId_list) or GetItemInfo(itemId_list)
                DEFAULT_CHAT_FRAME:AddMessage(("[%d] %s"):format(i, link or name or "item:"..itemId_list))
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Unknown command. Usage: /qtroll [debug|needadd|needremove|needlist]")
    end
end

-- Updated test command with new features
-- Updated test command with new features
SLASH_QTROLLTEST1 = "/qtrolltest"
SlashCmdList["QTROLLTEST"] = function(msg)
    if not qtRollDB or qtRollDB.enabled == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Addon is currently disabled. Enable with /qtroll or via settings.")
        return
    end
    
    local link_input = msg:match("|c.-|r") or msg 
    if not link_input or link_input == "" then
        print("|cff00bfffqt|r|cffff7d0aRoll|r: Provide item name, ID, or link for testing.")
        return
    end

    local name, actualLinkToTest, rarity, _, _, itype, isub
    local actualItemId = ResolveItemToID(link_input)
    
    if actualItemId then
        -- If input was already a full item link, preserve it to keep forge information
        if link_input:match("|H") then
            actualLinkToTest = link_input
            qtRollDebug("Using original item link: " .. actualLinkToTest)
        else
            -- Only create basic link if input was just an ID or name
            name, actualLinkToTest, rarity, _, _, itype, isub = GetItemInfoCustom and GetItemInfoCustom(actualItemId) or GetItemInfo(actualItemId)
            if not actualLinkToTest then actualLinkToTest = "item:"..actualItemId end
        end
        
        -- Get item info for basic properties (but keep the original link for forge info)
        name, _, rarity, _, _, itype, isub = GetItemInfoCustom and GetItemInfoCustom(actualItemId) or GetItemInfo(actualItemId)
        if not name then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: No info for item ID '" .. actualItemId .. "'")
            return
        end
    else
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: Failed to resolve item: " .. link_input)
        return
    end

    -- Test all the logic following the same order as main function
    if rarity == 5 then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NO ACTION (Legendary Item)"); 
        return
    end

    -- Custom/default lists
    for _, customNeedId in ipairs(qtRollDB.autoNeedCustomList or {}) do
        if customNeedId == actualItemId then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Custom List)"); return
        end
    end
    
    for _, defaultNeedId in ipairs(qtRollDB.defaultNeedRoll or {}) do
        if defaultNeedId == actualItemId then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Default List)"); return
        end
    end

    if TooltipHasAlreadyKnown(actualLinkToTest) then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Known)"); return
    end

    if itype == "Recipe" then
        if isub == "Class Books" then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Codex Recipe)"); return
        elseif qtRollDB.greedOnRecipe == 1 then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => GREED (Unknown Recipe)"); return
        end
    end

    local isAtt_test = IsAttunable(actualLinkToTest)
    local isBoE_test, isBoP_test = GetBindingTypeFromTooltip(actualLinkToTest)
    local isRes_test = RESOURCE_TYPES[itype] or RESOURCE_TYPES[isub] or TRADE_GOODS_ITEMS[actualItemId]
    local isLock_test = IsLockbox(actualLinkToTest)
    local isMythic_test = IsMythicItem(actualLinkToTest)
    local currentForgeLevel_test = GetForgeLevelFromLink(actualLinkToTest)
    local isTok_test_val = IsToken(actualLinkToTest)
    local isTokP_test = isTok_test_val and TokenIsForPlayer(actualLinkToTest)

    -- Test attunement progress for fully attuned check
    local attuneProg = 0
    if GetItemLinkAttuneProgress then
        attuneProg = GetItemLinkAttuneProgress(actualLinkToTest) or 0
    end

    -- Fully attuned check (Updated: BoE & fully attuned => GREED, else PASS)
    if isAtt_test and attuneProg >= 100 then
        if isBoE_test and qtRollDB.autoGreed > 0 then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => GREED (Fully attuned BoE)"); return
        else
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Fully attuned)"); return
        end
    end

    -- Test duplicate check - but skip for items that should be needed/greeded
    if isBoP_test and not isTok_test_val then
        -- Don't apply duplicate check to items in custom need list
        local isInCustomNeedList = false
        if actualItemId and qtRollDB.autoNeedCustomList then
            for _, id in ipairs(qtRollDB.autoNeedCustomList) do
                if id == actualItemId then
                    isInCustomNeedList = true
                    break
                end
            end
        end
        
        -- Don't apply duplicate check to items in default need list
        local isInDefaultNeedList = false
        if actualItemId and qtRollDB.defaultNeedRoll then
            for _, id in ipairs(qtRollDB.defaultNeedRoll) do
                if id == actualItemId then
                    isInDefaultNeedList = true
                    break
                end
            end
        end
        
        -- Don't apply duplicate check to trade goods items
        local isTradeGood = RESOURCE_TYPES[itype] or RESOURCE_TYPES[isub] or TRADE_GOODS_ITEMS[actualItemId]
        
        -- Don't apply duplicate check to attunable items
        local isAttunable = IsAttunable(actualLinkToTest)
        
        -- Don't apply duplicate check to class tokens (even if IsToken didn't catch them)
        local isForPlayer = TokenIsForPlayer(actualLinkToTest)
        
        if not isInCustomNeedList and not isInDefaultNeedList and not isTradeGood and not isAttunable and not isForPlayer then
            local foundDupe, dupeLink = ItemExistsInBags(actualItemId, name)
            if foundDupe then
                if isMythic_test then
                    print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => DISENCHANT (Duplicate Mythic BoP)"); return
                else
                    print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Duplicate Non-essential BoP)"); return
                end
            end
        end
    end

    -- 1) BoE + any forge tier => NEED
    if isBoE_test and currentForgeLevel_test > FORGE_LEVEL_MAP.BASE then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Forged BoE)"); return
    end

    -- 2) Check for forge upgrades using enhanced logic
    if IsUsableItem(actualLinkToTest) then
        local shouldNeedForForge = ShouldNeedForForgeUpgrade(actualLinkToTest, actualItemId)
        if shouldNeedForForge then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Forge Upgrade)"); return
        end
    end

    if qtRollDB.needOnToken == 1 and (isTok_test_val or TokenIsForPlayer(actualLinkToTest)) then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Token)"); return
    end

    -- Updated attunement need test using the new logic
    if qtRollDB.autoNeed > 0 and isAtt_test then
        local shouldNeedForAttune = ItemQualifiesForAttuneNeed(actualLinkToTest, qtRollDB.needOnNewAffixOnly == 1)
        if shouldNeedForAttune then
            local modeText = qtRollDB.needOnNewAffixOnly == 1 and "Strict Mode" or "Lenient Mode"
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Attunable - " .. modeText .. ")"); return
        else
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => Attunable but does not qualify for need, continuing to other checks...")
            -- Continue to greed checks
        end
    end

    if qtRollDB.autoGreed > 0 and isBoE_test then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => GREED (BoE)"); return
    end

    if qtRollDB.greedOnLockbox > 0 and isLock_test then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => GREED (Lockbox)"); return
    end

    if qtRollDB.greedOnResource > 0 and isRes_test then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => GREED (Resource)"); return
    end
    
    if isMythic_test and isBoP_test then
        if not isAtt_test then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => DISENCHANT (Mythic BoP, not attunable)"); return
        elseif attuneProg > 0 then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => DISENCHANT (Mythic BoP, has progress)"); return
        end
    end

    if qtRollDB.autoPass > 0 and isBoP_test and not isAtt_test and itype ~= "Recipe" then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (BoP, not attun)"); return
    end

    if rarity and rarity < 4 then 
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Rarity<4)"); return
    end

    print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NO ACTION (Fell through all rules)");
end

qtRollDebug("qtRoll Addon loaded. v4.5")