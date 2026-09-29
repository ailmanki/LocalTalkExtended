class 'GUIVoiceChat' (GUIScript)

kLocalVoiceFontColor         = Client.GetOptionColor("LocalTalkExtended_color", 0x80FF80)
kLocalVoiceTeamOnlyFontColor = Client.GetOptionColor("LocalTalkExtended_color_team",  0xC028C0)
kLocalVoiceCommanderFontColor = Client.GetOptionColor("LocalTalkExtended_color_commander", 0xFFA500)

GUIVoiceChat.kCommanderFontColor = Color(1, 1, 0, 1)
GUIVoiceChat.kMarineFontColor    = Color(147/255, 206/255, 1, 1)
GUIVoiceChat.kAlienFontColor     = Color(207/255, 139/255, 41/255, 1)
GUIVoiceChat.kSpectatorFontColor = Color(1, 1, 1, 1)

local kBackgroundTextureMarine = PrecacheAsset("ui/marine_HUD_presbg.dds")
local kBackgroundTextureAlien  = PrecacheAsset("ui/alien_HUD_presbg.dds")

local kGlobalSpeakerIcon = PrecacheAsset("ui/speaker.dds")

local chat_bars

local function ResetBarForPlayer(pie)
	local bar = pie.voice_chat_bar
	if not bar then return end

	pie.voice_chat_bar = nil
	pie.voice_channel  = nil
	bar.player = Entity.invalidId
	bar.background:SetIsVisible(false)
end

local function PlayerInfoForClient(client)
	for _, pie in ientitylist(Shared.GetEntitiesWithClassname "PlayerInfoEntity") do
		if pie.clientId == client then
			return pie
		end
	end
end

local function ResetBarForClient(client)
	local pie = PlayerInfoForClient(client)
	if pie then
		ResetBarForPlayer(pie)
	end
end

local function IsRelevant(pie)
	return
		Shared.GetEntity(pie.playerId) ~= nil or
		-- Dead team mates can still be heard although irrelevant,
		-- so we need to make an exception for them.
		--
		-- FIXME: When the person followed by a spectator is irrelevant
		-- to our client, then the flickering voice chat bug will appear.
		pie.isSpectator
end

-- The channel we are recording on. The engine reports it a bit late after
-- (re)starting the recording, e.g. when entering or leaving the command
-- structure while holding the key, and it can briefly report Invalid
-- between voice packets, which made the bar flicker.
local record_channel

local function GetVoiceChannel(client)
	local channel
	if Client.GetLocalClientIndex() == client then
		channel = record_channel or Client.GetVoiceChannelForRecording()
	else
		channel = Client.GetVoiceChannelForClient(client)
	end
	return channel or VoiceChannel.Invalid
end

function GUIVoiceChat:Initialize()
	self.visible = true

	local kBackgroundSize   = Vector(GUIScale(250), GUIScale(28), 0)
	local kBackgroundYSpace = GUIScale(4)

	local kVoiceChatIconSize   = Vector(kBackgroundSize.y, kBackgroundSize.y, 0)
	local kVoiceChatIconOffset = Vector(-kBackgroundSize.y * 2, -kVoiceChatIconSize.x / 2, 0)

	local kNameOffsetFromChatIcon = Vector(-kBackgroundSize.y - GUIScale(6), 0, 0)

	local num_chat_bars = math.ceil(Client.GetScreenHeight() / 2 / (kBackgroundYSpace + kBackgroundSize.y))
	chat_bars = table.array(num_chat_bars + 1)

	local bar_position = Vector(-kBackgroundSize.x, 0, 0)
	for i = 1, num_chat_bars do
		local background = GUIManager:CreateGraphicItem()
		background:SetSize(kBackgroundSize)
		background:SetAnchor(GUIItem.Right, GUIItem.Center)
		background:SetLayer(kGUILayerDeathScreen+1)
		background:SetPosition(bar_position)
		background:SetIsVisible(false)

		local icon = GUIManager:CreateGraphicItem()
		icon:SetSize(kVoiceChatIconSize)
		icon:SetAnchor(GUIItem.Right, GUIItem.Center)
		icon:SetPosition(kVoiceChatIconOffset)
		icon:SetTexture(kGlobalSpeakerIcon)
		background:AddChild(icon)

		local name = GUIManager:CreateTextItem()
		name:SetFontName(Fonts.kAgencyFB_Small)
		name:SetAnchor(GUIItem.Right, GUIItem.Center)
		name:SetScale(GetScaledVector())
		name:SetTextAlignmentX(GUIItem.Align_Max)
		name:SetTextAlignmentY(GUIItem.Align_Center)
		name:SetPosition(kNameOffsetFromChatIcon)
		GUIMakeFontScale(name)
		icon:AddChild(name)

		bar_position.y = bar_position.y + kBackgroundYSpace + kBackgroundSize.y

		chat_bars[i] = {background = background, icon = icon, name = name, player = Entity.invalidId}
	end
