-- define OP_TT_ColorPicker just incase ns2plus hasn't been loaded
Script.Load("lua/menu2/widgets/GUIMenuColorPickerWidget.lua") -- doesn't get loaded by vanilla menu
OP_TT_ColorPicker = OP_TT_ColorPicker or GetMultiWrappedClass(GUIMenuColorPickerWidget, {"Option", "Tooltip"})

local menu =
{
	categoryName = "localTalk",
	entryConfig =
	{
		name = "localTalkModEntry",
		class = GUIMenuCategoryDisplayBoxEntry,
		params =
		{
			label = "LOCAL TALK OPTIONS",
		},
	},
	contentsConfig = ModsMenuUtils.CreateBasicModsMenuContents
	{
		layoutName = "localTalkOptions",
		contents =
		{
			{
				name = "localTalkProximityDivider",
				class = GUIMenuDividerWidget,
				properties =
				{
					{"Label", "PROXIMITY CHAT"},
				},
			},
			{
				name = "pushToTalkLocal",
				class = OP_TT_Keybind,
				params = {
					optionPath = "input/LocalVoiceChat",
					optionType = "string",
					default = "None",

					bindGroup = "general",

					tooltip = "Proximity voice chat, everyone near you can hear it, including enemies.",
				},
				properties = {
					{ "Label", "PUSH TO TALK (PROXIMITY)" },
				},
			},
			{
				name = "pushToTalkLocalTeam",
				class = OP_TT_Keybind,
				params =
				{
					optionPath = "input/LocalVoiceChatTeam",
					optionType = "string",
					default = "None",

					bindGroup = "general",

					tooltip = "Proximity voice chat, only your team mates near you can hear it.",
				},
				properties =
				{
					{"Label", "PUSH TO TALK (TEAM-ONLY)"},
				},
			},
			{
				name = "localTalkCommanderDivider",
				class = GUIMenuDividerWidget,
				properties =
				{
					{"Label", "COMMANDER"},
				},
			},
			{
				name = "pushToTalkLocalCom",
				class = OP_TT_Keybind,
				params =
				{
					optionPath = "input/LocalVoiceChatCom",
					optionType = "string",
					default = "None",

					-- Like the vanilla commander push to talk
					inheritFrom = "pushToTalkLocalTeam",
					bindGroup = "commander",

					tooltip = "Team-only: only your team mates within your view hear you. It sounds like normal voice chat instead of coming from a position.",
				},
				properties =
				{
					{"Label", "COMMANDER PUSH TO TALK"},
				},
			},
			{
				name = "LocalTalkExtended_commander_hear",
				class = OP_TT_Checkbox,
				params =
				{
					optionPath = "LocalTalkExtended_commander_hear",
					optionType = "bool",
					default = true,

					tooltip = "As commander, hear the proximity chat of your team mates in range and within your view. Normal voice chat is not affected.",
				},
				properties =
				{
					{"Label", "COMMANDER HEARS PROXIMITY CHAT"},
				},
			},
			{
				name = "localTalkColorsDivider",
				class = GUIMenuDividerWidget,
				properties =
				{
					{"Label", "COLORS"},
				},
			},
			{
				name = "LocalTalkExtended_color",
				class = OP_TT_ColorPicker,
				params =
				{
					optionPath = "LocalTalkExtended_color",
					optionType = "color",
					default = 0x80FF80,

					tooltip = "This controls the color of the name you see when someone speaks using non-team-only proximity chat",
				},
				properties =
				{
					{"Label", string.upper("Color of proximity chat")},
				},
				postInit = function(self)
					self:HookEvent(self, "OnValueChanged", function(this)
						kLocalVoiceFontColor = this:GetValue()
					end)
				end
			},
			{
				name = "LocalTalkExtended_color_team",
				class = OP_TT_ColorPicker,
				params =
				{
					optionPath = "LocalTalkExtended_color_team",
					optionType = "color",
					default = 0xC028C0,

					tooltip =  "This controls the color of the name you see when someone speaks using team-only proximity chat",
				},
				properties =
				{
					{"Label", string.upper("Color of team-only chat")},
				},
				postInit = function(self)
					self:HookEvent(self, "OnValueChanged", function(this)
						kLocalVoiceTeamOnlyFontColor = this:GetValue()
					end)
				end
			},
			{
				name = "LocalTalkExtended_color_commander",
				class = OP_TT_ColorPicker,
				params =
				{
					optionPath = "LocalTalkExtended_color_commander",
					optionType = "color",
					default = 0xFFA500,

					tooltip = "This controls the color of the name you see when a commander talks only to the team mates within his view",
				},
				properties =
				{
					{"Label", string.upper("Color of commander local talk")},
				},
				postInit = function(self)
					self:HookEvent(self, "OnValueChanged", function(this)
						kLocalVoiceCommanderFontColor = this:GetValue()
					end)
				end
			},
		},
	}
}
table.insert(gModsCategories, menu)