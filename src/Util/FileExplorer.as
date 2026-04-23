//    _____   _          ______              _
//   |  ___(_) |        |  ____\            | |
//   | |_   _| | ___    | |___ __  __ _____ | | ___  _ __  ___  _ __ 
//   |  _| | | |/ _ \   |  __| \ \/ /| ___ \| |/ _ \| '__|/ _ \| '__|
//   | |   | | |  __/   | |____ >  < | |_/ /| | (_) | |  |  __/| | 
//   \_|   |_|_|\___|   \_____ /_/\_\| ___/ |_|\___/|_|   \___||_|
//                                   | |
//                                   |_|
//                                                                     
//   FILE EXPLORER for AngelScript
//   Version 0.1.0
//   https://github.com/st-AR-gazer/_file-explorer
//
//   Made with ❤️ by ar (AR / ar...... / AR_-_ / .ar / A---------ar / st-AR-gazer) 
//   for use in Trackmania Plugins using Openplanet and AngelScript
//   
//   License: The Unilicence
//   (Though if you want to credit me, that'd be nice :])

// Required Openplanet version 1.26.32

/** 
 * IMPORTANT:
 * This file is meant to be used together with "logging.as" as this contains that logging functionality needed to make custom 
 * log messages work properly. If you do not want to include this, please ctrl + h (or ctrl + f and click the dropdown) and add: 
 * ` log\("([^"]*)",\s*LogLevel::(Error|Warn|[A-Za-z]+),.* ` to find, and add ` ${2/^(Error|Warn)$/(?1error:warn)/trace}("$1") ` 
 * to replace, this will convert all the fancy log messages to normal 'trace'/'warn'/'error' messages. 
 * NOTE: You must also enable 'regex search' for this find/replace to work. (In vscode this can be done by pressing ctrl + f 
 * and selecting the |.*| icon in the search bar)
 */

/**
 * IMPORTANT:
 * Any changes not made by me (ar) will not (necessarily) be documented here. Please refer to any external sources the 
 * other developer has linked.
 */

/**
 * How to Integrate and Use the FileExplorer:
 * 
 * To integrate the FileExplorer into your plugin, follow the steps below:
 * 
 * 1. **Include the FileExplorer Script:**
 *    Add the FileExplorer script file to your plugin's folder. This script will handle all the file exploration 
 *    functionalities required in your plugin.
 * 
 * 2. **Render the FileExplorer:**
 *    To ensure the FileExplorer renders correctly, you must add the `FILE_EXPLORER_BASE_RENDERER()` function to the start 
 *    of your plugin's main render loop. This is usually either one of the the `Render()` or `RenderInterface()` functions. 
 *    
 *    Example:
 *    ```angelscript
 *    void RenderInterface() {
 *        FILE_EXPLORER_BASE_RENDERER();  // This ensures the FileExplorer is rendered properly.
 *    }
 *    ```
 * 
 * 3. **Open the FileExplorer:**
 *    To display the FileExplorer UI and allow users to select elements, you should call the `FileExplorer::fe_Start()` 
 *    function. This function configures and opens the FileExplorer based on the parameters you provide.
 *    
 *    Example:
 *    ```angelscript
 *    void OpenFileExplorerExample() {
 *        FileExplorer::fe_Start(
 *            "Local Files",                       // Unique session ID
 *            true,                                // _mustReturn: Require the user to select and return elements
 *            "path",                              // _returnType: "path" or "ElementInfo"
 *            vec2(1, -1),                         // _minmaxReturnAmount: Minimum and maximum number of selections
 *            IO::FromUserGameFolder("Replays/"),  // _path: The initial folder path to open
 *            "",                                  // _searchQuery: Optional search query to filter the elements (based on name)
 *            { "replay", "ghost" },               // _filters: File type filters (e.g., "replay" to show only replay files) (based on file extension)
 *            { "replay", "ghost" }                // _canOnlyReturn: The exported file must be of these types (e.g., "replay" to only allow replay files)
 *        );
 *    }
 *    ```
 *    This example opens the FileExplorer in the "Replays/" folder and filters to show only replay and ghost files.
 *    
 *    **Note:** The FileExplorer will close itself automatically when the user has selected the required files/elements 
 *    and clicks the "Return Selected Paths/Elements" button. This also locks that specific FileExplorer instance until
 *    the selected data is retrieved externally or for a set amount of frames (default: 150).
 * 
 * 4. **Retrieve Selected Data Externally:**
 *    After the user has made a selection and the FileExplorer has closed, you should retrieve the selected data externally 
 *    using the `fe_GetExplorerById` function.
 *    
 *    Example:
 *    ```angelscript
 *    // Global or appropriately scoped variable to store selected data
 *    array<string> selectedFiles;
 *    array<ElementInfo@> selectedElements;
 *    
 *    void SomeRenderFunction() {
 *        if (UI::Button(Icons::FolderOpen + " Open File Explorer")) {
 *            FileExplorer::fe_Start(
 *                "Local Files",                       // Unique session ID
 *                true,                                // _mustReturn: Require selection
 *                "path",                              // _returnType: "path" or "ElementInfo"
 *                vec2(1, -1),                         // _minmaxReturnAmount: Min and max selections
 *                IO::FromUserGameFolder("Replays/"),  // _path: Initial folder path
 *                "",                                  // _searchQuery: Optional search query
 *                { "replay", "ghost" },               // _filters: File type filters
 *                { "replay", "ghost" }                // _canOnlyReturn: Allowed types for export
 *            );
 *        }
 *        
 *        FileExplorer@ explorer = FileExplorer::fe_GetExplorerById("Local Files");
 *        if (explorer !is null && explorer.exports.IsSelectionComplete()) {
 *            array<ElementInfo@>@ elements = explorer.exports.GetSelectedElements();
 *            if (elements !is null) {
 *                selectedElements = elements;
 *            }
 *        }
 * 
 *        if (selectedElements.Length > 0) {
 *            UI::Text("Selected Elements: " + selectedElements.Length);
 *            for (uint i = 0; i < selectedElements.Length; i++) {
 *                ElementInfo@ elem = selectedElements[i];
 *                UI::PushItemWidth(1100);
 *                UI::InputText("Element Name " + (i + 1), elem.name);
 *                UI::InputText("Element Path " + (i + 1), elem.path);
 *                UI::PopItemWidth();
 *            }
 *        }
 * 
 *        // and if you only want to get the paths you can do this instead:
 * 
 *        if (UI::Button(Icons::FolderOpen + " Open File Explorer")) {
 *            FileExplorer::fe_Start(
 *                "Local Files",                       // Unique session ID
 *                true,                                // _mustReturn: Require selection
 *                "path",                              // _returnType: "path" or "ElementInfo"
 *                vec2(1, -1),                         // _minmaxReturnAmount: Min and max selections
 *                IO::FromUserGameFolder("Replays/"),  // _path: Initial folder path
 *                "",                                  // _searchQuery: Optional search query
 *                { "replay", "ghost" },               // _filters: File type filters
 *                { "replay", "ghost" }                // _canOnlyReturn: Allowed types for export
 *            );
 *        }
 *        
 *        FileExplorer@ explorer = FileExplorer::fe_GetExplorerById("Local Files");
 *        if (explorer !is null && explorer.exports.IsSelectionComplete()) {
 *            array<string>@ paths = explorer.exports.GetSelectedPaths();
 *            if (paths !is null) {
 *                selectedFiles = paths;
 *            }
 *        }
 *    
 *        if (selectedFiles.Length > 0) {
 *            UI::Text("Selected Files: " + selectedFiles.Length);
 *            for (uint i = 0; i < selectedFiles.Length; i++) {
 *                UI::PushItemWidth(1100);
 *                selectedFiles[i] = UI::InputText("File Path " + (i + 1), selectedFiles[i]);
 *                UI::PopItemWidth();
 *            }
 *        }
 *    }
 *    ```
 *    
 *    **Explanation:**
 *    - **Opening the FileExplorer:**
 *      - The "Open File Explorer" button initiates the FileExplorer with a unique session ID ("Local Files") and specifies the return type ("path" or "ElementInfo").
 *    
 *    - **Retrieving the Explorer Instance:**
 *      - `fe_GetExplorerById("Local Files")` retrieves the specific `FileExplorer` instance associated with the session ID.
 *      - It checks if the selection is complete using `explorer.exports.IsSelectionComplete()`.
 *    
 *    - **Processing the Exported Data:**
 *      - Depending on the `returnType`, it retrieves either the selected paths or `ElementInfo` objects.
 *      - The selected data is stored in `selectedFiles` or `selectedElements` arrays for further processing.
 *    
 *    - **Resetting Selection:**
 *      - After processing set the selection to be complete so that the explorer is imediatly cleared (if this is not done it will automatically be cleared after 150 frames).
 * 
 * 5. **Handling Multiple FileExplorer Instances:**
 *    If your plugin requires multiple FileExplorer instances simultaneously, ensure each has a unique session ID when calling `fe_Start()`. Retrieve and handle each instance separately using their respective session IDs.
 *    
 *    Example:
 *    ```angelscript
 *    void OpenMultipleExplorers() {
 *        FileExplorer::fe_Start(
 *            "Replays Explorer",
 *            true,
 *            "path",
 *            vec2(1, -1),
 *            IO::FromUserGameFolder("Replays/"),
 *            "",
 *            { "replay" },
 *            { "replay" }
 *        );
 *    
 *        FileExplorer::fe_Start(
 *            "Ghosts Explorer",
 *            true,
 *            "ElementInfo",
 *            vec2(1, -1),
 *            IO::FromUserGameFolder("Ghosts/"),
 *            "",
 *            { "ghost" },
 *            { "ghost" }
 *        );
 *    }
 *    
 *    void HandleMultipleExports() {
 *        FileExplorer@ replaysExplorer = FileExplorer::fe_GetExplorerById("Replays Explorer");
 *        if (replaysExplorer !is null && replaysExplorer.exports.IsSelectionComplete()) {
 *            array<string>@ replayPaths = replaysExplorer.exports.GetSelectedPaths();
 *            if (replayPaths !is null) {
 *                // Process replay paths
 *            }
 *            replaysExplorer.exports.selectionComplete = false;
 *        }
 *    
 *        // Handle Ghosts Explorer
 *        FileExplorer@ ghostsExplorer = FileExplorer::fe_GetExplorerById("Ghosts Explorer");
 *        if (ghostsExplorer !is null && ghostsExplorer.exports.IsSelectionComplete()) {
 *            array<ElementInfo@>@ ghostElements = ghostsExplorer.exports.GetSelectedElements();
 *            if (ghostElements !is null) {
 *                // Process ghost ElementInfo objects
 *            }
 *            ghostsExplorer.exports.selectionComplete = false;
 *        }
 *    }
 *    ```
 * 
 * 6. **Advanced Handling of `ElementInfo` Objects:**
 *    When using `returnType` as `"ElementInfo"`, you can access various metadata associated with each element. This allows for more detailed processing based on the selected elements' properties.
 *    
 *    Example:
 *    ```angelscript
 *    void ProcessSelectedElements() {
 *        FileExplorer@ explorer = FileExplorer::fe_GetExplorerById("ElementInfo Session");
 *        if (explorer !is null && explorer.exports.IsSelectionComplete()) {
 *            array<ElementInfo@>@ elements = explorer.exports.GetSelectedElements();
 *            if (elements !is null) {
 *                for (uint i = 0; i < elements.Length; i++) {
 *                    ElementInfo@ elem = elements[i];

 *                    string name = elem.name;
 *                    string path = elem.path;
 *                    string type = elem.type;

 *                    print("Element Name: " + name + ", Path: " + path + ", Type: " + type);
 *                }
 *            }
 *            explorer.exports.selectionComplete = false;
 *        }
 *    }
 *    ```
 * 
 * 7. **Summary:**
 * - **Rendering:** Add `FILE_EXPLORER_BASE_RENDERER()` to your rendering pipeline (usially the `Render()` or `RenderInterface()` method).
 * - **Opening:** Use `FileExplorer::fe_Start()` with a unique session ID and specify the `returnType` ("path" or "ElementInfo").
 * - **Export Handling:** Retrieve the specific `FileExplorer` instance using `fe_GetExplorerById(sessionId)` and process the exported data externally.
 * - **Multiple Instances:** Assign unique session IDs for handling multiple FileExplorer instances concurrently.
 * - **Advanced Usage:** Leverage `ElementInfo` objects for detailed metadata handling when `returnType` is set to `"ElementInfo"`.
 * 
 * With these steps, the FileExplorer will be fully integrated into your plugin, allowing users to easily navigate directories and select files or elements with relative ease.
 * 
 * 
 * **NOTE 1:**
 *
 * This is a full example implementation of how to use the FileExplorer in your plugin. This example includes all the
 * necessary steps to integrate the FileExplorer and handle the selected file paths or elements.
 * 
 *  ```angelscript
    // Global or appropriately scoped variables to store selected data
    array<string> selectedFiles;
    array<ElementInfo@> selectedElements;

    void RenderInterface() {
        FILE_EXPLORER_BASE_RENDERER();  // This ensures the FileExplorer is rendered properly.

        if (UI::Begin("Path explorer", true, UI::WindowFlags::AlwaysAutoResize)) {
            // Button to open the File Explorer for Paths
            if (UI::Button(Icons::FolderOpen + " Open File Explorer")) {
                FileExplorer::fe_Start(
                    "Local Files",                       // Unique session ID
                    true,                                // _mustReturn: Require selection
                    "path",                              // _returnType: "path" or "ElementInfo"
                    vec2(1, -1),                         // _minmaxReturnAmount: Min and max selections
                    IO::FromUserGameFolder("Replays/"),  // _path: Initial folder path
                    "",                                  // _searchQuery: Optional search query
                    { "replay", "ghost" },               // _filters: File type filters
                    { "replay", "ghost" }                // _canOnlyReturn: Allowed types for export
                );
            }

            // Button to open the File Explorer for ElementInfo
            if (UI::Button(Icons::Info + " Open Element Explorer")) {
                FileExplorer::fe_Start(
                    "ElementInfo Session",               // Unique session ID
                    true,                                // _mustReturn: Require selection
                    "ElementInfo",                       // _returnType: "path" or "ElementInfo"
                    vec2(1, -1),                         // _minmaxReturnAmount: Min and max selections
                    IO::FromUserGameFolder("Replays/"),  // _path: Initial folder path
                    "",                                  // _searchQuery: Optional search query
                    { "replay", "ghost" },               // _filters: File type filters
                    { "replay", "ghost" }                // _canOnlyReturn: Allowed types for export
                );
            }

            // Handle Path Selection
            auto pathExplorer = FileExplorer::fe_GetExplorerById("Local Files");
            if (pathExplorer !is null && pathExplorer.exports.IsSelectionComplete()) {
                auto paths = pathExplorer.exports.GetSelectedPaths();
                if (paths !is null) {
                    selectedFiles = paths;
                    // Additional processing if needed
                }
                pathExplorer.exports.SetSelectionComplete();
            }


            // IMPORTANT: When creating "auto elements" it's important to use "array<FileExplorer::ElementInfo> elements;" auto does not work in this case when in the global namespace.
            // Handle ElementInfo Selection
            auto elementExplorer = FileExplorer::fe_GetExplorerById("ElementInfo Session");
            if (elementExplorer !is null && elementExplorer.exports.IsSelectionComplete()) {
                auto elements = elementExplorer.exports.GetSelectedElements();
                if (elements !is null) {
                    selectedElements = elements;
                    // Optionally, extract paths or handle ElementInfo objects as needed
                }
                elementExplorer.exports.SetSelectionComplete();
            }

            // Display selected file paths
            if (selectedFiles.Length > 0) {
                UI::Text("Selected Files: " + selectedFiles.Length);
                for (uint i = 0; i < selectedFiles.Length; i++) {
                    UI::PushItemWidth(1100);
                    selectedFiles[i] = UI::InputText("File Path " + (i + 1), selectedFiles[i]);
                    UI::PopItemWidth();
                }
            }

            // Display selected ElementInfo objects
            if (selectedElements.Length > 0) {
                UI::Text("Selected Elements: " + selectedElements.Length);
                for (uint i = 0; i < selectedElements.Length; i++) {
                    ElementInfo@ elem = selectedElements[i];
                    UI::PushItemWidth(1100);
                    UI::InputText("Element Name " + (i + 1), elem.name);
                    UI::InputText("Element Path " + (i + 1), elem.path);
                    UI::PopItemWidth();
                }
            }

            UI::End();
        }
    }
 *  ```
 */


/*

    TODO: 
        - Add support for multiple tabs (not planned)

    FIXME: 
        
*/

namespace FileExplorer {
    // bool showInterface = false;
    // FileExplorer@ explorer;

    // ONLY CHANGE THIS IF A DESTRUCTIVE CHANGE IS MADE TO THE FILE EXPLORER SAVE FILE FORMAT, IDEALY 
    // THIS SHOULD NEVER 'CHANGE', JUST BE ADDED TOO, BUT FOR SOME FUTURE PROOFING, THIS WAS ADDED...
    const int FILE_EXPLORER_SETTINGS_VERSION = 1;

    // Change this if you need more than 150 yield calls to get the file explorer information (shouldn't ever be needed, but nice to know I guess xdd)
    const int FILE_EXPLORER_EXPORT_YIELD_AMOUNT = 150;


    class InstanceConfig {
        // Passed to settings
        string id;
        bool mustReturn;
        string returnType; // "path" or "ElementInfo"
        vec2 minMaxReturnAmount;
        string path;
        string searchQuery;
        array<string> filters;
        array<string> canOnlyReturn;

        // Reset on each start
        dictionary activeFilters;
        array<string> selectedPaths;
        array<ElementInfo@> selectedElements;

        InstanceConfig() {
            id = "";
            mustReturn = false;
            returnType = "path";
            path = "/";
            searchQuery = "";
            filters = array<string>();
            canOnlyReturn = array<string>();

            activeFilters = dictionary();
            selectedPaths = array<string>();
            selectedElements = array<ElementInfo@>();
        }

