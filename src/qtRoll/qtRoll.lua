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
            43102,
            47242
        }
    }
else
    if type(qtRollDB.autoNeedCustomList) ~= "table" then
        qtRollDB.autoNeedCustomList = {}
    end

    if type(qtRollDB.defaultNeedRoll) ~= "table" or #qtRollDB.defaultNeedRoll == 0 then
        qtRollDB.defaultNeedRoll = {
            43102,
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

local function HasNewAffixes(itemLink)
    if not itemLink then return false end
    
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then return false end
    
    return HasAttunedAnyVariantOfItem(itemID)
end

local function ItemExistsInBags(itemId, itemName)
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
    -- Gather every string UnitClass returns (localized, English, etc.),
    -- even if one of them is nil in the middle.
    local classNames = {}
    local c1, c2, c3 = UnitClass("player")
    for _, c in ipairs({ c1, c2, c3 }) do
      if type(c) == "string" then
        classNames[#classNames + 1] = c
      end
    end
  
    if #classNames == 0 then
      qtRollDebug("TokenIsForPlayer: no class names from UnitClass")
      return false
    end
  
    -- Lower‐case them once so we can do a case‐insensitive search
    for i = 1, #classNames do
      classNames[i] = classNames[i]:lower()
    end
  
    -- Populate tooltip
    TokenScanner:ClearLines()
    TokenScanner:SetHyperlink(itemLink)
  
    -- Scan each line for *any* of our class names
    for i = 2, TokenScanner:NumLines() do
      local line = _G["qtRollTokenTooltipTextLeft"..i]
      if not line then
        break
      end
      local text = line:GetText()
      if text then
        local tl = text:lower()
        for _, cls in ipairs(classNames) do
          -- plain find is fine now since we lowered both strings
          if tl:find(cls, 1, true) then
            TokenScanner:Hide()
            return true
          end
        end
      end
    end
  
    TokenScanner:Hide()
    return false
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
    ["Gem"] = true
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
    local isRes = RESOURCE_TYPES[itemType]
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
  
    -- Enhanced BoP duplicate check
    if isBoP and not isTok then
      local foundDupe, dupeLink = ItemExistsInBags(currentItemId,
        itemName)
      if foundDupe then
        if isMythic then
          qtRollDebug("Duplicate mythic BoP; disenchant: " ..
            (itemLink2 or itemLink))
          DoRoll(3)
          return
        else
          qtRollDebug("Duplicate non-token BoP; pass: " ..
            (itemLink2 or itemLink))
          DoRoll(0)
          return
        end
      end
    end
  
    -- Forge logic

    -- 1) BoE + any forge tier (i.e. currentForge > BASE) => NEED
    if isBoE and currentForge > FORGE_LEVEL_MAP.BASE then
        qtRollDebug(("Forged BoE – NEED: %s")
          :format(itemLink2 or itemLink))
        DoRoll(1)  -- NEED
        return
    end

    -- 2) BoP + equippable + strictly better forge than any you already own => NEED
    if isBoP and IsUsableItem(itemLink) then
        local worstForge  -- will hold the lowest‐tier forge you already have
        -- scan your bags
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local linkBag = GetContainerItemLink(bag, slot)
                if linkBag then
                    local idBag = tonumber(linkBag:match("item:(%d+)"))
                    if idBag == currentItemId then
                        local forgeBag = GetForgeLevelFromLink(linkBag)
                        if not worstForge or forgeBag < worstForge then
                            worstForge = forgeBag
                        end
                    end
                end
            end
        end
        -- scan your equipped gear (slots 1–19)
        for slotID = 1, 19 do
            local linkEq = GetInventoryItemLink("player", slotID)
            if linkEq then
                local idEq = tonumber(linkEq:match("item:(%d+)"))
                if idEq == currentItemId then
                    local forgeEq = GetForgeLevelFromLink(linkEq)
                    if not worstForge or forgeEq < worstForge then
                        worstForge = forgeEq
                    end
                end
            end
        end

        -- if we found an older forge version and this one is strictly higher:
        if worstForge and currentForge > worstForge then
            qtRollDebug(("Upgraded BoP – NEED (old:%d → new:%d): %s")
              :format(worstForge, currentForge, itemLink2 or itemLink))
            DoRoll(1)  -- NEED
            return
        end
    end
  
    -- Token need
    if qtRollDB.needOnToken == 1 and isTok and TokenIsForPlayer(itemLink)
    then
      qtRollDebug("Need token for player: " .. (itemLink2 or itemLink))
      DoRoll(1)
      return
    end
  
    -- Attunement need
    if qtRollDB.autoNeed > 0 and isAtt and not hasAttune then
      if qtRollDB.needOnNewAffixOnly == 1 then
        if HasNewAffixes(itemLink) then
          qtRollDebug("Need attunable with NEW affixes: "..itemLink)
          DoRoll(1)
        elseif not(HasNewAffixes(itemLink)) and isBoE then
          qtRollDebug("Greed BoE: " .. (itemLink2 or itemLink))
          DoRoll(2)
        elseif isMythic and isBoP then
            qtRollDebug("Disenchant mythic BoP (not attunable): " ..
              (itemLink2 or itemLink))
            DoRoll(3)
        else
          qtRollDebug("Pass (no new affixes): "..itemLink)
          DoRoll(0)
        end
      else
        qtRollDebug("Need attunable (no progress): "..itemLink)
        DoRoll(1)
      end
      return
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
        name, actualLinkToTest, rarity, _, _, itype, isub = GetItemInfoCustom and GetItemInfoCustom(actualItemId) or GetItemInfo(actualItemId)
        if not name then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: No info for item ID '" .. actualItemId .. "'")
            return
        end
    else
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: Failed to resolve item: " .. link_input)
        return
    end
    
    if not actualLinkToTest then actualLinkToTest = "item:"..actualItemId end

    -- Test all the logic
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
    local hasAttuneProg_test = HasAttuneProgress(actualLinkToTest)
    local isBoE_test, isBoP_test = GetBindingTypeFromTooltip(actualLinkToTest)
    local isRes_test = RESOURCE_TYPES[itype]
    local isLock_test = IsLockbox(actualLinkToTest)
    local isMythic_test = IsMythicItem(actualLinkToTest)
    local currentForgeLevel_test = GetForgeLevelFromLink(actualLinkToTest)
    local isTok_test_val = IsToken(actualLinkToTest)
    local isTokP_test = isTok_test_val and TokenIsForPlayer(actualLinkToTest)

    -- Test duplicate check
    local foundDupe, dupeLink = ItemExistsInBags(actualItemId, name)
    if isBoP_test and not isTok_test_val and foundDupe then
        if isMythic_test then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => DISENCHANT (Duplicate Mythic BoP)"); return
        else
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Duplicate BoP)"); return
        end
    end

    if qtRollDB.needOnToken == 1 and isTokP_test then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Token)"); return
    end

    if qtRollDB.autoNeed > 0 and isAtt_test and not hasAttuneProg_test then
        if qtRollDB.needOnNewAffixOnly == 1 then
            if HasNewAffixes(actualLinkToTest) then
                print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Attun, new affixes)"); return
            else
                print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => SKIP (Attun, no new affixes)");
            end
        else
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Attun, no prog)"); return
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
        if not isAtt_test or hasAttuneProg_test then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => DISENCHANT (Mythic BoP, not useful)"); return
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

qtRollDebug("qtRoll Addon loaded. v4")