namespace Integrations {
namespace GameLoader {

    string _ResolveLocalType(const string &in filePath) {
        string ext = Path::GetExtension(filePath).ToLower();
        if (ext != ".gbx") return ext;

        int secondLastDotIndex = _Text::NthLastIndexOf(filePath, ".", 2);
        int lastDotIndex = filePath.LastIndexOf(".");
        if (secondLastDotIndex != -1 && lastDotIndex > secondLastDotIndex) {
            return filePath.SubStr(secondLastDotIndex + 1, lastDotIndex - secondLastDotIndex - 1).ToLower();
        }
        return ext;
    }

    void LoadLocalFile(const string &in filePath) {
        if (!IO::FileExists(filePath)) {
            NotifyError("File does not exist.");
            return;
        }

        string fileType = _ResolveLocalType(filePath);
        if (fileType == "replay") {
            ReplayLoader::LoadReplayFromPath(filePath);
        } else if (fileType == "ghost") {
            GhostLoader::LoadGhostFromLocalFile(filePath);
        } else {
            log("Unsupported file type: " + fileType + " Full path: " + filePath, LogLevel::Error, 28, "LoadLocalFile");
            NotifyWarning("Error | Unsupported file type.");
        }
    }
}
}
