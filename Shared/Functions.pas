unit Functions;

interface

uses
  StrUtils,
  SysUtils,
  Windows;

type
  TProcess = record
    Pid: Cardinal;
    Exe: string;
  end;

  TProcessArray = array of TProcess;

  TEnumProcesses = function(lpidProcess: LPDWORD; cb: DWORD; var cbNeeded: DWORD): BOOL; stdcall;
  TQueryFullProcessImageNameW = function(hProcess: THandle; dwFlags: DWORD; lpImageFileName: LPWSTR; nSize: PDWORD): DWORD; stdcall;
  TIsWow64Process2 = function(hProcess: THandle; pProcessMachine: PUSHORT; pNativeMachine: PUSHORT): BOOL; stdcall;

  { TFunctions }

  TFunctions = class
  private
    class var
    FEnumProcesses: TEnumProcesses;
    FQueryFullProcessImageNameW: TQueryFullProcessImageNameW;
    FIsWow64Process2: TIsWow64Process2;
  public
    class procedure Init; static;

    class function MessageBox(hWnd: HWND; Text: string; Caption: string; uType: UINT): LongInt; static;
    class function CreateFile(FileName: string; dwDesiredAccess: DWORD; dwShareMode: DWORD; lpSecurityAttributes: LPSECURITY_ATTRIBUTES; dwCreationDisposition: DWORD; dwFlagsAndAttributes: DWORD; hTemplateFile: HANDLE): HANDLE; static;
    class function GetTempPath: string;
    class function InjectLibrary(const ProcessHandle: THandle): Boolean;
    class function GetExePath(ProcessHandle: THandle): string; static;
    class function IsWindows64Bit: Boolean; static;
    class function IsProcess64Bit(const Handle: THandle): Boolean; static;
    class function GetProcesses: TProcessArray; static;
  end;

implementation

{ TFunctions }

class procedure TFunctions.Init;
begin
  FEnumProcesses := GetProcAddress(GetModuleHandle('kernelbase.dll'), 'EnumProcesses');
  FQueryFullProcessImageNameW := GetProcAddress(GetModuleHandle('kernelbase.dll'), 'QueryFullProcessImageNameW');
  FIsWow64Process2 := GetProcAddress(GetModuleHandle('kernelbase.dll'), 'IsWow64Process2');

  if (not Assigned(FEnumProcesses)) or (not Assigned(FQueryFullProcessImageNameW)) or (not Assigned(FIsWow64Process2)) then
    raise Exception.Create('A required function could not be found, your windows version is most likely unsupported.');
end;

class function TFunctions.MessageBox(hWnd: HWND; Text: string; Caption: string; uType: UINT): LongInt;
var
  TextUnicode, CaptionUnicode: UnicodeString;
begin
  TextUnicode := Text;
  CaptionUnicode := Caption;
  Result := MessageBoxW(hWnd, PWideChar(TextUnicode), PWideChar(CaptionUnicode), uType);
end;

class function TFunctions.CreateFile(FileName: string; dwDesiredAccess: DWORD; dwShareMode: DWORD; lpSecurityAttributes: LPSECURITY_ATTRIBUTES; dwCreationDisposition: DWORD; dwFlagsAndAttributes: DWORD; hTemplateFile: HANDLE): HANDLE;
var
  FileNameUnicode: UnicodeString;
begin
  FileNameUnicode := FileName;
  Result := CreateFileW(PWideChar(FileNameUnicode), dwDesiredAccess, dwShareMode, lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
end;

class function TFunctions.GetTempPath: string;
var
  Buf: UnicodeString;
begin
  SetLength(Buf, MAX_PATH + 1);
  SetLength(Buf, GetTempPathW(Length(Buf), PWideChar(Buf)));
  Result := Buf;
end;

class function TFunctions.InjectLibrary(const ProcessHandle: THandle): Boolean;
var
  MemSize: Cardinal;
  LL, TargetMemory: Pointer;
  LibraryPath: UnicodeString;
  TID, Written: DWORD;
begin
  Result := False;

  LibraryPath := ConcatPaths([ExtractFileDir(GetExePath(GetCurrentProcess)), 'SocketMod_Lib-i386.dll']);

  MemSize := Length(LibraryPath) * 2 + 2;
  TargetMemory := VirtualAllocEx(ProcessHandle, nil, MemSize, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  LL := GetProcAddress(GetModuleHandle('kernel32.dll'), 'LoadLibraryW');
  if (LL <> nil) and (TargetMemory <> nil) then
    if WriteProcessMemory(ProcessHandle, TargetMemory, PWideChar(LibraryPath), MemSize, @Written) and (Written = MemSize) then
      Result := CreateRemoteThread(ProcessHandle, nil, 0, LL, TargetMemory, 0, TID) > 0;
end;

class function TFunctions.GetExePath(ProcessHandle: THandle): string;
var
  Size: DWORD;
  Buf: UnicodeString;
begin
  Size := 1024;
  SetLength(Buf, Size);

  if FQueryFullProcessImageNameW(ProcessHandle, 0, PWideChar(Buf), @Size) = 0 then
    raise Exception.Create(Format('QueryFullProcessImageNameW() failed: %d', [GetLastError]));

  Result := PWideChar(Buf);
end;

class function TFunctions.IsWindows64Bit: Boolean;
var
  ProcessMachine, NativeMachine: USHORT;
begin
  FIsWow64Process2(GetCurrentProcess, @ProcessMachine, @NativeMachine);
  Result := NativeMachine = IMAGE_FILE_MACHINE_AMD64;
end;

class function TFunctions.IsProcess64Bit(const Handle: THandle): Boolean;
var
  ProcessMachine, NativeMachine: USHORT;
begin
  FIsWow64Process2(Handle, @ProcessMachine, @NativeMachine);
  Result := ProcessMachine = IMAGE_FILE_MACHINE_UNKNOWN;
end;

class function TFunctions.GetProcesses: TProcessArray;
const
  PidCount: DWORD = 2048;
var
  Pids: array of DWORD;
  Pid, cbNeeded: DWORD;
  ProcHandle: THandle;
begin
  SetLength(Result, 0);
  SetLength(Pids, PidCount);
  if FEnumProcesses(@Pids[0], SizeOf(DWORD) * PidCount, cbNeeded) then
  begin
    if cbNeeded > SizeOf(DWORD) * PidCount then
      raise Exception.Create('Error enumerating processes');

    SetLength(Pids, cbNeeded div SizeOf(DWORD));

    for Pid in Pids do
    begin
      ProcHandle := OpenProcess(PROCESS_ALL_ACCESS, False, Pid);
      if ProcHandle = 0 then
        Continue;

      try
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)].Pid := Pid;
        Result[High(Result)].Exe := GetExePath(ProcHandle);
      finally
        CloseHandle(ProcHandle);
      end;
    end;
  end;
end;

end.
