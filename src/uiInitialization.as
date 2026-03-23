[Setting category="General" name="Window Open"]
bool S_ARL_WindowOpen = false;

enum ARL_Page {
    Load = 0,
    Loaded,
    Library,
    Automation,
    Hotkeys,
    SettingsDev
}

ARL_Page g_ARL_Page = ARL_Page::Load;

int g_DefaultRankOffset = 0;

vec4 ARL_AccentCol       = vec4(0.42f, 0.78f, 0.44f, 1.0f);
vec4 ARL_AccentDimCol    = vec4(0.30f, 0.58f, 0.32f, 1.0f);
vec4 ARL_AccentBrightCol = vec4(0.55f, 0.90f, 0.55f, 1.0f);
vec4 ARL_SidebarBg       = vec4(0.10f, 0.10f, 0.12f, 1.0f);
vec4 ARL_SidebarSelBg    = vec4(0.20f, 0.35f, 0.22f, 0.70f);
vec4 ARL_SidebarHoverBg  = vec4(0.18f, 0.28f, 0.20f, 0.50f);
vec4 ARL_ContextBg       = vec4(0.12f, 0.12f, 0.14f, 1.0f);
vec4 ARL_HeaderBg        = vec4(0.16f, 0.28f, 0.18f, 0.80f);
vec4 ARL_HeaderHoverBg   = vec4(0.22f, 0.38f, 0.24f, 0.80f);
vec4 ARL_HeaderActiveBg  = vec4(0.28f, 0.48f, 0.30f, 0.80f);
vec4 ARL_UnloadBtnCol    = vec4(0.70f, 0.25f, 0.25f, 1.0f);
vec4 ARL_UnloadBtnHover  = vec4(0.85f, 0.30f, 0.30f, 1.0f);
vec4 ARL_UnloadBtnActive = vec4(0.95f, 0.35f, 0.35f, 1.0f);

string g_LoadedFilter = "";
int g_LoadedExpandedIdx = -1;
int g_LoadedSortCol = -1;
bool g_LoadedSortAsc = true;
array<bool> g_LoadedSelected;

string ARL_Pad(uint value, uint length) {
    string s = "" + value;
    while (s.Length < length) s = "0" + s;
    return s;
}

void RenderMenu() {
    if (UI::MenuItem(Colorize(Icons::SnapchatGhost + Icons::Magic + Icons::FileO, {"#aaceac", "#c5d0a8", "#6ec9a8"}) + "\\$g" + " Arbitrary Record Loader", "", S_ARL_WindowOpen)) {
        S_ARL_WindowOpen = !S_ARL_WindowOpen;
    }
}

string ARL_FormatMs(int ms) {
    if (ms < 0) return "-";
    uint ums = uint(ms);
    uint minutes = ums / 60000;
    uint seconds = (ums % 60000) / 1000;
    uint milliseconds = ums % 1000;
    return ARL_Pad(minutes, 2) + ":" + ARL_Pad(seconds, 2) + "." + ARL_Pad(milliseconds, 3);
}

string ARL_FormatTimeAgo(uint loadedAt) {
    uint now = Time::Now;
    if (now <= loadedAt) return "just now";
    uint diff = now - loadedAt;
    uint secs = diff / 1000;
    if (secs < 60) return "" + secs + "s ago";
    uint mins = secs / 60;
    if (mins < 60) return "" + mins + "m ago";
    uint hrs = mins / 60;
    if (hrs < 24) return "" + hrs + "h " + (mins % 60) + "m ago";
    uint days = hrs / 24;
    return "" + days + "d " + (hrs % 24) + "h ago";
}

string ARL_ShortPath(const string &in s, uint maxLen = 64) {
    if (uint(s.Length) <= maxLen) return s;
    uint keep = maxLen / 2;
    return s.SubStr(0, keep) + "..." + s.SubStr(uint(s.Length) - keep);
}

string ARL_GetGhostName(LoadedRecords::LoadedItem@ it) {
    if (it is null) return "(ghost)";
    if (it.ghost !is null) {
        if (it.ghost.Nickname.Length > 0) return it.ghost.Nickname;
        else if (it.ghost.IdName.Length > 0) return it.ghost.IdName;
    }
    return "(ghost)";
}

int ARL_GetGhostTime(LoadedRecords::LoadedItem@ it) {
    if (it is null || it.ghost is null) return -1;
    if (it.ghost.Result.Time > 0) return it.ghost.Result.Time;
    return -1;
}

int ARL_CompareItems(int idxA, int idxB) {
    auto a = LoadedRecords::items[uint(idxA)];
    auto b = LoadedRecords::items[uint(idxB)];
    int result = 0;
    switch (g_LoadedSortCol) {
        case 0: {
            int va = (a !is null && a.isLoaded) ? 1 : 0;
            int vb = (b !is null && b.isLoaded) ? 1 : 0;
            result = va - vb;
            break;
        }
        case 1: {
            string la = Text::StripFormatCodes(ARL_GetGhostName(a)).ToLower();
            string lb = Text::StripFormatCodes(ARL_GetGhostName(b)).ToLower();
            if (la < lb) result = -1;
            else if (la > lb) result = 1;
            break;
        }
        case 2: {
            int ta = ARL_GetGhostTime(a);
            int tb = ARL_GetGhostTime(b);
            result = ta - tb;
            break;
        }
        case 3: {
            string sa = (a !is null) ? LoadedRecords::SourceKindToString(a.source) : "";
            string sb = (b !is null) ? LoadedRecords::SourceKindToString(b.source) : "";
            if (sa < sb) result = -1;
            else if (sa > sb) result = 1;
            break;
        }
    }
    return g_LoadedSortAsc ? result : -result;
}

