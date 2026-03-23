namespace Features {
namespace LRFromSaved {

    array<string> importSelectedFiles;
    string savedFilter = "";

    void RT_LRFromSaved() {
        SavedRecords::RefreshIfNeeded();

        if (UI::Button(Icons::FolderOpen + " Open Saved Folder")) {
            _IO::OpenFolder(Server::savedFilesDirectory);
        }
        UI::SameLine();
        if (UI::Button(Icons::Refresh + " Refresh")) {
            SavedRecords::MarkDirty();
        }
        UI::SameLine();
        if (SavedRecords::_saving) {
            UI::TextDisabled(Icons::HourglassHalf + " Saving...");
            UI::SameLine();
        }
        UI::TextDisabled("" + SavedRecords::records.Length + " saved record(s)");

        UI::Separator();
        UI::Dummy(vec2(0, 4));

        if (UI::CollapsingHeader(Icons::Upload + " Import Files")) {
            UI::Dummy(vec2(0, 2));
            UI::TextDisabled("Import .Gbx replay/ghost files into the library.");
            UI::Dummy(vec2(0, 2));

            if (UI::Button(Icons::FolderOpen + " Browse for Files")) {
                FileExplorer::fe_Start(
                    "Import Files",
                    true,
                    "path",
                    vec2(1, -1),
                    IO::FromUserGameFolder("Replays/"),
                    "",
                    { "replay", "ghost" }
                );
            }

            auto explorer = FileExplorer::fe_GetExplorerById("Import Files");
            if (explorer !is null && explorer.exports.IsSelectionComplete()) {
                auto paths = explorer.exports.GetSelectedPaths();
                if (paths !is null) {
                    importSelectedFiles = paths;
                    explorer.exports.SetSelectionComplete();
                }
            }

            if (importSelectedFiles.Length > 0) {
                UI::Dummy(vec2(0, 2));
                UI::Text("Selected: " + importSelectedFiles.Length + " file(s)");
                for (uint i = 0; i < importSelectedFiles.Length; i++) {
                    UI::TextDisabled("  " + Path::GetFileName(importSelectedFiles[i]));
                }
                UI::Dummy(vec2(0, 2));
                if (UI::Button(Icons::Download + " Import to Library")) {
                    for (uint fi = 0; fi < importSelectedFiles.Length; fi++) {
                        if (importSelectedFiles[fi] != "") {
                            SavedRecords::ImportFile(importSelectedFiles[fi]);
                        }
                    }
                    importSelectedFiles.RemoveRange(0, importSelectedFiles.Length);
                }
            }
            UI::Dummy(vec2(0, 4));
        }

        UI::Dummy(vec2(0, 4));

        if (SavedRecords::records.Length == 0) {
            UI::Dummy(vec2(0, 20));
            UI::PushFontSize(16);
            UI::TextDisabled(Icons::FolderOpen + "  No saved records.");
            UI::PopFontSize();
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled("Save ghosts from the Loaded page, or import replay files above.");
            return;
        }

        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
        UI::PushItemWidth(-1);
        savedFilter = UI::InputText(Icons::Search + " ##ARL_SavedFilter", savedFilter);
        UI::PopItemWidth();
        UI::PopStyleVar();
        _UI::SimpleTooltip("Filter by name, source, or map UID");

        UI::Dummy(vec2(0, 4));

        string filterLower = savedFilter.ToLower();

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));

        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY | UI::TableFlags::Resizable;
        if (UI::BeginTable("ARL_SavedRecords", 6, flags, vec2(0, 0))) {
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 85);
            UI::TableSetupColumn("Source", UI::TableColumnFlags::WidthFixed, 80);
            UI::TableSetupColumn("Map", UI::TableColumnFlags::WidthFixed, 100);
            UI::TableSetupColumn("Saved", UI::TableColumnFlags::WidthFixed, 130);
            UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, 120);
            UI::TableHeadersRow();

            for (uint j = 0; j < SavedRecords::records.Length; j++) {
                auto rec = SavedRecords::records[j];

                if (filterLower.Length > 0) {
                    string nameL = rec.nickname.ToLower();
                    string srcL = rec.source.ToLower();
                    string mapL = rec.mapUid.ToLower();
                    string fileL = rec.replayFileName.ToLower();
                    if (!nameL.Contains(filterLower) && !srcL.Contains(filterLower)
                        && !mapL.Contains(filterLower) && !fileL.Contains(filterLower))
                        continue;
                }

                UI::TableNextRow();

                UI::TableNextColumn();
                string displayName = rec.nickname.Length > 0 ? rec.nickname : rec.replayFileName;
                UI::Text(displayName);
                if (rec.nickname.Length > 0) {
                    _UI::SimpleTooltip(rec.replayFileName);
                }

                UI::TableNextColumn();
                if (rec.time > 0) {
                    UI::Text(ARL_FormatMs(rec.time));
                } else {
                    UI::TextDisabled("-");
                }

                UI::TableNextColumn();
                UI::TextDisabled(rec.source.Length > 0 ? rec.source : "-");

                UI::TableNextColumn();
                if (rec.mapUid.Length > 0) {
                    string shortUid = rec.mapUid;
                    if (uint(shortUid.Length) > 12) shortUid = shortUid.SubStr(0, 12) + "...";
                    UI::TextDisabled(shortUid);
                    _UI::SimpleTooltip(rec.mapUid);
                } else {
                    UI::TextDisabled("-");
                }

                UI::TableNextColumn();
                UI::TextDisabled(rec.savedAt);

                UI::TableNextColumn();
                UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

                if (UI::Button(Icons::Download + "##lib_load_" + j, vec2(28, 0))) {
                    SavedRecords::LoadRecord(j);
                }
                _UI::SimpleTooltip("Load this ghost");

                UI::SameLine();
                if (UI::Button(Icons::FolderOpen + "##lib_folder_" + j, vec2(28, 0))) {
                    _IO::OpenFolder(Server::savedFilesDirectory);
                }
                _UI::SimpleTooltip("Open saved folder");

                UI::SameLine();
                UI::PushStyleColor(UI::Col::Button, vec4(0.50, 0.18, 0.18, 0.80));
                UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65, 0.22, 0.22, 1.0));
                UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80, 0.28, 0.28, 1.0));
                if (UI::Button(Icons::TrashO + "##lib_del_" + j, vec2(28, 0))) {
                    SavedRecords::DeleteRecord(j);
                }
                UI::PopStyleColor(3);
                _UI::SimpleTooltip("Delete this saved record");

                UI::PopStyleVar();
            }
            UI::EndTable();
        }

        UI::PopStyleVar();
        UI::PopStyleColor();
    }
}
}
