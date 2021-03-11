unit GUILog;

interface

uses
  SysUtils,
  Windows,
  Messages;

type
  TMessageTypes = (mtInfo, mtError, mtAction);

  { TGUILog }

  TGUILog = class
  private
    FWindowHandle: THandle;

    procedure Send(const Msg: string; const MsgType: TMessageTypes);
  public
    constructor Create(const WindowHandle: THandle); overload;

    procedure Info(const Msg: string);
    procedure Error(const Msg: string);
    procedure Action(const Msg: string);
  end;

implementation

{ TGUILog }

constructor TGUILog.Create(const WindowHandle: THandle);
begin
  FWindowHandle := WindowHandle;
end;

procedure TGUILog.Info(const Msg: string);
begin
  Send(Msg, mtInfo);
end;

procedure TGUILog.Error(const Msg: string);
begin
  Send(Msg, mtError);
end;

procedure TGUILog.Action(const Msg: string);
begin
  Send(Msg, mtAction);
end;

procedure TGUILog.Send(const Msg: string; const MsgType: TMessageTypes);
var
  CDS: TCOPYDATASTRUCT;
begin
  CDS.dwData := LongWord(MsgType);
  CDS.cbData := CharToByteLen(Msg, 1024) + 1;
  CDS.lpData := PChar(Msg);
  SendMessage(FWindowHandle, WM_COPYDATA, 0, LPARAM(@CDS));
end;

end.
