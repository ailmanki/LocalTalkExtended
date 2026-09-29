local GetOwner = Server.GetOwner

-- All indexed by ServerClient:GetId()
local voice_teamonly = table.array(100)
local commander_talk = table.array(100)
local commander_hear = table.array(100)
local screen_aspect  = table.array(100)
-- notified[listener][speaker] = team-only state last sent to listener about speaker
local notified       = table.array(100)

Server.HookNetworkMessage("LocalTalkExtended_teamonly", function(client, msg)
	voice_teamonly[client:GetId()] = msg.on
end)

Server.HookNetworkMessage("LocalTalkExtended_commander", function(client, msg)
	commander_talk[client:GetId()] = msg.on
end)

Server.HookNetworkMessage("LocalTalkExtended_commander_hear", function(client, msg)
	commander_hear[client:GetId()] = msg.on
end)

Server.HookNetworkMessage("LocalTalkExtended_aspect", function(client, msg)
	screen_aspect[client:GetId()] = Clamp(msg.aspect, 1, 4)
end)

if not Shine then
	Shared.Message "\n\nPlease install Shine Administration to use Local Talk Extended\n\n"
	return
end

-- Tells the listener whether to color the speaker's bar as team-only.
-- Only sent when it changes, since we may be asked for every voice packet.
local function Notify(listener_client, speaker_client, on)
	if listener_client:GetIsVirtual() then return end

	local listener_id = listener_client:GetId()
	local speaker_id  = speaker_client:GetId()

	local sent = notified[listener_id]
	if not sent then
		sent = {}
		notified[listener_id] = sent
	end

	if (sent[speaker_id] or false) == on then return end
	sent[speaker_id] = on

	Server.SendNetworkMessage(
		listener_client,
		"LocalTalkExtended_teamonly_notify",
		{client = speaker_id, on = on},
		true
	)
end

-- The commander camera sits at the commander's origin, uses his view angles,
-- and Commander.kFov is the horizontal FOV of a 4:3 screen. Wider screens see
-- more on the sides (see GetScreenAdjustedFov in Client.lua).
local kDefaultAspect = 16 / 9
-- Be a bit generous: the server lags behind the commander's scrolling,
-- and players may only be partially on screen.
local kViewMargin = 1.1

local function IsPointInView(coords, tan_h, tan_v, point)
	local offset = point - coords.origin
	local depth  = offset:DotProduct(coords.zAxis)

	return
		depth > 0 and
		math.abs(offset:DotProduct(coords.xAxis)) <= depth * tan_h and
		math.abs(offset:DotProduct(coords.yAxis)) <= depth * tan_v
end

-- Spectators following a player do not move themselves
local function GetViewedPlayer(player)
	if player:isa "Spectator" then
		local client = GetOwner(player)
		local target = client and client:GetSpectatingPlayer()
		if target then
			return target
		end
	end
	return player
end

local function IsPlayerInCommanderView(commander, commander_client, player)
	local coords = commander:GetViewCoords()
	local tan_v  = math.tan(math.rad(commander:GetFov()) / 2) / (4 / 3) * kViewMargin
	local tan_h  = tan_v * (screen_aspect[commander_client:GetId()] or kDefaultAspect)

	player = GetViewedPlayer(player)

	return
		IsPointInView(coords, tan_h, tan_v, player:GetOrigin()) or
		IsPointInView(coords, tan_h, tan_v, player:GetEyePos())
end

Shine.Hook.Add("CanPlayerHearPlayer", "LocalTalkExtended",
function(gamerules, listener, speaker, channel)
	-- Also avoids sending teamonly_notify network message!
	if listener == speaker then return true end

	local listener_client = GetOwner(listener)
	local speaker_client = GetOwner(speaker)
	if not listener_client or not speaker_client then return end

	local enabled, basecommands = Shine:IsExtensionEnabled "basecommands"
	if not enabled then
		basecommands = nil
	end

	if
		basecommands and basecommands:IsClientGagged(speaker_client) or
		listener:GetClientMuted(speaker_client:GetId())
	then
		return false
	end

	local speaker_team  = speaker:GetTeamNumber()
	local listener_team = listener:GetTeamNumber()

	-- The channel is nil when asked about alerts, and Global when asked about
	-- private team sounds, so only filter while the commander uses his local talk.
	if channel == VoiceChannel.Global then
		if commander_talk[speaker_client:GetId()] then
			-- Commander local talk is global voice (not positional),
			-- but only the team mates within his view can hear it.
			-- If he just left the command structure, nobody hears the rest
			-- until his client catches up.
			if
				speaker:isa "Commander" and (
					speaker_team == listener_team and
						IsPlayerInCommanderView(speaker, speaker_client, listener) or
					basecommands and basecommands:IsSpectatorAllTalk(listener)
				)
			then
				Notify(listener_client, speaker_client, true)
				return true
			end
			return false
		elseif speaker:isa "Commander" then
			Notify(listener_client, speaker_client, false)
		end
	end

	-- Without it, let vanilla and Shine decide instead of erroring
	if not basecommands then return end

	if not channel or channel == VoiceChannel.Global then
		return basecommands:CanPlayerHearGlobalVoice(gamerules, listener, speaker, speaker_client)
	end

	if
		basecommands:IsLocalAllTalkDisabled(listener_client)
		or basecommands:IsLocalAllTalkDisabled(speaker_client)
		-- Commanders only hear their team, and can choose not to hear proximity chat
		or listener:isa "Commander" and (
			speaker_team ~= listener_team or
			commander_hear[listener_client:GetId()] == false
		)
	then
		return false
	end

	if
		not basecommands:ArePlayersInLocalVoiceRange(speaker, listener) and
		-- Commanders also hear the team mates they can see
		not (
			listener:isa "Commander" and
			IsPlayerInCommanderView(listener, listener_client, speaker)
		)
	then
		return false
	end

	local team_only = voice_teamonly[speaker_client:GetId()] or false

	if basecommands:IsSpectatorAllTalk(listener) or speaker_team == listener_team then
		-- Notify the listener of the team-only state
		Notify(listener_client, speaker_client, team_only)
		return true
	else
		return not team_only
	end
end, -20)

Shine.Hook.Add("ClientDisconnect", "LocalTalkExtended", function(client)
	local id = client:GetId()

	voice_teamonly[id] = nil
	commander_talk[id] = nil
	commander_hear[id] = nil
	screen_aspect[id]  = nil
	-- Only the listener's own table: the other clients still remember
	-- what we told them about this id.
	notified[id]       = nil
end)