        bool IsFilterActive(const string &in filter) const {
            bool isActive = true;
            if (activeFilters.Exists(filter)) {
                activeFilters.Get(filter, isActive);
            }
            return isActive;
        }

        void ToggleFilterActive(const string &in filter) {
            bool isActive = IsFilterActive(filter);
            activeFilters.Set(filter, !isActive);
        }
        
        void ClearSelections() {
            selectedPaths.Resize(0);
            selectedElements.Resize(0);
        }
    }
    
    class Config {
        FileExplorer@ explorer;
        Utils@ utils;

        // Internal settings
        array<string> pinnedElements;

        // Internal color
        vec4 validFileColor = vec4(1, 1, 1, 1);           // Default: White
        vec4 invalidFileColor = vec4(0.4, 0.4, 0.4, 1);   // Default: Gray
        vec4 validFolderColor = vec4(1, 1, 1, 1);         // Default: White
        vec4 invalidFolderColor = vec4(0.4, 0.4, 0.4, 1); // Default: Gray

        // UI-related settings
        int maxElementsPerPage = 30;
        int fileNameDisplayOption = 0; // 0: Default, 1: No Formatting, 2: ManiaPlanet Formatting
        int searchBarPadding = 0;
        bool hideFiles = false;
        bool hideFolders = false;
        bool enablePagination = false;
        bool recursiveSearch = false;
        bool useExtraWarningWhenDeleting = true;
        bool enableSearchBar = true;
        bool sortingAscending = true;
        bool sortFoldersBeforeFiles = true;
        dictionary columnsToShow;

        int recursiveSearchBatchSize = 7;
        array<string> blacklistedRecursiveSearchPaths;

        SortingCriteria sortingCriteria = SortingCriteria::name;

        /*const*/ string settingsDirectory = IO::FromDataFolder("Plugin_FileExplorer");
        /*const*/ string settingsFilePath = Path::Join(settingsDirectory, "FileExplorerSettings.json");

        Config(FileExplorer@ fe) {
            @explorer = fe;
            @utils = fe.utils;

            if (!IO::FileExists(settingsFilePath)) {
                columnsToShow.Set("ico", true);
                columnsToShow.Set("name", true);
                columnsToShow.Set("type", true);
                columnsToShow.Set("size", true);
                columnsToShow.Set("lastModified", true);
                columnsToShow.Set("createdDate", true);
            }

            if (!IO::FolderExists(settingsDirectory)) {
                IO::CreateFolder(settingsDirectory);
            }
            if (!IO::FileExists(settingsFilePath)) {
                SaveSharedSettings();
            }

            Json::Value settings = LoadSharedSettings();

            if (settings.HasKey("PinnedElements")) {
                Json::Value pins = settings["PinnedElements"];
                pinnedElements.Resize(pins.Length);
                for (uint i = 0; i < pins.Length; i++) {
                    pinnedElements[i] = pins[i];
                }
            }
            if (settings.HasKey("HideFiles")) { hideFiles = settings["HideFiles"]; }
            if (settings.HasKey("HideFolders")) { hideFolders = settings["HideFolders"]; }
            if (settings.HasKey("EnablePagination")) { enablePagination = settings["EnablePagination"]; }
            if (settings.HasKey("UseExtraWarningWhenDeleting")) { useExtraWarningWhenDeleting = settings["UseExtraWarningWhenDeleting"]; }
            if (settings.HasKey("RecursiveSearch")) { recursiveSearch = settings["RecursiveSearch"]; }

            if (settings.HasKey("FileNameDisplayOption")) { fileNameDisplayOption = settings["FileNameDisplayOption"]; }
            if (settings.HasKey("ColumnsToShow")) {
                Json::Value cols = settings["ColumnsToShow"];
                for (uint i = 0; i < cols.GetKeys().Length; i++) {
                    string col = cols.GetKeys()[i];
                    columnsToShow.Set(col, bool(cols[col]));
                }
            }
            if (settings.HasKey("MaxElementsPerPage")) { maxElementsPerPage = settings["MaxElementsPerPage"]; }
            if (settings.HasKey("SearchBarPadding")) { searchBarPadding = settings["SearchBarPadding"]; }
            if (settings.HasKey("EnableSearchBar")) { enableSearchBar = settings["EnableSearchBar"]; }
            if (settings.HasKey("SortingCriteria")) { sortingCriteria = utils.StringToSortingCriteria(settings["SortingCriteria"]); }
            if (settings.HasKey("SortingAscending")) { sortingAscending = settings["SortingAscending"]; }
            if (settings.HasKey("SortFoldersBeforeFiles")) { sortFoldersBeforeFiles = settings["SortFoldersBeforeFiles"]; }
            if (settings.HasKey("ValidFileColor")) { validFileColor = StringToVec4(settings["ValidFileColor"]); }
            if (settings.HasKey("InvalidFileColor")) { invalidFileColor = StringToVec4(settings["InvalidFileColor"]); }
            if (settings.HasKey("ValidFolderColor")) { validFolderColor = StringToVec4(settings["ValidFolderColor"]); }
            if (settings.HasKey("InvalidFolderColor")) { invalidFolderColor = StringToVec4(settings["InvalidFolderColor"]); }

            if (settings.HasKey("RecursiveSearchBatchSize")) { recursiveSearchBatchSize = settings["RecursiveSearchBatchSize"]; }

            if (settings.HasKey("BlacklistedRecursiveSearchPaths")) {
                Json::Value blacklistedPaths = settings["BlacklistedRecursiveSearchPaths"];

                for (uint i = 0; i < blacklistedPaths.Length; i++) {
                    blacklistedRecursiveSearchPaths.InsertLast(blacklistedPaths[i]);
                }
            }
        }

        Json::Value LoadSharedSettings() {
            if (!IO::FolderExists(settingsDirectory)) {
                IO::CreateFolder(settingsDirectory);
            }

            if (IO::FileExists(settingsFilePath)) {
                string jsonString = utils.ReadFileToEnd(settingsFilePath);
                Json::Value settings = Json::Parse(jsonString);

                bool foundVersion = false;

                for (uint i = 0; i < settings.Length; i++) {
                    Json::Value versionedSettings = settings[i];

                    if (versionedSettings.HasKey("version") && versionedSettings["version"] == FILE_EXPLORER_SETTINGS_VERSION) {
                        foundVersion = true;
                        return versionedSettings["settings"];
                    }
                }

                if (!foundVersion) {
                    log("Settings version mismatch or not found. Settings cannot be loaded.", LogLevel::Error, 547, "ClearSelections");
                }
            }

            return Json::Object();
        }

        void SaveSharedSettings() {
            if (!IO::FolderExists(settingsDirectory)) {
                IO::CreateFolder(settingsDirectory);
            }

            Json::Value settings = Json::Array();
            bool versionExists = false;
            for (uint i = 0; i < settings.Length; i++) {
                if (settings[i].HasKey("version") && settings[i]["version"] == FILE_EXPLORER_SETTINGS_VERSION) {
                    versionExists = true;

                    Json::Value explorerSettings = settings[i]["settings"];
                    explorerSettings = GetCurrentSettings();
                    settings[i]["settings"] = explorerSettings;
                    break;
                }
            }

            if (!versionExists) {
                Json::Value newVersion = Json::Object();
                newVersion["version"] = FILE_EXPLORER_SETTINGS_VERSION;
                newVersion["settings"] = GetCurrentSettings();
                settings.Add(newVersion);
            }

            utils.WriteFile(settingsFilePath, Json::Write(settings));
        }

        Json::Value GetCurrentSettings() {
            Json::Value explorerSettings = Json::Object();

            Json::Value pins = Json::Array();
            for (uint i = 0; i < pinnedElements.Length; i++) {
                pins.Add(pinnedElements[i]);
            }
            explorerSettings["PinnedElements"] = pins;

            explorerSettings["HideFiles"] = hideFiles;
            explorerSettings["HideFolders"] = hideFolders;
            explorerSettings["EnablePagination"] = enablePagination;
            explorerSettings["UseExtraWarningWhenDeleting"] = useExtraWarningWhenDeleting;
            explorerSettings["RecursiveSearch"] = recursiveSearch;
            explorerSettings["FileNameDisplayOption"] = fileNameDisplayOption;

            Json::Value cols = Json::Object();
            array<string> colKeys = columnsToShow.GetKeys();
            for (uint i = 0; i < colKeys.Length; i++) {
                string col = colKeys[i];
                bool value = false;
                columnsToShow.Get(col, value);
                cols[col] = value;
            }
            explorerSettings["ColumnsToShow"] = cols;

            explorerSettings["MaxElementsPerPage"] = maxElementsPerPage;
            explorerSettings["SearchBarPadding"] = searchBarPadding;
            explorerSettings["EnableSearchBar"] = enableSearchBar;
            explorerSettings["SortingCriteria"] = utils.SortingCriteriaToString(sortingCriteria);
            explorerSettings["SortingAscending"] = sortingAscending;
            explorerSettings["SortFoldersBeforeFiles"] = sortFoldersBeforeFiles;

            explorerSettings["ValidFileColor"] = Vec4ToString(validFileColor);
            explorerSettings["InvalidFileColor"] = Vec4ToString(invalidFileColor);
            explorerSettings["ValidFolderColor"] = Vec4ToString(validFolderColor);
            explorerSettings["InvalidFolderColor"] = Vec4ToString(invalidFolderColor);

            explorerSettings["RecursiveSearchBatchSize"] = recursiveSearchBatchSize;

            Json::Value blacklistedPaths = Json::Array();
            for (uint i = 0; i < blacklistedRecursiveSearchPaths.Length; i++) {
                blacklistedPaths.Add(blacklistedRecursiveSearchPaths[i]);
            }
            explorerSettings["BlacklistedRecursiveSearchPaths"] = blacklistedPaths;

            return explorerSettings;
        }

        void ResetSettings() {
            IO::Delete(settingsFilePath);
        }

        void ToggleColumnVisibility(const string &in columnName) {
            if (columnsToShow.Exists(columnName)) {
                bool isVisible;
                columnsToShow.Get(columnName, isVisible);
                columnsToShow.Set(columnName, !isVisible);
            }
        }

        bool IsColumnVisible(const string &in columnName) const {
            if (columnsToShow.Exists(columnName)) {
                bool isVisible;
                columnsToShow.Get(columnName, isVisible);
                return isVisible;
            }
            return false;
        }

        string Vec4ToString(vec4 color) {
            return color.x + "," + color.y + "," + color.z + "," + color.w;
        }

        vec4 StringToVec4(const string &in colorStr) {
            array<string> parts = colorStr.Split(",");
            if (parts.Length == 4) {
                return vec4(Text::ParseFloat(parts[0]), Text::ParseFloat(parts[1]), Text::ParseFloat(parts[2]), Text::ParseFloat(parts[3]));
            }
            return vec4(1, 1, 1, 1);
        }
    }

    enum SortingCriteria {
        nameIgnoreFileFolder,
        name,
        size,
        lastModified,
        createdDate
    }

    enum _Icon {
        folder,
        folderOpen,
        file,
        fileText,
        filePdf,
        fileWord,
        fileExcel,
        filePowerpoint,
        fileImage,
        fileArchive,
        fileAudio,
        fileVideo,
        fileCode,
        fileEpub
    }

    class Exports {
        bool selectionComplete = false;
        array<string> selectedPaths;
        array<ElementInfo@> selectedElements;

        FileExplorer@ explorer;
        Utils@ utils;
        InstanceConfig@ instConfig;

        Exports(FileExplorer@ fe) {
            @explorer = fe;
            @utils = fe.utils;
            @instConfig = fe.instConfig;
        }

        bool IsSelectionComplete() {
            return selectionComplete;
        }

        array<string>@ GetSelectedPaths() {
            if (instConfig.returnType != "path") { log("Return type is not 'path'. Cannot get selected paths.", LogLevel::Warning, 710, "IsSelectionComplete"); return null; }
            
            selectionComplete = false;
            utils.TruncateSelectedPathsIfNeeded();

            explorer.MarkForDeletionCoro();

            return selectedPaths;
        }

        array<ElementInfo@>@ GetSelectedElements() {
            if (instConfig.returnType != "elementinfo") { log("Return type is not 'ElementInfo'. Cannot get selected elements.", LogLevel::Warning, 721, "IsSelectionComplete"); return null; }
            
            selectionComplete = false;
            utils.TruncateSelectedPathsIfNeeded();

            explorer.MarkForDeletionCoro();

            return selectedElements;
        }

        void SetSelectionComplete() {
            selectionComplete = true;
        }

        void SetSelectionComplete(array<string>@ paths, array<ElementInfo@>@ elements) {
            if (instConfig.returnType == "path" && paths !is null) {
                selectedPaths = paths;
            } else if (instConfig.returnType == "elementinfo" && elements !is null) {
                selectedElements = elements;
            }
            selectionComplete = true;
        }
    }
    
    // Element info is set in "GetElementInfo" in the FE class
    class ElementInfo {
        string name;
        string path;
        string size;
        int64 sizeBytes;
        string type;
        string gbxType;
        int64 lastModifiedDate;
        int64 creationDate;
        bool isFolder;
        _Icon icon;
        bool isSelected;
        uint64 lastSelectedTime;
        dictionary gbxMetadata;
        bool shouldShow;

        uint64 lastClickTime;

        ElementInfo(
                const string &in _name, 
                const string &in _path, 
                const string &in _size, 
                int64 _sizeBytes, 
                const string &in _type, 
                const string &in _gbxType,
                int64 _lastModifiedDate, 
                int64 _creationDate, 
                bool _isFolder, 
                _Icon _icon, bool _isSelected) {
            this.name = _name;
            this.path = _path;
            this.size = _size;
            this.sizeBytes = _sizeBytes;
            this.type = _type;
            this.gbxType = _gbxType;
            this.lastModifiedDate = _lastModifiedDate;
            this.creationDate = _creationDate;
            this.isFolder = _isFolder;
            this.icon = _icon;
            this.isSelected = _isSelected;
            this.lastSelectedTime = 0;
            this.shouldShow = true;
            this.lastClickTime = 0;
        }

        // Default factory constructor
        ElementInfo() {
            this.name = "";
            this.path = "";
            this.size = "";
            this.sizeBytes = 0;
            this.type = "";
            this.gbxType = "";
            this.lastModifiedDate = 0;
            this.creationDate = 0;
            this.isFolder = false;
            this.icon = _Icon::file;
            this.isSelected = false;
            this.lastSelectedTime = 0;
            this.shouldShow = true;
            this.lastClickTime = 0;
        }

        void SetGbxMetadata(dictionary@ metadata) {
            gbxMetadata = metadata;
        }

        bool opEquals(ElementInfo@ other) {
            return path == other.path;
        }
    }

    class Navigation {
        string CurrentPath;
        FileExplorer@ explorer;

        Navigation(FileExplorer@ fe) {
            @explorer = fe;
            CurrentPath = fe.instConfig.path;
        }

        void SetPath(const string &in path) {
            CurrentPath = path;
        }

        string GetPath() {
            return CurrentPath;
        }

        bool IsInRootDirectory() {
            return CurrentPath == "/" || CurrentPath == "\\";
        }

        void MoveUpOneDirectory() {
            string path = GetPath();
            log("Current path before moving up: " + path, LogLevel::Info, 841, "MoveUpOneDirectory");

            UpdateHistory(path);

            if (path.EndsWith("/") || path.EndsWith("\\")) {
                path = path.SubStr(0, path.Length - 1);
            }
            
            int lastSlash = Math::Max(path.LastIndexOf("/"), path.LastIndexOf("\\"));
            if (lastSlash > 0) {
                path = path.SubStr(0, lastSlash);
            } else {
                path = "/";
            }

            if (!path.EndsWith("/") && !path.EndsWith("\\")) {
                path += "/";
            }

            log("New path after moving up: " + path, LogLevel::Info, 860, "MoveUpOneDirectory");

            explorer.tab[0].LoadDirectory(path);
        }

        void MoveIntoSelectedDirectory() {
            ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();
            // ElementInfo@ selectedElement = explorer.ui.GetSelectedElement();

            if (selectedElement !is null && selectedElement.isFolder) {
                if (!selectedElement.path.StartsWith(GetPath())) {
                    log("Folder is not in the current folder, cannot move into it.", LogLevel::Warning, 871, "MoveIntoSelectedDirectory");
                } else {
                    UpdateHistory(selectedElement.path);
                    explorer.tab[0].LoadDirectory(selectedElement.path);
                }
            } else {
                log("No folder selected or selected element is not a folder.", LogLevel::Warning, 877, "MoveIntoSelectedDirectory");
            }
        }

        bool CanMoveUpDirectory() {
            string path = GetPath();
            if (IsInRootDirectory() || path == "" || path.Length == 3) { return false; }
                                                     // Used since C:/ D:/ E:/ etc. is three characteres long
            return true;
        }

        // History management
        array<string> History;
        int HistoryIndex = -1;
        bool NavigatingHistory = false;

        void UpdateHistory(const string &in path) {
            if (!NavigatingHistory && path != "") {
                if (HistoryIndex == -1 || History[HistoryIndex] != path) {
                    if (HistoryIndex < int(History.Length) - 1) {
                        History.Resize(HistoryIndex + 1);
                    }
                    History.InsertLast(path);
                    HistoryIndex = History.Length - 1;
                }
            }
            NavigatingHistory = false;
        }

        void NavigateBack() {
            if (HistoryIndex > 0) {
                NavigatingHistory = true;
                HistoryIndex--;
                string path = History[HistoryIndex];
                explorer.tab[0].LoadDirectory(path);
            }
        }

        void NavigateForward() {
            if (HistoryIndex < int(History.Length) - 1) {
                NavigatingHistory = true;
                HistoryIndex++;
                string path = History[HistoryIndex];
                explorer.tab[0].LoadDirectory(path);
            }
        }
    }

    class FileTab {
        FileExplorer@ explorer;
        Utils@ utils;
        InstanceConfig@ instConfig;
        Config@ config;
        Navigation@ nav;

        uint currentSelectedTab = 0;
        array<ElementInfo@> Elements;
        uint SelectedElementIndex;

        uint CurrentPage = 0;
        uint TotalPages = 1;

