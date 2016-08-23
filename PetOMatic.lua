-----------------------------------------------------------------------------------------------
-- Client Lua Script for PetOMatic
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- PetOMatic Module Definition
-----------------------------------------------------------------------------------------------
local PetOMatic = {} 

local kstrContainerEventName_POM = "PetOMatic"
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
kCreator_POM = "Zaresir Tinktaker"
kVersion_POM = "2.2.0-release"
kResetOptions_POM = false

kOptionBtn_POM = "IconSprites:Icon_Windows32_UI_CRB_InterfaceMenu_NonCombatAbility"

kAPIBridge_POM = nil

kListSizeMin_POM = 1
kListSizeMax_POM = 7

local config_POM = {}

config_POM.defaults = {}
config_POM.user = {}

config_POM.defaults.DisplayHeight = Apollo.GetDisplaySize().nHeight
config_POM.defaults.btnAnchor = {1, 1, 1, 1}
config_POM.defaults.btnOffset = {-88, -113, -10, -32}
config_POM.defaults.lstAnchor = {1, 1, 1, 1}
config_POM.defaults.lstOffset = {-122, -407, 12, -87}
config_POM.defaults.wndListOffsets = {26, 294, 16, 55}
config_POM.defaults.SelectedPet = nil
config_POM.defaults.AutoSummon = false
config_POM.defaults.SuspendInRaid = false
config_POM.defaults.HideAddon = false
config_POM.defaults.HideInCombat = false
config_POM.defaults.MaxListSize = 7

config_POM.user.Debug = false
config_POM.user.CustomPosition = false
config_POM.user.bntAnchor = nil
config_POM.user.btnOffset = nil
config_POM.user.lstAnchor = nil
config_POM.user.lstOffset = nil
config_POM.user.SelectedPet = nil
config_POM.user.AutoSummon = false
config_POM.user.SuspendInRaid = false
config_POM.user.HideAddon = false
config_POM.user.HideInCombat = false
config_POM.user.MaxListSize = nil
config_POM.user.Version = nil

