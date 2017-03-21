module model.appdata;


struct AppData
{
    string exePath;
	ulong processStartTimepoint;
	string appVersion = "0.1.0";
	string compileDateTime;
	string logFilePath;
	int threadCountAfterStart;
	ushort listenPort;
	string serverDataDirPath;// ./data
	string serverReceiveDirPath; // ./data/receive
	string serverSendDirPath; // ./data/second
}

__gshared AppData gAppData;