        FileTab(FileExplorer@ fe) {
            @explorer = fe;
            @utils = fe.utils;
            @config = explorer.config;
            @instConfig = explorer.instConfig;
            @nav = fe.nav;

            LoadDirectory(instConfig.path);
        }

        void LoadDirectory(const string &in path) {
            Elements.Resize(0);
            explorer.nav.UpdateHistory(path);
            explorer.nav.SetPath(path);

            if (config.recursiveSearch) {
                StartRecursiveSearch();
            } else {
                StartIndexingFiles(path);
            }

            CurrentPage = 0;
            UpdatePagination();
        }

        // Start non-recursive indexing
        void StartIndexingFiles(const string &in path) {
            isIndexing = true;
            indexingMessage = "Folder is being indexed...";
            totalIndexingProgress = 0.0f;
            Elements.Resize(0);
            currentIndexingPath = path;

            folderProgressBars.DeleteAll();
            folderProgressOrder.Resize(0);
            folderSubfolderTotalCount.DeleteAll();
            folderSubfolderProcessedCount.DeleteAll();

            string normalizedMainPath = NormalizePath(nav.GetPath());
            folderProgressBars[normalizedMainPath] = 0.0f;
            folderProgressOrder.InsertLast(normalizedMainPath);
            folderSubfolderTotalCount[normalizedMainPath] = 0;
            folderSubfolderProcessedCount[normalizedMainPath] = 0;

            activePathStack.Resize(0);
            activePathStack.InsertLast(nav.GetPath());

            totalTasks = 0;
            processedTasks = 0;

            startnew(CoroutineFuncUserdata(IndexFilesCoroutine), this);
        }

        // Non recursive search
        void IndexFilesCoroutine(ref@ r) {
            FileTab@ tab = cast<FileTab@>(r);
            if (tab is null) return;

            tab.Elements.Resize(0);
            array<string> elements = IO::IndexFolder(nav.GetPath(), false);
            uint totalElements = elements.Length;

            for (uint i = 0; i < elements.Length; i++) {
                ElementInfo@ elementInfo = explorer.GetElementInfo(elements[i]);

                if (elementInfo !is null && (instConfig.searchQuery == "" || elementInfo.name.ToLower().Contains(instConfig.searchQuery.ToLower()))) {
                    tab.Elements.InsertLast(elementInfo);
                }

                if (i % 237 == 0 || i == elements.Length - 1) {
                    indexingMessage = "Indexed " + tostring(i + 1) + " files...";
                    totalIndexingProgress = float(i + 1) / float(totalElements);
                    yield();
                }
            }

            isIndexing = false;
            totalIndexingProgress = 1.0f;
            indexingMessage = "Indexing complete.";
            ApplyFiltersAndSearch();
        }


        bool isIndexing = false;
        string indexingMessage = "";
        float totalIndexingProgress = 0.0f;
        string currentIndexingPath;

        string currentLogState = "";

        dictionary folderProgressBars;
        array<string> folderProgressOrder;

        array<string> activePathStack;

        int totalTasks = 0;
        int processedTasks = 0;

        dictionary directoryProgressMap;
        dictionary normalizedPathCache;

        dictionary folderSubfolderTotalCount;
        dictionary folderSubfolderProcessedCount;

        dictionary folderFileTotalCount;
        dictionary folderFileProcessedCount;
        dictionary folderFileWeight;
        dictionary folderElementsProcessed;
        dictionary folderHasEarlySubfolder;

        bool forceStopRecursiveSearch = false;


        void StartRecursiveSearch() {
            isIndexing = true;
            indexingMessage = "Recursive search in progress...";
            totalIndexingProgress = 0.0f;
            Elements.Resize(0);
            currentIndexingPath = nav.GetPath();

            folderProgressBars.DeleteAll();
            folderProgressOrder.Resize(0);
            folderSubfolderTotalCount.DeleteAll();
            folderSubfolderProcessedCount.DeleteAll();
            folderFileTotalCount.DeleteAll();
            folderFileProcessedCount.DeleteAll();
            folderFileWeight.DeleteAll();
            folderElementsProcessed.DeleteAll();
            folderHasEarlySubfolder.DeleteAll();

            string normalizedMainPath = NormalizePath(nav.GetPath());
            folderProgressBars.Set(normalizedMainPath, 0.0f);
            folderProgressOrder.InsertLast(normalizedMainPath);
            folderSubfolderTotalCount.Set(normalizedMainPath, 0);
            folderSubfolderProcessedCount.Set(normalizedMainPath, 0);
            folderFileTotalCount.Set(normalizedMainPath, 0);
            folderFileProcessedCount.Set(normalizedMainPath, 0);
            folderFileWeight.Set(normalizedMainPath, 0.0f);
            folderElementsProcessed.Set(normalizedMainPath, 0);
            folderHasEarlySubfolder.Set(normalizedMainPath, false);

            activePathStack.Resize(0);
            activePathStack.InsertLast(nav.GetPath());

            totalTasks = 0;
            processedTasks = 0;

            startnew(CoroutineFuncUserdata(RecursiveSearchCoroutine), this);
        }

        // Recursive search coroutine
        void RecursiveSearchCoroutine(ref@ r) {
            FileTab@ tab = cast<FileTab@>(r);
            if (tab is null) return;

            array<string> dirsToProcess;
            dirsToProcess.InsertLast(nav.GetPath());

            const int batchSize = config.recursiveSearchBatchSize;
            int processedSinceLastYield = 0;

            while (dirsToProcess.Length > 0) {
                if (forceStopRecursiveSearch) {
                    forceStopRecursiveSearch = false;
                    break;
                }

                int lastDirIndex = dirsToProcess.Length - 1;
                string currentDir = dirsToProcess[lastDirIndex];
                dirsToProcess.RemoveAt(lastDirIndex);

                bool returningFromSubfolders = false;
                if (currentDir.StartsWith("*")) {
                    currentDir = currentDir.SubStr(1);
                    returningFromSubfolders = true;
                } else {
                    dirsToProcess.InsertLast("*" + currentDir);
                }


                bool isBlacklisted = false;
                for (uint i = 0; i < explorer.config.blacklistedRecursiveSearchPaths.Length; i++) {
                    string normalizedCurrentDir = NormalizePath(currentDir);
                    if (normalizedCurrentDir == NormalizePath(explorer.config.blacklistedRecursiveSearchPaths[i])) {
                        isBlacklisted = true;
                        break;
                    }
                }

                if (isBlacklisted) {
                    continue;
                }

                if (!returningFromSubfolders) {
                    array<string> elements = IO::IndexFolder(currentDir, false);

                    array<string> subfolders;
                    array<string> files;

                    for (uint i = 0; i < elements.Length; i++) {
                        string itemPath = elements[i];
                        if (_IO::Directory::IsDirectory(itemPath)) {
                            subfolders.InsertLast(itemPath);
                        } else {
                            files.InsertLast(itemPath);
                        }
                    }

                    string normalizedCurrentDir = NormalizePath(currentDir);
                    folderSubfolderTotalCount.Set(normalizedCurrentDir, subfolders.Length);
                    folderSubfolderProcessedCount.Set(normalizedCurrentDir, 0);
                    folderFileTotalCount.Set(normalizedCurrentDir, files.Length);
                    folderFileProcessedCount.Set(normalizedCurrentDir, 0);
                    folderFileWeight.Set(normalizedCurrentDir, 0.0f);
                    folderElementsProcessed.Set(normalizedCurrentDir, 0);
                    folderHasEarlySubfolder.Set(normalizedCurrentDir, false);

                    if (files.Length == 0) {
                        folderFileWeight.Set(normalizedCurrentDir, 0.0f);
                    }
                    else if (files.Length < 10) {
                        folderFileWeight.Set(normalizedCurrentDir, 0.05f);
                    }
                    else {
                        folderFileWeight.Set(normalizedCurrentDir, 0.25f);
                    }

                    if (!folderProgressBars.Exists(normalizedCurrentDir)) {
                        folderProgressBars.Set(normalizedCurrentDir, 0.0f);
                        folderProgressOrder.InsertLast(normalizedCurrentDir);

                        UpdateState("Added folder to progress tracking: " + utils.GetDirectoryName(normalizedCurrentDir));
                    }

                    totalTasks += subfolders.Length;

                    for (uint i = 0; i < files.Length; i++) {
                        string filePath = files[i];
                        ElementInfo@ elementInfo = explorer.GetElementInfo(filePath);
                        if (elementInfo !is null && (instConfig.searchQuery == "" || elementInfo.name.ToLower().Contains(instConfig.searchQuery.ToLower()))) {
                            Elements.InsertLast(elementInfo);
                        }

                        int filesProcessed = 0;
                        folderFileProcessedCount.Get(normalizedCurrentDir, filesProcessed);
                        filesProcessed += 1;
                        folderFileProcessedCount.Set(normalizedCurrentDir, filesProcessed);

                        int elementsProcessed = 0;
                        folderElementsProcessed.Get(normalizedCurrentDir, elementsProcessed);
                        elementsProcessed += 1;
                        folderElementsProcessed.Set(normalizedCurrentDir, elementsProcessed);

                        if (elementsProcessed == 50 && !folderHasEarlySubfolder.Get(normalizedCurrentDir, false) && files.Length >= 10) {
                            folderFileWeight.Set(normalizedCurrentDir, 0.85f);
                            UpdateState("Adjusted file weight to 85% for folder: " + utils.GetDirectoryName(normalizedCurrentDir));
                            UpdateFolderProgress(normalizedCurrentDir);
                        }

                        UpdateFolderProgress(normalizedCurrentDir);

                        processedSinceLastYield++;
                        if (processedSinceLastYield >= batchSize) {
                            indexingMessage = "Processing files in " + utils.GetDirectoryName(currentDir) + ": " + tostring(i + 1) + "/" + tostring(files.Length);
                            UpdateState(indexingMessage);
                            processedSinceLastYield = 0;
                            yield();
                        }
                    }

                    for (int i = int(subfolders.Length) - 1; i >= 0; i--) {
                        dirsToProcess.InsertLast(subfolders[i]);
                    }

                    if (subfolders.Length == 0) {
                        UpdateFolderProgress(normalizedCurrentDir);
                    }

                    processedSinceLastYield++;
                    if (processedSinceLastYield >= batchSize) {
                        indexingMessage = "Processing directory: " + utils.GetDirectoryName(currentDir);
                        UpdateState(indexingMessage);
                        processedSinceLastYield = 0;
                        yield();
                    }
                } else {
                    string parentDir = utils.GetParentDirectoryName(currentDir);
                    parentDir = NormalizePath(parentDir);

                    if (parentDir != "") {
                        int subfoldersProcessed = 0;
                        if (folderSubfolderProcessedCount.Get(parentDir, subfoldersProcessed)) {
                            subfoldersProcessed += 1;
                        } else {
                            subfoldersProcessed = 1;
                        }
                        folderSubfolderProcessedCount.Set(parentDir, subfoldersProcessed);

                        int subfoldersTotal = 0;
                        folderSubfolderTotalCount.Get(parentDir, subfoldersTotal);

                        indexingMessage = "Updating parent folder: " + utils.GetDirectoryName(parentDir) + 
                                            " | Subfolders Processed: " + tostring(subfoldersProcessed) + "/" + tostring(subfoldersTotal);
                        UpdateState(indexingMessage);

                        UpdateFolderProgress(parentDir);

                        processedTasks++;
                        UpdateOverallProgress();
                    }

                    int removeIndex = activePathStack.Find(currentDir);
                    if (removeIndex >= 0) {
                        activePathStack.RemoveAt(removeIndex);
                    }

                    string normalizedCurrentDir = NormalizePath(currentDir);
                    folderProgressBars.Delete(normalizedCurrentDir);
                    int index = folderProgressOrder.Find(normalizedCurrentDir);
                    if (index >= 0) {
                        folderProgressOrder.RemoveAt(index);
                    }

                    indexingMessage = "Finished indexing: " + utils.GetDirectoryName(currentDir);
                    UpdateState(indexingMessage);
                    yield();
                }
            }

            isIndexing = false;
            totalIndexingProgress = 1.0f;
            indexingMessage = "Recursive search complete.";
            UpdateState(indexingMessage);
            ApplyFiltersAndSearch();
        }



        void UpdateFolderProgress(const string &in folderPath) {
            string normalizedFolderPath = NormalizePath(folderPath);

            int subfoldersTotal = 0;
            folderSubfolderTotalCount.Get(normalizedFolderPath, subfoldersTotal);

            int subfoldersProcessed = 0;
            folderSubfolderProcessedCount.Get(normalizedFolderPath, subfoldersProcessed);

            int filesTotal = 0;
            folderFileTotalCount.Get(normalizedFolderPath, filesTotal);

            int filesProcessed = 0;
            folderFileProcessedCount.Get(normalizedFolderPath, filesProcessed);

            float fileWeight = 0.0f;
            folderFileWeight.Get(normalizedFolderPath, fileWeight);

            float fileProgress = (filesTotal > 0) ? float(filesProcessed) / float(filesTotal) : 1.0f;
            float subfolderProgress = (subfoldersTotal > 0) ? float(subfoldersProcessed) / float(subfoldersTotal) : 1.0f;

            float progress = (fileProgress * fileWeight) + (subfolderProgress * (1.0f - fileWeight));

            folderProgressBars.Set(normalizedFolderPath, progress);

            UpdateOverallProgress();

            indexingMessage = "Folder: " + utils.GetDirectoryName(folderPath) + 
                                " | Files: " + tostring(filesProcessed) + "/" + tostring(filesTotal) + 
                                " | Subfolders: " + tostring(subfoldersProcessed) + "/" + tostring(subfoldersTotal) + 
                                " | Progress: " + tostring(int(progress * 100)) + "%";
            UpdateState(indexingMessage);

            if (progress >= 1.0f) {
                folderProgressBars.Delete(normalizedFolderPath);
                int orderIndex = folderProgressOrder.Find(normalizedFolderPath);
                if (orderIndex >= 0) {
                    folderProgressOrder.RemoveAt(orderIndex);
                }
                indexingMessage = "Completed: " + utils.GetDirectoryName(folderPath);
                UpdateState(indexingMessage);
            }
        }

        void UpdateOverallProgress() {
            if (totalTasks > 0) {
                totalIndexingProgress = (float(processedTasks) / float(totalTasks));
                indexingMessage = "Overall Progress: " + tostring(int(totalIndexingProgress * 100)) + "% (" + tostring(processedTasks) + "/" + tostring(totalTasks) + ")";
            } else {
                totalIndexingProgress = 1.0f;
                indexingMessage = "Overall Progress: 100% (0/0)";
            }
            UpdateState(indexingMessage);
        }

        string NormalizePath(const string &in path) {
            string normalized = path.Replace("\\", "/");
            while (normalized.Contains("//")) {
                normalized = normalized.Replace("//", "/");
            }
            if (normalized.EndsWith("/")) {
                normalized = normalized.SubStr(0, normalized.Length - 1);
            }
            return normalized;
        }

        void UpdateState(const string &in message) {
            currentLogState = message;
        }




        void ForceStopRecursiveSearch() {
            forceStopRecursiveSearch = true;
        }


        void ApplyFiltersAndSearch() {
            if (config.recursiveSearch) {
                ApplyRecursiveSearch();
            } else {
                ApplyNonRecursiveSearch();
            }

            ApplyFilters();
            ApplyVisibilitySettings();
            UpdatePagination();
        }

        void ApplyNonRecursiveSearch() {
            array<ElementInfo@> tempElements = Elements;
            Elements.Resize(0);

            for (uint i = 0; i < tempElements.Length; i++) {
                if (instConfig.searchQuery == "" || tempElements[i].name.ToLower().Contains(instConfig.searchQuery.ToLower())) {
                    Elements.InsertLast(tempElements[i]);
                }
            }
        }

        void ApplyRecursiveSearch() {
            array<ElementInfo@> tempElements = Elements;
            Elements.Resize(0);

            for (uint i = 0; i < tempElements.Length; i++) {
                if (instConfig.searchQuery == "" || tempElements[i].name.ToLower().Contains(instConfig.searchQuery.ToLower())) {
                    Elements.InsertLast(tempElements[i]);
                }
            }
        }

        void ApplyFilters() {
            bool anyActiveFilters = false;
            for (uint i = 0; i < instConfig.filters.Length; i++) {
                if (instConfig.IsFilterActive(instConfig.filters[i])) {
                    anyActiveFilters = true;
                    break;
                }
            }

            for (uint i = 0; i < Elements.Length; i++) {
                ElementInfo@ element = Elements[i];
                element.shouldShow = true;

                if (anyActiveFilters && !element.isFolder) {
                    bool found = false;
                    for (uint j = 0; j < instConfig.filters.Length; j++) {
                        string filter = instConfig.filters[j];
                        if (instConfig.IsFilterActive(filter) && (element.gbxType.ToLower() == filter.ToLower())) {
                            found = true;
                            break;
                        }
                    }
                    element.shouldShow = found;
                }
            }
        }

        void ApplyVisibilitySettings() {
            for (uint i = 0; i < Elements.Length; i++) {
                ElementInfo@ element = Elements[i];
                if (config.hideFiles && !element.isFolder) {
                    element.shouldShow = false;
                }
                if (config.hideFolders && element.isFolder) {
                    element.shouldShow = false;
                }
            }
        }

        ElementInfo@ GetSelectedElement() {
            for (uint i = 0; i < Elements.Length; i++) {
                if (Elements[i].isSelected) {
                    return Elements[i];
                }
            }
            return null;
        }

        void UpdatePagination() {
            uint totalElements = Elements.Length;
            TotalPages = uint(Math::Ceil(float(totalElements) / config.maxElementsPerPage));
            if (CurrentPage >= TotalPages) {
                CurrentPage = Math::Max(TotalPages - 1, 0);
            }
        }

