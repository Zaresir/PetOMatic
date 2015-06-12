-----------------------------------------------------------------------------------------------
-- Client Lua Script for PetOMatic
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- PetOMatic Module Definition
-----------------------------------------------------------------------------------------------
local PetOMatic = {} 

local kstrContainerEventName = "PetOMatic"
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local config = {}

config.defaults = {}
config.user = {}

config.defaults.Creator = "Zaresir Tinktaker"
config.defaults.DisplayHeight = Apollo.GetDisplaySize().nHeight
config.defaults.btnOffset = {-96, -113, -4, -32}
config.defaults.lstOffset = {-122, -407, 12, -87}
config.defaults.wndOffsetL = -96
config.defaults.wndOffsetT = -113
config.defaults.wndOffsetR = -4
config.defaults.wndOffsetB = -32
config.defaults.wndListOffsetL = 26
config.defaults.wndListOffsetT = 294
config.defaults.wndListOffsetR = 16
config.defaults.wndListOffsetB = 55
config.defaults.SelectedPet = nil
config.defaults.AutoSummon = false
config.defaults.SuspendInRaid = false
config.defaults.HideAddon = false
config.defaults.MaxListSize = 7

config.user.Debug = false
config.user.CustomPosition = false
config.user.btnOffset = {}
config.user.lstOffset = {}
config.user.SelectedPet = nil
config.user.AutoSummon = false
config.user.SuspendInRaid = false
config.user.Moveable = false
config.user.HideAddon = false
config.user.MaxListSize = nil

SlashCommands = {
	debug = {desc = "Toggle DEBUG mode", hndlr = "E_PetOMaticDebug", func = "ToggleDebug"},
	config = {desc = "Open PetOMatic Options window", hndlr = "E_PetOMaticOptions", func = "ShowPetOptions"},
	auto = {desc = "Toggle autosummon feature", hndlr = "E_PetOMaticAutoSummon", func = "OnPetOptionsAutoSummonBtn"},
	hide = {desc = "Hide/show button", hndlr = "E_PetOMaticHide", func = "OnPetOptionsHideAddonBtn"}
}


-----------------------------------------------------------------------------------------------
-- New
-----------------------------------------------------------------------------------------------
function PetOMatic:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	self.ConfigData = {}
	self.ConfigData.default = setmetatable({}, {__index = config.defaults})
	self.ConfigData.saved = setmetatable({}, {__index = config.user})
	
	self.nSelectedPet = nil
	self.nSelectedPetCastTime = 0.0
	
	self.NumberOfPets = 0
	self.AutoSummonAttempts = 0
	self.LstAboveBtn = true
		
    return o
end

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PetOMatic:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {}
	
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
	Print("Init Success")
end

