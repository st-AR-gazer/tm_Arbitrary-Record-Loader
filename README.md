# Arbitrary Record Loader

[Openplanet](https://openplanet.dev/) plugin for [Trackmania](https://www.trackmania.com/) focused on loading ghosts and replays from a wide range of sources, then keeping enough metadata around to manage them properly once they are in game.

## What ARL Can Load

- Local `.Ghost.Gbx` and `.Replay.Gbx` files
- Direct file URLs
- Nadeo leaderboard records by map UID + rank offset
- A specific player's record on the current map
- Official content:
  seasonal campaigns, TOTDs, discovery campaigns, weekly shorts, and weekly grands
- JSON map profiles for batch loading
- Saved ghosts from ARL's own library
- Current-map helpers:
  validation replay and medal ghosts

## UI Overview

ARL is currently split into three main pages:

- **Load**
  local files, URL, map UID + rank, player ID, official sources, and current-map helpers
- **Loaded**
  inspect currently tracked ghosts, filter/sort them, hide/show them, forget them, or save them to the library
- **Library**
  manage saved ghosts and JSON profiles

### Load Page

- **Local Files**
  open the file explorer, load selected replays/ghosts, or quickly browse common replay folders
- **URL**
  load a direct replay/ghost link and keep a short recent-URL history
- **Map UID + Rank**
  fetch leaderboard ghosts by map UID and rank offset
- **Player ID**
  load a specific player's record on the currently loaded map
- **Official**
  browse official campaigns plus discovery and weekly content
- **Current Map**
  load the map's validation replay and available medal ghosts

### Loaded Page

- Filter by ghost name
- Sort by state, name, or time
- Bulk hide/show/forget selected ghosts
- Save tracked ghosts into the library
- Inspect all ghosts currently known to the game, not just ARL-loaded ones

### Library Page

- Save loaded ghosts with metadata
- Import replay/ghost files into the library
- Reload or delete saved items
- Create, download, browse, and batch-load JSON profiles

## Requirements

- [Trackmania](https://www.trackmania.com/) (2020+)
- [Openplanet](https://openplanet.dev/)

### Strongly Recommended Dependencies

- **NadeoServices**
  required for online lookups such as leaderboards, official sources, display-name resolution, and replay URL resolution
- **MLHook**
  used for some in-game visibility integration and hook-based helper behavior

### Optional Integrations

- [Champion Medals](https://openplanet.dev/plugin/championmedals)
- [Warrior Medals](https://openplanet.dev/plugin/warriormedals)
- [SBVille Campaign Challenges](https://openplanet.dev/plugin/sbvillecampaignchallenges)
- [Archivist](https://openplanet.dev/plugin/archivist)
- [BetterReplaysFolder](https://openplanet.dev/plugin/betterreplaysfolder)

These extend the Current Map / Local Files workflows when installed, but ARL itself does not require all of them.

## Current Status Notes

- The plugin has been reorganized around `App`, `Domain`, `Integrations`, `Services`, and `UI` folders.
- Record loading now runs through a shared request/queue pipeline instead of several disconnected loader paths.
- Hotkeys are being redesigned.
  The old implementation is archived under `backup/hotkeys_legacy/`.

## How It Works

ARL stages ghosts/replays locally, resolves online records through Trackmania/Nadeo services when needed, and then hands the resulting files to the game. It also tracks source metadata for loaded ghosts so the UI can tell you where a ghost came from and what map/account it was associated with.

## Building

This repo includes a simple `_build.py` helper that packages `src/` together with `info.toml`, `LICENSE`, and `README.md` into an `.op` archive.

## Credits

- **Author:** ar
