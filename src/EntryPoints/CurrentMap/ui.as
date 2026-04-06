namespace EntryPoints {
namespace CurrentMap {
    class MedalUIEntry {
        string label;
        string colorCode;
        EntryPoints::CurrentMap::Medals::Medal@ medal;
        bool depPresent;

        MedalUIEntry() {}
        MedalUIEntry(const string &in label, const string &in colorCode, EntryPoints::CurrentMap::Medals::Medal@ medal, bool depPresent) {
            this.label = label;
            this.colorCode = colorCode;
            @this.medal = medal;
            this.depPresent = depPresent;
        }
    }

    array<MedalUIEntry@> g_MedalEntries;

    void InitMedalEntries() {
        g_MedalEntries.Resize(0);

        bool hasChamp = false;
        bool hasWarrior = false;
        bool hasSBVille = false;
#if DEPENDENCY_CHAMPIONMEDALS
        hasChamp = true;
#endif
#if DEPENDENCY_WARRIORMEDALS
        hasWarrior = true;
#endif
#if DEPENDENCY_SBVILLECAMPAIGNCHALLENGES
        hasSBVille = true;
#endif

        g_MedalEntries.InsertLast(MedalUIEntry("Champion", "\\$e79", EntryPoints::CurrentMap::Medals::champMedal, hasChamp));
        g_MedalEntries.InsertLast(MedalUIEntry("Warrior", "\\$0cf", EntryPoints::CurrentMap::Medals::warriorMedal, hasWarrior));
        g_MedalEntries.InsertLast(MedalUIEntry("SB Ville", "\\$f90", EntryPoints::CurrentMap::Medals::sbVilleMedal, hasSBVille));
        g_MedalEntries.InsertLast(MedalUIEntry("Author", "\\$7e0", EntryPoints::CurrentMap::Medals::authorMedal, true));
        g_MedalEntries.InsertLast(MedalUIEntry("Gold", "\\$fd0", EntryPoints::CurrentMap::Medals::goldMedal, true));
        g_MedalEntries.InsertLast(MedalUIEntry("Silver", "\\$ddd", EntryPoints::CurrentMap::Medals::silverMedal, true));
        g_MedalEntries.InsertLast(MedalUIEntry("Bronze", "\\$c73", EntryPoints::CurrentMap::Medals::bronzeMedal, true));
    }

    void Render() {
        string mapName = get_CurrentMapName();
        if (mapName.Length > 0) mapName = Text::StripFormatCodes(mapName);
        UI::TextDisabled(Icons::Map + " " + (mapName.Length > 0 ? mapName : "(no map loaded)"));
        UI::Dummy(vec2(0, 4));

        if (UI::CollapsingHeader(Icons::Trophy + " Validation Replay", UI::TreeNodeFlags::DefaultOpen)) {
            RenderValidationReplay();
        }

        if (UI::CollapsingHeader(Icons::Certificate + " Medal Ghosts", UI::TreeNodeFlags::DefaultOpen)) {
            RenderMedalGhosts();
        }

        // GPS is intentionally hidden for now while the current-map GPS flow is being reworked.
        // Keep RenderGPS and the GPS module around so we can bring them back in a later pass.
        // if (UI::CollapsingHeader(Icons::Crosshairs + " GPS / Mediatracker")) {
        //     RenderGPS();
        // }
    }

    void RenderValidationReplay() {
        UI::TextDisabled("Uses the map-embedded author ghost when the current map exposes one.");

        if (EntryPoints::CurrentMap::ValidationReplay::Exists()) {
            UI::Text("\\$0f0Validation replay found.");

            int vrTime = EntryPoints::CurrentMap::ValidationReplay::GetTime();
            if (vrTime > 0) {
                UI::Text("Time: \\$fff" + ARL_FormatMs(vrTime));
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
            if (UI::Button(Icons::UserPlus + " Load Validation Replay")) {
                EntryPoints::CurrentMap::ValidationReplay::Add();
            }
        } else {
            UI::Text("\\$f00No validation replay found for this map.");
            _UI::DisabledButton(Icons::UserPlus + " Load Validation Replay");
        }
    }

    void RenderMedalGhosts() {
        if (g_MedalEntries.Length == 0) InitMedalEntries();

        UI::TextDisabled("Load the leaderboard ghost closest to each medal time on this map.");
        UI::Dummy(vec2(0, 4));

        bool anyLoadable = false;
        for (uint i = 0; i < g_MedalEntries.Length; i++) {
            auto entry = g_MedalEntries[i];
            if (entry.depPresent && entry.medal.medalExists) {
                anyLoadable = true;
                break;
            }
        }

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        UI::BeginDisabled(!anyLoadable);
        if (UI::Button(Icons::Download + " Load All Available")) {
            for (uint i = 0; i < g_MedalEntries.Length; i++) {
                auto entry = g_MedalEntries[i];
                if (entry.depPresent && entry.medal.medalExists) {
                    entry.medal.AddMedal();
                }
            }
        }
        UI::EndDisabled();
        _UI::SimpleTooltip("Load ghosts for all medals that currently have data.");
        UI::PopStyleVar();
        UI::Dummy(vec2(0, 4));

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 5));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders;

        if (UI::BeginTable("ARL_Medals", 5, flags)) {
            UI::TableSetupColumn("Medal", UI::TableColumnFlags::WidthFixed, 90);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
            UI::TableSetupColumn("Status", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Diff", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 60);
            UI::TableHeadersRow();

            for (uint i = 0; i < g_MedalEntries.Length; i++) {
                auto entry = g_MedalEntries[i];
                if (!entry.depPresent) continue;

                UI::TableNextRow();

                UI::TableNextColumn();
                UI::Text(entry.colorCode + entry.label + "\\$z");

                UI::TableNextColumn();
                if (entry.medal.medalExists) UI::Text(ARL_FormatMs(entry.medal.currentMapMedalTime));
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
                if (UI::Button(Icons::Download + "##medal_" + i, vec2(32, 0))) {
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
        auto tracks = EntryPoints::CurrentMap::GPS::GetGhostTracks();
        if (tracks.Length == 0) {
            UI::TextDisabled("No ghost or GPS-like mediatracker tracks were detected on this map.");
            return;
        }

        UI::TextDisabled("Track discovery is back. Extraction is still pending a dedicated implementation pass.");
        UI::Dummy(vec2(0, 4));

        if (UI::Button(Icons::Clipboard + " Copy GPS Summary")) {
            EntryPoints::CurrentMap::GPS::CopyDebugSummary();
        }
        _UI::SimpleTooltip("Copy the detected clip/track layout for planning GPS extraction work.");
        UI::SameLine();
        if (UI::Button(Icons::Wrench + " Extract (WIP)")) {
            EntryPoints::CurrentMap::GPS::RequestExtract();
        }

        UI::Dummy(vec2(0, 4));
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 5));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders;

        if (UI::BeginTable("ARL_CurrentMapGPS", 4, flags)) {
            UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 30);
            UI::TableSetupColumn("Track", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Clip", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Blocks", UI::TableColumnFlags::WidthFixed, 60);
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
                UI::Text(label);

                UI::TableNextColumn();
                UI::TextDisabled(track.clipName.Length > 0 ? track.clipName : "-");

                UI::TableNextColumn();
                UI::Text("" + track.blockCount);
            }

            UI::EndTable();
        }

        UI::PopStyleColor();
        UI::PopStyleVar();
    }
}
}
