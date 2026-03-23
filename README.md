# Arbitrary Record Loader

[Openplanet](https://openplanet.dev/) plugin for [Trackmania](https://www.trackmania.com/) that loads ghost replays from local files, URLs, leaderboards, official campaigns, or other players.

## Features

- **Loading** - Local `.Gbx` files, direct URLs, Nadeo leaderboards (map UID + rank), player account IDs, official campaign maps.
- **Official campaigns** - Seasonal campaigns, TOTDs, weekly shorts, weekly grands. Built-in map grid and leaderboard browser.
- **Current map** - Validation replays, medal ghosts (AT/Gold/Silver/Bronze), community medals (Champion, Warrior, etc.) if installed.
- **Ghost management** - Hide, show, label (dossard), bulk actions. Filter and sort by name, time, source.
- **Library** - Save ghosts with metadata. Import and organize replay files.
- **Profiles** - JSON map lists for batch loading (e.g. load WR for every map in a campaign).
- **Hotkeys** - Keyboard shortcuts for common actions.

## Requirements

- [Trackmania](https://www.trackmania.com/) (2020+)
- [Openplanet](https://openplanet.dev/) installed
- **NadeoServices** plugin (bundled with Openplanet)
- **MLHook** plugin

### Optional

Extra medal types on the Current Map tab:

- [Champion Medals](https://openplanet.dev/plugin/championmedals)
- [Warrior Medals](https://openplanet.dev/plugin/warriormedals)
- [SBVille Campaign Challenges](https://openplanet.dev/plugin/sbvillecampaignchallenges)
- [Archivist](https://openplanet.dev/plugin/archivist)
- [BetterReplaysFolder](https://openplanet.dev/plugin/betterreplaysfolder)

## How it works

Runs a local HTTP server to serve ghost files to the game's `Ghost_Download` API. Ghosts from any source get staged locally and fed to the game engine. Metadata is tracked per ghost so you know where it came from.

## Credits

- **Author:** ar