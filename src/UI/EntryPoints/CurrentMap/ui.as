namespace AutomationUI {
namespace CurrentMap {
    void RTPart_ValidationReplay() {
        UI::TextDisabled("Uses the map-embedded author ghost. Available for maps built between Oct 2022 and Jan 2026, and most maps after Jan 2026.");

        if (Services::Automation::CurrentMap::ValidationReplay::ValidationReplayExists()) {
            UI::Text("\\$0f0Validation replay found.");

            int vrTime = Services::Automation::CurrentMap::ValidationReplay::GetValidationReplayTime();
            if (vrTime > 0) {
                UI::Text("Time: \\$fff" + ARL_FormatMs(vrTime));
            }

            auto rootMap = GetApp().RootMap;
            if (rootMap !is null && rootMap.MapInfo !is null) {
                string authorName = rootMap.MapInfo.AuthorNickName;
                if (authorName.Length == 0)
                    authorName = rootMap.MapInfo.AuthorLogin;
                if (authorName.Length > 0) {
                    UI::Text("Author: \\$fff" + authorName);
                }
            }

            UI::Dummy(vec2(0, 2));
            if (UI::Button(Icons::UserPlus + " Load Validation Replay")) {
                Services::Automation::CurrentMap::ValidationReplay::AddValidationReplay();
            }
        } else {
            UI::Text("\\$f00No validation replay found for this map.");
            _UI::DisabledButton(Icons::UserPlus + " Load Validation Replay");
        }
    }

    class MedalUIEntry {
        string label;
        string colorCode;
        Services::Automation::CurrentMap::Medals::Medal@ medal;
        bool depPresent;

        MedalUIEntry() {}
        MedalUIEntry(const string &in _label, const string &in _color, Services::Automation::CurrentMap::Medals::Medal@ _medal, bool _depPresent) {
            label = _label;
            colorCode = _color;
            @medal = _medal;
            depPresent = _depPresent;
        }
    }

    array<MedalUIEntry@> medalEntries;

    void InitMedalEntries() {
        medalEntries.Resize(0);

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
        medalEntries.InsertLast(MedalUIEntry("Champion",  "\\$e79", Services::Automation::CurrentMap::Medals::champMedal,   hasChamp));
        medalEntries.InsertLast(MedalUIEntry("Warrior",   "\\$0cf", Services::Automation::CurrentMap::Medals::warriorMedal, hasWarrior));
        medalEntries.InsertLast(MedalUIEntry("SB Ville",  "\\$f90", Services::Automation::CurrentMap::Medals::sbVilleMedal, hasSBVille));
        medalEntries.InsertLast(MedalUIEntry("Author",    "\\$7e0", Services::Automation::CurrentMap::Medals::authorMedal,  true));
        medalEntries.InsertLast(MedalUIEntry("Gold",      "\\$fd0", Services::Automation::CurrentMap::Medals::goldMedal,    true));
        medalEntries.InsertLast(MedalUIEntry("Silver",    "\\$ddd", Services::Automation::CurrentMap::Medals::silverMedal,  true));
        medalEntries.InsertLast(MedalUIEntry("Bronze",    "\\$c73", Services::Automation::CurrentMap::Medals::bronzeMedal,  true));
    }

    void RTPart_MedalTable() {
        if (medalEntries.Length == 0) InitMedalEntries();

        UI::TextDisabled("Load the ghost closest to each medal time on this map.");
        UI::Dummy(vec2(0, 4));

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        bool anyLoadable = false;
        for (uint j = 0; j < medalEntries.Length; j++) {
            if (medalEntries[j].depPresent && medalEntries[j].medal.medalExists) {
                anyLoadable = true;
                break;
            }
        }
        UI::BeginDisabled(!anyLoadable);
        if (UI::Button(Icons::Download + " Load All Available")) {
            for (uint k = 0; k < medalEntries.Length; k++) {
                auto e = medalEntries[k];
                if (e.depPresent && e.medal.medalExists) {
                    e.medal.AddMedal();
                }
            }
        }
        UI::EndDisabled();
        _UI::SimpleTooltip("Load ghosts for all medals that have data");
        UI::PopStyleVar();
        UI::Dummy(vec2(0, 4));

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 5));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));

        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders;
        if (UI::BeginTable("ARL_Medals", 5, flags)) {
            UI::TableSetupColumn("Medal",  UI::TableColumnFlags::WidthFixed, 90);
            UI::TableSetupColumn("Time",   UI::TableColumnFlags::WidthFixed, 85);
            UI::TableSetupColumn("Status", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Diff",   UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("",       UI::TableColumnFlags::WidthFixed, 60);
            UI::TableHeadersRow();

            for (uint i = 0; i < medalEntries.Length; i++) {
                auto e = medalEntries[i];

                if (!e.depPresent) continue;

                UI::TableNextRow();

                UI::TableNextColumn();
                UI::Text(e.colorCode + e.label + "\\$z");

                UI::TableNextColumn();
                if (e.medal.medalExists)
                    UI::Text(Services::Automation::CurrentMap::FromMsToFormat(e.medal.currentMapMedalTime));
                else
                    UI::Text("-");

                UI::TableNextColumn();
                if (!e.medal.medalExists)
                    UI::TextDisabled("(no data)");
                else if (!e.medal.reqForCurrentMapFinished)
                    UI::Text("Not checked yet");
                else if (e.medal.medalHasExactMatch)
                    UI::Text("\\$0f0Exact match\\$z");
                else
                    UI::Text("Nearest (beats medal)");

                UI::TableNextColumn();
                if (e.depPresent && e.medal.reqForCurrentMapFinished)
                    UI::Text("+" + e.medal.timeDifference + " ms");
                else
                    UI::Text("-");

                UI::TableNextColumn();
                UI::BeginDisabled(!e.depPresent || !e.medal.medalExists);
                if (UI::Button(Icons::Download + "##medal_" + i, vec2(32, 0))) {
                    e.medal.AddMedal();
                }
                UI::EndDisabled();
                _UI::SimpleTooltip("Load " + e.label + " medal ghost");
            }

            UI::EndTable();
        }

        UI::PopStyleColor();
        UI::PopStyleVar();
    }
}
}
