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
kVersion = "1.5.0"
kResetOptions = false

kListSizeMin = 1
kListSizeMax = 7

local config = {}

config.defaults = {}
config.user = {}

config.defaults.Creator = "Zaresir Tinktaker"
config.defaults.DisplayHeight = Apollo.GetDisplaySize().nHeight
config.defaults.btnOffset = {-96, -113, -4, -32}
config.defaults.lstOffset = {-122, -407, 12, -87}
config.defaults.wndListOffsets = {26, 294, 16, 55}
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
config.user.HideAddon = false
config.user.MaxListSize = nil
config.user.Version = nil

SlashCommands = {
	debug = {disp = nil, desc = "Toggle DEBUG mode", hndlr = "E_PetOMaticDebug", func = "ToggleDebug"},
	config = {disp = nil, desc = "Open PetOMatic Options window", hndlr = "E_PetOMaticOptions", func = "ShowPetOptions"},
	auto = {disp = nil, desc = "Toggle autosummon feature", hndlr = "E_PetOMaticAutoSummon", func = "OnPetOptionsAutoSummonBtn"},
	hide = {disp = nil, desc = "Hide/show button", hndlr = "E_PetOMaticHide", func = "OnPetOptionsHideAddonBtn"},
	move = {disp = nil, desc = "Enable/disable button movement", hndlr = "E_PetOMaticMove", func = "OnPetOptionsMoveAddonBtn"},
	restore = {disp = nil, desc = "Restore default button position", hndlr = "E_PetOMaticRestor", func = "OnPetOptionsRestoreDefaultPositionBtn"},
	raid = {disp = nil, desc = "Enable/disable autosummoning in Raids", hndlr = "E_PetOMAticRaid", func = "OnPetOptionsSuspendInRaidBtn"},
	max = {disp = string.format("max [%d-%d]", kListSizeMin, kListSizeMax), desc = "Set the pet list size to specified value.", hndlr = "E_PetOMaticMax", func = "OnPetOptionsMaxListSizeChanged"},
	reset = {disp = nil, desc = "Clears all saved addon data and settings", hndlr = "E_PetOMaticReset", func = "ClearSavedData"}
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
	
	self.ResetSavedData = false
	
	self.PetListLoaded = false
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
	self:PrintDebug("Init Success")
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
	self:PrintMsg(string.format("Version %s loaded", tostring(kVersion)), true)
	
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
	Apollo.RegisterEventHandler("Mount", "OnDismount", self)
	
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
	for cmd, attribs in pairs(SlashCommands) do
		self:PrintDebug(string.format("Registering event handler: %s, %s", attribs.hndlr, attribs.func))
		
		Apollo.RegisterEventHandler(attribs.hndlr, attribs.func, self)
	end		
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnInterfaceMenuListHasLoaded Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnInterfaceMenuListLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", kstrContainerEventName, {"PetOptionsMenuClicked", "", "IconSprites:Icon_Windows32_UI_CRB_InterfaceMenu_NonCombatAbility"})
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
	msg = string.format("%s: %s", kstrContainerEventName, msg)
	if self.ConfigData.saved.Debug then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, msg)
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic PrintMsg Function
---------------------------------------------------------------------------------------------------
function PetOMatic:PrintMsg(msg, header)
	if header then
		msg = string.format("%s: %s", kstrContainerEventName, msg)
	end
	
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, msg)
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
-- PetOMatic UpdatePetList Function
---------------------------------------------------------------------------------------------------
function PetOMatic:UpdatePetList()
	if not self.wndPetFlyoutList then
		return
	end
	
	self:PrintDebug("Updating Pet List")
	
	local arPetList = GameLib.GetVanityPetList()
	local firstKnownPet = nil
	
	if #self.wndPetFlyoutList:GetChildren() > 0 then
		self.wndPetFlyoutList:DestroyChildren()
	end

	table.sort(arPetList, function(a,b) return (a.bIsKnown and not b.bIsKnown) or (a.bIsKnown == b.bIsKnown and a.strName < b.strName) end)

	for idx = 1, #arPetList do
		local tPetInfo = arPetList[idx]
		local wndPetBtn = nil

		if tPetInfo.bIsKnown then
			self:PrintDebug("Known Pet: " .. tPetInfo.strName)
			
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
	
	if not self.PetListLoaded then
		self.PetListLoaded = true
		self:PrintMsg(string.format("%d pets unlocked", self.NumberOfPets), true)
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
-- PetOMatic IsActiveVanityPetFunction
---------------------------------------------------------------------------------------------------
function PetOMatic:IsActiveVanityPet()
	local arPets = GameLib.GetPlayerPets()
	local arPetList = GameLib.GetVanityPetList()
	
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
	local arPets = GameLib.GetPlayerPets()
	
	if arPets then
		for idx, unitPet in pairs(arPets) do
			self:PrintDebug(string.format("Summoned = %s; Selected = %s", tostring(unitPet:GetName()), tostring(self.ConfigData.saved.SelectedPet.strName)))
						
			if unitPet:GetName() == self.ConfigData.saved.SelectedPet.strName then
				self:PrintDebug("IsSummoned = True")
				
				return true
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
	self:PrintDebug("kVersion = " .. tostring(kVersion))
	self:PrintDebug("User Version = " .. tostring(self.ConfigData.saved.version))
	self:PrintDebug("kResetOptions = " .. tostring(kResetOptions))
	
	if self.ConfigData.saved.Version ~= kVersion and kResetOptions then
		self:PrintDebug("Resetting Options...")
		
		self:PrintMsg("New version requires options reset. Clearing all saved data...", true)
		
		self.ConfigData.saved.Version = kVersion
		
		self.ClearSavedData()
	else
		self:PrintDebug("Loading options...")
	end
	
	self.ConfigData.saved.Version = kVersion
	
	self:PrintDebug("- AutoSummon = " .. tostring(self.ConfigData.saved.AutoSummon ~= nil and self.ConfigData.saved.AutoSummon or self.ConfigData.default.AutoSummon))
	self:PrintDebug("- SuspendInRaid = " .. tostring(self.ConfigData.saved.SuspendInRaid ~= nil and self.ConfigData.saved.SuspendInRaid or self.ConfigData.default.SuspendInRaid))
	self:PrintDebug("- HideAddon = " .. tostring(self.ConfigData.saved.HideAddon ~= nil and self.ConfigData.saved.HideAddon or self.ConfigData.default.HideAddon))
	self:PrintDebug("- MaxListSize = " .. tostring(self.ConfigData.saved.MaxListSize ~= nil and self.ConfigData.saved.MaxListSize or self.ConfigData.default.MaxListSize))
	
	self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):SetCheck(False)
	self:ToggleMoveable(false, true)
	self:ToggleAutoSummon(self.ConfigData.saved.AutoSummon ~= nil and self.ConfigData.saved.AutoSummon or self.ConfigData.default.AutoSummon, true)
	self:ToggleSuspendInRaid(self.ConfigData.saved.SuspendInRaid ~= nil and self.ConfigData.saved.SuspendInRaid or self.ConfigData.default.SuspendInRaid, true)
	self:ToggleHide(self.ConfigData.saved.HideAddon ~= nil and self.ConfigData.saved.HideAddon or self.ConfigData.default.HideAddon, true)
	self:UpdateSizeSlider(self.ConfigData.saved.MaxListSize ~= nil and self.ConfigData.saved.MaxListSize or self.ConfigData.default.MaxListSize, true)
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
	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
	end

	self.ConfigData.saved.AutoSummon = not self.ConfigData.saved.AutoSummon
	self:ToggleAutoSummon(self.ConfigData.saved.AutoSummon)
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
-- PetOMatic OnPetOptionsNoSuspendInRaidBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsSuspendInRaidBtn(wndHandler, wndControl)
	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
	end
	
	self.ConfigData.saved.SuspendInRaid = (not self.ConfigData.saved.SuspendInRaid)
	self:ToggleSuspendInRaid(self.ConfigData.saved.SuspendInRaid)
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
	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
	
		if wndControl:IsChecked() then
			self:PrintDebug("Move button checked")
		
			self:ToggleMoveable(true)
		else
			self:PrintDebug("Move button unchecked")
		
			self:ToggleMoveable(false)
		end
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

		-- Determine Button Offsets and save values
		local PetBtnOffsets = {self.wndPetFlyout:GetAnchorOffsets()}
		
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
			self.ConfigData.saved.CustomPosition = true

			-- Calculate FlyoutFrame Offsets
			local fLeft = PetBtnOffsets[1] - self.ConfigData.default.wndListOffsets [1]
			local fTop = PetBtnOffsets[2] - self.ConfigData.default.wndListOffsets [2]
			local fRight = PetBtnOffsets[3] + self.ConfigData.default.wndListOffsets [3]
			local fBottom = PetBtnOffsets[4] - self.ConfigData.default.wndListOffsets [4]
						
			-- Save new offsets
			self.ConfigData.saved.lstOffset = {fLeft, fTop, fRight, fBottom}
			
			-- Move FlyoutFrame
			self:MoveFlyoutFrame(self.ConfigData.saved.lstOffset)
		else
			self.ConfigData.saved.CustomPosition = false

			self:PrintDebug("Button not moved")
		end			
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsRestoreDefaultPositionBtn Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsRestoreDefaultPositionBtn(wndHandler, wndControl)
	if wndControl then
		self:PlayOptionsSound(wndControl, "Push")
	end
	
	self:PrintDebug("Restoring default button position")
	
	if not self.ResetSavedData then
		self:PrintMsg("Restoring button to default position", true)
	end
	
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
	if wndControl then
		self:PlayOptionsSound(wndControl, "Checkbox")
	end
	
	self.ConfigData.saved.HideAddon = not self.ConfigData.saved.HideAddon
	self:ToggleHide(self.ConfigData.saved.HideAddon)
