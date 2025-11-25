local _G = _G or getfenv(0)

-- Default SavedVariables
LPCONFIG = {}
LPCONFIG.DISMOUNT = true           -- Auto Dismount
LPCONFIG.AUTOSTANCE = true         -- Auto Stance
LPCONFIG.CAM = false               -- Extended camera distance
LPCONFIG.GINV = true               -- Auto accept invites from guild members
LPCONFIG.FINV = true               -- Auto accept invites from friends
LPCONFIG.SINV = false              -- Auto accept invites from strangers
LPCONFIG.DINV = false               -- Disable auto accept invite whiel in bg or in bg queue
LPCONFIG.SUMM = false              -- Auto accept summons
LPCONFIG.EBG = false                -- Auto join battleground
LPCONFIG.LBG = false                -- Auto leave battleground
LPCONFIG.QBG = false                -- Auto queue battleground
LPCONFIG.RBG = false                -- Auto release spirit in battleground
LPCONFIG.SBG = false               -- Auto decline quest sharing while in battleground
LPCONFIG.AQUE = false              -- Announce when queueing for battleground as party leader
LPCONFIG.LOOT = false              -- Position loot frame at cursor
LPCONFIG.RIGHT = false              -- Improved right click
LPCONFIG.GREEN = nil               -- [number or nil] Auto roll on green items
LPCONFIG.ZG = nil                  -- [number or nil] ZG coins/bijou auto roll
LPCONFIG.MC = nil                  -- [number or nil] MC mats auto roll
LPCONFIG.AQ = nil                  -- [number or nil] AQ scarabs/idols auto roll
LPCONFIG.SAND = nil                -- [number or nil] Corrupted sand auto roll
LPCONFIG.ES_SHARDS = nil           -- [number or nil] Dream Shrads auto roll
LPCONFIG.ROLLMSG = false           -- Lazy Pig Auto Roll Messages
LPCONFIG.WORLDDUNGEON = false      -- Mute Wolrd chat while in dungeons
LPCONFIG.WORLDRAID = false         -- Mute Wolrd chat while in raid
LPCONFIG.WORLDBG = false           -- Mute Wolrd chat while in battleground
LPCONFIG.WORLDUNCHECK = false      -- Mute Wolrd chat always
LPCONFIG.SPAM = false              -- Hide players spam messages
LPCONFIG.SPAM_UNCOMMON = false     -- Hide green items roll messages
LPCONFIG.SPAM_RARE = false         -- Hide blue items roll messages
LPCONFIG.SHIFTSPLIT = false        -- Improved stack splitting with shift
LPCONFIG.REZ = false               -- Auto accept resurrection while in raid, dungeon or bg if resurrecter is out of combat
LPCONFIG.GOSSIP = false             -- Auto proccess gossip
LPCONFIG.SALVA = nil               -- [number or nil] Autoremove Blessing of Salvation

local Original_SelectGossipActiveQuest = SelectGossipActiveQuest;
local Original_SelectGossipAvailableQuest = SelectGossipAvailableQuest;
local Original_SelectActiveQuest = SelectActiveQuest;
local Original_SelectAvailableQuest = SelectAvailableQuest;
local OriginalLootFrame_OnEvent = LootFrame_OnEvent;
local OriginalLootFrame_Update = LootFrame_Update;
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
local channelstatus = nil
local battleframe = nil

local ScheduleFunction = {}
local QuestRecord = {}
local ActiveQuest = {}
local AvailableQuest = {}
local ChatMessage = {{}, {}, INDEX = 1}
local GossipOptions = {}

local function twipe(t)
	if type(t) == "table" then
		for i = table.getn(t), 1, -1 do
			table.remove(t, i)
		end
		for k in next, t do
			t[k] = nil
		end
		return t
	else
		return {}
	end
end

local function strsplit(str, delimiter, container)
	local result = twipe(container)
	local from = 1
	local delim_from, delim_to = string.find(str, delimiter, from, true)
	while delim_from do
		table.insert(result, string.sub(str, from, delim_from - 1))
		from = delim_to + 1
		delim_from, delim_to = string.find(str, delimiter, from, true)
	end
	table.insert(result, string.sub(str, from))
	return result
end

