namespace Features {
namespace LRFromFile {
    array<string> selectedFiles;

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

    void RT_LRFromLocalFiles() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
        if (UI::Button(Icons::FolderOpen + " Open File Explorer", vec2(200, 0))) {
            FileExplorer::fe_Start(
                "Local Files", true, "path", vec2(1, -1),
                qb_ReplaysRoot, "", { "replay", "ghost" }
            );
        }
        UI::PopStyleColor(3);
        _UI::SimpleTooltip("Open a file picker to select .Ghost.Gbx or .Replay.Gbx files from any folder");

        UI::SameLine();
        UI::BeginDisabled(selectedFiles.Length == 0);
        if (UI::Button(Icons::Download + " Load (" + selectedFiles.Length + ")")) {
            for (uint i = 0; i < selectedFiles.Length; i++) {
                if (selectedFiles[i] != "") {
                    AddToRecent(selectedFiles[i]);
                    loadRecord.LoadRecordFromLocalFile(selectedFiles[i]);
                }
            }
        }
        _UI::SimpleTooltip("Load all selected files as ghosts/replays");
        UI::EndDisabled();

        UI::SameLine();
        UI::BeginDisabled(selectedFiles.Length == 0);
        if (UI::Button(Icons::Times + " Clear")) {
            selectedFiles.RemoveRange(0, selectedFiles.Length);
        }
        UI::EndDisabled();

        auto explorer = FileExplorer::fe_GetExplorerById("Local Files");
        if (explorer !is null && explorer.exports.IsSelectionComplete()) {
            auto paths = explorer.exports.GetSelectedPaths();
            if (paths !is null) {
                selectedFiles = paths;
                explorer.exports.SetSelectionComplete();
            }
        }

        if (selectedFiles.Length > 0) {
            UI::Dummy(vec2(0, 2));
            for (uint i = 0; i < selectedFiles.Length; i++) {
                UI::PushItemWidth(-40);
                selectedFiles[i] = UI::InputText("##FilePath_" + i, selectedFiles[i]);
                UI::PopItemWidth();
                UI::SameLine();
                if (UI::Button(Icons::Times + "##rm_" + i, vec2(28, 0))) {
                    selectedFiles.RemoveAt(i);
                    i--;
                }
            }
        }

        UI::PopStyleVar();

        UI::Separator();

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        if (UI::Button(Icons::Home + " Replays/")) { QuickOpenFolder(qb_ReplaysRoot); }
        UI::SameLine();
        if (UI::Button(Icons::ClockO + " Autosaves/")) { QuickOpenFolder(qb_Autosaves); }
        UI::SameLine();
        if (UI::Button(Icons::SnapchatGhost + " ARL/")) { QuickOpenFolder(qb_ARLRoot); }
        UI::SameLine();
        if (UI::Button(Icons::CloudDownload + " Downloads/")) { QuickOpenFolder(qb_Downloads); }

#if DEPENDENCY_ARCHIVIST
        if (IO::FolderExists(qb_Archivist)) {
            UI::SameLine();
            if (UI::Button(Icons::Archive + " Archivist/")) { QuickOpenFolder(qb_Archivist); }
        }
#endif

#if DEPENDENCY_BETTERREPLAYSFOLDER
        if (IO::FolderExists(qb_Offload)) {
            UI::SameLine();
            if (UI::Button(Icons::Exchange + " Replays_Offload/")) { QuickOpenFolder(qb_Offload); }
        }
#endif

        UI::PushItemWidth(-120);
        browsePath = UI::InputText("##BrowsePath", browsePath);
        UI::PopItemWidth();
        UI::SameLine();
        if (UI::Button(Icons::Refresh + " Scan", vec2(110, 0))) {
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
            if (UI::BeginTable("ARL_BrowseFiles", 3, tflags, vec2(0, 220))) {
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
                    if (UI::Button(Icons::Plus + "##sel_" + bi, vec2(28, 0))) {
                        bool dup = false;
                        for (uint si = 0; si < selectedFiles.Length; si++) {
                            if (selectedFiles[si] == filePath) { dup = true; break; }
                        }
                        if (!dup) selectedFiles.InsertLast(filePath);
                    }
                    _UI::SimpleTooltip("Add to selection");
                    UI::SameLine();
                    if (UI::Button(Icons::Play + "##ld_" + bi, vec2(28, 0))) {
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

            if (UI::CollapsingHeader(Icons::ClockO + " Recent (" + recentFiles.Length + ")")) {
                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(4, 2));
                int rflags = UI::TableFlags::RowBg | UI::TableFlags::Borders;
                if (UI::BeginTable("ARL_RecentFiles", 3, rflags)) {
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
                        if (UI::Button(Icons::Play + "##rl_" + ri, vec2(28, 0))) {
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
