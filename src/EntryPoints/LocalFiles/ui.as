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

    void EnsureManualFileRows() {
        if (manualFilePaths.Length == 0) manualFilePaths.InsertLast("");
    }

    void ResetManualFileRows() {
        manualFilePaths.RemoveRange(0, manualFilePaths.Length);
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
        manualFilePaths.RemoveRange(0, manualFilePaths.Length);
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

    void RefreshBrowse() {
        browseFiles.RemoveRange(0, browseFiles.Length);
        if (browsePath.Length == 0 || !IO::FolderExists(browsePath)) return;
        auto files = IO::IndexFolder(browsePath, false);
        if (files is null) return;
        for (uint i = 0; i < files.Length; i++) {
            string lower = files[i].ToLower();
            if (lower.EndsWith(".ghost.gbx") || lower.EndsWith(".replay.gbx")) {
                browseFiles.InsertLast(files[i]);
            }
        }
    }

    void QuickOpenFolder(const string &in path) {
        browsePath = path;
        RefreshBrowse();
    }

    void LoadQueuedPaths() {
        auto loadablePaths = CollectLoadablePaths();
        for (uint i = 0; i < loadablePaths.Length; i++) {
            AddToRecent(loadablePaths[i]);
            loadRecord.LoadRecordFromLocalFile(loadablePaths[i]);
        }
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

        auto loadablePaths = CollectLoadablePaths();
        int loadableCount = loadablePaths.Length;

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
        _UI::SimpleTooltip("Load every queued path from the list below");
        UI::EndDisabled();

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

        UI::Separator();

        if (UI::CollapsingHeader(Icons::FolderOpen + " Quick Browser & Recent")) {
            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

            if (_UI::Button(Icons::Home + " Replays/")) { QuickOpenFolder(qb_ReplaysRoot); }
            UI::SameLine();
            if (_UI::Button(Icons::ClockO + " Autosaves/")) { QuickOpenFolder(qb_Autosaves); }
            UI::SameLine();
            if (_UI::Button(Icons::SnapchatGhost + " ARL/")) { QuickOpenFolder(qb_ARLRoot); }
            UI::SameLine();
            if (_UI::Button(Icons::CloudDownload + " Downloads/")) { QuickOpenFolder(qb_Downloads); }

#if DEPENDENCY_ARCHIVIST
            bool archivistLoaded = PluginState::IsPluginLoaded("Archivist");
            if (archivistLoaded && IO::FolderExists(qb_Archivist)) {
                UI::Dummy(vec2(0, 2));
                if (_UI::Button(Icons::Archive + " Archivist/")) { QuickOpenFolder(qb_Archivist); }
            }
#endif

#if DEPENDENCY_BETTERREPLAYSFOLDER
            bool betterReplaysFolderLoaded = PluginState::IsPluginLoaded("BetterReplaysFolder");
            if (betterReplaysFolderLoaded && IO::FolderExists(qb_Offload)) {
                bool sameLine = false;
#if DEPENDENCY_ARCHIVIST
                sameLine = archivistLoaded && IO::FolderExists(qb_Archivist);
#endif
                if (sameLine) UI::SameLine();
                else UI::Dummy(vec2(0, 2));
                if (_UI::Button(Icons::Exchange + " Replays_Offload/")) { QuickOpenFolder(qb_Offload); }
            }
#endif

            UI::PushItemWidth(-120);
            browsePath = UI::InputText("##BrowsePath", browsePath);
            UI::PopItemWidth();
            UI::SameLine();
            if (_UI::Button(Icons::Refresh + " Scan", vec2(110, 0))) {
                RefreshBrowse();
            }

            UI::PopStyleVar();

            if (browsePath.Length > 0 && browseFiles.Length > 0) {
                UI::PushItemWidth(200);
                browseFilter = UI::InputText(Icons::Search + "##BrowseFilter", browseFilter);
                UI::PopItemWidth();
                UI::SameLine();
                UI::TextDisabled(browseFiles.Length + " file(s)");

                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));
                int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY;
                if (UI::BeginTable("BrowseFiles", 3, tflags, vec2(0, 220))) {
                    UI::TableSetupColumn("File", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthFixed, 70);
                    UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 70);
                    UI::TableHeadersRow();

                    string filterLower = browseFilter.ToLower();

                    for (uint bi = 0; bi < browseFiles.Length; bi++) {
                        string filePath = browseFiles[bi];
                        string fileName = Path::GetFileName(filePath);

                        if (filterLower.Length > 0 && !fileName.ToLower().Contains(filterLower)) continue;

                        bool isReplay = fileName.ToLower().EndsWith(".replay.gbx");

                        UI::TableNextRow();

                        UI::TableNextColumn();
                        UI::Text(fileName);
                        _UI::SimpleTooltip(filePath);

                        UI::TableNextColumn();
                        if (isReplay) {
                            UI::Text("\\$cda" + Icons::Film + " Replay\\$z");
                        } else {
                            UI::Text("\\$aca" + Icons::SnapchatGhost + " Ghost\\$z");
                        }

                        UI::TableNextColumn();
                        if (_UI::IconButton(Icons::Plus, "sel_" + bi, vec2(28, 0))) {
                            AddManualFilePath(filePath);
                        }
                        _UI::SimpleTooltip("Queue this file");
                        UI::SameLine();
                        if (_UI::IconButton(Icons::Play, "ld_" + bi, vec2(28, 0))) {
                            AddToRecent(filePath);
                            loadRecord.LoadRecordFromLocalFile(filePath);
                        }
                        _UI::SimpleTooltip("Load immediately");
                    }

                    UI::EndTable();
                }
                UI::PopStyleVar();
            } else if (browsePath.Length > 0 && browseFiles.Length == 0) {
                UI::TextDisabled("No ghost/replay files found. Press Scan to refresh.");
            }

            if (recentFiles.Length > 0) {
                UI::Separator();
                UI::TextDisabled(Icons::ClockO + " Recent (" + recentFiles.Length + ")");
                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));
                int rflags = UI::TableFlags::RowBg | UI::TableFlags::Borders;
                if (UI::BeginTable("RecentFiles", 3, rflags)) {
                    UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 30);
                    UI::TableSetupColumn("File", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Folder", UI::TableColumnFlags::WidthStretch);
                    UI::TableHeadersRow();

                    for (uint ri = 0; ri < recentFiles.Length; ri++) {
                        string rPath = recentFiles[ri];
                        string rName = Path::GetFileName(rPath);
                        string rDir = Path::GetDirectoryName(rPath);

                        UI::TableNextRow();

                        UI::TableNextColumn();
                        if (_UI::IconButton(Icons::Play, "rl_" + ri, vec2(28, 0))) {
                            AddToRecent(rPath);
                            loadRecord.LoadRecordFromLocalFile(rPath);
                        }
                        _UI::SimpleTooltip("Load again");

                        UI::TableNextColumn();
                        UI::Text(rName);

                        UI::TableNextColumn();
                        UI::TextDisabled(rDir);
                    }

                    UI::EndTable();
                }
                UI::PopStyleVar();
            }
        }
    }
}
}
