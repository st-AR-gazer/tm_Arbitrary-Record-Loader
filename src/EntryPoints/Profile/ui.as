namespace EntryPoints {
namespace Profile {
    bool _didInit = false;
    string downloadUrl = "";

    int selectedIndex = -1;
    string downloadedContent = "";
    array<Json::Value> mapList;

    string newJsonName = "";
    int recordOffset = 1;
    string mapFilter = "";

    void EnsureInit() {
        if (_didInit) return;
        _didInit = true;
        Create::RefreshFileList();
    }

    void Render() {
        EnsureInit();

        UI::TextDisabled("Profiles are JSON files that list maps for batch ghost loading.");
        UI::Dummy(vec2(0, 4));

        string comboLabel = (selectedIndex >= 0 && uint(selectedIndex) < Create::jsonFileNames.Length) ? Create::jsonFileNames[selectedIndex] : "Select a profile...";

        UI::PushItemWidth(UI::GetContentRegionAvail().x * 0.55f);
        if (UI::BeginCombo("##ProfileCombo", comboLabel)) {
            for (uint i = 0; i < Create::jsonFileNames.Length; i++) {
                bool isSelected = int(i) == selectedIndex;
                if (UI::Selectable(Create::jsonFileNames[i], isSelected)) {
                    selectedIndex = int(i);
                    downloadedContent = Create::LoadJsonContentByIndex(selectedIndex);
                    mapList = Create::GetMapListFromJson(downloadedContent);
                    mapFilter = "";
                }
                if (isSelected) UI::SetItemDefaultFocus();
            }
            UI::EndCombo();
        }
        UI::PopItemWidth();

        UI::SameLine();
        if (_UI::Button(Icons::File + " New")) {
            Create::isCreatingProfile = true;
        }
        _UI::SimpleTooltip("Create a new profile");

        UI::SameLine();
        UI::BeginDisabled(selectedIndex < 0);
        UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.65f, 0.22f, 0.22f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.80f, 0.28f, 0.28f, 1.0f));
        if (_UI::IconButton(Icons::TrashO, "DelProfile")) {
            Create::DeleteProfile(selectedIndex);
            selectedIndex = -1;
            downloadedContent = "";
            mapList.RemoveRange(0, mapList.Length);
        }
        UI::PopStyleColor(3);
        UI::EndDisabled();
        _UI::SimpleTooltip("Delete selected profile");

        UI::SameLine();
        if (_UI::IconButton(Icons::Refresh, "RefreshProfiles")) {
            Create::RefreshFileList();
            if (selectedIndex >= int(Create::jsonFileNames.Length)) {
                selectedIndex = -1;
                mapList.RemoveRange(0, mapList.Length);
            }
        }
        _UI::SimpleTooltip("Refresh profile list");

        UI::SameLine();
        if (selectedIndex >= 0) {
            UI::TextDisabled("(" + mapList.Length + " maps)");
        }

        UI::Dummy(vec2(0, 2));
        if (UI::CollapsingHeader(Icons::Download + " Download from URL")) {
            UI::Dummy(vec2(0, 2));
            UI::TextDisabled("Paste a direct link to a .json profile file.");
            UI::SetNextItemWidth(-1);
            downloadUrl = UI::InputText("##ProfileURL", downloadUrl);
            UI::Dummy(vec2(0, 2));
            UI::BeginDisabled(downloadUrl.Length == 0);
            if (_UI::Button(Icons::Download + " Download Profile")) {
                Create::StartDownload(downloadUrl);
            }
            UI::EndDisabled();
            UI::Dummy(vec2(0, 2));
        }

        if (_UI::Button(Icons::Folder + " Downloaded")) {
            _IO::OpenFolder(Server::specificDownloadedJsonFilesDirectory);
        }
        UI::SameLine();
        if (_UI::Button(Icons::Folder + " Created")) {
            _IO::OpenFolder(Server::specificDownloadedCreatedProfilesDirectory);
        }

        UI::Separator();
        UI::Dummy(vec2(0, 4));


        if (selectedIndex < 0) {
            UI::TextDisabled("Select a profile to view its maps.");
        } else if (mapList.Length == 0) {
            UI::TextDisabled("No maps found in this profile.");
        } else {
            recordOffset = UI::InputInt("Rank", recordOffset);
            int recordRank = NormalizeRankInput(recordOffset);

            UI::Dummy(vec2(0, 2));
            if (_UI::Button(Icons::Download + " Load All (" + mapList.Length + " maps)")) {
                for (uint li = 0; li < mapList.Length; li++) {
                    string uid = "";
                    if (mapList[li].HasKey("mapUid")) uid = string(mapList[li]["mapUid"]);
                    if (uid.Length > 0) {
                        loadRecord.LoadRecordFromMapUid(uid, tostring(recordRank), "OtherMaps", "", "");
                    }
                }
            }
            _UI::SimpleTooltip("Load ghost at rank " + recordRank + " for every map in this profile. 0 or negative also loads rank 1.");
            RenderHighRankLookupWarning(recordRank);

            UI::Dummy(vec2(0, 4));

            UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
            UI::AlignTextToFramePadding();
            UI::Text(Icons::Search);
            UI::SameLine();
            UI::SetNextItemWidth(-1);
            mapFilter = UI::InputText("##ProfileMapFilter", mapFilter);
            UI::PopStyleVar();
            _UI::SimpleTooltip("Filter maps by name or UID");

            UI::Dummy(vec2(0, 4));

            string filterLower = mapFilter.ToLower();

            UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(0.14f, 0.14f, 0.17f, 1.0f));
            UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 4));

            int tflags = UI::TableFlags::RowBg | UI::TableFlags::Borders | UI::TableFlags::Resizable | UI::TableFlags::ScrollY;
            if (UI::BeginTable("ProfileMaps", 4, tflags, vec2(0, 0))) {
                UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 30);
                UI::TableSetupColumn("Map Name", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("Map UID", UI::TableColumnFlags::WidthStretch);
                UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed, 120);
                UI::TableHeadersRow();

                for (uint mi = 0; mi < mapList.Length; mi++) {
                    auto map = mapList[mi];
                    string mapName = map.HasKey("mapName") ? string(map["mapName"]) : "";
                    string mapUid = map.HasKey("mapUid") ? string(map["mapUid"]) : "";

                    if (filterLower.Length > 0) {
                        if (!mapName.ToLower().Contains(filterLower) && !mapUid.ToLower().Contains(filterLower))
                            continue;
                    }

                    UI::TableNextRow();

                    UI::TableNextColumn();
                    UI::TextDisabled("" + (mi + 1));

                    UI::TableNextColumn();
                    UI::Text(mapName.Length > 0 ? mapName : "-");

                    UI::TableNextColumn();
                    if (mapUid.Length > 0) {
                        string shortUid = mapUid;
                        if (uint(shortUid.Length) > 20) shortUid = shortUid.SubStr(0, 20) + "...";
                        UI::TextDisabled(shortUid);
                        _UI::SimpleTooltip(mapUid);
                    } else {
                        UI::TextDisabled("-");
                    }

                    UI::TableNextColumn();
                    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

                    UI::BeginDisabled(mapUid.Length == 0);
                    if (_UI::IconButton(Icons::UserPlus, "prof_load_" + mi, vec2(28, 0))) {
                        loadRecord.LoadRecordFromMapUid(mapUid, tostring(recordRank), "OtherMaps", "", "");
                    }
                    _UI::SimpleTooltip("Load ghost at rank " + recordRank);
                    UI::EndDisabled();

                    UI::SameLine();
                    UI::BeginDisabled(mapUid.Length == 0);
                    if (_UI::IconButton(Icons::Clipboard, "prof_copy_" + mi, vec2(28, 0))) {
                        IO::SetClipboard(mapUid);
                    }
                    _UI::SimpleTooltip("Copy UID to clipboard");
                    UI::EndDisabled();

                    UI::SameLine();
                    UI::BeginDisabled(mapUid.Length == 0);
                    if (_UI::IconButton(Icons::ExternalLink, "prof_goto_" + mi, vec2(28, 0))) {
                        EntryPoints::MapUid::mapUID = mapUid;
                        g_WindowPage = WindowPage::Load;
                    }
                    _UI::SimpleTooltip("Open in Map UID tab");
                    UI::EndDisabled();

                    UI::PopStyleVar();
                }

                UI::EndTable();
            }

            UI::PopStyleVar();
            UI::PopStyleColor();
        }

        if (Create::isDownloading) {
            UI::OpenPopup("Downloading...");
        }
        if (UI::BeginPopupModal("Downloading...", Create::isDownloading, UI::WindowFlags::AlwaysAutoResize)) {
            UI::Text("Downloading JSON profile...");
            UI::TextDisabled("This closes automatically when complete.");
            UI::EndPopup();
        }

        if (Create::isCreatingProfile) {
            UI::OpenPopup("Create Profile");
        }
        if (UI::BeginPopupModal("Create Profile", Create::isCreatingProfile, UI::WindowFlags::AlwaysAutoResize)) {
            UI::Text("Profile Name");
            newJsonName = UI::InputText("##ProfileName", newJsonName);

            UI::Separator();
            UI::Dummy(vec2(0, 2));
            UI::Text("Maps (" + Create::newProfileMaps.Length + ")");
            UI::Dummy(vec2(0, 2));

            for (uint ci = 0; ci < Create::newProfileMaps.Length; ci++) {
                Create::newProfileMaps[ci].mapName = UI::InputText("Name##NP_Name_" + ci, Create::newProfileMaps[ci].mapName);
                UI::SameLine();
                Create::newProfileMaps[ci].mapUid = UI::InputText("UID##NP_Uid_" + ci, Create::newProfileMaps[ci].mapUid);
                UI::SameLine();
                UI::PushStyleColor(UI::Col::Button, vec4(0.50f, 0.18f, 0.18f, 0.80f));
                if (_UI::IconButton(Icons::Times, "NP_Remove_" + ci)) {
                    Create::newProfileMaps.RemoveAt(ci);
                    ci--;
                }
                UI::PopStyleColor();
            }

            UI::Dummy(vec2(0, 2));

            if (_UI::Button(Icons::Plus + " Add Map")) {
                Create::newProfileMaps.InsertLast(Create::MapEntry());
            }
            UI::SameLine();

            string curMapName = get_CurrentMapName();
            if (curMapName.Length > 0) curMapName = Text::StripFormatCodes(curMapName);
            string curMapUid = get_CurrentMapUID();
            UI::BeginDisabled(curMapUid.Length == 0);
            if (_UI::Button(Icons::Map + " Add Current Map")) {
                auto entry = Create::MapEntry();
                entry.mapName = curMapName;
                entry.mapUid = curMapUid;
                Create::newProfileMaps.InsertLast(entry);
            }
            UI::EndDisabled();
            if (curMapUid.Length > 0) {
                _UI::SimpleTooltip("Add: " + curMapName + " (" + curMapUid + ")");
            } else {
                _UI::SimpleTooltip("No map loaded");
            }

            UI::Separator();
            UI::Dummy(vec2(0, 2));

            bool canSave = newJsonName.Trim().Length > 0;
            UI::BeginDisabled(!canSave);
            if (_UI::Button(Icons::FloppyO + " Save Profile")) {
                Create::SaveNewProfile(newJsonName);
                newJsonName = "";
                Create::isCreatingProfile = false;
                Create::RefreshFileList();
                UI::CloseCurrentPopup();
            }
            UI::EndDisabled();

            UI::SameLine();
            if (_UI::Button("Cancel")) {
                Create::isCreatingProfile = false;
                UI::CloseCurrentPopup();
            }

            UI::EndPopup();
        }
    }
}
}
