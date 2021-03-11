unit MMF;

interface

uses
  Classes,
  Constants,
  SysUtils,
  Windows;

type
  TMMFStream = class(TMemoryStream)
  private
    FCapacity: PtrInt;
  protected
    function Realloc(var NewCapacity: PtrInt): Pointer; override;
    property Capacity: PtrInt read FCapacity write FCapacity;
  end;

  TMMFBase = class
  private
    FCriticalSection: TCriticalSection;
    FHandle: THandle;
    FName: string;

    procedure InitSecurityAttributes(const PSA: PSecurityAttributes; const PSD: PSecurityDescriptor);
  protected
    procedure ReadStream(const MS: TMemoryStream); virtual; abstract;
    procedure WriteStream(const MS: TMemoryStream); virtual; abstract;
  public
    class function Exists(const Name: string): Boolean; static;

    constructor Create(const Name: string; const Handle: THandle);
    destructor Destroy; override;

    procedure Read;
    procedure Write;

    property Handle: THandle read FHandle;
  end;

  TMMF = class(TMMFBase)
  private
    FWindowHandle: UInt64;
    FWriteLog: Boolean;
    FAddress: Cardinal;
    FLogFile: string;
  protected
    procedure ReadStream(const MS: TMemoryStream); override;
    procedure WriteStream(const MS: TMemoryStream); override;
  public
    constructor Create;

    property WindowHandle: UInt64 read FWindowHandle write FWindowHandle;
    property WriteLog: Boolean read FWriteLog write FWriteLog;
    property Address: Cardinal read FAddress write FAddress;
    property LogFile: string read FLogFile write FLogFile;
  end;

implementation

const
  MMF_SIZE = 8192;

function CreateFileMappingS(hFile: HANDLE; lpFileMappingAttributes: LPSECURITY_ATTRIBUTES; flProtect: DWORD; dwMaximumSizeHigh: DWORD; dwMaximumSizeLow: DWORD; lpName: string): HANDLE;
var
  Name: UnicodeString;
begin
  Name := lpName;
  Result := CreateFileMappingW(hFile, lpFileMappingAttributes, flProtect, dwMaximumSizeHigh, dwMaximumSizeLow, IfThen<PWideChar>(Name = '', nil, PWideChar(Name)));
end;

function OpenFileMappingS(dwDesiredAccess: DWORD; bInheritHandle: WINBOOL; lpName: string): HANDLE;
var
  Name: UnicodeString;
begin
  Name := lpName;
  Result := OpenFileMappingW(dwDesiredAccess, bInheritHandle, IfThen<PWideChar>(Name = '', nil, PWideChar(Name)));
end;

{ TMMFBase }

class function TMMFBase.Exists(const Name: string): Boolean;
var
  Handle: THandle;
begin
  Handle := OpenFileMappingS(FILE_MAP_READ, False, Name);
  if Handle = 0 then
    Exit(False)
  else
  begin
    CloseHandle(Handle);
    Exit(True);
  end;
end;

constructor TMMFBase.Create(const Name: string; const Handle: THandle);
begin
  InitializeCriticalSection(FCriticalSection);

  FName := Name;
  FHandle := Handle;
end;

destructor TMMFBase.Destroy;
begin
  if FHandle > 0 then
    CloseHandle(FHandle);

  DeleteCriticalSection(FCriticalSection);

  inherited;
end;

procedure TMMFBase.InitSecurityAttributes(const PSA: PSecurityAttributes; const PSD: PSecurityDescriptor);
begin
  if not InitializeSecurityDescriptor(PSD, SECURITY_DESCRIPTOR_REVISION) then
    raise Exception.Create('Error initializing security descriptor');
  if not SetSecurityDescriptorDacl(PSD, True, nil, False) then
    raise Exception.Create('Error setting security descriptor dacl');
  PSA.nLength := SizeOf(TSecurityAttributes);
  PSA.lpSecurityDescriptor := PSD;
  PSA.bInheritHandle := False;