        void SortElements() {
            for (uint i = 0; i < Elements.Length - 1; i++) {
                for (uint j = i + 1; j < Elements.Length; j++) {
                    bool swap = false;
                    if (config.sortFoldersBeforeFiles) {
                        swap = Elements[i].isFolder && !Elements[j].isFolder;
                    } else {
                        swap = !Elements[i].isFolder && Elements[j].isFolder;
                    }

                    if (config.sortingCriteria == SortingCriteria::nameIgnoreFileFolder) {
                        swap = config.sortingAscending ? Elements[i].name > Elements[j].name : Elements[i].name < Elements[j].name;
                    } else if (config.sortingCriteria == SortingCriteria::name) {
                        if (Elements[i].isFolder && Elements[j].isFolder) {
                            swap = config.sortingAscending ? Elements[i].name > Elements[j].name : Elements[i].name < Elements[j].name;
                        } else if (!Elements[i].isFolder && !Elements[j].isFolder) {
                            swap = config.sortingAscending ? Elements[i].name > Elements[j].name : Elements[i].name < Elements[j].name;
                        } else {
                            swap = config.sortFoldersBeforeFiles ? !Elements[i].isFolder : Elements[i].isFolder;
                        }
                    } else if (config.sortingCriteria == SortingCriteria::size) {
                        swap = config.sortingAscending ? Elements[i].sizeBytes > Elements[j].sizeBytes : Elements[i].sizeBytes < Elements[j].sizeBytes;
                    } else if (config.sortingCriteria == SortingCriteria::lastModified) {
                        swap = config.sortingAscending ? Elements[i].lastModifiedDate > Elements[j].lastModifiedDate : Elements[i].lastModifiedDate < Elements[j].lastModifiedDate;
                    } else if (config.sortingCriteria == SortingCriteria::createdDate) {
                        swap = config.sortingAscending ? Elements[i].creationDate > Elements[j].creationDate : Elements[i].creationDate < Elements[j].creationDate;
                    }

                    if (swap) {
                        ElementInfo@ temp = Elements[i];
                        @Elements[i] = Elements[j];
                        @Elements[j] = temp;
                    }
                }
            }
        }
    }

    class Utils {
        FileExplorer@ explorer;

        Utils(FileExplorer@ fe) {
            @explorer = fe;
        }

        // ------------------------------------------------
        // Directory and Path Operations
        // ------------------------------------------------

        bool IsDirectory(const string &in path) {
            if (path.EndsWith("/") || path.EndsWith("\\")) return true;
            return false;
        }

        string GetDirectoryName(const string &in path) {
            string trimmedPath = path;

            while (trimmedPath.EndsWith("/") || trimmedPath.EndsWith("\\")) {
                trimmedPath = trimmedPath.SubStr(0, trimmedPath.Length - 1);
            }

            int index = trimmedPath.LastIndexOf("/");
            int index2 = trimmedPath.LastIndexOf("\\");

            index = Math::Max(index, index2);

            if (index == -1) {
                return trimmedPath;
            }

            return trimmedPath.SubStr(index + 1);
        }

        string GetParentDirectoryName(const string &in path) {
            string normalizedPath = path.Replace("\\", "/");
            if (normalizedPath.EndsWith("/")) {
                normalizedPath = normalizedPath.SubStr(0, normalizedPath.Length - 1);
            }
            int lastSlash = normalizedPath.LastIndexOf("/");
            if (lastSlash != -1) {
                return normalizedPath.SubStr(0, lastSlash);
            }
            return "";
        }


        // ------------------------------------------------
        // File/Folder Loading and Operations
        // ------------------------------------------------

        void RefreshCurrentDirectory() {
            string currentPath = explorer.tab[0].nav.GetPath();
            log("Refreshing directory: " + currentPath, LogLevel::Info, 1537, "RefreshCurrentDirectory");
            explorer.tab[0].LoadDirectory(currentPath);
        }

        void OpenSelectedFolderInNativeFileExplorer() {
            ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();
            if (selectedElement !is null && selectedElement.isFolder) {
                log("Opening folder: " + selectedElement.path, LogLevel::Info, 1544, "OpenSelectedFolderInNativeFileExplorer");
                OpenExplorerPath(selectedElement.path);
            } else {
                log("No folder selected or selected element is not a folder.", LogLevel::Error, 1547, "OpenSelectedFolderInNativeFileExplorer");
            }
        }

        void OpenCurrentFolderInNativeFileExplorer() {
            string currentPath = explorer.tab[0].nav.GetPath();
            log("Opening folder: " + currentPath, LogLevel::Info, 1553, "OpenCurrentFolderInNativeFileExplorer");
            OpenExplorerPath(currentPath);
        }

        bool IsElementSelected() {
            ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();
            return selectedElement !is null;
        }

        // ------------------------------------------------
        // File I/O Operations
        // ------------------------------------------------

        string ReadFileToEnd(const string &in path) {
            IO::File file(path, IO::FileMode::Read);
            string content = file.ReadToEnd();
            file.Close();
            return content;
        }

        void WriteFile(const string &in path, const string &in content) {
            IO::File file;
            file.Open(path, IO::FileMode::Write);
            file.Write(content);
            file.Close();
        }

        // ------------------------------------------------
        // UI Helper Functions
        // ------------------------------------------------

        void DisabledButton(const string &in text, const vec2 &in size = vec2()) {
            UI::BeginDisabled();
            UI::Button(text, size);
            UI::EndDisabled();
        }

        void DisabledIconButton(const string &in iconText, const vec2 &in size = vec2()) {
            UI::BeginDisabled();
            UI::Button(iconText, size);
            UI::EndDisabled();
        }

        // ------------------------------------------------
        // Window Management Functions
        // ------------------------------------------------

        vec2 originalWindowPos;
        vec2 originalWindowSize;

        bool isMaximized = false;

        void MaximizeWindow() {
            vec2 screenSize = vec2(Display::GetWidth(), Display::GetHeight());
            if (isMaximized) {
                UI::SetWindowPos(originalWindowPos);
                UI::SetWindowSize(originalWindowSize);
                isMaximized = false;
            } else {
                originalWindowPos = UI::GetWindowPos();
                originalWindowSize = UI::GetWindowSize();

                vec2 maximizedPos = vec2(screenSize.x * 0.015, screenSize.y * 0.015);
                vec2 maximizedSize = vec2(screenSize.x * 0.97, screenSize.y * 0.97);

                print(maximizedPos);
                print(maximizedSize);

                UI::SetWindowPos(maximizedPos);
                UI::SetWindowSize(maximizedSize);
                isMaximized = true;
            }
        }

        void MinimizeWindow() {
            vec2 screenSize = vec2(Display::GetWidth(), Display::GetHeight());
            
            isMaximized = false;

            vec2 minimizedPos = vec2(screenSize.x * 0.015, screenSize.y * 0.92);
            vec2 minimizedSize = vec2(562.4, 38);

            UI::SetWindowPos(minimizedPos);
            UI::SetWindowSize(minimizedSize);
        }

        void BaseWindow() {
            UI::SetWindowPos(vec2(150, 200));
            UI::SetWindowSize(vec2(1650, 800));
        }

        // ------------------------------------------------
        // File and Folder Manipulation
        // ------------------------------------------------

        bool RENDER_DELETE_CONFIRMATION_POPUP_FLAG = false;

        void DeleteSelectedElement() {
            ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();
            if (selectedElement !is null) {
                if (selectedElement.isFolder) {
                    array<string> folderContents = IO::IndexFolder(selectedElement.path, false);
                    if (folderContents.Length > 0) {
                        RENDER_DELETE_CONFIRMATION_POPUP_FLAG = true;
                    } else {
                        log("Deleting empty folder: " + selectedElement.path, LogLevel::Info, 1658, "DeleteSelectedElement");
                        IO::DeleteFolder(selectedElement.path);
                        explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                    }
                } else {
                    log("Deleting file: " + selectedElement.path, LogLevel::Info, 1663, "DeleteSelectedElement");
                    IO::Delete(selectedElement.path);
                    explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                }
            }
        }

        bool RENDER_RENAME_POPUP_FLAG;

        void RenameSelectedElement(const string &in newName) {
            ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();
            if (selectedElement is null) return;

            string currentPath = selectedElement.path;
            string newPath;

            string sanitizedNewName = Path::SanitizeFileName(newName);

            if (selectedElement.isFolder) {
                while (currentPath.EndsWith("/") || currentPath.EndsWith("\\")) {
                    currentPath = currentPath.SubStr(0, currentPath.Length - 1);
                }

                string parentDirectory = Path::GetDirectoryName(currentPath);
                newPath = Path::Join(parentDirectory, sanitizedNewName);
            } else {
                string directoryPath = Path::GetDirectoryName(currentPath);
                string extension = Path::GetExtension(currentPath);
                newPath = Path::Join(directoryPath, sanitizedNewName + extension);
            }

            IO::Move(currentPath, newPath);

            explorer.tab[0].LoadDirectory(Path::GetDirectoryName(currentPath));
        }

        void PinSelectedElement() {
            ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();
            if (selectedElement !is null) {
                if (explorer.config.pinnedElements.Find(selectedElement.path) == -1) {
                    log("Pinning element: " + selectedElement.path, LogLevel::Info, 1703, "PinSelectedElement");
                    explorer.config.pinnedElements.InsertLast(selectedElement.path);
                    explorer.config.SaveSharedSettings();
                }
            }
        }

        void TruncateSelectedPathsIfNeeded() {
            uint maxAllowed = uint(explorer.instConfig.minMaxReturnAmount.y);
            if (explorer.instConfig.minMaxReturnAmount.y != -1 && explorer.instConfig.selectedPaths.Length > maxAllowed) {
                explorer.instConfig.selectedPaths.Resize(maxAllowed);
            }
        }

        void SelectAllVisibleAndValidElements() {
            for(uint i = 0; i < explorer.tab[0].Elements.Length; i++) {
                ElementInfo@ element = explorer.tab[0].Elements[i];
                
                if(element.shouldShow && IsValidReturnElement(element)) {
                    if(explorer.instConfig.returnType == "path") {
                        if(explorer.instConfig.minMaxReturnAmount.y != -1 && explorer.instConfig.selectedPaths.Length >= uint(explorer.instConfig.minMaxReturnAmount.y)) {
                            break;
                        }
                        
                        if(explorer.instConfig.selectedPaths.Find(element.path) == -1) {
                            explorer.instConfig.selectedPaths.InsertLast(element.path);
                        }
                    } else if(explorer.instConfig.returnType == "elementinfo") {
                        if(explorer.instConfig.minMaxReturnAmount.y != -1 && explorer.instConfig.selectedElements.Length >= uint(explorer.instConfig.minMaxReturnAmount.y)) {
                            break;
                        }
                        
                        if(explorer.instConfig.selectedElements.Find(element) == -1) {
                            explorer.instConfig.selectedElements.InsertLast(element);
                        }
                    }
                }
            }
        }

        // ------------------------------------------------
        // Sorting Functions
        // ------------------------------------------------

        string SortingCriteriaToString(SortingCriteria criteria) {
            switch (criteria) {
                case SortingCriteria::nameIgnoreFileFolder: return "NameIgnoreFileFolder";
                case SortingCriteria::name: return "Name";
                case SortingCriteria::size: return "Size";
                case SortingCriteria::lastModified: return "Date Modified";
                case SortingCriteria::createdDate: return "Date Created";
            }
            return "Unknown";
        }

        SortingCriteria StringToSortingCriteria(const string &in str) {
            if (str == "NameIgnoreFileFolder") return SortingCriteria::nameIgnoreFileFolder;
            if (str == "Name") return SortingCriteria::name;
            if (str == "Size") return SortingCriteria::size;
            if (str == "Date Modified") return SortingCriteria::lastModified;
            if (str == "Date Created") return SortingCriteria::createdDate;
            return SortingCriteria::name;
        }

        // ------------------------------------------------
        // File Type Handling
        // ------------------------------------------------

        string GetGbxFileType(const string &in path) {
            string ext = Path::GetExtension(path).SubStr(1).ToLower();
            if (ext == "gbx") {
                string fileName = Path::GetFileName(path);

                string trimmedPath = fileName;
                int index = trimmedPath.LastIndexOf(".");
                trimmedPath = trimmedPath.SubStr(0, index);
                int index2 = trimmedPath.LastIndexOf(".");

                string gbxFileType = trimmedPath.SubStr(index2 + 1);

                return gbxFileType;
            }
            return "";
        }

        // ------------------------------------------------
        // Validation Functions
        // ------------------------------------------------

        bool IsValidReturnElement(ElementInfo@ element) {
            bool canReturn = true;

            if (element.isFolder) {
                canReturn = !(explorer.instConfig.canOnlyReturn.Find("file") >= 0 || 
                            explorer.instConfig.canOnlyReturn.Find("files") >= 0);
            } else {
                canReturn = !(explorer.instConfig.canOnlyReturn.Find("folder") >= 0 || 
                            explorer.instConfig.canOnlyReturn.Find("folders") >= 0 || 
                            explorer.instConfig.canOnlyReturn.Find("dir") >= 0 || 
                            explorer.instConfig.canOnlyReturn.Find("directories") >= 0);
            }

            if (!element.isFolder && explorer.instConfig.canOnlyReturn.Length > 0) {
                bool isValidFileType = false;

                if (element.type.ToLower() == "gbx" && element.gbxType.Length > 0) {
                    for (uint i = 0; i < explorer.instConfig.canOnlyReturn.Length; i++) {
                        if (element.gbxType.ToLower() == explorer.instConfig.canOnlyReturn[i].ToLower()) {
                            isValidFileType = true;
                            break;
                        }
                    }
                } else {
                    for (uint i = 0; i < explorer.instConfig.canOnlyReturn.Length; i++) {
                        if (element.type.ToLower() == explorer.instConfig.canOnlyReturn[i].ToLower()) {
                            isValidFileType = true;
                            break;
                        }
                    }
                }

                if (!isValidFileType) {
                    canReturn = false;
                }
            }

            return canReturn;
        }
    }

    class FileExplorer {
        FileExplorer@ explorer;

        string sessionId;
        bool showInterface = false;
        int64 closeTime = -1;
        bool locked = false;

        Config@ config;
        InstanceConfig@ instConfig;
        Utils@ utils;
        array<FileTab@> tab;
        UserInterface@ ui;
        Exports@ exports;
        Navigation@ nav;


        array<string> PinnedElements;
        array<ElementInfo@> CurrentElements;
        ElementInfo@ CurrentSelectedElement;

        FileExplorer(InstanceConfig@ instCfg, const string &in id) {
            sessionId = id;
            @explorer = this;

            @instConfig = instCfg;
            @utils = Utils(this);
            @config = Config(this);

            @nav = Navigation(this);
            tab.Resize(1);
            @tab[0] = FileTab(this);
            @ui = UserInterface(this);
            @exports = Exports(this);

            @CurrentSelectedElement = null;

            nav.UpdateHistory(instCfg.path);
        }

        void UpdateCurrentSelectedElement() {
            @CurrentSelectedElement = tab[0].GetSelectedElement();
        }

        void Open(InstanceConfig@ instConfig) {
            string pluginName = Meta::ExecutingPlugin().Name;
            string sessionKey = pluginName + "::" + instConfig.id;

            if (!explorersByPlugin.Get(sessionKey, @explorer)) { log("Explorer not found for sessionKey: " + sessionKey, LogLevel::Error, 1881, "Open"); return; }
            log("Config initialized with path: " + instConfig.path, LogLevel::Info, 1882, "Open");

            if (nav is null) { @nav = Navigation(this); log("Navigation initialized", LogLevel::Info, 1884, "Open"); }
            if (nav is null) { log("Navigation is null after initialization.", LogLevel::Error, 1885, "Open"); return; }
            log("Setting navigation path to: " + instConfig.path, LogLevel::Info, 1886, "Open");

            nav.SetPath(instConfig.path);
            config.LoadSharedSettings();
            exports.selectionComplete = false;
            this.showInterface = true;
        }

        void Close() {
            config.SaveSharedSettings();

            this.showInterface = false;
            this.closeTime = Time::Now;
            this.locked = true;

            tab[0].ForceStopRecursiveSearch();

            startnew(CoroutineFunc(this.DelayedCleanup));
        }

        private void DelayedCleanup() {
            yield(FILE_EXPLORER_EXPORT_YIELD_AMOUNT);
            if (this.locked) {
                MarkForDeletion();
            }
        }

        void MarkForDeletionCoro() {
            startnew(CoroutineFunc(MarkForDeletion));
        }

        private void MarkForDeletion() {
            yield();
            CloseCurrentSession();
        }

        private void CloseCurrentSession() {
            string pluginName = Meta::ExecutingPlugin().Name;
            string sessionKey = pluginName + "::" + sessionId;
            explorersByPlugin.Delete(sessionKey);
        }

        array<string> GetFiles(const string &in path, bool recursive) {
            return IO::IndexFolder(path, recursive);
        }

        ElementInfo@ GetElementInfo(const string &in path) {
            bool isFolder = utils.IsDirectory(path);
            string name = isFolder ? utils.GetDirectoryName(path) : Path::GetFileName(path);
            string type = isFolder ? "folder" : Path::GetExtension(path).SubStr(1);
            string gbxType = isFolder ? "" : utils.GetGbxFileType(path);
            string size = isFolder ? "-" : ConvertFileSizeToString(IO::FileSize(path));
            int64 sizeBytes = IO::FileSize(path);
            int64 lastModified = IO::FileModifiedTime(path);
            int64 creationDate = IO::FileCreatedTime(path);
            _Icon icon = GetElementIcon(isFolder, type);
            ElementInfo@ elementInfo = ElementInfo(name, path, size, sizeBytes, type, gbxType, lastModified, creationDate, isFolder, icon, false);

            if (type.ToLower() == "gbx") {
                startnew(CoroutineFuncUserdata(ReadGbxMetadataCoroutine), elementInfo);
            }

            return elementInfo;
        }

        void ReadGbxMetadataCoroutine(ref@ r) {
            ElementInfo@ elementInfo = cast<ElementInfo@>(r);
            if (elementInfo is null) return;

            string path = elementInfo.path;
            dictionary gbxMetadata = gbx::ParseGbx(path);
            elementInfo.SetGbxMetadata(gbxMetadata);
        }

