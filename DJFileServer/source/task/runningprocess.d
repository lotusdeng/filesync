module task.runningprocess;
import std.path;
import std.array;
import std.file;
import std.algorithm.searching;
version (Windows)
{
    import core.sys.windows.winbase;
    import core.sys.windows.windef;
    import core.sys.windows.psapi;
}

string[string] listRunningTask()
{
    string taskDirPath = buildPath(dirName(thisExePath()), "data/receive/task");
    taskDirPath = taskDirPath.replace("\\", "/");
    string[string] runningTasks;
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

                char[MAX_PATH] tmpExePath;
                DWORD exePathLen = MAX_PATH;
                ret = GetModuleFileNameExA(hProcess, NULL, tmpExePath.ptr, exePathLen);
                if (ret)
                {
                    string exePath = tmpExePath.dup;
                    exePath = exePath.replace("\\", "/");
                    if(startsWith(exePath, taskDirPath))
                    {
                        string taskName = dirName(exePath);
                        runningTasks[taskName] = exePath;
                    }
                }
            }

        }

    }
    else
    {

    }
    return runningTasks;
}
