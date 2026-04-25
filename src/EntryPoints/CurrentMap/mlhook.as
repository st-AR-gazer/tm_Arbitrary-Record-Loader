#if DEPENDENCY_MLHOOK
namespace EntryPoints {
namespace CurrentMap {
namespace MLHookGhosts {
    const int PAGE_SIZE = 10;

    string fetchMapUid = "";
    int fetchPage = 0;
    int page = 0;
    bool loading = false;
    bool loaded = false;
    bool hasMore = true;
    string goToPage = "1";
    string error = "";
    int customRank = 1;
    int customCount = PAGE_SIZE;

    array<int> positions;
    array<string> accountIds;
    array<string> names;
    array<string> times;
    array<int> scores;

    void Reset() {
        positions.RemoveRange(0, positions.Length);
        accountIds.RemoveRange(0, accountIds.Length);
        names.RemoveRange(0, names.Length);
        times.RemoveRange(0, times.Length);
        scores.RemoveRange(0, scores.Length);
        fetchMapUid = "";
        fetchPage = 0;
        page = 0;
        loading = false;
        loaded = false;
        hasMore = true;
        goToPage = "1";
        error = "";
        customRank = 1;
        customCount = PAGE_SIZE;
    }

    void OnMapLoad() {
        Reset();
    }

    bool IsAvailable() {
        return ToggleGhostMgr::IsMLHookAvailable();
    }

    bool IsLoaded(const string &in accountId) {
        auto entry = ToggleGhostMgr::FindGhostByPlayerId(accountId);
        return entry !is null && entry.isLoaded;
    }

    int PageStartIndex(int pageIndex) {
        return pageIndex * PAGE_SIZE;
    }

    bool IsPageLoaded(int pageIndex) {
        int start = PageStartIndex(pageIndex);
        return start < int(accountIds.Length) && accountIds[uint(start)].Length > 0;
    }

    bool HasAnyRecords() {
        for (uint i = 0; i < accountIds.Length; i++) {
            if (accountIds[i].Length > 0) return true;
        }
        return false;
    }

    void EnsureRowCapacity(int count) {
        while (int(positions.Length) < count) positions.InsertLast(0);
        while (int(accountIds.Length) < count) accountIds.InsertLast("");
        while (int(names.Length) < count) names.InsertLast("");
        while (int(times.Length) < count) times.InsertLast("");
        while (int(scores.Length) < count) scores.InsertLast(0);
    }

    int HighestLoadedIndex() {
        for (int i = int(accountIds.Length) - 1; i >= 0; i--) {
            if (accountIds[uint(i)].Length > 0) return i;
        }
        return -1;
    }

    void EnsureAutoLoaded() {
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) return;

        if (fetchMapUid.Length > 0 && fetchMapUid != mapUid) Reset();
        if (!loading && !IsPageLoaded(0)) {
            FetchPage(0);
        }
    }

    void FetchPage(int pageIndex) {
        if (loading || pageIndex < 0) return;
        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) {
            error = "No map loaded.";
            return;
        }

        if (fetchMapUid.Length > 0 && fetchMapUid != mapUid) Reset();
        fetchMapUid = mapUid;
        fetchPage = pageIndex;
        loading = true;
        error = "";
        startnew(Coro_FetchPage);
    }

    void FetchMore() {
        if (loading) return;
        FetchPage(page + 1);
    }

    int ClampCustomRank() {
        if (customRank < 1) customRank = 1;
        return customRank;
    }

    int CustomOffset() {
        return ClampCustomRank() - 1;
    }

    int ClampCustomCount() {
        if (customCount < 1) customCount = 1;
        if (customCount > PAGE_SIZE) customCount = PAGE_SIZE;
        return customCount;
    }

    void FetchCustomRange() {
        int offset = CustomOffset();
        int targetPage = offset / PAGE_SIZE;
        page = targetPage;
        goToPage = tostring(page + 1);
        FetchPage(targetPage);
    }

    void JumpToPage(int targetPage) {
        if (targetPage < 0) targetPage = 0;

        if (IsPageLoaded(targetPage)) {
            page = targetPage;
            goToPage = tostring(page + 1);
            return;
        }

        if (!loading) {
            FetchPage(targetPage);
            return;
        }

        goToPage = tostring(page + 1);
    }

