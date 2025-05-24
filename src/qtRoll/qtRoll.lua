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

local function TooltipHasAlreadyKnown(itemLink)
    local tooltip = CreateFrame(
        "GameTooltip", "qtRollAlreadyKnownTooltip", nil,
        "GameTooltipTemplate"
    )
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    for i = 2, tooltip:NumLines() do
        local text = _G[
            "qtRollAlreadyKnownTooltipTextLeft" .. i
        ]:GetText()
        if text and (text:find(ITEM_SPELL_KNOWN)
            or text:find("Already known")) then
            tooltip:Hide()
            return true
        end
    end
    tooltip:Hide()
    return false
end

local function IsToken(itemLink)
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    return itemType == "Miscellaneous" and (
        itemSubType == "Token" or itemSubType == "Reagent"
        or itemSubType == "Junk"
    )
end

local function TokenIsForPlayer(itemLink)
    local _, playerClass = UnitClass("player")
    local className = LOCALIZED_CLASS_NAMES_MALE
        and LOCALIZED_CLASS_NAMES_MALE[playerClass]
        or playerClass
    local tooltip = CreateFrame(
        "GameTooltip", "qtRollTokenTooltip", nil,
        "GameTooltipTemplate"
    )
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    for i = 2, tooltip:NumLines() do
        local text = _G[
            "qtRollTokenTooltipTextLeft" .. i
        ]:GetText()
        if text and text:find(className) then
            tooltip:Hide()
            return true
        end
    end
    tooltip:Hide()
    return false
end

local function GetBindingTypeFromTooltip(itemLink)
    local tooltip = CreateFrame(
        "GameTooltip", "qtRollScanTooltip", nil,
        "GameTooltipTemplate"
    )
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    local isBoE, isBoP = false, false
    for i = 2, tooltip:NumLines() do
        local text = _G[
            "qtRollScanTooltipTextLeft" .. i
        ]:GetText()
        if text then
            if text:find("Binds when equipped")
                or text:find(ITEM_BIND_ON_EQUIP) then
                isBoE = true
            elseif text:find("Binds when picked up")
                or text:find(ITEM_BIND_ON_PICKUP) then
                isBoP = true
            end
        end
    end
    tooltip:Hide()
    return isBoE, isBoP
end

local RESOURCE_TYPES = {
    ["Trade Goods"] = true,
    ["Consumable"] = true
}

local function IsLockbox(itemLink)
    local name = GetItemInfo(itemLink)
    if name and name:lower():find("lockbox") then
        return true
    end
    return false
end