array<int> ARL_BuildSortedIndices(const array<int> &in filtered) {
    array<int> sorted = filtered;
    if (g_LoadedSortCol < 0) return sorted;
    for (uint i = 1; i < sorted.Length; i++) {
        int key = sorted[i];
        int j = int(i) - 1;
        while (j >= 0 && ARL_CompareItems(sorted[j], key) > 0) {
            sorted[j + 1] = sorted[j];
            j--;
        }
        sorted[j + 1] = key;
    }
    return sorted;
}

bool ARL_MatchesFilter(LoadedRecords::LoadedItem@ it) {
    if (g_LoadedFilter.Length == 0) return true;
    string lf = g_LoadedFilter.ToLower();
    string name = Text::StripFormatCodes(ARL_GetGhostName(it)).ToLower();
    if (name.Contains(lf)) return true;
    string src = LoadedRecords::SourceKindToString(it.source).ToLower();
    if (src.Contains(lf)) return true;
    string srcRef = it.sourceRef.ToLower();
    if (srcRef.Contains(lf)) return true;
    return false;
}

void ARL_ClickSortHeader(int col) {
    if (g_LoadedSortCol == col) {
        g_LoadedSortAsc = !g_LoadedSortAsc;
    } else {
        g_LoadedSortCol = col;
        g_LoadedSortAsc = true;
    }
}

void ARL_PageHeader(const string &in title, const string &in subtitle = "") {
    UI::PushFontSize(20);
    UI::Text("\\$fff" + title);
    UI::PopFontSize();
    if (subtitle.Length > 0) {
        UI::TextDisabled(subtitle);
    }
    UI::Dummy(vec2(0, 2));
    UI::PushStyleColor(UI::Col::Separator, ARL_AccentDimCol);
    UI::Separator();
    UI::PopStyleColor();
    UI::Dummy(vec2(0, 4));
}

void ARL_RenderContextBar() {
    string mapName = get_CurrentMapName();
    if (mapName.Length > 0) mapName = Text::StripFormatCodes(mapName);
    string mapUid = get_CurrentMapUID();

    string mode = GameCtx::GetModeName();

    bool cmapOk = GameCtx::GetCMap() !is null;
    bool dfmOk = GameCtx::GetDFM() !is null;
    bool gmOk = GameCtx::GetGhostMgr() !is null;

    string allowStr = "Allow: n/a";
    if (mapUid.Length > 0) {
        if (AllowCheck::allownessModules.Length == 0) {
            allowStr = "Allow: (init)";
        } else if (AllowCheck::ConditionCheckMet()) {
            allowStr = "\\$0f0" + Icons::Check + " OK\\$z";
        } else {
            allowStr = "\\$f00" + Icons::Times + " BLOCKED\\$z";
        }
    }

    UI::PushStyleColor(UI::Col::ChildBg, ARL_ContextBg);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(6, 2));
    if (UI::BeginChild("ARL_ContextBar", vec2(0, 44), true)) {
        UI::Text(Icons::Map);
        UI::SameLine();
        if (mapUid.Length == 0) {
            UI::TextDisabled("(no map loaded)");
        } else {
            UI::Text("\\$fff" + mapName);
            UI::SameLine();
            UI::TextDisabled(mapUid);
        }

        if (mode.Length > 0) {
            UI::SameLine();
            UI::TextDisabled(" | ");
            UI::SameLine();
            UI::Text(Icons::Gamepad + " " + mode);
        }

        UI::SameLine();
        UI::TextDisabled(" | ");
        UI::SameLine();
        UI::Text(allowStr);

        UI::SameLine();
        UI::TextDisabled(" | ");
        UI::SameLine();
        UI::Text(
            (cmapOk ? "\\$0f0" : "\\$f00") + "cmap\\$z "
            + (dfmOk ? "\\$0f0" : "\\$f00") + "dfm\\$z "
            + (gmOk ? "\\$0f0" : "\\$f00") + "ghost\\$z"
        );

        if (mapUid.Length > 0 && AllowCheck::allownessModules.Length > 0 && !AllowCheck::ConditionCheckMet()) {
            UI::Text("\\$f90" + Icons::ExclamationTriangle + " " + AllowCheck::DisallowReason() + "\\$z");
        }
    }
    UI::EndChild();
    UI::PopStyleVar(2);
    UI::PopStyleColor();
}

