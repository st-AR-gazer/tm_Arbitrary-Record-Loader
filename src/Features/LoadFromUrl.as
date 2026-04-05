namespace Features {
namespace LRFromUrl {
    string url;
    string lastStatus;
    uint lastStatusTime;

    array<string> urlHistory;
    uint MAX_URL_HISTORY = 10;

    void AddToHistory(const string &in u) {
        for (uint i = 0; i < urlHistory.Length; i++) {
            if (urlHistory[i] == u) {
                urlHistory.RemoveAt(i);
                break;
            }
        }
        urlHistory.InsertAt(0, u);
        if (urlHistory.Length > MAX_URL_HISTORY)
            urlHistory.RemoveRange(MAX_URL_HISTORY, urlHistory.Length - MAX_URL_HISTORY);
    }

    string GuessFileType(const string &in u) {
        string lower = u.ToLower();
        if (lower.EndsWith(".ghost.gbx")) return "Ghost";
        if (lower.EndsWith(".replay.gbx")) return "Replay";
        if (lower.EndsWith(".gbx")) return "Gbx (unknown type)";
        return "";
    }

    string GetFilenameFromUrl(const string &in u) {
        int lastSlash = -1;
        for (int i = u.Length - 1; i >= 0; i--) {
            if (u[i] == 0x2F) { // '/'
                lastSlash = i;
                break;
            }
        }
        if (lastSlash >= 0 && lastSlash < int(u.Length) - 1) {
            string name = u.SubStr(lastSlash + 1);
            int qMark = name.IndexOf("?");
            if (qMark >= 0) name = name.SubStr(0, qMark);
            return Net::UrlDecode(name);
        }
        return "";
    }

    void RT_LRFromUrl() {
        UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

        UI::Text(Icons::Link + " \\$fffEnter a direct URL to a ghost or replay file");
        UI::Dummy(vec2(0, 2));

        UI::SetNextItemWidth(ARL_LongInputWidth());
        url = UI::InputText("##URL", url);

        UI::Dummy(vec2(0, 2));

        if (UI::Button(Icons::Times + " Clear")) {
            url = "";
        }

        UI::SameLine();
        UI::PushStyleColor(UI::Col::Button, vec4(0.20f, 0.38f, 0.22f, 0.90f));
        UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.28f, 0.48f, 0.30f, 1.0f));
        UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.35f, 0.58f, 0.38f, 1.0f));
        UI::BeginDisabled(url.Length == 0);
        if (UI::Button(Icons::Download + " Load Ghost/Replay")) {
            AddToHistory(url);
            loadRecord.LoadRecordFromUrl(url);
            lastStatus = "\\$0f0" + Icons::Refresh + " Downloading...";
            lastStatusTime = Time::Now;
        }
        UI::EndDisabled();
        UI::PopStyleColor(3);

        if (lastStatus.Length > 0) {
            UI::SameLine();
            if (Time::Now - lastStatusTime > 5000) {
                lastStatus = "";
            } else {
                UI::Text(lastStatus);
            }
        }

        if (url.Length > 0) {
            UI::Dummy(vec2(0, 4));
            UI::PushStyleColor(UI::Col::ChildBg, vec4(0.12f, 0.12f, 0.14f, 1.0f));
            UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
            if (UI::BeginChild("ARL_UrlPreview", vec2(0, 68), true)) {
                string fileType = GuessFileType(url);
                string fileName = GetFilenameFromUrl(url);

                if (fileType == "Ghost") {
                    UI::Text("\\$aca" + Icons::SnapchatGhost + " Ghost file\\$z");
                } else if (fileType == "Replay") {
                    UI::Text("\\$cda" + Icons::Film + " Replay file\\$z");
                } else if (fileType.Length > 0) {
                    UI::Text("\\$da5" + Icons::FileO + " " + fileType + "\\$z");
                } else {
                    UI::Text("\\$f90" + Icons::ExclamationTriangle + "\\$z URL doesn't end with .Gbx");
                    UI::TextDisabled("This may not be a valid ghost/replay file.");
                }

                if (fileName.Length > 0) {
                    UI::SameLine();
                    UI::TextDisabled("  " + fileName);
                }

                string domain = "";
                if (url.StartsWith("http://") || url.StartsWith("https://")) {
                    string afterProto = url.SubStr(url.IndexOf("://") + 3);
                    int slashIdx = afterProto.IndexOf("/");
                    if (slashIdx > 0) domain = afterProto.SubStr(0, slashIdx);
                    else domain = afterProto;
                }
                if (domain.Length > 0) {
                    UI::TextDisabled(Icons::Globe + " " + domain);
                }

                UI::EndChild();
            }
            UI::PopStyleVar();
            UI::PopStyleColor();
        }

        UI::PopStyleVar();

        if (urlHistory.Length > 0) {
            UI::Dummy(vec2(0, 6));
            UI::PushStyleColor(UI::Col::Separator, vec4(0.3f, 0.3f, 0.35f, 0.5f));
            UI::Separator();
            UI::PopStyleColor();
            UI::Dummy(vec2(0, 2));

            if (UI::CollapsingHeader(Icons::ClockO + " Recent URLs (" + urlHistory.Length + ")")) {
                UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);
                UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(6, 3));

                int hflags = UI::TableFlags::RowBg | UI::TableFlags::Borders;
                if (UI::BeginTable("ARL_UrlHistory", 3, hflags)) {
                    UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, 60);
                    UI::TableSetupColumn("URL", UI::TableColumnFlags::WidthStretch);
                    UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthFixed, 70);
                    UI::TableHeadersRow();

                    for (uint hi = 0; hi < urlHistory.Length; hi++) {
                        string hUrl = urlHistory[hi];
                        string hType = GuessFileType(hUrl);
                        string hName = GetFilenameFromUrl(hUrl);

                        UI::TableNextRow();

                        UI::TableNextColumn();
                        if (UI::Button(Icons::Play + "##uh_" + hi, vec2(28, 0))) {
                            loadRecord.LoadRecordFromUrl(hUrl);
                            lastStatus = "\\$0f0" + Icons::Refresh + " Downloading...";
                            lastStatusTime = Time::Now;
                        }
                        _UI::SimpleTooltip("Load again");
                        UI::SameLine();
                        if (UI::Button(Icons::ArrowUp + "##uf_" + hi, vec2(28, 0))) {
                            url = hUrl;
                        }
                        _UI::SimpleTooltip("Fill URL field");

                        UI::TableNextColumn();
                        if (hName.Length > 0) {
                            UI::Text(hName);
                            _UI::SimpleTooltip(hUrl);
                        } else {
                            UI::Text(hUrl);
                        }

                        UI::TableNextColumn();
                        if (hType == "Ghost") {
                            UI::Text("\\$aca" + Icons::SnapchatGhost + "\\$z");
                        } else if (hType == "Replay") {
                            UI::Text("\\$cda" + Icons::Film + "\\$z");
                        } else {
                            UI::TextDisabled("?");
                        }
                    }

                    UI::EndTable();
                }
                UI::PopStyleVar(2);
            }
        }

        UI::Dummy(vec2(0, 6));
        UI::PushStyleColor(UI::Col::Separator, vec4(0.3f, 0.3f, 0.35f, 0.5f));
        UI::Separator();
        UI::PopStyleColor();
        UI::Dummy(vec2(0, 2));

        if (UI::CollapsingHeader(Icons::QuestionCircle + " Help")) {
            UI::TextDisabled("Supported file types:");
            UI::TextDisabled("  " + Icons::SnapchatGhost + "  .Ghost.Gbx  -  A single ghost recording");
            UI::TextDisabled("  " + Icons::Film + "  .Replay.Gbx  -  A replay (may contain multiple ghosts)");
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled("Where to find ghost URLs:");
            UI::TextDisabled("  " + Icons::Globe + "  Trackmania Exchange (TMX) - ghost download links");
            UI::TextDisabled("  " + Icons::Globe + "  Trackmania.io - replay download links");
            UI::TextDisabled("  " + Icons::Globe + "  Discord / community shares");
            UI::Dummy(vec2(0, 4));
            UI::TextDisabled("The URL must be a direct link to the file, not a webpage.");
        }
    }
}
}
