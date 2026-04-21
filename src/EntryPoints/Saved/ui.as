namespace EntryPoints {
namespace Saved {

    array<string> importSelectedFiles;
    string savedFilter = "";
    string savedMapFilter = "";
    string selectedMapUid = "";

    array<string> GetUniqueMapUids() {
        dictionary seen;
        array<string> uids;
        for (uint i = 0; i < SavedRecords::records.Length; i++) {
            string uid = SavedRecords::records[i].mapUid;
            if (uid.Length == 0) uid = "(no map)";
            if (!seen.Exists(uid)) {
                seen.Set(uid, true);
                uids.InsertLast(uid);
            }
        }
        return uids;
    }

    int CountRecordsForMap(const string &in uid) {
        int count = 0;
        for (uint i = 0; i < SavedRecords::records.Length; i++) {
            string recUid = SavedRecords::records[i].mapUid;
            if (recUid.Length == 0) recUid = "(no map)";
            if (recUid == uid) count++;
        }
        return count;
    }

    void Render() {
        SavedRecords::RefreshIfNeeded();

        if (_UI::Button(Icons::FolderOpen + " Open Folder")) _IO::OpenFolder(Server::storedFilesDirectory);
        UI::SameLine();
        if (_UI::IconButton(Icons::Refresh)) SavedRecords::MarkDirty();
        UI::SameLine();
        if (SavedRecords::_saving) {
            UI::TextDisabled(Icons::HourglassHalf + " Saving...");
            UI::SameLine();
        }
        UI::TextDisabled("" + SavedRecords::records.Length + " saved");

        if (SavedRecords::records.Length == 0) {
            UI::TextDisabled("No saved records. Save ghosts from the Loaded page, or import below.");

            if (UI::CollapsingHeader(Icons::Upload + " Import Files")) {
                RT_ImportSection();
            }
            return;
        }

        UI::Separator();

        int layoutFlags = UI::TableFlags::SizingFixedFit | UI::TableFlags::BordersInnerV;
        if (UI::BeginTable("SavedLayout", 2, layoutFlags, vec2(0, 0))) {
            UI::TableSetupColumn("Maps", UI::TableColumnFlags::WidthFixed, 200);
            UI::TableSetupColumn("Ghosts", UI::TableColumnFlags::WidthStretch);
            UI::TableNextRow();

            UI::TableNextColumn();
            RT_MapList();

            UI::TableNextColumn();
            RT_GhostTable();

            UI::EndTable();
        }

        if (UI::CollapsingHeader(Icons::Upload + " Import Files")) {
            RT_ImportSection();
        }
    }

    void RT_MapList() {
        UI::AlignTextToFramePadding();
        UI::Text(Icons::Search);
        UI::SameLine();
        UI::SetNextItemWidth(-1);
        savedMapFilter = UI::InputText("##mapFilter", savedMapFilter);

        if (UI::BeginChild("SavedMapList", vec2(0, 0), true)) {
            string mapFilterLower = savedMapFilter.ToLower();
            array<string> uids = GetUniqueMapUids();

            bool allSelected = selectedMapUid.Length == 0;
            if (UI::Selectable(Icons::List + " All (" + SavedRecords::records.Length + ")", allSelected)) {
                selectedMapUid = "";
            }

            for (uint i = 0; i < uids.Length; i++) {
                string uid = uids[i];
                if (mapFilterLower.Length > 0 && !uid.ToLower().Contains(mapFilterLower)) continue;

                int count = CountRecordsForMap(uid);
                string shortUid = uid;
                if (uid != "(no map)" && uint(shortUid.Length) > 16) shortUid = shortUid.SubStr(0, 16) + "...";
                string label = shortUid + " (" + count + ")";

                if (UI::Selectable(label, selectedMapUid == uid)) {
                    selectedMapUid = uid;
                }
                if (uid != "(no map)") _UI::SimpleTooltip(uid);
            }
            UI::EndChild();
        }
    }

    void RT_GhostTable() {
        UI::AlignTextToFramePadding();
        UI::Text(Icons::Search);
        UI::SameLine();
        UI::SetNextItemWidth(-1);
        savedFilter = UI::InputText("##ghostFilter", savedFilter);

        string filterLower = savedFilter.ToLower();

        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
        UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 3));

        int flags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::ScrollY | UI::TableFlags::Resizable;
        if (UI::BeginTable("SavedGhosts", 5, flags, vec2(0, 0))) {
            UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch);
            UI::TableSetupColumn("Time", UI::TableColumnFlags::WidthFixed, 80);
            UI::TableSetupColumn("Source", UI::TableColumnFlags::WidthFixed, 70);
            UI::TableSetupColumn("Saved", UI::TableColumnFlags::WidthFixed, 120);
            UI::TableSetupColumn("##Actions", UI::TableColumnFlags::WidthFixed, 80);
            UI::TableHeadersRow();

            for (uint j = 0; j < SavedRecords::records.Length; j++) {
                auto rec = SavedRecords::records[j];

                string recUid = rec.mapUid.Length > 0 ? rec.mapUid : "(no map)";
                if (selectedMapUid.Length > 0 && recUid != selectedMapUid) continue;

                if (filterLower.Length > 0) {
                    string nameL = rec.nickname.ToLower();
                    string srcL = rec.source.ToLower();
                    string fileL = rec.fileName.ToLower();
                    if (!nameL.Contains(filterLower) && !srcL.Contains(filterLower) && !fileL.Contains(filterLower))
                        continue;
                }

                UI::TableNextRow();

                UI::TableNextColumn();
                string displayName = rec.nickname.Length > 0 ? rec.nickname : rec.fileName;
                UI::Text(displayName);
                if (rec.nickname.Length > 0) _UI::SimpleTooltip(rec.fileName);

                UI::TableNextColumn();
                if (rec.time > 0) UI::Text(FormatMs(rec.time));
                else UI::TextDisabled("-");

                UI::TableNextColumn();
                UI::TextDisabled(rec.source.Length > 0 ? rec.source : "-");

                UI::TableNextColumn();
                UI::TextDisabled(rec.savedAt);

                UI::TableNextColumn();
                if (_UI::IconButton(Icons::Play, "load_" + j, vec2(28, 0))) {
                    SavedRecords::LoadRecord(j);
                }
                _UI::SimpleTooltip("Load ghost");
                UI::SameLine();
                UI::PushStyleColor(UI::Col::Button, vec4(0.50, 0.18, 0.18, 0.80));
                UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65, 0.22, 0.22, 1.0));
                UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80, 0.28, 0.28, 1.0));
                if (_UI::IconButton(Icons::TrashO, "del_" + j, vec2(28, 0))) {
                    SavedRecords::DeleteRecord(j);
                }
                UI::PopStyleColor(3);
                _UI::SimpleTooltip("Delete");
            }
            UI::EndTable();
        }

        UI::PopStyleVar();
        UI::PopStyleColor();
    }

    void RT_ImportSection() {
        UI::TextDisabled("Import .Gbx replay/ghost files into the library.");
        if (_UI::Button(Icons::FolderOpen + " Browse for Files")) {
            FileExplorer::fe_Start(
                "Import Files", true, "path", vec2(1, -1),
                IO::FromUserGameFolder("Replays/"), "",
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
            UI::Text("Selected: " + importSelectedFiles.Length + " file(s)");
            for (uint i = 0; i < importSelectedFiles.Length; i++) {
                UI::TextDisabled("  " + Path::GetFileName(importSelectedFiles[i]));
            }
            if (_UI::Button(Icons::Download + " Import to Library")) {
                for (uint fi = 0; fi < importSelectedFiles.Length; fi++) {
                    if (importSelectedFiles[fi] != "") {
                        SavedRecords::ImportFile(importSelectedFiles[fi]);
                    }
                }
                importSelectedFiles.RemoveRange(0, importSelectedFiles.Length);
            }
        }
    }
}
}
