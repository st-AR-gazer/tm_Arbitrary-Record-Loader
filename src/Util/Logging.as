string pluginName = Meta::ExecutingPlugin().Name;

enum LogLevel { Debug, Info, Notice, Warning, Error, Critical, Custom }

void NotifyAndLog(const string &in msg, const string &in pn, const vec4 &in col, int t, LogLevel level) {
    UI::ShowNotification(pn, msg, col, t);

    string logMsg = msg;
    if (pn.Length > 0 && pn != pluginName) {
        logMsg = "[" + pn + "] " + msg;
    }

    log(logMsg, level, -1, "Notify", "Notifications", "\\$8cf");
}

void NotifyDebug   (const string &in msg="", const string &in pn=pluginName, int t=6000){ NotifyAndLog(msg, pn, vec4(.5,.5,.5,.3), t, LogLevel::Debug); }
void NotifyInfo    (const string &in msg="", const string &in pn=pluginName, int t=6000){ NotifyAndLog(msg, pn, vec4(.2,.8,.5,.3), t, LogLevel::Info); }
void NotifyNotice  (const string &in msg="", const string &in pn=pluginName, int t=6000){ NotifyAndLog(msg, pn, vec4(.2,.8,.5,.3), t, LogLevel::Notice); }
void NotifyWarning (const string &in msg="", const string &in pn=pluginName, int t=6000){ NotifyAndLog(msg, pn, vec4(1,.5,.1,.5), t, LogLevel::Warning); }
void NotifyError   (const string &in msg="", const string &in pn=pluginName, int t=6000){ NotifyAndLog(msg, pn, vec4(1,.2,.2,.3), t, LogLevel::Error); }
void NotifyCritical(const string &in msg="", const string &in pn=pluginName, int t=6000){ NotifyAndLog(msg, pn, vec4(1,.2,.2,.3), t, LogLevel::Critical); }

namespace logging {

    [Setting category="z~DEV" name="Write a copy of each log line to file" hidden]
    bool S_writeLogToFile = false;

    /***********************************************/
    [Setting category="z~DEV" name="Show default OP logs" hidden] bool S_showDefaultLogs = true;
    /***********************************************/ // Change this wen using _build.py


    [Setting category="z~DEV" name="Show Custom logs"   hidden] bool DEV_S_sCustom   = false;
    [Setting category="z~DEV" name="Show Debug logs"    hidden] bool DEV_S_sDebug    = false;
    [Setting category="z~DEV" name="Show Info logs"     hidden] bool DEV_S_sInfo     = true;
    [Setting category="z~DEV" name="Show Notice logs"   hidden] bool DEV_S_sNotice   = true;
    [Setting category="z~DEV" name="Show Warning logs" hidden] bool DEV_S_sWarning  = true;
    [Setting category="z~DEV" name="Show Error logs"    hidden] bool DEV_S_sError    = true;
    [Setting category="z~DEV" name="Show Critical logs" hidden] bool DEV_S_sCritical = true;

    [Setting category="z~DEV" name="Set log level" min="0" max="5" hidden] int DEV_S_sLogLevelSlider = 0;

    [Setting category="z~DEV" name="Show function name in logs" hidden] bool S_showFunctionNameInLogs = true;
    [Setting category="z~DEV" name="Set max function name length in logs" min="0" max="50" hidden] int S_maxFunctionNameLength = 15;
    [Setting category="z~DEV" name="Show context in logs" hidden] bool S_showContextInLogs = true;
    [Setting category="z~DEV" name="Set max context length in logs" min="0" max="50" hidden] int S_maxContextLength = 20;

    const string kLogsFolder      = "Logs/";
    const string kDiagPrefix      = "diagnostics_";
    const string kLatestBuildFile = "latest_build.txt";
    const string kBuildJsonFile   = "build.json";
    const uint   kRetentionDays   = 14;
    const uint   kOneDayMs        = 86400000; // 24h in ms
    const string kDefaultContextColor = "\\$888";

    string g_diagFilePath;
    dictionary g_contextColors;

