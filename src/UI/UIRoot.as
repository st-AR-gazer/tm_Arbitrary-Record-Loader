[Setting category="General" name="Window Open"]
bool S_ARL_WindowOpen = false;

enum ARL_Page {
    Load = 0,
    Loaded,
    Library,
    Automation
}

ARL_Page g_ARL_Page = ARL_Page::Load;

int g_DefaultRankOffset = 0;

string g_LoadedFilter = "";
int g_LoadedExpandedIdx = -1;
int g_LoadedSortCol = -1;
bool g_LoadedSortAsc = true;
array<bool> g_LoadedSelected;

void RenderMenu() {
    if (UI::MenuItem(Colorize(Icons::SnapchatGhost + Icons::Magic + Icons::FileO, {"#aca", "#cda", "#6ca"}) + "\\$g" + " Arbitrary Record Loader", "", S_ARL_WindowOpen)) {
        S_ARL_WindowOpen = !S_ARL_WindowOpen;
    }
}

float ARL_SearchInputWidth() {
    float w = UI::GetFontSize() * 28.0f;
    w = Math::Max(260.0f, w);
    w = Math::Min(700.0f, w);
    float avail = UI::GetContentRegionAvail().x;
    if (avail > 0) w = Math::Min(w, avail);
    return w;
}

float ARL_LongInputWidth() {
    float w = UI::GetFontSize() * 46.0f;
    w = Math::Max(340.0f, w);
    w = Math::Min(1100.0f, w);
    float avail = UI::GetContentRegionAvail().x;
    if (avail > 0) w = Math::Min(w, avail);
    return w;
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

void ARL_RenderNavTabs() {
    UI::PushStyleColor(UI::Col::Tab, ARL_HeaderBg);
    UI::PushStyleColor(UI::Col::TabHovered, ARL_HeaderHoverBg);
    UI::PushStyleColor(UI::Col::TabActive, ARL_HeaderActiveBg);

    UI::BeginTabBar("ARL_NavTabs");

    if (UI::BeginTabItem(Icons::Download + " Load")) {
        g_ARL_Page = ARL_Page::Load;
        UI::EndTabItem();
    }

    string loadedLabel = Icons::List + " Loaded";
    if (LoadedRecords::items.Length > 0) loadedLabel += " (" + LoadedRecords::items.Length + ")";
    if (UI::BeginTabItem(loadedLabel)) {
        g_ARL_Page = ARL_Page::Loaded;
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::FolderOpen + " Library")) {
        g_ARL_Page = ARL_Page::Library;
        UI::EndTabItem();
    }

    UI::EndTabBar();

    UI::PopStyleColor(3);
}

bool g_LoadedShowAllGhosts = false;