function LazyPig_OnLoad()
	SelectGossipActiveQuest = LazyPig_SelectGossipActiveQuest;
	SelectGossipAvailableQuest = LazyPig_SelectGossipAvailableQuest;
	SelectActiveQuest = LazyPig_SelectActiveQuest;
	SelectAvailableQuest = LazyPig_SelectAvailableQuest;
	LootFrame_OnEvent = LazyPig_LootFrame_OnEvent;
	LootFrame_Update = LazyPig_LootFrame_Update;
	ChatFrame_OnEvent = LazyPig_ChatFrame_OnEvent;
	StaticPopup_OnShow = LazyPig_StaticPopup_OnShow;
	QuestRewardItem_OnClick = LazyPig_QuestRewardItem_OnClick

	SLASH_LAZYPIG1 = "/lp";
	SLASH_LAZYPIG2 = "/lazypig";
	SlashCmdList["LAZYPIG"] = LazyPig_Command;

	this:RegisterEvent("ADDON_LOADED")
	this:RegisterEvent("PLAYER_LOGIN")
	this:RegisterEvent("CHAT_MSG")
	this:RegisterEvent("CHAT_MSG_SYSTEM")
	this:RegisterEvent("PARTY_INVITE_REQUEST")
	this:RegisterEvent("CONFIRM_SUMMON")
	this:RegisterEvent("RESURRECT_REQUEST")
	this:RegisterEvent("GOSSIP_SHOW")
	this:RegisterEvent("QUEST_GREETING")
	this:RegisterEvent("UI_ERROR_MESSAGE")
	this:RegisterEvent("QUEST_PROGRESS")
	this:RegisterEvent("QUEST_COMPLETE")
	this:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	this:RegisterEvent("PLAYER_UNGHOST")
	this:RegisterEvent("PLAYER_AURAS_CHANGED")
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

local ErrorDismountAndForm = {
	[SPELL_FAILED_NOT_MOUNTED] = 1,                  -- "You are mounted"
	[ERR_ATTACK_MOUNTED] = 1,                        -- "Can't attack while mounted."
	[ERR_TAXIPLAYERALREADYMOUNTED] = 1,              -- "You are already mounted! Dismount first."
	[ERR_MOUNT_SHAPESHIFTED] = 1,                    -- "You can't mount while shapeshifted!"
	[SPELL_FAILED_NOT_SHAPESHIFT] = 1,               -- "You are in shapeshift form"
	[SPELL_FAILED_NO_ITEMS_WHILE_SHAPESHIFTED] = 1,  -- "Can't use items while shapeshifted"
	[SPELL_NOT_SHAPESHIFTED] = 1,                    -- "Can't do that while shapeshifted."
	[SPELL_NOT_SHAPESHIFTED_NOSPACE] = 1,            -- "Can't do that while shapeshifted."
	[ERR_TAXIPLAYERSHAPESHIFTED] = 1,                -- "You can't take a taxi while shapeshifted!"
	[ERR_CANT_INTERACT_SHAPESHIFTED] = 1,            -- "Can't speak while shapeshifted."
	[ERR_NO_ITEMS_WHILE_SHAPESHIFTED] = 1,           -- "Can't use items while shapeshifted."
	[ERR_NOT_WHILE_SHAPESHIFTED] = 1                 -- "You can't do that while shapeshifted."
}
local ErrorStanding = {
	[ERR_TAXINOTSTANDING] = 1,                       -- "You need to be standing to go anywhere."
	[ERR_LOOT_NOTSTANDING] = 1,                      -- "You need to be standing up to loot something!"
	[ERR_CANTATTACK_NOTSTANDING] = 1,                -- "You have to be standing to attack anything!"
	[SPELL_FAILED_NOT_STANDING] = 1                  -- "You must be standing to do that"
}