end;

procedure TMMFBase.Read;
var
  Handle: THandle;
  Mem: Pointer;
  MS: TMMFStream;
begin
  if (FHandle = 0) and (FName = '') then
    raise Exception.Create('(FHandle = 0) and (FName = '''')');

  EnterCriticalSection(FCriticalSection);
  try
    if FHandle = 0 then
    begin
      Handle := OpenFileMappingS(FILE_MAP_READ, False, FName);
      if Handle = 0 then
        raise Exception.Create(Format('OpenFileMapping() failed: %d', [GetLastError]));
    end else
      Handle := FHandle;

    Mem := MapViewOfFile(Handle, FILE_MAP_READ, 0, 0, MMF_SIZE);
    if not Assigned(Mem) then
      raise Exception.Create(Format('MapViewOfFile() failed: %d', [GetLastError]));

    MS := TMMFStream.Create;
    try
      MS.SetPointer(Mem, MMF_SIZE);
      ReadStream(MS);
    finally
      MS.Free;

      UnmapViewOfFile(Mem);

      if FHandle = 0 then
        CloseHandle(Handle);
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

procedure TMMFBase.Write;
var
  Handle: THandle;
  Mem: Pointer;
  MS: TMMFStream;
  SA: TSecurityAttributes;
  SD: TSecurityDescriptor;
begin
  if (FHandle = 0) and (FName = '') then
    raise Exception.Create('(FHandle = 0) and (FName = '''')');

  EnterCriticalSection(FCriticalSection);
  try
    if FHandle = 0 then
    begin
      InitSecurityAttributes(@SA, @SD);
      Handle := CreateFileMappingS(INVALID_HANDLE_VALUE, @SA, PAGE_READWRITE, 0, MMF_SIZE, FName);
      if Handle = 0 then
        raise Exception.Create(Format('CreateFileMapping() failed: %d', [GetLastError]));
    end else
      Handle := FHandle;

    Mem := MapViewOfFile(Handle, FILE_MAP_WRITE, 0, 0, MMF_SIZE);
    if not Assigned(Mem) then
      raise Exception.Create(Format('MapViewOfFile() failed: %d', [GetLastError]));

    MS := TMMFStream.Create;
    try
      MS.SetPointer(Mem, MMF_SIZE);
      WriteStream(MS);
    finally
      MS.Free;

      UnmapViewOfFile(Mem);

      if FHandle = 0 then
        FHandle := Handle;
    end;
  finally
    LeaveCriticalSection(FCriticalSection);
  end;
end;

{ TMMFStream }

function TMMFStream.Realloc(var NewCapacity: PtrInt): Pointer;
begin
  Result := nil;
end;

{ TMMF }

constructor TMMF.Create;
begin
  inherited Create(APP_NAME, Handle);
end;

procedure TMMF.ReadStream(const MS: TMemoryStream);
var
  StrLength: UInt16;
begin
  MS.ReadBuffer(FWindowHandle, SizeOf(FWindowHandle));
  MS.ReadBuffer(FWriteLog, SizeOf(FWriteLog));
  MS.ReadBuffer(FAddress, SizeOf(FAddress));

  MS.ReadBuffer(StrLength, SizeOf(UInt16));
  SetLength(FLogFile, StrLength);
  MS.ReadBuffer(FLogFile[1], StrLength);
end;

procedure TMMF.WriteStream(const MS: TMemoryStream);
var
  StrLength: UInt16;
begin
  MS.WriteBuffer(FWindowHandle, SizeOf(FWindowHandle));
  MS.WriteBuffer(FWriteLog, SizeOf(FWriteLog));
  MS.WriteBuffer(FAddress, SizeOf(FAddress));

  StrLength := Length(FLogFile);
  MS.WriteBuffer(StrLength, SizeOf(UInt16));
  MS.WriteBuffer(FLogFile[1], StrLength);
end;

end.

