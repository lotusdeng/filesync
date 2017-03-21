module model.appdata;


struct AppData
{
    string appVersion = "0.1.0";
    string localSendDir = "send";
    string remoteReceiveDir = "receive";
    string localReceiveDir = "receive";
    string remoteSendDir = "send";
    uint syncPeriodBySecond = 5;
    ulong seqId;
}


shared AppData gAppData;
 