-----------------------------------------------------------------------------------------------
-- PetOMatic OnLoad Function
-----------------------------------------------------------------------------------------------
function PetOMatic:OnLoad()
	Apollo.LoadSprites("Sprites/PetOMaticBtn.xml")
	
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("PetOMatic.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	self:RegisterObjects()
end

-----------------------------------------------------------------------------------------------
-- PetOMatic OnDocLoaded Function
-----------------------------------------------------------------------------------------------
function PetOMatic:OnDocLoaded()
	self.wndPetFlyout = Apollo.LoadForm(self.xmlDoc, "PetFlyout", "FixedHudStratumLow", self)
	self.wndPetFlyoutFrame  = Apollo.LoadForm(self.xmlDoc, "PetFlyoutFrame", nil, self)
	self.wndPetFlyoutList = self.wndPetFlyoutFrame:FindChild("PetFlyoutList")
	
	self.wndPetFlyout:FindChild("PetFlyoutBtn"):SetCheck(false)
	self.wndPetFlyout:FindChild("PetFlyoutBtn"):AttachWindow(self.wndPetFlyoutFrame)
	
	self:PrintDebug("Display Size = " .. tostring(self.ConfigData.default.DisplayHeight))
	
	self:LoadWindowPosition()
			
	if self.wndPetOptions == nil or not self.wndPetOptions then
		self.wndPetOptions = Apollo.LoadForm(self.xmlDoc, "PetOptions", nil, self)
		
		self:LoadOptions()
		
		self.wndPetOptions:Show(false, true)
	end
	
	self.wndPetFlyout:Show(not self.ConfigData.saved.HideAddon)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic RegosterObjects Function
---------------------------------------------------------------------------------------------------
function PetOMatic:RegisterObjects()
	-- Register Events
	Apollo.RegisterEventHandler("GenericEvent_CollectablesReady", "UpdatePetList", self)
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListLoaded", self)
	Apollo.RegisterEventHandler("MoveList", "MoveFlyoutFrame", self)
	Apollo.RegisterEventHandler("CombatLogResurrect", "OnResurrect", self)
	Apollo.RegisterEventHandler("AbilityBookChange", "UpdatePetList", self)
	
	self:RegisterSlashCommandEvents()
	
	-- Register Timers
	Apollo.RegisterTimerHandler("AutoSummonTimer", "AutoSummon", self)
	Apollo.RegisterTimerHandler("SummonFlashTimer", "HideBtnFlash", self)

	-- Register Slash Commands
	Apollo.RegisterSlashCommand("pom", "SlashCommandHandler", self)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic RegisterSlashCommandEvents Function
---------------------------------------------------------------------------------------------------
function PetOMatic:RegisterSlashCommandEvents()
	for cmd, attribs in pairs(SlashCommands) do
		self:PrintDebug(string.format("Registering event handler: %s, %s", attribs.hndlr, attribs.func))
		
		Apollo.RegisterEventHandler(attribs.hndlr, attribs.func, self)
	end		
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnInterfaceMenuListHasLoaded Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnInterfaceMenuListLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "PetOMatic", {"PetOptionsMenuClicked", "", "IconSprites:Icon_Windows32_UI_CRB_InterfaceMenu_NonCombatAbility"})
	Apollo.RegisterEventHandler("PetOptionsMenuClicked", "ShowPetOptions", self)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleDebug Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleDebug()
	self.ConfigData.saved.Debug = not self.ConfigData.saved.Debug
	
	if self.ConfigData.saved.Debug then
		Print("PetOMatic: DEBUG MODE ENABLED")
	else
		Print("PetOMatic: DEBUG MODE DISABLED")
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic PrintDebug Function
---------------------------------------------------------------------------------------------------
function PetOMatic:PrintDebug(msg)
	if self.ConfigData.saved.Debug then
		Print("PetOMatic: " .. msg)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic RedrawSelectedPet Function
---------------------------------------------------------------------------------------------------
function PetOMatic:RedrawSelectedPet()
	self.nSelectedPetCastTime = self.nSelectedPet.splObject:GetCastTime()
	
	self:PrintDebug("Selected Pet = " .. self.nSelectedPet.strName)
	self:PrintDebug("Cast Time = " .. tostring(self.nSelectedPetCastTime))
	
	self.wndPetFlyout:FindChild("PetSummonBtnIcon"):SetSprite(self.nSelectedPet.splObject and self.nSelectedPet.splObject:GetIcon() or "Icon_ItemArmorWaist_Unidentified_Buckle_0001")
	self.wndPetFlyout:FindChild("PetSummonBtnIcon"):SetTooltip(self.nSelectedPet.strName)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic UpdatePetList Function
