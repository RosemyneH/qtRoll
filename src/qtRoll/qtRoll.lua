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
        autoPass = 1,
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
end

local SynastriaCoreLib = LibStub('SynastriaCoreLib-1.0')

local function qtRollDebug(msg)
    if qtRollDB and qtRollDB.enabled == 1 and qtRollDB.debugMode and qtRollDB.debugMode > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00bfffqt|r|cffff7d0aRoll|r Debug: " .. msg
        )
    end
end

local function IsMythicItem(itemLink_for_scan)
    if not itemLink_for_scan then return false end
    local tt = CreateFrame("GameTooltip", "qtRollMythicItemScannerTooltip", nil, "GameTooltipTemplate")
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:SetHyperlink(itemLink_for_scan)
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
    local _, _, _, _, _, itemType, itemSubType = GetItemInfoCustom(itemId)
    return itemType == "Miscellaneous" and (
        itemSubType == "Token" or itemSubType == "Reagent" or itemSubType == "Junk"
    )
end

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
    ["Gem"] = true
}

local function IsLockbox(itemLink)
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    if not itemId then
        qtRollDebug("IsLockbox: Could not parse itemID from link: " .. itemLink)
        return false
    end
    local name = GetItemInfoCustom(itemId)
    if name and name:lower():find("lockbox") then
        return true
    end
    return false
end

local function ResolveItemToID(identifier)
    local itemId
    if type(identifier) == "number" then
        local name_check = GetItemInfoCustom(identifier)
        if name_check then
            itemId = identifier
        end
    elseif type(identifier) == "string" then
        local idFromLinkMatch = tonumber(identifier:match("item:(%d+)"))
        if idFromLinkMatch then
            local name_check = GetItemInfoCustom(idFromLinkMatch)
            if name_check then
                return idFromLinkMatch
            end
        end

        local idFromDirectNumberParse = tonumber(identifier)
        if idFromDirectNumberParse then
             local name_check = GetItemInfoCustom(idFromDirectNumberParse)
             if name_check then
                 return idFromDirectNumberParse
             end
        end
        
        -- If identifier is an item name, GetItemInfoCustom is expected to handle it
        -- and return an itemLink from which the ID can be parsed.
        local _, itemLinkFromCustom = GetItemInfoCustom(identifier)
        if itemLinkFromCustom then
            itemId = tonumber(itemLinkFromCustom:match("item:(%d+)"))
        end
    end
    return itemId
end