    void Coro_FetchPage() {
        string expectedMapUid = fetchMapUid;
        int requestedPage = fetchPage;
        int offset = PageStartIndex(requestedPage);

        if (api is null) {
            error = "Nadeo API is not ready.";
            loading = false;
            loaded = true;
            return;
        }

        Json::Value data = api.GetMapRecords("Personal_Best", expectedMapUid, true, uint(PAGE_SIZE), uint(offset));
        if (expectedMapUid != CurrentMap::GetMapUid()) {
            Reset();
            return;
        }

        if (data.GetType() == Json::Type::Null) {
            error = "Failed to fetch leaderboard records.";
            loading = false;
            loaded = true;
            return;
        }

        auto tops = data["tops"];
        if (tops.GetType() != Json::Type::Array || tops.Length == 0) {
            error = "No leaderboard records found for page " + (requestedPage + 1) + ".";
            loading = false;
            loaded = true;
            return;
        }

        auto top = tops[0]["top"];
        if (top.GetType() != Json::Type::Array) {
            error = "Invalid leaderboard response.";
            loading = false;
            loaded = true;
            return;
        }

        array<string> newAccountIds;
        uint startIndex = uint(offset);
        EnsureRowCapacity(offset + PAGE_SIZE);
        for (uint i = 0; i < top.Length; i++) {
            auto record = top[i];
            if (record.GetType() != Json::Type::Object) continue;

            string accountId = Services::LoadQueue::JsonFieldString(record, "accountId").Trim();
            int position = Services::LoadQueue::JsonFieldInt(record, "position", int(offset + int(i) + 1));
            int score = Services::LoadQueue::JsonFieldInt(record, "score", -1);
            if (accountId.Length == 0 || position < 1) continue;

            uint row = startIndex + i;
            positions[row] = position;
            accountIds[row] = accountId;
            int shortLen = Math::Min(8, accountId.Length);
            names[row] = accountId.SubStr(0, shortLen) + "...";
            times[row] = score > 0 ? FormatMs(score) : "-";
            scores[row] = score;

            auto cachedName = PlayerDirectory::GetCachedByAccountId(accountId);
            if (cachedName !is null && !cachedName.missing && cachedName.displayName.Length > 0) {
                names[row] = cachedName.displayName;
            }

            newAccountIds.InsertLast(accountId);
        }

        if (int(top.Length) < PAGE_SIZE) hasMore = false;

        if (newAccountIds.Length > 0) {
            auto nameMap = NadeoServices::GetDisplayNamesAsync(newAccountIds);
            if (nameMap !is null) {
                for (uint i = 0; i < newAccountIds.Length; i++) {
                    if (!nameMap.Exists(newAccountIds[i])) continue;
                    string resolved = Text::StripFormatCodes(string(nameMap[newAccountIds[i]])).Trim();
                    if (resolved.Length == 0) continue;
                    names[startIndex + i] = resolved;
                    PlayerDirectory::ObserveAccountDisplayName(newAccountIds[i], resolved, "mlhook-map-leaderboard");
                }
            }
        }

        if (!HasAnyRecords() && error.Length == 0) error = "No usable leaderboard records found.";
        if (IsPageLoaded(requestedPage)) {
            page = requestedPage;
            goToPage = tostring(page + 1);
        }
        loading = false;
        loaded = true;
    }

    void LoadAtIndex(uint idx) {
        if (idx >= accountIds.Length) return;
        if (accountIds[idx].Length == 0) return;
        int offset = positions[idx] > 0 ? positions[idx] - 1 : int(idx);
        ToggleGhostMgr::LoadGhost(accountIds[idx], offset, names[idx], scores[idx]);
    }

    void UnloadAtIndex(uint idx) {
        if (idx >= accountIds.Length) return;
        if (accountIds[idx].Length == 0) return;
        ToggleGhostMgr::UnloadGhost(accountIds[idx]);
    }

    void LoadVisiblePage() {
        int pageStart = page * PAGE_SIZE;
        int visibleStart = Math::Max(pageStart, CustomOffset());
        int visibleEnd = Math::Min(pageStart + PAGE_SIZE, visibleStart + ClampCustomCount());
        visibleEnd = Math::Min(visibleEnd, int(accountIds.Length));
        for (int i = visibleStart; i < visibleEnd; i++) {
            LoadAtIndex(uint(i));
        }
    }

    void UnloadVisiblePage() {
        int pageStart = page * PAGE_SIZE;
        int visibleStart = Math::Max(pageStart, CustomOffset());
        int visibleEnd = Math::Min(pageStart + PAGE_SIZE, visibleStart + ClampCustomCount());
        visibleEnd = Math::Min(visibleEnd, int(accountIds.Length));
        for (int i = visibleStart; i < visibleEnd; i++) {
            if (IsLoaded(accountIds[uint(i)])) UnloadAtIndex(uint(i));
        }
    }