---------------------------------------------------------------------------------------------------
function PetOMatic:UpdatePetList()
	if not self.wndPetFlyoutList then
		return
	end
	
	self:PrintDebug("Updating Pet List")
	
	local arPetList = GameLib.GetVanityPetList()
	
	if #self.wndPetFlyoutList:GetChildren() > 0 then
		self.wndPetFlyoutList:DestroyChildren()
	end

	table.sort(arPetList, function(a,b) return (a.bIsKnown and not b.bIsKnown) or (a.bIsKnown == b.bIsKnown and a.strName < b.strName) end)

	for idx = 1, #arPetList do
		local tPetInfo = arPetList[idx]
		local wndPetBtn = nil
		
		if tPetInfo.bIsKnown then
			self:PrintDebug("Known Pet: " .. tPetInfo.strName)
			
			wndPetBtn = Apollo.LoadForm(self.xmlDoc, "PetBtn", self.wndPetFlyoutList, self)
			local wndPetBtnIcon = wndPetBtn:FindChild("PetBtnIcon")
			
			wndPetBtnIcon:SetSprite(tPetInfo.splObject and tPetInfo.splObject:GetIcon() or "Icon_ItemArmorWaist_Unidentified_Buckle_0001")
			wndPetBtn:SetData(tPetInfo)
			wndPetBtn:SetTooltip(tPetInfo.strName)
		else
			self:PrintDebug("Unknown Pet: " .. tPetInfo.strName)
		end
		
		self.NumberOfPets = #self.wndPetFlyoutList:GetChildren()
		
		if self.NumberOfPets > 0 then
			if self.ConfigData.saved.SelectedPet ~= nil then
				if self.ConfigData.saved.SelectedPet.nId == tPetInfo.nId then
					self.nSelectedPet = tPetInfo
				end
			else
				if self.nSelectedPet == nil then
					self.nSelectedPet = tPetInfo
				end
			end
		else
			self.nSelectedPet = nil
		end
		
		if self.nSelectedPet then
			self:RedrawSelectedPet()
		end
	end
	
	if self.NumberOfPets > 0 then
		self:ResizeList()
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ResizeList Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ResizeList()
	if self.NumberOfPets > 0 then
		self:PrintDebug("We have pets")
		
		local nMax = (self.ConfigData.saved.MaxListSize ~= nil and self.ConfigData.saved.MaxListSize or self.ConfigData.default.MaxListSize)
		local nMaxHeight = (self.wndPetFlyoutList:ArrangeChildrenVert(0) / self.NumberOfPets) * nMax
		local nHeight = self.wndPetFlyoutList:ArrangeChildrenVert(0)
		local btnHeight = self.wndPetFlyout:ArrangeChildrenVert(0)
		
		self:PrintDebug("Resizing List...")
		self:PrintDebug("- nMax = " .. tostring(nMax))
		self:PrintDebug("- nMaxHeight = " .. tostring(nMaxHeight))
		self:PrintDebug("- nHeight = " .. tostring(nHeight))
		
		nHeight = nHeight <= nMaxHeight and nHeight or nMaxHeight
		
		local btnLeft, btnTop, btnRight, btnBottom = self.wndPetFlyout:GetAnchorOffsets()
		local nLeft, nTop, nRight, nBottom = self.wndPetFlyoutFrame:GetAnchorOffsets()
		
		self:PrintDebug("- Button Top = " .. tostring(btnTop))
		self:PrintDebug("- Button Bottom  = " .. tostring(btnBottom))
		self:PrintDebug("- nHeight = " .. tostring(nHeight))
		self:PrintDebug("- nTop = " .. tostring(nTop))
		
		if btnTop < 0 then
			if ((btnTop - nHeight - 74) * -1) > self.ConfigData.default.DisplayHeight then
				self.LstAboveBtn = false
			else
				self.LstAboveBtn = true
			end
		else
			if (btnTop + nHeight) > self.ConfigData.default.DisplayHeight then
				self.LstAboveBtn = false
			else
				self.LstAboveBtn = true
			end
		end
		
		if self.LstAboveBtn then
			self:PrintDebug("List Above Button")
			
			nBottom = btnTop + 26
			nTop = nBottom - nHeight - 74
			
			self:PrintDebug("- New nTop = " .. tostring(nTop))
		else
			self:PrintDebug("- List Below Button")

			nTop = btnBottom - 26
			nBottom = nTop + nHeight + 74
			
			self:PrintDebug("- New nTop = " .. tostring(nTop))
			self:PrintDebug("- New nBottom = " .. tostring(nBottom))
		end
		
		self.wndPetFlyoutFrame:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
		self.wndPetFlyoutList:SetVScrollPos(0)
		
		self:ToggleEnabled(true)
	else
		self:PrintDebug("We have no pets")
		
		self:ToggleEnabled(false)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetBtn( wndHandler, wndControl )
	self.nSelectedPet = wndControl:GetData()
	self.ConfigData.saved.SelectedPet = self.nSelectedPet
	self.wndPetFlyoutFrame:Show(false)
	self:UpdatePetList()
	self:RedrawSelectedPet()
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetSummonBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetSummonBtn( wndHandler, wndControl )
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end
	
	if self.wndPetFlyout:FindChild("PetFlyoutBtn"):IsEnabled() then
		self:PrintDebug("Summoning button enabled")
		
		if GameLib.GetPlayerUnit():IsMounted() or GameLib.GetPlayerUnit():IsInVehicle() then
			self:PrintDebug("Player mounted or in vehicle; not summoning pet")
		else
			self:PrintDebug("Player is not mounted and not in vehicle; summoning pet")

			local wndPetSummonBtnFlash = self.wndPetFlyout:FindChild("PetSummonBtnFlash")
			
			wndPetSummonBtnFlash:Show(true)
			GameLib.SummonVanityPet(self.nSelectedPet.nId)
			
			local CastTimer = self.nSelectedPetCastTime + 0.25			
			
			self:PrintDebug("Cast Timer = " .. string.format("%.2f", CastTimer))
			
			Apollo.CreateTimer("SummonFlashTimer", CastTimer, false)
		end
	else
		self:PrintDebug("Summoning button disabled")
	end