end

function GUIVoiceChat:Uninitialize()
	for i = 1, #chat_bars do
		GUI.DestroyItem(chat_bars[i].name)
		GUI.DestroyItem(chat_bars[i].background)
		GUI.DestroyItem(chat_bars[i].icon)
	end

	chat_bars = nil
end

function GUIVoiceChat:SetIsVisible(visible)
	self.visible = visible

	for i = 1, #chat_bars do
		local bar = chat_bars[i]
		if bar.player ~= Entity.invalidId then
			bar.background:SetIsVisible(visible)
		end
	end
end

function GUIVoiceChat:GetIsVisible()
	return self.visible
end

-- Keep recording and bars up to date while hidden (e.g. by the help screen)
function GUIVoiceChat:GetShouldUpdate()
	return true
end

function GUIVoiceChat:OnResolutionChanged()
	self:Uninitialize()
	self:Initialize()
end

local function CanUseLocalVoiceChat(player)
	return
		not player:isa "Spectator" or
		player:isa "TeamSpectator" or
		not GetGameInfoEntity():GetGameStarted() and player:GetIsFirstPerson()
end

-- Last states sent to the server
local team_only
local commander_talk
local commander_talk_end_time
local screen_aspect
local commander_hear

-- Keep the commander local talk on a little after recording stops,
-- the last voice packets may still be on their way.
local kCommanderTalkLinger = 0.3

local function SetTeamOnly(on)
	if team_only ~= on then
		team_only = on
		Client.SendNetworkMessage("LocalTalkExtended_teamonly", {on = on}, true)
	end
end

local function SetCommanderTalk(on)
	commander_talk_end_time = nil
	if (commander_talk or false) ~= on then
		commander_talk = on
		Client.SendNetworkMessage("LocalTalkExtended_commander", {on = on}, true)
	end
end

-- The server needs it to know what a commander can see
local function SendScreenAspect()
	local height = Client.GetScreenHeight()
	if height <= 0 then return end

	local aspect = Clamp(Client.GetScreenWidth() / height, 1, 4)
	if not screen_aspect or math.abs(aspect - screen_aspect) >= 0.01 then
		screen_aspect = aspect
		Client.SendNetworkMessage("LocalTalkExtended_aspect", {aspect = aspect}, true)
	end
end

-- The server decides who hears whom
local function SendCommanderHear()
	local on = Client.GetOptionBoolean("LocalTalkExtended_commander_hear", true)
	if commander_hear ~= on then
		commander_hear = on
		Client.SendNetworkMessage("LocalTalkExtended_commander_hear", {on = on}, true)
	end
end

local function StartRecording(self, key, bind, player)
	self.recordKey     = key
	self.recordBind    = bind
	self.recordPlayer  = player:GetId()
	self.recordEndTime = nil
	ResetBarForClient(Client.GetLocalClientIndex())
end

local function RecordGlobal()
	record_channel = VoiceChannel.Global
	Client.VoiceRecordStartGlobal()
end

local function RecordEntity(player)
	record_channel = VoiceChannel.Entity
	Client.VoiceRecordStartEntity(player, Vector.origin)
end

local function StopRecording(self, time)
	Client.VoiceRecordStop()
	record_channel = nil
	self.recordEndTime = nil

	if commander_talk then
		commander_talk_end_time = time + kCommanderTalkLinger
	end
end

