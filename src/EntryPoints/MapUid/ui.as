namespace EntryPoints {
namespace MapUid {
    string ghostPosition = "1";
    string mapUID;
    bool autoFilled = false;

    int batchFrom = 1;
    int batchTo = 5;

    array<string> lbNames;
    array<string> lbTimes;
    array<uint>   lbScores;
    array<string> lbAccountIds;
    array<int>    lbPositions;
    bool lbLoading = false;
    bool lbLoaded = false;
    string lbMapUid = "";
    string lbError = "";
    int lbPage = 0;
    int lbPageSize = 10;
    int lbTotalRequested = 0;
    bool lbHasMore = true;
    bool lbSectionOpen = false;
    bool lbNeedsLoad = false;
    string lbGoToPage = "1";
    const float FORM_WIDTH = 540.0f;
    const float MAP_UID_BUTTON_WIDTH = 110.0f;
    const float RANK_INPUT_WIDTH = 120.0f;

    void ResetLeaderboard() {
        lbNames.RemoveRange(0, lbNames.Length);
        lbTimes.RemoveRange(0, lbTimes.Length);
        lbScores.RemoveRange(0, lbScores.Length);
        lbAccountIds.RemoveRange(0, lbAccountIds.Length);
        lbPositions.RemoveRange(0, lbPositions.Length);
        lbLoaded = false;
        lbLoading = false;
        lbError = "";
        lbPage = 0;
        lbTotalRequested = 0;
        lbHasMore = true;
        lbGoToPage = "1";
    }

    void JumpToLeaderboardPage(int targetPage) {
        if (targetPage < 0) targetPage = 0;

        int maxLoadedPage = lbPageSize > 0 ? Math::Max(0, (int(lbPositions.Length) - 1) / lbPageSize) : 0;
        if (!lbHasMore && targetPage > maxLoadedPage) targetPage = maxLoadedPage;

        lbPage = targetPage;
        lbGoToPage = tostring(lbPage + 1);

        if (lbPageSize > 0 && lbPage * lbPageSize >= int(lbPositions.Length) && lbHasMore && !lbLoading) {
            FetchLeaderboardPage();
        }
    }

    void FetchLeaderboardPage() {
        if (mapUID.Length == 0) return;
        lbLoading = true;
        lbError = "";
        lbMapUid = mapUID;
        startnew(Coro_FetchLeaderboardPage);
    }

    void Coro_FetchLeaderboardPage() {
        int offset = lbTotalRequested;
        string url = "https://live-services.trackmania.nadeo.live/api/token/leaderboard/group/Personal_Best/map/" + lbMapUid + "/top?onlyWorld=true&length=" + lbPageSize + "&offset=" + offset;
        RequestThrottle::WaitForSlot("LoadFromMapUid leaderboard");
        auto req = NadeoServices::Get("NadeoLiveServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            lbError = "API error (code " + req.ResponseCode() + ")";
            lbLoading = false;
            lbLoaded = true;
            return;
        }

        Json::Value data = Json::Parse(req.String());
        if (data.GetType() == Json::Type::Null) {
            lbError = "Failed to parse response";
            lbLoading = false;
            lbLoaded = true;
            return;
        }

        auto tops = data["tops"];
        if (tops.GetType() != Json::Type::Array || tops.Length == 0) {
            lbError = offset == 0 ? "No leaderboard data found" : "";
            lbHasMore = false;
            lbLoading = false;
            lbLoaded = true;
            return;
        }

        auto top = tops[0]["top"];
        if (top.GetType() != Json::Type::Array) {
            lbError = "Invalid leaderboard format";
            lbLoading = false;
            lbLoaded = true;
            return;
        }

        if (int(top.Length) < lbPageSize) lbHasMore = false;

        array<string> newAccIds;

        for (uint ti = 0; ti < top.Length; ti++) {
            int pos = top[ti]["position"];
            string accId = top[ti]["accountId"];
            uint score = top[ti]["score"];

            lbPositions.InsertLast(pos);
            lbAccountIds.InsertLast(accId);
            lbScores.InsertLast(score);
            lbTimes.InsertLast(FormatMs(int(score)));
            lbNames.InsertLast("");
            newAccIds.InsertLast(accId);
        }

        lbTotalRequested += int(top.Length);

        if (newAccIds.Length > 0) {
            auto nameMap = NadeoServices::GetDisplayNamesAsync(newAccIds);
            if (nameMap !is null) {
                uint startIdx = lbNames.Length - newAccIds.Length;
                for (uint ni = 0; ni < newAccIds.Length; ni++) {
                    string resolved = "";
                    if (nameMap.Exists(newAccIds[ni])) {
                        resolved = string(nameMap[newAccIds[ni]]);
                    }
                    lbNames[startIdx + ni] = resolved.Length > 0 ? resolved : newAccIds[ni].SubStr(0, 8) + "...";
                }
            }
        }

        lbLoading = false;
        lbLoaded = true;
    }

    void Render() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        float availWidth = UI::GetContentRegionAvail().x;
        float formWidth = Math::Min(FORM_WIDTH, availWidth);
        float mapUidInputWidth = formWidth - _UI::ButtonSize(vec2(MAP_UID_BUTTON_WIDTH, 0)).x - 36.0f;
        if (mapUidInputWidth < 180.0f) mapUidInputWidth = 180.0f;

        if (!autoFilled && mapUID.Length == 0) {
            mapUID = get_CurrentMapUID();
            autoFilled = true;
        }

        string curMapName = get_CurrentMapName();
        string curMapUid = get_CurrentMapUID();

        UI::AlignTextToFramePadding();
        UI::Text(Icons::Map);
        UI::SameLine();
        UI::PushItemWidth(mapUidInputWidth);
        string prevMapUID = mapUID;
        mapUID = UI::InputText("##MapUID", mapUID);
        UI::PopItemWidth();
        UI::SameLine();
        UI::BeginDisabled(curMapUid.Length == 0);
        if (_UI::Button(Icons::Crosshairs + " Current Map", vec2(MAP_UID_BUTTON_WIDTH, 0))) {
            mapUID = curMapUid;
            ResetLeaderboard();
        }
        UI::EndDisabled();
        if (curMapUid.Length > 0 && curMapName.Length > 0) {
            _UI::SimpleTooltip(Text::StripFormatCodes(curMapName) + " — " + curMapUid);
        }
        if (mapUID != prevMapUID) {
            ResetLeaderboard();
        }

        UI::Dummy(vec2(0, 2));
        UI::PushItemWidth(RANK_INPUT_WIDTH);
        ghostPosition = UI::InputText("Rank", ghostPosition);
        UI::PopItemWidth();
        _UI::SimpleTooltip("Enter the player's rank. 1 = world record. 0 or negative also loads rank 1.");

        UI::SameLine();
        UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
        UI::BeginDisabled(mapUID.Length == 0);
        if (_UI::Button(Icons::Download + " Fetch Ghost")) {
            loadRecord.LoadRecordFromMapUid(mapUID, ghostPosition, "AnyMap");
        }
        UI::EndDisabled();
        UI::PopStyleColor(3);
        _UI::SimpleTooltip("Download and load ghost at this rank");
        RenderHighRankLookupWarning(ParseRankInput(ghostPosition));

        RenderLeaderboardBrowser();

        UI::Dummy(vec2(0, 2));

        if (UI::CollapsingHeader(Icons::Clone + " Batch Load")) {
            UI::Indent(4);

            UI::PushItemWidth(120);
            batchFrom = UI::InputInt("From Rank", batchFrom);
            UI::PopItemWidth();
            UI::SameLine();
            UI::PushItemWidth(120);
            batchTo = UI::InputInt("To Rank", batchTo);
            UI::PopItemWidth();

            int normalizedBatchFrom = NormalizeRankInput(batchFrom);
            int normalizedBatchTo = NormalizeRankInput(batchTo);
            int batchCount = (normalizedBatchTo >= normalizedBatchFrom) ? (normalizedBatchTo - normalizedBatchFrom + 1) : 0;
            UI::SameLine();
            UI::TextDisabled("(" + batchCount + " ghosts)");

            UI::BeginDisabled(mapUID.Length == 0 || batchCount == 0);
            if (_UI::Button(Icons::Download + " Load Range")) {
                for (int bi = normalizedBatchFrom; bi <= normalizedBatchTo; bi++) {
                    loadRecord.LoadRecordFromMapUid(mapUID, tostring(bi), "AnyMap", "", "");
                }
            }
            UI::EndDisabled();
            RenderHighRankLookupWarning(normalizedBatchTo);
            UI::Unindent(4);
        }
        UI::PopStyleVar();
    }

    void RenderLeaderboardBrowser() {
        UI::Dummy(vec2(0, 6));
        UI::PushStyleColor(UI::Col::Separator, vec4(0.3f, 0.3f, 0.35f, 0.5f));
        UI::Separator();
        UI::PopStyleColor();
        UI::Dummy(vec2(0, 2));

        UI::BeginDisabled(mapUID.Length == 0);
        bool wasOpen = lbSectionOpen;
        lbSectionOpen = UI::CollapsingHeader(Icons::Trophy + " Leaderboard Browser");
        UI::EndDisabled();

        if (lbSectionOpen) {
            if (!wasOpen || (lbMapUid != mapUID && !lbLoading)) {
                if (!lbLoading && (lbMapUid != mapUID || !lbLoaded)) {
                    ResetLeaderboard();
                    lbMapUid = mapUID;
                    FetchLeaderboardPage();
                }
            }

            UI::Indent(4);

            if (lbLoading && lbPositions.Length == 0) {
                UI::TextDisabled(Icons::Refresh + " Loading leaderboard...");
            } else if (lbError.Length > 0 && lbPositions.Length == 0) {
                UI::Text("\\$f90" + Icons::ExclamationTriangle + " " + lbError + "\\$z");
            } else if (lbPositions.Length > 0) {
                int pageStart = lbPage * lbPageSize;
                int pageEnd = Math::Min(pageStart + lbPageSize, int(lbPositions.Length));

                UI::TextDisabled("Showing " + (pageStart + 1) + "-" + pageEnd + " of " + lbPositions.Length + (lbHasMore ? "+" : "") + " records");
                UI::SameLine();

                UI::BeginDisabled(lbPage == 0);
                if (_UI::IconButton(Icons::ChevronLeft, "lbPrev")) { JumpToLeaderboardPage(lbPage - 1); }
                UI::EndDisabled();

                UI::SameLine();
                UI::Text("Page " + (lbPage + 1));
                UI::SameLine();

                UI::SetNextItemWidth(56);
                lbGoToPage = UI::InputText("##lbGoToPage", lbGoToPage);
                if (UI::IsItemDeactivated()) {
                    int targetPage = lbPage;
                    try { targetPage = Text::ParseInt(lbGoToPage) - 1; } catch {}
                    JumpToLeaderboardPage(targetPage);
                }
                _UI::SimpleTooltip("Go to page");
                UI::SameLine();

                UI::BeginDisabled((pageEnd >= int(lbPositions.Length)) && !lbHasMore);
                if (_UI::IconButton(Icons::ChevronRight, "lbNext")) {
                    JumpToLeaderboardPage(lbPage + 1);
                }
                UI::EndDisabled();

                if (lbLoading) {
                    UI::SameLine();
                    UI::TextDisabled(Icons::Refresh + " Loading...");
                }

                UI::Dummy(vec2(0, 2));

                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));
                UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
                int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders;
                float lbActionColWidth = _UI::ButtonSize(vec2(28, 0)).x * 2.0f + UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x + 6.0f;
                if (UI::BeginTable("LBBrowser", 4, tflags)) {
                    UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 45);
                    UI::TableSetupColumn("Player", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 95);
                    UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, lbActionColWidth);
                    UI::TableHeadersRow();

                    for (int ri = pageStart; ri < pageEnd; ri++) {
                        UI::TableNextRow();

                        UI::TableNextColumn();
                        int pos = lbPositions[ri];
                        if (pos == 1) UI::Text("\\$fd0" + Icons::Trophy + " " + pos + "\\$z");
                        else if (pos == 2) UI::Text("\\$ddd" + pos + "\\$z");
                        else if (pos == 3) UI::Text("\\$c73" + pos + "\\$z");
                        else UI::Text("" + pos);

                        UI::TableNextColumn();
                        UI::Text(lbNames[ri]);
                        _UI::SimpleTooltip("Account: " + lbAccountIds[ri]);

                        UI::TableNextColumn();
                        UI::Text(lbTimes[ri]);

                        UI::TableNextColumn();
                        if (_UI::IconButton(Icons::Download, "lbl_" + ri, vec2(28, 0))) {
                            print("ARL UI Load click: leaderboard row pos=" + pos + " mapUid=" + mapUID);
                            NotifyInfo("Queueing leaderboard record #" + pos);
                            loadRecord.LoadRecordFromMapUid(mapUID, tostring(pos), "AnyMap");
                        }
                        _UI::SimpleTooltip("Load #" + pos + " — " + lbNames[ri] + " (" + lbTimes[ri] + ")");
                        UI::SameLine();
                        if (_UI::IconButton(Icons::ArrowRight, "lbs_" + ri, vec2(28, 0))) {
                            ghostPosition = tostring(pos);
                        }
                        _UI::SimpleTooltip("Set rank field to #" + pos);
                    }

                    UI::EndTable();
                }
                UI::PopStyleColor();
                UI::PopStyleVar();
            }

            UI::Unindent(4);
        }
    }
}
}