SlashCommands_POM = {
	debug = {disp = nil, desc = "Toggle DEBUG mode", hndlr = "E_PetOMaticDebug", func = "ToggleDebug", show = false},
	config = {disp = nil, desc = "Open PetOMatic Options window", hndlr = "E_PetOMaticOptions", func = "ShowPetOptions", show = true},
	auto = {disp = nil, desc = "Toggle autosummon after death", hndlr = "E_PetOMaticAutoSummon", func = "OnPetOptionsAutoSummonBtn", show = true},
	hide = {disp = nil, desc = "Hide/show button", hndlr = "E_PetOMaticHide", func = "OnPetOptionsHideAddonBtn", show = true},
	chide = {disp = nil, desc = "Hide button in combat", hndlr = "E_PetOMaticHideInCombat", func = "OnPetOptionsHideInCombatBtn", show = true},
	move = {disp = nil, desc = "Enable/disable button movement", hndlr = "E_PetOMaticMove", func = "OnPetOptionsMoveAddonBtn", show = true},
	restore = {disp = nil, desc = "Restore default button position", hndlr = "E_PetOMaticRestor", func = "OnPetOptionsRestoreDefaultPositionBtn", show = true},
	raid = {disp = nil, desc = "Enable/disable autosummoning in Raids", hndlr = "E_PetOMAticRaid", func = "OnPetOptionsSuspendInRaidBtn", show = true},
	max = {disp = string.format("max [%d-%d]", kListSizeMin_POM, kListSizeMax_POM), desc = "Set the pet list size to specified value.", hndlr = "E_PetOMaticMax", func = "OnPetOptionsMaxListSizeChanged", show = true},
	reset = {disp = nil, desc = "Clears all saved addon data and settings", hndlr = "E_PetOMaticReset", func = "ClearSavedData", show = true},
	center = {disp = nil, desc = "Move button to center of screen", hndlr = "E_PetOMaticCenter", func = "OnPetOptionsCenterBtn", show = true},
	random = {disp = nil, desc = "Select and summon random pet", hndlr = "E_PetOMaticRandom", func = "OnPetRandomBtn", show = true},
	chompy = {disp = nil, desc = "Select and summon random Chompacabra pet", hndlr = "E_PetOMaticChompy", func = "RandomChompy", show = false}
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
	self.ConfigData.default = setmetatable({}, {__index = config_POM.defaults})
	self.ConfigData.saved = setmetatable({}, {__index = config_POM.user})
	
	self.ResetSavedData = false

	self.nSelectedPet = nil
	self.nSelectedPetCastTime = 0.0
	
	self.NumberOfPets = 0
	self.KnownPets = {}
	self.PetsChompy = {}
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
	self:PrintDebug("Init Success")
end

-----------------------------------------------------------------------------------------------
-- PetOMatic OnLoad Function
-----------------------------------------------------------------------------------------------
function PetOMatic:OnLoad()
	Apollo.LoadSprites("Sprites/PetOMatic.xml")
	
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("PetOMatic.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	if Apollo.GetAPIVersion() == 10 then
		kAPIBridge_POM = GameLib
	else
		kAPIBridge_POM = CollectiblesLib
	end
		
	self:RegisterObjects()
end

-----------------------------------------------------------------------------------------------
-- PetOMatic OnDocLoaded Function
-----------------------------------------------------------------------------------------------
function PetOMatic:OnDocLoaded()
	self:PrintMsg(string.format("Version %s loaded", tostring(kVersion_POM)), true)
	
	self.wndPetFlyout = Apollo.LoadForm(self.xmlDoc, "PetFlyout", "FixedHudStratumLow", self)
	self.wndPetFlyoutFrame  = Apollo.LoadForm(self.xmlDoc, "PetFlyoutFrame", nil, self)
	self.wndPetFlyoutList = self.wndPetFlyoutFrame:FindChild("PetFlyoutList")
	
	self.wndPetFlyout:FindChild("PetFlyoutBtn"):SetCheck(false)
	self.wndPetFlyout:FindChild("PetFlyoutBtn"):AttachWindow(self.wndPetFlyoutFrame)
		
	self:PrintDebug(string.format("API: %d", Apollo.GetAPIVersion()))
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
	Apollo.RegisterEventHandler("Mount", "OnDismount", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnCombatToggleHide", self)
	
	-- Register Slash Command Events
	self:RegisterSlashCommandEvents()
	
	-- Register Timers
	Apollo.RegisterTimerHandler("AutoSummonTimer", "AutoSummon", self)
	Apollo.RegisterTimerHandler("SummonDelayTimer", "PostSummonActions", self)
	Apollo.RegisterTimerHandler("DismountDelayTimer", "DismountActions", self)

	-- Register Slash Commands
	Apollo.RegisterSlashCommand("pom", "SlashCommandHandler", self)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic RegisterSlashCommandEvents Function
---------------------------------------------------------------------------------------------------
function PetOMatic:RegisterSlashCommandEvents()
	for cmd, attribs in pairs(SlashCommands_POM) do
		self:PrintDebug(string.format("Registering event handler: %s, %s", attribs.hndlr, attribs.func))
		
		Apollo.RegisterEventHandler(attribs.hndlr, attribs.func, self)
	end		
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnInterfaceMenuListHasLoaded Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnInterfaceMenuListLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", kstrContainerEventName_POM, {"PetOptionsMenuClicked", "", kOptionBtn_POM})
	Apollo.RegisterEventHandler("PetOptionsMenuClicked", "ShowPetOptions", self)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleDebug Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleDebug()
	self.ConfigData.saved.Debug = not self.ConfigData.saved.Debug
	
	if self.ConfigData.saved.Debug then
		self:PrintMsg("DEBUG MODE ENABLED", true)
	else
		self:PrintMsg("DEBUG MODE DISABLED", true)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic PrintDebug Function
---------------------------------------------------------------------------------------------------
function PetOMatic:PrintDebug(msg)
	msg = string.format("%s: %s", kstrContainerEventName_POM, msg)
	if self.ConfigData.saved.Debug then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, msg)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic PrintMsg Function
---------------------------------------------------------------------------------------------------
function PetOMatic:PrintMsg(msg, header)
	if header then
		msg = string.format("%s: %s", kstrContainerEventName_POM, msg)
	end
	
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, msg)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic UpdatePetList Function
---------------------------------------------------------------------------------------------------
function PetOMatic:UpdatePetList()
	if not self.wndPetFlyoutList then
		return
	end
	
	self:PrintDebug("Updating Pet List")
	
	self.KnownPets = {}
	
	local arPetList = kAPIBridge_POM.GetVanityPetList()
	
	local firstKnownPet = nil
	local kPetIdx = 1
	local kChompyIdx = 1
	
	if #self.wndPetFlyoutList:GetChildren() > 0 then
		self.wndPetFlyoutList:DestroyChildren()
	end

	table.sort(arPetList, function(a,b) return (a.bIsKnown and not b.bIsKnown) or (a.bIsKnown == b.bIsKnown and a.strName < b.strName) end)

	for idx = 1, #arPetList do
		local tPetInfo = arPetList[idx]
		local wndPetBtn = nil

		if tPetInfo.bIsKnown then
			self:PrintDebug("Known Pet: " .. tPetInfo.strName)
			
			self.KnownPets[kPetIdx] = tPetInfo
			kPetIdx = kPetIdx + 1
			
			if string.match(tPetInfo.strName, 'Chompacabra') ~= nil then
				self.PetsChompy[kChompyIdx] = tPetInfo
				kChompyIdx = kChompyIdx + 1
			end
			
			if idx == 1 then
				firstKnownPet = tPetInfo
			end
			
			wndPetBtn = Apollo.LoadForm(self.xmlDoc, "PetBtn", self.wndPetFlyoutList, self)
			local wndPetBtnIcon = wndPetBtn:FindChild("PetBtnIcon")
			
			wndPetBtnIcon:SetSprite(tPetInfo.splObject and tPetInfo.splObject:GetIcon() or "Icon_ItemArmorWaist_Unidentified_Buckle_0001")
			
			self:GenerateTooltip(wndPetBtn, tPetInfo)
			
			if self.ConfigData.saved.SelectedPet ~= nil then
				if self.ConfigData.saved.SelectedPet.nId == tPetInfo.nId then
					self.nSelectedPet = tPetInfo
				end
			end
		else
			self:PrintDebug("Unknown Pet: " .. tPetInfo.strName)
		end
	end
		
	self.NumberOfPets = #self.wndPetFlyoutList:GetChildren()
		
	if self.NumberOfPets > 0 then
		if self.nSelectedPet == nil or self.ResetSavedData then
			self:PrintDebug("No saved selected pet/Or resetting saved data. Defaulting to first known pet.")
			
			self.nSelectedPet = firstKnownPet
		end
	else
		self.nSelectedPet = nil
	end
		
	if self.nSelectedPet ~= nil then
		self:PrintDebug(string.format("Selected Pet = %s", self.nSelectedPet.strName))
		
		self.nSelectedPetCastTime = self.nSelectedPet.splObject:GetCastTime()
		self:RedrawSelectedPet(self.nSelectedPet)
	else
		self:PrintDebug("No pet selected")
	end
	
	if self.NumberOfPets > 0 then
		self:PrintDebug("We have pets")
		
		self:ResizeList()
		self:ToggleEnabled(true)
	else
		self:PrintDebug("We have no pets")
		
		self:ToggleEnabled(false)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ResizeList Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ResizeList()
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
end

---------------------------------------------------------------------------------------------------
-- PetOMatic RedrawSelectedPet Function
---------------------------------------------------------------------------------------------------
function PetOMatic:RedrawSelectedPet(tPetInfo)
	local wndSummonBtn = self.wndPetFlyout:FindChild("PetSummonBtnIcon")
	
	self:PrintDebug("Selected Pet = " .. tPetInfo.strName)
	self:PrintDebug("Cast Time = " .. tostring(self.nSelectedPetCastTime))
	
	wndSummonBtn:SetSprite(tPetInfo.splObject and tPetInfo.splObject:GetIcon() or "Icon_ItemArmorWaist_Unidentified_Buckle_0001")	
	
	self:GenerateTooltip(wndSummonBtn, tPetInfo)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnDismount Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnDismount()
	if self:IsMounted() then
		self:PrintDebug("Mounted")
		
		return
	end
	
	self:PrintDebug("Dismounted")

	Apollo.CreateTimer("DismountDelayTimer", 2.0, false)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic DismountActions Function
---------------------------------------------------------------------------------------------------
function PetOMatic:DismountActions()
	if self:IsSummoned() then
		self:PrintDebug("Selected pet currently summoned.")
	else
		self:PrintDebug("Selected pet not currently summoned.")
		
		if self:IsActiveVanityPet() then
			self:PrintDebug("Active Pet - Summoning pet")
			self:CastSummon()
		else
			self:PrintDebug("No active Pet - Not summoning pet")
		end
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetBtn( wndHandler, wndControl )
	self.ConfigData.saved.SelectedPet = wndControl:GetData()
	self.wndPetFlyoutFrame:Show(false)
	self:UpdatePetList()
	
	if not self:IsMounted() then
		if self:IsSummoned() then
			self:PrintDebug("IsSummoned = True")
		else
			self:PrintDebug("IsSummoned = False")
			self:PrintDebug("SummonState = " .. tostring(self:IsActiveVanityPet()))
			
			if self.nSelectedPet ~= nil then 
				if self:IsActiveVanityPet() then
					self:PrintDebug("IsSummoned = False")
			
					self:CastSummon()
				end
			end
		end
	end
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
		
		if self:IsMounted() then
			self:PrintDebug("Player mounted or in vehicle; not summoning pet")
		else
			self:PrintDebug("Player is not mounted and not in vehicle; summoning pet")

			self:CastSummon()
		end
	else
		self:PrintDebug("Summoning button disabled")
	end
end

-----------------------------------------------------------------------------------------------
-- PetOMatic GenerateTooltip Function
-----------------------------------------------------------------------------------------------
function PetOMatic:GenerateTooltip(wndCurrBtn, tPetInfo)
	wndCurrBtn:SetData(tPetInfo)
	
	if Tooltip and Tooltip.GetSpellTooltipForm then
		wndCurrBtn:SetTooltipDoc(nil)
		Tooltip.GetSpellTooltipForm(self, wndCurrBtn, tPetInfo.splObject, {})
	end
end

-----------------------------------------------------------------------------------------------
-- PetOMatic HideBtnFlash Function
-----------------------------------------------------------------------------------------------
function PetOMatic:PostSummonActions(arg)
	local wndPetSummonBtnFlash = self.wndPetFlyout:FindChild("PetSummonBtnFlash")

	wndPetSummonBtnFlash:Show(false)
	
	self:PrintDebug("SummonState = " .. tostring(self:IsActiveVanityPet()))
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
		self.wndPetFlyout:FindChild("PetFlyoutRandomBtn"):Enable(true)
	else
		self.wndPetFlyout:FindChild("PetFlyoutBtn"):Enable(false)
		self.wndPetFlyout:FindChild("PetSummonBtnIcon"):Show(false)
		self.wndPetFlyout:FindChild("PetSummonBtn"):SetText("No Pets")
		self.wndPetFlyout:FindChild("PetSummonBtn"):Enable(false)
		self.wndPetFlyout:FindChild("PetFlyoutRandomBtn"):Enable(false)
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

	self:CastSummon()
	self.AutoSummonAttempts = self.AutoSummonAttempts + 1
	
	if not self:IsSummoned() and self.AutoSummonAttempts < 20 then
		Apollo.CreateTimer("AutoSummonTimer", 0.5, false)
	else
		Apollo.StopTimer("AutoSummonTimer")
		self.AutoSummonAttempts = 0
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetBtnRandom Function
---------------------------------------------------------------------------------------------------

function PetOMatic:OnPetRandomBtn( wndHandler, wndControl )
	if wndControl then
		self:PlayOptionsSound(wndControl, "Push")
	end
	
	self:PrintDebug(string.format("Number of available Pets: %d", #self.KnownPets))
	
	if #self.KnownPets > 0 then
		self:SummonRandomPet(self.KnownPets)
	else
		self:PrintMsg("You have no unlocked Chompacabra pets")
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic RandomChompy Function
---------------------------------------------------------------------------------------------------
function PetOMatic:RandomChompy()
	self:PrintDebug(string.format("Number of available Chompy Pets: %d", #self.PetsChompy))
	
	if #self.PetsChompy > 0 then
		self:SummonRandomPet(self.PetsChompy)
	else
		self:PrintMsg("You have no unlocked Chompacabra pets")
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetChompyRandom Function
---------------------------------------------------------------------------------------------------
function PetOMatic:SummonRandomPet(PetList)
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end
	
	local rPetIdx = math.random(#PetList)
	
	self:PrintDebug(string.format("Random Pet Index: %d", rPetIdx))
	self:PrintDebug(string.format("Random Pet: %s", PetList[rPetIdx].strName))
	
	self.nSelectedPet = PetList[rPetIdx]
	self.ConfigData.saved.SelectedPet = self.nSelectedPet
	self.nSelectedPetCastTime = self.nSelectedPet.splObject:GetCastTime()
	self:RedrawSelectedPet(self.nSelectedPet)
	
	local arPets = GameLib.GetPlayerPets()
	
	if not self:IsSummoned() then
		if not self:IsMounted() then
			self:CastSummon()
		end 
	else
		if arPets then
			for idx, unitPet in pairs(arPets) do
				if unitPet:GetName() ~= self.nSelectedPet.strName then
					if not self:IsMounted() then
						self:CastSummon()
					end
				else
					if #PetList > 1 then	
						self:SummonRandomPet(PetList)
					else
						self:PrintMsg('You only have one summonable pet')
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic IsActiveVanityPetFunction
---------------------------------------------------------------------------------------------------
function PetOMatic:IsActiveVanityPet()
	local arPets = GameLib.GetPlayerPets()
	local arPetList = kAPIBridge_POM.GetVanityPetList()
	
	self:PrintDebug("Player pets: " .. tostring(#arPets))
	self:PrintDebug("Pet List: " .. tostring(#arPetList))
	
	if arPets then
		for idx, unitPet in pairs(arPets) do
			for idx = 1, #arPetList do
				local tPetInfo = arPetList[idx]
				
				self:PrintDebug(string.format("Player Pet: %s - List Pet: %s", unitPet:GetName(), tPetInfo.strName))
				
				if tPetInfo.strName == unitPet:GetName() then
					self:PrintDebug("Active pet found")
					
					return true
				end
			end	
		end
	end
	
	self:PrintDebug("No active pet found")
	
	return false
end

---------------------------------------------------------------------------------------------------
-- PetOMatic IsSummoned Function
---------------------------------------------------------------------------------------------------
function PetOMatic:IsSummoned()
	local SelectedPet = (self.ConfigData.saved.SelectedPet ~= nil and self.ConfigData.saved.SelectedPet or self.ConfigData.default.SelectedPet)
	
	if SelectedPet ~= nil then
		local arPets = GameLib.GetPlayerPets()
		
		if arPets then
			for idx, unitPet in pairs(arPets) do
				self:PrintDebug(string.format("Summoned = %s; Selected = %s", tostring(unitPet:GetName()), tostring(SelectedPet.strName)))
							
				if unitPet:GetName() == SelectedPet.strName then
					self:PrintDebug("IsSummoned = True")
					
					return true
				end
			end
		end
	end
	
	self:PrintDebug("IsSummoned = False")

	return false
end

---------------------------------------------------------------------------------------------------
-- PetOMatic IsMounted Function
---------------------------------------------------------------------------------------------------
function PetOMatic:IsMounted()
	local bMounted = GameLib.GetPlayerUnit():IsMounted()
	local bVehicle = GameLib.GetPlayerUnit():IsInVehicle()
	local bTaxi = GameLib.GetPlayerTaxiUnit() and true or false
	
	if bMounted or bVehicle or bTaxi then
		self:PrintDebug("IsMounted = True")
		return true
	else
		self:PrintDebug("IsMounted = False")
		return false
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic CastSummon Function
---------------------------------------------------------------------------------------------------
function PetOMatic:CastSummon()
	local wndPetSummonBtnFlash = self.wndPetFlyout:FindChild("PetSummonBtnFlash")
			
	wndPetSummonBtnFlash:Show(true)
	GameLib.SummonVanityPet(self.nSelectedPet.nId)

	local CastTimer = self.nSelectedPetCastTime + 0.25			
			
	self:PrintDebug("Cast Timer = " .. string.format("%.2f", CastTimer))
			
	Apollo.CreateTimer("SummonDelayTimer", CastTimer, false)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ShowPetOptions Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ShowPetOptions()
	self:PlayOptionsSound(self.wndPetOptions, "Window")
	
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
		
		btnAnchor = (self.ConfigData.saved.btnAnchor ~= nil and self.ConfigData.saved.btnAnchor or self.ConfigData.default.btnAnchor)
		btnOffset = (self.ConfigData.saved.btnOffset ~= nil and self.ConfigData.saved.btnOffset or self.ConfigData.default.btnOffset)
		lstAnchor = (self.ConfigData.saved.lstAnchor ~= nil and self.ConfigData.saved.btnAnchor or self.ConfigData.default.lstAnchor)
		lstOffset = (self.ConfigData.saved.lstOffset ~= nil and self.ConfigData.saved.lstOffset or self.ConfigData.default.lstOffset)
	else
		self:PrintDebug("- Default Position")
	
		btnAnchor = self.ConfigData.default.btnAnchor
		btnOffset = self.ConfigData.default.btnOffset
		lstAnchor = self.ConfigData.default.lstAnchor
		lstOffset = self.ConfigData.default.lstOffset
	end
	
	self:PrintDebug(string.format("Button Anchors LWP: %d, %d, %d, %d", btnAnchor[1], btnAnchor[2], btnAnchor[3], btnAnchor[4]))
	self:PrintDebug(string.format("Button Offsets LWP: %d, %d, %d, %d", btnOffset[1], btnOffset[2], btnOffset[3], btnOffset[4]))
	self:PrintDebug(string.format("List Anchors LWP: %d, %d, %d, %d", lstAnchor[1], lstAnchor[2], lstAnchor[3], lstAnchor[4]))
	self:PrintDebug(string.format("List Offsets LWP: %d, %d, %d, %d", lstOffset[1], lstOffset[2], lstOffset[3], lstOffset[4]))
	
	self:MoveButton(btnAnchor, btnOffset, lstAnchor, lstOffset)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic LoadOptions Function
---------------------------------------------------------------------------------------------------
function PetOMatic:LoadOptions()
	self:PrintDebug("kVersion_POM = " .. tostring(kVersion_POM))
	self:PrintDebug("User Version = " .. tostring(self.ConfigData.saved.version))
	self:PrintDebug("kResetOptions_POM = " .. tostring(kResetOptions_POM))
	
	if self.ConfigData.saved.Version ~= kVersion_POM and kResetOptions_POM then
		self:PrintDebug("Resetting Options...")
		
		self:PrintMsg("New version requires options reset. Clearing all saved data...", true)
		
		self.ConfigData.saved.Version = kVersion_POM
		
		self.ClearSavedData()
	else
		self:PrintDebug("Loading options...")
	end
	
	self.ConfigData.saved.Version = kVersion_POM
	
	self:PrintDebug("- AutoSummon = " .. tostring(self.ConfigData.saved.AutoSummon ~= nil and self.ConfigData.saved.AutoSummon or self.ConfigData.default.AutoSummon))
	self:PrintDebug("- SuspendInRaid = " .. tostring(self.ConfigData.saved.SuspendInRaid ~= nil and self.ConfigData.saved.SuspendInRaid or self.ConfigData.default.SuspendInRaid))
	self:PrintDebug("- HideAddon = " .. tostring(self.ConfigData.saved.HideAddon ~= nil and self.ConfigData.saved.HideAddon or self.ConfigData.default.HideAddon))
	self:PrintDebug("- HideInCombat = " .. tostring(self.ConfigData.saved.HideInCombat ~= nil and self.ConfigData.saved.HideInCombat or self.ConfigData.default.HideInCombat))
	self:PrintDebug("- MaxListSize = " .. tostring(self.ConfigData.saved.MaxListSize ~= nil and self.ConfigData.saved.MaxListSize or self.ConfigData.default.MaxListSize))
	
	local options = self.wndPetOptions:FindChild("MaxPetListSize")
	local tAutoSummon = (self.ConfigData.saved.AutoSummon ~= nil and self.ConfigData.saved.AutoSummon or self.ConfigData.default.AutoSummon)
	local tSuspendInRaid = (self.ConfigData.saved.SuspendInRaid ~= nil and self.ConfigData.saved.SuspendInRaid or self.ConfigData.default.SuspendInRaid)
	local tHide = (self.ConfigData.saved.HideAddon ~= nil and self.ConfigData.saved.HideAddon or self.ConfigData.default.HideAddon)
	local vMaxListSize = (self.ConfigData.saved.MaxListSize ~= nil and self.ConfigData.saved.MaxListSize or self.ConfigData.default.MaxListSize)
	local ListSizeSlider = options:FindChild("MaxPetListSize")
	local tHideInCombat = (self.ConfigData.saved.HideInCombat ~= nil and self.ConfigData.saved.HideInCombat or self.ConfigData.default.HideInCombat )
	
	self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):SetCheck(False)
	self:ToggleMoveable(false, true)
	self:ToggleAutoSummon(tAutoSummon, true)
	self:ToggleSuspendInRaid(tSuspendInRaid, true)
	self:ToggleHide(tHide, true)
	self:ToggleHideInCombat(tHideInCombat, true)
	self:InitSlider(ListSizeSlider, kListSizeMin_POM, kListSizeMax_POM, 1, vMaxListSize , 0, function (value) vMaxListSize = value end)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsCloseBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsCloseBtn(wndHandler, wndControl)
	self:PlayOptionsSound(wndControl, "Push")
	
	self:PrintDebug("Closing option window...")
	self:PrintDebug("oAutoSummon = " .. tostring(self.ConfigData.saved.AutoSummon))
	self:PrintDebug("oHideAddon = " .. tostring(self.ConfigData.saved.HideAddon))
	
	if self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):IsChecked() then
		self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):SetCheck(false)
		self:ToggleMoveable(false)
	end
	
	self.wndPetOptions:Close()
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsAutoSummonBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsAutoSummonBtn(wndHandler, wndControl)
	local suppressOutput = false
	
	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
		
		suppressOutput = true
	end

	self.ConfigData.saved.AutoSummon = not self.ConfigData.saved.AutoSummon
	self:ToggleAutoSummon(self.ConfigData.saved.AutoSummon, suppressOutput)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleAutoSummon Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleAutoSummon(bAutoSummon, SuppressOutput)	
	if bAutoSummon then
		self:PrintDebug("Enabling automsummon after death")
		
		self.wndPetOptions:FindChild("PetOptionsSuspendInRaidBtn"):Enable(true)
		
		if not SuppressOutput then
			self:PrintMsg("Autosummon after death enabled", true)
		end
	else
		self:PrintDebug("Disabling automsummon after death")
		self.wndPetOptions:FindChild("PetOptionsSuspendInRaidBtn"):Enable(false)
		
		if not SuppressOutput then
			self:PrintMsg("Autosummon after death disabled", true)
		end
	end
	
	self.wndPetOptions:FindChild("PetOptionsAutoSummonBtn"):SetCheck(bAutoSummon)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsSuspendInRaidBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsSuspendInRaidBtn(wndHandler, wndControl)
	local suppressOutput = false

	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
		
		suppressOutput = true
	end
	
	self.ConfigData.saved.SuspendInRaid = (not self.ConfigData.saved.SuspendInRaid)
	self:ToggleSuspendInRaid(self.ConfigData.saved.SuspendInRaid, suppressOutput)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleSuspendInRaid Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleSuspendInRaid(bSuspendInRaid, SuppressOutput)
	if self.ConfigData.saved.SuspendInRaid then		
		self:PrintDebug("Disabling Auto Summon In Raid")
		
		if not SuppressOutput then
			self:PrintMsg("Autosummon in Raid disabled", true)
		end
	else
		self:PrintDebug("Enabling AutoSummon In Raid")
		
		if not SuppressOutput then
			self:PrintMsg("Autosummon in Raid enabled", true)
		end
	end
	
	self.wndPetOptions:FindChild("PetOptionsSuspendInRaidBtn"):SetCheck(bSuspendInRaid)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsMoveAddonBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsMoveAddonBtn(wndHandler, wndControl)
	local suppressOutput = false

	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
		
		suppressOutput = true
		
		local bChecked = false

		if wndControl:IsChecked() then
			self:PrintDebug("Move button checked")
		
			bChecked = true
		else
			self:PrintDebug("Move button unchecked")	
		end
		
		self:ToggleMoveable(bChecked, suppressOutput)
	else
		self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):SetCheck(not self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):IsChecked())
		self:ToggleMoveable(self.wndPetFlyout:FindChild("PetFlyoutBtn"):IsEnabled())
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleMoveable Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleMoveable(Moveable, SuppressOutput)
	self:PrintDebug("Moveable = " .. tostring(Moveable))
	
	if Moveable then
		self:PrintDebug("Making button moveable")
		self.wndPetFlyout:FindChild("PetFlyoutBtn"):Enable(false)
		
		if not SuppressOutput then
			self:PrintMsg("Button is moveable", true)
		end
	else
		self:PrintDebug("Making button unmoveable")
		self.wndPetFlyout:FindChild("PetFlyoutBtn"):Enable(true)
		
		if not SuppressOutput then
			self:PrintMsg("Button position is locked", true)
		end

		-- Determine Button Anchor Points and Offsets and save values
		local PetBtnAnchors = {self.wndPetFlyout:GetAnchorPoints()}
		local PetBtnOffsets = {self.wndPetFlyout:GetAnchorOffsets()}
		
		self:PrintDebug(string.format("Button anchors: %.2f, %.2f, %.2f, %.2f", PetBtnAnchors[1], PetBtnAnchors[2], PetBtnAnchors[3], PetBtnAnchors[4]))
		self:PrintDebug(string.format("Button offsets: %d, %d, %d, %d", PetBtnOffsets[1], PetBtnOffsets[2], PetBtnOffsets[3], PetBtnOffsets[4]))
		self:PrintDebug(string.format("Default offsets: %d, %d, %d, %d", self.ConfigData.default.btnOffset[1], self.ConfigData.default.btnOffset[2], self.ConfigData.default.btnOffset[3], self.ConfigData.default.btnOffset[4]))
		
		-- Determine if button moved
		local NewPosition = false
		
		self:PrintDebug("Custom Position = " .. tostring(self.ConfigData.saved.CustomPosition))
		
		if self.ConfigData.saved.CustomPosition then
			if PetBtnOffsets ~= self.ConfigData.saved.btnOffset then
				self:PrintDebug("OffSets not equal")
				
				NewPosition = true
			else
				self:PrintDebug("OffSets equal")
			end
		else
			for idx = 1, #PetBtnOffsets do
				self:PrintDebug(string.format("Index = %d", idx))
				
				local dOffset = tonumber(self.ConfigData.default.btnOffset[idx])
				local bOffset = tonumber(PetBtnOffsets[idx])
				
				self:PrintDebug(string.format("bOffSet = %d, dOffset = %d", bOffset, dOffset))
				
				if -(bOffset) ~= -(dOffset) then
					self:PrintDebug("OffSets not equal")

					NewPosition = true
					
					break
				else
					self:PrintDebug("OffSets equal")
				end
			end
		end
		
		-- Move FlyoutFrame if needed
		if NewPosition then
			self:PrintDebug("Button moved")
			
			-- Save new position
			self.ConfigData.saved.btnOffset = PetBtnOffsets
			self.ConfigData.saved.btnAnchor = PetBtnAnchors
			self.ConfigData.saved.CustomPosition = true

			-- Calculate FlyoutFrame Offsets
			local fLeft = PetBtnOffsets[1] - self.ConfigData.default.wndListOffsets [1]
			local fTop = PetBtnOffsets[2] - self.ConfigData.default.wndListOffsets [2]
			local fRight = PetBtnOffsets[3] + self.ConfigData.default.wndListOffsets [3]
			local fBottom = PetBtnOffsets[4] - self.ConfigData.default.wndListOffsets [4]
						
			-- Save new offsets
			self.ConfigData.saved.lstAnchors = {self.wndPetFlyout:GetAnchorPoints()}
			self.ConfigData.saved.lstOffset = {fLeft, fTop, fRight, fBottom}
			
			self:PrintDebug(string.format("List anchors: %.2f, %.2f, %.2f, %.2f", self.ConfigData.saved.lstAnchors[1], self.ConfigData.saved.lstAnchors[2], self.ConfigData.saved.lstAnchors[3], self.ConfigData.saved.lstAnchors[4]))
			self:PrintDebug(string.format("List offsets: %d, %d, %d, %d", self.ConfigData.saved.lstOffset[1], self.ConfigData.saved.lstOffset[2], self.ConfigData.saved.lstOffset[3], self.ConfigData.saved.lstOffset[4]))
			
			-- Move FlyoutFrame
			self:MoveFlyoutFrame(self.ConfigData.saved.lstAnchors, self.ConfigData.saved.lstOffset)
		else
			self.ConfigData.saved.CustomPosition = false

			self:PrintDebug("Button not moved")
		end			
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsCenterBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsCenterBtn(wndHandler, wndControl)
	local suppressOutput = (self.ResetSavedData or false)

	if wndControl then
		self:PlayOptionsSound(wndControl, "Push")
		
		suppressOutput = true
	end
	
	self:PrintDebug("Centering button")
	
	if not suppressOutput then
		self:PrintMsg("Centering button", true)
	end
	
	self.ConfigData.saved.CustomPosition = true
	
	self.ConfigData.saved.btnAnchor = {0.5, 0.5, 0.5, 0.5}
	self.ConfigData.saved.btnOffset = {-46, -41, 46, 40}
	
	self.ConfigData.saved.lstAnchor = {0.5, 0.5, 0.5, 0.5}
	
	-- Calculate FlyoutFrame Offsets
	local fLeft = self.ConfigData.saved.btnOffset[1] - self.ConfigData.default.wndListOffsets [1]
	local fTop = self.ConfigData.saved.btnOffset[2] - self.ConfigData.default.wndListOffsets [2]
	local fRight = self.ConfigData.saved.btnOffset[3] + self.ConfigData.default.wndListOffsets [3]
	local fBottom = self.ConfigData.saved.btnOffset[4] - self.ConfigData.default.wndListOffsets [4]
				
	-- Save new offsets
	self.ConfigData.saved.lstOffset = {fLeft, fTop, fRight, fBottom}
	
	self:MoveButton(self.ConfigData.saved.btnAnchor, self.ConfigData.saved.btnOffset, self.ConfigData.saved.lstAnchor, self.ConfigData.saved.lstOffset)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsRestoreDefaultPositionBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsRestoreDefaultPositionBtn(wndHandler, wndControl)
	local suppressOutput = (self.ResetSavedData or false)

	if wndControl then
		self:PlayOptionsSound(wndControl, "Push")
		
		suppressOutput = true
	end
	
	self:PrintDebug("Restoring default button position")
	
	if not suppressOutput then
		self:PrintMsg("Restoring button to default position", true)
	end
	
	self.ConfigData.saved.CustomPosition = false
	self.ConfigData.saved.btnAnchor = nil
	self.ConfigData.saved.btnOffset = nil
	self.ConfigData.saved.lstAnchor = nil
	self.ConfigData.saved.lstOffset = nil
	
	self:MoveButton(self.ConfigData.default.btnAnchor, self.ConfigData.default.btnOffset, self.ConfigData.default.lstAnchor, self.ConfigData.default.lstOffset)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic MoveButton Function
---------------------------------------------------------------------------------------------------
function PetOMatic:MoveButton(btnAnchor, btnOffset, lstAnchor, lstOffset)
	self:PrintDebug("Moving button")
	self:PrintDebug(string.format("Button anchors (2): %.2f, %.2f, %.2f, %.2f", btnAnchor[1], btnAnchor[2], btnAnchor[3], btnAnchor[4]))
	self:PrintDebug(string.format("Button offsets (2): %d, %d, %d, %d", btnOffset[1], btnOffset[2], btnOffset[3], btnOffset[4]))
	self:PrintDebug(string.format("List anchors (2): %.2f, %.2f, %.2f, %.2f", lstAnchor[1], lstAnchor[2], lstAnchor[3], lstAnchor[4]))
	self:PrintDebug(string.format("List offsets (2): %d, %d, %d, %d", lstOffset[1], lstOffset[2], lstOffset[3], lstOffset[4]))
	
	self.wndPetFlyout:SetAnchorPoints(btnAnchor[1], btnAnchor[2], btnAnchor[3], btnAnchor[4])
	self.wndPetFlyout:SetAnchorOffsets(btnOffset[1], btnOffset[2], btnOffset[3], btnOffset[4])
	
	self:MoveFlyoutFrame(lstAnchor, lstOffset)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic MoveFlyoutFrame Function
---------------------------------------------------------------------------------------------------
function PetOMatic:MoveFlyoutFrame(lstAnchor, lstOffset)
	self:PrintDebug("Moving list")	
	self:PrintDebug(string.format("List anchors (3): %.2f, %.2f, %.2f, %.2f", lstAnchor[1], lstAnchor[2], lstAnchor[3], lstAnchor[4]))
	self:PrintDebug(string.format("List offsets (3): %d, %d, %d, %d", lstOffset[1], lstOffset[2], lstOffset[3], lstOffset[4]))

	
	self.wndPetFlyoutFrame:SetAnchorPoints(lstAnchor[1], lstAnchor[2], lstAnchor[3], lstAnchor[4])
	self.wndPetFlyoutFrame:SetAnchorOffsets(lstOffset[1], lstOffset[2], lstOffset[3], lstOffset[4])
	
	self:ResizeList()
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsHideAddonBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsHideAddonBtn(wndHandler, wndControl)
	local suppressOutput = false
	
	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
		
		suppressOutput = true
	end
	
	self.ConfigData.saved.HideAddon = not self.ConfigData.saved.HideAddon
	self:ToggleHide(self.ConfigData.saved.HideAddon, suppressOutput)
	
	self.ConfigData.saved.HideInCombat = false
	self.wndPetOptions:FindChild("PetOptionsHideInCombatBtn"):SetCheck(false)
	self:ToggleHideInCombat(false, true)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsHideInCombatBtn Function
---------------------------------------------------------------------------------------------------

function PetOMatic:OnPetOptionsHideInCombatBtn( wndHandler, wndControl, eMouseButton )
	local suppressOutput = false

	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
		
		suppressOutput = true
	end
	
	self.ConfigData.saved.HideInCombat = (not self.ConfigData.saved.HideInCombat)
	self:ToggleHideInCombat(self.ConfigData.saved.HideInCombat, suppressOutput)
	
	self.ConfigData.saved.HideAddon = false
	self.wndPetOptions:FindChild("PetOptionsHideAddonBtn"):SetCheck(false)
	self:ToggleHide(false, true)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleHideInCombat Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleHideInCombat(bHideInCombat, SuppressOutput)
	if self.ConfigData.saved.HideInCombat then		
		self:PrintDebug("Enabling Hide Button in Combat")
		
		if not SuppressOutput then
			self:PrintMsg("Hide button in combat enabled", true)
		end
	else
		self:PrintDebug("Disabling Hide button in combat")
		
		if not SuppressOutput then
			self:PrintMsg("Hide button in combat disabled", true)
		end
	end
	
	self.wndPetOptions:FindChild("PetOptionsHideInCombatBtn"):SetCheck(bHideInCombat)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnCombatToggleHide Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnCombatToggleHide()
	if self.ConfigData.saved.HideInCombat then
		if GameLib.GetPlayerUnit():IsInCombat() then
			self:PrintDebug("Player in combat; hiding button")
			
			self:ToggleHide(true, true, true)
		else
			self:PrintDebug("Player left combat; showing button")
			
			self:ToggleHide(false,true, true)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleHide Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleHide(bHideAddon, SuppressOutput, Combat)
	Combat = (Combat ~= nil and Combat or false)
	
	if bHideAddon then
		self:PrintDebug("Hiding button")
	else
		self:PrintDebug("Unhiding button")
	end
	
	if not Combat then
		self.wndPetOptions:FindChild("PetOptionsHideAddonBtn"):SetCheck(bHideAddon)
	
		if bHideAddon  then
			self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):Enable(false)
			self.wndPetOptions:FindChild("PetOptionsRestoreDefaultPositionBtn"):Enable(false)
			self.wndPetOptions:FindChild("PetOptionsCenterBtn"):Enable(false)
			
			if not SuppressOutput then
				self:PrintMsg("Button hidden", true)
			end
		else
			self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):Enable(true)
			self.wndPetOptions:FindChild("PetOptionsRestoreDefaultPositionBtn"):Enable(true)
			self.wndPetOptions:FindChild("PetOptionsCenterBtn"):Enable(true)
			
			if not SuppressOutput then
				self:PrintMsg("Button visible", true)
			end
		end
	end
	
	self.wndPetFlyout:Show(not bHideAddon )
end
	
---------------------------------------------------------------------------------------------------
-- PetOMatic InitSlider Function
---------------------------------------------------------------------------------------------------
function PetOMatic:InitSlider(slider, min, max, tick, value, roundDigits, callback)
	slider:SetData({
		callback = callback,
		digits = roundDigits
	})
	
	slider:FindChild("Slider"):SetMinMax(min, max, tick)
	slider:FindChild("Slider"):SetValue(value)
	slider:FindChild("Input"):SetText(tostring(value))
	slider:FindChild("Min"):SetText(tostring(min))
	slider:FindChild("Max"):SetText(tostring(max))
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsMaxListSizeChanged Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsMaxListSizeChanged(wndHandler, wndControl, value)
	if wndControl then
		self:PlayOptionsSound(wndControl, "Push")
		
		self.ConfigData.saved.MaxListSize = value
		
		value = self:UpdateSlider(wndHandler, value)
		wndHandler:GetParent():GetData().callback(value)
	else
		slider = self.wndPetOptions:FindChild("MaxPetListSize")
		
		self:PrintMsg(string.format("New maximum list size set to: %d", self.ConfigData.saved.MaxListSize), true)
		
		slider:FindChild("Slider"):SetValue(self.ConfigData.saved.MaxListSize)
		slider:FindChild("Input"):SetText(tostring(self.ConfigData.saved.MaxListSize))
	end
	
	self:PrintDebug("New Max List Size: " .. tostring(self.ConfigData.saved.MaxListSize))
	
	if self.NumberOfPets > 0 then
		self:ResizeList()
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic UpdateSizeSlider Function
---------------------------------------------------------------------------------------------------
function PetOMatic:UpdateSlider(wndHandler, value)
	local parent = wndHandler:GetParent()
	if wndHandler:GetName() == "Input" then
		value = self:round(tonumber(value))
		if not value then
			return nil
		end
	else
		value = self:round(value, wndHandler:GetParent():GetData().digits)
		parent:FindChild("Input"):SetText(tostring(value))
	end
	
	parent:FindChild("Slider"):SetValue(value)
	
	return value
end

---------------------------------------------------------------------------------------------------
-- PetOMatic PlayOptionsSound Function
---------------------------------------------------------------------------------------------------
function PetOMatic:PlayOptionsSound(wndControl, soundType)
	if soundType == "Checkbox" then
		if wndControl:IsChecked() then
			Sound.Play(Sound.PlayUIButtonHoloLarge)
		else
			Sound.Play(Sound.PlayUIButtonHoloSmall)
		end
	elseif soundType == "Push" then
		Sound.Play(Sound.PlayUI11To13GenericPushButtonDigital01)
	elseif soundType == "Window" then	
		if not wndControl:IsShown() then
			Sound.Play(Sound.PlayUIWindowHoloOpen)
		else
			Sound.Play(Sound.PlayUIWindowHoloClose)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ClearSavedData Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ClearSavedData()
	self.ResetSavedData = true
	
	self:PrintMsg("Resetting addon...", true)
	
	self.ConfigData.saved.CustomPosition = false
	self.ConfigData.saved.btnOffset = nil
	self.ConfigData.saved.lstOffset = nil
	self.ConfigData.saved.SelectedPet = nil
	self.ConfigData.saved.AutoSummon = false
	self.ConfigData.saved.SuspendInRaid = false
	self.ConfigData.saved.HideAddon = false
	self.ConfigData.saved.MaxListSize = false
	
	self:LoadOptions()
	self:OnPetOptionsRestoreDefaultPositionBtn()
	self:UpdatePetList()
	
	self:PrintMsg(" - Addon reset", false)
	
	self.ResetSavedData = false
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
		self.ConfigData.saved = setmetatable(tData, {__index = config_POM.user})
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic SlashCommandHandler Function
---------------------------------------------------------------------------------------------------
function PetOMatic:SlashCommandHandler(cmd, arg)
	local CmdFound = false
	
	self:PrintDebug(string.format("cmd = %s; arg = %s", cmd, arg))
	
	-- Handle 'max' command with value
	if string.find(arg, "max") == 1 then
		local maxInfo = split(arg, " ")
		arg = maxInfo[1]
		local value = tonumber(maxInfo[2])
		
		if value then
			if kListSizeMin_POM <= value and value <= kListSizeMax_POM  and value % 1 == 0 then
				self.ConfigData.saved.MaxListSize = value
			else
				self:PrintDebug("INVALID_LIST_SIZE")
				
				self:PrintMsg(string.format("Invalid list size: %s. List size must be a whole number between %d and %d", value, kListSizeMin_POM, kListSizeMax_POM), true)
				
				return
			end
		else
			self:PrintDebug("INVALID_MAX_VALUE")
			
			self:PrintMsg(string.format("ERROR - '%s' command must be followed by a number between %d and %d", arg, kListSizeMin_POM, kListSizeMax_POM), true)
			
			return
		end			
		
		self:PrintDebug(string.format("arg = %s; MaxListSize = %d", arg, self.ConfigData.saved.MaxListSize))
	end
	
	for cmd, attribs in pairs(SlashCommands_POM) do
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
	self:PrintMsg(string.format("%s Available Commands:", kstrContainerEventName_POM), false)

	local cmdList = {}
	
	for cmd in pairs(SlashCommands_POM) do
		self:PrintDebug(cmd)
		table.insert(cmdList, cmd)
	end
	
	table.sort(cmdList)

	for idx, cmd in pairs(cmdList) do
		local PrintCmd = true
		
		if not SlashCommands_POM[cmd].show then
			if GameLib.GetPlayerUnit():GetName() ~= kCreator_POM then
				PrintCmd = false
			end
		end

		if PrintCmd then
			self:PrintMsg(string.format("- %s : %s", (SlashCommands_POM[cmd].disp ~= nil and SlashCommands_POM[cmd].disp or cmd), SlashCommands_POM[cmd].desc), false)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic round Function
---------------------------------------------------------------------------------------------------
function PetOMatic:round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

-----------------------------------------------------------------------------------------------
-- PetOMatic Instance
-----------------------------------------------------------------------------------------------
local PetOMaticInst = PetOMatic:new()
PetOMaticInst:Init()
