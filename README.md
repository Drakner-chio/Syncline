# Syncline

![Syncline – one guide, everyone in it](docs/images/syncline-1.jpg)

**Level together with RestedXP.** The group leader picks a RestedXP guide and everyone in the group follows – same guide, same route settings, and you see at a glance who is at which step, who is stuck and why, and who needs which quest.

Made for **World of Warcraft: Forever**. Interface in English and German.

Everyone in the group needs **RestedXP Guides** and **Syncline**: it's the group's addons that talk to each other.

The CurseForge description lives in [`docs/curseforge.md`](docs/curseforge.md).

## Features

**One guide for the group**
- The leader picks a guide in the RestedXP window as usual, and it goes to the whole group. Whoever joins, logs in or reloads gets it too.
- Members can suggest a guide: pick one yourself and Syncline offers to suggest it to the leader, who takes it for everyone with one click.
- The leader's RestedXP route settings (dungeons, skip overleveled steps, group quests, Solo Self Found, EXP rate) go to the group as well, so everyone's guide has the same steps.
- Nothing switches in combat: it waits until combat ends. Switch right away or get asked first – your choice.

**Steps**
- The group window shows every player's step and how far ahead or behind the leader they are, plus the leader's step with its text. A progress bar marks where everyone is in the guide.
- Views for the group window, set separately for leading and for being a member: **Full**, **Quests** (overview plus quest helpers), **Compact** (overview, quest progress, hearthstone, missing quests) or **Custom**. The compact overview shows a dot per player and only what needs attention: the leader sees everyone's problems, a member only their own. A click on a card's title folds it; buttons show only what fits right now.
- The leader skips a step for the whole group, or pulls everyone to his step. Members ask the leader for a skip.
- Skip check: before a skip, Syncline shows whether follow-up quests hang on the step (green: safe, orange/red: these quests would be gone) and asks the leader once more.
- Why can't I do this step? A missing prerequisite, your level, an overleveled or grey quest, a quest already turned in, a full quest log, a quest not in your log or objectives still open. You see your own reason, and the group sees who is stuck and why.

**Quests**
- Quest progress of the group: everyone's progress on the quests of the step (`Bob 8/8 · Dani 6/8`), and a word with a sound once everyone is done.
- Accept check: forget to accept a quest the guide just picked up, and you hear it at once; the leader sees it too.
- Group steps: for steps RestedXP marks for groups, who doesn't have the quest yet and who isn't in range.
- Hearthstone and flight paths: when the guide hearths soon, everyone's hearthstone cooldown and whether it's set where the guide expects; flight paths the guide flies to soon that someone hasn't got.
- Missing quests: quests your guide still expects later that are no longer in your log, for you and for everyone in the group. A warning before you abandon a quest the guide still needs.
- Share quests: see which quests from your log the others still need and share them with one click, all at once, or automatically (`/sl autoshare`).

**Group overview**
- Experience: level, experience, rested XP and the XP of quests ready to turn in for everyone, plus XP per hour and the time to the next level.
- Slack meter (leader only): who keeps the group waiting, with a ranking and titles, and a button to post it in the group chat.

**Your way**
- Minimap button (left click: group window, right click: settings, drag to move), an entry in the minimap's addon menu, key bindings for skip and the group window.
- Settings in Syncline's own window, also under *Options → AddOns → Syncline*. Every part can be switched off.

## Mixed client languages

RestedXP loads its guides in the client's language, and their names differ: *RestedXP Forever Guide (H) · 12-17 The Barrens* on an English client is *RestedXP Forever Route (H) · 12-17 Das Brachland* on a German one. Syncline never sends names alone:

- **Public guides** are sent with a language-independent id from [`GuideMap.lua`](GuideMap.lua), built from the RestedXP source for all six RestedXP languages.
- **Imported guides** (RestedXP's paid Forever guides, which everyone imports in their own language) are recognised by a fingerprint: the level range in the name plus the guide's first quest ids.
- **Steps** are matched by their line in the guide text, not by their number: RestedXP leaves out steps for other classes and races, so step numbers differ from player to player, the line doesn't.
- **Route settings, quests and flight paths** travel as setting keys, RestedXP's dungeon tags, quest ids and flight path ids. Whether the hearthstone is set right is checked on each client, in its own language.

Every message and window text is then built on each client, in its own language.

## Commands

| Command | |
|---|---|
| `/sl` | open or close the group window |
| `/sl status` | who is in which guide at which step, in the chat |
| `/sl options` | settings |
| `/sl minimap` | show or hide the minimap button |
| `/sl send` | (leader) send your guide to the group again |
| `/sl get` | load the leader's guide |
| `/sl suggest` | suggest your guide to the leader |
| `/sl skip` | leader: skip the step for everyone · others: ask the leader |
| `/sl pull` | (leader) everyone in the guide to your step |
| `/sl route` | (leader) send your RestedXP route settings again |
| `/sl why` | why the step you're at can't be done yet |
| `/sl missing` | quests your guide still needs that aren't in your log |
| `/sl share` | share the quests the others need |
| `/sl autoshare` | share them automatically (`on` / `off`) |
| `/sl auto` / `ask` | switch right away / ask first |
| `/sl on` / `off` | sync on or off |
| `/sl version` | your Syncline version |
| `/sl debug` | show every Syncline message in the chat |
| `/sl help` | all commands |

`/syncline` works as well. German clients also take the German words (`/sl skippen`, `/sl holen`, `/sl warum`, `/sl teilen`, `/sl optionen`, …).

## Development

| File | |
|---|---|
| `Core.lua` | messages, guide sync, steps, skips, route settings, slash commands |
| `GuideMap.lua` | the same guide in every language (generated, don't edit) |
| `Missing.lua` · `Blockers.lua` · `Share.lua` | missing and not accepted quests, why a step hangs, sharing quests |
| `Progress.lua` · `Travel.lua` | quest progress and group steps, hearthstone and flight paths |
| `XP.lua` · `Slack.lua` | experience overview, slack meter |
| `GroupWindow.lua` · `Options.lua` · `Theme.lua` · `Locale.lua` | windows, settings, look, texts |

- **Tests** run outside the game: `lua5.1 tests/run.lua` (a small fake of the game's API and of RestedXP in `tests/wowstub.lua`).
- **GuideMap** is rebuilt every day by [`.github/workflows/guidemap.yml`](.github/workflows/guidemap.yml) when RestedXP changes its guides. By hand: `python3 tools/build_guidemap.py <path to RXPGuides> > GuideMap.lua`.
- **Releases**: *Actions → Release → Run workflow* with a version (e.g. `0.12.0`, or `0.12.0-beta1`). It packages the addon and uploads it to GitHub and CurseForge (project 1833016).
- **CurseForge banners** come from [`docs/banner-source`](docs/banner-source): `python3 docs/banner-source/render.py`.

## Planned

- Quest rewards: which reward is the best upgrade for whom, using [GearShare](https://github.com/Drakner-chio/Gearshare) when it's installed.
- Quest items and drops: who still needs which quest items, so the group knows who should roll need.

## License

MIT, see [LICENSE](LICENSE). Bugs and ideas are welcome as issues.
