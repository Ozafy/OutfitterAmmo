local AddonName = ...

local AMMO_SLOT = INVSLOT_AMMO or 0

local L = {
   Ammo = "Ammo",
   None = "None",
   UseEquipped = "Equipped: %s",
   NoAmmoEquipped = "Equip the ammo first to link it",
   NotInBags = "%s for outfit '%s' isn't in your bags.",
}

local frame = CreateFrame("Frame")
local pendingAmmo -- ammo to equip once combat ends

local function Print(msg)
   print("|cff33ff99" .. AddonName .. "|r: " .. msg)
end

-- outfit name -> ammo item id, per character
local function GetDB()
   OutfitterAmmoDB = OutfitterAmmoDB or {}
   OutfitterAmmoDB.outfits = OutfitterAmmoDB.outfits or {}
   return OutfitterAmmoDB.outfits
end

-- an empty ammo slot gives 0 instead of nil
local function GetEquippedAmmo()
   local itemID = GetInventoryItemID("player", AMMO_SLOT)
   if itemID and itemID > 0 then
      return itemID
   end
end

local function GetItemName(itemID)
   local name = C_Item.GetItemInfo(itemID)
   return name or ("item:" .. itemID)
end

local function EquipAmmo(itemID, outfitName)
   if GetEquippedAmmo() == itemID then
      return
   end
   if InCombatLockdown() then
      pendingAmmo = itemID
      frame:RegisterEvent("PLAYER_REGEN_ENABLED")
      return
   end
   if C_Item.GetItemCount(itemID) == 0 then
      Print(L.NotInBags:format(GetItemName(itemID), outfitName or "?"))
      return
   end
   EquipItemByName(itemID)
end

local function OnWearOutfit(event, outfitName)
   local itemID = outfitName and GetDB()[outfitName]
   if itemID then
      EquipAmmo(itemID, outfitName)
   end
end

local function OnRenameOutfit(event, outfit, previousName)
   local db = GetDB()
   if previousName and db[previousName] then
      db[outfit:GetName()] = db[previousName]
      db[previousName] = nil
   end
end

local function OnDeleteOutfit(event, outfitName)
   if outfitName then
      GetDB()[outfitName] = nil
   end
end

local function AddAmmoMenu(_, menu, outfit)
   if not outfit or not menu or not menu.AddChildMenu then
      return
   end
   local outfitName = outfit:GetName()
   menu:AddChildMenu(L.Ammo, function(submenu)
      local db = GetDB()
      submenu:AddToggle(L.None, function()
         return db[outfitName] == nil
      end, function()
         db[outfitName] = nil
      end)

      local equipped = GetEquippedAmmo()
      if equipped then
         submenu:AddToggle(L.UseEquipped:format(GetItemName(equipped)), function()
            return db[outfitName] == equipped
         end, function()
            db[outfitName] = equipped
         end)
      else
         submenu:AddFunction(L.NoAmmoEquipped, function() end, true)
      end

      -- the linked ammo, when it's not what's equipped right now
      local linked = db[outfitName]
      if linked and linked ~= equipped then
         submenu:AddToggle(GetItemName(linked), function()
            return db[outfitName] == linked
         end, function()
            db[outfitName] = linked
         end)
      end
   end)
end

frame:SetScript("OnEvent", function(self, event, ...)
   if event == "PLAYER_LOGIN" then
      if not Outfitter or not Outfitter.RegisterOutfitEvent then
         return
      end
      Outfitter:RegisterOutfitEvent("WEAR_OUTFIT", OnWearOutfit)
      Outfitter:RegisterOutfitEvent("DID_RENAME_OUTFIT", OnRenameOutfit)
      Outfitter:RegisterOutfitEvent("DELETE_OUTFIT", OnDeleteOutfit)
      hooksecurefunc(Outfitter, "AddOutfitMenu", AddAmmoMenu)
   elseif event == "PLAYER_REGEN_ENABLED" then
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      if pendingAmmo then
         local itemID = pendingAmmo
         pendingAmmo = nil
         EquipAmmo(itemID)
      end
   end
end)
frame:RegisterEvent("PLAYER_LOGIN")