end

-----------------------------------------------------------------------------------------------
-- PetOMatic HideBtnFlash Function
-----------------------------------------------------------------------------------------------
function PetOMatic:HideBtnFlash(arg)
	local wndPetSummonBtnFlash = self.wndPetFlyout:FindChild("PetSummonBtnFlash")

	wndPetSummonBtnFlash:Show(false)
end

-----------------------------------------------------------------------------------------------
-- PetOMatic ToggleEnabled Function
-----------------------------------------------------------------------------------------------
function PetOMatic:ToggleEnabled(Enabled)
	if Enabled then
		self.wndPetFlyout:FindChild("PetFlyoutBtn"):Enable(true)
		self.wndPetFlyout:FindChild("PetSummonBtnIcon"):Show(true)
		self.wndPetFlyout:FindChild("PetSummonBtn"):SetText("")
		self.wndPetFlyout:FindChild("PetSummonBtn"):Enable(true)
	else
		self.wndPetFlyout:FindChild("PetFlyoutBtn"):Enable(false)
		self.wndPetFlyout:FindChild("PetSummonBtnIcon"):Show(false)
		self.wndPetFlyout:FindChild("PetSummonBtn"):SetText("No Pets")
		self.wndPetFlyout:FindChild("PetSummonBtn"):Enable(false)
	end
end
---------------------------------------------------------------------------------------------------
-- PetOMatic OnResurrect Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnResurrect(unit)
	self:PrintDebug("Resurrection event triggered")
	
	if self.ConfigData.saved.AutoSummon then
		Apollo.CreateTimer("AutoSummonTimer", 0.5, false)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic AutoSummon Function
---------------------------------------------------------------------------------------------------
function PetOMatic:AutoSummon()
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end
	
	if self.ConfigData.saved.SuspendInRaid then
		if GroupLib.InRaid() then
			return
		end
	end

	self:OnPetSummonBtn(nil,nil)
	self.AutoSummonAttempts = self.AutoSummonAttempts + 1
	
	local arPets = GameLib.GetPlayerPets()
	local bPetSummoned = false
	
	if arPets then
		for idx, unitPet in pairs (arPets) do
			if unitPet:GetName() == self.nSelectedPet.strName then
				bPetSummoned = true
				break
			end
		end
	end
	
	if not bPetSummoned and self.AutoSummonAttempts < 20 then
		Apollo.CreateTimer("AutoSummonTimer", 0.5, false)
	else
		Apollo.StopTimer("AutoSummonTimer")
		self.AutoSummonAttempts = 0
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ShowPetOptions Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ShowPetOptions()
	if self.wndPetOptions == nil or not self.wndPetOptions then
		self.wndPetOptions = Apollo.LoadForm(self.xmlDoc, "PetOptions", nil, self)
		
		self:LoadOptions()
	end
	
	self.wndPetOptions:Show(not self.wndPetOptions:IsShown(), true)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic LoadWindowPosition Function
