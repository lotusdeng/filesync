module task.monitor;
import std.path;
import std.file;
import std.stdio;
import std.experimental.logger;
import core.thread;
import detached;
import task.runningprocess;

void taskMonitor()
{
    info("TaskMonitor start");
    while (true)
    {
        scope (exit)
            Thread.sleep(dur!("seconds")(5));
        try
        {
            string[string] taskExePaths = listTaskExe();
            string[string] taskResultPaths = listTaskResult();
            string[string] runningTaskExePaths = listRunningTask();
            foreach (taskName, taskExePath; taskExePaths)
            {
                if (taskName in taskResultPaths)
                {
                    trace("TaskMonitor task:", taskName,
                            " already have result.txt, already finish");
                    continue;
                }
                if (taskName in runningTaskExePaths)
                {
                    trace("TaskMonitor task:", taskName, " already running, but not finish");
                }
                info("TaskMonitor start task:", taskName);
                string taskDataDirPath = buildPath(dirName(thisExePath()),
                        "data/send/task", taskName);
                if (!exists(taskDataDirPath))
                {
                    info("TaskMonitor create dir:", taskDataDirPath);
                    mkdirRecurse(taskDataDirPath);
                }
                string stdoutFilePath = buildPath(dirName(thisExePath()),
                        "data/send/task", taskName, "stdout.txt");
                File stdoutFile = File(stdoutFilePath, "a");
                string stderrFilePath = buildPath(dirName(thisExePath()),
                        "data/send/task", taskName, "stderr.txt");
                File stderrFile = File(stderrFilePath, "a");
                string workingDirectory = buildPath(dirName(thisExePath),
                        "data/send/task", taskName);
                ulong pid;
                string[string] env;
                spawnProcessDetached([taskExePath], stdin, stdoutFile,
                        stderrFile, env, Config.none, workingDirectory, &pid);
                info("TaskMonitor start task, exe:", taskName, ", pid:", pid, ", exe:", taskExePath);

            }
        }
        catch (Exception e)
        {
            error("TaskMonitor exception:", e.toString());
        }
    }
}

string[string] listTaskExe()
{
    string[string] taskExePaths;
    string receiveTaskDirPath = buildPath(dirName(thisExePath), "data/receive/task");
    if (exists(receiveTaskDirPath) && isDir(receiveTaskDirPath))
    {
        foreach (dirItem; dirEntries(receiveTaskDirPath, SpanMode.shallow))
        {
            if (dirItem.isDir)
            {
                string taskName = baseName(dirItem.name);
                string taskExePath = buildPath(dirItem.name, taskName ~ ".exe");
                if (exists(taskExePath))
                {
                    File fd = File(taskExePath, "r");
                    if (fd.size > 0)
                    {
                        taskExePaths[taskName] = taskExePath;
                    }
                }
            }
        }
    }
    return taskExePaths;
}

string[string] listTaskResult()
{
    string[string] taskResultPaths;
    string sendTaskDirPath = buildPath(dirName(thisExePath), "data/send/task");
    if (exists(sendTaskDirPath) && isDir(sendTaskDirPath))
    {
        foreach (dirItem; dirEntries(sendTaskDirPath, SpanMode.shallow))
        {
            if (dirItem.isDir)
            {
                string taskName = baseName(dirItem.name);
                string taskResultPath = buildPath(dirItem.name, "result.txt");
                if (exists(taskResultPath))
                {
                    File fd = File(taskResultPath, "r");
                    if (fd.size > 0)
                    {
                        taskResultPaths[taskName] = taskResultPath;
                    }
                }
            }
        }
    }

    return taskResultPaths;
}

string[string] listTaskPid()
{
    string[string] taskPidPaths;
    string sendTaskDirPath = buildPath(dirName(thisExePath), "data/send/task");
    if (exists(sendTaskDirPath) && isDir(sendTaskDirPath))
    {
        foreach (dirItem; dirEntries(sendTaskDirPath, SpanMode.shallow))
        {
            if (dirItem.isDir)
            {
                string taskName = baseName(dirItem.name);
                string taskPidPath = buildPath(dirItem.name, "pid.txt");
                if (exists(taskPidPath))
                {
                    File fd = File(taskPidPath, "r");
                    if (fd.size > 0)
                    {
                        taskPidPaths[taskName] = taskPidPath;
                    }
                }
            }
        }
    }

    return listTaskPid;
}
