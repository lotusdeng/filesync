module task.runningprocess;
import std.path;
import std.array;
import std.stdio;
import std.file;
import std.conv;
import std.algorithm.searching;

version (Windows)
{
	import core.sys.windows.winbase;
	import core.sys.windows.windef;
	import core.sys.windows.psapi;
}

struct ProcessInfo
{
	uint processId;
	string exePath;
}

ProcessInfo[] listRunningProcess()
{
	ProcessInfo[] processInfos;
	version (Windows)
	{
		DWORD[1024] processIds;
		DWORD cbNeeded;
		BOOL ret = EnumProcesses(processIds.ptr, processIds.length * DWORD.sizeof, &cbNeeded);
		if (ret)
		{
			DWORD processCount = cbNeeded / DWORD.sizeof;
			foreach (i; 0 .. processCount)
			{
				DWORD processId = processIds[i];
				HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
						FALSE, processId);
				if (hProcess == NULL)
				{
					continue;
				}

				char[MAX_PATH] exePath;
				DWORD exePathLen = MAX_PATH;
				ret = GetModuleFileNameExA(hProcess, NULL, exePath.ptr, exePathLen);
				if (ret)
				{
					ProcessInfo processInfo;
					processInfo.processId = processId;
					processInfo.exePath = exePath.dup;
					processInfos ~= processInfo;

				}
			}

		}

	}
	else
	{

	}
	return processInfos;
}

void main()
{
	scope(exit)
	{
		std.file.write("result.txt", "success");
	}

	ProcessInfo[] processInfos = listRunningProcess();
	File dataFd = File("data.txt", "w");
	foreach(processInfo; processInfos)
	{
		dataFd.writeln(to!(string)(processInfo.processId) ~ " " ~ processInfo.exePath);
	}
}