local f = CreateFrame("Frame")
f:RegisterEvent("START_LOOT_ROLL")
f:SetScript("OnEvent", function(self, event, rollID)
    if not qtRollDB or qtRollDB.enabled == 0 then
        return
    end

    local itemLink = GetLootRollItemLink(rollID)
    if not itemLink then
        qtRollDebug("START_LOOT_ROLL: invalid itemLink for rollID " .. tostring(rollID))
        return
    end

    local currentItemId = tonumber(itemLink:match("item:(%d+)"))
    if not currentItemId then
        qtRollDebug("START_LOOT_ROLL: Could not parse itemID from link: " .. itemLink)
        return
    end

    local itemName, itemLink2, rarity, _, _, itemType, itemSubType = GetItemInfoCustom(currentItemId)
    qtRollDB = qtRollDB or {}

    if rarity == 5 then
        qtRollDebug("Item is Legendary: " .. (itemLink2 or itemLink) .. ". Taking NO ACTION (manual roll).")
        return
    end
    
    local isBoE_check, isBoP_check = GetBindingTypeFromTooltip(itemLink)
    local isTok = IsToken(itemLink)

    local function DoRoll(choice)
        RollOnLoot(rollID, choice)
        if choice > 0 and isBoP_check then 
            ConfirmLootRoll(rollID, choice)
        end
    end

    if currentItemId and qtRollDB.autoNeedCustomList then
        for _, customNeedId in ipairs(qtRollDB.autoNeedCustomList) do
            if customNeedId == currentItemId then
                qtRollDebug("Need custom list item: " .. (itemLink2 or itemLink))
                DoRoll(1)
                return
            end
        end
    end

    if currentItemId and qtRollDB.defaultNeedRoll and type(qtRollDB.defaultNeedRoll) == "table" then
        for _, defaultNeedId in ipairs(qtRollDB.defaultNeedRoll) do
            if defaultNeedId == currentItemId then
                qtRollDebug("Need default list item: " .. (itemLink2 or itemLink))
                DoRoll(1)
                return
            end
        end
    end

    if TooltipHasAlreadyKnown(itemLink) then
        qtRollDebug("Passing known (recipe or item): " .. (itemLink2 or itemLink))
        DoRoll(0)
        return
    end

    if itemType == "Recipe" then
        if itemSubType == "Class Books" then 
            qtRollDebug("Passing codex class book (recipe): " .. (itemLink2 or itemLink))
            DoRoll(0)
            return
        end
        qtRollDebug("Item is an unknown, non-codex recipe: " .. (itemLink2 or itemLink) .. ". Specific auto-pass rule for BoP non-attunables will ignore this type.")
    end

    local isAtt = SynastriaCoreLib and SynastriaCoreLib.IsAttunable and SynastriaCoreLib.IsAttunable(itemLink)
    local hasAttuneProgress = false
    if isAtt then
        hasAttuneProgress = SynastriaCoreLib and SynastriaCoreLib.HasAttuneProgress and SynastriaCoreLib.HasAttuneProgress(itemLink)
    end

    local isRes = RESOURCE_TYPES[itemType]
    local isLock = IsLockbox(itemLink)
    local isMythic = IsMythicItem(itemLink) 
    local currentForgeLevel = (GetItemLinkTitanforge and GetItemLinkTitanforge(itemLink)) or 0

    if isBoP_check and not isTok then
        local tf_duplicate_check = -1 
        if GetItemLinkTitanforge then
            tf_duplicate_check = GetItemLinkTitanforge(itemLink) or 0
        else
            qtRollDebug("No Titanforge function available for duplicate check on BoP item.")
        end
        if tf_duplicate_check <= 0 then 
            qtRollDebug("BoP non-token (forge " .. tf_duplicate_check .. "); scanning bags for duplicates of: " .. (itemLink2 or itemLink))
            local found_duplicate = false 
            if currentItemId or itemName then 
                for bag = 0, 4 do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local link_in_bag = GetContainerItemLink(bag, slot) 
                        if link_in_bag then
                            local itemId_in_bag = tonumber(link_in_bag:match("item:(%d+)"))
                            if itemId_in_bag then
                                if currentItemId and itemId_in_bag == currentItemId then
                                    found_duplicate = true; break
                                elseif not currentItemId and itemName then 
                                    local nameB_custom = GetItemInfoCustom(itemId_in_bag)
                                    if nameB_custom and nameB_custom == itemName then
                                        found_duplicate = true; break
                                    end
                                end
                            end
                        end
                    end
                    if found_duplicate then break end
                end
                if found_duplicate then
                    qtRollDebug("Found duplicate BoP non-token in bags; passing: " .. (itemLink2 or itemLink))
                    DoRoll(0)
                    return
                end
            end
        end
    end

    if qtRollDB.needOnWeakerForge == 1 and GetItemLinkTitanforge then
        if currentForgeLevel > 0 then
            for bag = 0, 4 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local link_in_bag = GetContainerItemLink(bag, slot)
                    if link_in_bag then
                        local itemId_in_bag_forge = tonumber(link_in_bag:match("item:(%d+)"))
                        if itemId_in_bag_forge then
                            local name_in_bag = GetItemInfoCustom(itemId_in_bag_forge) 
                            if name_in_bag and name_in_bag == itemName then 
                                local tfB = GetItemLinkTitanforge(link_in_bag) or 0
                                if tfB < currentForgeLevel then
                                    qtRollDebug("Need weaker forge (item in bag is "..tfB..", current is "..currentForgeLevel.."): " .. (itemLink2 or itemLink))
                                    DoRoll(1)
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if qtRollDB.needOnToken == 1 and isTok and TokenIsForPlayer(itemLink) then
        qtRollDebug("Need token for player: " .. (itemLink2 or itemLink))
        DoRoll(1)
        return
    end

    if qtRollDB.autoNeed > 0 and isAtt and not hasAttuneProgress then
        qtRollDebug("Need attunable (no progress): " .. (itemLink2 or itemLink))
        DoRoll(1)
        return
    end

    if qtRollDB.autoGreed > 0 and isBoE_check then 
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
    elseif not isAtt and isMythic and isBoP_check and not (currentForgeLevel > 0) then
        qtRollDebug("Disenchanting Mythic BoP (not attun, forge<=" .. currentForgeLevel .. "): " .. (itemLink2 or itemLink))
        DoRoll(3) 
        return
    elseif qtRollDB.autoPass > 0 and isBoP_check and not isAtt then
        if itemType == "Recipe" then
            qtRollDebug("Pass BoP (not attun) rule: SKIPPING for RECIPE " .. (itemLink2 or itemLink) .. ". Will fall to rarity/manual.")
        else
            qtRollDebug("Pass BoP (not attunable for player, NOT a recipe): " .. (itemLink2 or itemLink))
            DoRoll(0)
            return
        end
    elseif rarity and rarity < 4 then
        qtRollDebug("Pass low rarity (rarity=" .. rarity .. "): " .. (itemLink2 or itemLink))
        DoRoll(0)
        return
    end
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
            local _, itemLink_add = GetItemInfoCustom(itemId)
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
            local _, itemLink_rem = GetItemInfoCustom(itemIdToRemove)
            itemRemovedDisplay = itemLink_rem or "item:"..itemIdToRemove
            table.remove(qtRollDB.autoNeedCustomList, listIndex)
            removed = true
        else
            itemIdToRemove = ResolveItemToID(fullItemInput)
            if itemIdToRemove then
                local _, itemLink_rem = GetItemInfoCustom(itemIdToRemove)
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
                local name, link = GetItemInfoCustom(itemId_list)
                DEFAULT_CHAT_FRAME:AddMessage(("[%d] %s"):format(i, link or name or "item:"..itemId_list))
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Unknown command. Usage: /qtroll [debug|needadd|needremove|needlist]")
    end
end


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
    local actualItemId

    local id_from_input_str = tonumber(link_input)
    local id_from_input_link = tonumber(link_input:match("item:(%d+)"))

    if type(link_input) == "number" then
        actualItemId = link_input
    elseif id_from_input_link then
         actualItemId = id_from_input_link
    elseif id_from_input_str then -- Check if the plain string is a number (itemID)
        actualItemId = id_from_input_str
    end

    if actualItemId then
        name, actualLinkToTest, rarity, _, _, itype, isub = GetItemInfoCustom(actualItemId)
        if not name then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: No info for item ID '" .. actualItemId .. "' derived from input: " .. link_input)
            return
        end
    else
        -- Input is likely an item name, let GetItemInfoCustom handle it
        local tempName, tempLink, tempRarity, _, _, tempItype, tempIsub = GetItemInfoCustom(link_input)
        if not tempName then
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: No info for '" .. link_input .. "'. Ensure it's a valid item name, ID, or link.")
            return
        end
        if tempLink then
            actualItemId = tonumber(tempLink:match("item:(%d+)"))
            if actualItemId then
                 name, actualLinkToTest, rarity, _, _, itype, isub = GetItemInfoCustom(actualItemId) -- Re-fetch with confirmed ID
            else
                 print("|cff00bfffqt|r|cffff7d0aRoll|r Test: Could not parse ItemID from link resolved from name: " .. tempLink)
                 return
            end
        else
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: Item name '" .. link_input .. "' resolved but provided no link to get ID.")
            return
        end
    end
    
    if not actualItemId then
         print("|cff00bfffqt|r|cffff7d0aRoll|r Test: Failed to determine item ID for input: " .. link_input)
         return
    end
    if not actualLinkToTest then actualLinkToTest = "item:"..actualItemId end


    qtRollDB = qtRollDB or {}
    qtRollDB.autoNeedCustomList = qtRollDB.autoNeedCustomList or {}
    if type(qtRollDB.defaultNeedRoll) ~= "table" or #qtRollDB.defaultNeedRoll == 0 then
        qtRollDB.defaultNeedRoll = {43102, 47242}
    end

    if rarity == 5 then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NO ACTION (Legendary Item)"); 
        return
    end

    if actualItemId and qtRollDB.autoNeedCustomList then
        for _, customNeedId in ipairs(qtRollDB.autoNeedCustomList) do
            if customNeedId == actualItemId then
                print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Custom List)"); return
            end
        end
    end
    
    if actualItemId and qtRollDB.defaultNeedRoll then
        for _, defaultNeedId in ipairs(qtRollDB.defaultNeedRoll) do
            if defaultNeedId == actualItemId then
                print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Default List)"); return
            end
        end
    end

    if TooltipHasAlreadyKnown(actualLinkToTest) then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Known)"); return
    end

    if itype == "Recipe" and isub == "Class Books" then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Codex Recipe)"); return
    end

    local isAtt_test = SynastriaCoreLib and SynastriaCoreLib.IsAttunable and SynastriaCoreLib.IsAttunable(actualLinkToTest)
    local hasAttuneProg_test = false
    if isAtt_test then
        hasAttuneProg_test = SynastriaCoreLib and SynastriaCoreLib.HasAttuneProgress and SynastriaCoreLib.HasAttuneProgress(actualLinkToTest)
    end
    local isBoE_test, isBoP_test = GetBindingTypeFromTooltip(actualLinkToTest)
    local isRes_test = RESOURCE_TYPES[itype] 
    local isLock_test = IsLockbox(actualLinkToTest)
    local isMythic_test = IsMythicItem(actualLinkToTest)
    local currentForgeLevel_test = (GetItemLinkTitanforge and GetItemLinkTitanforge(actualLinkToTest)) or 0
    local isTok_test_val = IsToken(actualLinkToTest)
    local isTokP_test = isTok_test_val and TokenIsForPlayer(actualLinkToTest) 

    local hasWeak_test = false 
    if qtRollDB.needOnWeakerForge == 1 and GetItemLinkTitanforge and currentForgeLevel_test > 0 then
        -- This would require a simulated bag scan for full test accuracy.
        -- For simplicity, this test doesn't perform the bag scan.
        -- To test this rule, you would manually check your bags against a hypothetical item.
        -- print("|cff00bfffqt|r|cffff7d0aRoll|r Test: Weaker forge rule check (manual bag check needed for full verification).")
    end
    if hasWeak_test then 
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Weaker Forge - simulated)"); return
    end

    if qtRollDB.needOnToken == 1 and isTokP_test then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Token)"); return
    end

    if qtRollDB.autoNeed > 0 and isAtt_test and not hasAttuneProg_test then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NEED (Attun, no prog)"); return
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
    
    if not isAtt_test and isMythic_test and isBoP_test and not (currentForgeLevel_test > 0) then
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => DISENCHANT (Mythic BoP, not attun, forge<=" .. currentForgeLevel_test .. ")"); return
    end

    if qtRollDB.autoPass > 0 and isBoP_test and not isAtt_test then
        if itype == "Recipe" then
            -- Skipped
        else
            print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (BoP, not attun, NOT a recipe)"); return
        end
    end

    if rarity and rarity < 4 then 
        print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => PASS (Rarity<4)"); return
    end

    print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actualLinkToTest .. " => NO ACTION (Fell through all rules)");
end

qtRollDebug("qtRoll Addon loaded. v3 (GetItemInfoCustom update)")