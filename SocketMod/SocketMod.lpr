program SocketMod;

uses
  Forms,
  Interfaces,
  MainForm,
  Functions,
  Constants,
  MMF,
  SysUtils,
  WinSock2,
  Windows;

{$R *.res}
{$R resources.rc}

var
  Data: TWSAData;
  MMFile: TMMF;
  MainForm: TfrmMain;
begin
  IsMultiThread := True;

  try
    TFunctions.Init;

    if TMMF.Exists(APP_NAME) then
    begin
      MMFile := TMMF.Create;
      try
        MMFile.Read;

        SetForegroundWindow(MMFile.WindowHandle);

        Exit;
      finally
        MMFile.Free;
      end;
    end;

    if WSAStartup(MakeWord(2, 2), Data) = SOCKET_ERROR then
      raise Exception.Create('Error initializing Winsock.');

    if not TFunctions.GetDebugPrivilege then
      TFunctions.MessageBox(0, 'Unable to aquire debug privilege. If an application does not work with SocketMod start SocketMod as administrator.', 'Error', MB_ICONERROR);

    Application.Initialize;
    Application.CaptureExceptions := False;
    Application.Title := APP_NAME;
    Application.CreateForm(TfrmMain, MainForm);
    Application.Run;

    WSACleanup;
  except
    on E: Exception do
    begin
      if not E.Message.EndsWith('.') then
        E.Message := E.Message + '.';

      TFunctions.MessageBox(0, Format('%s encountered an error: %s', [APP_NAME, E.Message]), 'Error', MB_ICONERROR);

      ExitProcess(1);
    end;
  end;
end.
