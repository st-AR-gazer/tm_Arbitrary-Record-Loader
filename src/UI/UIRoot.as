[Setting category="General" name="Window Open"]
bool windowOpen = false;

[Setting category="General" name="Settings Window Open"]
bool settingsWindowOpen = false;

enum WindowPage {
    Load = 0,
    Loaded,
    Library,
    Help,
    Automation
}

WindowPage g_WindowPage = WindowPage::Load;

int g_DefaultRankOffset = 1;

string g_LoadedFilter = "";
int g_LoadedExpandedIdx = -1;
int g_LoadedSortCol = -1;
bool g_LoadedSortAsc = true;
array<bool> g_LoadedSelected;

void RenderMenu() {
    if (UI::MenuItem(Colorize(Icons::SnapchatGhost + Icons::Magic + Icons::FileO, {"#aca", "#cda", "#6ca"}) + "\\$g" + " Arbitrary Record Loader", "", windowOpen)) {
        windowOpen = !windowOpen;
    }
    if (UI::MenuItem(Icons::Cogs + " ARL Settings", "", settingsWindowOpen)) {
        settingsWindowOpen = !settingsWindowOpen;
    }
}

float SearchInputWidth() {
    float w = UI::GetFontSize() * 28.0f;
    w = Math::Max(260.0f, w);
    w = Math::Min(700.0f, w);
    float avail = UI::GetContentRegionAvail().x;
    if (avail > 0) w = Math::Min(w, avail);
    return w;
}

float LongInputWidth() {
    float w = UI::GetFontSize() * 46.0f;
    w = Math::Max(340.0f, w);
    w = Math::Min(1100.0f, w);
    float avail = UI::GetContentRegionAvail().x;
    if (avail > 0) w = Math::Min(w, avail);
    return w;
}

float GetContentFitColumnWidth(const string &in headerText, const array<string>@ samples, float padding = 16.0f, float minWidth = 0.0f) {
    float width = UI::MeasureString(Text::StripFormatCodes(headerText)).x;
    if (samples !is null) {
        for (uint i = 0; i < samples.Length; i++) {
            width = Math::Max(width, UI::MeasureString(Text::StripFormatCodes(samples[i])).x);
        }
    }
    return Math::Max(minWidth, width + padding);
}

float ApproxTableWidth(const array<float>@ columnWidths, float cellPaddingX = 4.0f) {
    float total = 0.0f;
    if (columnWidths !is null) {
        for (uint i = 0; i < columnWidths.Length; i++) {
            total += columnWidths[i];
        }
        total += columnWidths.Length * (cellPaddingX * 2.0f);
        total += columnWidths.Length + 1.0f;
    }
    return total;
}

string GetGhostName(LoadedRecords::LoadedItem@ it) {
    if (it is null) return "(ghost)";
    if (it.ghost !is null) {
        if (it.ghost.Nickname.Length > 0) return it.ghost.Nickname;
        else if (it.ghost.IdName.Length > 0) return LoadedRecords::VisibleIdName(it.ghost);
    }
    return "(ghost)";
}

int GetGhostTime(LoadedRecords::LoadedItem@ it) {
    if (it is null || it.ghost is null) return -1;
    int expectedTime = LoadedRecords::TryParseExpectedRaceTimeMs(it.sourceRef);
    if (expectedTime > 0) return expectedTime;
    if (it.ghost.Result.Time > 0 && it.ghost.Result.Time < uint(0xFFFFFFFF)) return it.ghost.Result.Time;
    return -1;
}

string FormatGhostPrimaryMetric(CGameGhostScript@ ghost) {
    if (ghost is null) return "-";
    if (ghost.Result.Score > 0) return "Score: " + ghost.Result.Score;
    if (ghost.Result.Time > 0 && ghost.Result.Time < uint(0xFFFFFFFF)) return "Time: " + FormatMs(int(ghost.Result.Time));
    return "Time: -";
}

uint NormalizeGhostRespawns(CGameGhostScript@ ghost) {
    if (ghost is null) return 0;
    uint nb = ghost.Result.NbRespawns;
    return nb == uint(0xFFFFFFFF) ? 0 : nb;
}

string FormatGhostCheckpoints(CGameGhostScript@ ghost) {
    if (ghost is null) return "-";
    string ret = "";
    for (uint i = 0; i < ghost.Result.Checkpoints.Length; i++) {
        if (i > 0) ret += ", ";
        ret += FormatMs(int(ghost.Result.Checkpoints[i]));
    }
    return ret.Length > 0 ? ret : "-";
}

