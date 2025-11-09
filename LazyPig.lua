LPCONFIG = {}
LPCONFIG.DISMOUNT = false
LPCONFIG.CAM = false
LPCONFIG.GINV = false
LPCONFIG.FINV = false
LPCONFIG.SINV = nil
LPCONFIG.DINV = false
LPCONFIG.SUMM = true
LPCONFIG.EBG = false
LPCONFIG.LBG = false
LPCONFIG.QBG = false
LPCONFIG.RBG = false
LPCONFIG.SBG = false
LPCONFIG.AQUE = false
LPCONFIG.LOOT = false
LPCONFIG.EPLATE = false
LPCONFIG.FPLATE = false
LPCONFIG.HPLATE = false
LPCONFIG.RIGHT = true
LPCONFIG.ZG = 1
LPCONFIG.MC = 1
LPCONFIG.AQ = 2
LPCONFIG.AQMOUNT = 0
LPCONFIG.SAND = 1
LPCONFIG.NAXX = 0
LPCONFIG.BWL = 0
LPCONFIG.WHITE_TAILORING = 0
LPCONFIG.FOOD_AND_DRINK = 0
LPCONFIG.ES_SHARDS = 0
LPCONFIG.ROLLMSG = true
LPCONFIG.DUEL = false
LPCONFIG.GREEN = 2
LPCONFIG.SPECIALKEY = false
LPCONFIG.WORLDDUNGEON = false
LPCONFIG.WORLDRAID = false
LPCONFIG.WORLDBG = false
LPCONFIG.WORLDUNCHECK = nil
LPCONFIG.SPAM = false
LPCONFIG.SPAM_UNCOMMON = false
LPCONFIG.SPAM_RARE = false
LPCONFIG.SHIFTSPLIT = false
LPCONFIG.REZ = true
LPCONFIG.GOSSIP = false
LPCONFIG.SALVA = false
LPCONFIG.REMOVEMANABUFFS = false

BINDING_HEADER_LP_HEADER = "_LazyPig";
BINDING_NAME_LOGOUT = "Logout";
BINDING_NAME_UNSTUCK = "Unstuck";
BINDING_NAME_RELOAD = "Reaload UI";
BINDING_NAME_DUEL = "Target WSG EFC/Duel Request-Cancel";
BINDING_NAME_WSGDROP = "Drop WSG Flag/Remove Slow Fall";
BINDING_NAME_MENU = "_LazyPig Menu";

local Original_SelectGossipActiveQuest = SelectGossipActiveQuest;
local Original_SelectGossipAvailableQuest = SelectGossipAvailableQuest;
local Original_SelectActiveQuest = SelectActiveQuest;
local Original_SelectAvailableQuest = SelectAvailableQuest;
local OriginalLootFrame_OnEvent = LootFrame_OnEvent;
local OriginalLootFrame_Update = LootFrame_Update;
local Original_SetItemRef = SetItemRef;
local Original_ChatFrame_OnEvent = ChatFrame_OnEvent;
local Original_StaticPopup_OnShow = StaticPopup_OnShow;
local Original_QuestRewardItem_OnClick = QuestRewardItem_OnClick

local roster_task_refresh = 0
local last_click = 0
local delayaction = 0
local tradedelay = 0
local bgstatus = 0
local tmp_splitval = 1
local passpopup = 0

local ctrltime = 0
local alttime = 0
local shift_time = 0
local greenrolltime = 0

local timer_split = nil
local player_summon_confirm = nil
local player_summon_message = nil
local player_bg_confirm = nil
local player_bg_message = nil
local afk_active = nil
local duel_active = nil
local dnd_active = false
local merchantstatus = nil
local tradestatus = nil
local mailstatus = nil
local auctionstatus = nil
local auctionbrowse = nil
local bankstatus = nil
local channelstatus = nil
local battleframe = nil
local wsgefc = nil

local WHITE = "|cffffffff"
local RED = "|cffff0000"
local GREEN = "|cff00ff00"
local BLUE = "|cff00eeee"

local ScheduleFunction = {}
local QuestRecord = {}
local ActiveQuest = {}
local AvailableQuest = {}
local ChatMessage = {{}, {}, INDEX = 1}


local LazyPigMenuObjects = {}
local LazyPigMenuStrings = {}
LazyPigMenuStrings[21] = "LazyPig Auto Roll Messages"
LazyPigMenuStrings[22] = "Dungeon"
LazyPigMenuStrings[23] = "Raid"
LazyPigMenuStrings[24] = "Battleground"
LazyPigMenuStrings[25] = "Mute Permanently"

LazyPigMenuStrings[60] = "Always"
LazyPigMenuStrings[61] = "Paladin Righteous Fury"

LazyPigMenuStrings[70] = "Players' Spam"
LazyPigMenuStrings[71] = "Uncommon Roll"
LazyPigMenuStrings[72] = "Rare Roll"
LazyPigMenuStrings[73] = "Poor-Common-Money Loot"

LazyPigMenuStrings[90] = "Summon Auto Accept"
LazyPigMenuStrings[91] = "Loot Window Auto Position"
LazyPigMenuStrings[94] = "Extended Camera Distance"
LazyPigMenuStrings[97] = "Instance Resurrection Accept OOC"
LazyPigMenuStrings[98] = "Gossip Auto Processing"
LazyPigMenuStrings[101] = "Chat Spam Filter"

function LazyPig_OnLoad()
	SelectGossipActiveQuest = LazyPig_SelectGossipActiveQuest;
	SelectGossipAvailableQuest = LazyPig_SelectGossipAvailableQuest;
	SelectActiveQuest = LazyPig_SelectActiveQuest;
	SelectAvailableQuest = LazyPig_SelectAvailableQuest;
	LootFrame_OnEvent = LazyPig_LootFrame_OnEvent;
	LootFrame_Update = LazyPig_LootFrame_Update;
	SetItemRef = LazyPig_SetItemRef_OnEvent;
	ChatFrame_OnEvent = LazyPig_ChatFrame_OnEvent;
	StaticPopup_OnShow = LazyPig_StaticPopup_OnShow;
	QuestRewardItem_OnClick = LazyPig_QuestRewardItem_OnClick

	SLASH_LAZYPIG1 = "/lp";
	SLASH_LAZYPIG2 = "/lazypig";
	SlashCmdList["LAZYPIG"] = LazyPig_Command;

	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("PLAYER_LOGIN")
end

function LazyPig_Command()
	if LazyPigOptionsFrame:IsShown() then
		LazyPigOptionsFrame:Hide()
	else
		LazyPigOptionsFrame:Show()
	end
end