function LazyPig_OnEvent(event)
	if event == "ADDON_LOADED" and arg1 == "_LazyPig" then
		this:UnregisterEvent("ADDON_LOADED")
		local title = GetAddOnMetadata("_LazyPig", "Title")
		local version = GetAddOnMetadata("_LazyPig", "Version")
		DEFAULT_CHAT_FRAME:AddMessage(title.." v"..version.."|cffffffff".." loaded, type".."|cff00eeee".." /lp".."|cffffffff for options")

	elseif event == "PLAYER_LOGIN" then
		LazyPig_CreateOptionsFrame()

		LazyPig_CheckSalvation();
		LazyPig_AutoSummon();
		ScheduleFunctionLaunch(LazyPig_ZoneCheck, 6);

		if LPCONFIG.LOOT then
			UIPanelWindows["LootFrame"] = nil
		end
		QuestRecord["index"] = 0

	elseif LPCONFIG.SALVA and (event == "PLAYER_AURAS_CHANGED") then
		LazyPig_CheckSalvation()

	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UNGHOST" then
		ScheduleFunctionLaunch(LazyPig_ZoneCheck, 5)
		--DEFAULT_CHAT_FRAME:AddMessage(event);

	elseif event == "UI_ERROR_MESSAGE" then
		if ErrorStanding[arg1] then
			SitOrStand()
		else
			if LPCONFIG.DISMOUNT then
				if ErrorDismountAndForm[arg1] then
					UIErrorsFrame:Clear()
					LazyPig_Dismount()
					LazyPig_CancelShapeshiftBuff()
				end
			end
			if LPCONFIG.AUTOSTANCE then
				LazyPig_AutoStance(arg1)
			end
		end

	elseif event == "CHAT_MSG_SYSTEM" then
		if arg1 == CLEARED_DND or arg1 == CLEARED_AFK then
			afk_active = false

		elseif string.find(arg1, string.sub(MARKED_DND, 1, string.len(MARKED_DND) -3)) then
			afk_active = false

		elseif LPCONFIG.AQUE and string.find(arg1 ,"Queued") and UnitIsPartyLeader("player") then
			if UnitInRaid("player") then
				SendChatMessage(arg1, "RAID");
			elseif GetNumPartyMembers() > 1 then
				SendChatMessage(arg1, "PARTY");
			end

		elseif string.find(arg1 ,"completed.") then
			LazyPig_FixQuest(arg1)
			QuestRecord["progress"] = nil

		end

	elseif event == "QUEST_GREETING" then
		ActiveQuest = twipe(ActiveQuest)
		AvailableQuest = twipe(AvailableQuest)
		for i=1, GetNumActiveQuests() do
			table.insert(ActiveQuest, i, GetActiveTitle(i).." "..GetActiveLevel(i))
		end
		for i=1, GetNumAvailableQuests() do
			table.insert(AvailableQuest, i, GetAvailableTitle(i).." "..GetAvailableLevel(i))
		end

		LazyPig_ReplyQuest(event);

		--DEFAULT_CHAT_FRAME:AddMessage("active_: "..table.getn(ActiveQuest))
		--DEFAULT_CHAT_FRAME:AddMessage("available_: "..table.getn(AvailableQuest))

	elseif event == "GOSSIP_SHOW" then
		GossipOptions = twipe(GossipOptions)
		local dsc = nil
		local gossipnr = nil
		local gossipbreak = nil
		local processgossip = LPCONFIG.GOSSIP and not IsShiftKeyDown()

		dsc,GossipOptions[1],_,GossipOptions[2],_,GossipOptions[3],_,GossipOptions[4],_,GossipOptions[5] = GetGossipOptions()

		ActiveQuest = LazyPig_ProcessQuests(GetGossipActiveQuests())
		AvailableQuest = LazyPig_ProcessQuests(GetGossipAvailableQuests())

		if QuestRecord["qnpc"] ~= UnitName("npc") then
			QuestRecord["index"] = 0
			QuestRecord["qnpc"] = UnitName("npc")
		end

		if table.getn(AvailableQuest) ~= 0 or table.getn(ActiveQuest) ~= 0 then
			gossipbreak = true
		end

		--DEFAULT_CHAT_FRAME:AddMessage("gossip: "..table.getn(GossipOptions))
		--DEFAULT_CHAT_FRAME:AddMessage("active: "..table.getn(ActiveQuest))
		--DEFAULT_CHAT_FRAME:AddMessage("available: "..table.getn(AvailableQuest))

		for i=1, 5 do
			if not GossipOptions[i] then
				break
			end
			if GossipOptions[i] == "binder" then
				local bind = GetBindLocation();
				if not (bind == GetSubZoneText() or bind == GetZoneText() or bind == GetRealZoneText() or bind == GetMinimapZoneText()) then
					gossipbreak = true
				end
			elseif gossipnr then
				gossipbreak = true
			elseif GossipOptions[i] == "trainer" and dsc == "Reset my talents." then
				gossipbreak = false
			elseif ((GossipOptions[i] == "trainer" and processgossip)
					or (GossipOptions[i] == "vendor" and processgossip)
					or (GossipOptions[i] == "gossip" and processgossip)
					or (GossipOptions[i] == "banker" and string.find(dsc, "^I would like to check my deposit box.") and processgossip)
					or (GossipOptions[i] == "petition" and (IsAltKeyDown()or IsShiftKeyDown() or string.find(dsc, "Teleport me to the Molten Core")) and processgossip))
				then
				gossipnr = i
			elseif GossipOptions[i] == "taxi" and processgossip then
				gossipnr = i
				LazyPig_Dismount();
			end
		end

		if not gossipbreak and gossipnr then
			SelectGossipOption(gossipnr);
		else
			LazyPig_ReplyQuest(event);
		end

	elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
		LazyPig_ReplyQuest(event);

	elseif event == "CONFIRM_SUMMON" then
		LazyPig_AutoSummon();

	elseif event == "PARTY_INVITE_REQUEST" then
		local check1 = not LPCONFIG.DINV or LPCONFIG.DINV
		local check2 = LPCONFIG.GINV and IsGuildMate(arg1) or LPCONFIG.FINV and IsFriend(arg1) or not IsGuildMate(arg1) and not IsFriend(arg1) and LPCONFIG.SINV
		if check1 and check2 then
			AcceptGroupInvite();
		end
	elseif event == "RESURRECT_REQUEST" and LPCONFIG.REZ then
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
			local button = _G["LootButton"..index];
			if  button:IsVisible() then
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
	if event == "LOOT_SLOT_CLEARED" then
		LazyPig_ItemUnderCursor();
	end
