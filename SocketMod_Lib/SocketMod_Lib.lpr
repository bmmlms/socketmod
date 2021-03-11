library WhatsMissing_Lib;

uses
  Functions,
  Hooks,
  Log,
  GUILog,
  SysUtils,
  WinSock2,
  MMF,
  Windows,
  Constants;

{ R *.res}

var
  Log: TFileLog;
  MMFile: TMMF;
  GUILog: TGUILog;

procedure ProcessAttach;
begin
  try
    TFunctions.Init;

    MMFile := TMMF.Create;
    try
      MMFile.Read;
    except
      TFunctions.MessageBox(0, 'Unable to find running SocketMod instance.', 'SocketMod error', MB_ICONERROR);
      Exit;
    end;

    if MMFile.WriteLog then
      Log := TFileLog.Create(MMFile.LogFile)
    else
      Log := TNullLog.Create;

    GUILog := TGUILog.Create(MMFile.WindowHandle);

    GUILog.Info(Format('Initializing using address %s', [inet_ntoa(TInAddr(MMFile.Address))]));

    THooks.Initialize(Log, GUILog, MMFile);
  except
    on E: Exception do
    begin
      if Assigned(Log) then
        Log.Error(Format('Library: %s', [E.Message]));
      TFunctions.MessageBox(0, Format('Unexpected exception: %s', [E.Message]), 'SocketMod error', MB_ICONERROR);
      ExitProcess(1);
    end;
  end;
end;

procedure ProcessDetach;
begin
  THooks.Uninitialize;

  if Assigned(MMFile) then
    MMFile.Free;

  if Assigned(Log) then
    Log.Free;

  if Assigned(GUILog) then
    GUILog.Free;
end;

{$R *.res}

begin
  IsMultiThread := True;

  Dll_Process_Detach_Hook := @ProcessDetach;

  ProcessAttach;
end.