string FormatGhostCheckpointLandmarkIds(CGameGhostScript@ ghost) {
    if (ghost is null) return "-";
    string ret = "";
    for (uint i = 0; i < ghost.Result.CheckpointLandmarkIds.Length; i++) {
        if (i > 0) ret += ", ";
        ret += "" + ghost.Result.CheckpointLandmarkIds[i].Value;
    }
    return ret.Length > 0 ? ret : "-";
}

string FormatGhostSpawnLandmarkId(CGameGhostScript@ ghost) {
    if (ghost is null) return "-";
    return "" + ghost.Result.SpawnLandmarkId.Value;
}

void RenderGhostInspector(CGameGhostScript@ ghost, const string &in idSuffix) {
    if (ghost is null) {
        UI::TextDisabled("(no ghost reference)");
        return;
    }

    string header
        = "IdName: " + LoadedRecords::VisibleIdName(ghost)
        + " | Nick: " + ghost.Nickname
        + " | Trigram: " + ghost.Trigram
        + " | Country: " + ghost.CountryPath
        + " | " + FormatGhostPrimaryMetric(ghost)
        + " | NbRespawns: " + NormalizeGhostRespawns(ghost)
        + " | SpawnLandmarkId: " + FormatGhostSpawnLandmarkId(ghost);

    UI::TextWrapped(header);
    UI::TextWrapped("Checkpoints (" + ghost.Result.Checkpoints.Length + "): " + FormatGhostCheckpoints(ghost));
    UI::TextWrapped("CheckpointLandmarkIds (" + ghost.Result.CheckpointLandmarkIds.Length + "): " + FormatGhostCheckpointLandmarkIds(ghost));
    UI::Dummy(vec2(0, 4));

    if (UI::TreeNode("Raw Ghost Object##" + idSuffix)) {
        UI::PushID("GhostInspector_" + idSuffix);
        UI::NodTree(ghost);
        UI::PopID();
        UI::TreePop();
    }
}

int CompareItems(int idxA, int idxB) {
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
            string la = Text::StripFormatCodes(GetGhostName(a)).ToLower();
            string lb = Text::StripFormatCodes(GetGhostName(b)).ToLower();
            if (la < lb) result = -1;
            else if (la > lb) result = 1;
            break;
        }
        case 2: {
            int ta = GetGhostTime(a);
            int tb = GetGhostTime(b);
            result = ta - tb;
            break;
        }
    }
    return g_LoadedSortAsc ? result : -result;
}

array<int> BuildSortedIndices(const array<int> &in filtered) {
    array<int> sorted = filtered;
    if (g_LoadedSortCol < 0) return sorted;
    for (uint i = 1; i < sorted.Length; i++) {
        int key = sorted[i];
        int j = int(i) - 1;
        while (j >= 0 && CompareItems(sorted[j], key) > 0) {
            sorted[j + 1] = sorted[j];
            j--;
        }
        sorted[j + 1] = key;
    }
    return sorted;
}

bool MatchesFilter(LoadedRecords::LoadedItem@ it) {
    if (g_LoadedFilter.Length == 0) return true;
    string lf = g_LoadedFilter.ToLower();
    string name = Text::StripFormatCodes(GetGhostName(it)).ToLower();
    if (name.Contains(lf)) return true;
    return false;
}

void ClickSortHeader(int col) {
    if (g_LoadedSortCol == col) {
        g_LoadedSortAsc = !g_LoadedSortAsc;
    } else {
        g_LoadedSortCol = col;
        g_LoadedSortAsc = true;
    }
}

void PageHeader(const string &in title, const string &in subtitle = "") {
    UI::PushFontSize(20);
    UI::Text("\\$fff" + title);
    UI::PopFontSize();
    if (subtitle.Length > 0) {
        UI::TextDisabled(subtitle);
    }
    UI::Dummy(vec2(0, 2));
    UI::PushStyleColor(UI::Col::Separator, AccentDimCol);
    UI::Separator();
    UI::PopStyleColor();
    UI::Dummy(vec2(0, 4));
}

