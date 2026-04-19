namespace EntryPoints {
namespace CurrentMap {
    bool ShouldRenderMedalEntry(EntryPoints::CurrentMap::Medals::DisplayEntry@ entry) {
        return entry !is null && entry.depPresent && entry.medal !is null && entry.medal.ShouldRender();
    }

    string GetMedalEntryLabelText(EntryPoints::CurrentMap::Medals::DisplayEntry@ entry) {
        if (entry is null) return "";
        if (entry.iconText.Length > 0) return entry.iconText + "\\$z " + entry.label;
        return entry.colorCode + entry.label + "\\$z";
    }

    string GetMedalEntryTimeText(EntryPoints::CurrentMap::Medals::DisplayEntry@ entry) {
        if (entry is null || entry.medal is null || !entry.medal.medalExists) return "-";
        return FormatMs(entry.medal.currentMapMedalTime);
    }

    string GetMedalEntryStatusText(EntryPoints::CurrentMap::Medals::DisplayEntry@ entry) {
        if (entry is null || entry.medal is null || !entry.medal.medalExists) return "(no data)";
        if (!entry.medal.reqForCurrentMapFinished) return "Not checked yet";
        if (entry.medal.medalHasExactMatch) return "\\$0f0Exact match\\$z";
        if (entry.medal.loadedGhostBeatsMedal) return "Nearest (beats medal)";
        return "Nearest (slower than medal)";
    }

    string GetMedalEntryDiffText(EntryPoints::CurrentMap::Medals::DisplayEntry@ entry) {
        if (entry is null || entry.medal is null) return "-";
        if (entry.depPresent && entry.medal.reqForCurrentMapFinished) return "+" + entry.medal.timeDifference + " ms";
        return "-";
    }

    float GetContentFitColumnWidth(const string &in headerText, const array<string>@ samples, float padding = 12.0f, float minWidth = 0.0f) {
        float width = UI::MeasureString(Text::StripFormatCodes(headerText)).x;
        if (samples !is null) {
            for (uint i = 0; i < samples.Length; i++) {
                width = Math::Max(width, UI::MeasureString(Text::StripFormatCodes(samples[i])).x);
            }
        }
        return Math::Max(minWidth, width + padding);
    }

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
        bool showFasterFallbackWarning = false;
        bool showSlowerFallbackWarning = false;

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 5));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::SizingFixedFit;

        auto medalSamples = array<string>();
        auto timeSamples = array<string>();
        auto statusSamples = array<string>();
        auto diffSamples = array<string>();

        statusSamples.InsertLast("(no data)");
        statusSamples.InsertLast("Not checked yet");
        statusSamples.InsertLast("\\$0f0Exact match\\$z");
        statusSamples.InsertLast("Nearest (beats medal)");
        statusSamples.InsertLast("Nearest (slower than medal)");
        diffSamples.InsertLast("-");

        for (uint i = 0; i < medalEntries.Length; i++) {
            auto entry = medalEntries[i];
            if (!ShouldRenderMedalEntry(entry)) continue;

            medalSamples.InsertLast(GetMedalEntryLabelText(entry));
            timeSamples.InsertLast(GetMedalEntryTimeText(entry));
            statusSamples.InsertLast(GetMedalEntryStatusText(entry));
            diffSamples.InsertLast(GetMedalEntryDiffText(entry));
        }

        float medalColWidth = GetContentFitColumnWidth("Medal", medalSamples, 0.0f, 0.0f);
        float timeColWidth = GetContentFitColumnWidth("Time", timeSamples, 0.0f, 0.0f);
        float statusColWidth = GetContentFitColumnWidth("Status", statusSamples, 0.0f, 0.0f);
        float diffColWidth = GetContentFitColumnWidth("Diff", diffSamples, 0.0f, 0.0f);
        float actionColWidth = 40.0f;

        if (UI::BeginTable("Medals", 5, flags)) {
            UI::TableSetupColumn("Medal", UI::TableColumnFlags::WidthFixed, medalColWidth);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, timeColWidth);
            UI::TableSetupColumn("Status", UI::TableColumnFlags::WidthFixed, statusColWidth);
            UI::TableSetupColumn("Diff", UI::TableColumnFlags::WidthFixed, diffColWidth);
            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, actionColWidth);
            UI::TableHeadersRow();

            for (uint i = 0; i < medalEntries.Length; i++) {
                auto entry = medalEntries[i];
                if (!ShouldRenderMedalEntry(entry)) continue;

                UI::TableNextRow();

                UI::TableNextColumn();
                UI::Text(GetMedalEntryLabelText(entry));

                UI::TableNextColumn();
                UI::Text(GetMedalEntryTimeText(entry));

                UI::TableNextColumn();
                if (!entry.medal.medalExists) UI::TextDisabled(GetMedalEntryStatusText(entry));
                else UI::Text(GetMedalEntryStatusText(entry));

                UI::TableNextColumn();
                UI::Text(GetMedalEntryDiffText(entry));

                if (entry.depPresent && entry.medal.reqForCurrentMapFinished && !entry.medal.medalHasExactMatch && entry.medal.timeDifference > 0) {
                    if (entry.medal.loadedGhostBeatsMedal) showFasterFallbackWarning = true;
                    else showSlowerFallbackWarning = true;
                }

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

        if (showFasterFallbackWarning) {
            UI::Dummy(vec2(0, 4));
            UI::Text("\\$fd0" + Icons::ExclamationTriangle + "\\$z Exact ghost unavailable, so ARL loaded a faster fallback.\nThis usually means the selected time is outside the top 10k individual-record range.");
        }

        if (showSlowerFallbackWarning) {
            UI::Dummy(vec2(0, 4));
            UI::Text("\\$fd0" + Icons::ExclamationTriangle + "\\$z No ghost was fast enough to match the selected medal time.\nARL loaded the fastest available run and shows the +diff to the medal.");
        }
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