    /* settings UI tab */
    [SettingsTab name="Logs" icon="DevTo" order="99999999999999999999999999999999999999999999999999"]
    void RT_LOGs() {
        if (UI::BeginChild("Logging Settings", vec2(0, 0), true)) {
            UI::Text("Logging Options"); UI::Separator();

            S_showDefaultLogs = UI::Checkbox("Show default OP logs", S_showDefaultLogs);
            S_writeLogToFile  = UI::Checkbox("Write a copy of each log line to file", S_writeLogToFile);
            DEV_S_sDebug      = UI::Checkbox("Show Debug logs",      DEV_S_sDebug);
            DEV_S_sInfo       = UI::Checkbox("Show Info logs",       DEV_S_sInfo);
            DEV_S_sNotice     = UI::Checkbox("Show Notice logs",     DEV_S_sNotice);
            DEV_S_sWarning    = UI::Checkbox("Show Warning logs",    DEV_S_sWarning);
            DEV_S_sError      = UI::Checkbox("Show Error logs",      DEV_S_sError);
            DEV_S_sCritical   = UI::Checkbox("Show Critical logs",   DEV_S_sCritical);

            int newSlider = UI::SliderInt("Set log level", DEV_S_sLogLevelSlider, 0, 5);
            if (newSlider != DEV_S_sLogLevelSlider) {
                DEV_S_sLogLevelSlider = newSlider;

                switch (DEV_S_sLogLevelSlider) {
                    case 0: DEV_S_sDebug=true;  DEV_S_sCustom=true;  DEV_S_sInfo=true;  DEV_S_sNotice=true;  DEV_S_sWarning=true;  DEV_S_sError=true; DEV_S_sCritical=true; break;
                    case 1: DEV_S_sDebug=false; DEV_S_sCustom=true;  DEV_S_sInfo=true;  DEV_S_sNotice=true;  DEV_S_sWarning=true;  DEV_S_sError=true; DEV_S_sCritical=true; break;
                    case 2: DEV_S_sDebug=false; DEV_S_sCustom=false; DEV_S_sInfo=true;  DEV_S_sNotice=true;  DEV_S_sWarning=true;  DEV_S_sError=true; DEV_S_sCritical=true; break;
                    case 3: DEV_S_sDebug=false; DEV_S_sCustom=false; DEV_S_sInfo=false; DEV_S_sNotice=true;  DEV_S_sWarning=true;  DEV_S_sError=true; DEV_S_sCritical=true; break;
                    case 4: DEV_S_sDebug=false; DEV_S_sCustom=false; DEV_S_sInfo=false; DEV_S_sNotice=false; DEV_S_sWarning=true;  DEV_S_sError=true; DEV_S_sCritical=true; break;
                    case 5: DEV_S_sDebug=false; DEV_S_sCustom=false; DEV_S_sInfo=false; DEV_S_sNotice=false; DEV_S_sWarning=false; DEV_S_sError=true; DEV_S_sCritical=true; break;
                }
            }

            UI::Separator();
            UI::Text("Function Name Settings");
            S_showFunctionNameInLogs = UI::Checkbox("Show function name in logs", S_showFunctionNameInLogs);
            S_maxFunctionNameLength  = UI::SliderInt("Set max function name length", S_maxFunctionNameLength, 0, 50);

            UI::Separator();
            UI::Text("Context Settings");
            S_showContextInLogs = UI::Checkbox("Show context in logs", S_showContextInLogs);
            S_maxContextLength  = UI::SliderInt("Set max context length", S_maxContextLength, 0, 50);

            UI::EndChild();
        }
    }
    
    void AppendToDiagFile(const string &in line) {
        if (!S_writeLogToFile) return;

        if (g_diagFilePath.Length == 0) SetDiagFilePath();

        string absLogs = IO::FromStorageFolder(kLogsFolder);
        if (!IO::FolderExists(absLogs)) IO::CreateFolder(absLogs);

        IO::File f;
        f.Open(g_diagFilePath, IO::FileMode::Append);
        f.Write(line + "\n");
        f.Close();
    }

    void RotateOldLogFiles() {
        string absFolder = IO::FromStorageFolder(kLogsFolder);
        array<string>@ files = IO::IndexFolder(absFolder, /*recursive=*/false);

        int64 earliestMs = Time::Now - int64(kRetentionDays - 1) * kOneDayMs;
        if (earliestMs < 0) earliestMs = 0;
        string earliestKeep = Time::FormatString("%Y-%m-%d", earliestMs);

        for (uint i = 0; i < files.Length; i++) {
            string fullPath = files[i];
            if (!fullPath.EndsWith(".log")) continue;

            string baseName = fullPath.SubStr(absFolder.Length);
            if (!baseName.StartsWith(kDiagPrefix)) continue;

            string dateStr = baseName.SubStr(kDiagPrefix.Length, 10);  // YYYY-MM-DD
            if (dateStr < earliestKeep) IO::Delete(fullPath);
        }
    }

    void SetDiagFilePath() {
        string today = Time::FormatString("%Y-%m-%d");
        g_diagFilePath = IO::FromStorageFolder(kLogsFolder + kDiagPrefix + today + ".log");
    }

