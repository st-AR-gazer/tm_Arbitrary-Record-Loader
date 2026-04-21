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

    enum ArchivistMode {
        FullBest = 0,
        Segmented,
        All
    }

    class ArchivistEntry {
        string path;
        string fileName;
        string directory;
        string relativeDirectory;
        string pathLower;
        string typeLabel;
        bool isSegmented = false;
        bool isFullBest = false;
    }

    array<ArchivistEntry@> archivistEntries;
    bool archivistNeedsRefresh = true;
    string archivistFilter = "";
    bool archivistCurrentMapOnly = true;
    ArchivistMode archivistMode = ArchivistMode::All;

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

    bool PathLooksFullBest(const string &in lowerPath) {
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
        if (entry.isFullBest) return "Full Best";
        return "Other";
    }

    bool ArchivistEntryMatchesCurrentMap(ArchivistEntry@ entry, const string &in mapUidLower) {
        if (entry is null || mapUidLower.Length == 0) return false;
        return entry.pathLower.Contains(mapUidLower);
    }

    bool ArchivistEntryMatchesFilters(ArchivistEntry@ entry, const string &in mapUidLower) {
        if (entry is null) return false;

        bool applyCurrentMap = archivistCurrentMapOnly && mapUidLower.Length > 0;
        if (applyCurrentMap && !ArchivistEntryMatchesCurrentMap(entry, mapUidLower)) return false;

        switch (archivistMode) {
            case ArchivistMode::FullBest:
                if (!entry.isFullBest) return false;
                break;
            case ArchivistMode::Segmented:
                if (!entry.isSegmented) return false;
                break;
            case ArchivistMode::All:
                break;
        }

        string filterLower = archivistFilter.Trim().ToLower();
        if (filterLower.Length == 0) return true;

        return entry.fileName.ToLower().Contains(filterLower)
            || entry.relativeDirectory.ToLower().Contains(filterLower)
            || entry.pathLower.Contains(filterLower);
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

    void RefreshArchivistIndex() {
        archivistNeedsRefresh = false;
        if (archivistEntries.Length > 0) archivistEntries.RemoveRange(0, archivistEntries.Length);
        if (!IO::FolderExists(qb_Archivist)) return;

        auto files = IO::IndexFolder(qb_Archivist, true);
        if (files is null) return;

        string archivistRootLower = qb_Archivist.ToLower();
        for (uint i = 0; i < files.Length; i++) {
            string path = files[i];
            if (!IsLoadableFilePath(path)) continue;

            ArchivistEntry@ entry = ArchivistEntry();
            entry.path = path;
            entry.fileName = Path::GetFileName(path);
            entry.directory = Path::GetDirectoryName(path);
            entry.pathLower = path.ToLower();
            entry.typeLabel = GetLocalFileTypeLabel(path);
            entry.isSegmented = PathLooksSegmented(entry.pathLower);
            entry.isFullBest = PathLooksFullBest(entry.pathLower);

            if (entry.directory.ToLower().StartsWith(archivistRootLower)) {
                entry.relativeDirectory = entry.directory.SubStr(qb_Archivist.Length);
            } else {
                entry.relativeDirectory = entry.directory;
            }
            if (entry.relativeDirectory.Length == 0) entry.relativeDirectory = "./";

            archivistEntries.InsertLast(entry);
        }
    }

    bool RenderArchivistModeButton(const string &in label, const string &in id, ArchivistMode mode) {
        bool active = archivistMode == mode;
        if (active) {
            UI::PushStyleColor(UI::Col::Button, HeaderActiveBg);
            UI::PushStyleColor(UI::Col::ButtonHovered, HeaderHoverBg);
            UI::PushStyleColor(UI::Col::ButtonActive, HeaderActiveBg);
        }

        bool clicked = _UI::Button(label + "##ArchivistMode_" + id);

        if (active) UI::PopStyleColor(3);
        if (clicked) archivistMode = mode;
        return clicked;
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

        if (IO::FolderExists(qb_Archivist)) {
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
        _UI::SimpleTooltip(entry.path);

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
        if (archivistNeedsRefresh) RefreshArchivistIndex();

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        if (_UI::Button(Icons::Refresh + " Refresh Index")) {
            archivistNeedsRefresh = true;
            RefreshArchivistIndex();
        }
        _UI::SimpleTooltip("Rescan the Archivist folder recursively");

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
#if DEPENDENCY_ARCHIVIST
        bool archivistPluginLoaded = PluginState::IsPluginLoaded("Archivist");
        UI::TextDisabled(archivistPluginLoaded ? "Archivist plugin detected." : "Archivist files can be browsed even when the plugin is not currently loaded.");
#else
        UI::TextDisabled("Browsing the local Archivist folder.");
#endif

        UI::TextDisabled("Folder: " + qb_Archivist);
        UI::Dummy(vec2(0, 2));

        if (!IO::FolderExists(qb_Archivist)) {
            UI::TextDisabled("No Archivist folder found yet. Use Archivist once or verify its replay path.");
            UI::PopStyleVar();
            return;
        }

        UI::TextDisabled(archivistEntries.Length + " file(s) indexed");
        UI::Dummy(vec2(0, 4));

        RenderArchivistModeButton(Icons::Certificate + " Full Bests", "Full", ArchivistMode::FullBest);
        UI::SameLine();
        RenderArchivistModeButton(Icons::List + " Segmented", "Segmented", ArchivistMode::Segmented);
        UI::SameLine();
        RenderArchivistModeButton(Icons::FolderOpen + " All", "All", ArchivistMode::All);

        UI::Dummy(vec2(0, 4));
        UI::PushItemWidth(220);
        archivistFilter = UI::InputText(Icons::Search + "##ArchivistFilter", archivistFilter);
        UI::PopItemWidth();
        UI::SameLine();

        string mapUidLower = get_CurrentMapUID().ToLower();
        bool hasCurrentMap = mapUidLower.Length > 0;
        UI::BeginDisabled(!hasCurrentMap);
        archivistCurrentMapOnly = UI::Checkbox("Current Map Only", archivistCurrentMapOnly);
        UI::EndDisabled();
        if (!hasCurrentMap) {
            UI::SameLine();
            UI::TextDisabled("(load a map to enable)");
        }

        UI::Dummy(vec2(0, 4));
        UI::TextDisabled(Icons::Map + " Current Map Picks");

        ArchivistEntry@ firstFull;
        ArchivistEntry@ firstSegmented;
        int fullCount = 0;
        int segmentedCount = 0;
        for (uint i = 0; i < archivistEntries.Length; i++) {
            auto entry = archivistEntries[i];
            if (!ArchivistEntryMatchesCurrentMap(entry, mapUidLower)) continue;
            if (entry.isFullBest) {
                fullCount++;
                if (firstFull is null) @firstFull = entry;
            }
            if (entry.isSegmented) {
                segmentedCount++;
                if (firstSegmented is null) @firstSegmented = entry;
            }
        }

        if (hasCurrentMap) {
            RenderArchivistQuickRow("Full Best", firstFull, fullCount, "Full");
            RenderArchivistQuickRow("Segmented", firstSegmented, segmentedCount, "Segmented");
        } else {
            UI::TextDisabled("Load a map to highlight current-map Archivist matches.");
        }

        UI::Separator();

        array<ArchivistEntry@> filtered;
        for (uint i = 0; i < archivistEntries.Length; i++) {
            auto entry = archivistEntries[i];
            if (!ArchivistEntryMatchesFilters(entry, mapUidLower)) continue;
            filtered.InsertLast(entry);
        }

        if (filtered.Length == 0) {
            UI::TextDisabled("No Archivist files matched the current filters.");
            UI::PopStyleVar();
            return;
        }

        UI::TextDisabled(filtered.Length + " matching file(s)");
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));
        int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY;
        if (UI::BeginTable("ArchivistEntries", 5, tflags, vec2(0, 260))) {
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Kind", UI::TableColumnFlags::WidthFixed, 92);
            UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthFixed, 64);
            UI::TableSetupColumn("Folder", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableHeadersRow();

            for (uint i = 0; i < filtered.Length; i++) {
                auto entry = filtered[i];
                UI::TableNextRow();

                UI::TableNextColumn();
                string nameText = entry.fileName;
                if (ArchivistEntryMatchesCurrentMap(entry, mapUidLower)) {
                    nameText = "\\$0f0" + Icons::Map + "\\$z " + nameText;
                }
                UI::Text(nameText);
                _UI::SimpleTooltip(entry.path);

                UI::TableNextColumn();
                UI::Text(GetArchivistKindLabel(entry));

                UI::TableNextColumn();
                UI::Text(entry.typeLabel);

                UI::TableNextColumn();
                UI::TextDisabled(entry.relativeDirectory);

                UI::TableNextColumn();
                if (_UI::IconButton(Icons::Plus, "arch_queue_" + i, vec2(28, 0))) {
                    AddManualFilePath(entry.path);
                }
                _UI::SimpleTooltip("Queue this Archivist file");
                UI::SameLine();
                if (_UI::IconButton(Icons::Play, "arch_load_" + i, vec2(28, 0))) {
                    AddToRecent(entry.path);
                    loadRecord.LoadRecordFromLocalFile(entry.path);
                }
                _UI::SimpleTooltip("Load immediately");
            }

            UI::EndTable();
        }
        UI::PopStyleVar();
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

        if (UI::BeginTabItem(Icons::Archive + " Archivist")) {
            RenderArchivistTab(loadableCount);
            UI::EndTabItem();
        }

        UI::EndTabBar();

        UI::PopStyleColor(3);
    }
}
}
