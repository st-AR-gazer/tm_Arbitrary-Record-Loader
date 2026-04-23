namespace EntryPoints {
namespace LocalFiles {
    array<string> manualFilePaths = {""};

    string qb_ReplaysRoot = IO::FromUserGameFolder("Replays/");
    string qb_Autosaves   = IO::FromUserGameFolder("Replays/Autosaves/");
    string qb_ARLRoot     = IO::FromUserGameFolder("Replays/ArbitraryRecordLoader/");
    string qb_Downloads   = IO::FromDataFolder("../Downloads/");
    string qb_Archivist   = IO::FromUserGameFolder("Replays/Archivist/");
    string qb_Offload     = IO::FromUserGameFolder("Replays_Offload/");

    array<string> recentFiles;
    uint MAX_RECENT = 15;

    string browsePath = "";
    array<string> browseFiles;
    string browseFilter = "";

    class ArchivistEntry {
        string path;
        string fileName;
        string directory;
        string relativeDirectory;
        string pathLower;
        string typeLabel;
        int64 archivistTimestamp = 0;
        int archivistTimeMs = 0;
        bool hasArchivistTimestamp = false;
        bool hasArchivistTime = false;
        bool isSegmented = false;
        bool isComplete = false;
    }

    enum ArchivistSortMode {
        Timestamp = 0,
        Time = 1
    }

    bool archivistNeedsRefresh = true;
    string archivistFilter = "";
    bool archivistCurrentMapOnly = true;
    bool archivistShowComplete = true;
    bool archivistShowPartial = true;
    bool archivistShowSegmented = true;
    [Setting hidden]
    int archivistSortMode = int(ArchivistSortMode::Timestamp);
    int archivistFileActionId = 0;
    dictionary archivistTreeOpen;

    bool IsArchivistAvailable() {
#if DEPENDENCY_ARCHIVIST
        return PluginState::IsPluginLoaded("Archivist");
#else
        return false;
#endif
    }

    void EnsureManualFileRows() {
        if (manualFilePaths.Length == 0) manualFilePaths.InsertLast("");
    }

    void ResetManualFileRows() {
        if (manualFilePaths.Length > 0) manualFilePaths.RemoveRange(0, manualFilePaths.Length);
        manualFilePaths.InsertLast("");
    }

    string NormalizePath(const string &in path) {
        return path.Trim();
    }

    bool ArrayContainsPath(const array<string> &in paths, const string &in candidate) {
        string normalized = NormalizePath(candidate);
        if (normalized.Length == 0) return false;
        for (uint i = 0; i < paths.Length; i++) {
            if (NormalizePath(paths[i]) == normalized) return true;
        }
        return false;
    }

    bool IsLoadableFilePath(const string &in path) {
        string lower = path.ToLower();
        return lower.EndsWith(".ghost.gbx") || lower.EndsWith(".replay.gbx");
    }

    string GetLocalFileTypeLabel(const string &in path) {
        string lower = path.ToLower();
        if (lower.EndsWith(".replay.gbx")) return "Replay";
        if (lower.EndsWith(".ghost.gbx")) return "Ghost";
        return "File";
    }

    bool PathLooksSegmented(const string &in lowerPath) {
        return lowerPath.Contains("segment")
            || lowerPath.Contains("segmented")
            || lowerPath.Contains("split");
    }

    bool PathLooksComplete(const string &in lowerPath) {
        if (PathLooksSegmented(lowerPath)) return false;
        return lowerPath.Contains("fullbest")
            || lowerPath.Contains("full-best")
            || lowerPath.Contains("full_best")
            || lowerPath.Contains("full run")
            || lowerPath.Contains("fullrun")
            || lowerPath.Contains("best run")
            || lowerPath.Contains("personal best")
            || lowerPath.Contains("_pb")
            || lowerPath.Contains("-pb")
            || lowerPath.Contains("/pb")
            || lowerPath.Contains("\\pb");
    }

    string GetArchivistKindLabel(ArchivistEntry@ entry) {
        if (entry is null) return "Other";
        if (entry.isSegmented) return "Segmented";
        if (entry.isComplete) return "Complete";
        return "Partial";
    }

    string GetArchivistSortModeLabel() {
        return archivistSortMode == int(ArchivistSortMode::Time) ? "Time" : "Timestamp";
    }

    string ArchivistFileStem(const string &in fileName) {
        string stem = fileName;
        string lower = stem.ToLower();
        if (lower.EndsWith(".ghost.gbx")) return stem.SubStr(0, stem.Length - 10);
        if (lower.EndsWith(".replay.gbx")) return stem.SubStr(0, stem.Length - 11);
        return stem;
    }

    void ParseArchivistFileName(ArchivistEntry@ entry) {
        if (entry is null) return;

        string stem = ArchivistFileStem(entry.fileName).Trim();
        int firstSpace = stem.IndexOf(" ");
        if (firstSpace <= 0) return;

        string timestampText = stem.SubStr(0, firstSpace).Trim();
        int64 parsedTimestamp = 0;
        if (Text::TryParseInt64(timestampText, parsedTimestamp)) {
            entry.archivistTimestamp = parsedTimestamp;
            entry.hasArchivistTimestamp = true;
        }

        string rest = stem.SubStr(firstSpace + 1).Trim();
        int secondSpace = rest.IndexOf(" ");
        if (secondSpace <= 0) return;

        string timeText = rest.SubStr(0, secondSpace).Trim();
        int parsedTime = 0;
        if (Text::TryParseInt(timeText, parsedTime) && parsedTime >= 0) {
            entry.archivistTimeMs = parsedTime;
            entry.hasArchivistTime = true;
        }
    }

    bool ArchivistEntrySortAfter(ArchivistEntry@ left, ArchivistEntry@ right) {
        if (left is null) return false;
        if (right is null) return true;

        if (archivistSortMode == int(ArchivistSortMode::Time)) {
            if (left.hasArchivistTime && right.hasArchivistTime && left.archivistTimeMs != right.archivistTimeMs) {
                return left.archivistTimeMs > right.archivistTimeMs;
            }
            if (left.hasArchivistTime != right.hasArchivistTime) return !left.hasArchivistTime;
        }

        if (left.hasArchivistTimestamp && right.hasArchivistTimestamp && left.archivistTimestamp != right.archivistTimestamp) {
            return left.archivistTimestamp > right.archivistTimestamp;
        }
        if (left.hasArchivistTimestamp != right.hasArchivistTimestamp) return !left.hasArchivistTimestamp;

        if (left.hasArchivistTime && right.hasArchivistTime && left.archivistTimeMs != right.archivistTimeMs) {
            return left.archivistTimeMs > right.archivistTimeMs;
        }
        if (left.hasArchivistTime != right.hasArchivistTime) return !left.hasArchivistTime;

        return left.fileName.ToLower() > right.fileName.ToLower();
    }

    void SortArchivistFiles(array<ArchivistEntry@>@ files) {
        if (files is null || files.Length < 2) return;

        for (uint i = 1; i < files.Length; i++) {
            auto current = files[i];
            int j = int(i) - 1;
            while (j >= 0 && ArchivistEntrySortAfter(files[uint(j)], current)) {
                @files[uint(j + 1)] = files[uint(j)];
                j--;
            }
            @files[uint(j + 1)] = current;
        }
    }

    bool ArchivistEntryMatchesKindFilter(ArchivistEntry@ entry) {
        if (entry is null) return false;
        if (entry.isSegmented) return archivistShowSegmented;
        if (entry.isComplete) return archivistShowComplete;
        return archivistShowPartial;
    }

    bool ArchivistEntryMatchesCurrentMap(ArchivistEntry@ entry, const string &in mapUidLower) {
        if (entry is null || mapUidLower.Length == 0) return false;
        return entry.pathLower.Contains(mapUidLower);
    }

    bool ArchivistEntryMatchesFilters(ArchivistEntry@ entry, const string &in mapUidLower) {
        if (entry is null) return false;

        bool applyCurrentMap = archivistCurrentMapOnly && mapUidLower.Length > 0;
        if (applyCurrentMap && !ArchivistEntryMatchesCurrentMap(entry, mapUidLower)) return false;

        if (!ArchivistEntryMatchesKindFilter(entry)) return false;

        string filterLower = archivistFilter.Trim().ToLower();
        if (filterLower.Length == 0) return true;

        return entry.fileName.ToLower().Contains(filterLower)
            || entry.relativeDirectory.ToLower().Contains(filterLower)
            || entry.pathLower.Contains(filterLower);
    }

    string EnsureTrailingSlash(const string &in path) {
        if (path.Length == 0) return path;
        string ret = path;
        if (!ret.EndsWith("/") && !ret.EndsWith("\\")) ret += "/";
        return ret;
    }

    string NormalizeDirPath(const string &in path) {
        return EnsureTrailingSlash(path.Replace("\\", "/").Trim());
    }

    string ArchivistRoot() {
        return NormalizeDirPath(qb_Archivist);
    }

    string ArchivistRelativeDir(const string &in dir) {
        string root = ArchivistRoot();
        string current = NormalizeDirPath(dir);
        if (current.ToLower().StartsWith(root.ToLower())) {
            string rel = current.SubStr(root.Length);
            if (rel.Length == 0) return "./";
            return rel;
        }
        return current;
    }

    bool IsArchivistRoot(const string &in dir) {
        return NormalizeDirPath(dir).ToLower() == ArchivistRoot().ToLower();
    }

    bool IsArchivistTreeOpen(const string &in dir) {
        string normalized = NormalizeDirPath(dir).ToLower();
        if (IsArchivistRoot(normalized)) return true;
        return archivistTreeOpen.Exists(normalized);
    }

    void SetArchivistTreeOpen(const string &in dir, bool open) {
        string normalized = NormalizeDirPath(dir).ToLower();
        if (open) archivistTreeOpen.Set(normalized, true);
        else if (archivistTreeOpen.Exists(normalized)) archivistTreeOpen.Delete(normalized);
    }

    void ToggleArchivistTreeOpen(const string &in dir) {
        SetArchivistTreeOpen(dir, !IsArchivistTreeOpen(dir));
    }

    string FolderDisplayName(const string &in dir) {
        string normalized = NormalizeDirPath(dir);
        if (IsArchivistRoot(normalized)) return "Archivist";
        if (normalized.Length > 1) normalized = normalized.SubStr(0, normalized.Length - 1);
        string name = Path::GetFileName(normalized);
        return name.Length > 0 ? name : normalized;
    }

    void AddToRecent(const string &in path) {
        for (uint i = 0; i < recentFiles.Length; i++) {
            if (recentFiles[i] == path) {
                recentFiles.RemoveAt(i);
                break;
            }
        }
        recentFiles.InsertAt(0, path);
        if (recentFiles.Length > MAX_RECENT) {
            recentFiles.RemoveRange(MAX_RECENT, recentFiles.Length - MAX_RECENT);
        }
    }

    bool HasQueuedPaths() {
        for (uint i = 0; i < manualFilePaths.Length; i++) {
            if (NormalizePath(manualFilePaths[i]).Length > 0) return true;
        }
        return false;
    }

    bool CanClearQueuedPaths() {
        return manualFilePaths.Length > 1 || HasQueuedPaths();
    }

    array<string> CollectLoadablePaths() {
        array<string> paths;
        for (uint i = 0; i < manualFilePaths.Length; i++) {
            string normalized = NormalizePath(manualFilePaths[i]);
            if (normalized.Length == 0 || ArrayContainsPath(paths, normalized)) continue;
            paths.InsertLast(normalized);
        }
        return paths;
    }

    void ReplaceManualFilePaths(array<string>@ paths) {
        if (manualFilePaths.Length > 0) manualFilePaths.RemoveRange(0, manualFilePaths.Length);
        if (paths !is null) {
            for (uint i = 0; i < paths.Length; i++) {
                string normalized = NormalizePath(paths[i]);
                if (normalized.Length == 0 || ArrayContainsPath(manualFilePaths, normalized)) continue;
                manualFilePaths.InsertLast(normalized);
            }
        }
        EnsureManualFileRows();
    }

    void AddManualFilePath(const string &in path) {
        string normalized = NormalizePath(path);
        if (normalized.Length == 0 || ArrayContainsPath(manualFilePaths, normalized)) return;

        for (uint i = 0; i < manualFilePaths.Length; i++) {
            if (NormalizePath(manualFilePaths[i]).Length == 0) {
                manualFilePaths[i] = normalized;
                return;
            }
        }

        manualFilePaths.InsertLast(normalized);
    }

    void RemoveManualFilePathAt(uint index) {
        if (index >= manualFilePaths.Length) return;

        if (manualFilePaths.Length <= 1) manualFilePaths[0] = "";
        else manualFilePaths.RemoveAt(index);

        EnsureManualFileRows();
    }

    void LoadQueuedPaths() {
        auto loadablePaths = CollectLoadablePaths();
        for (uint i = 0; i < loadablePaths.Length; i++) {
            AddToRecent(loadablePaths[i]);
            loadRecord.LoadRecordFromLocalFile(loadablePaths[i]);
        }
    }

    void RefreshBrowse() {
        if (browseFiles.Length > 0) browseFiles.RemoveRange(0, browseFiles.Length);
        if (browsePath.Length == 0 || !IO::FolderExists(browsePath)) return;

        auto files = IO::IndexFolder(browsePath, false);
        if (files is null) return;

        for (uint i = 0; i < files.Length; i++) {
            if (!IsLoadableFilePath(files[i])) continue;
            browseFiles.InsertLast(files[i]);
        }
    }

    void QuickOpenFolder(const string &in path) {
        browsePath = path;
        RefreshBrowse();
    }

    ArchivistEntry@ MakeArchivistEntry(const string &in path) {
        if (!IsLoadableFilePath(path)) return null;
        ArchivistEntry@ entry = ArchivistEntry();
        entry.path = path;
        entry.fileName = Path::GetFileName(path);
        entry.directory = Path::GetDirectoryName(path);
        entry.pathLower = path.ToLower();
        entry.typeLabel = GetLocalFileTypeLabel(path);
        entry.isSegmented = PathLooksSegmented(entry.pathLower);
        entry.isComplete = PathLooksComplete(entry.pathLower);
        entry.relativeDirectory = ArchivistRelativeDir(entry.directory);
        ParseArchivistFileName(entry);
        return entry;
    }

    void LoadArchivistFolderLevel(const string &in dir, array<string>@ folders, array<ArchivistEntry@>@ files) {
        if (folders !is null && folders.Length > 0) folders.RemoveRange(0, folders.Length);
        if (files !is null && files.Length > 0) files.RemoveRange(0, files.Length);
        if (!IO::FolderExists(dir)) return;

        auto entries = IO::IndexFolder(dir, false);
        if (entries is null) return;

        for (uint i = 0; i < entries.Length; i++) {
            string path = entries[i];
            if (IO::FolderExists(path)) {
                if (folders !is null) folders.InsertLast(NormalizeDirPath(path));
                continue;
            }

            auto entry = MakeArchivistEntry(path);
            if (entry !is null && files !is null) files.InsertLast(entry);
        }

        SortArchivistFiles(files);
    }

    bool ArchivistFileVisible(ArchivistEntry@ entry, const string &in mapUidLower) {
        return ArchivistEntryMatchesFilters(entry, mapUidLower);
    }

    bool ArchivistFilenameFilterActive() {
        return archivistFilter.Trim().Length > 0;
    }

    void FindArchivistSearchRootFolders(const string &in filterLower, array<string>@ roots) {
        if (roots is null) return;
        if (roots.Length > 0) roots.RemoveRange(0, roots.Length);
        if (filterLower.Length == 0 || !IO::FolderExists(qb_Archivist)) return;

        auto entries = IO::IndexFolder(ArchivistRoot(), false);
        if (entries is null) return;

        for (uint i = 0; i < entries.Length; i++) {
            string path = entries[i];
            if (!IO::FolderExists(path)) continue;

            string dir = NormalizeDirPath(path);
            string name = FolderDisplayName(dir).ToLower();
            string rel = ArchivistRelativeDir(dir).ToLower();
            if (name.Contains(filterLower) || rel.Contains(filterLower)) {
                roots.InsertLast(dir);
            }
        }
    }

    bool FolderWithinSearchRoots(const string &in folder, const array<string>@ searchRoots) {
        if (searchRoots is null || searchRoots.Length == 0) return true;

        string normalized = NormalizeDirPath(folder).ToLower();
        for (uint i = 0; i < searchRoots.Length; i++) {
            string root = NormalizeDirPath(searchRoots[i]).ToLower();
            if (normalized.StartsWith(root)) return true;
        }
        return false;
    }

    bool ArchivistFolderHasMatchingDescendant(const string &in folder, const string &in mapUidLower) {
        if (!ArchivistFilenameFilterActive()) return true;
        if (!IO::FolderExists(folder)) return false;

        auto files = IO::IndexFolder(folder, true);
        if (files is null) return false;

        for (uint i = 0; i < files.Length; i++) {
            auto entry = MakeArchivistEntry(files[i]);
            if (entry is null) continue;
            if (ArchivistFileVisible(entry, mapUidLower)) return true;
        }

        return false;
    }

    void RenderArchivistFileActions(ArchivistEntry@ entry, const string &in idPrefix) {
        if (entry is null) return;

        if (_UI::IconButton(Icons::Plus, idPrefix + "_queue_" + archivistFileActionId, vec2(28, 0))) {
            AddManualFilePath(entry.path);
        }
        _UI::SimpleTooltip("Queue this Archivist file");
        UI::SameLine();
        if (_UI::IconButton(Icons::Play, idPrefix + "_load_" + archivistFileActionId, vec2(28, 0))) {
            AddToRecent(entry.path);
            loadRecord.LoadRecordFromLocalFile(entry.path);
        }
        _UI::SimpleTooltip("Load immediately");
        archivistFileActionId++;
    }

    void RenderArchivistTreeFile(ArchivistEntry@ entry, const string &in mapUidLower) {
        if (entry is null || !ArchivistFileVisible(entry, mapUidLower)) return;

        UI::PushID("arch_file_" + entry.path);

        string icon = entry.typeLabel == "Replay" ? Icons::Film : Icons::SnapchatGhost;
        string nameText = icon + " " + entry.fileName;
        if (ArchivistEntryMatchesCurrentMap(entry, mapUidLower)) {
            nameText = "\\$0f0" + Icons::Map + "\\$z " + nameText;
        }

        if (UI::Selectable(nameText, false, UI::SelectableFlags::AllowDoubleClick)) {
            if (UI::IsMouseDoubleClicked(UI::MouseButton::Left)) {
                AddToRecent(entry.path);
                loadRecord.LoadRecordFromLocalFile(entry.path);
            }
        }

        UI::SameLine();
        UI::TextDisabled(GetArchivistKindLabel(entry));
        UI::SameLine();
        RenderArchivistFileActions(entry, "arch_tree");

        UI::PopID();
    }

    void RenderArchivistFolderNode(const string &in folder, const string &in mapUidLower, const array<string>@ searchRoots = null, int depth = 0) {
        if (depth > 24) return;
        if (!FolderWithinSearchRoots(folder, searchRoots) && !IsArchivistRoot(folder)) return;

        string normalized = NormalizeDirPath(folder);
        bool open = IsArchivistTreeOpen(normalized);

        UI::PushID("arch_folder_" + normalized);

        if (_UI::IconButton(open ? Icons::ChevronDown : Icons::ChevronRight, "toggle", vec2(24, 0))) {
            ToggleArchivistTreeOpen(normalized);
            open = IsArchivistTreeOpen(normalized);
        }

        UI::SameLine();
        if (UI::Selectable(Icons::Folder + " " + FolderDisplayName(normalized), false, UI::SelectableFlags::AllowDoubleClick)) {
            ToggleArchivistTreeOpen(normalized);
            open = IsArchivistTreeOpen(normalized);
        }

        if (!open) {
            UI::PopID();
            return;
        }

        array<string> childFolders;
        array<ArchivistEntry@> childFiles;
        LoadArchivistFolderLevel(folder, childFolders, childFiles);

        UI::Indent(18);
        for (uint i = 0; i < childFolders.Length; i++) {
            if (!FolderWithinSearchRoots(childFolders[i], searchRoots)) continue;
            if (!ArchivistFolderHasMatchingDescendant(childFolders[i], mapUidLower)) continue;
            RenderArchivistFolderNode(childFolders[i], mapUidLower, searchRoots, depth + 1);
        }

        for (uint i = 0; i < childFiles.Length; i++) {
            RenderArchivistTreeFile(childFiles[i], mapUidLower);
        }
        UI::Unindent(18);

        UI::PopID();
    }

    void FindCurrentMapArchivistPicks(const string &in mapUidLower, ArchivistEntry@ &out firstFull, ArchivistEntry@ &out firstSegmented, int &out fullCount, int &out segmentedCount) {
        @firstFull = null;
        @firstSegmented = null;
        fullCount = 0;
        segmentedCount = 0;
        if (mapUidLower.Length == 0 || !IO::FolderExists(qb_Archivist)) return;

        auto files = IO::IndexFolder(qb_Archivist, true);
        if (files is null) return;

        for (uint i = 0; i < files.Length; i++) {
            string pathLower = files[i].ToLower();
            if (!pathLower.Contains(mapUidLower)) continue;
            auto entry = MakeArchivistEntry(files[i]);
            if (entry is null) continue;

            if (entry.isComplete) {
                fullCount++;
                if (firstFull is null) @firstFull = entry;
            }
            if (entry.isSegmented) {
                segmentedCount++;
                if (firstSegmented is null) @firstSegmented = entry;
            }
        }
    }

    void RenderSharedQueueBar(int loadableCount, const string &in idSuffix) {
        UI::BeginDisabled(loadableCount == 0);
        if (_UI::Button(Icons::Download + " Load All (" + loadableCount + ")##LoadAll_" + idSuffix)) {
            LoadQueuedPaths();
        }
        UI::EndDisabled();
        _UI::SimpleTooltip("Load every queued path");

        UI::SameLine();
        UI::BeginDisabled(!CanClearQueuedPaths());
        if (_UI::Button(Icons::Times + " Clear##Clear_" + idSuffix)) {
            ResetManualFileRows();
        }
        UI::EndDisabled();

        UI::SameLine();
        UI::TextDisabled(Icons::List + " " + loadableCount + " queued");
    }

    void RenderQuickFolderButtons() {
        if (_UI::Button(Icons::Home + " Replays/")) { QuickOpenFolder(qb_ReplaysRoot); }
        UI::SameLine();
        if (_UI::Button(Icons::ClockO + " Autosaves/")) { QuickOpenFolder(qb_Autosaves); }
        UI::SameLine();
        if (_UI::Button(Icons::SnapchatGhost + " ARL/")) { QuickOpenFolder(qb_ARLRoot); }
        UI::SameLine();
        if (_UI::Button(Icons::CloudDownload + " Downloads/")) { QuickOpenFolder(qb_Downloads); }

        bool renderedOptionalButton = true;

        if (IsArchivistAvailable() && IO::FolderExists(qb_Archivist)) {
            UI::Dummy(vec2(0, 2));
            if (_UI::Button(Icons::Archive + " Archivist/")) { QuickOpenFolder(qb_Archivist); }
        } else {
            renderedOptionalButton = false;
        }

#if DEPENDENCY_BETTERREPLAYSFOLDER
        bool betterReplaysFolderLoaded = PluginState::IsPluginLoaded("BetterReplaysFolder");
        if (betterReplaysFolderLoaded && IO::FolderExists(qb_Offload)) {
            if (renderedOptionalButton) UI::SameLine();
            else UI::Dummy(vec2(0, 2));
            if (_UI::Button(Icons::Exchange + " Replays_Offload/")) { QuickOpenFolder(qb_Offload); }
        }
#endif
    }

    void RenderQuickBrowserTab(int loadableCount) {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        RenderSharedQueueBar(loadableCount, "QuickBrowser");
        UI::Dummy(vec2(0, 2));
        RenderQuickFolderButtons();
        UI::Dummy(vec2(0, 4));

        float scanReservedWidth = _UI::ButtonSize(vec2(110, 0)).x + UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x;
        UI::PushItemWidth(-scanReservedWidth);
        browsePath = UI::InputText("##QuickBrowsePath", browsePath);
        UI::PopItemWidth();
        UI::SameLine();
        if (_UI::Button(Icons::Refresh + " Scan", vec2(110, 0))) {
            RefreshBrowse();
        }

        if (browsePath.Length > 0 && browseFiles.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::PushItemWidth(200);
            browseFilter = UI::InputText(Icons::Search + "##QuickBrowseFilter", browseFilter);
            UI::PopItemWidth();
            UI::SameLine();
            UI::TextDisabled(browseFiles.Length + " file(s)");

            UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));
            int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY;
            if (UI::BeginTable("QuickBrowseFiles", 3, tflags, vec2(0, 220))) {
                UI::TableSetupColumn("File", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthFixed, 70);
                UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 70);
                UI::TableHeadersRow();

                string filterLower = browseFilter.ToLower();
                for (uint i = 0; i < browseFiles.Length; i++) {
                    string path = browseFiles[i];
                    string name = Path::GetFileName(path);
                    if (filterLower.Length > 0 && !name.ToLower().Contains(filterLower)) continue;

                    UI::TableNextRow();

                    UI::TableNextColumn();
                    UI::Text(name);
                    _UI::SimpleTooltip(path);

                    UI::TableNextColumn();
                    string typeLabel = GetLocalFileTypeLabel(path);
                    if (typeLabel == "Replay") UI::Text("\\$cda" + Icons::Film + " Replay\\$z");
                    else UI::Text("\\$aca" + Icons::SnapchatGhost + " Ghost\\$z");

                    UI::TableNextColumn();
                    if (_UI::IconButton(Icons::Plus, "qb_queue_" + i, vec2(28, 0))) {
                        AddManualFilePath(path);
                    }
                    _UI::SimpleTooltip("Queue this file");
                    UI::SameLine();
                    if (_UI::IconButton(Icons::Play, "qb_load_" + i, vec2(28, 0))) {
                        AddToRecent(path);
                        loadRecord.LoadRecordFromLocalFile(path);
                    }
                    _UI::SimpleTooltip("Load immediately");
                }

                UI::EndTable();
            }
            UI::PopStyleVar();
        } else if (browsePath.Length > 0 && browseFiles.Length == 0) {
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled("No ghost/replay files found. Press Scan to refresh.");
        }

        if (recentFiles.Length > 0) {
            UI::Separator();
            UI::TextDisabled(Icons::ClockO + " Recent (" + recentFiles.Length + ")");
            UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));
            int rflags = UI::TableFlags::RowBg | UI::TableFlags::Borders;
            if (UI::BeginTable("QuickBrowserRecentFiles", 3, rflags)) {
                UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 30);
                UI::TableSetupColumn("File", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("Folder", UI::TableColumnFlags::WidthStretch);
                UI::TableHeadersRow();

                for (uint i = 0; i < recentFiles.Length; i++) {
                    string path = recentFiles[i];
                    UI::TableNextRow();

                    UI::TableNextColumn();
                    if (_UI::IconButton(Icons::Play, "qb_recent_" + i, vec2(28, 0))) {
                        AddToRecent(path);
                        loadRecord.LoadRecordFromLocalFile(path);
                    }
                    _UI::SimpleTooltip("Load again");

                    UI::TableNextColumn();
                    UI::Text(Path::GetFileName(path));

                    UI::TableNextColumn();
                    UI::TextDisabled(Path::GetDirectoryName(path));
                }

                UI::EndTable();
            }
            UI::PopStyleVar();
        }
        UI::PopStyleVar();
    }

    void RenderDirectFilesTab(int loadableCount) {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
        if (_UI::Button(Icons::FolderOpen + " Open File Explorer", vec2(200, 0))) {
            FileExplorer::fe_Start(
                "Local Files", true, "path", vec2(1, -1),
                qb_ReplaysRoot, "", { "replay", "ghost" }
            );
        }
        UI::PopStyleColor(3);
        _UI::SimpleTooltip("Open a file picker to select .Ghost.Gbx or .Replay.Gbx files from any folder");

        UI::SameLine();
        UI::BeginDisabled(loadableCount == 0);
        if (_UI::Button(Icons::Download + " Load All (" + loadableCount + ")")) {
            LoadQueuedPaths();
        }
        UI::EndDisabled();
        _UI::SimpleTooltip("Load every queued path from the list below");

        UI::SameLine();
        UI::BeginDisabled(!CanClearQueuedPaths());
        if (_UI::Button(Icons::Times + " Clear")) {
            ResetManualFileRows();
        }
        UI::EndDisabled();

        UI::SameLine();
        if (_UI::Button(Icons::Plus + " Add Path")) {
            if (manualFilePaths.Length == 0 || NormalizePath(manualFilePaths[manualFilePaths.Length - 1]).Length > 0) {
                manualFilePaths.InsertLast("");
            }
        }

        UI::Dummy(vec2(0, 2));
        for (uint i = 0; i < manualFilePaths.Length; i++) {
            bool canRemove = manualFilePaths.Length > 1 || NormalizePath(manualFilePaths[i]).Length > 0;
            UI::BeginDisabled(!canRemove);
            if (_UI::IconButton(Icons::Times, "rm_manual_" + i, vec2(28, 0))) {
                RemoveManualFilePathAt(i);
                UI::EndDisabled();
                continue;
            }
            UI::EndDisabled();
            _UI::SimpleTooltip(manualFilePaths.Length > 1 ? "Remove this queued path" : "Clear this queued path");
            UI::SameLine();
            UI::SetNextItemWidth(-1);
            manualFilePaths[i] = UI::InputText("##ManualFilePath_" + i, manualFilePaths[i]);
        }
        UI::PopStyleVar();
    }

    void RenderArchivistQuickRow(const string &in label, ArchivistEntry@ entry, int count, const string &in idSuffix) {
        UI::Text(label);
        UI::SameLine();

        if (entry is null) {
            UI::TextDisabled("No detected match");
            return;
        }

        string summary = entry.fileName;
        if (count > 1) summary += " (+" + (count - 1) + " more)";
        UI::TextDisabled(summary);

        UI::SameLine();
        if (_UI::Button(Icons::Plus + " Queue##ArchivistQueue_" + idSuffix)) {
            AddManualFilePath(entry.path);
        }
        _UI::SimpleTooltip("Queue this Archivist file");

        UI::SameLine();
        if (_UI::Button(Icons::Play + " Load##ArchivistLoad_" + idSuffix)) {
            AddToRecent(entry.path);
            loadRecord.LoadRecordFromLocalFile(entry.path);
        }
        _UI::SimpleTooltip("Load this Archivist file immediately");
    }

    void RenderArchivistTab(int loadableCount) {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        if (_UI::Button(Icons::Refresh + " Refresh Tree")) {
            archivistTreeOpen.DeleteAll();
            archivistNeedsRefresh = false;
        }
        _UI::SimpleTooltip("Collapse and refresh the Archivist tree");

        UI::SameLine();
        UI::BeginDisabled(!IO::FolderExists(qb_Archivist));
        if (_UI::Button(Icons::FolderOpen + " Open Folder")) {
            _IO::OpenFolder(qb_Archivist);
        }
        UI::EndDisabled();

        UI::SameLine();
        UI::BeginDisabled(loadableCount == 0);
        if (_UI::Button(Icons::Download + " Load All (" + loadableCount + ")##ArchivistLoadAll")) {
            LoadQueuedPaths();
        }
        UI::EndDisabled();

        UI::SameLine();
        UI::BeginDisabled(!CanClearQueuedPaths());
        if (_UI::Button(Icons::Times + " Clear##ArchivistClear")) {
            ResetManualFileRows();
        }
        UI::EndDisabled();

        UI::SameLine();
        UI::TextDisabled(Icons::List + " " + loadableCount + " queued");

        UI::Dummy(vec2(0, 2));

        if (!IO::FolderExists(qb_Archivist)) {
            UI::TextDisabled("No Archivist folder found yet. Use Archivist once or verify its replay path.");
            UI::PopStyleVar();
            return;
        }

        archivistShowComplete = UI::Checkbox("Complete", archivistShowComplete);
        UI::SameLine();
        archivistShowPartial = UI::Checkbox("Partial", archivistShowPartial);
        UI::SameLine();
        archivistShowSegmented = UI::Checkbox("Segmented", archivistShowSegmented);

        UI::SameLine();
        UI::SetNextItemWidth(120);
        if (UI::BeginCombo("Sort##ArchivistSort", GetArchivistSortModeLabel())) {
            bool timestampSelected = archivistSortMode == int(ArchivistSortMode::Timestamp);
            if (UI::Selectable("Timestamp", timestampSelected)) {
                archivistSortMode = int(ArchivistSortMode::Timestamp);
            }
            if (timestampSelected) UI::SetItemDefaultFocus();

            bool timeSelected = archivistSortMode == int(ArchivistSortMode::Time);
            if (UI::Selectable("Time", timeSelected)) {
                archivistSortMode = int(ArchivistSortMode::Time);
            }
            if (timeSelected) UI::SetItemDefaultFocus();

            UI::EndCombo();
        }

        UI::Dummy(vec2(0, 4));
        string currentMapName = Text::StripFormatCodes(get_CurrentMapName()).Trim();
        UI::TextDisabled("Current Map");
        UI::SameLine();
        if (currentMapName.Length > 0) UI::Text(currentMapName);
        else UI::Text("");

        UI::Dummy(vec2(0, 2));
        UI::PushItemWidth(220);
        archivistFilter = UI::InputText(Icons::Search + "##ArchivistFilter", archivistFilter);
        UI::PopItemWidth();
        UI::SameLine();

        string mapUidLower = get_CurrentMapUID().ToLower();
        bool hasCurrentMap = mapUidLower.Length > 0;
        archivistCurrentMapOnly = UI::Checkbox("Current Map Only", archivistCurrentMapOnly);

        UI::Dummy(vec2(0, 4));

        string archivistFilterLower = archivistFilter.Trim().ToLower();
        array<string> archivistSearchRoots;
        FindArchivistSearchRootFolders(archivistFilterLower, archivistSearchRoots);
        if (archivistSearchRoots.Length > 0) {
            UI::TextDisabled("Scoped to " + archivistSearchRoots.Length + " matching map folder(s).");
        }

        ArchivistEntry@ firstFull;
        ArchivistEntry@ firstSegmented;
        int fullCount = 0;
        int segmentedCount = 0;
        if (hasCurrentMap) {
            FindCurrentMapArchivistPicks(mapUidLower, firstFull, firstSegmented, fullCount, segmentedCount);
            RenderArchivistQuickRow("Complete", firstFull, fullCount, "Complete");
            RenderArchivistQuickRow("Segmented", firstSegmented, segmentedCount, "Segmented");
        }

        UI::Separator();

        archivistFileActionId = 0;
        if (UI::BeginChild("ArchivistTreeView", vec2(0, 320), true)) {
            RenderArchivistFolderNode(ArchivistRoot(), mapUidLower, archivistSearchRoots);
        }
        UI::EndChild();
        UI::PopStyleVar();
    }

    void Render() {
        EnsureManualFileRows();

        auto explorer = FileExplorer::fe_GetExplorerById("Local Files");
        if (explorer !is null && explorer.exports.IsSelectionComplete()) {
            auto paths = explorer.exports.GetSelectedPaths();
            if (paths !is null) {
                ReplaceManualFilePaths(paths);
                explorer.exports.SetSelectionComplete();
            }
        }

        int loadableCount = CollectLoadablePaths().Length;

        UI::PushStyleColor(UI::Col::Tab, HeaderBg);
        UI::PushStyleColor(UI::Col::TabHovered, HeaderHoverBg);
        UI::PushStyleColor(UI::Col::TabActive, HeaderActiveBg);

        UI::BeginTabBar("LocalFilesTabs");
        if (UI::BeginTabItem(Icons::FolderOpen + " Quick Browser")) {
            RenderQuickBrowserTab(loadableCount);
            UI::EndTabItem();
        }

        if (UI::BeginTabItem(Icons::File + " Direct Files")) {
            RenderDirectFilesTab(loadableCount);
            UI::EndTabItem();
        }

        if (IsArchivistAvailable() && UI::BeginTabItem(Icons::Archive + " Archivist")) {
            RenderArchivistTab(loadableCount);
            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::PopStyleColor(3);
    }
}
}