---------------------------------------------------------------------------------------------------
function PetOMatic:LoadWindowPosition()
	self:PrintDebug("Loading window position")
	
	if self.ConfigData.saved.CustomPosition then
		self:PrintDebug("- Custom Position")
		
		btnOffset = self.ConfigData.saved.btnOffset
		lstOffset = self.ConfigData.saved.lstOffset
	else
		self:PrintDebug("- Default Position")
	
		btnOffset = self.ConfigData.default.btnOffset
		lstOffset = self.ConfigData.default.lstOffset
	end
	
	self:MoveButton(btnOffset, lstOffset)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic LoadOptions Function
---------------------------------------------------------------------------------------------------
function PetOMatic:LoadOptions()
	self:PrintDebug("Loading options...")
	self:PrintDebug("- AutoSummon = " .. tostring(self.ConfigData.saved.AutoSummon ~= nil and self.ConfigData.saved.AutoSummon or self.ConfigData.default.AutoSummon))
	self:PrintDebug("- SuspendInRaid = " .. tostring(self.ConfigData.saved.SuspendInRaid ~= nil and self.ConfigData.saved.SuspendInRaid or self.ConfigData.default.SuspendInRaid))
	self:PrintDebug("- HideAddon = " .. tostring(self.ConfigData.saved.HideAddon ~= nil and self.ConfigData.saved.HideAddon or self.ConfigData.default.HideAddon))
	self:PrintDebug("- MaxListSize = " .. tostring(self.ConfigData.saved.MaxListSize ~= nil and self.ConfigData.saved.MaxListSize or self.ConfigData.saved.MaxListSize))
	
	self:ToggleAutoSummon(self.ConfigData.saved.AutoSummon ~= nil and self.ConfigData.saved.AutoSummon or self.ConfigData.default.AutoSummon)
	self:ToggleSuspendInRaid(self.ConfigData.saved.SuspendInRaid ~= nil and self.ConfigData.saved.SuspendInRaid or self.ConfigData.default.SuspendInRaid)
	self:ToggleHide(self.ConfigData.saved.HideAddon ~= nil and self.ConfigData.saved.HideAddon or self.ConfigData.default.HideAddon)
	self:UpdateSizeSlider(self.ConfigData.saved.MaxListSize ~= nil and self.ConfigData.saved.MaxListSize or self.ConfigData.default.MaxListSize)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsCloseBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsCloseBtn(wndHandler, wndControl)
	self:PrintDebug("Closing option window...")
	self:PrintDebug("oAutoSummon = " .. tostring(self.ConfigData.saved.AutoSummon))
	self:PrintDebug("oHideAddon = " .. tostring(self.ConfigData.saved.HideAddon))
	
	self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):SetCheck(false)
	self:ToggleMoveable(false)
	
	self.wndPetOptions:Close()
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsAutoSummonBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsAutoSummonBtn(wndHandler, wndControl)
	self.ConfigData.saved.AutoSummon = not self.ConfigData.saved.AutoSummon
	self:ToggleAutoSummon(self.ConfigData.saved.AutoSummon)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleAutoSummon Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleAutoSummon(bAutoSummon)	
	if bAutoSummon then
		self:PrintDebug("Enabling automsummon after death")
		
		self.wndPetOptions:FindChild("PetOptionsSuspendInRaidBtn"):Enable(true)
	else
		self:PrintDebug("Disabling automsummon after death")
		self.wndPetOptions:FindChild("PetOptionsSuspendInRaidBtn"):Enable(false)
	end
	
	self.wndPetOptions:FindChild("PetOptionsAutoSummonBtn"):SetCheck(bAutoSummon)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsNoSuspendInRaidBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsSuspendInRaidBtn(wndHandler, wndControl)
	self.ConfigData.saved.SuspendInRaid = (not self.ConfigData.saved.SuspendInRaid)
	self:ToggleSuspendInRaid(self.ConfigData.saved.SuspendInRaid)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleSuspendInRaid Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleSuspendInRaid(bSuspendInRaid)
	if self.ConfigData.saved.SuspendInRaid then
		self:PrintDebug("Disabling Auto Summon In Raid")
	else
		self:PrintDebug("Enabling AutoSummon In Raid")
	end
	
	self.wndPetOptions:FindChild("PetOptionsSuspendInRaidBtn"):SetCheck(bSuspendInRaid)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsMoveAddonBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsMoveAddonBtn(wndHandler, wndControl)
	if wndControl:IsChecked() then
		self:PrintDebug("Move button checked")
		
		self:ToggleMoveable(true)
	else
		self:PrintDebug("Move button unchecked")
		
		self:ToggleMoveable(false)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleMoveable Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleMoveable(Moveable)
	if Moveable then
		self:PrintDebug("Making button moveable")
		self.wndPetFlyout:FindChild("PetFlyoutBtn"):Enable(false)
	else
		self:PrintDebug("Making button unmoveable")
		self.wndPetFlyout:FindChild("PetFlyoutBtn"):Enable(true)

		-- Determine Button Offsets and save values
		local PetBtnOffsets = {self.wndPetFlyout:GetAnchorOffsets()}
		
		self:PrintDebug("Button offsets: " .. tostring(PetBtnOffsets[1]) .. "," .. tostring(PetBtnOffsets[2]) .. "," .. tostring(PetBtnOffsets[3]) .. "," .. tostring(PetBtnOffsets[4]))
		
		-- Determine if button moved
		local NewPosition = false
		
		if self.ConfigData.saved.CustomPosition then
			if PetBtnOffsets ~= self.ConfigData.saved.btnOffset then
				self:PrintDebug("Button moved")
				
				NewPosition = true
		
				-- Save new position
				self.ConfigData.saved.btnOffset = PetBtnOffsets
			else
				self:PrintDebug("Button not moved")
			end
		else
			if PetBtnOffsets ~= self.ConfigData.default.btnOffset then
				self.ConfigData.saved.CustomPosition = true
				
				self:PrintDebug("Button moved")
				
				NewPosition = true
		
				-- Save new position
				self.ConfigData.saved.btnOffset = PetBtnOffsets
			else
				self.ConfigData.saved.CustomPosition = false

				self:PrintDebug("Button not moved")
			end
		end
		
		-- Move FlyoutFrame if needed
		if NewPosition then
			-- Calculate FlyoutFrame Offsets
			local fLeft = PetBtnOffsets[1] - self.ConfigData.default.wndListOffsetL
			local fTop = PetBtnOffsets[2] - self.ConfigData.default.wndListOffsetT
			local fRight = PetBtnOffsets[3] + self.ConfigData.default.wndListOffsetR
			local fBottom = PetBtnOffsets[4] - self.ConfigData.default.wndListOffsetB
			
			-- Save new offsets
			self.ConfigData.saved.lstOffset = {fLeft, fTop, fRight, fBottom}
			
			-- Move FlyoutFrame
			self:MoveFlyoutFrame(self.ConfigData.saved.lstOffset)
		end			
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsRestoreDefaultPositionBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsRestoreDefaultPositionBtn(wndHandler, wndControl)
	self:PrintDebug("Restoring default button position")
	
	self.ConfigData.saved.CustomPosition = false
	self.ConfigData.saved.btnOffset = {}
	self.ConfigData.saved.lstOffset = {}
	
	self:MoveButton(self.ConfigData.default.btnOffset, self.ConfigData.default.lstOffset)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic MoveButton Function
