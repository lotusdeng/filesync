import std.file;
import std.path;
import std.stdio;
import std.array;
import std.concurrency;
import std.process;
import std.experimental.logger;
import std.experimental.logger.core;
import model.appdata;
import syncserver;
import mylog;

void createDir()
{
	string receiveDirPath = buildPath(dirName(thisExePath()), "data", gAppData.localReceiveDir);
	if (!exists(receiveDirPath) || !isDir(receiveDirPath))
	{
		log("create dir:", receiveDirPath);
		mkdirRecurse(receiveDirPath);
	}

	string sendDirPath = buildPath(dirName(thisExePath()), "data", gAppData.localSendDir);
	if (!exists(sendDirPath) || !isDir(sendDirPath))
	{
		log("create dir:", sendDirPath);
		mkdirRecurse(sendDirPath);
	}

	string logDirPath = buildPath(dirName(thisExePath()), "data", "log");
	if (!exists(logDirPath) || !isDir(logDirPath))
	{
		log("create dir:", logDirPath);
		mkdirRecurse(logDirPath);
	}
}

void createLog()
{
	string logFilePath = buildPath(dirName(thisExePath()), "data", "log", "fileclient.txt");
	auto multiLog = new MultiLogger();
	multiLog.insertLogger("fileLog", new MyFileLogger(new FileLogger(logFilePath)));
	multiLog.insertLogger("consoleLog", new MyConsoleLogger(LogLevel.info));
	sharedLog = multiLog;
}

void main(string[] args)
{
	createDir();
	createLog();
	
	info("--------------------------------------------------------");
	info("fileclient start, processid:", thisProcessID(), ", version:", gAppData.appVersion);
	string[] remoteServers = args[1 .. args.length];

	foreach (remoteServer; remoteServers)
	{
		spawn(&syncRemoteServerThread, remoteServer, buildPath(dirName(thisExePath()), "data", gAppData.localSendDir),
				buildPath(dirName(thisExePath()), "data", gAppData.localReceiveDir, remoteServer.replace(":", "_")),
				 gAppData.remoteSendDir, gAppData.remoteReceiveDir);
	}
}