-- Returns whether a recording was started
local function StartRecordingForKey(self, key, player)
	local iscomm = player:isa "Commander"
	local isspectator = player:isa "Spectator"

	local bind = iscomm and "VoiceChatCom" or "VoiceChat"
	if GetIsBinding(key, bind) then
		StartRecording(self, key, bind, player)

		SetCommanderTalk(false)
		RecordGlobal()
		return true
	elseif iscomm then
		-- Commander local talk: the team mates within the commander's view hear him.
		-- It is global voice (not positional), since the commander is high above the
		-- map and not even relevant to most players. The server filters the listeners.
		if GetIsBinding(key, "LocalVoiceChatCom") then
			StartRecording(self, key, "LocalVoiceChatCom", player)

			SetCommanderTalk(true)
			RecordGlobal()
			return true
		end
	elseif CanUseLocalVoiceChat(player) then
		if not isspectator and GetIsBinding(key, "LocalVoiceChat") then
			StartRecording(self, key, "LocalVoiceChat", player)

			SetCommanderTalk(false)
			SetTeamOnly(false)
			RecordEntity(player)
			return true
		elseif GetIsBinding(key, "LocalVoiceChatTeam") then
			StartRecording(self, key, "LocalVoiceChatTeam", player)

			SetCommanderTalk(false)
			SetTeamOnly(true)
			RecordEntity(player)
			return true
		end
	end

	return false
end

function GUIVoiceChat:SendKeyEvent(key, down, amount)
	if down then
		local player = Client.GetLocalPlayer()
		if not player or ChatUI_EnteringChatMessage() then return end

		-- Ignore key repeats while holding the key.
		-- A new player entity is handled in Update.
		if self.recordBind and GetIsBinding(key, self.recordBind) then return end

		StartRecordingForKey(self, key, player)
	elseif self.recordBind and GetIsBinding(key, self.recordBind) then
		self.recordBind = nil
		self.recordEndTime = Shared.GetTime() + Client.GetOptionFloat("recordingReleaseDelay", 0.15)
	end
end

-- The player entity changes when dying, evolving, entering or leaving the command
-- structure... Proximity voice is attached to the old entity, and commander local
-- talk would reach the whole team, so restart the recording for the held key.
function GUIVoiceChat:UpdateRecordingPlayer(time)
	if not self.recordBind then return end

	local player = Client.GetLocalPlayer()
	if not player or player:GetId() == self.recordPlayer then return end

	if
		not commander_talk and
		(self.recordBind == "VoiceChat" or self.recordBind == "VoiceChatCom")
	then
		-- Global voice does not care, but the bar color may change
		self.recordPlayer = player:GetId()
		ResetBarForClient(Client.GetLocalClientIndex())
	elseif commander_talk and not player:isa "Commander" and CanUseLocalVoiceChat(player) then
		-- Left the command structure while talking to the team mates within his view:
		-- continue team-only, enemies must not hear the rest.
		StartRecording(self, self.recordKey, self.recordBind, player)

		SetCommanderTalk(false)
		SetTeamOnly(true)
		RecordEntity(player)
	elseif not StartRecordingForKey(self, self.recordKey, player) then
		-- Not allowed anymore
		self.recordBind = nil
		StopRecording(self, time)
	end
end

local voice_teamonly = table.array(100)

local function GetBarColor(pie, channel, local_client, local_team)
	local client = pie.clientId
	local team   = pie.teamNumber

	local teamonly
	local iscommander = pie.isCommander
	if client == local_client then
		if channel == VoiceChannel.Global then
			teamonly = commander_talk
		else
			teamonly = team_only
		end

		-- The PlayerInfoEntity lags behind when entering or leaving the command structure
		local player = Client.GetLocalPlayer()
		if player then
			iscommander = player:isa "Commander"
		end
	else
		teamonly = (team == local_team or local_team == kSpectatorIndex) and voice_teamonly[client]
	end

	if channel ~= VoiceChannel.Global then
		return teamonly and kLocalVoiceTeamOnlyFontColor or kLocalVoiceFontColor
	elseif teamonly and (iscommander or client == local_client) then
		-- Commander local talk
		return kLocalVoiceCommanderFontColor
	end

	return
		iscommander and GUIVoiceChat.kCommanderFontColor or
		team == 1 and GUIVoiceChat.kMarineFontColor or
		team == 2 and GUIVoiceChat.kAlienFontColor or
		GUIVoiceChat.kSpectatorFontColor
end

local function SetBarColor(bar, color)
	bar.name:SetColor(color)
	bar.icon:SetColor(color)
end