---------------------------------------------------------------------------------------------------
function PetOMatic:MoveButton(btnOffset, lstOffset)
	self:PrintDebug("Moving button")
	self:PrintDebug("Button Offsets: " .. tostring(btnOffset[1]) .. "," .. tostring(btnOffset[2]) .. "," .. tostring(btnOffset[3]) .. "," .. tostring(btnOffset[4]))

	self.wndPetFlyout:SetAnchorOffsets(btnOffset[1], btnOffset[2], btnOffset[3], btnOffset[4])
	
	self:MoveFlyoutFrame(lstOffset)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic MoveFlyoutFrame Function
---------------------------------------------------------------------------------------------------
function PetOMatic:MoveFlyoutFrame(lstOffset)
	self:PrintDebug("Moving list")
	self:PrintDebug("List Offsets: " .. tostring(lstOffset[1]) .. "," .. tostring(lstOffset[2]) .. "," .. tostring(lstOffset[3]) .. "," .. tostring(lstOffset[4]))
	
	self.wndPetFlyoutFrame:SetAnchorOffsets(lstOffset[1], lstOffset[2], lstOffset[3], lstOffset[4])
	
	self:ResizeList()
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsHideAddonBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsHideAddonBtn(wndHandler, wndControl)
	self.ConfigData.saved.HideAddon = not self.ConfigData.saved.HideAddon
	self:ToggleHide(self.ConfigData.saved.HideAddon)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleHide Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleHide(bHideAddon)
	if bHideAddon then
		self:PrintDebug("Hiding button")
	else
		self:PrintDebug("Unhiding button")
	end
	
	self.wndPetOptions:FindChild("PetOptionsHideAddonBtn"):SetCheck(bHideAddon)
	
	self.wndPetFlyout:Show(not bHideAddon )
	
	if bHideAddon  then
		self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):Enable(false)
		self.wndPetOptions:FindChild("PetOptionsRestoreDefaultPositionBtn"):Enable(false)
	else
		self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):Enable(true)
		self.wndPetOptions:FindChild("PetOptionsRestoreDefaultPositionBtn"):Enable(true)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsMaxListSizeChanged Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsMaxListSizeChanged(wmdHandler, wndControl, fNewValue, fOldValue)
	self.ConfigData.saved.MaxListSize = fNewValue
	self.wndPetOptions:FindChild("MaxPetListSizeText"):SetText(fNewValue)
	
	self:PrintDebug("New Max List Size: " .. tostring(self.ConfigData.saved.MaxListSize))
	
	self:ResizeList()