end

function LazyPig_LootFrame_Update()
	OriginalLootFrame_Update();
	LazyPig_ItemUnderCursor();
end

function IsFriend(name)
	for i = 1, GetNumFriends() do
		if GetFriendInfo(i) == name then
			return true
		end
	end
	return nil
end

function IsGuildMate(name)
	if IsInGuild() then
		for i=1, GetNumGuildMembers() do
			if strlower(GetGuildRosterInfo(i)) == strlower(name) then
			  return true
			end
		end
	end
	return nil
end

function AcceptGroupInvite()
	AcceptGroup();
	StaticPopup_Hide("PARTY_INVITE");
	UIErrorsFrame:AddMessage("Group Auto Accept");
end

function LazyPig_AutoSummon()
	if not LPCONFIG.SUMM then
		return
	end
	local keyenter = IsAltKeyDown() and IsControlKeyDown() and GetTime() > delayaction and GetTime() > (tradedelay + 0.5)
	local expireTime = GetSummonConfirmTimeLeft()
	if not player_summon_message and expireTime ~= 0 then
		player_summon_message = true
		player_summon_confirm = true
		DEFAULT_CHAT_FRAME:AddMessage("LazyPig: Auto Summon in "..math.floor(expireTime).."s", 1.0, 1.0, 0.0);

	elseif expireTime <= 3 or keyenter then
		player_summon_confirm = false
		player_summon_message = false

		for i=1,STATICPOPUP_NUMDIALOGS do
			local frame = _G["StaticPopup"..i]
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

local COLOR_COPPER = "|cffeda55f"
local COLOR_SILVER = "|cffc7c7cf"
local COLOR_GOLD = "|cffffd700"

local function MoneyToString(money)
	if not money then
		return ""
	end
	local gold = floor(abs(money / 10000))
	local silver = floor(abs(mod(money / 100, 100)))
	local copper = floor(abs(mod(money, 100)))
	return COLOR_GOLD..gold.."g|r "..COLOR_SILVER..silver.."s|r "..COLOR_COPPER..copper.."c|r"
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

-- taken from ShaguTweaks
-- https://github.com/shagu/ShaguTweaks/blob/master/mods/auto-dismount.lua
local dismountStrings = {
	-- enUS
	"^Increases speed by (.+)%%",
	-- turtle-wow
	"speed based on", "Slow and steady...", "Riding",
}