Client.HookNetworkMessage("LocalTalkExtended_teamonly_notify", function(msg)
	if (voice_teamonly[msg.client] or false) == msg.on then return end
	voice_teamonly[msg.client] = msg.on

	-- Recolor in place, recreating the bar could move it to another slot
	local pie = PlayerInfoForClient(msg.client)
	local bar = pie and pie.voice_chat_bar
	if not bar then return end

	local local_client = Client.GetLocalClientIndex()
	local player_info  = PlayerInfoForClient(local_client)
	if player_info then
		SetBarColor(bar, GetBarColor(pie, pie.voice_channel, local_client, player_info.teamNumber))
	end
end)

-- Silence after which talking again delays the bar again
local kNewTalkSilence = 0.5

local function ShouldCreateBar(local_client, client, channel, pie, time)
	if channel == VoiceChannel.Invalid or pie.voice_chat_bar then
		return false
	end

	if local_client ~= client then
		if channel ~= VoiceChannel.Global then
			-- Reasoning for IsRelevant (local function defined above) call:
			-- Sadly Spark can not handle VoiceChannel.Entity when the entity referred to is not relevant
			-- to the client.
			-- This is understandable though, since the position is a part of the entity, so a fix
			-- would be an architectural change, something too grand for a small bug like this.
			if not IsRelevant(pie) then
				return false
			end
		elseif not pie.isCommander then
			return true
		end

		-- We need to do this because the team-only network message
		-- arrives after the voice transmission begins.
		-- The commander local talk is global voice, so commanders need it too.
		--
		-- They may have stopped talking before their bar got created,
		-- or all bars may have been occupied.
		local heard_time = pie.voice_heard_time
		pie.voice_heard_time = time
		if heard_time and time - heard_time > kNewTalkSilence then
			pie.voice_chat_bar_time = nil
		end

		local bar_time = pie.voice_chat_bar_time
		if not bar_time then
			pie.voice_chat_bar_time = time + 0.15
			return false
		else
			return bar_time <= time
		end
	end

	return true
end

function GUIVoiceChat:Update(delta_time)
	PROFILE("GUIVoiceChat:Update")

	local time = Shared.GetTime()

	if self.recordEndTime and self.recordEndTime < time then
		StopRecording(self, time)
	end

	self:UpdateRecordingPlayer(time)

	if commander_talk_end_time and commander_talk_end_time < time then
		SetCommanderTalk(false)
	end

	SendScreenAspect()
	SendCommanderHear()

	local local_client = Client.GetLocalClientIndex()
	local player_info = PlayerInfoForClient(local_client)
	if not player_info then return end
	local local_team = player_info.teamNumber

	for i = 1, #chat_bars do
		local bar = chat_bars[i]
		local id = bar.player
		if id ~= Entity.invalidId then
			local pie = Shared.GetEntity(id)
			if pie then
				local channel = GetVoiceChannel(pie.clientId)
				if channel ~= pie.voice_channel then
					-- If it's proximity or a commander, we also need the network
					-- message to tell us what kind of local voice chat it is,
					-- so we delay the bar again (see ShouldCreateBar).
					pie.voice_chat_bar_time = nil
					ResetBarForPlayer(pie)
				end
			else
				bar.player = Entity.invalidId
				bar.background:SetIsVisible(false)
			end
		end
	end

	for _, pie in ientitylist(Shared.GetEntitiesWithClassname "PlayerInfoEntity") do
		local client  = pie.clientId
		local channel = GetVoiceChannel(client)

		if ShouldCreateBar(local_client, client, channel, pie, time) then
			local bar
			for i = 1, #chat_bars do
				if chat_bars[i].player == Entity.invalidId then
					bar = chat_bars[i]
					break
				end
			end
			-- All bars may be occupied
			if bar then
				local team = pie.teamNumber

				bar.name:SetText(pie.playerName)
				SetBarColor(bar, GetBarColor(pie, channel, local_client, local_team))

				bar.background:SetTexture(team == 2 and kBackgroundTextureAlien or kBackgroundTextureMarine)
				bar.background:SetColor(team ~= 1 and team ~= 2 and Color(1, 200/255, 150/255, 1) or Color(1, 1, 1, 1))
				bar.background:SetIsVisible(self.visible)

				pie.voice_chat_bar = bar
				bar.player = pie:GetId()

				pie.voice_channel = channel
			end
		end
	end
end

-- Is this correct? No idea, but I can't test the game to fix it properly
function GUIVoiceChat:Reload() end