function LazyPig_OnUpdate()
	if (this.tick or 0.1) > GetTime() then
		return
	else
		this.tick = GetTime() + 0.1
	end

	local current_time = GetTime();
	local shiftstatus = IsShiftKeyDown();
	local ctrlstatus = IsControlKeyDown();
	local altstatus = IsAltKeyDown();

	if shiftstatus then
		shift_time = current_time
	elseif altstatus and not ctrlstatus and current_time > alttime then
		alttime = current_time + 0.75
	elseif not altstatus and ctrlstatus and current_time > ctrltime then
		ctrltime = current_time + 0.75
	elseif not altstatus and not ctrlstatus or altstatus and ctrlstatus then
		ctrltime = 0
		alttime = 0
	end

	if altstatus then
		if QuestFrameDetailPanel:IsVisible() then
			AcceptQuest();
		end
	elseif QuestRecord["details"] and not altstatus then
		LazyPig_RecordQuest();
	end

	if player_summon_confirm then
		LazyPig_AutoSummon();
	end

	LazyPig_CheckSalvation();
	ScheduleFunctionLaunch();

end

function ScheduleFunctionLaunch(func, delay)
	local current_time = GetTime()
	if func and not ScheduleFunction[func] then
		delay = delay or 0.75
		ScheduleFunction[func] = current_time + delay
	else
		for blockindex,blockmatch in pairs(ScheduleFunction) do
			if current_time >= blockmatch then
				blockindex()
				ScheduleFunction[blockindex] = nil
			end
		end
	end
end