function LazyPig_Dismount()
	local buff = 0
	while GetPlayerBuff(buff) >= 0 do
		LazyPig_Buff_Tooltip:SetPlayerBuff(GetPlayerBuff(buff))
		local desc = LazyPig_Buff_TooltipTextLeft2:GetText()
		if desc then
			for _, str in pairs(dismountStrings) do
				if string.find(desc, str) then
					CancelPlayerBuff(buff)
					return
				end
			end
		end
		buff = buff + 1
	end
end

local stanceString = string.gsub(SPELL_FAILED_ONLY_SHAPESHIFT, "%%s", "(.+)")
local stances = {}

function LazyPig_AutoStance(msg)
	for stancesStr in string.gfind(msg, stanceString) do
		for _, st in pairs(strsplit(stancesStr, ",", stances)) do
			CastSpellByName((string.gsub(st, "^%s*(.-)%s*$", "%1")))
		end
	end
end

function LazyPig_ItemIsTradeable(bag, item)
	for i = 1, 29, 1 do
		_G["LazyPig_Buff_TooltipTextLeft" .. i]:SetText("");
	end

	LazyPig_Buff_Tooltip:SetBagItem(bag, item);

	for i = 1, LazyPig_Buff_Tooltip:NumLines(), 1 do
		local text = _G["LazyPig_Buff_TooltipTextLeft" .. i]:GetText();
		if  text == ITEM_SOULBOUND  then
			return nil
		elseif  text == ITEM_BIND_QUEST  then
			return nil
		elseif  text == ITEM_CONJURED  then
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

function LazyPig_DecodeItemLink(link)
	if link then
		local found, _, id, name = string.find(link, "item:(%d+):.*%[(.*)%]")
		if found then
			id = tonumber(id)
			return name, id
		end
	end
	return nil
end

function LazyPig_BindLootOpen()
	for i=1,STATICPOPUP_NUMDIALOGS do
		local frame = _G["StaticPopup"..i]
		if frame:IsShown() and frame.which == "LOOT_BIND" then
			--DEFAULT_CHAT_FRAME:AddMessage("LazyPig_BindLootOpen - TRUE")
			return true
		end
	end
	return nil
end

local process = function(ChatFrame, name)
    for index, value in ChatFrame.channelList do
        if strupper(name) == strupper(value) then
            return true
        end
    end
    return nil
end

function LazyPig_ZoneCheck()
	local leavechat = LPCONFIG.WORLDRAID and LazyPig_Raid() or LPCONFIG.WORLDDUNGEON and LazyPig_Dungeon() or LPCONFIG.WORLDBG and LazyPig_BG() or LPCONFIG.WORLDUNCHECK
	for i = 1, NUM_CHAT_WINDOWS do
		local ChatFrame = _G["ChatFrame"..i]
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

function LazyPig_CancelShapeshiftBuff()
	for i = 1, GetNumShapeshiftForms() do
		local _, _, isActive = GetShapeshiftFormInfo(i);
		if isActive and LazyPig_PlayerClass("Druid", "player") then
			CastShapeshiftForm(i)
			return
		end
	end
end

local salvationbuffs = {
	"Spell_Holy_SealOfSalvation",
	"Spell_Holy_GreaterBlessingofSalvation"
}
function LazyPig_CheckSalvation()
	if not LPCONFIG.SALVA then
		return
	end
	if not (LPCONFIG.SALVA == 1 or (LPCONFIG.SALVA == 2 and LazyPig_HasRighteousFury())) then
		return
	end
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

	if LPCONFIG.SPAM and arg2 and arg2 ~= GetUnitName("player") and (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_EMOTE" and not (IsGuildMate(arg2) or IsFriend(arg2))) then
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

    -- suppress BigWigs spam
	if LPCONFIG.SPAM and event == "CHAT_MSG_SAY" and string.find(arg1 or "" ,"^Casted %u[%a%s]+ on %u[%a%s]+") then
        return
    end

	-- supress #showtooltip spam
	if string.find(arg1 or "" , "^#showtooltip") then
		return
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
	ChatMessage[index] = twipe(ChatMessage[index])
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
