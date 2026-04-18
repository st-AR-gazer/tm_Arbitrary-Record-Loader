namespace PluginState {
    Meta::Plugin@ FindLoadedPlugin(const string &in pluginId = "", const string &in pluginName = "") {
        auto plugins = Meta::AllPlugins();
        for (uint i = 0; i < plugins.Length; i++) {
            auto plugin = plugins[i];
            if (plugin is null || !plugin.Enabled) continue;
            if (pluginId.Length > 0 && plugin.ID == pluginId) return plugin;
            if (pluginName.Length > 0 && plugin.Name == pluginName) return plugin;
        }
        return null;
    }

    bool IsPluginLoaded(const string &in pluginId = "", const string &in pluginName = "") {
        return FindLoadedPlugin(pluginId, pluginName) !is null;
    }
}
