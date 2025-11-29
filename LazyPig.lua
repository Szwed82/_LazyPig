local _G = _G or getfenv(0)

-- Default SavedVariables
LPCONFIG = {}
LPCONFIG.DISMOUNT = false           -- Auto Dismount
LPCONFIG.GINV = false               -- Auto accept invites from guild members
LPCONFIG.FINV = false               -- Auto accept invites from friends
LPCONFIG.SINV = false               -- Auto accept invites from strangers
LPCONFIG.SUMM = false               -- Auto accept summons
LPCONFIG.LOOT = false               -- Position loot frame at cursor
LPCONFIG.WORLDDUNGEON = false       -- Mute Wolrd chat while in dungeons
LPCONFIG.WORLDRAID = false          -- Mute Wolrd chat while in raid
LPCONFIG.WORLDBG = false            -- Mute Wolrd chat while in battleground
LPCONFIG.WORLDUNCHECK = false       -- Mute Wolrd chat always
LPCONFIG.SPAM = false               -- Hide players spam messages
LPCONFIG.SPAM_UNCOMMON = false      -- Hide green items roll messages
LPCONFIG.SPAM_RARE = false          -- Hide blue items roll messages
LPCONFIG.SPAM_EPIC = false          -- Hide epic items roll messages
LPCONFIG.SPAM_LOOT = false			-- Hide poor and white items loot messages
LPCONFIG.REZ = false                -- Auto accept resurrection while in raid, dungeon or bg if resurrecter is out of combat
LPCONFIG.SALVA = nil                -- [number or nil] Autoremove Blessing of Salvation

local OriginalLootFrame_OnEvent = LootFrame_OnEvent;
local OriginalLootFrame_Update = LootFrame_Update;
local Original_ChatFrame_OnEvent = ChatFrame_OnEvent;
local Original_StaticPopup_OnShow = StaticPopup_OnShow;

local delayaction = 0
local tradedelay = 0

local player_summon_confirm = nil
local player_summon_message = nil
local channelstatus = nil

local ScheduleFunction = {}
local ChatMessage = {{}, {}, INDEX = 1}

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
	LootFrame_OnEvent = LazyPig_LootFrame_OnEvent;
	LootFrame_Update = LazyPig_LootFrame_Update;
	ChatFrame_OnEvent = LazyPig_ChatFrame_OnEvent;
	StaticPopup_OnShow = LazyPig_StaticPopup_OnShow;
	
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
	this:RegisterEvent("UI_ERROR_MESSAGE")
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
	if event == "ADDON_LOADED" and arg1 == "LazyPig" then
		this:UnregisterEvent("ADDON_LOADED")
		local title = GetAddOnMetadata("LazyPig", "Title")
		local version = GetAddOnMetadata("LazyPig", "Version")
		DEFAULT_CHAT_FRAME:AddMessage(title.." v"..version.."|cffffffff".." loaded, type".."|cff00eeee".." /lp".."|cffffffff for options")

	elseif event == "PLAYER_LOGIN" then
		LazyPig_CreateOptionsFrame()
		LazyPig_CheckSalvation();
		LazyPig_AutoSummon();
		ScheduleFunctionLaunch(LazyPig_ZoneCheck, 6);

		if LPCONFIG.LOOT then
			UIPanelWindows["LootFrame"] = nil
		end

	elseif event == "PLAYER_AURAS_CHANGED" then
		LazyPig_CheckSalvation()

	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UNGHOST" then
		ScheduleFunctionLaunch(LazyPig_ZoneCheck, 5)

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
		end
	
	elseif event == "CHAT_MSG_SYSTEM" then
		if arg1 == CLEARED_DND or arg1 == CLEARED_AFK then
			afk_active = false
			Check_Bg_Status()

		elseif string.find(arg1, string.sub(MARKED_DND, 1, string.len(MARKED_DND) -3)) then
			afk_active = false
		end

	elseif event == "CONFIRM_SUMMON" then
		LazyPig_AutoSummon();

	elseif event == "PARTY_INVITE_REQUEST" then
		local check1 = not LPCONFIG.DINV or LPCONFIG.DINV and not LazyPig_BG()
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
		local check_epic = LPCONFIG.SPAM_EPIC and string.find(arg1 ,"a335ee")
		local check_loot = LPCONFIG.SPAM_LOOT and (string.find(arg1 ,"9d9d9d") or string.find(arg1 ,"ffffff") or string.find(arg1 ,"Your share of the loot"))
		local check_money = LPCONFIG.SPAM_LOOT and string.find(arg1 ,"Your share of the loot")

		local check1 = string.find(arg1 ,"You")
		local check2 = string.find(arg1 ,"won") or string.find(arg1 ,"receive")
		local check3 = LPCONFIG.AQ and (idol or scarab)
		local check4 = LPCONFIG.ZG and (bijou or coin)
		local check5 = check1 and not check4 and not check3 and not green_roll or check2

		if not check5 and (check_uncommon or check_rare or check_epic) or check_loot and not check1 or check_money then
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
