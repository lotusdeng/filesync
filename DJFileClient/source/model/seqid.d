module model.seqid;
import core.atomic;
import std.conv;

shared ulong gSeqId;

ulong getSeqIdInteger()
{
    return atomicOp!("+=")(gSeqId, 1) - 1;
}

string getSeqIdStr()
{
    return to!string(getSeqIdInteger());
}