void ARL_RenderSidebar() {
    UI::PushStyleColor(UI::Col::ChildBg, ARL_SidebarBg);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
    if (!UI::BeginChild("ARL_Sidebar", vec2(0, 0), true)) {
        UI::EndChild();
        UI::PopStyleVar();
        UI::PopStyleColor();
        return;
    }

    UI::Dummy(vec2(0, 4));

    UI::PushStyleColor(UI::Col::Header, ARL_SidebarSelBg);
    UI::PushStyleColor(UI::Col::HeaderHovered, ARL_SidebarHoverBg);
    UI::PushStyleColor(UI::Col::HeaderActive, ARL_SidebarSelBg);
    UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(8, 5));

    if (UI::Selectable(Icons::Download + "  Load", g_ARL_Page == ARL_Page::Load)) g_ARL_Page = ARL_Page::Load;
    if (UI::Selectable(Icons::List + "  Loaded", g_ARL_Page == ARL_Page::Loaded)) g_ARL_Page = ARL_Page::Loaded;
    if (LoadedRecords::items.Length > 0) {
        UI::SameLine();
        UI::PushStyleColor(UI::Col::Text, ARL_AccentCol);
        UI::Text("(" + LoadedRecords::items.Length + ")");
        UI::PopStyleColor();
    }
    if (UI::Selectable(Icons::FolderOpen + "  Library", g_ARL_Page == ARL_Page::Library)) g_ARL_Page = ARL_Page::Library;
    if (UI::Selectable(Icons::KeyboardO + "  Hotkeys", g_ARL_Page == ARL_Page::Hotkeys)) g_ARL_Page = ARL_Page::Hotkeys;
    if (UI::Selectable(Icons::Wrench + "  Settings", g_ARL_Page == ARL_Page::SettingsDev)) g_ARL_Page = ARL_Page::SettingsDev;

    UI::PopStyleVar();
    UI::PopStyleColor(3);

    UI::Dummy(vec2(0, 8));
    UI::PushStyleColor(UI::Col::Separator, vec4(0.3f, 0.3f, 0.35f, 0.5f));
    UI::Separator();
    UI::PopStyleColor();
    UI::Dummy(vec2(0, 8));

    UI::PushStyleColor(UI::Col::Button, ARL_UnloadBtnCol);
    UI::PushStyleColor(UI::Col::ButtonHovered, ARL_UnloadBtnHover);
    UI::PushStyleColor(UI::Col::ButtonActive, ARL_UnloadBtnActive);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 4.0f);
    UI::BeginDisabled(LoadedRecords::items.Length == 0);
    if (UI::Button(Icons::UserTimes + " Unload All", vec2(-1, 0))) {
        LoadedRecords::UnloadAll();
    }
    UI::EndDisabled();
    UI::PopStyleVar();
    UI::PopStyleColor(3);

    UI::EndChild();
    UI::PopStyleVar();
    UI::PopStyleColor();
}

void ARL_RenderPage_Load() {
    ARL_PageHeader("Load", "Import ghosts/replays from different sources.");

    UI::PushStyleColor(UI::Col::Tab, ARL_HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, ARL_HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, ARL_HeaderActiveBg);

    UI::BeginTabBar("ARL_LoadTabs");

    if (UI::BeginTabItem(Icons::FolderOpen + " Local Files")) {
        UI::Dummy(vec2(0, 4));
        Features::LRFromFile::RT_LRFromLocalFiles();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Link + " URL")) {
        UI::Dummy(vec2(0, 4));
        Features::LRFromUrl::RT_LRFromUrl();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Map + " Map UID + Rank")) {
        UI::Dummy(vec2(0, 4));
        Features::LRFromMapIdentifier::RT_LRFromMapUid();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::IdCard + " Player ID")) {
        UI::Dummy(vec2(0, 4));
        Features::LRFromPlayerId::RT_LRFromPlayerID();
        UI::Dummy(vec2(0, 2));
        UI::TextDisabled("Loads this player's record on the current map via Nadeo API.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Globe + " Official")) {
        UI::Dummy(vec2(0, 4));
        Features::LRFromOfficialMaps::RT_LRFromOfficialMaps();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Map + " Current Map")) {
        UI::Dummy(vec2(0, 4));
        string _cmMapName = get_CurrentMapName();
        if (_cmMapName.Length > 0) _cmMapName = Text::StripFormatCodes(_cmMapName);
        UI::AlignTextToFramePadding();
        UI::TextDisabled(Icons::Map + " " + (_cmMapName.Length > 0 ? _cmMapName : "(no map loaded)"));
        UI::Dummy(vec2(0, 4));

        if (UI::CollapsingHeader(Icons::Trophy + " Validation Replay")) {
            if (Features::LRBasedOnCurrentMap::ValidationReplay::ValidationReplayExists()) {
                Features::LRBasedOnCurrentMap::RTPart_ValidationReplay();
            } else {
                UI::TextDisabled("No validation replay available for this map.");
            }
        }

        if (UI::CollapsingHeader(Icons::Certificate + " Medal Ghosts")) {
            Features::LRBasedOnCurrentMap::RTPart_MedalTable();
        }
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}

bool g_LoadedShowAllGhosts = false;

