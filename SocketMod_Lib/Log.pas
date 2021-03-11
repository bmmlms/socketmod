unit Log;

interface

uses
  Functions,
  SysUtils,
  Windows;

type
  TFileLog = class
  private
    FFileName: string;
    FHandle: THandle;
  protected
    procedure Write(const Msg: string); virtual;
  public
    constructor Create(const Filename: string);
    destructor Destroy; override;
    procedure Info(const Msg: string);
    procedure Debug(const Msg: string);
    procedure Error(const Msg: string);

    property FileName: string read FFileName;
    property Handle: THandle read FHandle;
  end;

  { TNullLog }

  TNullLog = class(TFileLog)
  protected
    procedure Write(const Msg: string); override;
  public
    constructor Create;
    destructor Destroy; override;
  end;

const
  UTF8_BOM: array[0..2] of Byte = ($EF, $BB, $BF);

implementation

{ TFileLog }

constructor TFileLog.Create(const FileName: string);
var
  W: Cardinal;
  Handle: THandle;
begin
  FFileName := FileName;

  Handle := TFunctions.CreateFile(FileName, FILE_APPEND_DATA, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if Handle = INVALID_HANDLE_VALUE then
    raise Exception.Create(Format('Error opening log file "%s"', [FileName]));
  if GetLastError <> ERROR_ALREADY_EXISTS then
    WriteFile(Handle, UTF8_BOM[0], Length(UTF8_BOM), W, nil);
  SetHandleInformation(Handle, HANDLE_FLAG_INHERIT, 1);
  FHandle := Handle;
end;

destructor TFileLog.Destroy;
begin
  CloseHandle(FHandle);

  inherited;
end;

procedure TFileLog.Debug(const Msg: string);
begin
  Write(Format('%s - %s', ['DEBUG', Msg]));
end;

procedure TFileLog.Info(const Msg: string);
begin
  Write(Format('%s - %s', ['INFO', Msg]));
end;

procedure TFileLog.Error(const Msg: string);
begin
  Write(Format('%s - %s', ['ERROR', Msg]));
end;

procedure TFileLog.Write(const Msg: string);
var
  W: Cardinal;
  Bytes: TBytes;
begin
  if (FHandle = 0) or (FHandle = INVALID_HANDLE_VALUE) then
    raise Exception.Create('Log file not opened');

  Bytes := TEncoding.UTF8.GetBytes(Format('%s - [%d] - %s'#13#10, [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), GetCurrentProcessId, Msg]));

  WriteFile(FHandle, Bytes[0], Length(Bytes), W, nil);
end;

{ TNullLog }

constructor TNullLog.Create;
begin

end;

destructor TNullLog.Destroy;
begin
  inherited;
end;

procedure TNullLog.Write(const Msg: string);
begin

end;

end.
