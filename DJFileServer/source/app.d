import std.stdio;
import std.file;
import std.utf;
import std.conv;
import std.path;
import std.array;
import std.exception;
import std.algorithm;
import std.string;
import std.experimental.logger;
import std.process;
import model.appdata;
import rest.server;
import mylog;


void createDir()
{
	gAppData.serverDataDirPath = buildPath(dirName(thisExePath()), "data");
	if (!exists(gAppData.serverDataDirPath) || !isDir(gAppData.serverDataDirPath))
	{
		info("create dir:", gAppData.serverDataDirPath);
		mkdir(gAppData.serverDataDirPath);
	}
	gAppData.serverSendDirPath = buildPath(gAppData.serverDataDirPath, "send");
	if (!exists(gAppData.serverSendDirPath) || !isDir(gAppData.serverSendDirPath))
	{
		info("create dir:", gAppData.serverSendDirPath);
		mkdir(gAppData.serverSendDirPath);
	}
	gAppData.serverReceiveDirPath = buildPath(gAppData.serverDataDirPath, "receive");
	if (!exists(gAppData.serverReceiveDirPath) || !isDir(gAppData.serverReceiveDirPath))
	{
		info("create dir:", gAppData.serverReceiveDirPath);
		mkdir(gAppData.serverReceiveDirPath);
	}
}


void createLog()
{
	string logDirPath = buildPath(dirName(thisExePath()), "data/log");
	if(!exists(logDirPath) || !isDir(logDirPath))
	{
		info("create dir:", logDirPath);
		mkdirRecurse(logDirPath);
	}
	string logFilePath = buildPath(dirName(thisExePath()), "data", "log", "fileserver.txt");
	auto multiLog = new MultiLogger();
	multiLog.insertLogger("fileLog", new MyFileLogger(new FileLogger(logFilePath)));
	multiLog.insertLogger("consoleLog", new MyConsoleLogger(LogLevel.info));
	sharedLog = multiLog;
}


void main(string[] args)
{
	createLog();
	info("--------------------------------------------------------");
	info("fileserver start, processid:", thisProcessID(), ", version:", gAppData.appVersion);
	createDir();
	gAppData.exePath = thisExePath();
	gAppData.listenPort = 8080;
	if (args.length >= 2)
	{
		gAppData.listenPort = to!ushort(args[1]);
	}
	
	info("listen port:", gAppData.listenPort);
	
	startRESTServer(gAppData.listenPort);
}
