namespace EntryPoints {
namespace Official {

    enum OfficialSource {
        Seasonal = 0,
        Discovery,
        WeeklyShorts,
        WeeklyGrands
    }

    OfficialSource currentSource = OfficialSource::Seasonal;

    int selectedOffset = 1;

    string Official_MapUID;

    array<string> mapUids;
    bool mapUidsLoaded = false;
    string lastLoadedSeason = "";
    string officialSeasonUid = "";
    bool seasonalOpenLeaderboardAfterDetect = false;

    enum DiscoveryCampaign {
        Snow = 0,
        Rally,
        Desert,
        Stunt,
        Platform
    }

    array<string> discoveryNames = { "Snow Discovery", "Rally Discovery", "Desert Discovery", "Stunt Discovery", "Platform Discovery" };
    array<int> discoveryCampaignIds = { 55779, 61394, 68071, 71524, 78488 };
    int discoveryClubId = 150;

    int selectedDiscovery = -1;
    array<string> discoveryMapUids;
    array<string> discoveryMapNames;
    bool discoveryLoading = false;
    bool discoveryLoaded = false;
    string discoveryError = "";
    int selectedDiscoveryMap = -1;

    dictionary weeklyCache;

    array<string> weeklyMapUids;
    array<string> weeklyMapNames;
    array<int> weeklyMapPositions;
    string weeklyDisplayName = "";
    string weeklySeasonUid = "";
    bool weeklyLoading = false;
    bool weeklyLoaded = false;
    string weeklyError = "";
    int weeklySelectedMap = -1;
    int weeklyLoadedKind = -1;
    int weeklyLoadedOffset = -1;

    int shortsWeekOffset = 1;
    int grandsWeekOffset = 1;
    const int WEEKLY_DETECT_MAX_OFFSET = 64;

    void LoadMapUids() {
        if (Official::selectedYear < 0 || Official::selectedSeason < 0) return;
        if (Official::selectedYear >= int(Official::years.Length)) return;
        if (Official::selectedSeason >= int(Official::seasons.Length)) return;

        string season = Official::seasons[Official::selectedSeason];
        int year = Official::years[Official::selectedYear];
        string key = season + "_" + tostring(year);
        if (key == lastLoadedSeason && mapUidsLoaded && mapUids.Length > 0) return;

        mapUids.Resize(0);
        mapUidsLoaded = false;
        officialSeasonUid = "";

        string filePath = Server::officialJsonFilesDirectory + "/" + key + ".json";
        if (!IO::FileExists(filePath)) return;

        Json::Value root = Json::Parse(_IO::File::ReadFileToEnd(filePath));
        if (root.GetType() == Json::Type::Null) return;
        officialSeasonUid = string(root["seasonUid"]);
        if (officialSeasonUid.Length == 0) {
            officialSeasonUid = string(root["leaderboardGroupUid"]);
        }

        auto playlist = root["playlist"];
        if (playlist.GetType() != Json::Type::Array) return;

        int maxPos = -1;
        for (uint pi = 0; pi < playlist.Length; pi++) {
            int pos = playlist[pi]["position"];
            if (pos > maxPos) maxPos = pos;
        }
        int totalMaps = maxPos + 1;
        if (totalMaps <= 0) return;

        mapUids.Resize(uint(totalMaps));
        for (uint pi = 0; pi < mapUids.Length; pi++) mapUids[pi] = "";

        for (uint pi = 0; pi < playlist.Length; pi++) {
            int pos = playlist[pi]["position"];
            string uid = playlist[pi]["mapUid"];
            if (pos >= 0 && pos < int(mapUids.Length)) {
                mapUids[pos] = uid;
            }
        }

        lastLoadedSeason = key;
        mapUidsLoaded = true;
    }

    string discoveryCacheDir = IO::FromStorageFolder("cache/discovery/");

    string DiscoveryCachePath(int idx) {
        return discoveryCacheDir + discoveryNames[idx].Replace(" ", "_") + ".json";
    }