        string ConvertFileSizeToString(uint64 size) {
            if (size < 1024) return size + " B";
            else if (size < 1024 * 1024) return (size / 1024) + " KB";
            else if (size < 1024 * 1024 * 1024) return (size / (1024 * 1024)) + " MB";
            else return (size / (1024 * 1024 * 1024)) + " GB";
        }

        _Icon GetElementIcon(bool isFolder, const string &in type) {
            if (isFolder) return _Icon::folder;
            string ext = type.ToLower();
            if (ext == "txt" || ext == "rtf" || ext == "csv" || ext == "json") return _Icon::fileText;
            if (ext == "pdf") return _Icon::filePdf;
            if (ext == "doc" || ext == "docx") return _Icon::fileWord;
            if (ext == "xls" || ext == "xlsx") return _Icon::fileExcel;
            if (ext == "ppt" || ext == "pptx") return _Icon::filePowerpoint;
            if (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "gif") return _Icon::fileImage;
            if (ext == "rar" || ext == "zip" || ext == "7z") return _Icon::fileArchive;
            if (ext == "ogg" || ext == "mp3" || ext == "wav") return _Icon::fileAudio;
            if (ext == "mp4" || ext == "mov") return _Icon::fileVideo;
            if (ext == "cs" || ext == "cpp" || ext == "js" || ext == "java" || ext == "py") return _Icon::fileCode;
            if (ext == "epub") return _Icon::fileEpub;
            return _Icon::file;
        }

        string GetElementIconString(_Icon icon, bool isSelected) {
            switch(icon) {
                case _Icon::folder: return isSelected ? "\\$FD4"+Icons::FolderOpenO+"\\$g" : "\\$FD4"+Icons::FolderO+"\\$g";
                case _Icon::fileText: return Icons::FileTextO;
                case _Icon::filePdf: return Icons::FilePdfO;
                case _Icon::fileWord: return Icons::FileWordO;
                case _Icon::fileExcel: return Icons::FileExcelO;
                case _Icon::filePowerpoint: return Icons::FilePowerpointO;
                case _Icon::fileImage: return Icons::FileImageO;
                case _Icon::fileArchive: return Icons::FileArchiveO;
                case _Icon::fileAudio: return Icons::FileAudioO;
                case _Icon::fileVideo: return Icons::FileVideoO;
                case _Icon::fileCode: return Icons::FileCodeO;
                case _Icon::fileEpub: return Icons::FileEpub;
                default: return Icons::FileO;
            }
        }
    }

    enum ContextType {
        mainArea,
        selectedElements,
        pinnedElements
    }

    class UserInterface {
        FileExplorer@ explorer;
        Utils@ utils;
        InstanceConfig@ instConfig;
        Config@ config;

        UserInterface(FileExplorer@ fe) {
            @explorer = fe;
            @utils = fe.utils;
            @instConfig = fe.instConfig;
            @config = fe.config;
        }

        void Render_FileExplorer() {
            Render_Rows();
            Render_Columns();

            Render_Misc();
        }

        void Render_Misc() {
            Render_RenamePopup();
            Render_DeleteConfirmationPopup();

            switch (currentContextType) {
                case ContextType::mainArea:
                    Render_Context_MainArea();
                    break;
                case ContextType::selectedElements:
                    Render_Context_SelectedElements();
                    break;
                case ContextType::pinnedElements:
                    Render_Context_PinnedElements();
                    break;
            }
        }

        void Render_Rows() {
            Render_TopBar();
            Render_NavigationBar();
            Render_ActionBar();
            Render_ReturnBar();
        }

        void Render_Columns() {
            
            if (UI::GetWindowSize().x > 250 && UI::GetWindowSize().y > 155) {
                UI::BeginTable("FileExplorerTable", 3, UI::TableFlags::Resizable | UI::TableFlags::Borders);
                UI::TableNextColumn();
                    UI::BeginChild("LeftSidebar", vec2(0, 0), true);
                    Render_LeftSidebar();
                    UI::EndChild();
                UI::TableNextColumn();
                    UI::BeginChild("MainArea", vec2(0, 0), true);
                    Render_MainAreaBar();
                    UI::EndChild();
                UI::TableNextColumn();
                    UI::BeginChild("DetailBar", vec2(0, 0), true);
                    Render_DetailBar();
                    UI::EndChild();
                UI::EndTable();
            } else {
                UI::Text("Window too small to \nrender columns (it \nwill crash your game \nif it is rendered any \nsmaller).");
            }

        }