void RenderContextBar() {
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

    UI::PushStyleColor(UI::Col::ChildBg, ContextBg);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
    UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(6, 2));
    if (UI::BeginChild("ContextBar", vec2(0, 44), true)) {
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

void RenderNavTabs() {
    LoadedRecords::RecoverMarkedGhostsFromGame();

    UI::PushStyleColor(UI::Col::Tab, HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, HeaderActiveBg);

    UI::BeginTabBar("NavTabs");

    if (UI::BeginTabItem(Icons::Download + " Load")) {
        g_WindowPage = WindowPage::Load;
        UI::EndTabItem();
    }

    string loadedLabel = Icons::List + " Loaded";
    if (LoadedRecords::items.Length > 0) loadedLabel += " (" + LoadedRecords::items.Length + ")";
    if (UI::BeginTabItem(loadedLabel)) {
        g_WindowPage = WindowPage::Loaded;
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::FolderOpen + " Library")) {
        g_WindowPage = WindowPage::Library;
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::QuestionCircle + " Help")) {
        g_WindowPage = WindowPage::Help;
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}

bool g_LoadedShowAllGhosts = false;

void RenderPageLoaded() {
    if (get_CurrentMapUID().Length == 0) {
        UI::TextDisabled(Icons::Map + " No map is currently open. Open a map to view loaded ghosts.");
        return;
    }

    while (g_LoadedSelected.Length < LoadedRecords::items.Length)
        g_LoadedSelected.InsertLast(false);
    while (g_LoadedSelected.Length > LoadedRecords::items.Length)
        g_LoadedSelected.RemoveAt(g_LoadedSelected.Length - 1);

    int selectedCount = 0;
    for (uint sc = 0; sc < g_LoadedSelected.Length; sc++) {
        if (g_LoadedSelected[sc]) selectedCount++;
    }

    g_LoadedShowAllGhosts = UI::Checkbox("Show all game ghosts", g_LoadedShowAllGhosts);
    _UI::SimpleTooltip("Shows ALL ghosts known to the game engine, not just ARL-loaded ones.");
    UI::SameLine();
    if (!g_LoadedShowAllGhosts) {
        UI::AlignTextToFramePadding();
        UI::Text("\\$fff" + Icons::SnapchatGhost + " " + LoadedRecords::items.Length);
        UI::SameLine();
        if (_UI::Button(Icons::TrashO + " Clear")) {
            LoadedRecords::Clear();
            g_LoadedSelected.RemoveRange(0, g_LoadedSelected.Length);
            g_LoadedExpandedIdx = -1;
        }
    } else {
        auto dfm = GameCtx::GetDFM();
        int allCount = (dfm !is null) ? int(dfm.Ghosts.Length) : 0;
        UI::AlignTextToFramePadding();
        UI::Text("\\$fff" + Icons::SnapchatGhost + " " + allCount + " in game");
    }

    if (selectedCount > 0) {
        UI::AlignTextToFramePadding();
        UI::PushStyleColor(UI::Col::Text, AccentBrightCol);
        UI::Text("" + selectedCount + " selected");
        UI::PopStyleColor();
        UI::SameLine();
        if (_UI::Button(Icons::EyeSlash + " Hide")) {
            for (uint bi = 0; bi < g_LoadedSelected.Length; bi++) {
                if (g_LoadedSelected[bi] && bi < LoadedRecords::items.Length)
                    LoadedRecords::Unload(LoadedRecords::items[bi]);
            }
        }
        UI::SameLine();
        if (_UI::Button(Icons::Eye + " Show")) {
            for (uint bi = 0; bi < g_LoadedSelected.Length; bi++) {
                if (g_LoadedSelected[bi] && bi < LoadedRecords::items.Length)
                    LoadedRecords::Reload(LoadedRecords::items[bi]);
            }
        }
        UI::SameLine();
        UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65f, 0.22f, 0.22f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80f, 0.28f, 0.28f, 1.0f));
        if (_UI::Button(Icons::Times + " Forget")) {
            for (int bi = int(g_LoadedSelected.Length) - 1; bi >= 0; bi--) {
                if (g_LoadedSelected[bi] && uint(bi) < LoadedRecords::items.Length) {
                    LoadedRecords::ForgetAt(uint(bi));
                    g_LoadedSelected.RemoveAt(uint(bi));
                }
            }
            g_LoadedExpandedIdx = -1;
        }
        UI::PopStyleColor(3);
    }

    if (g_LoadedShowAllGhosts) {
        RenderAllGameGhosts();
        return;
    }

    if (LoadedRecords::items.Length == 0) {
        UI::TextDisabled(Icons::SnapchatGhost + " No ARL-tracked ghosts. Use the Load page to import ghosts.");
        auto _dfmCheck = GameCtx::GetDFM();
        if (_dfmCheck !is null && _dfmCheck.Ghosts.Length > 0) {
            UI::TextDisabled(Icons::InfoCircle + " " + _dfmCheck.Ghosts.Length + " ghost(s) in game - enable toggle above to see them.");
        }
        return;
    }

    array<int> filteredIndices;
    for (int fi = 0; fi < int(LoadedRecords::items.Length); fi++) {
        auto fit = LoadedRecords::items[uint(fi)];
        if (fit is null) continue;
        if (!MatchesFilter(fit)) continue;
        filteredIndices.InsertLast(fi);
    }
    array<int> sortedIndices = BuildSortedIndices(filteredIndices);

    auto loadedNameSamples = array<string>();
    for (uint si = 0; si < sortedIndices.Length; si++) {
        int idx = sortedIndices[si];
        auto sampleItem = LoadedRecords::items[uint(idx)];
        if (sampleItem is null) continue;
        loadedNameSamples.InsertLast(GetGhostName(sampleItem));
    }
    float loadedNameColWidth = GetContentFitColumnWidth("Name", loadedNameSamples, 20.0f, 180.0f);
    float loadedTableWidth = ApproxTableWidth({30.0f, 60.0f, loadedNameColWidth, 85.0f, LoadedActionsColWidth});
    float loadedSearchWidth = Math::Max(180.0f, loadedTableWidth - UI::MeasureString(Icons::Search).x - UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x);

    UI::AlignTextToFramePadding();
    UI::Text(Icons::Search);
    UI::SameLine();
    UI::SetNextItemWidth(loadedSearchWidth);
    g_LoadedFilter = UI::InputText("##LoadedFilter", g_LoadedFilter);

    if (sortedIndices.Length == 0) {
        UI::TextDisabled("No items match the filter.");
        return;
    }

    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
    UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));

    int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::Resizable | UI::TableFlags::ScrollY | UI::TableFlags::SizingFixedFit;
    if (UI::BeginTable("LoadedTable", 5, flags, vec2(0, 0))) {
        UI::TableSetupColumn("##Sel", UI::TableColumnFlags::WidthFixed, 30);
        UI::TableSetupColumn("State", UI::TableColumnFlags::WidthFixed, 60);
        UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthFixed, loadedNameColWidth);
        UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
        UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, LoadedActionsColWidth);

        UI::TableNextRow(UI::TableRowFlags::Headers);

        UI::TableNextColumn();
        bool allSel = (selectedCount > 0 && selectedCount == int(sortedIndices.Length));
        bool newAll = UI::Checkbox("##SelAll", allSel);
        if (newAll != allSel) {
            for (uint hi = 0; hi < sortedIndices.Length; hi++) {
                uint idx = uint(sortedIndices[hi]);
                if (idx < g_LoadedSelected.Length) g_LoadedSelected[idx] = newAll;
            }
        }

        array<string> sortColNames = {"State", "Name", "Time"};
        for (int ci = 0; ci < 3; ci++) {
            UI::TableNextColumn();
            string arrow = "";
            if (g_LoadedSortCol == ci) arrow = g_LoadedSortAsc ? " \\$aaa" + Icons::ChevronUp : " \\$aaa" + Icons::ChevronDown;
            if (UI::Selectable(sortColNames[ci] + arrow + "##SortH_" + ci, false)) {
                ClickSortHeader(ci);
            }
        }
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

            string name = GetGhostName(it);
            int ghostTime = 0;
            string timeScore = "-";
            if (it.ghost !is null) {
                ghostTime = GetGhostTime(it);
                if (ghostTime > 0) {
                    timeScore = FormatMs(ghostTime);
                } else if (it.ghost.Result.Score > 0) {
                    timeScore = "" + it.ghost.Result.Score;
                }
            }

            UI::TableNextRow();

            UI::TableNextColumn();
            bool sel = (uint(i) < g_LoadedSelected.Length) ? g_LoadedSelected[uint(i)] : false;
            bool newSel = UI::Checkbox("##Sel_" + i, sel);
            if (newSel != sel && uint(i) < g_LoadedSelected.Length) g_LoadedSelected[uint(i)] = newSel;

            UI::TableNextColumn();
            if (it.isLoaded) {
                UI::PushStyleColor(UI::Col::Text, AccentCol);
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
            if (UI::Selectable(name + "##NameSel_" + i, g_LoadedExpandedIdx == i)) {
                g_LoadedExpandedIdx = (g_LoadedExpandedIdx == i) ? -1 : i;
            }

            UI::TableNextColumn();
            if (ghostTime > 0 && medalAT > 0) {
                string medalColor = "\\$fff";
                string medalTip = "";
                if (uint(ghostTime) <= medalAT) {
                    medalColor = "\\$7e0";
                    medalTip = "Beats Author Time (" + FormatMs(int(medalAT)) + ")";
                } else if (uint(ghostTime) <= medalGold) {
                    medalColor = "\\$fd0";
                    medalTip = "Beats Gold (" + FormatMs(int(medalGold)) + ")";
                } else if (uint(ghostTime) <= medalSilver) {
                    medalColor = "\\$ddd";
                    medalTip = "Beats Silver (" + FormatMs(int(medalSilver)) + ")";
                } else if (uint(ghostTime) <= medalBronze) {
                    medalColor = "\\$c73";
                    medalTip = "Beats Bronze (" + FormatMs(int(medalBronze)) + ")";
                } else {
                    medalColor = "\\$999";
                    medalTip = "Below Bronze (" + FormatMs(int(medalBronze)) + ")";
                }
                UI::Text(medalColor + timeScore + "\\$z");
                if (medalTip.Length > 0) {
                    string fullTip = medalTip;
                    if (it.loadedAt > 0) fullTip += "\nLoaded " + FormatTimeAgo(it.loadedAt);
                    _UI::SimpleTooltip(fullTip);
                }
            } else {
                UI::Text(timeScore);
                if (it.loadedAt > 0) {
                    _UI::SimpleTooltip("Loaded " + FormatTimeAgo(it.loadedAt));
                }
            }

            UI::TableNextColumn();
            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

            if (it.isLoaded) {
                if (_UI::IconButton(Icons::EyeSlash, "Hide_" + i, vec2(IconButtonWidth, 0))) {
                    LoadedRecords::Unload(it);
                }
                _UI::SimpleTooltip("Hide ghost");
            } else {
                UI::BeginDisabled(it.ghost is null);
                if (_UI::IconButton(Icons::Eye, "Show_" + i, vec2(IconButtonWidth, 0))) {
                    LoadedRecords::Reload(it);
                }
                UI::EndDisabled();
                _UI::SimpleTooltip("Show ghost");
            }

            UI::SameLine();
            string folderPath = it.filePath.Length > 0 ? it.filePath : it.sourceRef;
            bool canOpenFolder = folderPath.Length > 0 && IO::FileExists(folderPath);
            UI::BeginDisabled(!canOpenFolder);
            if (_UI::IconButton(Icons::FolderOpen, "OpenFolder_" + i, vec2(IconButtonWidth, 0))) {
                _IO::OpenFolder(Path::GetDirectoryName(folderPath));
            }
            UI::EndDisabled();
            _UI::SimpleTooltip("Open containing folder");

            UI::SameLine();
            UI::BeginDisabled(it.ghost is null || SavedRecords::_saving);
            if (_UI::IconButton(Icons::FloppyO, "Save_" + i, vec2(IconButtonWidth, 0))) {
                SavedRecords::SaveFromLoaded(it);
            }
            UI::EndDisabled();
            _UI::SimpleTooltip("Save to library");

            UI::SameLine();
            UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65f, 0.22f, 0.22f, 1.0f));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80f, 0.28f, 0.28f, 1.0f));
            if (_UI::IconButton(Icons::Times, "Forget_" + i, vec2(IconButtonWidth, 0))) {
                LoadedRecords::ForgetAt(uint(i));
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
                if (it.ghost !is null) {
                    string extra = "Nick: " + it.ghost.Nickname + " | Tri: " + it.ghost.Trigram + " | " + it.ghost.CountryPath;
                    if (it.mapUid.Length > 0) extra += "\nMapUid: " + it.mapUid;
                    UI::TextDisabled(extra);
                    UI::Dummy(vec2(0, 4));
                    RenderGhostInspector(it.ghost, "" + i);
                } else {
                    UI::TextDisabled("(no ghost reference)");
                }

                UI::TableNextColumn();
                UI::TextDisabled(it.loadedAt > 0 ? FormatTimeAgo(it.loadedAt) : "");

                UI::TableNextColumn();
                string actionsInfo = "";
                if (it.accountId.Length > 0) actionsInfo += "AccountId: " + it.accountId;
                if (actionsInfo.Length > 0) actionsInfo += "\n";
                actionsInfo += "MwId:" + it.instId.Value + (it.useGhostLayer ? " GL" : "");
                UI::TextDisabled(actionsInfo);
            }
        }

        UI::EndTable();
    }

    UI::PopStyleVar();
    UI::PopStyleColor();
}