    int FindUidIndex(const array<string> &in uids, const string &in targetUid) {
        if (targetUid.Length == 0) return -1;
        for (uint i = 0; i < uids.Length; i++) {
            if (uids[i] == targetUid) return int(i);
        }
        return -1;
    }

    string GetDiscoveryCampaignData(int idx) {
        if (idx < 0 || idx >= int(discoveryCampaignIds.Length)) return "";

        string cachePath = DiscoveryCachePath(idx);
        if (IO::FileExists(cachePath)) {
            string cached = _IO::File::ReadFileToEnd(cachePath);
            if (cached.Length > 0) return cached;
        }

        int campId = discoveryCampaignIds[idx];
        string url = NadeoServices::BaseURLLive() + "/api/token/club/" + discoveryClubId + "/campaign/" + campId;
        RequestThrottle::WaitForSlot("Discovery campaign detect");
        auto req = NadeoServices::Get("NadeoLiveServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) return "";

        string response = req.String();
        if (response.Length == 0) return "";

        if (!IO::FolderExists(discoveryCacheDir)) IO::CreateFolder(discoveryCacheDir, true);
        _IO::File::WriteFile(cachePath, response);
        return response;
    }

    void FetchDiscoveryCampaign(int idx) {
        if (idx < 0 || idx >= int(discoveryCampaignIds.Length)) return;
        selectedDiscovery = idx;
        selectedDiscoveryMap = -1;

        string cachePath = DiscoveryCachePath(idx);
        if (IO::FileExists(cachePath)) {
            string cached = _IO::File::ReadFileToEnd(cachePath);
            if (cached.Length > 0) {
                ApplyDiscoveryData(cached);
                return;
            }
        }

        discoveryLoading = true;
        discoveryLoaded = false;
        discoveryError = "";
        discoveryMapUids.Resize(0);
        discoveryMapNames.Resize(0);
        startnew(Coro_FetchDiscovery);
    }

    void Coro_FetchDiscovery() {
        int campId = discoveryCampaignIds[selectedDiscovery];
        string url = NadeoServices::BaseURLLive() + "/api/token/club/" + discoveryClubId + "/campaign/" + campId;
        RequestThrottle::WaitForSlot("Discovery campaign");
        auto req = NadeoServices::Get("NadeoLiveServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            discoveryError = "API error (code " + req.ResponseCode() + ")";
            discoveryLoading = false;
            discoveryLoaded = true;
            return;
        }

        string response = req.String();

        if (!IO::FolderExists(discoveryCacheDir)) IO::CreateFolder(discoveryCacheDir, true);
        _IO::File::WriteFile(DiscoveryCachePath(selectedDiscovery), response);

        ApplyDiscoveryData(response);
    }

    void ApplyDiscoveryData(const string &in response) {
        discoveryMapUids.Resize(0);
        discoveryMapNames.Resize(0);
        discoveryError = "";

        Json::Value data = Json::Parse(response);
        if (data.GetType() == Json::Type::Null || !data.HasKey("campaign")) {
            discoveryError = "Failed to parse campaign data";
            discoveryLoading = false;
            discoveryLoaded = true;
            return;
        }

        auto campaign = data["campaign"];
        auto playlist = campaign["playlist"];
        if (playlist.GetType() != Json::Type::Array) {
            discoveryError = "No maps in campaign";
            discoveryLoading = false;
            discoveryLoaded = true;
            return;
        }

        for (uint mi = 0; mi < playlist.Length; mi++) {
            string uid = playlist[mi]["mapUid"];
            int pos = playlist[mi]["position"];
            discoveryMapUids.InsertLast(uid);
            discoveryMapNames.InsertLast("Map " + (pos + 1));
        }

        discoveryLoading = false;
        discoveryLoaded = true;
    }

    void Coro_DetectDiscoveryCurrentMap() {
        string curMapUid = get_CurrentMapUID();
        if (curMapUid.Length == 0) {
            NotifyWarning("No map loaded to detect.");
            return;
        }

        for (int idx = 0; idx < int(discoveryCampaignIds.Length); idx++) {
            string response = GetDiscoveryCampaignData(idx);
            if (response.Length == 0) continue;

            Json::Value data = Json::Parse(response);
            if (data.GetType() == Json::Type::Null || !data.HasKey("campaign")) continue;

            auto playlist = data["campaign"]["playlist"];
            if (playlist.GetType() != Json::Type::Array) continue;

            bool found = false;
            for (uint mi = 0; mi < playlist.Length; mi++) {
                if (string(playlist[mi]["mapUid"]) == curMapUid) {
                    found = true;
                    break;
                }
            }

            if (!found) continue;

            selectedDiscovery = idx;
            ApplyDiscoveryData(response);
            selectedDiscoveryMap = FindUidIndex(discoveryMapUids, curMapUid);
            EntryPoints::MapUid::RequestOpenLeaderboardBrowser(curMapUid);
            NotifyInfo("Detected current map in " + discoveryNames[idx] + ".");
            return;
        }

        NotifyWarning("Current map was not found in the discovery campaigns.");
    }

    bool weeklyFetchIsGrands = false;
    int weeklyFetchOffset = 0;

    string WeeklyCacheKey(bool isGrands, int weekOffset) {
        return (isGrands ? "grands_" : "shorts_") + weekOffset;
    }

    int WeeklyKind(bool isGrands) {
        return isGrands ? 1 : 0;
    }

    bool WeeklyStateMatches(bool isGrands, int weekOffset) {
        return weeklyLoaded && weeklyLoadedKind == WeeklyKind(isGrands) && weeklyLoadedOffset == weekOffset;
    }

    string GetWeeklyCampaignData(bool isGrands, int weekOffset) {
        string cacheKey = WeeklyCacheKey(isGrands, weekOffset);
        if (weeklyCache.Exists(cacheKey)) {
            return string(weeklyCache[cacheKey]);
        }

        string endpoint = isGrands ? "weekly-grands" : "weekly-shorts";
        string url = NadeoServices::BaseURLLive() + "/api/campaign/" + endpoint + "?offset=" + weekOffset + "&length=1";
        RequestThrottle::WaitForSlot("Weekly campaign detect");
        auto req = NadeoServices::Get("NadeoLiveServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) return "";

        string response = req.String();
        if (response.Length == 0) return "";

        weeklyCache.Set(cacheKey, response);
        return response;
    }

    void FetchWeeklyAtOffset(bool isGrands, int weekOffset) {
        string cacheKey = (isGrands ? "grands_" : "shorts_") + weekOffset;
        if (weeklyCache.Exists(cacheKey)) {
            string cached = string(weeklyCache[cacheKey]);
            ApplyWeeklyData(cached, isGrands);
            weeklyLoadedKind = WeeklyKind(isGrands);
            weeklyLoadedOffset = weekOffset;
            return;
        }

        weeklyLoading = true;
        weeklyLoaded = false;
        weeklyError = "";
        weeklyMapUids.Resize(0);
        weeklyMapNames.Resize(0);
        weeklyMapPositions.Resize(0);
        weeklyDisplayName = "";
        weeklySeasonUid = "";
        weeklySelectedMap = -1;
        weeklyFetchIsGrands = isGrands;
        weeklyFetchOffset = weekOffset;
        startnew(Coro_FetchWeekly);
    }

    void Coro_FetchWeekly() {
        string endpoint = weeklyFetchIsGrands ? "weekly-grands" : "weekly-shorts";
        string url = NadeoServices::BaseURLLive() + "/api/campaign/" + endpoint + "?offset=" + weeklyFetchOffset + "&length=1";
        RequestThrottle::WaitForSlot("Weekly campaign");
        auto req = NadeoServices::Get("NadeoLiveServices", url);
        req.Start();
        while (!req.Finished()) { yield(); }

        if (req.ResponseCode() != 200) {
            weeklyError = "API error (code " + req.ResponseCode() + ")";
            weeklyLoading = false;
            weeklyLoaded = true;
            return;
        }

        string response = req.String();

        string cacheKey = (weeklyFetchIsGrands ? "grands_" : "shorts_") + weeklyFetchOffset;
        weeklyCache.Set(cacheKey, response);

        ApplyWeeklyData(response, weeklyFetchIsGrands);
        weeklyLoadedKind = WeeklyKind(weeklyFetchIsGrands);
        weeklyLoadedOffset = weeklyFetchOffset;
    }

    void ApplyWeeklyData(const string &in response, bool isGrands) {
        weeklyMapUids.Resize(0);
        weeklyMapNames.Resize(0);
        weeklyMapPositions.Resize(0);
        weeklyDisplayName = "";
        weeklySeasonUid = "";
        weeklySelectedMap = -1;

        Json::Value data = Json::Parse(response);
        if (data.GetType() == Json::Type::Null) {
            weeklyError = "Failed to parse response";
            weeklyLoading = false;
            weeklyLoaded = true;
            return;
        }

        auto campList = data["campaignList"];
        if (campList.GetType() != Json::Type::Array || campList.Length == 0) {
            weeklyError = "No campaign found for this week";
            weeklyLoading = false;
            weeklyLoaded = true;
            return;
        }

        auto campaign = campList[0];
        string campName = campaign["name"];
        weeklyDisplayName = campName;
        weeklySeasonUid = string(campaign["seasonUid"]);
        if (weeklySeasonUid.Length == 0) {
            weeklySeasonUid = string(campaign["leaderboardGroupUid"]);
        }

        auto playlist = campaign["playlist"];
        if (playlist.GetType() != Json::Type::Array) {
            weeklyError = "No maps in campaign";
            weeklyLoading = false;
            weeklyLoaded = true;
            return;
        }

        string prefix = isGrands ? "Grand" : "Short";
        for (uint mi = 0; mi < playlist.Length; mi++) {
            string uid = playlist[mi]["mapUid"];
            int pos = playlist[mi]["position"];
            weeklyMapUids.InsertLast(uid);
            weeklyMapNames.InsertLast(prefix + " #" + (pos + 1));
            weeklyMapPositions.InsertLast(pos);
        }

        weeklyLoading = false;
        weeklyLoaded = true;
    }

    void Coro_DetectWeeklyCurrentMap(int64 isGrandsRaw) {
        bool isGrands = isGrandsRaw != 0;
        string curMapUid = get_CurrentMapUID();
        if (curMapUid.Length == 0) {
            NotifyWarning("No map loaded to detect.");
            return;
        }

        for (int offset = 0; offset <= WEEKLY_DETECT_MAX_OFFSET; offset++) {
            string response = GetWeeklyCampaignData(isGrands, offset);
            if (response.Length == 0) {
                if (offset == 0) continue;
                break;
            }

            Json::Value data = Json::Parse(response);
            if (data.GetType() == Json::Type::Null) continue;

            auto campList = data["campaignList"];
            if (campList.GetType() != Json::Type::Array || campList.Length == 0) continue;

            auto playlist = campList[0]["playlist"];
            if (playlist.GetType() != Json::Type::Array) continue;

            bool found = false;
            for (uint mi = 0; mi < playlist.Length; mi++) {
                if (string(playlist[mi]["mapUid"]) == curMapUid) {
                    found = true;
                    break;
                }
            }

            if (!found) continue;

            if (isGrands) grandsWeekOffset = offset;
            else shortsWeekOffset = offset;

            ApplyWeeklyData(response, isGrands);
            weeklyLoadedKind = WeeklyKind(isGrands);
            weeklyLoadedOffset = offset;
            weeklySelectedMap = FindUidIndex(weeklyMapUids, curMapUid);
            EntryPoints::MapUid::RequestOpenLeaderboardBrowser(curMapUid);
            NotifyInfo("Detected current map in " + (isGrands ? "Weekly Grands" : "Weekly Shorts") + ".");
            return;
        }

        NotifyWarning("Current map was not found in " + (isGrands ? "Weekly Grands" : "Weekly Shorts") + ".");
    }

    void Render() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        if (SourceButton("Seasonal", OfficialSource::Seasonal)) currentSource = OfficialSource::Seasonal;
        UI::SameLine();
        if (SourceButton("Discovery", OfficialSource::Discovery)) currentSource = OfficialSource::Discovery;
        UI::SameLine();
        if (SourceButton("Weekly Shorts", OfficialSource::WeeklyShorts)) {
            currentSource = OfficialSource::WeeklyShorts;
            if (!weeklyLoading && !WeeklyStateMatches(false, shortsWeekOffset)) FetchWeeklyAtOffset(false, shortsWeekOffset);
        }
        UI::SameLine();
        if (SourceButton("Weekly Grands", OfficialSource::WeeklyGrands)) {
            currentSource = OfficialSource::WeeklyGrands;
            if (!weeklyLoading && !WeeklyStateMatches(true, grandsWeekOffset)) FetchWeeklyAtOffset(true, grandsWeekOffset);
        }

        UI::Dummy(vec2(0, 4));
        UI::AlignTextToFramePadding();
        UI::Text("Rank:");
        UI::SameLine();
        UI::PushItemWidth(80);
        selectedOffset = UI::InputInt("##Offset", selectedOffset);
        UI::PopItemWidth();
        int selectedRank = NormalizeRankInput(selectedOffset);
        _UI::SimpleTooltip("Enter the player's rank. 1 = world record. 0 or negative also loads rank 1.");
        UI::SameLine();
        UI::TextDisabled("(1 = WR)");
        RenderHighRankLookupWarning(selectedRank);

        UI::Dummy(vec2(0, 4));
        UI::PushStyleColor(UI::Col::Separator, vec4(0.3f, 0.3f, 0.35f, 0.5f));
        UI::Separator();
        UI::PopStyleColor();
        UI::Dummy(vec2(0, 4));

        switch (currentSource) {
            case OfficialSource::Seasonal:   RenderSeasonal(); break;
            case OfficialSource::Discovery:  RenderDiscovery(); break;
            case OfficialSource::WeeklyShorts: RenderWeekly(false); break;
            case OfficialSource::WeeklyGrands: RenderWeekly(true); break;
        }

        UI::PopStyleVar();
    }

    bool SourceButton(const string &in label, OfficialSource src) {
        bool active = (currentSource == src);
        if (active) {
            UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
        }
        bool clicked = _UI::Button(label);
        if (active) UI::PopStyleColor(3);
        return clicked;
    }

    void RenderSeasonal() {
        UI::PushItemWidth(100);
        int prevYear = Official::selectedYear;
        bool preserveSelectedMap = false;
        string yearLabel = "Year";
        if (Official::selectedYear >= 0 && Official::selectedYear < int(Official::years.Length)) {
            yearLabel = tostring(Official::years[Official::selectedYear]);
        }
        if (UI::BeginCombo("Year", yearLabel)) {
            for (uint yi = 0; yi < Official::years.Length; yi++) {
                if (UI::Selectable(tostring(Official::years[yi]), Official::selectedYear == int(yi))) Official::selectedYear = int(yi);
            }
            UI::EndCombo();
        }
        UI::PopItemWidth();

        UI::SameLine();
        UI::PushItemWidth(110);
        int prevSeason = Official::selectedSeason;
        string seasonLabel = "Season";
        if (Official::selectedSeason >= 0 && Official::selectedSeason < int(Official::seasons.Length)) {
            seasonLabel = Official::seasons[Official::selectedSeason];
        }
        if (UI::BeginCombo("Season", seasonLabel)) {
            for (uint si = 0; si < Official::seasons.Length; si++) {
                if (UI::Selectable(Official::seasons[si], Official::selectedSeason == int(si))) Official::selectedSeason = int(si);
            }
            UI::EndCombo();
        }
        UI::PopItemWidth();

        UI::SameLine();
        if (_UI::Button(Icons::Calendar + " Current")) { Official::SetSeasonYearToCurrent(); }
        _UI::SimpleTooltip("Jump to the current season");
        UI::SameLine();
        if (_UI::Button(Icons::MapMarker + " Detect")) {
            if (!Official::DetectSeasonYearAndMapFromCurrentMapName()) {
                NotifyWarning("Could not detect season, year, and map number from the current map name.");
            } else {
                preserveSelectedMap = true;
                seasonalOpenLeaderboardAfterDetect = true;
                NotifyInfo("Detected seasonal campaign from the current map name.");
            }
        }
        _UI::SimpleTooltip("Detect season, year, and map number from the current map name");
        UI::SameLine();
        if (_UI::IconButton(Icons::Refresh)) {
            Official::UpdateYears(); Official::UpdateSeasons(); Official::UpdateMaps();
            Official::EnsureLegacyCampaignJsonFiles();
            lastLoadedSeason = ""; Campaign::CheckForNewCampaign();
        }
        _UI::SimpleTooltip("Refresh campaign data");

        if (Official::selectedYear != prevYear || Official::selectedSeason != prevSeason) {
            if (!preserveSelectedMap) Official::selectedMap = -1;
            LoadMapUids();
            if (Official::selectedMap >= int(mapUids.Length)) {
                Official::selectedMap = -1;
            }
        }
        if (!mapUidsLoaded && Official::selectedYear >= 0 && Official::selectedSeason >= 0) LoadMapUids();

        if (Official::selectedYear >= 0 && Official::selectedSeason >= 0) {
            RenderMapGrid(mapUids, mapUidsLoaded, Official::selectedMap, int(mapUids.Length));
            if (gridResult >= 0) Official::selectedMap = gridResult;
        }

        if (Official::selectedMap >= 0) {
            Official_MapUID = (Official::selectedMap < int(mapUids.Length)) ? mapUids[Official::selectedMap] : "";
            if (Official_MapUID.Length == 0) {
                Official_MapUID = Official::FetchOfficialMapUID();
            }
            if (seasonalOpenLeaderboardAfterDetect && Official_MapUID.Length > 0) {
                EntryPoints::MapUid::RequestOpenLeaderboardBrowser(Official_MapUID);
                seasonalOpenLeaderboardAfterDetect = false;
            }
            RenderSelectedMap(Official::selectedMap + 1, Official_MapUID, officialSeasonUid);
            EntryPoints::MapUid::RenderLeaderboardBrowser();
        }
    }

    void RenderDiscovery() {
        for (uint di = 0; di < discoveryNames.Length; di++) {
            bool active = (selectedDiscovery == int(di) && discoveryLoaded);
            if (active) {
                UI::PushStyleColor(UI::Col::Button, vec4(0.25f, 0.35f, 0.50f, 0.90f));
                UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.32f, 0.42f, 0.58f, 1.0f));
                UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.40f, 0.50f, 0.65f, 1.0f));
            }
            if (_UI::Button(discoveryNames[di])) {
                FetchDiscoveryCampaign(int(di));
            }
            if (active) UI::PopStyleColor(3);
            if (di < discoveryNames.Length - 1) UI::SameLine();
        }

        UI::Dummy(vec2(0, 4));
        if (_UI::Button(Icons::MapMarker + " Detect##Discovery")) {
            startnew(CoroutineFunc(Coro_DetectDiscoveryCurrentMap));
        }
        _UI::SimpleTooltip("Detect which discovery campaign contains the current map");

        if (discoveryLoading) {
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled(Icons::Refresh + " Loading campaign...");
        } else if (discoveryError.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::Text("\\$f90" + Icons::ExclamationTriangle + " " + discoveryError + "\\$z");
        }

        if (discoveryLoaded && discoveryMapUids.Length > 0) {
            RenderMapGrid(discoveryMapUids, true, selectedDiscoveryMap, int(discoveryMapUids.Length));
            if (gridResult >= 0) selectedDiscoveryMap = gridResult;

            if (selectedDiscoveryMap >= 0 && selectedDiscoveryMap < int(discoveryMapUids.Length)) {
                RenderSelectedMap(selectedDiscoveryMap + 1, discoveryMapUids[selectedDiscoveryMap]);
                EntryPoints::MapUid::RenderLeaderboardBrowser();
            }
        }
    }

    void RenderWeekly(bool isGrands) {
        string label = isGrands ? "Weekly Grands" : "Weekly Shorts";
        int weekOffset = isGrands ? grandsWeekOffset : shortsWeekOffset;
        int selectedRank = NormalizeRankInput(selectedOffset);

        UI::AlignTextToFramePadding();
        if (_UI::IconButton(Icons::ChevronLeft, "wkOlder")) {
            if (isGrands) grandsWeekOffset++; else shortsWeekOffset++;
            FetchWeeklyAtOffset(isGrands, isGrands ? grandsWeekOffset : shortsWeekOffset);
        }
        _UI::SimpleTooltip("Older week");

        UI::SameLine();
        string weekLabel = weeklyDisplayName.Length > 0 ? weeklyDisplayName : (label + " (offset " + weekOffset + ")");
        if (weekOffset == 0) weekLabel += " (current)";
        float labelStartX = UI::GetCursorPos().x;
        UI::Text(weekLabel);
        UI::SameLine();
        UI::SetCursorPosX(labelStartX + 220);
        UI::BeginDisabled(weekOffset <= 0);
        if (_UI::IconButton(Icons::ChevronRight, "wkNewer")) {
            if (isGrands) grandsWeekOffset--; else shortsWeekOffset--;
            FetchWeeklyAtOffset(isGrands, isGrands ? grandsWeekOffset : shortsWeekOffset);
        }
        UI::EndDisabled();
        _UI::SimpleTooltip("Newer week");

        UI::SameLine();
        if (_UI::IconButton(Icons::Refresh, "wkRefresh")) {
            string cacheKey = WeeklyCacheKey(isGrands, isGrands ? grandsWeekOffset : shortsWeekOffset);
            if (weeklyCache.Exists(cacheKey)) weeklyCache.Delete(cacheKey);
            FetchWeeklyAtOffset(isGrands, isGrands ? grandsWeekOffset : shortsWeekOffset);
        }
        _UI::SimpleTooltip("Refresh (clear cache for this week)");
        UI::SameLine();
        if (_UI::Button(Icons::MapMarker + " Detect##wkDetect")) {
            startnew(Coro_DetectWeeklyCurrentMap, int64(isGrands ? 1 : 0));
        }
        _UI::SimpleTooltip("Detect which weekly campaign contains the current map");

        if (weeklyLoading) {
            UI::TextDisabled(Icons::Refresh + " Loading...");
        } else if (weeklyError.Length > 0) {
            UI::Text("\\$f90" + Icons::ExclamationTriangle + " " + weeklyError + "\\$z");
        }

        if (weeklyLoaded && weeklyMapUids.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::Text(Icons::Map + " \\$fffCurrent " + label + " (" + weeklyMapUids.Length + " maps)");
            UI::Dummy(vec2(0, 2));

            UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));
            UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
            int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders;
            float weeklyActionColWidth = _UI::ButtonSize(vec2(28, 0)).x * 2.0f + UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x + 6.0f;
            if (UI::BeginTable("Weekly", 3, tflags)) {
                UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 40);
                UI::TableSetupColumn("Map UID", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, weeklyActionColWidth);
                UI::TableHeadersRow();

                for (uint wi = 0; wi < weeklyMapUids.Length; wi++) {
                    UI::TableNextRow();

                    UI::TableNextColumn();
                    UI::Text("" + (wi + 1));

                    UI::TableNextColumn();
                    UI::TextDisabled(weeklyMapUids[wi]);

                    UI::TableNextColumn();
                    if (_UI::IconButton(Icons::Download, "wk_" + wi, vec2(28, 0))) {
                        print("ARL UI Load click: weekly row=" + wi + " uid=" + weeklyMapUids[wi] + " rank=" + selectedRank);
                        NotifyInfo("Queueing weekly record load #" + selectedRank);
                        loadRecord.LoadRecordFromMapUid(weeklyMapUids[wi], tostring(selectedRank), "Official", "", "", weeklySeasonUid);
                    }
                    _UI::SimpleTooltip("Load rank #" + selectedRank);
                    UI::SameLine();
                    if (_UI::IconButton(Icons::ArrowRight, "wks_" + wi, vec2(28, 0))) {
                        weeklySelectedMap = int(wi);
                        EntryPoints::MapUid::mapUID = weeklyMapUids[wi];
                    }
                    _UI::SimpleTooltip("Select this map");
                }
                UI::EndTable();
            }
            UI::PopStyleColor();
            UI::PopStyleVar();

            if (weeklySelectedMap >= 0 && weeklySelectedMap < int(weeklyMapUids.Length)) {
                RenderSelectedMap(weeklySelectedMap + 1, weeklyMapUids[weeklySelectedMap], weeklySeasonUid);
                EntryPoints::MapUid::RenderLeaderboardBrowser();
            }
        }
    }

    int gridResult = -1;

    void RenderMapGrid(array<string>@ uids, bool loaded, int selected, int totalMaps) {
        gridResult = -1;
        if (!loaded || uids.Length == 0) return;

        string curMapUid = get_CurrentMapUID();
        int cols = totalMaps <= 5 ? totalMaps : 5;
        int rows = int(Math::Ceil(float(totalMaps) / float(cols)));

        UI::Dummy(vec2(0, 4));
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(3, 3));
        if (UI::BeginTable("MapGrid", cols, UI::TableFlags::SizingStretchSame)) {
            for (int row = 0; row < rows; row++) {
                UI::TableNextRow();
                for (int col = 0; col < cols; col++) {
                    UI::TableNextColumn();
                    int mapIdx = row * cols + col;
                    if (mapIdx >= totalMaps) continue;

                    string uid = (mapIdx < int(uids.Length)) ? uids[mapIdx] : "";
                    bool isSelected = (selected == mapIdx);
                    bool isCurrent = (uid.Length > 0 && uid == curMapUid);

                    if (isCurrent) {
                        UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.45f, 0.25f, 1.0f));
                        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.55f, 0.32f, 1.0f));
                        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.65f, 0.40f, 1.0f));
                    } else if (isSelected) {
                        UI::PushStyleColor(UI::Col::Button, vec4(0.30f, 0.35f, 0.50f, 1.0f));
                        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.38f, 0.42f, 0.58f, 1.0f));
                        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.45f, 0.50f, 0.65f, 1.0f));
                    }

                    int mapNum = mapIdx + 1;
                    string lbl = (mapNum < 10 ? " " : "") + mapNum;
                    if (_UI::Button(lbl + "##mg_" + mapIdx, vec2(-1, 32))) {
                        gridResult = mapIdx;
                        if (uid.Length > 0) {
                            EntryPoints::MapUid::mapUID = uid;
                        }
                    }

                    if (isCurrent || isSelected) UI::PopStyleColor(3);

                    if (isCurrent) _UI::SimpleTooltip("Map " + mapNum + " (current map)\n" + uid);
                    else if (uid.Length > 0) _UI::SimpleTooltip("Map " + mapNum + "\n" + uid);
                }
            }
            UI::EndTable();
        }
        UI::PopStyleVar();
    }

    void RenderSelectedMap(int mapNum, const string &in uid, const string &in seasonUid = "") {
        if (uid.Length > 0 && EntryPoints::MapUid::mapUID != uid) {
            EntryPoints::MapUid::mapUID = uid;
        }

        UI::Dummy(vec2(0, 4));
        UI::AlignTextToFramePadding();
        UI::Text(Icons::Map + " Map " + mapNum);
        UI::SameLine();
        if (uid.Length > 0) {
            UI::TextDisabled(uid);
        } else {
            UI::TextDisabled("(no UID)");
        }

        UI::SameLine();
        UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
        UI::BeginDisabled(uid.Length == 0);
        int selectedRank = NormalizeRankInput(selectedOffset);
        if (_UI::Button(Icons::Download + " Load #" + selectedRank)) {
            print("ARL UI Load click: seasonal map " + mapNum + " uid=" + uid + " rank=" + selectedRank);
            NotifyInfo("Queueing seasonal record load for map " + mapNum + " (#" + selectedRank + ")");
            loadRecord.LoadRecordFromMapUid(uid, tostring(selectedRank), "Official", "", "", seasonUid);
        }
        UI::EndDisabled();
        UI::PopStyleColor(3);
        if (uid.Length == 0) {
            _UI::SimpleTooltip("Selected map has no UID resolved yet, so loading is disabled.");
        }
    }
}
}
