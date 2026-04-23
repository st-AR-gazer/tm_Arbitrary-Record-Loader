namespace EntryPoints {
namespace PlayerId {
    string searchInput;
    string resolvedAccountId;
    string resolvedDisplayName;
    string resolveStatus;
    uint resolveStatusTime;
    bool isResolving = false;
    string lastSearchQuery = "";
    array<PlayerDirectory::LookupResult@>@ lastSearchResults = array<PlayerDirectory::LookupResult@>();
    string localResultsQuery = "";
    array<PlayerDirectory::LookupResult@>@ localResults = array<PlayerDirectory::LookupResult@>();
    int localResultsPage = 0;

    const float SEARCH_ACTION_BUTTON_WIDTH = 75.0f;
    const uint LOCAL_RESULTS_PAGE_SIZE = 10;

    bool IsUUID(const string &in s) {
        return PlayerDirectory::NormalizeAccountId(s).Length > 0;
    }

    void SetResolveStatus(const string &in status) {
        resolveStatus = status;
        resolveStatusTime = Time::Now;
    }

    void ApplySelectedResult(PlayerDirectory::LookupResult@ result, const string &in status) {
        if (result is null || result.missing) return;
        resolvedAccountId = result.accountId;
        resolvedDisplayName = result.displayName;
        SetResolveStatus(status);
    }

    void ClearSearchResults() {
        lastSearchQuery = "";
        lastSearchResults.RemoveRange(0, lastSearchResults.Length);
    }

    bool HasCurrentSearchResults() {
        return PlayerDirectory::NormalizeDisplayNameKey(lastSearchQuery) == PlayerDirectory::NormalizeDisplayNameKey(searchInput)
            && lastSearchResults.Length > 0;
    }

    void RefreshLocalResults() {
        string query = searchInput.Trim();
        string normalized = PlayerDirectory::NormalizeDisplayNameKey(query);
        if (normalized == PlayerDirectory::NormalizeDisplayNameKey(localResultsQuery)) return;

        localResultsQuery = query;
        localResultsPage = 0;
        localResults.RemoveRange(0, localResults.Length);
        if (query.Length < 2 || IsUUID(query) || !PlayerDirectory::IsReady()) return;

        auto results = PlayerDirectory::SearchLocal(query, 100);
        for (uint i = 0; i < results.Length; i++) {
            localResults.InsertLast(results[i]);
        }
    }

    void ResolveInput() {
        PlayerDirectory::EnsureInit();

        string input = searchInput.Trim();
        if (input.Length == 0) return;

        if (IsUUID(input)) {
            ClearSearchResults();
            resolvedAccountId = PlayerDirectory::NormalizeAccountId(input);
            auto cached = PlayerDirectory::GetCachedByAccountId(resolvedAccountId);
            resolvedDisplayName = (cached !is null && !cached.missing) ? cached.displayName : "";

            if (cached !is null && !cached.missing && !cached.stale) {
                SetResolveStatus("\\$0f0" + Icons::Check + " Found in local cache\\$z");
                isResolving = false;
                return;
            }

            isResolving = true;
            resolveStatus = "";
            startnew(Coro_ResolveDisplayName);
            return;
        }

        auto exactMatches = PlayerDirectory::FindExactLocal(input);
        if (exactMatches.Length == 1) {
            resolvedAccountId = exactMatches[0].accountId;
            resolvedDisplayName = exactMatches[0].displayName;
        } else {
            resolvedAccountId = "";
            resolvedDisplayName = input;
        }

        isResolving = true;
        resolveStatus = "";
        startnew(Coro_SearchByDisplayName);
    }

    void Coro_ResolveDisplayName() {
        auto result = PlayerDirectory::ResolveAccountIdToName(resolvedAccountId);
        if (result !is null && !result.missing) {
            resolvedDisplayName = result.displayName;
            if (result.stale) {
                SetResolveStatus("\\$ff0" + Icons::ClockO + " Using cached player name\\$z");
            } else {
                SetResolveStatus("\\$0f0" + Icons::Check + " Resolved player name\\$z");
            }
        } else {
            SetResolveStatus("\\$f90" + Icons::ExclamationTriangle + " Could not resolve display name\\$z");
        }
        isResolving = false;
    }

    void Coro_SearchByDisplayName() {
        string query = resolvedDisplayName.Trim();
        auto results = PlayerDirectory::SearchDisplayNames(query, 20, true);
        lastSearchQuery = query;
        lastSearchResults.RemoveRange(0, lastSearchResults.Length);
        for (uint i = 0; i < results.Length; i++) {
            lastSearchResults.InsertLast(results[i]);
        }

        auto exactMatches = PlayerDirectory::FindExactLocal(query);
        if (exactMatches.Length == 1) {
            if (exactMatches[0].stale) {
                ApplySelectedResult(exactMatches[0], "\\$ff0" + Icons::ClockO + " Using cached player match\\$z");
            } else {
                ApplySelectedResult(exactMatches[0], "\\$0f0" + Icons::Check + " Resolved player\\$z");
            }
            isResolving = false;
            return;
        }

        if (exactMatches.Length > 1) {
            SetResolveStatus("\\$ff0" + Icons::Search + " " + exactMatches.Length + " exact matches found\\$z");
            isResolving = false;
            return;
        }

        if (results.Length > 0) {
            SetResolveStatus("\\$ff0" + Icons::Search + " " + results.Length + " matches found\\$z");
        } else {
            SetResolveStatus("\\$f00" + Icons::Times + " No player found with that name\\$z");
        }
        isResolving = false;
    }

    void RenderSearchControls() {
        vec2 itemSpacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
        float buttonWidth = _UI::ButtonSize(vec2(SEARCH_ACTION_BUTTON_WIDTH, 0)).x;
        float inputReserveWidth = buttonWidth * 2.0f + itemSpacing.x * 2.0f;

        UI::AlignTextToFramePadding();
        UI::Text(Icons::Search);
        UI::SameLine();
        UI::SetNextItemWidth(-inputReserveWidth);
        searchInput = UI::InputText("##PlayerSearch", searchInput);
        RefreshLocalResults();

        UI::SameLine();
        UI::BeginDisabled(searchInput.Trim().Length == 0 || isResolving);
        if (_UI::Button(Icons::Search + " Search", vec2(SEARCH_ACTION_BUTTON_WIDTH, 0))) {
            ResolveInput();
        }
        UI::EndDisabled();
        _UI::SimpleTooltip("Search local cache + aggregator.xjk.yt shared cache. Nadeo is only used when resolving an account ID that the caches cannot name.");

        UI::SameLine();
        if (_UI::Button(Icons::User + " Me", vec2(SEARCH_ACTION_BUTTON_WIDTH, 0))) {
            searchInput = NadeoServices::GetAccountID();
            ResolveInput();
        }
        _UI::SimpleTooltip("Use your own account ID");

        if (PlayerDirectory::IsLoading()) {
            UI::TextDisabled(Icons::Refresh + " Loading player cache...");
        } else if (isResolving) {
            UI::TextDisabled(Icons::Refresh + " Resolving...");
        } else if (resolveStatus.Length > 0 && Time::Now - resolveStatusTime < 15000) {
            UI::Text(resolveStatus);
        }

        if (searchInput.Trim().Length > 0) {
            if (IsUUID(searchInput.Trim())) {
                UI::TextDisabled(Icons::IdCard + " Detected: Account ID (UUID)");
            } else {
                UI::TextDisabled(Icons::User + " Detected: Display name");
            }
        }
    }

    void RenderResolvedPlayer() {
        if (resolvedAccountId.Length > 0 && !isResolving) {
            UI::Dummy(vec2(0, 4));
            UI::PushStyleColor(UI::Col::ChildBg, vec4(0.12f, 0.12f, 0.14f, 1.0f));
            UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
            float cardHeight = Math::Max(UI::GetFrameHeight(), UI::GetTextLineHeightWithSpacing()) * 2.0f + 14.0f;
            bool cardVis = UI::BeginChild("PlayerCard", vec2(0, cardHeight), true);
            if (cardVis) {
            UI::Text(Icons::User + " \\$fff" + (resolvedDisplayName.Length > 0 ? resolvedDisplayName : "(unknown)") + "\\$z");
                UI::TextDisabled(resolvedAccountId);
                UI::TextDisabled(Icons::InfoCircle + " ARL will only know whether this player has a record on the current map after trying to load it.");

                UI::SameLine();
                float btnX = UI::GetWindowSize().x - 150;
                if (btnX > UI::GetCursorPos().x) {
                    UI::SetCursorPosX(btnX);
                    UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
                    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
                    UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
                    string curMap = get_CurrentMapUID();
                    UI::BeginDisabled(curMap.Length == 0);
                    if (_UI::Button(Icons::Download + " Load Ghost", vec2(140, 0))) {
                        loadRecord.LoadRecordFromPlayerId(resolvedAccountId);
                    }
                    UI::EndDisabled();
                    UI::PopStyleColor(3);
                    if (curMap.Length == 0) {
                        _UI::SimpleTooltip("No map loaded - load a map first");
                    }
                }
            }
            UI::EndChild();
            UI::PopStyleVar();
            UI::PopStyleColor();
        }
    }

    void RenderSearchResults() {
        if (PlayerDirectory::IsReady() && !IsUUID(searchInput.Trim()) && searchInput.Trim().Length >= 2 && !isResolving) {
            array<PlayerDirectory::LookupResult@>@ results = null;
            if (HasCurrentSearchResults()) @results = lastSearchResults;
            else @results = localResults;
            if (results.Length > 0) {
                UI::Dummy(vec2(0, 6));
                int pageCount = Math::Max(1, (int(results.Length) + int(LOCAL_RESULTS_PAGE_SIZE) - 1) / int(LOCAL_RESULTS_PAGE_SIZE));
                if (localResultsPage >= pageCount) localResultsPage = pageCount - 1;
                if (localResultsPage < 0) localResultsPage = 0;
                int pageStart = localResultsPage * int(LOCAL_RESULTS_PAGE_SIZE);
                int pageEnd = Math::Min(pageStart + int(LOCAL_RESULTS_PAGE_SIZE), int(results.Length));

                UI::TextDisabled("Showing " + (pageStart + 1) + "-" + pageEnd + " of " + results.Length + " local cached player(s)");
                UI::SameLine();
                UI::BeginDisabled(localResultsPage == 0);
                if (_UI::IconButton(Icons::ChevronLeft, "playerLocalPrev")) localResultsPage--;
                UI::EndDisabled();
                UI::SameLine();
                UI::Text("Page " + (localResultsPage + 1));
                UI::SameLine();
                UI::BeginDisabled(localResultsPage + 1 >= pageCount);
                if (_UI::IconButton(Icons::ChevronRight, "playerLocalNext")) localResultsPage++;
                UI::EndDisabled();

                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));
                UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
                int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY;
                if (UI::BeginTable("PlayerSearch", 3, tflags, vec2(0, Math::Min(320.0f, float(pageEnd - pageStart) * 28.0f + 30.0f)))) {
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Account ID", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 60);
                    UI::TableHeadersRow();

                    for (int ri = pageStart; ri < pageEnd; ri++) {
                        auto result = results[uint(ri)];
                        if (result is null || result.missing) continue;

                        UI::TableNextRow();

                        UI::TableNextColumn();
                        if (result.stale) {
                            UI::TextDisabled(result.displayName);
                            _UI::SimpleTooltip("Cached entry is older than 6 months and will be refreshed when possible.");
                        } else {
                            UI::Text(result.displayName);
                        }

                        UI::TableNextColumn();
                        UI::TextDisabled(result.accountId);

                        UI::TableNextColumn();
                        if (_UI::IconButton(Icons::ArrowRight, "ps_" + ri, vec2(28, 0))) {
                            resolvedAccountId = result.accountId;
                            resolvedDisplayName = result.displayName;
                            searchInput = result.displayName;
                            if (result.stale) {
                                SetResolveStatus("\\$ff0" + Icons::ClockO + " Selected cached player\\$z");
                            } else {
                                SetResolveStatus("\\$0f0" + Icons::Check + " Selected\\$z");
                            }
                        }
                        _UI::SimpleTooltip("Select this player");
                        UI::SameLine();
                        if (_UI::IconButton(Icons::Download, "pl_" + ri, vec2(28, 0))) {
                            loadRecord.LoadRecordFromPlayerId(result.accountId);
                        }
                        _UI::SimpleTooltip("Load ghost immediately");
                    }

                    UI::EndTable();
                }
                UI::PopStyleColor();
                UI::PopStyleVar();
            }
        }
    }

    void RenderDetails() {
        RenderResolvedPlayer();
        RenderSearchResults();
    }

    void Render() {
        PlayerDirectory::EnsureInit();

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        RenderSearchControls();
        RenderDetails();

        UI::PopStyleVar();
    }
}
}