    void Render() {
        EnsureAutoLoaded();

        if (!IsAvailable()) {
            UI::Text("\\$f90" + Icons::ExclamationTriangle + " MLHook is not loaded.\\$z");
            return;
        }

        string mapUid = CurrentMap::GetMapUid();
        if (mapUid.Length == 0) {
            UI::TextDisabled("No map is currently loaded.");
            return;
        }

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::BeginDisabled(loading);
        if (_UI::Button(Icons::Refresh + " Refresh Top 10")) {
            Reset();
            FetchPage(0);
        }
        UI::EndDisabled();
        UI::SameLine();

        UI::BeginDisabled(loading);
        if (_UI::Button(Icons::Plus + " Load More")) {
            FetchMore();
        }
        UI::EndDisabled();
        _UI::SimpleTooltip("Fetch the next 10 leaderboard records.");
        UI::SameLine();

        UI::BeginDisabled(accountIds.Length == 0);
        if (_UI::Button(Icons::Download + " Load Page")) {
            LoadVisiblePage();
        }
        UI::EndDisabled();
        UI::SameLine();

        UI::BeginDisabled(accountIds.Length == 0);
        if (_UI::Button(Icons::EyeSlash + " Hide Page")) {
            UnloadVisiblePage();
        }
        UI::EndDisabled();

        if (loading) {
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled(Icons::Refresh + " Fetching leaderboard records...");
        } else if (error.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::Text("\\$f90" + Icons::ExclamationTriangle + " " + error + "\\$z");
        }

        if (HasAnyRecords()) {
            int pageStart = page * PAGE_SIZE;

            UI::Dummy(vec2(0, 4));
            UI::SetNextItemWidth(92);
            customRank = UI::InputInt("Rank##MLHookCustomRank", customRank);
            ClampCustomRank();
            _UI::SimpleTooltip("1 = WR. Fetches the page containing this rank.");
            UI::SameLine();
            UI::SetNextItemWidth(80);
            customCount = UI::InputInt("Count##MLHookCustomCount", customCount);
            ClampCustomCount();
            _UI::SimpleTooltip("Number of displayed records to load from this offset. Limited to 10.");
            UI::SameLine();
            UI::BeginDisabled(loading);
            if (_UI::Button(Icons::Search + " Fetch Offset")) FetchCustomRange();
            UI::EndDisabled();
            UI::SameLine();

            UI::BeginDisabled(page == 0);
            if (_UI::IconButton(Icons::ChevronLeft, "mlPrev")) JumpToPage(page - 1);
            UI::EndDisabled();

            UI::SameLine();
            UI::Text("Page " + (page + 1));
            UI::SameLine();

            UI::SetNextItemWidth(56);
            goToPage = UI::InputText("##MLHookGoToPage", goToPage);
            if (UI::IsItemDeactivated()) {
                int targetPage = page;
                try { targetPage = Text::ParseInt(goToPage) - 1; } catch {
                    log("Failed to parse MLHook page input '" + goToPage + "': " + getExceptionInfo(), LogLevel::Debug, -1, "Render");
                }
                JumpToPage(targetPage);
            }
            _UI::SimpleTooltip("Go to a page by fetching that page directly.");
            UI::SameLine();

            UI::BeginDisabled(loading);
            if (_UI::IconButton(Icons::ChevronRight, "mlNext")) JumpToPage(page + 1);
            UI::EndDisabled();

            UI::Dummy(vec2(0, 2));
            UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, 5));
            UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));

            int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::SizingFixedFit;
            if (UI::BeginTable("MLHookGhosts", 5, flags)) {
                UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 45);
                UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 95);
                UI::TableSetupColumn("State", UI::TableColumnFlags::WidthFixed, 70);
                UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 90);
                UI::TableHeadersRow();

                int visibleStart = Math::Max(pageStart, CustomOffset());
                int visibleEnd = Math::Min(pageStart + PAGE_SIZE, visibleStart + ClampCustomCount());
                visibleEnd = Math::Min(visibleEnd, int(accountIds.Length));
                for (int ri = visibleStart; ri < visibleEnd; ri++) {
                    uint i = uint(ri);
                    if (i >= accountIds.Length || accountIds[i].Length == 0) continue;
                    bool isLoaded = IsLoaded(accountIds[i]);
                    UI::TableNextRow();

                    UI::TableNextColumn();
                    UI::Text("" + positions[i]);

                    UI::TableNextColumn();
                    UI::Text(names[i]);
                    _UI::SimpleTooltip("Account: " + accountIds[i]);

                    UI::TableNextColumn();
                    UI::Text(times[i]);

                    UI::TableNextColumn();
                    if (isLoaded) UI::Text("\\$0f0Loaded\\$z");
                    else UI::TextDisabled("Hidden");

                    UI::TableNextColumn();
                    if (!isLoaded) {
                        if (_UI::IconButton(Icons::Download, "ml_load_" + ri, vec2(32, 0))) LoadAtIndex(i);
                        _UI::SimpleTooltip("Load through MLHook");
                    } else {
                        if (_UI::IconButton(Icons::EyeSlash, "ml_hide_" + ri, vec2(32, 0))) UnloadAtIndex(i);
                        _UI::SimpleTooltip("Hide through MLHook");
                    }
                }

                UI::EndTable();
            }

            UI::PopStyleColor();
            UI::PopStyleVar();
        }

        UI::PopStyleVar();
    }
}
}
}
#endif