void ARL_RenderPage_Loaded() {
    ARL_PageHeader("Loaded");

    while (g_LoadedSelected.Length < LoadedRecords::items.Length)
        g_LoadedSelected.InsertLast(false);
    while (g_LoadedSelected.Length > LoadedRecords::items.Length)
        g_LoadedSelected.RemoveAt(g_LoadedSelected.Length - 1);

    int selectedCount = 0;
    for (uint sc = 0; sc < g_LoadedSelected.Length; sc++) {
        if (g_LoadedSelected[sc]) selectedCount++;
    }

    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
    g_LoadedShowAllGhosts = UI::Checkbox("Show all game ghosts", g_LoadedShowAllGhosts);
    _UI::SimpleTooltip("When enabled, shows ALL ghosts known to the game engine — not just those loaded by ARL.");

    UI::SameLine();
    UI::Dummy(vec2(16, 0));
    UI::SameLine();

    if (!g_LoadedShowAllGhosts) {
        UI::AlignTextToFramePadding();
        UI::Text("\\$fff" + Icons::SnapchatGhost + " " + LoadedRecords::items.Length + " ARL ghosts");
        UI::SameLine();
        UI::Dummy(vec2(8, 0));
        UI::SameLine();
        if (UI::Button(Icons::TrashO + " Clear List")) {
            LoadedRecords::Clear();
            g_LoadedSelected.RemoveRange(0, g_LoadedSelected.Length);
            g_LoadedExpandedIdx = -1;
        }
    } else {
        auto dfm = GameCtx::GetDFM();
        int allCount = (dfm !is null) ? int(dfm.Ghosts.Length) : 0;
        UI::AlignTextToFramePadding();
        UI::Text("\\$fff" + Icons::SnapchatGhost + " " + allCount + " total ghosts in game");
    }
    UI::PopStyleVar();

    if (selectedCount > 0) {
        UI::Dummy(vec2(0, 2));
        UI::PushStyleColor(UI::Col::ChildBg, vec4(0.18f, 0.28f, 0.20f, 0.60f));
        UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
        if (UI::BeginChild("ARL_BulkBar", vec2(0, 32), true)) {
            UI::AlignTextToFramePadding();
            UI::PushStyleColor(UI::Col::Text, ARL_AccentBrightCol);
            UI::Text("" + selectedCount + " selected");
            UI::PopStyleColor();
            UI::SameLine();
            UI::Dummy(vec2(8, 0));
            UI::SameLine();
            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
            if (UI::Button(Icons::EyeSlash + " Hide Selected")) {
                for (uint bi = 0; bi < g_LoadedSelected.Length; bi++) {
                    if (g_LoadedSelected[bi] && bi < LoadedRecords::items.Length)
                        LoadedRecords::Unload(LoadedRecords::items[bi]);
                }
            }
            UI::SameLine();
            if (UI::Button(Icons::Eye + " Show Selected")) {
                for (uint bi = 0; bi < g_LoadedSelected.Length; bi++) {
                    if (g_LoadedSelected[bi] && bi < LoadedRecords::items.Length)
                        LoadedRecords::Reload(LoadedRecords::items[bi]);
                }
            }
            UI::SameLine();
            UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65f, 0.22f, 0.22f, 1.0f));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80f, 0.28f, 0.28f, 1.0f));
            if (UI::Button(Icons::Times + " Forget Selected")) {
                for (int bi = int(g_LoadedSelected.Length) - 1; bi >= 0; bi--) {
                    if (g_LoadedSelected[bi] && uint(bi) < LoadedRecords::items.Length) {
                        LoadedRecords::items.RemoveAt(uint(bi));
                        g_LoadedSelected.RemoveAt(uint(bi));
                    }
                }
                g_LoadedExpandedIdx = -1;
            }
            UI::PopStyleColor(3);
            UI::PopStyleVar();
            UI::EndChild();
        }
        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    UI::Dummy(vec2(0, 4));

    if (g_LoadedShowAllGhosts) {
        ARL_RenderAllGameGhosts();
        return;
    }


    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
    UI::PushItemWidth(-1);
    g_LoadedFilter = UI::InputText(Icons::Search + " ##ARL_LoadedFilter", g_LoadedFilter);
    UI::PopItemWidth();
    UI::PopStyleVar();
    _UI::SimpleTooltip("Filter by ghost name, source type, or source path");

    UI::Dummy(vec2(0, 4));

    if (LoadedRecords::items.Length == 0) {
        UI::Dummy(vec2(0, 20));
        UI::PushFontSize(16);
        UI::TextDisabled(Icons::SnapchatGhost + "  No ARL-tracked ghosts.");
        UI::PopFontSize();
        UI::Dummy(vec2(0, 4));
        UI::TextDisabled("Use the Load page to import ghosts from files, URLs, or leaderboards.");
        UI::TextDisabled("Toggle \"Show all game ghosts\" above to see every ghost the game has loaded.");
        auto _dfmCheck = GameCtx::GetDFM();
        if (_dfmCheck !is null && _dfmCheck.Ghosts.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled(Icons::InfoCircle + " The game currently has " + _dfmCheck.Ghosts.Length + " ghost(s) loaded — enable the toggle to see them.");
        }
        return;
    }

    array<int> filteredIndices;
    for (int fi = 0; fi < int(LoadedRecords::items.Length); fi++) {
        auto fit = LoadedRecords::items[uint(fi)];
        if (fit is null) continue;
        if (!ARL_MatchesFilter(fit)) continue;
        filteredIndices.InsertLast(fi);
    }
    array<int> sortedIndices = ARL_BuildSortedIndices(filteredIndices);

    if (sortedIndices.Length == 0) {
        UI::TextDisabled("No items match the filter.");
        return;
    }

    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
    UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));

    int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::Resizable | UI::TableFlags::ScrollY;
    if (UI::BeginTable("ARL_LoadedTable", 8, flags, vec2(0, 0))) {
        UI::TableSetupColumn("##Sel", UI::TableColumnFlags::WidthFixed, 30);
        UI::TableSetupColumn("State", UI::TableColumnFlags::WidthFixed, 60);
        UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
        UI::TableSetupColumn("Source", UI::TableColumnFlags::WidthFixed, 80);
        UI::TableSetupColumn("Ref", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Label", UI::TableColumnFlags::WidthFixed, 140);
        UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, 220);

        UI::TableNextRow(UI::TableRowFlags::Headers);

        UI::TableNextColumn();
        bool allSel = (selectedCount > 0 && selectedCount == int(sortedIndices.Length));
        bool newAll = UI::Checkbox("##ARL_SelAll", allSel);
        if (newAll != allSel) {
            for (uint hi = 0; hi < sortedIndices.Length; hi++) {
                uint idx = uint(sortedIndices[hi]);
                if (idx < g_LoadedSelected.Length) g_LoadedSelected[idx] = newAll;
            }
        }

        array<string> sortColNames = {"State", "Name", "Time", "Source"};
        for (int ci = 0; ci < 4; ci++) {
            UI::TableNextColumn();
            string arrow = "";
            if (g_LoadedSortCol == ci) arrow = g_LoadedSortAsc ? " \\$aaa" + Icons::ChevronUp : " \\$aaa" + Icons::ChevronDown;
            if (UI::Selectable(sortColNames[ci] + arrow + "##ARL_SortH_" + ci, false)) {
                ARL_ClickSortHeader(ci);
            }
        }

        UI::TableNextColumn(); UI::Text("Ref");
        UI::TableNextColumn(); UI::Text("Label");
        UI::TableNextColumn(); UI::Text("Actions");

        uint medalAT = 0, medalGold = 0, medalSilver = 0, medalBronze = 0;
        auto _rootMap = GetApp().RootMap;
        if (_rootMap !is null && _rootMap.ChallengeParameters !is null) {
            medalAT = _rootMap.ChallengeParameters.AuthorTime;
            medalGold = _rootMap.ChallengeParameters.GoldTime;
            medalSilver = _rootMap.ChallengeParameters.SilverTime;
            medalBronze = _rootMap.ChallengeParameters.BronzeTime;
        }

        for (uint ri = 0; ri < sortedIndices.Length; ri++) {
            int i = sortedIndices[ri];
            auto it = LoadedRecords::items[uint(i)];
            if (it is null) continue;

            string name = ARL_GetGhostName(it);
            int ghostTime = 0;
            string timeScore = "-";
            if (it.ghost !is null) {
                if (it.ghost.Result.Time > 0) {
                    ghostTime = it.ghost.Result.Time;
                    timeScore = ARL_FormatMs(ghostTime);
                } else if (it.ghost.Result.Score > 0) {
                    timeScore = "" + it.ghost.Result.Score;
                }
            }

            UI::TableNextRow();

            UI::TableNextColumn();
            bool sel = (uint(i) < g_LoadedSelected.Length) ? g_LoadedSelected[uint(i)] : false;
            bool newSel = UI::Checkbox("##ARL_Sel_" + i, sel);
            if (newSel != sel && uint(i) < g_LoadedSelected.Length) g_LoadedSelected[uint(i)] = newSel;

            UI::TableNextColumn();
            if (it.isLoaded) {
                UI::PushStyleColor(UI::Col::Text, ARL_AccentCol);
                UI::Text(Icons::Eye + " On");
                UI::PopStyleColor();
            } else {
                if (it.ghost is null) {
                    UI::Text("\\$f00" + Icons::ExclamationTriangle + " Lost\\$z");
                    _UI::SimpleTooltip("Ghost reference lost — cannot be re-shown.\nThis can happen after a map change.");
                } else {
                    UI::TextDisabled(Icons::EyeSlash + " Off");
                    _UI::SimpleTooltip("Ghost is hidden. Click the eye button to show it again.");
                }
            }

            UI::TableNextColumn();
            if (UI::Selectable(name + "##ARL_NameSel_" + i, g_LoadedExpandedIdx == i)) {
                g_LoadedExpandedIdx = (g_LoadedExpandedIdx == i) ? -1 : i;
            }

            UI::TableNextColumn();
            if (ghostTime > 0 && medalAT > 0) {
                string medalColor = "\\$fff";
                string medalTip = "";
                if (uint(ghostTime) <= medalAT) {
                    medalColor = "\\$7e0";
                    medalTip = "Beats Author Time (" + ARL_FormatMs(int(medalAT)) + ")";
                } else if (uint(ghostTime) <= medalGold) {
                    medalColor = "\\$fd0";
                    medalTip = "Beats Gold (" + ARL_FormatMs(int(medalGold)) + ")";
                } else if (uint(ghostTime) <= medalSilver) {
                    medalColor = "\\$ddd";
                    medalTip = "Beats Silver (" + ARL_FormatMs(int(medalSilver)) + ")";
                } else if (uint(ghostTime) <= medalBronze) {
                    medalColor = "\\$c73";
                    medalTip = "Beats Bronze (" + ARL_FormatMs(int(medalBronze)) + ")";
                } else {
                    medalColor = "\\$999";
                    medalTip = "Below Bronze (" + ARL_FormatMs(int(medalBronze)) + ")";
                }
                UI::Text(medalColor + timeScore + "\\$z");
                if (medalTip.Length > 0) {
                    string fullTip = medalTip;
                    if (it.loadedAt > 0) fullTip += "\nLoaded " + ARL_FormatTimeAgo(it.loadedAt);
                    _UI::SimpleTooltip(fullTip);
                }
            } else {
                UI::Text(timeScore);
                if (it.loadedAt > 0) {
                    _UI::SimpleTooltip("Loaded " + ARL_FormatTimeAgo(it.loadedAt));
                }
            }

            UI::TableNextColumn();
            UI::TextDisabled(LoadedRecords::SourceKindToString(it.source));

            UI::TableNextColumn();
            UI::TextDisabled(ARL_ShortPath(it.sourceRef, 60));
            if (it.sourceRef.Length > 0) {
                string tip = it.sourceRef;
                if (it.mapUid.Length > 0) tip += "\nMapUid: " + it.mapUid;
                if (it.accountId.Length > 0) tip += "\nAccountId: " + it.accountId;
                _UI::SimpleTooltip(tip);
            }

            UI::TableNextColumn();
            UI::PushItemWidth(-1);
            it.dossard = UI::InputText("Dossard##ARL_Dossard_" + i, it.dossard);
            UI::PopItemWidth();

            UI::TableNextColumn();
            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

            if (it.isLoaded) {
                if (UI::Button(Icons::EyeSlash + "##ARL_Hide_" + i, vec2(28, 0))) {
                    LoadedRecords::Unload(it);
                }
                _UI::SimpleTooltip("Hide ghost");
            } else {
                UI::BeginDisabled(it.ghost is null);
                if (UI::Button(Icons::Eye + "##ARL_Show_" + i, vec2(28, 0))) {
                    LoadedRecords::Reload(it);
                }
                UI::EndDisabled();
                _UI::SimpleTooltip("Show ghost");
            }

            UI::SameLine();
            UI::BeginDisabled(!it.isLoaded || it.dossard.Length == 0);
            if (UI::Button(Icons::Tag + "##ARL_SetDossard_" + i, vec2(28, 0))) {
                auto gm = GameCtx::GetGhostMgr();
                if (gm !is null) {
                    gm.Ghost_SetDossard(it.instId, it.dossard, vec3());
                }
            }
            UI::EndDisabled();
            _UI::SimpleTooltip("Apply label as dossard overlay");

            UI::SameLine();
            bool canOpenFolder = it.sourceRef.Length > 0 && IO::FileExists(it.sourceRef);
            UI::BeginDisabled(!canOpenFolder);
            if (UI::Button(Icons::FolderOpen + "##ARL_OpenFolder_" + i, vec2(28, 0))) {
                _IO::OpenFolder(Path::GetDirectoryName(it.sourceRef));
            }
            UI::EndDisabled();
            _UI::SimpleTooltip("Open containing folder");

            UI::SameLine();
            UI::BeginDisabled(it.ghost is null || SavedRecords::_saving);
            if (UI::Button(Icons::FloppyO + "##ARL_Save_" + i, vec2(28, 0))) {
                SavedRecords::SaveFromLoaded(it);
            }
            UI::EndDisabled();
            _UI::SimpleTooltip("Save to library");

            UI::SameLine();
            UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65f, 0.22f, 0.22f, 1.0f));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80f, 0.28f, 0.28f, 1.0f));
            if (UI::Button(Icons::Times + "##ARL_Forget_" + i, vec2(28, 0))) {
                LoadedRecords::items.RemoveAt(uint(i));
                if (uint(i) < g_LoadedSelected.Length) g_LoadedSelected.RemoveAt(uint(i));
                if (g_LoadedExpandedIdx == i) g_LoadedExpandedIdx = -1;
                else if (g_LoadedExpandedIdx > i) g_LoadedExpandedIdx--;
            }
            UI::PopStyleColor(3);
            _UI::SimpleTooltip("Remove from ARL list (ghost stays loaded if visible)");

            UI::PopStyleVar();

            if (g_LoadedExpandedIdx == i) {
                UI::TableNextRow();
                UI::TableNextColumn();
                UI::TableNextColumn();

                UI::TableNextColumn();
                UI::PushStyleColor(UI::Col::Text, vec4(0.80f, 0.85f, 0.80f, 1.0f));
                UI::Dummy(vec2(0, 2));

                if (it.ghost !is null) {
                    UI::Text("\\$aaaFull Nickname: \\$fff" + it.ghost.Nickname);
                    UI::Text("\\$aaaTrigram: \\$fff" + it.ghost.Trigram);
                    UI::Text("\\$aaaCountry Path: \\$fff" + it.ghost.CountryPath);
                } else {
                    UI::TextDisabled("(no ghost reference)");
                }

                UI::Text("\\$aaaSource: \\$fff" + it.sourceRef);
                UI::Text("\\$aaaMap UID: \\$fff" + (it.mapUid.Length > 0 ? it.mapUid : "(none)"));
                UI::Text("\\$aaaAccount ID: \\$fff" + (it.accountId.Length > 0 ? it.accountId : "(none)"));

                if (it.loadedAt > 0) {
                    UI::Text("\\$aaaTime Loaded: \\$fff" + ARL_FormatTimeAgo(it.loadedAt));
                } else {
                    UI::Text("\\$aaaTime Loaded: \\$fff(unknown)");
                }

                UI::Text("\\$aaaGhost Layer: \\$fff" + (it.useGhostLayer ? "Yes" : "No"));
                UI::Text("\\$aaaMwId: \\$fff" + it.instId.Value);

                UI::Dummy(vec2(0, 2));
                UI::PopStyleColor();

                UI::TableNextColumn();
                UI::TableNextColumn();
                UI::TableNextColumn();
                UI::TableNextColumn();
                UI::TableNextColumn();
            }
        }

        UI::EndTable();
    }

    UI::PopStyleVar();
    UI::PopStyleColor();
}

