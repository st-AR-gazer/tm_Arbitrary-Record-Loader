namespace EntryPoints {
namespace PlayerId {
    string searchInput;
    string resolvedAccountId;
    string resolvedDisplayName;
    string resolveStatus;
    uint resolveStatusTime;
    bool isResolving = false;

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

    void ResolveInput() {
        PlayerDirectory::EnsureInit();

        string input = searchInput.Trim();
        if (input.Length == 0) return;

        if (IsUUID(input)) {
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
        if (exactMatches.Length == 1 && !exactMatches[0].stale) {
            ApplySelectedResult(exactMatches[0], "\\$0f0" + Icons::Check + " Found in local cache\\$z");
            isResolving = false;
            return;
        }

        resolvedDisplayName = input;
        if (exactMatches.Length == 1) {
            resolvedAccountId = exactMatches[0].accountId;
        } else {
            resolvedAccountId = "";
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
        PlayerDirectory::SearchAggregator(query, 20);

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

        auto results = PlayerDirectory::SearchLocal(query, 20);
        if (results.Length > 0) {
            SetResolveStatus("\\$ff0" + Icons::Search + " " + results.Length + " matches found\\$z");
        } else {
            SetResolveStatus("\\$f00" + Icons::Times + " No player found with that name\\$z");
        }
        isResolving = false;
    }

    void Render() {
        PlayerDirectory::EnsureInit();

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::Text(Icons::User + " \\$fffLoad a player's ghost on the current map");
        UI::TextDisabled("Enter a player name or account ID (UUID). Uses the shared aggregator cache plus local cache.");
        UI::Dummy(vec2(0, 4));

        UI::AlignTextToFramePadding();
        UI::Text(Icons::Search);
        UI::SameLine();
        UI::PushItemWidth(-170);
        searchInput = UI::InputText("##PlayerSearch", searchInput);
        UI::PopItemWidth();

        UI::SameLine();
        UI::BeginDisabled(searchInput.Trim().Length == 0 || isResolving);
        if (UI::Button(Icons::Search + " Search", vec2(75, 0))) {
            ResolveInput();
        }
        UI::EndDisabled();

        UI::SameLine();
        if (UI::Button(Icons::User + " Me", vec2(75, 0))) {
            searchInput = NadeoServices::GetAccountID();
            ResolveInput();
        }
        _UI::SimpleTooltip("Use your own account ID");

        if (isResolving) {
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

        if (resolvedAccountId.Length > 0 && !isResolving) {
            UI::Dummy(vec2(0, 4));
            UI::PushStyleColor(UI::Col::ChildBg, vec4(0.12f, 0.12f, 0.14f, 1.0f));
            UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
            float cardHeight = Math::Max(UI::GetFrameHeight(), UI::GetTextLineHeightWithSpacing()) * 2.0f + 14.0f;
            bool cardVis = UI::BeginChild("ARL_PlayerCard", vec2(0, cardHeight), true);
            if (cardVis) {
                UI::Text(Icons::User + " \\$fff" + (resolvedDisplayName.Length > 0 ? resolvedDisplayName : "(unknown)") + "\\$z");
                UI::TextDisabled(resolvedAccountId);

                UI::SameLine();
                float btnX = UI::GetWindowSize().x - 150;
                if (btnX > UI::GetCursorPos().x) {
                    UI::SetCursorPosX(btnX);
                    UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
                    UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
                    UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
                    string curMap = get_CurrentMapUID();
                    UI::BeginDisabled(curMap.Length == 0);
                    if (UI::Button(Icons::Download + " Load Ghost", vec2(140, 0))) {
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

        if (!IsUUID(searchInput.Trim()) && searchInput.Trim().Length >= 2 && !isResolving) {
            auto results = PlayerDirectory::SearchLocal(searchInput, 20);
            if (results.Length > 0) {
                UI::Dummy(vec2(0, 6));
                UI::PushStyleColor(UI::Col::Separator, vec4(0.3f, 0.3f, 0.35f, 0.5f));
                UI::Separator();
                UI::PopStyleColor();
                UI::Dummy(vec2(0, 2));

                UI::Text(Icons::Search + " \\$fffSearch Results");
                UI::SameLine();
                UI::TextDisabled("(local + shared cache)");
                UI::Dummy(vec2(0, 2));

                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));
                UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
                int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY;
                if (UI::BeginTable("ARL_PlayerSearch", 3, tflags, vec2(0, Math::Min(240.0f, float(results.Length) * 28.0f + 30.0f)))) {
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Account ID", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 60);
                    UI::TableHeadersRow();

                    for (uint ri = 0; ri < results.Length; ri++) {
                        auto result = results[ri];
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
                        if (UI::Button(Icons::ArrowRight + "##ps_" + ri, vec2(28, 0))) {
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
                        if (UI::Button(Icons::Download + "##pl_" + ri, vec2(28, 0))) {
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

        UI::PopStyleVar();
    }
}
}
