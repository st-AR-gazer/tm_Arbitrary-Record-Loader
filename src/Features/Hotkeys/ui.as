namespace Features {
[SettingsTab name="Hotkeys" icon="KeyboardO" order="10"]
void RenderHotkeySettings() {
    Hotkeys::RT_Hotkeys();
}

namespace Hotkeys {
    [Setting hidden]
    bool S_windowOpen = false;

    bool capturingKey = false;
    string filterText = "";
    string previewKey = "";

    bool editMode = false; 
    int editHotkeyIndex = -1;
    string editAction = "";

    bool editIsOrdered = false;
    string editComboString = "";
    int editExtraValue = -1;

    array<string> quickKeys;
    string quickAction = "";
    int quickExtraValue = 1;
    bool showQuickAdd = false; 
    bool showAdvancedAdd = false; 

    void ResetQuickAdd() {
        quickKeys.RemoveRange(0, quickKeys.Length);
        quickAction = "";
        quickExtraValue = 1;
        filterText = "";
        capturingKey = false;
        previewKey = "";
    }

    string BuildQuickComboString() {
        array<string> finalKeys;
        for (uint i = 0; i < quickKeys.Length; i++) {
            if (quickKeys[i] != "Choose key...") {
                finalKeys.InsertLast(quickKeys[i]);
            }
        }
        return string::Join(finalKeys, "+");
    }

    void RT_Hotkeys_Popout() {
        if (UI::Begin("Hotkeys", S_windowOpen)) {            
            RT_Hotkeys();
            UI::End();
        }
    }

    void RT_Hotkeys() {
        UI::Text("Existing Hotkeys:");
        array<string> actions = hotkeyMappings.GetKeys();
        if (actions.Length > 0) {
            for (uint i = 0; i < actions.Length; i++) {
                array<Hotkey@>@ hotkeysList = cast<array<Hotkey@>@>(hotkeyMappings[actions[i]]);
                for (uint j = 0; j < hotkeysList.Length; j++) {
                    Hotkey@ hotkey = hotkeysList[j];
                    string currentKeys = hotkey.get_description();

                    UI::Text(hotkey.action + ": ");
                    UI::SameLine();
                    if (UI::Button(currentKeys + "##edit" + actions[i] + "-" + j)) {
                        editMode = true;
                        editHotkeyIndex = j;
                        editAction = actions[i];
                        editIsOrdered = hotkey.isOrdered;
                        editComboString = hotkey.comboString;
                        editExtraValue = hotkey.extraValue;
                        filterText = "";
                        capturingKey = false;
                        showQuickAdd = false;
                        showAdvancedAdd = true;                        
                    }
                    UI::SameLine();
                    if (UI::Button("Remove##remove" + actions[i] + "-" + j)) {
                        RemoveHotkey(actions[i], j);
                    }
                }
            }
        } else {
            UI::TextDisabled("No hotkeys configured yet.");
        }

        UI::Dummy(vec2(0, 10));
        UI::Separator();
        UI::Dummy(vec2(0, 10));

        if (!editMode && UI::Button("Add New Hotkey")) {
            editMode = true;
            editHotkeyIndex = -1;
            editAction = "";
            editComboString = "";
            editIsOrdered = false;
            editExtraValue = -1;
            filterText = "";
            capturingKey = false;
            showQuickAdd = true;
            showAdvancedAdd = false;
            ResetQuickAdd();
        }

        if (editMode) {
            UI::Dummy(vec2(0, 10));
            UI::Text("Configure Hotkey:");
            UI::Separator();

            UI::BeginTabBar("HotkeyAddTabs");
            if (UI::BeginTabItem("Quick Add", showQuickAdd)) {
                showQuickAdd = true;
                showAdvancedAdd = false;
                RenderQuickAddTab();
                UI::EndTabItem();
            }
            if (UI::BeginTabItem("Advanced Add", showAdvancedAdd)) {
                showQuickAdd = false;
                showAdvancedAdd = true;
                RenderAdvancedAddTab();
                UI::EndTabItem();
            }
            UI::EndTabBar();
        }
    }

    void RenderQuickAddTab() {
        UI::Text("Select Action:");
        auto allActions = GetAllAvailableActions();
        if (UI::BeginCombo("##QuickSelectAction", quickAction.Length == 0 ? "Choose action..." : quickAction)) {
            for (uint i = 0; i < allActions.Length; i++) {
                if (UI::Selectable(allActions[i], allActions[i] == quickAction)) {
                    quickAction = allActions[i];
                }
            }
            UI::EndCombo();
        }

        if (quickAction == "Load X time") {
            UI::Dummy(vec2(0, 10));
            UI::Text("Specify Position:");
            quickExtraValue = Math::Clamp(UI::InputInt("Position (1 for top)", quickExtraValue), 1, 1000);
        }

        UI::Dummy(vec2(0, 10));

        UI::Text("Keys:");
        UI::TextWrapped("Add keys for a simple combo. Keys are combined with '+'. No order or alternate keys.");
        if (UI::Button("Add Key")) {
            quickKeys.InsertLast("Choose key...");
        }

        UI::Dummy(vec2(0, 5));
        for (uint i = 0; i < quickKeys.Length; i++) {
            UI::PushID("QuickKey"+i);

            UI::Text("Filter:");
            filterText = UI::InputText("##KeyFilterQuick"+i, filterText);

            array<string> allKeys = GenerateKeyList();
            array<string> filteredKeys;
            string f = filterText.ToLower();
            for (uint m = 0; m < allKeys.Length; m++) {
                if (f.Length == 0 || allKeys[m].ToLower().Contains(f)) {
                    filteredKeys.InsertLast(allKeys[m]);
                }
            }

            if (UI::BeginCombo("##QuickKeyCombo"+i, quickKeys[i])) {
                for (uint m = 0; m < filteredKeys.Length; m++) {
                    if (UI::Selectable(filteredKeys[m], filteredKeys[m] == quickKeys[i])) {
                        quickKeys[i] = filteredKeys[m];
                    }
                }
                UI::EndCombo();
            }

            UI::SameLine();
            if (UI::Button("Capture Key")) {
                capturingKey = true;
                previewKey = "Choose key...";
            }

            UI::SameLine();
            if (UI::Button("Remove Key")) {
                quickKeys.RemoveAt(i);
                UI::PopID();
                i--;
                continue;
            }

            UI::PopID();
            UI::Dummy(vec2(0, 5));
        }

        UI::Separator();
        UI::Dummy(vec2(0, 10));

        if (UI::Button(editHotkeyIndex == -1 ? "Add Hotkey" : "Update Hotkey")) {
            if (quickAction.Length > 0) {
                string combo = BuildQuickComboString();
                if (combo.Length > 0) {
                    bool ordered = false;
                    if (editHotkeyIndex == -1) {
                        RegisterHotkey(quickAction, combo, ordered, quickAction == "Load X time" ? quickExtraValue : -1);
                    } else {
                        UpdateHotkey(quickAction, editHotkeyIndex, combo, ordered, quickAction == "Load X time" ? quickExtraValue : -1);
                    }
                    editMode = false;
                    showQuickAdd = false;
                }
            }
        }
        UI::SameLine();
        if (UI::Button("Cancel")) {
            editMode = false;
            editHotkeyIndex = -1;
            showQuickAdd = false;
        }
    }

    void RenderAdvancedAddTab() {
        UI::Text("Action:");
        auto allActions = GetAllAvailableActions();
        if (UI::BeginCombo("##SelectAction", editAction.Length == 0 ? "Choose action..." : editAction)) {
            for (uint i = 0; i < allActions.Length; i++) {
                if (UI::Selectable(allActions[i], allActions[i] == editAction)) {
                    editAction = allActions[i];
                }
            }
            UI::EndCombo();
        }

        if (editAction == "Load X time") {
            UI::Dummy(vec2(0, 10));
            UI::Text("Specify Position:");
            editExtraValue = Math::Clamp(UI::InputInt("Position (1 for top)", editExtraValue <= 0 ? 1 : editExtraValue), 1, 1000);
        }

        UI::Dummy(vec2(0, 10));

        editIsOrdered = UI::Checkbox("Ordered Combo", editIsOrdered);

        UI::Text("Enter Combo String (use '|' for alternate keys):");
        editComboString = UI::InputText("##ComboString", editComboString);

        UI::TextWrapped("Instructions:\n- Use '>' to separate ordered steps.\n- Use '+' for multiple keys at once.\n- Use '|' for alternate keys.\nExamples:\nNo order: 'K|T+Numpad3'\nOrder: 'X > Y > Z+W'");

        UI::Separator();
        UI::Text("Key Helper:");
        UI::TextWrapped("Use this helper to find and insert keys into your combo. After selecting or capturing a key, press 'Add Key to Combo' to append it at the end.");

        UI::Text("Filter:");
        filterText = UI::InputText("##AdvancedKeyFilter", filterText);

        array<string> allKeys = GenerateKeyList();
        array<string> filteredKeys;
        string f = filterText.ToLower();
        for (uint m = 0; m < allKeys.Length; m++) {
            if (f.Length == 0 || allKeys[m].ToLower().Contains(f)) {
                filteredKeys.InsertLast(allKeys[m]);
            }
        }

        if (UI::BeginCombo("##AdvancedKeyCombo", previewKey.Length == 0 ? "Choose key..." : previewKey)) {
            for (uint m = 0; m < filteredKeys.Length; m++) {
                if (UI::Selectable(filteredKeys[m], filteredKeys[m] == previewKey)) {
                    previewKey = filteredKeys[m];
                }
            }
            UI::EndCombo();
        }
        UI::SameLine();
        if (UI::Button("Capture Key")) {
            capturingKey = true;
            previewKey = "Choose key...";
        }

        if (previewKey.Length > 0 && previewKey != "Choose key...") {
            if (UI::Button("Add Key to Combo")) {
                if (editComboString.Length > 0 && !editComboString.EndsWith("+") && !editComboString.EndsWith(">") && !editComboString.EndsWith("|")) {
                    editComboString += "+";
                }
                editComboString += previewKey;
            }
        }

        UI::Dummy(vec2(0, 10));

        if (UI::Button(editHotkeyIndex == -1 ? "Add Hotkey" : "Update Hotkey")) {
            if (editAction.Length > 0 && editComboString.Length > 0) {
                if (editHotkeyIndex == -1) {
                    RegisterHotkey(editAction, editComboString, editIsOrdered, editAction == "Load X time" ? editExtraValue : -1);
                } else {
                    UpdateHotkey(editAction, editHotkeyIndex, editComboString, editIsOrdered, editAction == "Load X time" ? editExtraValue : -1);
                }
                editMode = false;
                showAdvancedAdd = false;
            }
        }
        UI::SameLine();
        if (UI::Button("Cancel")) {
            editMode = false;
            editHotkeyIndex = -1;
            showAdvancedAdd = false;
        }
    }

    UI::InputBlocking HandleCapturingKeyPress(bool down, VirtualKey key) {
        if (capturingKey && down) {
            string captured = tostring(key);
            if (showQuickAdd) {
                for (uint i = 0; i < quickKeys.Length; i++) {
                    if (quickKeys[i] == "Choose key...") {
                        quickKeys[i] = captured;
                        break;
                    }
                }
            } else if (showAdvancedAdd) {
                previewKey = captured;
            }

            capturingKey = false;
            return UI::InputBlocking::Block;
        }
        return UI::InputBlocking::DoNothing;
    }
}
}