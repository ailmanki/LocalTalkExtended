# Notice to server operators

This mod now requires Shine's basecommands plugin to be loaded.

# What is this?

A mod that allows all players to talk to players in their proximity.

There's lots of mods like this on the workshop, although none are as
complete and as bug-free as this.

## Features

- Team-only proximity/local voice chat
- Non-team-only proximity/local voice chat
- Proximity voice chat works spectator, dead player, commander, etc., but with restrictions
- Commander local talk: the commander talks only to the team within his view
- Static voice chat bar placement, so that the bar of a player does not move around constantly
- Different color for each voice channel (team-only, non-team-only, global)
- Customization of proximity/local voice chat colors in Options -> Mods -> Local Talk Options

## Bugs fixed compared to competitors
- Spectators not being always able to hear proximity/local voice chat when in first person mode

# How to use this?

First you have to set your keybindings in Options -> Mods -> Local Talk Options.
Once you've set your keybindings, you can use proximity/local voice chat
on any server that has this mod enabled.

# Voice chat restrictions

## Spectators
Spectators can not use local voice.

## Commanders
Like the vanilla commander push to talk, commanders have their own key for local
voice chat (by default it follows the team-only key). When the commander uses it,
only the team within his view can hear him. It sounds like normal voice chat
instead of coming from a position, and his name is shown in its own color (orange by default).
This way the commander can talk to a squad without cluttering everyone's voice chat.
Leaving the command chair while talking continues as team-only local voice chat.

Commanders only hear the local voice chat of their team: in range, and also
within their view. This can be turned off in the options.