    void UpdateBuildFiles() {
        string curVer  = Meta::ExecutingPlugin().Version;
        string latestP = IO::FromStorageFolder(kLogsFolder + kLatestBuildFile);

        string prevVer;
        if (IO::FileExists(latestP)) {
            IO::File f;
            f.Open(latestP, IO::FileMode::Read);
            prevVer = f.ReadLine().Trim();
            f.Close();
        }

        if (curVer == prevVer) return;

        IO::File f;
        f.Open(latestP, IO::FileMode::Write);
        f.WriteLine(curVer);
        f.WriteLine("Updated: " + Time::FormatString("%Y-%m-%d %H:%M:%S"));
        f.Close();

        Json::Value j = Json::Object();
        j["name"]      = Meta::ExecutingPlugin().Name;
        j["version"]   = curVer;
        j["updatedAt"] = Time::FormatString("%Y-%m-%dT%H:%M:%SZ");
        j["author"]    = Meta::ExecutingPlugin().Author;

        IO::File jf;
        jf.Open(IO::FromStorageFolder(kLogsFolder + kBuildJsonFile), IO::FileMode::Write);
        jf.Write(Json::Write(j, true));
        jf.Close();
    }

    string _Tag(const string &in txt, const string &in col, int width = 7) {
        string t = txt.ToUpper();
        if (width < 0) width = 0;
        if (width > 0 && t.Length > width) t = t.SubStr(0, width);
        while (t.Length < width) t += " ";
        return col + "[" + t + "] ";
    }

    string NormalizeContext(const string &in context) {
        return context.Trim();
    }

    void RegisterContextColor(const string &in context, const string &in color) {
        string normalized = NormalizeContext(context);
        if (normalized.Length == 0 || color.Length == 0) return;
        g_contextColors[normalized] = color;
    }

    string ResolveContextColor(const string &in context, const string &in overrideColor = "") {
        string normalized = NormalizeContext(context);
        if (normalized.Length == 0) return "";

        if (overrideColor.Length > 0) {
            RegisterContextColor(normalized, overrideColor);
            return overrideColor;
        }

        if (g_contextColors.Exists(normalized)) {
            return string(g_contextColors[normalized]);
        }

        return kDefaultContextColor;
    }

    string FormatLineInfo(int line) {
        string lineInfo = line >= 0 ? tostring(line) : "-";
        while (lineInfo.Length < 4) lineInfo = " " + lineInfo;
        return lineInfo;
    }

    string FormatFunctionName(const string &in fnName) {
        if (!S_showFunctionNameInLogs) return "";

        string formatted = fnName;
        if (formatted.Length > S_maxFunctionNameLength) formatted = formatted.SubStr(0, S_maxFunctionNameLength);
        while (formatted.Length < S_maxFunctionNameLength) formatted += " ";
        return formatted;
    }

    string FormatContextTag(const string &in context, const string &in contextColor = "") {
        if (!S_showContextInLogs) return "";

        string normalized = NormalizeContext(context);
        if (normalized.Length == 0) return "";

        return _Tag(normalized, ResolveContextColor(normalized, contextColor), S_maxContextLength);
    }

    string GetLevelTag(LogLevel level) {
        switch (level) {
            case LogLevel::Debug:    return "\\$0ff[DEBUG]   ";
            case LogLevel::Info:     return "\\$0f0[INFO]    ";
            case LogLevel::Notice:   return "\\$0ff[NOTICE]  ";
            case LogLevel::Warning:  return "\\$ff0[WARNING] ";
            case LogLevel::Error:    return "\\$f00[ERROR]   ";
            case LogLevel::Critical: return "\\$f00\\$o\\$i\\$w[CRITICAL]";
            case LogLevel::Custom:   return "\\$f80[CUSTOM]  ";
        }
        return "\\$fff[LOG]     ";
    }

    string GetLevelBodyColor(LogLevel level) {
        switch (level) {
            case LogLevel::Debug:    return "\\$0cc";
            case LogLevel::Info:     return "\\$0c0";
            case LogLevel::Notice:   return "\\$0cc";
            case LogLevel::Warning:  return "\\$cc0";
            case LogLevel::Error:    return "\\$c00";
            case LogLevel::Critical: return "\\$f00\\$o\\$i\\$w";
            case LogLevel::Custom:   return "\\$f80";
        }
        return "\\$fff";
    }

    bool IsLevelEnabled(LogLevel level) {
        switch (level) {
            case LogLevel::Debug:    return DEV_S_sDebug;
            case LogLevel::Info:     return DEV_S_sInfo;
            case LogLevel::Notice:   return DEV_S_sNotice;
            case LogLevel::Warning:  return DEV_S_sWarning;
            case LogLevel::Error:    return DEV_S_sError;
            case LogLevel::Critical: return DEV_S_sCritical;
            case LogLevel::Custom:   return DEV_S_sCustom;
        }
        return true;
    }