end

---------------------------------------------------------------------------------------------------
-- PetOMatic UpdateSizeSlider Function
---------------------------------------------------------------------------------------------------
function PetOMatic:UpdateSizeSlider(bMaxListSize)
	self:PrintDebug("Setting Max List Size option to: " .. tostring(bMaxListSize))	
	
	self.wndPetOptions:FindChild("MaxPetListSizeText"):SetText(bMaxListSize)
	self.wndPetOptions:FindChild("MaxPetListSizeSlider"):Enable(false)
	self.wndPetOptions:FindChild("MaxPetListSizeSlider"):SetValue(bMaxListSize)
	self.wndPetOptions:FindChild("MaxPetListSizeSlider"):Enable(true)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnSave Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnSave(eLevel)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
		return self.ConfigData.saved
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnRestore Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnRestore(eLevel, tData)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
		self.ConfigData.saved = setmetatable(tData, {__index = config.user})
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic SlashCommandHandler Function
---------------------------------------------------------------------------------------------------
function PetOMatic:SlashCommandHandler(cmd, arg)
	local CmdFound = false
	
	for cmd, attribs in pairs(SlashCommands) do
		if arg == cmd then
			CmdFound = true
			
			self:PrintDebug(string.format("%s : %s (%s)", cmd, attribs.hndlr, attribs.func))
			
			Event_FireGenericEvent(attribs.hndlr)
		end
	end
	
	if not CmdFound then
		self:PrintCommands()
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic PrintCommands Function
---------------------------------------------------------------------------------------------------
function PetOMatic:PrintCommands()
	Print("PetOMatic Available commands:")
	
	for cmd, attribs in pairs(SlashCommands) do
		local PrintCmd = true
		
		if cmd == "debug" then
			if GameLib.GetPlayerUnit():GetName() ~= self.ConfigData.default.Creator then
				PrintCmd = false
			end
		end
		
		if PrintCmd then
			Print(string.format("- %s : %s", cmd, attribs.desc))
		end
	end
end

-----------------------------------------------------------------------------------------------
-- PetOMatic Instance
-----------------------------------------------------------------------------------------------
local PetOMaticInst = PetOMatic:new()
PetOMaticInst:Init()