string g_AllGhostsFilter = "";

void ARL_RenderAllGameGhosts() {
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
    UI::PushItemWidth(-1);
    g_AllGhostsFilter = UI::InputText(Icons::Search + " ##ARL_AllGhostsFilter", g_AllGhostsFilter);
    UI::PopItemWidth();
    UI::PopStyleVar();
    _UI::SimpleTooltip("Filter by ghost name or ID");

    UI::Dummy(vec2(0, 4));

    auto dfm = GameCtx::GetDFM();
    if (dfm is null) {
        UI::TextDisabled("DataFileMgr not available (no map loaded?)");
        return;
    }

    auto ghosts = dfm.Ghosts;
    if (ghosts.Length == 0) {
        UI::Dummy(vec2(0, 20));
        UI::PushFontSize(16);
        UI::TextDisabled(Icons::SnapchatGhost + "  No ghosts in game.");
        UI::PopFontSize();
        return;
    }

    string filterLower = g_AllGhostsFilter.ToLower();

    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
    UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));

    int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::Resizable | UI::TableFlags::ScrollY;
    if (UI::BeginTable("ARL_AllGhosts", 7, tflags, vec2(0, 0))) {
        UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("ID Name", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
        UI::TableSetupColumn("Trigram", UI::TableColumnFlags::WidthFixed, 60);
        UI::TableSetupColumn("MwId", UI::TableColumnFlags::WidthFixed, 80);
        UI::TableSetupColumn("ARL", UI::TableColumnFlags::WidthFixed, 35);
        UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 60);
        UI::TableHeadersRow();

        for (uint gi = 0; gi < ghosts.Length; gi++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(ghosts[gi]);
            if (ghost is null) continue;

            string nickname = ghost.Nickname;
            string idName = ghost.IdName;
            string strippedName = Text::StripFormatCodes(nickname).ToLower();
            string strippedId = idName.ToLower();

            if (filterLower.Length > 0) {
                if (!strippedName.Contains(filterLower) && !strippedId.Contains(filterLower))
                    continue;
            }

            bool isARL = (LoadedRecords::FindByInstId(ghost.Id) !is null);

            UI::TableNextRow();

            UI::TableNextColumn();
            UI::Text(nickname.Length > 0 ? nickname : "-");

            UI::TableNextColumn();
            UI::TextDisabled(idName.Length > 0 ? idName : "-");

            UI::TableNextColumn();
            if (ghost.Result.Time > 0)
                UI::Text(ARL_FormatMs(ghost.Result.Time));
            else if (ghost.Result.Score > 0)
                UI::Text("" + ghost.Result.Score);
            else
                UI::Text("-");

            UI::TableNextColumn();
            UI::TextDisabled(ghost.Trigram.Length > 0 ? ghost.Trigram : "-");

            UI::TableNextColumn();
            UI::TextDisabled(Text::Format("%08x", ghost.Id.Value));

            UI::TableNextColumn();
            if (isARL) {
                UI::PushStyleColor(UI::Col::Text, ARL_AccentCol);
                UI::Text(Icons::Check);
                UI::PopStyleColor();
                _UI::SimpleTooltip("Tracked by ARL");
            } else {
                UI::TextDisabled("-");
            }

            UI::TableNextColumn();
            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
            if (UI::Button(Icons::EyeSlash + "##ag_rm_" + gi, vec2(28, 0))) {
                auto gm = GameCtx::GetGhostMgr();
                if (gm !is null) {
                    gm.Ghost_Remove(ghost.Id);
                    auto arlItem = LoadedRecords::FindByInstId(ghost.Id);
                    if (arlItem !is null) arlItem.isLoaded = false;
                }
            }
            _UI::SimpleTooltip("Remove this ghost from the game");
            UI::SameLine();
            if (UI::Button(Icons::InfoCircle + "##ag_info_" + gi, vec2(28, 0))) {
                string info = "Nickname: " + nickname
                    + "\nIdName: " + idName
                    + "\nTrigram: " + ghost.Trigram
                    + "\nCountry: " + ghost.CountryPath
                    + "\nTime: " + ARL_FormatMs(ghost.Result.Time)
                    + "\nScore: " + ghost.Result.Score
                    + "\nMwId: " + Text::Format("%08x", ghost.Id.Value);
                IO::SetClipboard(info);
            }
            _UI::SimpleTooltip("Copy ghost info to clipboard");
            UI::PopStyleVar();
        }

        UI::EndTable();
    }

    UI::PopStyleVar();
    UI::PopStyleColor();
}

