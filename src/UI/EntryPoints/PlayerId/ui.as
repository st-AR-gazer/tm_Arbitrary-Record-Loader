namespace EntryPoints {
namespace PlayerId {
    string searchInput;
    string resolvedAccountId;
    string resolvedDisplayName;
    string resolveStatus;
    uint resolveStatusTime;
    bool isResolving = false;

    bool gpCacheLoaded = false;
    dictionary gpNameToId;
    dictionary gpIdToName;

    string gpFilePath = IO::FromStorageFolder("../ghosts-pp/player_names.jsons");

    void LoadGhostsPPCache() {
        if (gpCacheLoaded) return;
        gpCacheLoaded = true;

        if (!IO::FileExists(gpFilePath)) return;

        try {
            IO::File file(gpFilePath, IO::FileMode::Read);
            string content = file.ReadToEnd();
            file.Close();

            auto lines = content.Split("\n");
            for (uint li = 0; li < lines.Length; li++) {
                string line = lines[li].Trim();
                if (line.Length == 0) continue;

                Json::Value entry = Json::Parse(line);
                if (entry.GetType() != Json::Type::Object) continue;
                if (!entry.HasKey("wsid") || !entry.HasKey("names")) continue;

                string wsid = entry["wsid"];
                auto names = entry["names"];
                if (names.GetType() != Json::Type::Object) continue;

                auto nameKeys = names.GetKeys();
                for (uint ni = 0; ni < nameKeys.Length; ni++) {
                    string displayName = nameKeys[ni];
                    string stripped = Text::StripFormatCodes(displayName).Trim();
                    if (stripped.ToLower() == "personal best" || stripped.Length == 0) continue;

                    gpNameToId.Set(stripped.ToLower(), wsid);
                    gpIdToName.Set(wsid, stripped);
                }
            }
        } catch { }
    }

    bool IsUUID(const string &in s) {
        if (s.Length != 36) return false;
        if (s[8] != 0x2D || s[13] != 0x2D || s[18] != 0x2D || s[23] != 0x2D) return false;
        return true;
    }

    void ResolveInput() {
        if (searchInput.Trim().Length == 0) return;
        string input = searchInput.Trim();

        if (IsUUID(input)) {
            resolvedAccountId = input;
            resolvedDisplayName = "";
            isResolving = true;
            resolveStatus = "";
            startnew(Coro_ResolveDisplayName);
        } else {
            LoadGhostsPPCache();
            string inputLower = input.ToLower();

            if (gpNameToId.Exists(inputLower)) {
                resolvedAccountId = string(gpNameToId[inputLower]);
                resolvedDisplayName = input;
                resolveStatus = "\\$0f0" + Icons::Check + " Found in local cache\\$z";
                resolveStatusTime = Time::Now;
                isResolving = false;
            } else {
                resolvedAccountId = "";
                resolvedDisplayName = input;
                isResolving = true;
                resolveStatus = "";
                startnew(Coro_SearchByDisplayName);
            }
        }
    }

    void Coro_ResolveDisplayName() {
        string name = NadeoServices::GetDisplayNameAsync(resolvedAccountId);
        if (name.Length > 0) {
            resolvedDisplayName = name;
            resolveStatus = "\\$0f0" + Icons::Check + " " + name + "\\$z";
        } else {
            resolveStatus = "\\$f90" + Icons::ExclamationTriangle + " Could not resolve display name\\$z";
        }
        resolveStatusTime = Time::Now;
        isResolving = false;
    }

    void Coro_SearchByDisplayName() {
        LoadGhostsPPCache();

        auto keys = gpNameToId.GetKeys();
        array<string> matches;
        string inputLower = resolvedDisplayName.ToLower();

        for (uint ki = 0; ki < keys.Length; ki++) {
            if (keys[ki].Contains(inputLower)) {
                matches.InsertLast(keys[ki]);
                if (matches.Length >= 10) break;
            }
        }

        if (matches.Length == 1) {
            resolvedAccountId = string(gpNameToId[matches[0]]);
            resolveStatus = "\\$0f0" + Icons::Check + " Found: " + matches[0] + "\\$z";
        } else if (matches.Length > 1) {
            resolveStatus = "\\$ff0" + Icons::Search + " " + matches.Length + " matches found\\$z";
        } else {
            resolveStatus = "\\$f00" + Icons::Times + " No player found with that name\\$z";
        }

        resolveStatusTime = Time::Now;
        isResolving = false;
    }

    array<string> GetSearchResults() {
        array<string> results;
        if (searchInput.Trim().Length < 2) return results;
        if (IsUUID(searchInput.Trim())) return results;

        LoadGhostsPPCache();
        string inputLower = searchInput.Trim().ToLower();
        auto keys = gpNameToId.GetKeys();

        for (uint ki = 0; ki < keys.Length; ki++) {
            if (keys[ki].Contains(inputLower)) {
                results.InsertLast(keys[ki]);
                if (results.Length >= 20) break;
            }
        }
        return results;
    }

    void Render() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::Text(Icons::User + " \\$fffLoad a player's ghost on the current map");
        UI::TextDisabled("Enter a player name or account ID (UUID). Searches the current map's leaderboard.");
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
            bool cardVis = UI::BeginChild("ARL_PlayerCard", vec2(0, 56), true);
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
                        _UI::SimpleTooltip("No map loaded — load a map first");
                    }
                }
            }
            UI::EndChild();
            UI::PopStyleVar();
            UI::PopStyleColor();
        }

        if (!IsUUID(searchInput.Trim()) && searchInput.Trim().Length >= 2 && !isResolving) {
            auto results = GetSearchResults();
            if (results.Length > 0) {
                UI::Dummy(vec2(0, 6));
                UI::PushStyleColor(UI::Col::Separator, vec4(0.3f, 0.3f, 0.35f, 0.5f));
                UI::Separator();
                UI::PopStyleColor();
                UI::Dummy(vec2(0, 2));

                bool hasGPP = IO::FileExists(gpFilePath);
                UI::Text(Icons::Search + " \\$fffSearch Results");
                if (hasGPP) {
                    UI::SameLine();
                    UI::TextDisabled("(from ghosts++ cache)");
                }
                UI::Dummy(vec2(0, 2));

                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));
                UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
                int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY;
                if (UI::BeginTable("ARL_PlayerSearch", 3, tflags, vec2(0, Math::Min(200.0f, float(results.Length) * 28.0f + 30.0f)))) {
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Account ID", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 60);
                    UI::TableHeadersRow();

                    for (uint ri = 0; ri < results.Length; ri++) {
                        string name = results[ri];
                        string accId = string(gpNameToId[name]);

                        UI::TableNextRow();

                        UI::TableNextColumn();
                        UI::Text(name);

                        UI::TableNextColumn();
                        UI::TextDisabled(accId);

                        UI::TableNextColumn();
                        if (UI::Button(Icons::ArrowRight + "##ps_" + ri, vec2(28, 0))) {
                            resolvedAccountId = accId;
                            resolvedDisplayName = name;
                            searchInput = name;
                            resolveStatus = "\\$0f0" + Icons::Check + " Selected\\$z";
                            resolveStatusTime = Time::Now;
                        }
                        _UI::SimpleTooltip("Select this player");
                        UI::SameLine();
                        if (UI::Button(Icons::Download + "##pl_" + ri, vec2(28, 0))) {
                            loadRecord.LoadRecordFromPlayerId(accId);
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
