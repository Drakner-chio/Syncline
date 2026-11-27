![Syncline – one guide, everyone in it](https://raw.githubusercontent.com/Drakner-chio/syncline/main/docs/images/syncline-1.jpg)

## Level together with RestedXP

**Syncline** keeps your leveling group in the same **RestedXP** guide: the **group leader picks a guide**, and a second later everyone in the group has it loaded – with the same route settings, so everyone has the same steps. And you see at a glance **who is at which step, who is stuck and why, and who needs which quest**.

### One guide for the group

- **The leader decides:** pick a guide in the RestedXP window as usual – it goes to the whole group. Whoever joins, logs in or reloads gets it too
- **Any client language:** RestedXP names its guides differently in every language. Syncline knows they're the same guide – also RestedXP's imported Forever guides. German, English, French, Spanish, Portuguese and Chinese clients play together
- **Same route settings:** dungeons, skipping overleveled steps, group quests, Solo Self Found and the EXP rate decide which steps a guide has. The leader's settings go to the group
- **Suggest a guide:** pick another guide yourself and Syncline offers to suggest it to the leader. One click on *Take it*, and the whole group switches

![German, English, French … same guide](https://raw.githubusercontent.com/Drakner-chio/syncline/main/docs/images/syncline-2.jpg)

### Steps

- **Who is where:** every player's step and how far ahead or behind the leader they are – correct even across classes, whose guides have different steps
- **Skip for everyone:** the leader skips a step for the whole group with one click, or pulls everyone to his step. Members ask the leader for a skip
- **Skip check:** before a skip, Syncline shows whether follow-up quests hang on the step – green: safe to skip, orange/red: these quests would be gone for the whole group
- **Why can't I do this step?** A missing prerequisite, your level, an overleveled or grey quest, a full quest log, a quest not in your log or objectives still open – you see your own reason, and the group sees who is stuck and why

![Skip a step – for everyone](https://raw.githubusercontent.com/Drakner-chio/syncline/main/docs/images/syncline-3.jpg)

### Quests

- **Quest progress of the group:** everyone's progress on the quests of the step – *Bob 8/8 · Dani 6/8 · Fluffy 3/8* – and a word once everyone is done: off to turn it in
- **Accept check:** forget to accept a quest the guide just picked up, and you hear it at once – and the leader sees it too
- **Group steps:** who doesn't have the group quest yet, and who isn't in range
- **Hearthstone and flight paths:** before the guide hearths, everyone's cooldown and whether the hearthstone is set right; flight paths the guide flies to soon that someone hasn't got
- **Missing quests:** quests your guide still expects later that are no longer in your log – for you and for everyone in the group – and a warning before you abandon one the guide still needs
- **Share quests:** see which quests from your log the others still need and share them with one click, all at once, or automatically (`/sl autoshare`)

![Anyone suggests. The leader decides.](https://raw.githubusercontent.com/Drakner-chio/syncline/main/docs/images/syncline-4.jpg)

### Group overview

- **Experience:** level, experience, rested XP and the XP of quests ready to turn in for everyone – plus XP per hour and the time to the next level
- **Slack meter** (leader only): who keeps the group waiting – time spent behind the leader's step, with a ranking, titles and a button to post it in the group chat

### Your way

- Switch right away or get asked first, let the leader move your step or not, every part can be switched off (`/sl options`)
- Nothing switches in combat – it waits until combat ends
- Minimap button, an entry in the minimap's addon menu and key bindings for *skip / request skip* and the group window
- English and German

![Follow along – or ask first](https://raw.githubusercontent.com/Drakner-chio/syncline/main/docs/images/syncline-5.jpg)

## Requirements

- **RestedXP Guides** (required).
- **Everyone in the group** needs Syncline – it's the group's addons that talk to each other.

Made for **World of Warcraft: Forever**.

## Commands

| Command | |
|---|---|
| `/sl` | open or close the group window |
| `/sl status` | who is in which guide at which step, in the chat |
| `/sl send` | (leader) send your guide to the group again |
| `/sl get` | load the leader's guide |
| `/sl suggest` | suggest your guide to the leader |
| `/sl skip` | leader: skip the step for everyone · others: ask the leader |
| `/sl pull` | (leader) everyone in the guide to your step |
| `/sl route` | (leader) send your RestedXP route settings again |
| `/sl why` | why the step you're at can't be done yet |
| `/sl missing` | quests your guide still needs that aren't in your log |
| `/sl share` | share the quests the others need |
| `/sl autoshare` | share them automatically (on/off) |
| `/sl auto` / `ask` | switch right away / ask first |
| `/sl on` / `off` | sync on or off |
| `/sl options` | settings |
| `/sl minimap` | show or hide the minimap button |

German clients can use the German words too (`/sl skippen`, `/sl holen`, `/sl warum`, `/sl teilen`, `/sl optionen`, …).

Minimap button: left click opens the group window, right click the settings, drag to move it. Key bindings: *Key Bindings → AddOns → Syncline*.

## Source

[github.com/Drakner-chio/syncline](https://github.com/Drakner-chio/syncline) – MIT licence. Bugs and ideas welcome as issues.
