void Initializations() {
    CreateFolders();
    InitClasses();
    startnew(Server::StartHttpServer);

    EntryPoints::Official::Official::Init();
    EntryPoints::Official::Campaign::Init();

    startnew(MapTracker::MapMonitor);
}

void InitClasses() {
    @api = NadeoApi();
    @loadRecord = LoadRecord();
}

void CreateFolders() {
    IO::CreateFolder(Server::replayARL, true);
    IO::CreateFolder(Server::replayARLTmp, true);
    IO::CreateFolder(Server::replayARLDummy, true);
    IO::CreateFolder(Server::replayARLAutoMove, true);

    IO::CreateFolder(Server::serverDirectory, true);
    IO::CreateFolder(Server::storedFilesDirectory, true);
    IO::CreateFolder(Server::serverDirectoryAutoMove, true);

    IO::CreateFolder(Server::currentMapRecords, true);

    IO::CreateFolder(Server::linksDirectory, true);

    IO::CreateFolder(Server::specificDownloadedJsonFilesDirectory, true);
    IO::CreateFolder(Server::specificDownloadedCreatedProfilesDirectory, true);
        
    IO::CreateFolder(Server::officialInfoFilesDirectory, true);
    IO::CreateFolder(Server::officialJsonFilesDirectory, true);
}