void ARL_RenderPage_Library() {
    ARL_PageHeader("Library", "Saved items and profiles.");

    UI::PushStyleColor(UI::Col::Tab, ARL_HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, ARL_HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, ARL_HeaderActiveBg);

    UI::BeginTabBar("ARL_LibraryTabs");

    if (UI::BeginTabItem(Icons::Kenney::Save + " Saved")) {
        UI::Dummy(vec2(0, 4));
        Features::LRFromSaved::RT_LRFromSaved();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::File + " Profiles (JSON)")) {
        UI::Dummy(vec2(0, 4));
        Features::LRFromProfile::RT_LRFromProfile();
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}

void ARL_RenderPage_Hotkeys() {
    ARL_PageHeader("Hotkeys");
    Features::Hotkeys::RT_Hotkeys();
}

void ARL_RenderPage_SettingsDev() {
    ARL_PageHeader("Settings / Dev");

    UI::PushStyleColor(UI::Col::Tab, ARL_HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, ARL_HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, ARL_HeaderActiveBg);

    UI::BeginTabBar("ARL_SettingsTabs");

    if (UI::BeginTabItem(Icons::Cogs + " Behavior")) {
        UI::Dummy(vec2(0, 4));
        GhostLoader::S_UseGhostLayer = UI::Checkbox("Use Ghost Layer (recommended)", GhostLoader::S_UseGhostLayer);
        _UI::SimpleTooltip("Places ghosts on the ghost layer instead of the main layer.");
        UI::TextDisabled("Ghost layer renders ghosts with standard ghost transparency.");
        UI::TextDisabled("Main layer renders ghosts as fully opaque cars.");
        MapTracker::enableGhosts = UI::Checkbox("Enable auto-load on map change", MapTracker::enableGhosts);
        _UI::SimpleTooltip("Automatically run Automation tasks when entering a new map.");
        UI::Dummy(vec2(0, 8));
        UI::Separator();
        UI::Dummy(vec2(0, 4));
        UI::Text("Defaults");
        g_DefaultRankOffset = UI::InputInt("Default Rank Offset", g_DefaultRankOffset);
        _UI::SimpleTooltip("Default rank when loading from Map UID, Profiles, or Official Campaigns. 0 = world record.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Folder + " Folders")) {
        UI::Dummy(vec2(0, 4));
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        if (UI::Button(Icons::FolderOpen + " ARL Root")) _IO::OpenFolder(Server::replayARL);
        UI::TextDisabled(Server::replayARL);
        UI::Dummy(vec2(0, 4));

        if (UI::Button(Icons::FolderOpen + " Downloaded")) _IO::OpenFolder(Server::specificDownloadedFilesDirectory);
        UI::TextDisabled(Server::specificDownloadedFilesDirectory);
        UI::Dummy(vec2(0, 4));

        if (UI::Button(Icons::FolderOpen + " Official")) _IO::OpenFolder(Server::officialFilesDirectory);
        UI::TextDisabled(Server::officialFilesDirectory);

        UI::Dummy(vec2(0, 8));
        UI::Separator();
        UI::Dummy(vec2(0, 4));
        if (UI::Button(Icons::TrashO + " Clear Staging Folder")) {
            array<string>@ files = IO::IndexFolder(Server::serverDirectoryAutoMove, false);
            if (files !is null) {
                for (uint i = 0; i < files.Length; i++) {
                    IO::Delete(files[i]);
                }
            }
        }
        _UI::SimpleTooltip("Remove temporary files from the AutoMove staging directory");
        UI::PopStyleVar();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::DevTo + " Logging")) {
        UI::Dummy(vec2(0, 4));
        UI::TextDisabled("Plugin log output. Check Openplanet console for full logs.");
        UI::Dummy(vec2(0, 4));
        DEV::RT_LOGs();
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}

void ARL_RenderPage() {
    switch (g_ARL_Page) {
        case ARL_Page::Load:        ARL_RenderPage_Load(); break;
        case ARL_Page::Loaded:      ARL_RenderPage_Loaded(); break;
        case ARL_Page::Library:     ARL_RenderPage_Library(); break;
        case ARL_Page::Hotkeys:     ARL_RenderPage_Hotkeys(); break;
        case ARL_Page::SettingsDev: ARL_RenderPage_SettingsDev(); break;
    }
}

void RenderInterface() {
    FILE_EXPLORER_BASE_RENDERER();
    Features::Hotkeys::HKInterfaceModule::RenderInterface();

    if (!S_ARL_WindowOpen) return;

    UI::SetNextWindowSize(980, 680, UI::Cond::FirstUseEver);

    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 10));
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);

    if (UI::Begin(Icons::UserPlus + " Arbitrary Record Loader", S_ARL_WindowOpen, UI::WindowFlags::NoCollapse)) {
        ARL_RenderContextBar();

        UI::Dummy(vec2(0, 4));

        int tableFlags = UI::TableFlags::SizingFixedFit | UI::TableFlags::BordersInnerV;
        if (UI::BeginTable("ARL_MainLayout", 2, tableFlags, vec2(0, 0))) {
            UI::TableSetupColumn("Sidebar", UI::TableColumnFlags::WidthFixed, 180);
            UI::TableSetupColumn("Content", UI::TableColumnFlags::WidthStretch);
            UI::TableNextRow();
            UI::TableNextColumn();
            ARL_RenderSidebar();
            UI::TableNextColumn();
            UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(12, 8));
            UI::BeginChild("ARL_Content", vec2(0, 0), false);
            ARL_RenderPage();
            UI::EndChild();
            UI::PopStyleVar();
            UI::EndTable();
        }
    }
    UI::End();

    UI::PopStyleVar(3);
}
