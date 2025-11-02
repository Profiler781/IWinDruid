# IWinDruid v0.3

Smart macros for Turtle Druids v1.18.0. Make macros with commands. Put them on your action bars. Enjoy!

/!\ IN DEVELOPMENT

Author: Agamemnoth (discord)

## Commands

    /iblast      Single target caster rotation
    /iruetoo     Single target cat rotation
    /isacat      Multi target cat rotation
    /itank       Single target bear rotation
    /ihodor      Multi target bear rotation
    /ichase      Stick to your target TODO
    /ikick       Kick TODO
    /itaunt      Growl if the target is not under another taunt effect

## Setup commands

    /iwin                             Current setup
    /iwin frontshred <toggle>         Setup for Front Shredding

toggle possible values: on, off.

Example: /iwin frontshred on
=> Will setup shred usable in rotations while in front of target. You must strafe through the mob and spam the command.

## Required Mods & Addons

Mandatory Mods:
* [SuperWoW](https://github.com/balakethelock/SuperWoW/), A mod made for fixing client bugs and expanding the lua-based API used by user interface addons. Used for debuff tracking.
* [Nampower](https://github.com/pepopo978/nampower/), A mod made to dramatically increase cast efficiency on the 1.12.1 client. Used for range checks.

You need one of the following addons, used for debuff tracking:
* [SuperCleveRoidMacros](https://github.com/jrc13245/SuperCleveRoidMacros/), Recommanded, Advanced macro conditions and syntax.
* [pfUI](https://github.com/shagu/pfUI/), A full UI replacement.
* [ShaguTweaks](https://github.com/shagu/ShaguTweaks/), A non-intrusive quality of life addon.