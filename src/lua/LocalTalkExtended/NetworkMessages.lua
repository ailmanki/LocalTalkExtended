Shared.RegisterNetworkMessage("LocalTalkExtended_teamonly", {
	on = "boolean"
})

Shared.RegisterNetworkMessage("LocalTalkExtended_teamonly_notify", {
	client = "entityid",
	on = "boolean",
})

-- Commander talking to the team mates within his view
Shared.RegisterNetworkMessage("LocalTalkExtended_commander", {
	on = "boolean"
})

-- Whether the player wants to hear proximity chat while commanding
Shared.RegisterNetworkMessage("LocalTalkExtended_commander_hear", {
	on = "boolean"
})

-- The server needs the screen aspect ratio to know what a commander can see
Shared.RegisterNetworkMessage("LocalTalkExtended_aspect", {
	aspect = "float (1 to 4 by 0.01)"
})