void ARL_RenderPage_Loaded() {
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
        if (UI::Button(Icons::TrashO + " Clear")) {
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
        UI::PushStyleColor(UI::Col::Text, ARL_AccentBrightCol);
        UI::Text("" + selectedCount + " selected");
        UI::PopStyleColor();
        UI::SameLine();
        if (UI::Button(Icons::EyeSlash + " Hide")) {
            for (uint bi = 0; bi < g_LoadedSelected.Length; bi++) {
                if (g_LoadedSelected[bi] && bi < LoadedRecords::items.Length)
                    LoadedRecords::Unload(LoadedRecords::items[bi]);
            }
        }
        UI::SameLine();
        if (UI::Button(Icons::Eye + " Show")) {
            for (uint bi = 0; bi < g_LoadedSelected.Length; bi++) {
                if (g_LoadedSelected[bi] && bi < LoadedRecords::items.Length)
                    LoadedRecords::Reload(LoadedRecords::items[bi]);
            }
        }
        UI::SameLine();
        UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65f, 0.22f, 0.22f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80f, 0.28f, 0.28f, 1.0f));
        if (UI::Button(Icons::Times + " Forget")) {
            for (int bi = int(g_LoadedSelected.Length) - 1; bi >= 0; bi--) {
                if (g_LoadedSelected[bi] && uint(bi) < LoadedRecords::items.Length) {
                    LoadedRecords::items.RemoveAt(uint(bi));
                    g_LoadedSelected.RemoveAt(uint(bi));
                }
            }
            g_LoadedExpandedIdx = -1;
        }
        UI::PopStyleColor(3);
    }

    if (g_LoadedShowAllGhosts) {
        ARL_RenderAllGameGhosts();
        return;
    }

    UI::SetNextItemWidth(ARL_SearchInputWidth());
    g_LoadedFilter = UI::InputText(Icons::Search + " ##ARL_LoadedFilter", g_LoadedFilter);

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
        if (!ARL_MatchesFilter(fit)) continue;
        filteredIndices.InsertLast(fi);
    }
    array<int> sortedIndices = ARL_BuildSortedIndices(filteredIndices);

    if (sortedIndices.Length == 0) {
        UI::TextDisabled("No items match the filter.");
        return;
    }

    UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
    UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));

    int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::Resizable | UI::TableFlags::ScrollY;
    if (UI::BeginTable("ARL_LoadedTable", 5, flags, vec2(0, 0))) {
        UI::TableSetupColumn("##Sel", UI::TableColumnFlags::WidthFixed, 30);
        UI::TableSetupColumn("State", UI::TableColumnFlags::WidthFixed, 60);
        UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
        UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, ARL_LoadedActionsColWidth);

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

        array<string> sortColNames = {"State", "Name", "Time"};
        for (int ci = 0; ci < 3; ci++) {
            UI::TableNextColumn();
            string arrow = "";
            if (g_LoadedSortCol == ci) arrow = g_LoadedSortAsc ? " \\$aaa" + Icons::ChevronUp : " \\$aaa" + Icons::ChevronDown;
            if (UI::Selectable(sortColNames[ci] + arrow + "##ARL_SortH_" + ci, false)) {
                ARL_ClickSortHeader(ci);
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
            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

            if (it.isLoaded) {
                if (UI::Button(Icons::EyeSlash + "##ARL_Hide_" + i, vec2(ARL_IconButtonWidth, 0))) {
                    LoadedRecords::Unload(it);
                }
                _UI::SimpleTooltip("Hide ghost");
            } else {
                UI::BeginDisabled(it.ghost is null);
                if (UI::Button(Icons::Eye + "##ARL_Show_" + i, vec2(ARL_IconButtonWidth, 0))) {
                    LoadedRecords::Reload(it);
                }
                UI::EndDisabled();
                _UI::SimpleTooltip("Show ghost");
            }

            UI::SameLine();
            bool canOpenFolder = it.sourceRef.Length > 0 && IO::FileExists(it.sourceRef);
            UI::BeginDisabled(!canOpenFolder);
            if (UI::Button(Icons::FolderOpen + "##ARL_OpenFolder_" + i, vec2(ARL_IconButtonWidth, 0))) {
                _IO::OpenFolder(Path::GetDirectoryName(it.sourceRef));
            }
            UI::EndDisabled();
            _UI::SimpleTooltip("Open containing folder");

            UI::SameLine();
            UI::BeginDisabled(it.ghost is null || SavedRecords::_saving);
            if (UI::Button(Icons::FloppyO + "##ARL_Save_" + i, vec2(ARL_IconButtonWidth, 0))) {
                SavedRecords::SaveFromLoaded(it);
            }
            UI::EndDisabled();
            _UI::SimpleTooltip("Save to library");

            UI::SameLine();
            UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65f, 0.22f, 0.22f, 1.0f));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80f, 0.28f, 0.28f, 1.0f));
            if (UI::Button(Icons::Times + "##ARL_Forget_" + i, vec2(ARL_IconButtonWidth, 0))) {
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
                if (it.ghost !is null) {
                    string extra = "Nick: " + it.ghost.Nickname + " | Tri: " + it.ghost.Trigram + " | " + it.ghost.CountryPath;
                    if (it.mapUid.Length > 0) extra += "\nMapUid: " + it.mapUid;
                    UI::TextDisabled(extra);
                } else {
                    UI::TextDisabled("(no ghost reference)");
                }

                UI::TableNextColumn();
                UI::TextDisabled(it.loadedAt > 0 ? ARL_FormatTimeAgo(it.loadedAt) : "");

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

void ARL_RenderAllGameGhosts() {
    UI::SetNextItemWidth(ARL_SearchInputWidth());
    g_AllGhostsFilter = UI::InputText(Icons::Search + " ##ARL_AllGhostsFilter", g_AllGhostsFilter);

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

    int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::Resizable | UI::TableFlags::ScrollY;
    if (UI::BeginTable("ARL_AllGhosts", 7, tflags, vec2(0, 0))) {
        UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("ID Name", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
        UI::TableSetupColumn("Trigram", UI::TableColumnFlags::WidthFixed, 60);
        UI::TableSetupColumn("MwId", UI::TableColumnFlags::WidthFixed, 80);
        UI::TableSetupColumn("ARL", UI::TableColumnFlags::WidthFixed, 35);
        UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, ARL_AllGhostActionsColWidth);
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
            if (UI::Button(Icons::EyeSlash + "##ag_rm_" + gi, vec2(ARL_IconButtonWidth, 0))) {
                auto gm = GameCtx::GetGhostMgr();
                if (gm !is null) {
                    gm.Ghost_Remove(ghost.Id);
                    auto arlItem = LoadedRecords::FindByInstId(ghost.Id);
                    if (arlItem !is null) arlItem.isLoaded = false;
                }
            }
            _UI::SimpleTooltip("Remove this ghost from the game");
            UI::SameLine();
            if (UI::Button(Icons::InfoCircle + "##ag_info_" + gi, vec2(ARL_IconButtonWidth, 0))) {
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

void RenderSettings() {
    UI::BeginTabBar("ARL_SettingsTabs");

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
        g_DefaultRankOffset = UI::InputInt("Default Rank Offset", g_DefaultRankOffset);
        _UI::SimpleTooltip("Default rank when loading from Map UID, Profiles, or Official Campaigns. 0 = world record.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::KeyboardO + " Hotkeys")) {
        UI::TextDisabled("Hotkeys redesign in progress.");
        UI::EndTabItem();
    }

    if (UI::BeginTabItem(Icons::Folder + " Folders")) {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        if (UI::Button(Icons::FolderOpen + " ARL Root")) _IO::OpenFolder(Server::replayARL);
        UI::TextDisabled(Server::replayARL);

        if (UI::Button(Icons::FolderOpen + " Downloaded")) _IO::OpenFolder(Server::specificDownloadedFilesDirectory);
        UI::TextDisabled(Server::specificDownloadedFilesDirectory);

        if (UI::Button(Icons::FolderOpen + " Official")) _IO::OpenFolder(Server::officialFilesDirectory);
        UI::TextDisabled(Server::officialFilesDirectory);

        UI::Separator();
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
        UI::TextDisabled("Plugin log output. Check Openplanet console for full logs.");
        logging::RT_LOGs();
        UI::EndTabItem();
    }

    UI::EndTabBar();
}

void ARL_RenderPage() {
    switch (g_ARL_Page) {
        case ARL_Page::Load:        ARL_RenderPage_Load(); break;
        case ARL_Page::Loaded:      ARL_RenderPage_Loaded(); break;
        case ARL_Page::Library:     ARL_RenderPage_Library(); break;
    }
}

void RenderInterface() {
    FILE_EXPLORER_BASE_RENDERER();

    if (!S_ARL_WindowOpen) return;

    UI::SetNextWindowSize(980, 680, UI::Cond::FirstUseEver);

    UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 10));
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
    UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);

    if (UI::Begin(Icons::UserPlus + " Arbitrary Record Loader", S_ARL_WindowOpen, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize)) {
        ARL_RenderNavTabs();
        ARL_RenderPage();
    }
    UI::End();

    UI::PopStyleVar(3);
}