string g_AllGhostsFilter = "";

void RenderAllGameGhosts() {
    auto dfm = GameCtx::GetDFM();
    if (dfm is null) {
        UI::TextDisabled("DataFileMgr not available (no map loaded?)");
        return;
    }

    auto ghosts = dfm.Ghosts;
    if (ghosts.Length == 0) {
        UI::TextDisabled(Icons::SnapchatGhost + " No ghosts in game.");
        return;
    }

    string filterLower = g_AllGhostsFilter.ToLower();

    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
    UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));

    auto ghostNameSamples = array<string>();
    auto ghostIdSamples = array<string>();
    for (uint gi = 0; gi < ghosts.Length; gi++) {
        CGameGhostScript@ ghost = cast<CGameGhostScript>(ghosts[gi]);
        if (ghost is null) continue;

        string nickname = ghost.Nickname;
        string idName = LoadedRecords::VisibleIdName(ghost);
        string strippedName = Text::StripFormatCodes(nickname).ToLower();
        string strippedId = idName.ToLower();
        if (filterLower.Length > 0) {
            if (!strippedName.Contains(filterLower) && !strippedId.Contains(filterLower))
                continue;
        }

        ghostNameSamples.InsertLast(nickname.Length > 0 ? nickname : "-");
        ghostIdSamples.InsertLast(idName.Length > 0 ? idName : "-");
    }
    float ghostNameColWidth = GetContentFitColumnWidth("Name", ghostNameSamples, 20.0f, 160.0f);
    float ghostIdColWidth = GetContentFitColumnWidth("ID Name", ghostIdSamples, 20.0f, 180.0f);
    float allGhostsTableWidth = ApproxTableWidth({ghostNameColWidth, ghostIdColWidth, 85.0f, 60.0f, 80.0f, 35.0f, AllGhostActionsColWidth});
    float allGhostsSearchWidth = Math::Max(180.0f, allGhostsTableWidth - UI::MeasureString(Icons::Search).x - UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x);

    UI::AlignTextToFramePadding();
    UI::Text(Icons::Search);
    UI::SameLine();
    UI::SetNextItemWidth(allGhostsSearchWidth);
    g_AllGhostsFilter = UI::InputText("##AllGhostsFilter", g_AllGhostsFilter);

    int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::Resizable | UI::TableFlags::ScrollY | UI::TableFlags::SizingFixedFit;
    if (UI::BeginTable("AllGhosts", 7, tflags, vec2(0, 0))) {
        UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthFixed, ghostNameColWidth);
        UI::TableSetupColumn("ID Name", UI::TableColumnFlags::WidthFixed, ghostIdColWidth);
        UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
        UI::TableSetupColumn("Trigram", UI::TableColumnFlags::WidthFixed, 60);
        UI::TableSetupColumn("MwId", UI::TableColumnFlags::WidthFixed, 80);
        UI::TableSetupColumn("ARL", UI::TableColumnFlags::WidthFixed, 35);
        UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, AllGhostActionsColWidth);
        UI::TableHeadersRow();

        for (uint gi = 0; gi < ghosts.Length; gi++) {
            CGameGhostScript@ ghost = cast<CGameGhostScript>(ghosts[gi]);
            if (ghost is null) continue;

            string nickname = ghost.Nickname;
            string idName = LoadedRecords::VisibleIdName(ghost);
            string strippedName = Text::StripFormatCodes(nickname).ToLower();
            string strippedId = idName.ToLower();

            if (filterLower.Length > 0) {
                if (!strippedName.Contains(filterLower) && !strippedId.Contains(filterLower))
                    continue;
            }

            auto arlItem = LoadedRecords::FindByInstId(ghost.Id);
            bool isARL = (arlItem !is null) || LoadedRecords::IsMarkedGhost(ghost);

            UI::TableNextRow();

            UI::TableNextColumn();
            UI::Text(nickname.Length > 0 ? nickname : "-");

            UI::TableNextColumn();
            UI::TextDisabled(idName.Length > 0 ? idName : "-");

            UI::TableNextColumn();
            int shownTime = arlItem !is null ? GetGhostTime(arlItem) : -1;
            if (shownTime > 0)
                UI::Text(FormatMs(shownTime));
            else if (ghost.Result.Time > 0)
                UI::Text(FormatMs(ghost.Result.Time));
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
                UI::PushStyleColor(UI::Col::Text, AccentCol);
                UI::Text(Icons::Check);
                UI::PopStyleColor();
                _UI::SimpleTooltip("Tracked by ARL");
            } else {
                UI::TextDisabled("-");
            }

            UI::TableNextColumn();
            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
            if (_UI::IconButton(Icons::EyeSlash, "ag_rm_" + gi, vec2(IconButtonWidth, 0))) {
                auto gm = GameCtx::GetGhostMgr();
                if (gm !is null) {
                    gm.Ghost_Remove(ghost.Id);
                    if (arlItem !is null) arlItem.isLoaded = false;
                }
            }
            _UI::SimpleTooltip("Remove this ghost from the game");
            UI::SameLine();
            if (_UI::IconButton(Icons::InfoCircle, "ag_info_" + gi, vec2(IconButtonWidth, 0))) {
                int shownTime = arlItem !is null ? GetGhostTime(arlItem) : int(ghost.Result.Time);
                string info = "Nickname: " + nickname
                    + "\nIdName: " + idName
                    + "\nTrigram: " + ghost.Trigram
                    + "\nCountry: " + ghost.CountryPath
                    + "\nTime: " + FormatMs(shownTime)
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

void RenderSettings() {
    UI::BeginTabBar("SettingsTabs");

    if (UI::BeginTabItem(Icons::Cogs + " Behavior")) {
        GhostLoader::S_UseGhostLayer = UI::Checkbox("Use Ghost Layer (recommended)", GhostLoader::S_UseGhostLayer);
        _UI::SimpleTooltip("Places ghosts on the ghost layer instead of the main layer.");
        UI::TextDisabled("Ghost layer renders ghosts with standard ghost transparency.");
        UI::TextDisabled("Main layer renders ghosts as fully opaque cars.");
        bool enableGhostsVal = MapTracker::enableGhosts;
        MapTracker::enableGhosts = UI::Checkbox("Enable auto-load on map change", enableGhostsVal);
        _UI::SimpleTooltip("Automatically run Automation tasks when entering a new map.");
        UI::Separator();
        UI::Text("Defaults");
        g_DefaultRankOffset = UI::InputInt("Default Rank", g_DefaultRankOffset);
        _UI::SimpleTooltip("Default player rank when loading from Map UID, Profiles, or Official Campaigns. 1 = world record. 0 or negative also loads rank 1.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::KeyboardO + " Hotkeys")) {
        UI::TextDisabled("Hotkeys redesign in progress.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Folder + " Folders")) {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        if (_UI::Button(Icons::FolderOpen + " ARL Root")) _IO::OpenFolder(Server::replayARL);
        UI::TextDisabled(Server::replayARL);

        if (_UI::Button(Icons::FolderOpen + " Managed Store")) _IO::OpenFolder(Server::storedFilesDirectory);
        UI::TextDisabled(Server::storedFilesDirectory);

        UI::Separator();
        if (_UI::Button(Icons::TrashO + " Clear Staging Folder")) {
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

    if (UI::BeginTabItem(Icons::IdCard + " Identity")) {
        PlayerDirectory::EnsureInit();

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        UI::TextDisabled("Passive player-name diagnostics collected from ARL activity, cached lookups, and intercepted HTTP responses.");
        UI::Dummy(vec2(0, 4));

        PlayerDirectory::S_LogObservedMatches = UI::Checkbox("Log observed name matches", PlayerDirectory::S_LogObservedMatches);
        _UI::SimpleTooltip("Print every observed accountId <-> displayName match to the ARL logs.");

        UI::SameLine();
        if (_UI::Button(Icons::TrashO + " Clear Recent Matches")) {
            PlayerDirectory::ClearRecentObservedMatches();
        }

        UI::SameLine();
        if (_UI::Button(Icons::FolderOpen + " Open Storage Folder")) {
            _IO::OpenFolder(Path::GetDirectoryName(PlayerDirectory::GetDatabasePath()));
        }

        UI::Dummy(vec2(0, 4));
        UI::Text(Icons::InfoCircle + " \\$fffCache");
        UI::TextDisabled("Entries: " + PlayerDirectory::GetEntryCount());
        UI::TextDisabled("Persisting: " + (PlayerDirectory::IsPersisting() ? "yes" : "no") + " | Syncing: " + (PlayerDirectory::IsSyncing() ? "yes" : "no"));
        UI::TextDisabled("DB: " + PlayerDirectory::GetDatabasePath());

        auto recent = PlayerDirectory::GetRecentObservedMatches();
        UI::Dummy(vec2(0, 6));
        UI::Text(Icons::Exchange + " \\$fffRecent Name Matches (" + recent.Length + ")");
        UI::Dummy(vec2(0, 2));

        auto recentNameSamples = array<string>();
        auto recentIdSamples = array<string>();
        for (uint i = 0; i < recent.Length; i++) {
            auto match = recent[i];
            if (match is null) continue;
            recentNameSamples.InsertLast(match.displayName);
            recentIdSamples.InsertLast(match.accountId);
        }
        float recentNameColWidth = GetContentFitColumnWidth("Name", recentNameSamples, 20.0f, 160.0f);
        float recentIdColWidth = GetContentFitColumnWidth("Account ID", recentIdSamples, 20.0f, 280.0f);

        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY | UI::TableFlags::SizingFixedFit;
        if (UI::BeginTable("PlayerDirectoryRecentMatches", 5, tflags, vec2(0, 320))) {
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthFixed, recentNameColWidth);
            UI::TableSetupColumn("Account ID", UI::TableColumnFlags::WidthFixed, recentIdColWidth);
            UI::TableSetupColumn("Source", UI::TableColumnFlags::WidthFixed, 150);
            UI::TableSetupColumn("Status", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Observed", UI::TableColumnFlags::WidthFixed, 145);
            UI::TableHeadersRow();

            for (uint i = 0; i < recent.Length; i++) {
                auto match = recent[i];
                if (match is null) continue;

                UI::TableNextRow();

                UI::TableNextColumn();
                UI::Text(match.displayName);

                UI::TableNextColumn();
                UI::TextDisabled(match.accountId);
                _UI::SimpleTooltip(match.accountId);

                UI::TableNextColumn();
                UI::TextDisabled(match.source);

                UI::TableNextColumn();
                if (match.status == "new") UI::Text("\\$0f0new\\$z");
                else if (match.status == "rename") UI::Text("\\$fd0rename\\$z");
                else UI::TextDisabled(match.status);

                UI::TableNextColumn();
                if (match.observedAt > 0) UI::TextDisabled(Time::FormatStringUTC("%Y-%m-%d %H:%M:%S", match.observedAt));
                else UI::TextDisabled("-");
            }

            UI::EndTable();
        }
        UI::PopStyleColor();
        UI::PopStyleVar();
        UI::PopStyleVar();
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::DevTo + " Logging")) {
        UI::TextDisabled("Plugin log output. Check Openplanet console for full logs.");
        logging::RT_LOGs();
        UI::EndTabItem();
    }

    UI::EndTabBar();
}

void RenderSettingsWindow() {
    if (!settingsWindowOpen) return;

    UI::SetNextWindowSize(860, 620, UI::Cond::FirstUseEver);

    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 10));
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);

    if (UI::Begin(Icons::Cogs + " Arbitrary Record Loader Settings", settingsWindowOpen, UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize | UI::WindowFlags::AlwaysAutoResize)) {
        RenderSettings();
    }
    UI::End();

    UI::PopStyleVar(3);
}

void RenderPage() {
    switch (g_WindowPage) {
        case WindowPage::Load:        RenderPageLoad(); break;
        case WindowPage::Loaded:      RenderPageLoaded(); break;
        case WindowPage::Library:     RenderPageLibrary(); break;
        case WindowPage::Help:        EntryPoints::Help::Render(); break;
    }
}

void RenderInterface() {
    FILE_EXPLORER_BASE_RENDERER();
    RenderSettingsWindow();

    if (!windowOpen) return;

    UI::SetNextWindowSize(980, 680, UI::Cond::FirstUseEver);

    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 10));
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);

    if (UI::Begin(Icons::UserPlus + " Arbitrary Record Loader", windowOpen, UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize | UI::WindowFlags::AlwaysAutoResize)) {
        RenderNavTabs();
        RenderPage();
    }
    UI::End();

    UI::PopStyleVar(3);
}
