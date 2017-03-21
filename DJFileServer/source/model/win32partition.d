module model.win32partition;
import std.stdio;
import std.string;
import std.conv;
import core.sys.windows.windef;
import core.sys.windows.winbase;

version (Windows)
{
  
    string[] listPartition()
    {
		string[] partitions;
		//char driveNames[MAX_PATH] = { 0 };
		char[] driveNames = new char[MAX_PATH];
		char* tempBuf = cast(char*)driveNames.toStringz;
		DWORD len = GetLogicalDriveStringsA(MAX_PATH, tempBuf);
		writeln(len);
		uint parititionCount = len / 4;
		for(uint i = 0; i < parititionCount; ++i)
		{
			char* partitionBuf = tempBuf + i * 4;
			string partition = to!string(partitionBuf);
			partitions ~= partition;
		}
		
		return partitions;
    }

    unittest
    {
        string[] partitions = listPartition();
    }
}