    string BuildFormattedLine(const string &in msg,
                              LogLevel level,
                              int line,
                              const string &in fnName,
                              const string &in context = "",
                              const string &in contextColor = "")
    {
        string levelTag = GetLevelTag(level);
        string contextTag = FormatContextTag(context, contextColor);
        string bodyColor = GetLevelBodyColor(level);
        string lineInfo = FormatLineInfo(line);
        string fnInfo = FormatFunctionName(fnName);

        string fields = lineInfo;
        if (fnInfo.Length > 0) fields += " : " + fnInfo;

        return levelTag + contextTag + "\\$z" + bodyColor + fields + " : \\$z" + msg;
    }

    void Initialise() {
        string absLogs = IO::FromStorageFolder(kLogsFolder);
        if (!IO::FolderExists(absLogs)) IO::CreateFolder(absLogs);

        RotateOldLogFiles();
        SetDiagFilePath();
        UpdateBuildFiles();
    }

}

void _log_impl(const string &in msg,
               LogLevel level,
               int line,
               const string &in fnName,
               const string &in context = "",
               const string &in contextColor = "")
{
    string full = logging::BuildFormattedLine(msg, level, line, fnName, context, contextColor);
    string plain = Text::StripOpenplanetFormatCodes(full);
    string ts = Time::FormatString("%Y-%m-%d %H:%M:%S  ");
    logging::AppendToDiagFile(ts + plain);

    if (!logging::IsLevelEnabled(level)) return;

    if (logging::S_showDefaultLogs && level != LogLevel::Custom) {
        switch (level) {
            case LogLevel::Warning:  warn(plain); break;
            case LogLevel::Error:
            case LogLevel::Critical: error(plain); break;
            default:                 trace(plain); break;
        }
        return;
    }

    print(full);
}

void log(const string &in msg, LogLevel level, int line, const string &in fnName) {
    _log_impl(msg, level, line, fnName);
}

void log(const string &in msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    _log_impl(msg, level, line, fnName, context);
}

void log(const string &in msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    _log_impl(msg, level, line, fnName, context, contextColor);
}

void log(int msg, LogLevel level, int line, const string &in fnName) {
    log(tostring(msg), level, line, fnName);
}

void log(int msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    log(tostring(msg), level, line, fnName, context);
}

void log(int msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    log(tostring(msg), level, line, fnName, context, contextColor);
}

void log(uint msg, LogLevel level, int line, const string &in fnName) {
    log(tostring(msg), level, line, fnName);
}

void log(uint msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    log(tostring(msg), level, line, fnName, context);
}

void log(uint msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    log(tostring(msg), level, line, fnName, context, contextColor);
}

void log(int64 msg, LogLevel level, int line, const string &in fnName) {
    log(tostring(msg), level, line, fnName);
}

void log(int64 msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    log(tostring(msg), level, line, fnName, context);
}

void log(int64 msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    log(tostring(msg), level, line, fnName, context, contextColor);
}

void log(uint64 msg, LogLevel level, int line, const string &in fnName) {
    log(tostring(msg), level, line, fnName);
}

void log(uint64 msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    log(tostring(msg), level, line, fnName, context);
}

void log(uint64 msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    log(tostring(msg), level, line, fnName, context, contextColor);
}

void log(float msg, LogLevel level, int line, const string &in fnName) {
    log(tostring(msg), level, line, fnName);
}

void log(float msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    log(tostring(msg), level, line, fnName, context);
}

void log(float msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    log(tostring(msg), level, line, fnName, context, contextColor);
}

void log(double msg, LogLevel level, int line, const string &in fnName) {
    log(tostring(msg), level, line, fnName);
}

void log(double msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    log(tostring(msg), level, line, fnName, context);
}

void log(double msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    log(tostring(msg), level, line, fnName, context, contextColor);
}

void log(bool msg, LogLevel level, int line, const string &in fnName) {
    log(msg ? "true" : "false", level, line, fnName);
}

void log(bool msg, LogLevel level, int line, const string &in fnName, const string &in context) {
    log(msg ? "true" : "false", level, line, fnName, context);
}

void log(bool msg, LogLevel level, int line, const string &in fnName, const string &in context, const string &in contextColor) {
    log(msg ? "true" : "false", level, line, fnName, context, contextColor);
}

// Plugin entry for the logging
auto logging_initializer = startnew(logging::Initialise);
// Unload handler to unregister the module
// class logging_OnUnload { ~logging_OnUnload() { print("run this if I ever need to unload something in the logging"); } }
// logging_OnUnload logging_unloader;