function LazyPig_OnEvent(event)
	if (event == "ADDON_LOADED") and (arg1 == "_LazyPig") then
		this:UnregisterEvent("ADDON_LOADED")
		local LP_TITLE = GetAddOnMetadata("_LazyPig", "Title")
		local LP_VERSION = GetAddOnMetadata("_LazyPig", "Version")
		local LP_AUTHOR = GetAddOnMetadata("_LazyPig", "Author")

		DEFAULT_CHAT_FRAME:AddMessage(LP_TITLE .. " v" .. LP_VERSION .. " by " .."|cffFF0066".. LP_AUTHOR .."|cffffffff".. " loaded, type".."|cff00eeee".." /lp".."|cffffffff for options")
	elseif (event == "PLAYER_LOGIN") then
		this:RegisterEvent("CHAT_MSG")
		this:RegisterEvent("CHAT_MSG_SYSTEM")
		this:RegisterEvent("CONFIRM_SUMMON")
		this:RegisterEvent("RESURRECT_REQUEST")
		this:RegisterEvent("GOSSIP_SHOW")
		this:RegisterEvent("QUEST_GREETING")
		this:RegisterEvent("QUEST_PROGRESS")
		this:RegisterEvent("QUEST_COMPLETE")
		this:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		this:RegisterEvent("PLAYER_UNGHOST")
		this:RegisterEvent("PLAYER_AURAS_CHANGED")

		LazyPigOptionsFrame = LazyPig_CreateOptionsFrame()

		LazyPig_CheckSalvation();
		LazyPig_AutoSummon();
		ScheduleFunctionLaunch(LazyPig_ZoneCheck, 6);
		ScheduleFunctionLaunch(LazyPig_ZoneCheck2, 7);

		if LPCONFIG.CAM then SetCVar("cameraDistanceMax",50) end
		QuestRecord["index"] = 0

	elseif (LPCONFIG.SALVA and (event == "PLAYER_AURAS_CHANGED")) then
		LazyPig_CheckSalvation()

	elseif(event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UNGHOST") then
		if event == "ZONE_CHANGED_NEW_AREA" then
		end

		ScheduleFunctionLaunch(LazyPig_ZoneCheck, 5)
		ScheduleFunctionLaunch(LazyPig_ZoneCheck, 6)

	elseif(event == "QUEST_GREETING") then
		ActiveQuest = {}
		AvailableQuest = {}
		for i=1, GetNumActiveQuests() do
			ActiveQuest[i] = GetActiveTitle(i).." "..GetActiveLevel(i)
		end
		for i=1, GetNumAvailableQuests() do
			AvailableQuest[i] = GetAvailableTitle(i).." "..GetAvailableLevel(i)
		end

		LazyPig_ReplyQuest(event);

		--DEFAULT_CHAT_FRAME:AddMessage("active_: "..table.getn(ActiveQuest))
		--DEFAULT_CHAT_FRAME:AddMessage("available_: "..table.getn(AvailableQuest))

	elseif(event == "GOSSIP_SHOW") then
		local GossipOptions = {};
		local dsc = nil
		local gossipnr = nil
		local gossipbreak = nil
		local processgossip = LPCONFIG.GOSSIP and not IsShiftKeyDown()

		dsc,GossipOptions[1],_,GossipOptions[2],_,GossipOptions[3],_,GossipOptions[4],_,GossipOptions[5] = GetGossipOptions()

		ActiveQuest = LazyPig_ProcessQuests(GetGossipActiveQuests())
		AvailableQuest = LazyPig_ProcessQuests(GetGossipAvailableQuests())

		if QuestRecord["qnpc"] ~= UnitName("target") then
			QuestRecord["index"] = 0
			QuestRecord["qnpc"] = UnitName("target")
		end

		if table.getn(AvailableQuest) ~= 0 or table.getn(ActiveQuest) ~= 0 then
			gossipbreak = true
		end

		--DEFAULT_CHAT_FRAME:AddMessage("gossip: "..table.getn(GossipOptions))
		--DEFAULT_CHAT_FRAME:AddMessage("active: "..table.getn(ActiveQuest))
		--DEFAULT_CHAT_FRAME:AddMessage("available: "..table.getn(AvailableQuest))

		for i=1, getn(GossipOptions) do
			if GossipOptions[i] == "binder" then
				local bind = GetBindLocation();
				if not (bind == GetSubZoneText() or bind == GetZoneText() or bind == GetRealZoneText() or bind == GetMinimapZoneText()) then
					gossipbreak = true
				end
			elseif gossipnr then
				gossipbreak = true
			elseif (GossipOptions[i] == "trainer" and dsc == "Reset my talents.") then
				gossipbreak = false
			elseif ((GossipOptions[i] == "trainer" and processgossip)
					or (GossipOptions[i] == "vendor" and processgossip)
					or (GossipOptions[i] == "gossip" and processgossip)
					or (GossipOptions[i] == "banker" and string.find(dsc, "^I would like to check my deposit box.") and processgossip)
					or (GossipOptions[i] == "petition" and (IsAltKeyDown()or IsShiftKeyDown() or string.find(dsc, "Teleport me to the Molten Core")) and processgossip))
				then
				gossipnr = i
			end
		end

		if not gossipbreak and gossipnr then
			SelectGossipOption(gossipnr);
		else
			LazyPig_ReplyQuest(event);
		end

	elseif(event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE") then
		LazyPig_ReplyQuest(event);

	elseif (event == "CONFIRM_SUMMON") then
		LazyPig_AutoSummon();

	elseif(event == "RESURRECT_REQUEST" and LPCONFIG.REZ) then
		UIErrorsFrame:AddMessage(arg1.." - Resurrection")
		TargetByName(arg1, true)
		if GetCorpseRecoveryDelay() == 0 and (LazyPig_Raid() or LazyPig_Dungeon() or LazyPig_BG()) and UnitIsPlayer("target") and UnitIsVisible("target") and not UnitAffectingCombat("target") then
			AcceptResurrect()
			StaticPopup_Hide("RESURRECT_NO_TIMER");
			StaticPopup_Hide("RESURRECT_NO_SICKNESS");
			StaticPopup_Hide("RESURRECT");
		end
		TargetLastTarget();
	end
	--DEFAULT_CHAT_FRAME:AddMessage(event);
end

function LazyPig_StaticPopup_OnShow()
	if this.which == "QUEST_ACCEPT" and LazyPig_BG() and LPCONFIG.SBG then
		UIErrorsFrame:Clear();
		UIErrorsFrame:AddMessage("Quest Blocked Successfully");
		this:Hide();

	else
		Original_StaticPopup_OnShow();
	end
end

function LazyPig_Text(txt)
	if txt then
		LazyPigText:SetTextColor(0, 1, 0)
		LazyPigText:SetText(txt)
		LazyPigText:Show()
	else
		LazyPigText:SetText()
		LazyPigText:Hide()
	end
end

--code taken from quickloot
local function LazyPig_ItemUnderCursor()
	if LPCONFIG.LOOT then
		local x, y = GetCursorPosition();
		local scale = LootFrame:GetEffectiveScale();
		x = x / scale;
		y = y / scale;
		LootFrame:ClearAllPoints();
		for index = 1, LOOTFRAME_NUMBUTTONS, 1 do
			local button = getglobal("LootButton"..index);
			if( button:IsVisible() ) then
				x = x - 42;
				y = y + 56 + (40 * index);
				LootFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", x, y);
				return;
			end
		end
		if LootFrameDownButton:IsVisible() then
			x = x - 158;
			y = y + 223;
		else
			if GetNumLootItems() == 0  then
				HideUIPanel(LootFrame);
				return
			end
			x = x - 173;
			y = y + 25;
		end
		LootFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", x, y);
	end
end

function LazyPig_LootFrame_OnEvent(event)
	OriginalLootFrame_OnEvent(event);
	if(event == "LOOT_SLOT_CLEARED") then
		LazyPig_ItemUnderCursor();
	end
end

function LazyPig_LootFrame_Update()
	OriginalLootFrame_Update();
	LazyPig_ItemUnderCursor();
end

function LazyPig_AutoSummon()
	local keyenter = IsAltKeyDown() and IsControlKeyDown() and GetTime() > delayaction and GetTime() > (tradedelay + 0.5)
	if LPCONFIG.SUMM then
		local expireTime = GetSummonConfirmTimeLeft()
		if not player_summon_message and expireTime ~= 0 then
			player_summon_message = true
			player_summon_confirm = true
			DEFAULT_CHAT_FRAME:AddMessage("LazyPig: Auto Summon in "..math.floor(expireTime).."s", 1.0, 1.0, 0.0);

		elseif expireTime <= 3 or keyenter then
			player_summon_confirm = false
			player_summon_message = false

			for i=1,STATICPOPUP_NUMDIALOGS do
				local frame = getglobal("StaticPopup"..i)
				if frame.which == "CONFIRM_SUMMON" and frame:IsShown() then
					ConfirmSummon();
					delayaction = GetTime() + 0.75
					StaticPopup_Hide("CONFIRM_SUMMON");
				end
			end
		elseif expireTime == 0 then
			player_summon_confirm = false
			player_summon_message = false
		end
	end
end

function LazyPig_ProcessQuests(...)
	local quest = {}
	for i = 1, table.getn(arg), 2 do
		local count, title, level = i, arg[i], arg[i+1]
		if count > 1 then count = (count+1)/2 end
		quest[count] = title.." "..level
	end
	return quest
end

function LazyPig_PrepareQuestAutoPickup()
	if IsAltKeyDown() then
		GossipFrameCloseButton:Click();
		ClearTarget();
	end
end

function LazyPig_SelectGossipActiveQuest(index, norecord)
	if not ActiveQuest[index] then
		--DEFAULT_CHAT_FRAME:AddMessage("LazyPig_SelectGossipActiveQuest Error");
	elseif not norecord then
		LazyPig_RecordQuest(ActiveQuest[index])
	end
	Original_SelectGossipActiveQuest(index);
end

function LazyPig_SelectGossipAvailableQuest(index, norecord)
	if not AvailableQuest[index] then
		--DEFAULT_CHAT_FRAME:AddMessage("LazyPig_SelectGossipAvailableQuest Error");
	elseif not norecord then
		LazyPig_RecordQuest(AvailableQuest[index])
	end
	Original_SelectGossipAvailableQuest(index);
end

function LazyPig_SelectActiveQuest(index, norecord)
	if not ActiveQuest[index] then
		--DEFAULT_CHAT_FRAME:AddMessage("LazyPig_SelectActiveQuest Error");
	elseif not norecord then
		LazyPig_RecordQuest(ActiveQuest[index])
	end
	Original_SelectActiveQuest(index);
end

function LazyPig_SelectAvailableQuest(index, norecord)
	if not AvailableQuest[index] then
		--DEFAULT_CHAT_FRAME:AddMessage("LazyPig_SelectAvailableQuest Error");
	elseif not norecord then
		LazyPig_RecordQuest(AvailableQuest[index])
	end
	Original_SelectAvailableQuest(index);
end

function LazyPig_FixQuest(quest, annouce)
	if not QuestRecord["details"] then
		annouce = true
	end
	if UnitLevel("player") == 60 then
		if string.find(quest, "Fight for Warsong Gulch") then
			QuestRecord["details"] = "Fight for Warsong Gulch 60"
		elseif string.find(quest, "Battle of Warsong Gulch") then
			QuestRecord["details"] = "Battle of Warsong Gulch 60"
		elseif string.find(quest, "Claiming Arathi Basin") then
			QuestRecord["details"] = "Claiming Arathi Basin 60"
		elseif string.find(quest, "Conquering Arathi Basin") then
			QuestRecord["details"] = "Conquering Arathi Basin 60"
		end
	end
	if QuestRecord["details"] and annouce then
		UIErrorsFrame:Clear();
		UIErrorsFrame:AddMessage("Recording: "..QuestRecord["details"])
	end
end

function LazyPig_RecordQuest(qdetails)
	if IsAltKeyDown() and qdetails then
		if QuestRecord["details"] ~= qdetails then
			QuestRecord["details"] = qdetails
		end
		LazyPig_FixQuest(QuestRecord["details"], true)
	elseif not IsAltKeyDown() and QuestRecord["details"] then
		QuestRecord["details"] = nil
		QuestRecord.itemChoice = nil
	end
	QuestRecord["progress"] = true
end

function LazyPig_QuestRewardItem_OnClick()
	Original_QuestRewardItem_OnClick()
	if QuestRecord.details and this.type == "choice" then
		QuestRewardItemHighlight:SetPoint("TOPLEFT", this, "TOPLEFT", -8, 7);
		QuestRewardItemHighlight:Show();
		QuestFrameRewardPanel.itemChoice = this:GetID();
		QuestRecord.itemChoice = this:GetID();
	end
end

function LazyPig_ReplyQuest(event)
	if not IsAltKeyDown() then
		return
	end

	if QuestRecord["details"] then
		UIErrorsFrame:Clear();
		UIErrorsFrame:AddMessage("Replaying: "..QuestRecord["details"])
	end

	if event == "GOSSIP_SHOW" then
		if QuestRecord["details"] then
			for blockindex,blockmatch in pairs(ActiveQuest) do
				if blockmatch == QuestRecord["details"] then
					Original_SelectGossipActiveQuest(blockindex)
					return
				end
			end
			for blockindex,blockmatch in pairs(AvailableQuest) do
				if blockmatch == QuestRecord["details"] then
					Original_SelectGossipAvailableQuest(blockindex)
					return
				end
			end
		elseif table.getn(ActiveQuest) == 0 and table.getn(AvailableQuest) == 1 or IsAltKeyDown() and table.getn(AvailableQuest) > 0 then
			LazyPig_SelectGossipAvailableQuest(1, true)
		elseif table.getn(ActiveQuest) == 1 and table.getn(AvailableQuest) == 0 or IsAltKeyDown() and table.getn(ActiveQuest) > 0 then
			local nr = table.getn(ActiveQuest)
			if QuestRecord["progress"] and (nr - QuestRecord["index"]) > 0 then
				--DEFAULT_CHAT_FRAME:AddMessage("++quest dec nr - "..nr.." index - "..QuestRecord["index"])
				QuestRecord["index"] = QuestRecord["index"] + 1
				nr = nr - QuestRecord["index"]
			end
			LazyPig_SelectGossipActiveQuest(nr, true)
		end
	elseif event == "QUEST_GREETING" then
		if QuestRecord["details"] then
			for blockindex,blockmatch in pairs(ActiveQuest) do
				if blockmatch == QuestRecord["details"] then
					Original_SelectActiveQuest(blockindex)
					return
				end
			end
			for blockindex,blockmatch in pairs(AvailableQuest) do
				if blockmatch == QuestRecord["details"] then
					Original_SelectAvailableQuest(blockindex)
					return
				end
			end
		elseif table.getn(ActiveQuest) == 0 and table.getn(AvailableQuest) == 1 or IsAltKeyDown() and table.getn(AvailableQuest) > 0 then
			LazyPig_SelectAvailableQuest(1, true)
		elseif table.getn(ActiveQuest) == 1 and table.getn(AvailableQuest) == 0 or IsAltKeyDown() and table.getn(ActiveQuest) > 0 then
			local nr = table.getn(ActiveQuest)
			if QuestRecord["progress"] and (nr - QuestRecord["index"]) > 0 then
				--DEFAULT_CHAT_FRAME:AddMessage("--quest dec nr - "..nr.." index - "..QuestRecord["index"])
				QuestRecord["index"] = QuestRecord["index"] + 1
				nr = nr - QuestRecord["index"]
			end
			LazyPig_SelectActiveQuest(nr, true)
		end

	elseif event == "QUEST_PROGRESS" then
		CompleteQuest()
	elseif event == "QUEST_COMPLETE" then
		if GetNumQuestChoices() == 0 then
			GetQuestReward(0)
		elseif GetNumQuestChoices() > 0 and QuestRecord.itemChoice then
			GetQuestReward(QuestRecord.itemChoice)
		end
	end
end

function LazyPig_ItemIsTradeable(bag, item)
	for i = 1, 29, 1 do
		getglobal("LazyPig_Buff_TooltipTextLeft" .. i):SetText("");
	end

	LazyPig_Buff_Tooltip:SetBagItem(bag, item);

	for i = 1, LazyPig_Buff_Tooltip:NumLines(), 1 do
		local text = getglobal("LazyPig_Buff_TooltipTextLeft" .. i):GetText();
		if ( text == ITEM_SOULBOUND ) then
			return nil
		elseif ( text == ITEM_BIND_QUEST ) then
			return nil
		elseif ( text == ITEM_CONJURED ) then
			return nil
		end
	end
	return true
end

function LazyPig_Raid()
	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType == "raid"
end

function LazyPig_Dungeon()
	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType == "party"
end

function LazyPig_BG()
	local inInstance, instanceType = IsInInstance()
	return inInstance and instanceType == "pvp"
end

function LazyPig_SetItemRef_OnEvent(link, text, button)
	if link and string.find(link, "lazypig:") then
		--local count = string.gsub(link,"lazypig:","")
		LazyPig_Command()
	else
		Original_SetItemRef(link, text, button)
	end
end

function LazyPig_GetOption(num)
	local labelString = getglobal(this:GetName().."Text");
	local label = LazyPigMenuStrings[num] or "";
	LazyPigMenuObjects[num] = this

	if num == 00 and LPCONFIG.GREEN == 1
	or num == 01 and LPCONFIG.GREEN == 2
	or num == 02 and LPCONFIG.GREEN == 0
	or num == 03 and LPCONFIG.ZG == 1
	or num == 04 and LPCONFIG.ZG == 2
	or num == 05 and LPCONFIG.ZG == 0
	or num == 06 and LPCONFIG.MC == 1
	or num == 07 and LPCONFIG.MC == 2
	or num == 08 and LPCONFIG.MC == 0
	or num == 09 and LPCONFIG.AQ == 1
	or num == 10 and LPCONFIG.AQ == 2
	or num == 11 and LPCONFIG.AQ == 0
	or num == 12 and LPCONFIG.AQMOUNT == 1
	or num == 13 and LPCONFIG.AQMOUNT == 2
	or num == 14 and LPCONFIG.AQMOUNT == 0
	or num == 15 and LPCONFIG.SAND == 1
	or num == 16 and LPCONFIG.SAND == 2
	or num == 17 and LPCONFIG.SAND == 0
	or num == 18 and LPCONFIG.NAXX == 1
	or num == 19 and LPCONFIG.NAXX == 2
	or num == 20 and LPCONFIG.NAXX == 0
	or num == 21 and LPCONFIG.ROLLMSG
	or num == 22 and LPCONFIG.WORLDDUNGEON
	or num == 23 and LPCONFIG.WORLDRAID
	or num == 24 and LPCONFIG.WORLDBG
	or num == 25 and LPCONFIG.WORLDUNCHECK
	or num == 26 and LPCONFIG.BWL == 1
	or num == 27 and LPCONFIG.BWL == 2
	or num == 28 and LPCONFIG.BWL == 0
	or num == 30 and LPCONFIG.GINV
	or num == 31 and LPCONFIG.FINV
	or num == 32 and LPCONFIG.SINV
	or num == 33 and LPCONFIG.DINV
	or num == 40 and LPCONFIG.FPLATE
	or num == 41 and LPCONFIG.EPLATE
	or num == 42 and LPCONFIG.HPLATE
	or num == 50 and LPCONFIG.EBG
	or num == 51 and LPCONFIG.LBG
	or num == 52 and LPCONFIG.QBG
	or num == 53 and LPCONFIG.RBG
	or num == 54 and LPCONFIG.AQUE
	or num == 55 and LPCONFIG.SBG

	or num == 60 and LPCONFIG.SALVA == 1
	or num == 61 and LPCONFIG.SALVA == 2

	or num == 62 and LPCONFIG.REMOVEMANABUFFS == 1

	or num == 63 and LPCONFIG.ASPECT

	or num == 90 and LPCONFIG.SUMM

	or num == 70 and LPCONFIG.SPAM
	or num == 71 and LPCONFIG.SPAM_UNCOMMON
	or num == 72 and LPCONFIG.SPAM_RARE
	or num == 73 and LPCONFIG.SPAM_LOOT

	or num == 91 and LPCONFIG.LOOT
	or num == 92 and LPCONFIG.RIGHT
	or num == 93 and LPCONFIG.SHIFTSPLIT
	or num == 94 and LPCONFIG.CAM
	or num == 95 and LPCONFIG.SPECIALKEY
	or num == 96 and LPCONFIG.DUEL
	or num == 97 and LPCONFIG.REZ
	or num == 98 and LPCONFIG.GOSSIP
	or num == 100 and LPCONFIG.DISMOUNT
	or num == 101 and LPCONFIG.SPAM
	or num == 102 and LPCONFIG.WHITE_TAILORING == 1
	or num == 103 and LPCONFIG.WHITE_TAILORING == 2
	or num == 104 and LPCONFIG.WHITE_TAILORING == 0
	or num == 105 and LPCONFIG.FOOD_AND_DRINK == 1
	or num == 106 and LPCONFIG.FOOD_AND_DRINK == 2
	or num == 107 and LPCONFIG.FOOD_AND_DRINK == 0
	or num == 108 and LPCONFIG.ES_SHARDS == 1
	or num == 109 and LPCONFIG.ES_SHARDS == 2
	or num == 110 and LPCONFIG.ES_SHARDS == 0

	or nil then
		this:SetChecked(true);
	else
		this:SetChecked(nil);
	end
	labelString:SetText(label);
end

function LazyPig_SetOption(num)
	local checked = this:GetChecked()
	if num == 00 then
		LPCONFIG.GREEN = 1
		if not checked then LPCONFIG.GREEN = nil end
		LazyPigMenuObjects[01]:SetChecked(nil)
		LazyPigMenuObjects[02]:SetChecked(nil)
	elseif num == 01 then
		LPCONFIG.GREEN = 2
		if not checked then LPCONFIG.GREEN = nil end
		LazyPigMenuObjects[00]:SetChecked(nil)
		LazyPigMenuObjects[02]:SetChecked(nil)
	elseif num == 02 then
		LPCONFIG.GREEN = 0
		if not checked then LPCONFIG.GREEN = nil end
		LazyPigMenuObjects[00]:SetChecked(nil)
		LazyPigMenuObjects[01]:SetChecked(nil)
	elseif num == 03 then
		LPCONFIG.ZG = 1
		if not checked then LPCONFIG.ZG = nil end
		LazyPigMenuObjects[04]:SetChecked(nil)
		LazyPigMenuObjects[05]:SetChecked(nil)
	elseif num == 04 then
		LPCONFIG.ZG = 2
		if not checked then LPCONFIG.ZG = nil end
		LazyPigMenuObjects[03]:SetChecked(nil)
		LazyPigMenuObjects[05]:SetChecked(nil)
	elseif num == 05 then
		LPCONFIG.ZG = 0
		if not checked then LPCONFIG.ZG = nil end
		LazyPigMenuObjects[03]:SetChecked(nil)
		LazyPigMenuObjects[04]:SetChecked(nil)
	elseif num == 06 then
		LPCONFIG.MC = 1
		if not checked then LPCONFIG.MC = nil end
		LazyPigMenuObjects[07]:SetChecked(nil)
		LazyPigMenuObjects[08]:SetChecked(nil)
	elseif num == 07 then
		LPCONFIG.MC = 2
		if not checked then LPCONFIG.MC = nil end
		LazyPigMenuObjects[06]:SetChecked(nil)
		LazyPigMenuObjects[08]:SetChecked(nil)
	elseif num == 08 then
		LPCONFIG.MC = 0
		if not checked then LPCONFIG.MC = nil end
		LazyPigMenuObjects[06]:SetChecked(nil)
		LazyPigMenuObjects[07]:SetChecked(nil)
	elseif num == 09 then
		LPCONFIG.AQ = 1
		if not checked then LPCONFIG.AQ = nil end
		LazyPigMenuObjects[10]:SetChecked(nil)
		LazyPigMenuObjects[11]:SetChecked(nil)
	elseif num == 10 then
		LPCONFIG.AQ = 2
		if not checked then LPCONFIG.AQ = nil end
		LazyPigMenuObjects[09]:SetChecked(nil)
		LazyPigMenuObjects[11]:SetChecked(nil)
	elseif num == 11 then
		LPCONFIG.AQ = 0
		if not checked then LPCONFIG.AQ = nil end
		LazyPigMenuObjects[09]:SetChecked(nil)
		LazyPigMenuObjects[10]:SetChecked(nil)
	elseif num == 12 then
		LPCONFIG.AQMOUNT = 1
		if not checked then LPCONFIG.AQMOUNT = nil end
		LazyPigMenuObjects[13]:SetChecked(nil)
		LazyPigMenuObjects[14]:SetChecked(nil)
	elseif num == 13 then
		LPCONFIG.AQMOUNT = 2
		if not checked then LPCONFIG.AQMOUNT = nil end
		LazyPigMenuObjects[12]:SetChecked(nil)
		LazyPigMenuObjects[14]:SetChecked(nil)
	elseif num == 14 then
		LPCONFIG.AQMOUNT = 0
		if not checked then LPCONFIG.AQMOUNT = nil end
		LazyPigMenuObjects[12]:SetChecked(nil)
		LazyPigMenuObjects[13]:SetChecked(nil)
	elseif num == 15 then
		LPCONFIG.SAND = 1
		if not checked then LPCONFIG.SAND = nil end
		LazyPigMenuObjects[16]:SetChecked(nil)
		LazyPigMenuObjects[17]:SetChecked(nil)
	elseif num == 16 then
		LPCONFIG.SAND = 2
		if not checked then LPCONFIG.SAND = nil end
		LazyPigMenuObjects[15]:SetChecked(nil)
		LazyPigMenuObjects[17]:SetChecked(nil)
	elseif num == 17 then
		LPCONFIG.SAND = 0
		if not checked then LPCONFIG.SAND = nil end
		LazyPigMenuObjects[18]:SetChecked(nil)
		LazyPigMenuObjects[19]:SetChecked(nil)
	elseif num == 18 then
		LPCONFIG.NAXX = 1
		if not checked then LPCONFIG.NAXX = nil end
		LazyPigMenuObjects[19]:SetChecked(nil)
		LazyPigMenuObjects[20]:SetChecked(nil)
	elseif num == 19 then
		LPCONFIG.NAXX = 2
		if not checked then LPCONFIG.NAXX = nil end
		LazyPigMenuObjects[18]:SetChecked(nil)
		LazyPigMenuObjects[20]:SetChecked(nil)
	elseif num == 20 then
		LPCONFIG.NAXX = 0
		if not checked then LPCONFIG.NAXX = nil end
		LazyPigMenuObjects[18]:SetChecked(nil)
		LazyPigMenuObjects[19]:SetChecked(nil)
	elseif num == 21 then
		LPCONFIG.ROLLMSG = true
		if not checked then LPCONFIG.ROLLMSG = nil end
	elseif num == 22 then
		LPCONFIG.WORLDDUNGEON = true					--fixed
		if not checked then LPCONFIG.WORLDDUNGEON = nil end
		if LPCONFIG.WORLDDUNGEON or LPCONFIG.WORLDRAID or LPCONFIG.WORLDBG then
			LPCONFIG.WORLDUNCHECK = nil
			LazyPigMenuObjects[25]:SetChecked(nil)
		end
		LazyPig_ZoneCheck()
	elseif num == 23 then
		LPCONFIG.WORLDRAID = true
		if not checked then LPCONFIG.WORLDRAID = nil end
		if LPCONFIG.WORLDDUNGEON or LPCONFIG.WORLDRAID or LPCONFIG.WORLDBG then
			LPCONFIG.WORLDUNCHECK = nil
			LazyPigMenuObjects[25]:SetChecked(nil)
		end
		LazyPig_ZoneCheck()
	elseif num == 24 then
		LPCONFIG.WORLDBG = true
		if not checked then LPCONFIG.WORLDBG = nil end
		if LPCONFIG.WORLDDUNGEON or LPCONFIG.WORLDRAID or LPCONFIG.WORLDBG then
			LPCONFIG.WORLDUNCHECK = nil
			LazyPigMenuObjects[25]:SetChecked(nil)
		end
		LazyPig_ZoneCheck()
	elseif num == 25 then
		LPCONFIG.WORLDUNCHECK = true
		if not checked then
			LPCONFIG.WORLDUNCHECK = nil
		else
			LPCONFIG.WORLDDUNGEON = nil
			LPCONFIG.WORLDRAID = nil
			LPCONFIG.WORLDBG = nil


			LazyPigMenuObjects[22]:SetChecked(nil)
			LazyPigMenuObjects[23]:SetChecked(nil)
			LazyPigMenuObjects[24]:SetChecked(nil)
		end
		LazyPig_ZoneCheck()
	elseif num == 26 then
		LPCONFIG.BWL = 1
		if not checked then LPCONFIG.BWL = nil end
		LazyPigMenuObjects[27]:SetChecked(nil)
		LazyPigMenuObjects[28]:SetChecked(nil)
	elseif num == 27 then
		LPCONFIG.BWL = 2
		if not checked then LPCONFIG.BWL = nil end
		LazyPigMenuObjects[26]:SetChecked(nil)
		LazyPigMenuObjects[28]:SetChecked(nil)
	elseif num == 28 then
		LPCONFIG.BWL = 0
		if not checked then LPCONFIG.BWL = nil end
		LazyPigMenuObjects[26]:SetChecked(nil)
		LazyPigMenuObjects[27]:SetChecked(nil)
	elseif num == 30 then 								--fixed
		LPCONFIG.GINV = true
		if not checked then LPCONFIG.GINV = nil end
	elseif num == 31 then
		LPCONFIG.FINV = true
		if not checked then LPCONFIG.FINV = nil end
	elseif num == 32 then
		LPCONFIG.SINV = true
		if not checked then LPCONFIG.SINV = nil end
	elseif num == 33 then
		LPCONFIG.DINV = true
		if not checked then LPCONFIG.DINV = nil end
	elseif num == 40 then 								--fixed
		LPCONFIG.FPLATE = true
		if not checked then LPCONFIG.FPLATE = nil end
		if LPCONFIG.EPLATE and LPCONFIG.FPLATE then
			LPCONFIG.HPLATE = nil
			LazyPigMenuObjects[42]:SetChecked(nil)
		end
	elseif num == 41 then
		LPCONFIG.EPLATE = true
		if not checked then LPCONFIG.EPLATE = nil end
		if LPCONFIG.EPLATE and LPCONFIG.FPLATE then
			LPCONFIG.HPLATE = nil
			LazyPigMenuObjects[42]:SetChecked(nil)
		end
	elseif num == 42 then
		LPCONFIG.HPLATE = true
		if not checked then
			LPCONFIG.HPLATE = nil
		end
		if LPCONFIG.EPLATE and LPCONFIG.FPLATE then
			LPCONFIG.HPLATE = nil
			LazyPigMenuObjects[42]:SetChecked(nil)
		end
	elseif num == 50 then --fixed
		LPCONFIG.EBG = true
		if not checked then LPCONFIG.EBG = nil end
	elseif num == 51 then
		LPCONFIG.LBG = true
		if not checked then LPCONFIG.LBG = nil end
	elseif num == 52 then
		LPCONFIG.QBG = true
		if not checked then LPCONFIG.QBG = nil end
	elseif num == 53 then
		LPCONFIG.RBG = true
		if not checked then LPCONFIG.RBG = nil end
	elseif num == 54 then
		LPCONFIG.AQUE = true
		if not checked then LPCONFIG.AQUE = nil end
	elseif num == 55 then
		LPCONFIG.SBG  = true
		if not checked then LPCONFIG.SBG  = nil end
	elseif num == 60 then
		LPCONFIG.SALVA = 1
		if not checked then LPCONFIG.SALVA = nil end
		LazyPigMenuObjects[61]:SetChecked(nil)
		LazyPig_CheckSalvation()
	elseif num == 61 then
		LPCONFIG.SALVA = 2
		if not checked then LPCONFIG.SALVA = nil end
		LazyPigMenuObjects[60]:SetChecked(nil)
		LazyPig_CheckSalvation()
	elseif num == 62 then
		LPCONFIG.REMOVEMANABUFFS = 1
		if not checked then LPCONFIG.REMOVEMANABUFFS = nil end
	elseif num == 63 then
		LPCONFIG.ASPECT = true
		if not checked then LPCONFIG.ASPECT = nil end
	elseif num == 70 then --fixed
		LPCONFIG.SPAM = true
		if not checked then LPCONFIG.SPAM = nil end
	elseif num == 71 then
		LPCONFIG.SPAM_UNCOMMON = true
		if not checked then LPCONFIG.SPAM_UNCOMMON = nil end
	elseif num == 72 then
		LPCONFIG.SPAM_RARE	 = true
		if not checked then LPCONFIG.SPAM_RARE	 = nil end
	elseif num == 73 then
		LPCONFIG.SPAM_LOOT	 = true
		if not checked then LPCONFIG.SPAM_LOOT	 = nil end

	elseif num == 90 then
		LPCONFIG.SUMM = true
		if not checked then LPCONFIG.SUMM = nil end
	elseif num == 91 then
		LPCONFIG.LOOT = true
		if not checked then LPCONFIG.LOOT = nil end
	elseif num == 92 then
		LPCONFIG.RIGHT = true
		if not checked then LPCONFIG.RIGHT = nil end
	elseif num == 93 then--fixed
		LPCONFIG.SHIFTSPLIT = true
		if not checked then LPCONFIG.SHIFTSPLIT = nil end
	elseif num == 94 then--fixed
		LPCONFIG.CAM = true
		if not checked then LPCONFIG.CAM = nil end
		if LPCONFIG.CAM then SetCVar("cameraDistanceMax",50) else SetCVar("cameraDistanceMaxFactor",1) SetCVar("cameraDistanceMax",15) end
	elseif num == 95 then
		LPCONFIG.SPECIALKEY = true
		if not checked then LPCONFIG.SPECIALKEY = nil end
	elseif num == 96 then
		LPCONFIG.DUEL = true
		if not checked then LPCONFIG.DUEL = nil end
		if LPCONFIG.DUEL then CancelDuel() end
	elseif num == 97 then
		LPCONFIG.REZ = true
		if not checked then LPCONFIG.REZ = nil end
	elseif num == 98 then
		LPCONFIG.GOSSIP = true
		if not checked then LPCONFIG.GOSSIP = nil end
	elseif num == 100 then
		LPCONFIG.DISMOUNT = true
		if not checked then LPCONFIG.DISMOUNT = nil end
	elseif num == 101 then
		LPCONFIG.SPAM  = true
		if not checked then LPCONFIG.SPAM  = nil end
	elseif num == 102 then
		LPCONFIG.WHITE_TAILORING = 1
		if not checked then LPCONFIG.WHITE_TAILORING = nil end
		LazyPigMenuObjects[103]:SetChecked(nil)
		LazyPigMenuObjects[104]:SetChecked(nil)
	elseif num == 103 then
		LPCONFIG.WHITE_TAILORING = 2
		if not checked then LPCONFIG.WHITE_TAILORING = nil end
		LazyPigMenuObjects[102]:SetChecked(nil)
		LazyPigMenuObjects[104]:SetChecked(nil)
	elseif num == 104 then
		LPCONFIG.WHITE_TAILORING = 0
		if not checked then LPCONFIG.WHITE_TAILORING = nil end
		LazyPigMenuObjects[102]:SetChecked(nil)
		LazyPigMenuObjects[103]:SetChecked(nil)
	elseif num == 105 then
		LPCONFIG.FOOD_AND_DRINK = 1
		if not checked then LPCONFIG.FOOD_AND_DRINK = nil end
		LazyPigMenuObjects[106]:SetChecked(nil)
		LazyPigMenuObjects[107]:SetChecked(nil)
	elseif num == 106 then
		LPCONFIG.FOOD_AND_DRINK = 2
		if not checked then LPCONFIG.FOOD_AND_DRINK = nil end
		LazyPigMenuObjects[105]:SetChecked(nil)
		LazyPigMenuObjects[107]:SetChecked(nil)
	elseif num == 107 then
		LPCONFIG.FOOD_AND_DRINK = 0
		if not checked then LPCONFIG.FOOD_AND_DRINK = nil end
		LazyPigMenuObjects[105]:SetChecked(nil)
		LazyPigMenuObjects[106]:SetChecked(nil)
	elseif num == 108 then
		LPCONFIG.ES_SHARDS = 1
		if not checked then LPCONFIG.ES_SHARDS = nil end
		LazyPigMenuObjects[109]:SetChecked(nil)
		LazyPigMenuObjects[110]:SetChecked(nil)
	elseif num == 109 then
		LPCONFIG.ES_SHARDS = 2
		if not checked then LPCONFIG.ES_SHARDS = nil end
		LazyPigMenuObjects[108]:SetChecked(nil)
		LazyPigMenuObjects[110]:SetChecked(nil)
	elseif num == 110 then
		LPCONFIG.ES_SHARDS = 0
		if not checked then LPCONFIG.ES_SHARDS = nil end
		LazyPigMenuObjects[108]:SetChecked(nil)
		LazyPigMenuObjects[109]:SetChecked(nil)
	else
		--DEFAULT_CHAT_FRAME:AddMessage("DEBUG: No num assigned - "..num)
	end
	--DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Num chosen - "..num)
end

function LazyPig_RollLootOpen()
	for i=1,STATICPOPUP_NUMDIALOGS do
		local frame = getglobal("StaticPopup"..i)
		if frame:IsShown() and frame.which == "CONFIRM_LOOT_ROLL" then
			--DEFAULT_CHAT_FRAME:AddMessage("LazyPig_RollLootOpen - TRUE")
			return true
		end
	end
	return nil
end

function LazyPig_BindLootOpen()
	for i=1,STATICPOPUP_NUMDIALOGS do
		local frame = getglobal("StaticPopup"..i)
		if frame:IsShown() and frame.which == "LOOT_BIND" then
			--DEFAULT_CHAT_FRAME:AddMessage("LazyPig_BindLootOpen - TRUE")
			return true
		end
	end
	return nil
end

function LazyPig_ZoneCheck2()
	LazyPig_ZoneCheck()
end

local process = function(ChatFrame, name)
    for index, value in ChatFrame.channelList do
        if (strupper(name) == strupper(value)) then
            return true
        end
    end
    return nil
end

function LazyPig_ZoneCheck()
	local leavechat = LPCONFIG.WORLDRAID and LazyPig_Raid() or LPCONFIG.WORLDDUNGEON and LazyPig_Dungeon() or LPCONFIG.WORLDBG and LazyPig_BG() or LPCONFIG.WORLDUNCHECK
	for i = 1, NUM_CHAT_WINDOWS do
		local ChatFrame = getglobal("ChatFrame"..i)
		if ChatFrame:IsVisible() and not UnitIsDeadOrGhost("player") then
			local id, name = GetChannelName("world")
			if id > 0 then
				if leavechat then
					if process(ChatFrame, name)  then
						ChatFrame_RemoveChannel(ChatFrame, name)
						channelstatus = true
						UIErrorsFrame:Clear();
						UIErrorsFrame:AddMessage("Leaving World")
					end
					return
				end
			end
			if (LPCONFIG.WORLDRAID or LPCONFIG.WORLDDUNGEON or LPCONFIG.WORLDBG) and not leavechat then
				local framename = ChatFrame:GetName()
				if id == 0 then
					UIErrorsFrame:Clear();
					UIErrorsFrame:AddMessage("Joining World");
					JoinChannelByName("world", nil, ChatFrame:GetID());
				else
					if (not process(ChatFrame, name) or channelstatus) and framename == "ChatFrame1" then
						ChatFrame_AddChannel(ChatFrame, name);
						UIErrorsFrame:Clear();
						UIErrorsFrame:AddMessage("Joining World");
						channelstatus = false
					end
				end
			end
		end
	end
end

function LazyPig_PlayerClass(class, unit)
	if class then
		local unit = unit or "player"
		local _, c = UnitClass(unit)
		if c then
			if string.lower(c) == string.lower(class) then
				return true
			end
		end
	end
	return false
end

local salvationbuffs = {"Spell_Holy_SealOfSalvation", "Spell_Holy_GreaterBlessingofSalvation"}
function LazyPig_CheckSalvation()
	if(LPCONFIG.SALVA == 1 or (LPCONFIG.SALVA == 2 and LazyPig_HasRighteousFury())) then
		local counter = 0
		while GetPlayerBuff(counter) >= 0 do
			local index, untilCancelled = GetPlayerBuff(counter)
			if untilCancelled ~= 1 then
				local texture = GetPlayerBuffTexture(index)
				if texture then  -- Check if texture is not nil
					local i = 1
						while salvationbuffs[i] do
							if string.find(texture, salvationbuffs[i]) then
							CancelPlayerBuff(index);
							UIErrorsFrame:Clear();
							UIErrorsFrame:AddMessage("Salvation Removed");
							return
						end
						i = i + 1
					end
				end
			end
			counter = counter + 1
		end
		return nil
	end
end

function LazyPig_ChatFrame_OnEvent(event)
	if event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_MONEY" then
		local bijou = string.find(arg1 ,"Bijou")
		local coin = string.find(arg1 ,"Coin")
		local idol = string.find(arg1, "Idol")
		local scarab = string.find(arg1, "Scarab")
		local green_roll = greenrolltime > GetTime()
		local check_uncommon = LPCONFIG.SPAM_UNCOMMON and string.find(arg1 ,"1eff00")
		local check_rare = LPCONFIG.SPAM_RARE and string.find(arg1 ,"0070dd")
		local check_loot = LPCONFIG.SPAM_LOOT and (string.find(arg1 ,"9d9d9d") or string.find(arg1 ,"ffffff") or string.find(arg1 ,"Your share of the loot"))
		local check_money = LPCONFIG.SPAM_LOOT and string.find(arg1 ,"Your share of the loot")

		local check1 = string.find(arg1 ,"You")
		local check2 = string.find(arg1 ,"won") or string.find(arg1 ,"receive")
		local check3 = LPCONFIG.AQ and (idol or scarab)
		local check4 = LPCONFIG.ZG and (bijou or coin)
		local check5 = check1 and not check4 and not check3 and not green_roll or check2

		if not check5 and (check_uncommon or check_rare) or check_loot and not check1 or check_money then
			return
		end
	end

	if LPCONFIG.SPAM and arg2 and arg2 ~= GetUnitName("player") and (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_EMOTE") then
		local time = GetTime()
		local index = ChatMessage["INDEX"]

		for blockindex,blockmatch in pairs(ChatMessage[index]) do
			local findmatch1 = (blockmatch + 70) > time --70s delay
			local findmatch2 = blockindex == arg1
			if findmatch1 and findmatch2 then
				return
			end
		end
		ChatMessage[index][arg1] = time
	end

	Original_ChatFrame_OnEvent(event);
end

function ChatSpamClean()
	local time = GetTime()
	local index = ChatMessage["INDEX"]
	local newindex = nil

	if index == 1 then
		newindex = 2
	else
		newindex = 1
	end

	for blockindex,blockmatch in pairs(ChatMessage[index]) do
		if (blockmatch + 70) > time then
			ChatMessage[newindex][blockindex] = ChatMessage[index][blockindex]
		end
	end
	ChatMessage[index] = {}
	ChatMessage["INDEX"] = newindex

	--DEFAULT_CHAT_FRAME:AddMessage("ChatSpamClean")
end

function LazyPig_HasRighteousFury()
	if not LazyPig_PlayerClass("Paladin", "player") then return false end
	local counter = 0
	while GetPlayerBuff(counter) >= 0 do
		local index, untilCancelled = GetPlayerBuff(counter)
		if untilCancelled == 1 then
			local texture = GetPlayerBuffTexture(index)
			if texture and string.find(texture, "Spell_Holy_SealOfFury") then
				return true
			end
		end
		counter = counter + 1
	end
	return false
end