end

---------------------------------------------------------------------------------------------------
-- PetOMatic ToggleHide Function
---------------------------------------------------------------------------------------------------
function PetOMatic:ToggleHide(bHideAddon, SuppressOutput)
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
		
		if not SuppressOutput then
			self:PrintMsg("Button hidden", true)
		end
	else
		self.wndPetOptions:FindChild("PetOptionsMoveAddonBtn"):Enable(true)
		self.wndPetOptions:FindChild("PetOptionsRestoreDefaultPositionBtn"):Enable(true)
		
		if not SuppressOutput then
			self:PrintMsg("Button visible", true)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- PetOMatic OnPetOptionsMaxListSizeChanged Function
---------------------------------------------------------------------------------------------------
function PetOMatic:OnPetOptionsMaxListSizeChanged(wmdHandler, wndControl, fNewValue, fOldValue)
	if wndControl then
		self.ConfigData.saved.MaxListSize = fNewValue
	else
		self:PrintMsg(string.format("New maximum list size set to: %d", self.ConfigData.saved.MaxListSize), true)
		self.wndPetOptions:FindChild("MaxPetListSizeSlider"):SetValue(self.ConfigData.saved.MaxListSize)
	end
	
	self.wndPetOptions:FindChild("MaxPetListSizeText"):SetText(self.ConfigData.saved.MaxListSize)
	
	self:PrintDebug("New Max List Size: " .. tostring(self.ConfigData.saved.MaxListSize))
	
	if self.NumberOfPets > 0 then
		self:ResizeList()
	end
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
	self.ConfigData.saved.btnOffset = {}
	self.ConfigData.saved.lstOffset = {}
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
		self.ConfigData.saved = setmetatable(tData, {__index = config.user})
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
			if kListSizeMin <= value and value <= kListSizeMax  and value % 1 == 0 then
				self.ConfigData.saved.MaxListSize = value
			else
				self:PrintDebug("INVALID_LIST_SIZE")
				
				self:PrintMsg(string.format("Invalid list size: %s. List size must be a whole number between %d and %d", value, kListSizeMin, kListSizeMax), true)
				
				return
			end
		else
			self:PrintDebug("INVALID_MAX_VALUE")
			
			self:PrintMsg(string.format("ERROR - '%s' command must be followed by a number between %d and %d", arg, kListSizeMin, kListSizeMax), true)
			
			return
		end			
		
		self:PrintDebug(string.format("arg = %s; MaxListSize = %d", arg, self.ConfigData.saved.MaxListSize))
	end
	
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
	self:PrintMsg(string.format("%s Available Commands:", kstrContainerEventName), false)

	local cmdList = {}
	
	for cmd in pairs(SlashCommands) do
		self:PrintDebug("cmd")
		table.insert(cmdList, cmd)
	end
	
	table.sort(cmdList)

	for idx, cmd in pairs(cmdList) do
		local PrintCmd = true
		
		if cmd == "debug" then
			if GameLib.GetPlayerUnit():GetName() ~= self.ConfigData.default.Creator then
				PrintCmd = false
			end
		end

		if PrintCmd then
			self:PrintMsg(string.format("- %s : %s", (SlashCommands[cmd].disp ~= nil and SlashCommands[cmd].disp or cmd), SlashCommands[cmd].desc), false)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- PetOMatic Instance
-----------------------------------------------------------------------------------------------
local PetOMaticInst = PetOMatic:new()
PetOMaticInst:Init()
