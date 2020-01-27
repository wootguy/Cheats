# Cheats
`Impulse 101 N/A: Player slots is above 3`

... let's bypass this silly restriction, shall we?

*Update: I didn't know that sv_cheats 2 gets around the player count limit (just make sure to add yourself to admins.txt). You may want to just do that instead of installing this plugin. That said, you might still find this useful if you prefer chat commands, or if you don't want to bother with admins.txt.*

This plugin aims to replicate the built-in cheats, while also adding a little more power to the commands.

# Supported cheats

`.noclip` - Fly through walls  
`.godmode` or `.god` - Take no damage  
`.notarget` - Monsters ignore you  
`.nonsolid` or `.notouch` - Things pass through you and triggers ignore you  
`.rambo` - Disables weapon cooldowns and reloading. All weapons fire at 20 fps.  
`.impulse 101` - Gives all weapons, some ammo, and a battery (less efficient than .giveall)  
`.impulse 50` - Toggle your HEV suit and HUD  
`.give` - Give a **weapon_** **ammo_** or **item_** entity  
`.givepoints` - Add points to user score  
`.giveall` - Give all weapons and *infinite ammo* (I did this to make it more effecient than impulse 101)  
`.healme` or `.heal` - Fully restores health   
`.chargeme` or `.charge` or `.recharge` - Fully charges HEV suit 
`.maxhealth` - Sets max health value  
`.maxcharge` or `.maxarmor` - Sets max armor value  
`.revive` - Brings you back to life  
`.strip` - Remove all weapons and ammo    
`.speed` - Change movement speed (range is 0 to sv_maxspeed)  
`.damage` - Change current weapon damage (most weapons don't respond to this properly, but future sven updates may improve support for this)  
`.gravity` or `.grav` - Change percentage of gravity applied to an individual (50 = 50% of sv_gravity). Overrides trigger_gravity if not set to 100.  
`.cloak` - Same as notarget but also makes your player model invisible  

If I forgot a cheat, let me know and I'll consider adding it. I've rarely used anything besides *the big three* (noclip/godmode/impulse 101), so I probably missed some.

# Usage

Cheats are enabled for admins at all times. To enable cheats for all players, say `.cheats 1` or type it into the console. To enable cheats for a specific player, add their name to the end of the command. For example, `.cheats 1 w00tguy` would enable cheats only for that player.

Cheats that change state (godmode, noclip, notarget, and notouch) can optionally be given a 0/1 argument. If no argument is given, the player's cheat state will be toggled.

You can apply cheats to other players by adding their name as the last argument. To apply a cheat to all players in the server, use `\all` as the player name.

Use the `.cheatlist` command to list all available cheats. All commands can be typed in chat or in the console.

# Some examples
`.god`  
Toggles your god mode on/off.

`.god 1`  
Enables your god mode (or leaves it on if you already have it enabled).

`.give weapon_rpg \all`  
Gives every player in the server a rocket launcher. Note: You don't have to type `\all`, you can just type `\`.

`.god 1 w00tguy`  
Enables godmode for the player named "w00tguy".

**Other ways you could have done this:**
- Typing part of the name (`.god 1 w00t` or `.god 1 guy`)
- Using w00tguy's Steam ID instead of username
- Using the wrong capitalization (`.god 1 W00tGUy`)

If a player's name has spaces in it, surround it with quotes (`.god 1 "w00tguy the yoloswag 2016"`).