local function ResolveItemToID(identifier)
    local itemId
    if type(identifier) == "string" then
        local name, link, _, _, _, _, _, _, _, _, idFromInfo = GetItemInfo(identifier)
        if idFromInfo then
            itemId = idFromInfo
        else
            local numId = tonumber(identifier)
            if numId and GetItemInfo(numId) then
                itemId = numId
            end
        end
    elseif type(identifier) == "number" then
        if GetItemInfo(identifier) then
            itemId = identifier
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
        qtRollDebug(
            "START_LOOT_ROLL: invalid itemLink for rollID "
            .. tostring(rollID)
        )
        return
    end

    local itemName, itemLink2, rarity, _, _, itemType, itemSubType =
        GetItemInfo(itemLink)
    qtRollDB = qtRollDB or {}
    local _, isBoP = GetBindingTypeFromTooltip(itemLink)
    local isTok = IsToken(itemLink)
    local currentItemId = tonumber(itemLink:match("item:(%d+)"))

    local function DoRoll(choice)
        RollOnLoot(rollID, choice)
        if choice > 0 and isBoP then
            ConfirmLootRoll(rollID, choice)
        end
    end

    if currentItemId and qtRollDB.autoNeedCustomList then
        for _, customNeedId in ipairs(qtRollDB.autoNeedCustomList) do
            if customNeedId == currentItemId then
                qtRollDebug("Need custom list item: " .. itemLink)
                DoRoll(1)
                return
            end
        end
    end

    if currentItemId and qtRollDB.defaultNeedRoll and type(qtRollDB.defaultNeedRoll) == "table" then
        for _, defaultNeedId in ipairs(qtRollDB.defaultNeedRoll) do
            if defaultNeedId == currentItemId then
                qtRollDebug("Need default list item: " .. itemLink)
                DoRoll(1)
                return
            end
        end
    end

    if TooltipHasAlreadyKnown(itemLink) then
        qtRollDebug("Passing known: " .. itemLink)
        DoRoll(0)
        return
    end

    if itemType == "Recipe" and itemSubType == "Class Books" then
        qtRollDebug("Passing codex class book: " .. itemLink)
        DoRoll(0)
        return
    end

    if isBoP and not isTok then
        local tf = -1
        if GetItemLinkTitanforge then
            tf = GetItemLinkTitanforge(itemLink) or 0
        else
            qtRollDebug("No Titanforge function for pass rule")
        end
        if tf == 0 then
            qtRollDebug("BoP non-token forge 0; scanning bags")
            local id
            if itemLink2 then
                id = tonumber(
                    string.match(itemLink2, "item:(%d+)")
                )
            end
            local found = false
            if id or itemName then
                for bag = 0, 4 do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local link = GetContainerItemLink(bag, slot)
                        if link then
                            local nameB, linkB_Bag = GetItemInfo(link)
                            local idB
                            if linkB_Bag then
                                idB = tonumber(
                                    string.match(linkB_Bag, "item:(%d+)")
                                )
                            end
                            if id and idB == id then
                                found = true
                                break
                            elseif itemName and nameB == itemName then
                                found = true
                                break
                            end
                        end
                    end
                    if found then break end
                end
                if found then
                    qtRollDebug("Found duplicate; passing: " .. itemLink)
                    DoRoll(0)
                    return
                end
            end
        end
    end

    local isAtt = SynastriaCoreLib
        and SynastriaCoreLib.IsAttunable
        and SynastriaCoreLib.IsAttunable(itemLink)
    local hasAttuneProgress = false
    if isAtt then
        hasAttuneProgress = SynastriaCoreLib and SynastriaCoreLib.HasAttuneProgress and SynastriaCoreLib.HasAttuneProgress(itemLink)
    end

    local isBoE_from_tooltip = not isBoP
    local isRes = RESOURCE_TYPES[itemType]
    local isLock = IsLockbox(itemLink)

    if qtRollDB.needOnWeakerForge == 1
        and GetItemLinkTitanforge then
        local curTF = GetItemLinkTitanforge(itemLink) or 0
        if curTF > 0 then
            for bag = 0, 4 do
                for slot = 1, GetContainerNumSlots(bag) do
                    local link = GetContainerItemLink(bag, slot)
                    if link and GetItemInfo(link) == itemName then
                        local tfB = GetItemLinkTitanforge(link) or 0
                        if tfB < curTF then
                            qtRollDebug(
                                "Need weaker forge: " .. itemLink
                            )
                            DoRoll(1)
                            return
                        end
                    end
                end
            end
        end
    end

    if qtRollDB.needOnToken == 1
        and isTok
        and TokenIsForPlayer(itemLink) then
        qtRollDebug("Need token: " .. itemLink)
        DoRoll(1)
        return
    end

    if qtRollDB.autoNeed > 0 and isAtt and not hasAttuneProgress then
        qtRollDebug("Need attunable (no progress): " .. itemLink)
        DoRoll(1)
        return
    elseif qtRollDB.autoGreed > 0 and isBoE_from_tooltip then
        qtRollDebug("Greed BoE: " .. itemLink)
        DoRoll(2)
        return
    elseif qtRollDB.greedOnLockbox > 0 and isLock then
        qtRollDebug("Greed lockbox: " .. itemLink)
        DoRoll(2)
        return
    elseif qtRollDB.greedOnResource > 0 and isRes then
        qtRollDebug("Greed resource: " .. itemLink)
        DoRoll(2)
        return
    elseif qtRollDB.autoPass > 0 and isBoP and not isAtt then
        qtRollDebug("Pass BoP (not attunable for player): " .. itemLink)
        DoRoll(0)
        return
    elseif rarity and rarity < 4 then
        qtRollDebug("Pass low rarity: " .. itemLink)
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
        if qtRollDB.debugMode == 1 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Debug messages enabled.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Debug messages disabled.")
        end
    elseif command == "" then
        qtRollDB.enabled = (qtRollDB.enabled == 1) and 0 or 1
        if qtRollDB.enabled == 1 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Addon enabled.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00bfffqt|r|cffff7d0aRoll|r: Addon disabled.")
        end
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
            if not found then
                table.insert(qtRollDB.autoNeedCustomList, itemId)
                local _, itemLink_add = GetItemInfo(itemId)
                DEFAULT_CHAT_FRAME:AddMessage(("|cff00bfffqt|r|cffff7d0aRoll|r: Added %s to custom need list."):format(itemLink_add or "item:"..itemId))
            else
                local _, itemLink_add = GetItemInfo(itemId)
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
            local _, itemLink_rem = GetItemInfo(itemIdToRemove)
            itemRemovedDisplay = itemLink_rem or "item:"..itemIdToRemove
            table.remove(qtRollDB.autoNeedCustomList, listIndex)
            removed = true
        else
            itemIdToRemove = ResolveItemToID(fullItemInput)
            if itemIdToRemove then
                local _, itemLink_rem = GetItemInfo(itemIdToRemove)
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
                local name, link = GetItemInfo(itemId_list)
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
    local link = msg:match("|c.-|r") or msg
    if not link or link == "" then
        print(
            "|cff00bfffqt|r|cffff7d0aRoll|r: Provide item name or link."
        )
        return
    end
    local name, link2, rarity, _, _, itype, isub, _, _, _, itemIdFromFile =
        GetItemInfo(link)

    local actualItemId
    if link2 then
        actualItemId = tonumber(link2:match("item:(%d+)"))
    elseif name then
        actualItemId = itemIdFromFile
    else
        local tempId = tonumber(link:match("item:(%d+)"))
        if tempId then
            actualItemId = tempId
        end
    end


    if not name and not (actualItemId and GetItemInfo(actualItemId)) then
        print(
            "|cff00bfffqt|r|cffff7d0aRoll|r: No info for '" ..
            link .. "'."
        )
        return
    end

    local actual = link2 or (actualItemId and select(2, GetItemInfo(actualItemId))) or link


    local action = "NO ACTION"
    qtRollDB = qtRollDB or {}
    qtRollDB.autoNeedCustomList = qtRollDB.autoNeedCustomList or {}
    -- Ensure defaultNeedRoll is a table with defaults for the test command context
    if type(qtRollDB.defaultNeedRoll) ~= "table" or #qtRollDB.defaultNeedRoll == 0 then
         qtRollDB.defaultNeedRoll = {43102, 47242}
    end


    if actualItemId and qtRollDB.autoNeedCustomList then
        for _, customNeedId in ipairs(qtRollDB.autoNeedCustomList) do
            if customNeedId == actualItemId then
                action = "NEED (Custom List)"
                print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actual .. " => " .. action)
                return
            end
        end
    end
    
    if actualItemId and qtRollDB.defaultNeedRoll and type(qtRollDB.defaultNeedRoll) == "table" then
        for _, defaultNeedId in ipairs(qtRollDB.defaultNeedRoll) do
            if defaultNeedId == actualItemId then
                action = "NEED (Default List)"
                print("|cff00bfffqt|r|cffff7d0aRoll|r Test: " .. actual .. " => " .. action)
                return
            end
        end
    end

    local isAtt = SynastriaCoreLib
        and SynastriaCoreLib.IsAttunable
        and SynastriaCoreLib.IsAttunable(actual)
    local hasAttuneProg = false
    if isAtt then
        hasAttuneProg = SynastriaCoreLib and SynastriaCoreLib.HasAttuneProgress and SynastriaCoreLib.HasAttuneProgress(actual)
    end
    local isBoE_test, isBoP_test = GetBindingTypeFromTooltip(actual)
    local isRes_test = RESOURCE_TYPES[itype]
    local isLock_test = IsLockbox(actual)


    if TooltipHasAlreadyKnown(actual) then
        action = "PASS (Known)"
    elseif itype == "Recipe"
        and isub == "Class Books" then
        action = "PASS (Codex)"
    else
        local hasWeak = false
        if qtRollDB.needOnWeakerForge == 1
            and GetItemLinkTitanforge then
            local tf = GetItemLinkTitanforge(actual)
            if tf and tf > 0 then
                for bag = 0, 4 do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local linkB_Test = GetContainerItemLink(bag, slot)
                        if linkB_Test
                            and GetItemInfo(linkB_Test) == name then
                            local tfB = GetItemLinkTitanforge(linkB_Test)
                                or 0
                            if tfB < tf then
                                hasWeak = true
                                break
                            end
                        end
                    end
                    if hasWeak then break end
                end
            end
        end
        local isTokP = IsToken(actual)
            and TokenIsForPlayer(actual)
        if hasWeak then
            action = "NEED (Weaker)"
        elseif qtRollDB.needOnToken == 1 and isTokP then
            action = "NEED (Token)"
        elseif qtRollDB.autoNeed > 0 and isAtt and not hasAttuneProg then
            action = "NEED (Attun, no prog)"
        elseif qtRollDB.autoGreed > 0 and isBoE_test then
            action = "GREED (BoE)"
        elseif qtRollDB.greedOnLockbox > 0 and isLock_test then
            action = "GREED (Lockbox)"
        elseif qtRollDB.greedOnResource > 0 and isRes_test then
            action = "GREED (Resource)"
        elseif qtRollDB.autoPass > 0 and isBoP_test and not isAtt then
            action = "PASS (BoP)"
        elseif rarity and rarity < 4 then
            action = "PASS (Rarity<4)"
        end
    end
    print("|cff00bfffqt|r|cffff7d0aRoll|r Test: "
        .. actual .. " => " .. action)
end

qtRollDebug("qtRoll Addon loaded")