        void Render_TopBar() {
            UI::PushStyleColor(UI::Col::Button, vec4(0, 0, 0, 0));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0, 0, 0, 0));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0, 0, 0, 0));


            // print(UI::GetWindowContentRegionWidth());
            UI::Text("File Explorer | " + "\\$888" + Meta::ExecutingPlugin().Name + "\\$g" + " | " + instConfig.id);
            
            UI::PopStyleColor(3);

            UI::SameLine();

            float availWidth = UI::GetContentRegionAvail().x;
            UI::Dummy(vec2(availWidth - 240, 0));
            UI::SameLine();

            vec2 buttonSize = vec2(60, 0);
            UI::PushStyleColor(UI::Col::Button, vec4(0, 0, 0, 0));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0, 0, 0, 0));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0, 0, 0, 0));
            uint currentPage = explorer.tab[0].CurrentPage + 1;
            uint totalPages = explorer.tab[0].TotalPages;
            string text = ("\\$AAA" + currentPage + "/" + totalPages + "\\$g");

            if (config.enablePagination) {
                if (UI::Button(text, buttonSize)) {}
            } else {
                if (UI::Button("##", buttonSize)) {}
            }
            
            UI::PopStyleColor(3);

            UI::SameLine();

            if (UI::Button(Icons::WindowMinimize)) {
                utils.MinimizeWindow();
            }
            UI::SameLine();
            if (UI::Button(Icons::WindowMaximize)) {
                utils.MaximizeWindow();
            }
            UI::SameLine();
            if (UI::Button(Icons::WindowClose)) {
                explorer.Close();
            }
            UI::SameLine();
            if (UI::Button(Icons::WindowRestore)) {
                utils.BaseWindow();
            }

            UI::Separator();
        }

        void Render_NavigationBar() {
            float totalWidth = UI::GetContentRegionAvail().x;
            float pathWidth = (totalWidth * 0.8f - 30.0f * 3);
    
            if (config.enableSearchBar) {
                pathWidth += config.searchBarPadding;
            }

            float searchWidth = totalWidth - pathWidth - 30.0f * 3;

            // Navigation Buttons
            if (explorer.tab[0].nav.HistoryIndex > 0) {
                if (UI::Button(Icons::ArrowLeft)) {
                    explorer.tab[0].nav.NavigateBack();
                }
            } else {
                utils.DisabledIconButton(Icons::ArrowLeft);
            }
            UI::SameLine();
            if (explorer.tab[0].nav.HistoryIndex < int(explorer.tab[0].nav.History.Length) - 1) {
                if (UI::Button(Icons::ArrowRight)) {
                    explorer.tab[0].nav.NavigateForward();
                }
            } else {
                utils.DisabledIconButton(Icons::ArrowRight);
            }
            UI::SameLine();
            if (explorer.tab[0].nav.CanMoveUpDirectory()) {
                if (UI::Button(Icons::ArrowUp)) {
                    explorer.tab[0].nav.MoveUpOneDirectory();
                }
            } else {
                utils.DisabledIconButton(Icons::ArrowUp);
            }
            UI::SameLine();
            
            if (
                explorer.tab[0].GetSelectedElement() !is null
            &&  explorer.tab[0].GetSelectedElement().isFolder
            &&  explorer.tab[0].GetSelectedElement().isSelected
            ) {
                if (UI::Button(Icons::ArrowDown)) { explorer.tab[0].nav.MoveIntoSelectedDirectory(); }
            } else {
                utils.DisabledIconButton(Icons::ArrowDown);
            }

            UI::SameLine();

            UI::PushItemWidth(pathWidth);
            string newPath = UI::InputText("##PathInput", explorer.tab[0].nav.GetPath());
            if (UI::IsKeyPressed(UI::Key::Enter)) {
                explorer.tab[0].LoadDirectory(newPath);
            }
            UI::PopItemWidth();

            if (config.enableSearchBar) {
                UI::SameLine();
                UI::PushItemWidth(searchWidth - 115);

                UI::Text(Icons::Search + "");
                UI::SameLine();
                string newSearchQuery = UI::InputText("##SearchInput", instConfig.searchQuery);
                if (UI::IsKeyPressed(UI::Key::Enter) && newSearchQuery != instConfig.searchQuery) {
                    instConfig.searchQuery = newSearchQuery;

                    if (config.recursiveSearch) {
                        explorer.tab[0].StartRecursiveSearch();
                    } else {
                        explorer.tab[0].ApplyNonRecursiveSearch();
                    }
                }

                UI::PopItemWidth();
            }

            UI::Separator();
        }

        string newFilter = "";
        string newBlacklistPath = "";
        void Render_ActionBar() {
            if (!config.enablePagination) {
                utils.DisabledIconButton(Icons::ChevronLeft);
                UI::SameLine();
                utils.DisabledIconButton(Icons::ChevronRight);
                UI::SameLine();
            } else {
                if (explorer.tab[0].CurrentPage > 0) {
                    if (UI::Button(Icons::ChevronLeft)) {
                        explorer.tab[0].CurrentPage--;
                    }
                } else {
                    utils.DisabledIconButton(Icons::ChevronLeft);
                }
                UI::SameLine();

                if (explorer.tab[0].CurrentPage < explorer.tab[0].TotalPages - 1) {
                    if (UI::Button(Icons::ChevronRight)) {
                        explorer.tab[0].CurrentPage++;
                    }
                } else {
                    utils.DisabledIconButton(Icons::ChevronRight);
                }
                UI::SameLine();
            }

            if (UI::Button(Icons::Refresh)) { utils.RefreshCurrentDirectory(); }
            UI::SameLine();
            if (UI::Button(Icons::FolderOpen)) { utils.OpenCurrentFolderInNativeFileExplorer(); }
            UI::SameLine();
            if (!utils.IsElementSelected()) {
                utils.DisabledIconButton(Icons::Trash); 
                UI::SameLine();
                utils.DisabledIconButton(Icons::Pencil);
                UI::SameLine();
                utils.DisabledIconButton(Icons::ThumbTack);
            } else {
                if (UI::Button(Icons::Trash)) { utils.DeleteSelectedElement(); }
                UI::SameLine();
                if (UI::Button(Icons::Pencil)) { utils.RENDER_RENAME_POPUP_FLAG = !utils.RENDER_RENAME_POPUP_FLAG; }
                UI::SameLine();
                if (UI::Button(Icons::ThumbTack)) { utils.PinSelectedElement(); }
            }
            UI::SameLine();
            if (UI::Button(Icons::Filter)) { UI::OpenPopup("filterMenu"); }

            if (UI::BeginPopup("filterMenu")) {
                UI::Text("All filters");
                UI::Separator();

                UI::PushStyleColor(UI::Col::Button, vec4(0, 0, 0, 0));
                UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0, 0, 0, 0));
                UI::PushStyleColor(UI::Col::ButtonActive, vec4(0, 0, 0, 0));

                if (UI::Button("Add filter", vec2(70, 0))) {}
                
                UI::PopStyleColor(3);

                UI::SameLine();
                newFilter = UI::InputText("##", newFilter);
                UI::SameLine();
                if (UI::Button("Add")) {
                    instConfig.filters.InsertLast(newFilter.ToLower());
                    explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                }
                UI::Separator();
                UI::Text("Filter length: " + instConfig.filters.Length);

                if (UI::Button("Remove All Filters")) {
                    instConfig.filters.Resize(0);
                    explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                }

                for (uint i = 0; i < instConfig.filters.Length; i++) {
                    string filter = instConfig.filters[i];
                    bool isActive = instConfig.IsFilterActive(filter);

                    if (UI::BeginMenu(filter + (isActive ? "\\$888 (Active)" : "\\$888 (Inactive)"))) {
                        if (UI::MenuItem(isActive ? "Deactivate Filter" : "Activate Filter")) {
                            instConfig.ToggleFilterActive(filter);
                            explorer.tab[0].ApplyFiltersAndSearch();
                        }
                        
                        if (UI::MenuItem("Remove Filter")) {
                            instConfig.filters.RemoveAt(i);
                            instConfig.activeFilters.Delete(filter);
                            explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                        }
                        UI::EndMenu();
                    }
                }

                UI::EndPopup();
            }

            UI::SameLine();

            if (UI::Button(Icons::Sort)) { UI::OpenPopup("sortMenu"); }

            if (UI::BeginPopup("sortMenu")) {
                string orderButtonLabel = config.sortingAscending ? Icons::ArrowUp : Icons::ArrowDown;
                if (UI::MenuItem(orderButtonLabel + " Order", "", config.sortingAscending)) {
                    config.sortingAscending = !config.sortingAscending;
                    explorer.tab[0].SortElements();
                    config.SaveSharedSettings();
                }
                if (UI::MenuItem("Sort Folders Before Files", "", config.sortFoldersBeforeFiles)) {
                    config.sortFoldersBeforeFiles = !config.sortFoldersBeforeFiles;
                    explorer.tab[0].SortElements();
                    config.SaveSharedSettings();
                }
                UI::Separator();

                if (UI::MenuItem("Name", "", config.sortingCriteria == SortingCriteria::name)) {
                    config.sortingCriteria = SortingCriteria::name;
                    explorer.tab[0].SortElements();
                    config.SaveSharedSettings();
                }
                if (UI::MenuItem("Name (Ignore File/Folder)", "", config.sortingCriteria == SortingCriteria::nameIgnoreFileFolder)) {
                    config.sortingCriteria = SortingCriteria::nameIgnoreFileFolder;
                    explorer.tab[0].SortElements();
                    config.SaveSharedSettings();
                }
                if (UI::MenuItem("Size", "", config.sortingCriteria == SortingCriteria::size)) {
                    config.sortingCriteria = SortingCriteria::size;
                    explorer.tab[0].SortElements();
                    config.SaveSharedSettings();
                }
                if (UI::MenuItem("Date Modified", "", config.sortingCriteria == SortingCriteria::lastModified)) {
                    config.sortingCriteria = SortingCriteria::lastModified;
                    explorer.tab[0].SortElements();
                    config.SaveSharedSettings();
                }
                if (UI::MenuItem("Date Created", "", config.sortingCriteria == SortingCriteria::createdDate)) {
                    config.sortingCriteria = SortingCriteria::createdDate;
                    explorer.tab[0].SortElements();
                    config.SaveSharedSettings();
                }

                UI::EndPopup();
            }

            UI::SameLine();

            // LAST ELEMENT LEFT SIDE
            // LARGE SEPERATOR
            // FIRST ELEMENT RIGHT SIDE

            UI::SameLine();
            UI::Dummy(vec2(UI::GetContentRegionAvail().x - 45, 0));
            UI::SameLine();
            if (UI::Button(Icons::Bars)) { UI::OpenPopup("burgerMenu"); }

            if (UI::BeginPopup("burgerMenu")) {
                if (UI::MenuItem("Hide Files", "", config.hideFiles)) {
                    config.hideFiles = !config.hideFiles;
                    config.SaveSharedSettings();
                    explorer.tab[0].ApplyVisibilitySettings();
                    utils.RefreshCurrentDirectory();
                }
                if (UI::MenuItem("Hide Folders", "", config.hideFolders)) {
                    config.hideFolders = !config.hideFolders;
                    config.SaveSharedSettings();
                    explorer.tab[0].ApplyVisibilitySettings();
                    utils.RefreshCurrentDirectory();
                }

                if (UI::BeginMenu("Pagination")) {
                    if (UI::MenuItem("Enable Pagination", "", config.enablePagination)) {
                        config.enablePagination = !config.enablePagination;
                        config.SaveSharedSettings();
                        utils.RefreshCurrentDirectory();
                    }

                    if (config.enablePagination) {
                        config.maxElementsPerPage = UI::SliderInt("Max Elements Per Page", config.maxElementsPerPage, 1, 100);
                    }

                    UI::EndMenu();
                }

                if (UI::BeginMenu("Search Bar")) {
                    if (UI::MenuItem("Enable Search Bar", "", config.enableSearchBar)) {
                        config.enableSearchBar = !config.enableSearchBar;
                        config.SaveSharedSettings();
                        utils.RefreshCurrentDirectory();
                    }

                    if (config.enableSearchBar) {
                        config.searchBarPadding = UI::SliderInt("Search Bar Padding", config.searchBarPadding, -200, 100);
                    }

                    if (UI::MenuItem("Enable Recursive Search", "", config.recursiveSearch)) {
                        config.recursiveSearch = !config.recursiveSearch;
                        config.SaveSharedSettings();
                        explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                    }

                    config.recursiveSearchBatchSize = UI::SliderInt("##BatchSize", config.recursiveSearchBatchSize, 1, 37);
                    UI::Text("Note: Recursive search cannot be changed while a search is in progress.");

                    if (UI::BeginMenu("Blacklisted recursive search paths")) {
                        UI::Text("Blacklisted Paths for recursive search");
                        UI::Separator();

                        UI::Text("Add a path to the blacklist:");
                        newBlacklistPath = UI::InputText("##NewPath", newBlacklistPath);
                        
                        if (UI::Button("Add Path") && newBlacklistPath != "") {
                            if (config.blacklistedRecursiveSearchPaths.Find(newBlacklistPath) == -1) {
                                config.blacklistedRecursiveSearchPaths.InsertLast(newBlacklistPath);
                                config.SaveSharedSettings();
                                newBlacklistPath = "";
                            } else {
                                UI::Text("Path is already blacklisted.");
                            }
                        }

                        UI::Separator();

                        for (uint i = 0; i < config.blacklistedRecursiveSearchPaths.Length; i++) {
                            string path = config.blacklistedRecursiveSearchPaths[i];
                            UI::Text(path);

                            UI::SameLine();
                            if (UI::Button("Remove##" + i)) {
                                config.blacklistedRecursiveSearchPaths.RemoveAt(i);
                                config.SaveSharedSettings();
                                explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                            }
                        }

                        UI::EndMenu();
                    }


                    UI::EndMenu();
                }

                if (UI::MenuItem("Use Extra Warning When Deleting", "", config.useExtraWarningWhenDeleting)) {
                    config.useExtraWarningWhenDeleting = !config.useExtraWarningWhenDeleting;
                }
                
                UI::Separator();

                if (UI::BeginMenu("Visible Columns")) {
                    array<string> orderedColumns = { "ico", "name", "type", "size", "lastModified", "createdDate" };
                    for (uint i = 0; i < orderedColumns.Length; i++) {
                        string col = orderedColumns[i];
                        bool isVisible = config.IsColumnVisible(col);
                        if (UI::MenuItem(col, "", isVisible, true)) {
                            config.ToggleColumnVisibility(col);
                            utils.RefreshCurrentDirectory();
                        }
                    }
                    UI::EndMenu();
                }

                if (UI::BeginMenu("File Name Display Options")) {
                    if (UI::MenuItem("Default File Name", "", config.fileNameDisplayOption == 0)) {
                        config.fileNameDisplayOption = 0;
                        utils.RefreshCurrentDirectory();
                    }
                    if (UI::MenuItem("No Formatting", "", config.fileNameDisplayOption == 1)) {
                        config.fileNameDisplayOption = 1;
                        utils.RefreshCurrentDirectory();
                    }
                    if (UI::MenuItem("ManiaPlanet Formatting", "", config.fileNameDisplayOption == 2)) {
                        config.fileNameDisplayOption = 2;
                        utils.RefreshCurrentDirectory();
                    }
                    UI::EndMenu();
                }

                UI::Separator();

                if (UI::BeginMenu("Valid/Invalid File Colors")) {
                    UI::Text("Valid File Color");
                    config.validFileColor = UI::InputColor4("##", config.validFileColor);
                    UI::Text("Invalid File Color");
                    config.invalidFileColor = UI::InputColor4("##", config.invalidFileColor);
                    UI::Text("Valid Folder Color");
                    config.validFolderColor = UI::InputColor4("##", config.validFolderColor);
                    UI::Text("Invalid Folder Color");
                    config.invalidFolderColor = UI::InputColor4("##", config.invalidFolderColor);

                    UI::EndMenu();
                }

                if (UI::BeginMenu("Reset Settings")) {
                    if (UI::MenuItem("Reset All Settings")) {
                        config.ResetSettings();
                        explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                    }
                    UI::EndMenu();
                }

                // config.SaveSettings();

                UI::EndPopup();
            }

            UI::Separator();
        }

        string newFileName = "";
        void Render_RenamePopup() {
            if (utils.RENDER_RENAME_POPUP_FLAG) {
                UI::OpenPopup("RenamePopup");
                utils.RENDER_RENAME_POPUP_FLAG = false;
            }

            if (UI::BeginPopupModal("RenamePopup", UI::WindowFlags::AlwaysAutoResize)) {
                UI::Text("Enter new name:");
                newFileName = UI::InputText("##RenameInput", newFileName);
                if (UI::Button("Rename")) {
                    utils.RenameSelectedElement(newFileName);
                    newFileName = "";
                    UI::CloseCurrentPopup();
                }
                UI::SameLine();
                if (UI::Button("Cancel")) {
                    newFileName = "";
                    UI::CloseCurrentPopup();
                }
                UI::EndPopup();
            }
        }

        void Render_DeleteConfirmationPopup() {
            string popupName = "DeleteConfirmationPopup_" + explorer.sessionId;

            if (utils.RENDER_DELETE_CONFIRMATION_POPUP_FLAG && config.useExtraWarningWhenDeleting) {
                UI::OpenPopup(popupName);
            } else if (utils.RENDER_DELETE_CONFIRMATION_POPUP_FLAG && !config.useExtraWarningWhenDeleting) {
                ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();

                if (selectedElement !is null && selectedElement.isFolder) {
                    log("Deleting empty folder: " + selectedElement.path, LogLevel::Info, 2548, "Render_DeleteConfirmationPopup");
                    IO::DeleteFolder(selectedElement.path);
                    utils.RENDER_DELETE_CONFIRMATION_POPUP_FLAG = false;
                    explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                }
            }

            if (UI::BeginPopupModal(popupName, utils.RENDER_DELETE_CONFIRMATION_POPUP_FLAG, UI::WindowFlags::AlwaysAutoResize)) {
                ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();

                UI::Text("Are you sure you want to delete this folder and all its contents?");
                UI::Separator();
                if (UI::Button("Yes, delete all")) {
                    if (selectedElement !is null && selectedElement.isFolder) {
                        log("Deleting folder with contents: " + selectedElement.path, LogLevel::Info, 2562, "Render_DeleteConfirmationPopup");
                        IO::DeleteFolder(selectedElement.path, true);
                        utils.RENDER_DELETE_CONFIRMATION_POPUP_FLAG = false;
                        explorer.tab[0].LoadDirectory(explorer.tab[0].nav.GetPath());
                    } else {
                        log("No selected element or element is not a folder.", LogLevel::Error, 2567, "Render_DeleteConfirmationPopup");
                    }
                    UI::CloseCurrentPopup();
                }
                UI::SameLine();
                if (UI::Button("Cancel")) {
                    utils.RENDER_DELETE_CONFIRMATION_POPUP_FLAG = false;
                    UI::CloseCurrentPopup();
                }
                UI::EndPopup();
            }
        }


        void Render_ReturnBar() {
            if (instConfig.mustReturn) {
                bool validReturnAmount;
                if(instConfig.returnType == "path") {
                    validReturnAmount = instConfig.selectedPaths.Length >= uint(instConfig.minMaxReturnAmount.x) &&
                                        (instConfig.selectedPaths.Length <= uint(instConfig.minMaxReturnAmount.y) || instConfig.minMaxReturnAmount.y == -1);
                } else if(instConfig.returnType == "elementinfo") {
                    validReturnAmount = instConfig.selectedElements.Length >= uint(instConfig.minMaxReturnAmount.x) &&
                                        (instConfig.selectedElements.Length <= uint(instConfig.minMaxReturnAmount.y) || instConfig.minMaxReturnAmount.y == -1);
                } else {
                    validReturnAmount = false;
                }

                if (validReturnAmount) {
                    bool hasValidSelections = false;
                    if(instConfig.returnType == "path") {
                        for(uint i = 0; i < instConfig.selectedPaths.Length; i++) {
                            ElementInfo@ element = explorer.GetElementInfo(instConfig.selectedPaths[i]);
                            if(utils.IsValidReturnElement(element)) {
                                hasValidSelections = true;
                                break;
                            }
                        }
                    } else if(instConfig.returnType == "elementinfo") {
                        for(uint i = 0; i < instConfig.selectedElements.Length; i++) {
                            ElementInfo@ element = instConfig.selectedElements[i];
                            if(utils.IsValidReturnElement(element)) {
                                hasValidSelections = true;
                                break;
                            }
                        }
                    }

                    if(hasValidSelections) {
                        string buttonText = instConfig.returnType == "path" ? "Return Selected Paths" : "Return Selected Elements";
                        if (UI::Button(buttonText)) {
                            if (instConfig.returnType == "path") {
                                explorer.exports.SetSelectionComplete(instConfig.selectedPaths, null);
                            } else if (instConfig.returnType == "elementinfo") {
                                explorer.exports.SetSelectionComplete(null, instConfig.selectedElements);
                            }
                            explorer.Close();
                        }
                    } else {
                        if(instConfig.returnType == "path") {
                            utils.DisabledButton("Return Selected Paths");
                        } else if(instConfig.returnType == "elementinfo") {
                            utils.DisabledButton("Return Selected Elements");
                        }
                    }
                } else {
                    if(instConfig.returnType == "path") {
                        utils.DisabledButton("Return Selected Paths");
                    } else if(instConfig.returnType == "elementinfo") {
                        utils.DisabledButton("Return Selected Elements");
                    }
                }

                UI::SameLine();

                if (UI::Button("Select All")) {
                    utils.SelectAllVisibleAndValidElements();
                }

                UI::SameLine();

                if(instConfig.returnType == "path") {
                    UI::Text("Selected element amount: " + instConfig.selectedPaths.Length);
                } else if(instConfig.returnType == "elementinfo") {
                    UI::Text("Selected element amount: " + instConfig.selectedElements.Length);
                }

                UI::Separator();
            }
        }

        void Render_LeftSidebar() {
            UI::Text("Hardcoded Paths");
            UI::Separator();
            Render_HardcodedPaths();
            UI::Separator();

            UI::Text("Pinned Elements");
            UI::Separator();
            Render_PinnedElements();
            UI::Separator();

            UI::Text("Selected Elements");
            UI::Separator();
            Render_SelectedElements();
            UI::Separator();
        }

        void Render_HardcodedPaths() {
            vec4 defaultColor = vec4(1, 1, 1, 1);    // White         (default)
            vec4 grayColor = vec4(0.7, 0.7, 0.7, 1); // Slightly gray

            string currentPath = explorer.tab[0].nav.GetPath();

            UI::PushStyleColor(UI::Col::Text, Path::SanitizeFileName(currentPath) == Path::SanitizeFileName(IO::FromUserGameFolder("")) ? grayColor : defaultColor);
            if (UI::Selectable(Icons::Home + " Trackmania Folder", false)) {
                explorer.tab[0].LoadDirectory(IO::FromUserGameFolder(""));
            }
            UI::PopStyleColor();

            UI::PushStyleColor(UI::Col::Text, Path::SanitizeFileName(currentPath) == Path::SanitizeFileName(IO::FromUserGameFolder("Maps/")) ? grayColor : defaultColor);
            if (UI::Selectable(Icons::Map + " Trackmania Maps Folder", false)) {
                explorer.tab[0].LoadDirectory(IO::FromUserGameFolder("Maps/"));
            }
            UI::PopStyleColor();

            UI::PushStyleColor(UI::Col::Text, Path::SanitizeFileName(currentPath) == Path::SanitizeFileName(IO::FromUserGameFolder("Replays/")) ? grayColor : defaultColor);
            if (UI::Selectable(Icons::SnapchatGhost + " Trackmania Replays Folder", false)) {
                explorer.tab[0].LoadDirectory(IO::FromUserGameFolder("Replays/"));
            }
            UI::PopStyleColor();

            UI::PushStyleColor(UI::Col::Text, Path::SanitizeFileName(currentPath) == Path::SanitizeFileName(IO::FromAppFolder("")) ? grayColor : defaultColor);
            if (UI::Selectable(Icons::Trademark + " Trackmania App Folder", false)) {
                explorer.tab[0].LoadDirectory(IO::FromAppFolder(""));
            }
            UI::PopStyleColor();

            UI::PushStyleColor(UI::Col::Text, Path::SanitizeFileName(currentPath) == Path::SanitizeFileName(IO::FromDataFolder("")) ? grayColor : defaultColor);
            if (UI::Selectable(Icons::Heartbeat + " Openplanet Folder", false)) {
                explorer.tab[0].LoadDirectory(IO::FromDataFolder(""));
            }
            UI::PopStyleColor();

            UI::PushStyleColor(UI::Col::Text, Path::SanitizeFileName(currentPath) == Path::SanitizeFileName(IO::FromStorageFolder("")) ? grayColor : defaultColor);
            if (UI::Selectable(Icons::Inbox + " Openplanet Storage Folder", false)) {
                explorer.tab[0].LoadDirectory(IO::FromStorageFolder(""));
            }
            UI::PopStyleColor();
        }

        void Render_PinnedElements() {
            if (config.pinnedElements.Length == 0) {
                UI::Text("\\$888" + "No pinned elements.");
            } else {
                for (uint i = 0; i < config.pinnedElements.Length; i++) {
                    string path = config.pinnedElements[i];
                    ElementInfo@ element = explorer.GetElementInfo(path);

                    if (element !is null) {
                        SelectableWithClickCheck(element, ContextType::pinnedElements);
                    } else {
                        config.pinnedElements.RemoveAt(i);
                        config.SaveSharedSettings();
                        i--;
                    }
                }
            }
        }

        void Render_Context_PinnedElements() {
            string popupName = "PinnedElementContextMenu_" + explorer.sessionId;

            if (explorer.ui.openContextMenu) {
                UI::OpenPopup(popupName);
                explorer.ui.openContextMenu = false;
            }

            if (UI::BeginPopup(popupName)) {
                ElementInfo@ element = explorer.tab[0].GetSelectedElement();
                if (element !is null) {
                    if (UI::MenuItem("Add to Selected Elements")) {
                        if (instConfig.selectedPaths.Find(element.path) == -1) {
                            instConfig.selectedPaths.InsertLast(element.path);
                            utils.TruncateSelectedPathsIfNeeded();
                        }
                    }

                    if (UI::MenuItem("Remove from Pinned Elements")) {
                        int index = config.pinnedElements.Find(element.path);
                        if (index != -1) {
                            config.pinnedElements.RemoveAt(index);
                            config.SaveSharedSettings();
                        }
                    }

                    if (UI::MenuItem("Rename Pinned Element")) {
                        utils.RENDER_RENAME_POPUP_FLAG = true;
                    }
                } else {
                    int pinnedPath = config.pinnedElements.Find(element.path);
                    config.pinnedElements.RemoveAt(pinnedPath);
                }
                UI::EndPopup();
            }
        }

        void Render_SelectedElements() {
            if (instConfig.returnType == "path") {
                for (uint i = 0; i < instConfig.selectedPaths.Length; i++) {
                    string path = instConfig.selectedPaths[i];
                    ElementInfo@ element = explorer.GetElementInfo(path);

                    SelectableWithClickCheck(element, ContextType::selectedElements);
                }
            } else if (instConfig.returnType == "elementinfo") {
                for (uint i = 0; i < instConfig.selectedElements.Length; i++) {
                    ElementInfo@ element = instConfig.selectedElements[i];

                    SelectableWithClickCheck(element, ContextType::selectedElements);
                }
            }
        }

        void Render_Context_SelectedElements() {
            string popupName = "SelectedElementContextMenu_" + explorer.sessionId;

            if (openContextMenu) {
                UI::OpenPopup(popupName);
                openContextMenu = false;
            }

            if (UI::BeginPopup(popupName)) {
                ElementInfo@ element = explorer.tab[0].GetSelectedElement();
                if (element !is null) {
                    if (UI::MenuItem("Remove from Selected Elements")) {
                        int index = instConfig.selectedPaths.Find(element.path);
                        if (index != -1) {
                            instConfig.selectedPaths.RemoveAt(index);
                        }
                    }

                    if (UI::MenuItem("Pin Element")) {
                        utils.PinSelectedElement();
                    }
                }
                UI::EndPopup();
            }
        }

        void Render_MainAreaBar() {
            FileTab@ currentTab = explorer.tab[0];

            if (currentTab.isIndexing) {

                UI::Text("Indexing in progress...");
                UI::Text(currentTab.currentLogState);
                
                UI::Separator();

                UI::Text("Overall Progress:");
                UI::ProgressBar(currentTab.totalIndexingProgress, vec2(-1, 0), "Total");

                UI::Separator();

                UI::Text("Indexing Details:");

                for (uint i = 0; i < currentTab.folderProgressOrder.Length; i++) {
                    string folderPath = currentTab.folderProgressOrder[i];
                    folderPath = currentTab.NormalizePath(folderPath);

                    float progress = 0.0f;
                    bool found = currentTab.folderProgressBars.Get(folderPath, progress);
                    if (!found) {
                        progress = 0.0f;
                    }

                    string mainPath = currentTab.NormalizePath(currentTab.nav.GetPath());
                    string displayName = folderPath.Replace(mainPath, "");
                    if (displayName.StartsWith("/")) {
                        displayName = displayName.SubStr(1);
                    }
                    if (displayName == "") {
                        displayName = utils.GetDirectoryName(folderPath);
                    }

                    int depth = 0;
                    if (displayName != "") {
                        depth = displayName.Split("/").Length - 1;
                    }

                    string indent = "";
                    for (int d = 0; d < depth; d++) {
                        indent += "    ";
                    }

                    UI::Text(indent + "Indexing: " + displayName);
                    UI::ProgressBar(progress, vec2(-1, 0), tostring(int(progress * 100)) + "%");
                }
            } else if (currentTab.Elements.Length == 0) {
                UI::Text("No elements to display.");
            } else {
                array<string> orderedColumns = { "ico", "name", "type", "size", "lastModified", "createdDate" };
                uint columnCount = 0;

                for (uint i = 0; i < orderedColumns.Length; i++) {
                    bool isVisible = config.IsColumnVisible(orderedColumns[i]);
                    if (isVisible) {
                        columnCount++;
                    }
                }

                if (columnCount > 0) {
                    string tableId = "FilesTable_" + explorer.sessionId;
                    UI::BeginTable(tableId, columnCount, UI::TableFlags::Resizable | UI::TableFlags::Borders | UI::TableFlags::SizingFixedSame);

                    for (uint i = 0; i < orderedColumns.Length; i++) {
                        if (config.IsColumnVisible(orderedColumns[i])) {
                            if (orderedColumns[i] == "ico") {
                                UI::TableSetupColumn(orderedColumns[i], UI::TableColumnFlags::None, 30.0f);
                            } else {
                                UI::TableSetupColumn(orderedColumns[i]);
                            }
                        }
                    }

                    UI::TableHeadersRow();

                    uint startIndex = config.enablePagination ? explorer.tab[0].CurrentPage * config.maxElementsPerPage : 0;
                    uint endIndex = config.enablePagination ? Math::Min(startIndex + config.maxElementsPerPage, explorer.tab[0].Elements.Length) : explorer.tab[0].Elements.Length;

                    for (uint i = startIndex; i < endIndex; i++) {
                        if (i >= explorer.tab[0].Elements.Length) { break; }
                        
                        ElementInfo@ element = explorer.tab[0].Elements[i];
                        if (!element.shouldShow) continue;

                        UI::TableNextRow();
                        uint colIndex = 0;
                        for (uint j = 0; j < orderedColumns.Length; j++) {
                            if (config.IsColumnVisible(orderedColumns[j])) {
                                UI::TableSetColumnIndex(colIndex++);
                                string col = orderedColumns[j];
                                
                                // FIXME: The column size is not set on first load, this has to be done manually by the user, which is not ideal...
                                if (col == "ico") {
                                    UI::Text(explorer.GetElementIconString(element.icon, element.isSelected));
                                } else if (col == "name") {
                                    SelectableWithClickCheck(element, ContextType::mainArea);
                                } else if (col == "type") {
                                    UI::Text(element.type);
                                } else if (col == "size") {
                                    UI::Text(element.isFolder ? "-" : element.size);
                                } else if (col == "lastModified") {
                                    UI::Text(Time::FormatString("%Y-%m-%d %H:%M:%S", element.lastModifiedDate));
                                } else if (col == "createdDate") {
                                    UI::Text(Time::FormatString("%Y-%m-%d %H:%M:%S", element.creationDate));
                                }
                            }
                        }
                    }

                    UI::EndTable();
                } else {
                    UI::Text("No columns selected to display.");
                }
            }
        }

        void Render_Context_MainArea() {
            string popupName = "MainElementContextMenu_" + explorer.sessionId;

            if (openContextMenu) {
                UI::OpenPopup(popupName);
                openContextMenu = false;
            }

            if (UI::BeginPopup(popupName)) {
                ElementInfo@ element = explorer.tab[0].GetSelectedElement();
                if (element !is null) {
                    bool canAddMore = instConfig.returnType == "path" ? instConfig.selectedPaths.Length < uint(instConfig.minMaxReturnAmount.y) || instConfig.minMaxReturnAmount.y == -1
                                                                    : instConfig.selectedElements.Length < uint(instConfig.minMaxReturnAmount.y) || instConfig.minMaxReturnAmount.y == -1;

                    bool isValidElement = utils.IsValidReturnElement(element);

                    if (canAddMore && isValidElement) {
                        if (UI::MenuItem("Add to Selected Elements", "", false)) {
                            if (instConfig.returnType == "path") {
                                if (instConfig.selectedPaths.Find(element.path) == -1) {
                                    instConfig.selectedPaths.InsertLast(element.path);
                                    utils.TruncateSelectedPathsIfNeeded();
                                }
                            } else if (instConfig.returnType == "elementinfo") {
                                if (instConfig.selectedElements.Find(element) == -1) {
                                    instConfig.selectedElements.InsertLast(element);
                                    utils.TruncateSelectedPathsIfNeeded();
                                }
                            }
                        }
                    } else {
                        UI::MenuItem("Add to Selected Elements", "", false, false);
                    }

                    if (canAddMore && isValidElement) {
                        if (UI::MenuItem("Quick return")) {
                            if (instConfig.returnType == "path") {
                                array<string> paths = { element.path };
                                explorer.exports.SetSelectionComplete(paths, null);
                            } else if (instConfig.returnType == "elementinfo") {
                                array<ElementInfo@> elements = { element };
                                explorer.exports.SetSelectionComplete(null, elements);
                            }
                            explorer.Close();
                        }
                    } else {
                        UI::MenuItem("Quick return", "", false, false);
                    }

                    if (UI::MenuItem("Rename Element")) {
                        utils.RENDER_RENAME_POPUP_FLAG = true;
                    }

                    if (UI::MenuItem("Pin Element")) {
                        utils.PinSelectedElement();
                    }

                    if (UI::MenuItem("Delete Element")) {
                        utils.DeleteSelectedElement();
                    }
                }
                UI::EndPopup();
            }
        }

        void SelectableWithClickCheck(ElementInfo@ element, ContextType contextType) {
            string displayName = element.name;
            switch (config.fileNameDisplayOption) {
                case 1:
                    displayName = Text::StripFormatCodes(element.name);
                    break;
                case 2:
                    displayName = element.name.Replace("$", "\\$");
                    break;
                default:
                    displayName = element.name;
            }

            bool isValid = utils.IsValidReturnElement(element);

            vec4 textColor = element.isFolder
                            ? (isValid ? config.validFolderColor : config.invalidFolderColor)
                            : (isValid ? config.validFileColor : config.invalidFileColor);

            UI::PushStyleColor(UI::Col::Text, textColor);
            UI::Selectable(displayName, element.isSelected);
            UI::PopStyleColor();

            if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Left) && (UI::IsKeyDown(UI::Key::LeftCtrl) || UI::IsKeyDown(UI::Key::RightCtrl)) ) {
                HandleElementSelection(element, EnterType::ControlClick, contextType);
            } else if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Left)) {
                HandleElementSelection(element, EnterType::LeftClick, contextType);
            } else if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right)) {
                HandleElementSelection(element, EnterType::RightClick, contextType);
            }
        }

        void HandleElementSelection(ElementInfo@ element, EnterType enterType, ContextType contextType) {
            bool canAddMore = instConfig.selectedPaths.Length < uint(instConfig.minMaxReturnAmount.y) || instConfig.minMaxReturnAmount.y == -1;
            bool isValidForSelection = utils.IsValidReturnElement(element);

            uint64 currentTime = Time::Now;
            const uint64 doubleClickThreshold = 600; // 0.6 seconds

            // Handle right- and control-click (context menu)
            if (enterType == EnterType::RightClick || enterType == EnterType::ControlClick) {
                if (contextType == ContextType::mainArea || contextType == ContextType::selectedElements || contextType == ContextType::pinnedElements) {
                    if (contextType != ContextType::selectedElements) {
                        for (uint i = 0; i < explorer.tab[0].Elements.Length; i++) {
                            explorer.tab[0].Elements[i].isSelected = false;
                        }
                        element.isSelected = true;
                    }

                    element.lastSelectedTime = currentTime;
                    element.lastClickTime = currentTime;
                    @explorer.CurrentSelectedElement = element;
                }

                openContextMenu = true;
                currentContextType = contextType;
                @explorer.CurrentSelectedElement = element;
                return;
            }

            if (!isValidForSelection) return;

            // Handle double-click
            if (currentTime - element.lastClickTime <= doubleClickThreshold) {
                if (contextType == ContextType::selectedElements) {
                    if(instConfig.returnType == "path") {
                        int index = instConfig.selectedPaths.Find(element.path);
                        if(index != -1) {
                            instConfig.selectedPaths.RemoveAt(index);
                            element.isSelected = false;
                            log("Removed path from selected paths: " + element.path, LogLevel::Info, 3070, "HandleElementSelection");
                        }
                    } else if(instConfig.returnType == "elementinfo") {
                        int index = instConfig.selectedElements.Find(element);
                        if(index != -1) {
                            instConfig.selectedElements.RemoveAt(index);
                            element.isSelected = false;
                            log("Removed element from selected elements: " + element.name, LogLevel::Info, 3077, "HandleElementSelection");
                        }
                    }
                }
                else if (contextType == ContextType::pinnedElements) {
                    if (canAddMore && (instConfig.returnType == "path" ? instConfig.selectedPaths.Find(element.path) == -1 : instConfig.selectedElements.Find(element) == -1)) {
                        if(instConfig.returnType == "path") {
                            instConfig.selectedPaths.InsertLast(element.path);
                            utils.TruncateSelectedPathsIfNeeded();
                        } else if(instConfig.returnType == "elementinfo") {
                            instConfig.selectedElements.InsertLast(element);
                            utils.TruncateSelectedPathsIfNeeded();
                        }
                        log("Added element to selected elements via pinnedElements double-click: " + element.name, LogLevel::Info, 3090, "HandleElementSelection");
                    }
                    @explorer.CurrentSelectedElement = element;
                }
                else if (contextType == ContextType::mainArea) {
                    if (element.isFolder) {
                        explorer.tab[0].nav.MoveIntoSelectedDirectory();
                        log("Navigated into folder: " + element.path, LogLevel::Info, 3097, "HandleElementSelection");
                    } else if (canAddMore) {
                        if (instConfig.returnType == "path") {
                            if (instConfig.selectedPaths.Find(element.path) == -1) {
                                instConfig.selectedPaths.InsertLast(element.path);
                                utils.TruncateSelectedPathsIfNeeded();
                                log("Added path to selected paths via mainArea double-click: " + element.path, LogLevel::Info, 3103, "HandleElementSelection");
                            }
                        } else if (instConfig.returnType == "elementinfo") {
                            if (instConfig.selectedElements.Find(element) == -1) {
                                instConfig.selectedElements.InsertLast(element);
                                utils.TruncateSelectedPathsIfNeeded();
                                log("Added element to selected elements via mainArea double-click: " + element.name, LogLevel::Info, 3109, "HandleElementSelection");
                            }
                        }
                    }
                }
            }
            else {
                if (contextType == ContextType::selectedElements) {
                    element.lastClickTime = currentTime;
                }
                else if (contextType == ContextType::pinnedElements) {
                    if (canAddMore && (instConfig.returnType == "path" ? instConfig.selectedPaths.Find(element.path) == -1 : instConfig.selectedElements.Find(element) == -1)) {
                        if(instConfig.returnType == "path") {
                            instConfig.selectedPaths.InsertLast(element.path);
                            utils.TruncateSelectedPathsIfNeeded();
                        } else if(instConfig.returnType == "elementinfo") {
                            instConfig.selectedElements.InsertLast(element);
                            utils.TruncateSelectedPathsIfNeeded();
                        }
                        log("Added element to selected elements via pinnedElements single click: " + element.name, LogLevel::Info, 3128, "HandleElementSelection");
                    }
                    @explorer.CurrentSelectedElement = element;
                    element.lastClickTime = currentTime;
                }
                else if (contextType == ContextType::mainArea) {
                    if (contextType != ContextType::pinnedElements) {
                        for (uint i = 0; i < explorer.tab[0].Elements.Length; i++) {
                            explorer.tab[0].Elements[i].isSelected = false;
                        }
                    }
                    element.isSelected = true;
                    element.lastSelectedTime = currentTime;
                    element.lastClickTime = currentTime;
                    @explorer.CurrentSelectedElement = element;
                }
            }
        }

        ContextType currentContextType;
        bool openContextMenu = false;

        void Render_DetailBar() {
            ElementInfo@ selectedElement = explorer.tab[0].GetSelectedElement();
            if (selectedElement !is null) {
                UI::Text("Selected Element Details");
                UI::Separator();
                UI::Text("ICO: " + explorer.GetElementIconString(selectedElement.icon, selectedElement.isSelected));
                if (UI::Selectable("Name: " + selectedElement.name, false)) {
                    IO::SetClipboard(selectedElement.name);
                }
                if (UI::Selectable("Path: " + selectedElement.path, false)) {
                    IO::SetClipboard(selectedElement.path);
                }
                if (UI::Selectable("Size: " + selectedElement.size, false)) {
                    IO::SetClipboard(selectedElement.size);
                }
                if (UI::Selectable("Type: " + selectedElement.type, false)) {
                    IO::SetClipboard(selectedElement.type);
                }
                if (UI::Selectable("Last modified: " + Time::FormatString("%Y-%m-%d %H:%M:%S", selectedElement.lastModifiedDate), false)) {
                    IO::SetClipboard(Time::FormatString("%Y-%m-%d %H:%M:%S", selectedElement.lastModifiedDate));
                }
                if (UI::Selectable("Last selected: " + selectedElement.lastSelectedTime, false)) {
                    IO::SetClipboard(Time::FormatString("%Y-%m-%d %H:%M:%S", selectedElement.lastSelectedTime));
                }
                
                if (selectedElement.type.ToLower() == "gbx") {
                    UI::Separator();
                    UI::Text("GBX File Detected - Displaying GBX Info");

                    dictionary gbxMetadata = selectedElement.gbxMetadata;

                    if (gbxMetadata.IsEmpty()) {
                        UI::Text("No metadata found.");
                    }

                    if (true) UI::Text("Selected element " + selectedElement.path);

                    string value;
                    if (gbxMetadata.Get("type", value)) { if (UI::Selectable("Type: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("exever", value)) { if (UI::Selectable("Exe Version: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("exebuild", value)) { if (UI::Selectable("Exe Build: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("title", value)) { if (UI::Selectable("Title: " + value, false)) { IO::SetClipboard(value); } }

                    if (gbxMetadata.Get("map_uid", value)) { if (UI::Selectable("Map UID: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("map_name", value)) { if (UI::Selectable("Map Name: " + Text::StripFormatCodes(value), false)) { IO::SetClipboard(Text::StripFormatCodes(value)); } }
                    if (gbxMetadata.Get("map_author", value)) { if (UI::Selectable("Map Author: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("map_authorzone", value)) { if (UI::Selectable("Map Author Zone: " + value, false)) { IO::SetClipboard(value); } }

                    if (gbxMetadata.Get("desc_envir", value)) { if (UI::Selectable("Environment: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("desc_mood", value)) { if (UI::Selectable("Mood: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("desc_maptype", value)) { if (UI::Selectable("Map Type: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("desc_mapstyle", value)) { if (UI::Selectable("Map Style: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("desc_displaycost", value)) { if (UI::Selectable("Display Cost: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("desc_mod", value)) { if (UI::Selectable("Mod: " + value, false)) { IO::SetClipboard(value); } }

                    if (gbxMetadata.Get("times_bronze", value)) { if (UI::Selectable("Bronze Time: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("times_silver", value)) { if (UI::Selectable("Silver Time: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("times_gold", value)) { if (UI::Selectable("Gold Time: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("times_authortime", value)) { if (UI::Selectable("Author Time: " + value, false)) { IO::SetClipboard(value); } }
                    if (gbxMetadata.Get("times_authorscore", value)) { if (UI::Selectable("Author Score: " + value, false)) { IO::SetClipboard(value); } }

                    uint depIndex = 0;
                    while (gbxMetadata.Get("dep_file_" + tostring(depIndex), value)) {
                        UI::Text("Dependency File: " + value);
                        depIndex++;
                    }
                }
            } else {
                UI::Text("No element selected.");
            }
        }
    }

    /* ------------------------ Handle Button Clicks ------------------------ */
    enum EnterType {
        None,
        LeftClick,
        RightClick,
        DoubleClick,
        ControlClick
    }
    /* ------------------------ End Handle Button Clicks ------------------------ */



    /* ------------------------ GBX Parsing ------------------------ */
    // Fixme:
    // - Currently only Replay type is accounted for, need to add Map (and more) types as well 
    // (but it's proving to be a bit tricky) (Reason: nothing is being added to the xmlString)
    /* ------------------------ GBX Parsing ------------------------ */
    namespace gbx {

        const bool VERBOSE_GBX = false;

        enum GBX_CHUNK_IDS {
            Replay0     = 50933760,  // 0x3093000 // Example: Replays
            Replay1     = 50933761,  // 0x3093001 // Example: Replays alternate ID
            Replay2     = 50933762,  // 0x3093002 // Example: Replays alternate ID

            Ghost0      = 0,         // 0x0       // Example: Ghosts
            Ghost11420  = 11420,     // 0x2C9C    // Example: Ghosts alternate ID
            
            Map2        = 50606082,  // 0x3043002 // Example: Maps
            Map3        = 50606083,  // 0x3043003 // Example: Maps alternate ID
            Map4        = 50606084,  // 0x3043004 // Example: Maps alternate ID
            Map5        = 50606085,  // 0x3043005 // Example: Maps alternate ID
         // Map6        = 50606086,  // 0x3043006 // Example: Maps alternate ID
            Map7        = 50606087,  // 0x3043007 // Example: Maps alternate ID
            Map8        = 50606088,  // 0x3043008 // Example: Maps alternate ID

            Challenge2  = 50606082,  // 0x3043002 // Example: Challenges           (Maps douplicate ID)
            Challenge3  = 50606083,  // 0x3043003 // Example: Challenges alternate (Maps douplicate ID)
            Challenge4  = 50606084,  // 0x3043004 // Example: Challenges alternate (Maps douplicate ID)
            Challenge5  = 50606085,  // 0x3043005 // Example: Challenges alternate (Maps douplicate ID)
         // Challenge6  = 50606086,  // 0x3043006 // Example: Challenges alternate (Maps douplicate ID)
            Challenge7  = 50606087   // 0x3043007 // Example: Challenges alternate (Maps douplicate ID)
         // Challenge8  = 50606088,  // 0x3043008 // Challenge 8 does not seem to exist
        }

        class GbxHeaderChunkInfo {
            int ChunkId;
            int ChunkSize;
        };

        class GbxParser {
            string filePath;
            IO::File gbxFile;
            dictionary metadata;
            string xmlContent;
            GbxHeaderChunkInfo[] headerChunks;


            void ReadHeader() {
                gbxFile.SetPos(17);
                int chunkCount = gbxFile.Read(4).ReadInt32();
                if (VERBOSE_GBX) log("Number of header chunks: " + tostring(chunkCount), LogLevel::Info, 3285, "ReadHeader");

                for (int i = 0; i < chunkCount; i++) {
                    GbxHeaderChunkInfo chunk;
                    chunk.ChunkId = gbxFile.Read(4).ReadInt32();
                    chunk.ChunkSize = gbxFile.Read(4).ReadInt32() & 0x7FFFFFFF;
                    headerChunks.InsertLast(chunk);
                    if (VERBOSE_GBX) log("Header Chunk " + tostring(i) + ": ID=" + tostring(chunk.ChunkId) + ", Size=" + tostring(chunk.ChunkSize), LogLevel::Info, 3292, "ReadHeader");
                }
            }

            void ReadChunks() {
                int64 startTime = Time::Now;

                for (uint i = 0; i < headerChunks.Length; i++) {
                    MemoryBuffer chunkData = gbxFile.Read(headerChunks[i].ChunkSize);

                    if (VERBOSE_GBX) log("Processing ChunkId: " + tostring(headerChunks[i].ChunkId), LogLevel::Info, 3302, "ReadChunks");

                    if (//headerChunks[i].ChunkId == GBX_CHUNK_IDS::Replay0 || 
                        headerChunks[i].ChunkId == GBX_CHUNK_IDS::Replay1 || 

                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Ghost0 ||
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Ghost11420 ||

                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Map2
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Map3
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Map4
                        headerChunks[i].ChunkId == GBX_CHUNK_IDS::Map5 ||
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Map7
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Map8

                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Challenge2 ||
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Challenge3 ||
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Challenge4 ||
                        headerChunks[i].ChunkId == GBX_CHUNK_IDS::Challenge5
                        // headerChunks[i].ChunkId == GBX_CHUNK_IDS::Challenge7
                        ) {
                        
                        try {
                            int xmlLength = chunkData.ReadInt32();
                            if (VERBOSE_GBX) log("ChunkId " + tostring(headerChunks[i].ChunkId) + " contains XML of length: " + tostring(xmlLength), LogLevel::Info, 3326, "ReadChunks");

                            string currentXmlContent = chunkData.ReadString(xmlLength);
                            if (VERBOSE_GBX) log("Read XML content: " + currentXmlContent.SubStr(0, Math::Min(currentXmlContent.Length, 100)), LogLevel::Debug, 3329, "ReadChunks");

                            if (xmlContent != "") {
                                xmlContent += currentXmlContent;
                                if (VERBOSE_GBX) log("Accumulated XML content from ChunkId: " + tostring(headerChunks[i].ChunkId), LogLevel::Info, 3333, "ReadChunks");
                            } else {
                                xmlContent = currentXmlContent;
                                if (VERBOSE_GBX) log("Extracted XML content from ChunkId: " + tostring(headerChunks[i].ChunkId), LogLevel::Info, 3336, "ReadChunks");
                            }
                        } catch {
                            if (VERBOSE_GBX) log("Error reading XML content from ChunkId: " + tostring(headerChunks[i].ChunkId), LogLevel::Error, 3339, "ReadChunks");
                            continue;
                        }
                    }

                    if (Time::Now - startTime > 300) {
                        if (VERBOSE_GBX) log("Error: Timeout while reading GBX chunks for file: " + filePath, LogLevel::Error, 3345, "ReadChunks");
                    }
                }

                if (VERBOSE_GBX) log("Total XML Content Length: " + tostring(xmlContent.Length), LogLevel::Info, 3349, "ReadChunks");
            }

            void ParseXmlContent() {
                if (xmlContent == "") {
                    if (VERBOSE_GBX) log("Warning: No XML content found in GBX file: " + filePath, LogLevel::Warning, 3354, "ParseXmlContent");
                    return;
                }

                XML::Document doc;
                doc.LoadString(xmlContent);

                XML::Node rootNode = doc.Root().FirstChild();

                if (rootNode) {
                    string gbxType = rootNode.Attribute("type");
                    metadata["type"] = gbxType;
                    metadata["exever"] = rootNode.Attribute("exever");
                    metadata["exebuild"] = rootNode.Attribute("exebuild");
                    metadata["title"] = rootNode.Attribute("title");

                    if (VERBOSE_GBX) log("Parsed GBX Type: " + gbxType, LogLevel::Info, 3370, "ParseXmlContent");

                    if (gbxType == "map") {
                        ParseMapMetadata(rootNode);
                    } else if (gbxType == "replay") {
                        ParseReplayMetadata(rootNode);
                    } else if (gbxType == "challenge") {
                        ParseChallengeMetadata(rootNode);
                    } else {
                        if (VERBOSE_GBX) log("Warning: Unknown GBX type '" + gbxType + "' in file: " + filePath, LogLevel::Warning, 3379, "ParseXmlContent");
                    }

                    XML::Node playermodelNode = rootNode.Child("playermodel");
                    if (playermodelNode) {
                        metadata["playermodel_id"] = playermodelNode.Attribute("id");
                        if (VERBOSE_GBX) log("Parsed playermodel_id: " + string(metadata["playermodel_id"]), LogLevel::Info, 3385, "ParseXmlContent");
                    }
                } else {
                    if (VERBOSE_GBX) log("Error: Missing root node in GBX file: " + filePath, LogLevel::Error, 3388, "ParseXmlContent");
                }
            }

            void ParseMapMetadata(XML::Node &in rootNode) {
                if (VERBOSE_GBX) log("Parsing Map Metadata", LogLevel::Info, 3393, "ParseMapMetadata");
                XML::Node identNode = rootNode.Child("ident");
                if (identNode) {
                    metadata["map_uid"] = identNode.Attribute("uid");
                    metadata["map_name"] = identNode.Attribute("name");
                    metadata["map_author"] = identNode.Attribute("author");
                    metadata["map_authorzone"] = identNode.Attribute("authorzone");
                    if (VERBOSE_GBX) log("Parsed ident node for Map", LogLevel::Info, 3400, "ParseMapMetadata");
                }

                ParseDescNode(rootNode);

                XML::Node timesNode = rootNode.Child("times");
                if (timesNode) {
                    metadata["times_bronze"] = timesNode.Attribute("bronze");
                    metadata["times_silver"] = timesNode.Attribute("silver");
                    metadata["times_gold"] = timesNode.Attribute("gold");
                    metadata["times_authortime"] = timesNode.Attribute("authortime");
                    metadata["times_authorscore"] = timesNode.Attribute("authorscore");
                    metadata["times_challenger"] = timesNode.Attribute("challenger");
                    if (VERBOSE_GBX) log("Parsed times node for Map", LogLevel::Info, 3413, "ParseMapMetadata");
                }

                ParseDependencies(rootNode);
            }

            void ParseReplayMetadata(XML::Node &in rootNode) {
                if (VERBOSE_GBX) log("Parsing Replay Metadata", LogLevel::Info, 3420, "ParseReplayMetadata");
                XML::Node mapNode = rootNode.Child("map");
                if (mapNode) {
                    metadata["map_uid"] = mapNode.Attribute("uid");
                    metadata["map_name"] = mapNode.Attribute("name");
                    metadata["map_author"] = mapNode.Attribute("author");
                    metadata["map_authorzone"] = mapNode.Attribute("authorzone");
                    if (VERBOSE_GBX) log("Parsed map node for Replay", LogLevel::Info, 3427, "ParseReplayMetadata");
                }

                ParseDescNode(rootNode);

                XML::Node timesNode = rootNode.Child("times");
                if (timesNode) {
                    metadata["replay_best"] = timesNode.Attribute("best");
                    metadata["replay_respawns"] = timesNode.Attribute("respawns");
                    metadata["replay_stuntscore"] = timesNode.Attribute("stuntscore");
                    metadata["replay_validable"] = timesNode.Attribute("validable");
                    if (VERBOSE_GBX) log("Parsed times node for Replay", LogLevel::Info, 3438, "ParseReplayMetadata");
                }

                XML::Node checkpointsNode = rootNode.Child("checkpoints");
                if (checkpointsNode) {
                    metadata["replay_checkpoints"] = checkpointsNode.Attribute("cur");
                    if (VERBOSE_GBX) log("Parsed checkpoints node for Replay", LogLevel::Info, 3444, "ParseReplayMetadata");
                }
            }

            void ParseChallengeMetadata(XML::Node &in rootNode) {
                if (VERBOSE_GBX) log("Parsing Challenge Metadata", LogLevel::Info, 3449, "ParseChallengeMetadata");
                XML::Node identNode = rootNode.Child("ident");
                if (identNode) {
                    metadata["map_uid"] = identNode.Attribute("uid");
                    metadata["map_name"] = identNode.Attribute("name");
                    metadata["map_author"] = identNode.Attribute("author");
                    if (VERBOSE_GBX) log("Parsed ident node for Challenge", LogLevel::Info, 3455, "ParseChallengeMetadata");
                }

                ParseDescNode(rootNode);

                XML::Node timesNode = rootNode.Child("times");
                if (timesNode) {
                    metadata["times_bronze"] = timesNode.Attribute("bronze");
                    metadata["times_silver"] = timesNode.Attribute("silver");
                    metadata["times_gold"] = timesNode.Attribute("gold");
                    metadata["times_authortime"] = timesNode.Attribute("authortime");
                    metadata["times_authorscore"] = timesNode.Attribute("authorscore");
                    metadata["times_challenger"] = timesNode.Attribute("challenger");
                    if (VERBOSE_GBX) log("Parsed times node for Challenge", LogLevel::Info, 3468, "ParseChallengeMetadata");
                }

                ParseDependencies(rootNode);
            }

            void ParseDescNode(XML::Node &in rootNode) {
                XML::Node descNode = rootNode.Child("desc");
                if (descNode) {
                    metadata["desc_envir"] = descNode.Attribute("envir");
                    metadata["desc_mood"] = descNode.Attribute("mood");
                    metadata["desc_maptype"] = descNode.Attribute("type");
                    metadata["desc_mapstyle"] = descNode.Attribute("mapstyle");
                    metadata["desc_displaycost"] = descNode.Attribute("displaycost");
                    metadata["desc_mod"] = descNode.Attribute("mod");
                    metadata["desc_validated"] = descNode.Attribute("validated");
                    metadata["desc_nblaps"] = descNode.Attribute("nblaps");
                    metadata["desc_hasghostblocks"] = descNode.Attribute("hasghostblocks");
                    if (VERBOSE_GBX) log("Parsed desc node", LogLevel::Info, 3486, "ParseDescNode");
                }
            }

            void ParseDependencies(XML::Node &in rootNode) {
                XML::Node depsNode = rootNode.Child("deps");
                if (depsNode) {
                    XML::Node depNode = depsNode.FirstChild();
                    int depIndex = 0;
                    while (depNode) {
                        metadata["dep_file_" + tostring(depIndex)] = depNode.Attribute("file");
                        depNode = depNode.NextSibling();
                        depIndex++;
                    }
                    if (VERBOSE_GBX) log("Parsed dependencies node with " + tostring(depIndex) + " dependencies", LogLevel::Info, 3500, "ParseDependencies");
                }
            }

            void ListAllChunkIds() {
                if (VERBOSE_GBX) log("Listing all ChunkIds for file: " + filePath, LogLevel::Info, 3505, "ListAllChunkIds");
                for (uint i = 0; i < headerChunks.Length; i++) {
                    if (VERBOSE_GBX) log("Chunk " + tostring(i) + " - ChunkId: " + tostring(headerChunks[i].ChunkId) + ", ChunkSize: " + tostring(headerChunks[i].ChunkSize), LogLevel::Info, 3507, "ListAllChunkIds");
                }
            }

            GbxParser(const string &in path) {
                filePath = path;
            }

            dictionary Parse() {
                if (VERBOSE_GBX) log("Parse started for file: " + filePath, LogLevel::Info, 3516, "Parse");
                try {
                    if (VERBOSE_GBX) log("Opening GBX file: " + filePath, LogLevel::Info, 3518, "Parse");
                    gbxFile.Open(filePath, IO::FileMode::Read);
                    ReadHeader();

                    ListAllChunkIds();
                    ReadChunks();
                    ParseXmlContent();
                    gbxFile.Close();
                    if (VERBOSE_GBX) log("Closed GBX file: " + filePath, LogLevel::Info, 3526, "Parse");
                } catch {
                    if (VERBOSE_GBX) log("Exception in file: " + filePath, LogLevel::Error, 3528, "Parse");
                    gbxFile.Close();
                }
                return metadata;
            }
        };

        dictionary ParseGbx(const string &in filePath) {
            GbxParser parser(filePath);
            return parser.Parse();
        }
    }
    /* ------------------------ End GBX Parsing ------------------------ */



    FileExplorer@ fe_GetExplorerById(const string &in id) {
        string pluginName = Meta::ExecutingPlugin().Name;
        string sessionKey = pluginName + "::" + id;
        FileExplorer@ explorer;
        explorersByPlugin.Get(sessionKey, @explorer);
        return explorer;
    }

    void RenderFileExplorer() {
        string pluginName = Meta::ExecutingPlugin().Name;

        array<string> keys = explorersByPlugin.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            string sessionKey = keys[i];

            if (sessionKey.StartsWith(pluginName + "::")) {
                FileExplorer@ explorer;
                if (explorersByPlugin.Get(sessionKey, @explorer)) {
                    string sessionId = sessionKey.SubStr(pluginName.Length + 2); // Skip "pluginName::"
                    string windowTitle = "File Explorer " + sessionId;

                    if (!explorer.showInterface) continue;
                    if (UI::Begin(windowTitle, explorer.showInterface, UI::WindowFlags::NoTitleBar)) {
                        explorer.ui.Render_FileExplorer();
                    }
                    UI::End();
                }
            }
        }
    }

    dictionary explorersByPlugin;

    void fe_Start(
        string _id,
        bool _mustReturn,
        string _returnType = "path", // Possible "path", "ElementInfo"
        vec2 _minmaxReturnAmount = vec2(1, -1),
        string _path = "",
        string _searchQuery = "",
        string[] _filters = array<string>(),
        string[] _canOnlyReturn = array<string>()
    ) {
        string pluginName = Meta::ExecutingPlugin().Name;

        string sessionKey = pluginName + "::" + _id;

        if (explorersByPlugin.Exists(sessionKey)) {
            NotifyError(
            "The session ID '" + _id + "' is already in use by this plugin. This can happen if you try to open another instance of the same file explorer, or if you attempt "+
            "to re-open the same file explorer window less than " + FILE_EXPLORER_EXPORT_YIELD_AMOUNT + " frames after closing the file explorer with the same sessionId it with the "+
            "same session ID. If you have waited more than " + FILE_EXPLORER_EXPORT_YIELD_AMOUNT + " frames and are not trying to open the same session, please contact the plugin "+
            "developer (" + Meta::ExecutingPlugin().Name + ") or the creator of the file explorer ('@ar___' on Discord).", 
            "Error: " + Meta::ExecutingPlugin().Name, 
            25000
            );
            return;
        }

        InstanceConfig instConfig;
        instConfig.id = _id;
        instConfig.mustReturn = _mustReturn;
        instConfig.returnType = _returnType.ToLower();
        instConfig.minMaxReturnAmount = _minmaxReturnAmount;
        instConfig.path = _path;
        instConfig.searchQuery = _searchQuery;
        instConfig.filters = _filters;
        instConfig.canOnlyReturn = _canOnlyReturn;

        FileExplorer@ newExplorer = FileExplorer(instConfig, _id);

        explorersByPlugin.Set(sessionKey, @newExplorer);

        newExplorer.Open(instConfig);
    }


    void fe_ForceClose(const string &in id = "*") {
        string pluginName = Meta::ExecutingPlugin().Name;
        
        if (id == "*") {
            array<string> keys = explorersByPlugin.GetKeys();
            for (uint i = 0; i < keys.Length; i++) {
                string sessionKey = keys[i];
                if (sessionKey.StartsWith(pluginName + "::")) {
                    FileExplorer@ explorer;
                    if (explorersByPlugin.Get(sessionKey, @explorer)) {
                        explorer.Close();
                    }
                }
            }
            log("All file explorer instances for this plugin have been closed.", LogLevel::Error, 3635, "fe_ForceClose");
            return;
        }

        string sessionKey = pluginName + "::" + id;
        FileExplorer@ explorer;
        if (explorersByPlugin.Get(sessionKey, @explorer)) {
            explorer.Close();
            explorersByPlugin.Delete(sessionKey);
            log("File explorer instance '" + id + "' has been closed.", LogLevel::Info, 3644, "fe_ForceClose");
        } else {
            NotifyError("Error", "Session ID '" + id + "' not found for this plugin.", 20000);
        }
    }
}

/* ------------------------ Functions / Variables that have to be in the global namespace ------------------------ */


// Sorry, but due to limitations in Openplanet the "Render" function has to be in the global namespace.
// If you are using this function in your own project please add ` FILE_EXPLORER_BASE_RENDERER ` to your own 
// render pipeline, usually one of the "Render", or "RenderInterface" functions.
// If this is not done, the File Explorer will not work as intended.

// ----- REMOVE THIS IF YOU HAVE ANY RENDER FUNCTION IN YOUR OWN CODE (also read the comment above) ----- //
/*
void RenderInterface() {
    FILE_EXPLORER_BASE_RENDERER();
}
*/
// ----- REMOVE THIS IF YOU HAVE ANY RENDER FUNCTION IN YOUR OWN CODE (also read the comment above) ----- //

void FILE_EXPLORER_BASE_RENDERER() {
    FileExplorer::RenderFileExplorer();
}


/* 
    ,---,.           ,--,                                                   
  ,'  .' |  ,--,   ,--.'|                                                   
,---.'   |,--.'|   |  | :                                                   
|   |   .'|  |,    :  : '                                                   
:   :  :  `--'_    |  ' |      ,---.                                        
:   |  |-,,' ,'|   '  | |     /     \                                       
|   :  ;/|'  | |   |  | :    /    /  |                                      
|   |   .'|  | :   '  : |__ .    ' / |                                      
'   :  '  '  : |__ |  | '.'|'   ;   /|                                      
|   |  |  |  | '.'|;  :    ;'   |  / |                                      
|   :  \  ;  :    ;|  ,   / |   :    |                                      
|   | ,'  |  ,   /  ---`-'   \   \  /                                       
`----'     ---`-'             `----'                                        
    ,---,.                        ,--,                                      
  ,'  .' |            ,-.----.  ,--.'|                                      
,---.'   |            \    /  \ |  | :     ,---.    __  ,-.          __  ,-.
|   |   .' ,--,  ,--, |   :    |:  : '    '   ,'\ ,' ,'/ /|        ,' ,'/ /|
:   :  |-, |'. \/ .`| |   | .\ :|  ' |   /   /   |'  | |' | ,---.  '  | |' |
:   |  ;/| '  \/  / ; .   : |: |'  | |  .   ; ,. :|  |   ,'/     \ |  |   ,'
|   :   .'  \  \.' /  |   |  \ :|  | :  '   | |: :'  :  / /    /  |'  :  /  
|   |  |-,   \  ;  ;  |   : .  |'  : |__'   | .; :|  | ' .    ' / ||  | '   
'   :  ;/|  / \  \  \ :     |`-'|  | '.'|   :    |;  : | '   ;   /|;  : |   
|   |    \./__;   ;  \:   : :   ;  :    ;\   \  / |  , ; '   |  / ||  , ;   
|   :   .'|   :/\  \ ;|   | :   |  ,   /  `----'   ---'  |   :    | ---'    
|   | ,'  `---'  `--` `---'.|    ---`-'                   \   \  /          
`----'                  `---`                              `----'          
*/
// Made with ❤️ by ar
