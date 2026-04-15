namespace EntryPoints {
namespace CurrentMap {
    void Render() {
        UI::PushStyleColor(UI::Col::Tab, HeaderBg);
        UI::PushStyleColor(UI::Col::TabHovered, HeaderHoverBg);
        UI::PushStyleColor(UI::Col::TabActive, HeaderActiveBg);

        UI::BeginTabBar("CurrentMapTabs");

        if (UI::BeginTabItem(Icons::Trophy + " Validation Replay")) {
            RenderValidationReplay();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::Certificate + " Medal Ghosts")) {
            RenderMedalGhosts();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::IdCard + " Player ID")) {
            EntryPoints::PlayerId::Render();
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::Crosshairs + " GPS")) {
            RenderGPS();
            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::PopStyleColor(3);
    }

    void RenderValidationReplay() {
        UI::Dummy(vec2(0, 2));
        UI::TextDisabled("Uses the map-embedded author ghost when the current map exposes one.");

        if (EntryPoints::CurrentMap::ValidationReplay::Exists()) {
            UI::Text("\\$0f0Validation replay found.");

            int vrTime = EntryPoints::CurrentMap::ValidationReplay::GetTime();
            if (vrTime > 0) {
                UI::Text("Time: \\$fff" + FormatMs(vrTime));
            }

            auto rootMap = GetApp().RootMap;
            if (rootMap !is null && rootMap.MapInfo !is null) {
                string authorName = rootMap.MapInfo.AuthorNickName;
                if (authorName.Length == 0) authorName = rootMap.MapInfo.AuthorLogin;
                if (authorName.Length > 0) {
                    UI::Text("Author: \\$fff" + authorName);
                }
            }

            UI::Dummy(vec2(0, 2));
            if (_UI::Button(Icons::UserPlus + " Load Validation Replay")) {
                EntryPoints::CurrentMap::ValidationReplay::Add();
            }
        } else {
            UI::Text("\\$f00No validation replay found for this map.");
            _UI::DisabledButton(Icons::UserPlus + " Load Validation Replay");
        }
    }

    void RenderMedalGhosts() {
        UI::Dummy(vec2(0, 2));
        auto medalEntries = EntryPoints::CurrentMap::Medals::GetDisplayEntriesSorted();

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 5));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders;

        if (UI::BeginTable("Medals", 5, flags)) {
            UI::TableSetupColumn("Medal", UI::TableColumnFlags::WidthFixed, 110);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
            UI::TableSetupColumn("Status", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Diff", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 60);
            UI::TableHeadersRow();

            for (uint i = 0; i < medalEntries.Length; i++) {
                auto entry = medalEntries[i];
                if (!entry.depPresent || !entry.medal.ShouldRender()) continue;

                UI::TableNextRow();

                UI::TableNextColumn();
                if (entry.iconText.Length > 0) {
                    UI::Text(entry.iconText + "\\$z " + entry.label);
                } else {
                    UI::Text(entry.colorCode + entry.label + "\\$z");
                }

                UI::TableNextColumn();
                if (entry.medal.medalExists) UI::Text(FormatMs(entry.medal.currentMapMedalTime));
                else UI::Text("-");

                UI::TableNextColumn();
                if (!entry.medal.medalExists) UI::TextDisabled("(no data)");
                else if (!entry.medal.reqForCurrentMapFinished) UI::Text("Not checked yet");
                else if (entry.medal.medalHasExactMatch) UI::Text("\\$0f0Exact match\\$z");
                else UI::Text("Nearest (beats medal)");

                UI::TableNextColumn();
                if (entry.depPresent && entry.medal.reqForCurrentMapFinished) UI::Text("+" + entry.medal.timeDifference + " ms");
                else UI::Text("-");

                UI::TableNextColumn();
                UI::BeginDisabled(!entry.depPresent || !entry.medal.medalExists);
                if (_UI::IconButton(Icons::Download, "medal_" + i, vec2(32, 0))) {
                    entry.medal.AddMedal();
                }
                UI::EndDisabled();
                _UI::SimpleTooltip("Load " + entry.label + " medal ghost");
            }

            UI::EndTable();
        }

        UI::PopStyleColor();
        UI::PopStyleVar();
    }

    void RenderGPS() {
        UI::Dummy(vec2(0, 2));
        auto tracks = EntryPoints::CurrentMap::GPS::GetGhostTracks();
        bool hasInspectedTracks = false;
        for (uint i = 0; i < tracks.Length; i++) {
            auto track = tracks[i];
            if (track !is null && track.fromInspect) {
                hasInspectedTracks = true;
                break;
            }
        }

        if (_UI::Button(Icons::Upload + " Send Map + Inspect")) {
            EntryPoints::CurrentMap::GPS::RefreshInspection();
        }
        _UI::SimpleTooltip("Upload the current map file to Clip-To-Ghost and refresh GPS candidates.");
        UI::SameLine();
        if (_UI::Button(Icons::FolderOpen + " Cache Folder")) {
            EntryPoints::CurrentMap::GPS::OpenCacheFolder();
        }

        string gpsStatus = EntryPoints::CurrentMap::GPS::GetLastStatus();
        if (gpsStatus.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::Text(gpsStatus);
        } else if (tracks.Length > 0 && !hasInspectedTracks) {
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled("Block indices are still unresolved. Send the map once to inspect candidates for these tracks.");
        }

        if (tracks.Length == 0) {
            UI::TextDisabled("No ghost or GPS-like mediatracker tracks were detected on this map yet.");
            return;
        }

        UI::Dummy(vec2(0, 4));
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 5));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders;

        if (UI::BeginTable("CurrentMapGPS", 6, flags)) {
            UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 30);
            UI::TableSetupColumn("Track", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Clip", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Block", UI::TableColumnFlags::WidthFixed, 52);
            UI::TableSetupColumn("Race", UI::TableColumnFlags::WidthFixed, 72);
            UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, 110);
            UI::TableHeadersRow();

            for (uint i = 0; i < tracks.Length; i++) {
                auto track = tracks[i];
                if (track is null) continue;

                UI::TableNextRow();
                UI::TableNextColumn();
                UI::Text("" + (i + 1));

                UI::TableNextColumn();
                string label = track.trackName;
                if (track.looksLikeGps) label = "\\$fd0" + label + "\\$z";
                if (track.fromInspect) label += " \\$888(api)\\$z";
                UI::Text(label);

                UI::TableNextColumn();
                UI::TextDisabled(track.clipName.Length > 0 ? track.clipName : "-");

                UI::TableNextColumn();
                if (track.blockIndex >= 0) UI::Text("" + track.blockIndex);
                else UI::TextDisabled(track.blockCount > 0 ? ("?" + " / " + track.blockCount) : "?");

                UI::TableNextColumn();
                if (track.derivedRaceTimeMs >= 0) UI::Text(FormatMs(track.derivedRaceTimeMs));
                else UI::TextDisabled("-");

                UI::TableNextColumn();
                UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

                bool cached = EntryPoints::CurrentMap::GPS::HasCachedGhost(track);
                if (_UI::IconButton(cached ? Icons::Play : Icons::Download, "gps_load_" + i, vec2(28, 0))) {
                    EntryPoints::CurrentMap::GPS::LoadGhostTrack(track, false);
                }
                _UI::SimpleTooltip(cached ? "Load cached GPS ghost" : "Upload the current map file, export this GPS ghost, and load it");

                UI::SameLine();
                if (_UI::IconButton(Icons::Refresh, "gps_refresh_" + i, vec2(28, 0))) {
                    EntryPoints::CurrentMap::GPS::LoadGhostTrack(track, true);
                }
                _UI::SimpleTooltip("Re-upload the current map file and force a fresh GPS ghost export");

                UI::SameLine();
                if (_UI::IconButton(Icons::Link, "gps_url_" + i, vec2(28, 0))) {
                    EntryPoints::CurrentMap::GPS::CopyGhostApiUrl(track);
                }
                _UI::SimpleTooltip("Copy the Clip-To-Ghost export endpoint");

                UI::PopStyleVar();
            }

            UI::EndTable();
        }

        UI::PopStyleColor();
        UI::PopStyleVar();
    }
}
}
