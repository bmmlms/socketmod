unit MainForm;

interface

uses
  AdapterComboBox,
  Buttons,
  Classes,
  ColorBox,
  ComCtrls,
  Constants,
  Controls,
  ExeFunctions,
  ExtCtrls,
  SelectProcessForm,
  Forms,
  Functions,
  Generics.Collections,
  Graphics,
  GUILog,
  JwaWindows,
  LogListBox,
  MMF,
  NetworkAdapter,
  StdCtrls,
  SysUtils,
  Types,
  Windows;

const
  WM_EXE = WM_USER + 4711;
  WM_INTERFACES_CHANGED = WM_EXE + 1;
  WM_INTERFACES_NOTIFY_ERROR = WM_EXE + 2;

  WNDPROC_PROPNAME = 'SocketMod_WndProc';

type

  { TInterfaceChangesNotifier }

  TInterfaceChangesNotifier = class(TThread)
  private
    FWindowHandle: THandle;
    FTerminatedEvent: THandle;

  protected
    procedure Execute; override;
  public
    constructor Create(WindowHandle: THandle); reintroduce;
    destructor Destroy; override;

    procedure Terminate;
  end;

  { TfrmMain }

  TfrmMain = class(TForm)
    BitBtnInject: TBitBtn;
    CheckBoxAutoInject: TCheckBox;
    CheckBoxWriteLog: TCheckBox;
    GroupBoxControl: TGroupBox;
    GroupBoxLog: TGroupBox;
    LabelNetworkAdapter: TLabel;
    PanelInject: TPanel;
    PanelNetworkAdapter: TPanel;
    PanelOptions: TPanel;
    TimerInject: TTimer;
    procedure AdapterComboBoxSelect(Sender: TObject);
    procedure BitBtnInjectClick(Sender: TObject);
    procedure CheckBoxAutoInjectClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure TimerInjectTimer(Sender: TObject);
  private
    FPrevWndProc: Windows.WNDPROC;
    FInterfaceChangesNotifier: TInterfaceChangesNotifier;
    FAdapterComboBox: TAdapterComboBox;
    FLogListBox: TLogListBox;
    FInjectedPIDs: TList<Cardinal>;
    FMMF: TMMF;

    class function CustomWndProcWrapper(hwnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; static;

    function CustomWndProc(hwnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;

    procedure Inject(PID: Cardinal; WindowText: string);

    procedure InterfacesChanged(var Message: TMessage); message WM_INTERFACES_CHANGED;
    procedure InterfacesNotifyError(var Message: TMessage); message WM_INTERFACES_NOTIFY_ERROR;
  public

  end;

implementation

{$R *.lfm}

{ TInterfaceChangesNotifier }

procedure TInterfaceChangesNotifier.Execute;
var
  WaitRes: Cardinal;
  WaitHandles: array[0..1] of THandle;
  Overlapped: TOverlapped;
  DummyHandle: THandle;
begin
  inherited;

  while not Terminated do
  begin
    Overlapped.hEvent := WSACreateEvent;

    if Overlapped.hEvent = WSA_INVALID_EVENT then
    begin
      PostMessage(FWindowHandle, WM_INTERFACES_NOTIFY_ERROR, 0, 0);
      Exit;
    end;

    if NotifyAddrChange(DummyHandle, @Overlapped) <> ERROR_IO_PENDING then
    begin
      WSACloseEvent(Overlapped.hEvent);
      PostMessage(FWindowHandle, WM_INTERFACES_NOTIFY_ERROR, 0, 0);
      Exit;
    end;

    WaitHandles[0] := FTerminatedEvent;
    WaitHandles[1] := Overlapped.hEvent;

    WaitRes := WaitForMultipleObjects(2, @WaitHandles, False, INFINITE);

    CancelIPChangeNotify(@Overlapped);
    WSACloseEvent(Overlapped.hEvent);

    if WaitRes = WAIT_OBJECT_0 + 1 then
      PostMessage(FWindowHandle, WM_INTERFACES_CHANGED, 0, 0);
  end;
end;

constructor TInterfaceChangesNotifier.Create(WindowHandle: THandle);
begin
  inherited Create(False);

  FWindowHandle := WindowHandle;
  FTerminatedEvent := CreateEvent(nil, False, False, nil);
end;

destructor TInterfaceChangesNotifier.Destroy;
begin
  CloseHandle(FTerminatedEvent);

  inherited;
end;

procedure TInterfaceChangesNotifier.Terminate;
begin
  inherited;

  SetEvent(FTerminatedEvent);
end;

{ TfrmMain }

class function TfrmMain.CustomWndProcWrapper(hwnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  Result := TfrmMain(GetPropW(hwnd, WNDPROC_PROPNAME)).CustomWndProc(hwnd, uMsg, wParam, lParam);
end;

function TfrmMain.CustomWndProc(hwnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  CDS: PCOPYDATASTRUCT;
begin
  if uMsg = WM_COPYDATA then
  begin
    CDS := PCOPYDATASTRUCT(lParam);
    FLogListBox.Log(PChar(CDS.lpData), TMessageTypes(CDS.dwData));
    Exit(0);
  end;

  Result := FPrevWndProc(hwnd, uMsg, wParam, lParam);
end;

procedure TfrmMain.Inject(PID: Cardinal; WindowText: string);
var
  ProcessHandle: THandle;
begin
  FMMF.WriteLog := CheckBoxWriteLog.Checked;
  FMMF.Address := FAdapterComboBox.SelectedAdapter.Addresses[0].S_addr;
  FMMF.Write;

  if WindowText.IsEmpty then
    FLogListBox.Log(Format('Injecting into process %d', [PID]))
  else
    FLogListBox.Log(Format('Injecting into process %d ("%s")', [PID, WindowText]));

  ProcessHandle := OpenProcess(PROCESS_ALL_ACCESS, False, PID);
  if ProcessHandle = 0 then
  begin
    FLogListBox.Log('Error opening process', mtError);
    Exit;
  end;

  try
    if not TFunctions.InjectLibrary(ProcessHandle) then
    begin
      FLogListBox.Log('Error injecting into process', mtError);
      Exit;
    end;
  finally
    CloseHandle(ProcessHandle);
  end;
end;

procedure TfrmMain.InterfacesChanged(var Message: TMessage);
begin
  FAdapterComboBox.SetAdapters(TNetworkAdapters.GetAdapters);
end;

procedure TfrmMain.InterfacesNotifyError(var Message: TMessage);
begin
  TFunctions.MessageBox(Handle, 'Error registering for interface notifications.', 'Error', MB_ICONERROR);
  Close;
end;

procedure TfrmMain.AdapterComboBoxSelect(Sender: TObject);
begin
  CheckBoxAutoInject.Enabled := Assigned(FAdapterComboBox.SelectedAdapter);
  BitBtnInject.Enabled := Assigned(FAdapterComboBox.SelectedAdapter);
  if TimerInject.Enabled and ((FAdapterComboBox.SelectedAdapter = nil) or (not FAdapterComboBox.SelectedAdapter.Up) or (Length(FAdapterComboBox.SelectedAdapter.Addresses) = 0)) then
  begin
    FLogListBox.Log('Interface down', mtError);
    CheckBoxAutoInject.Checked := False;
  end;
end;

procedure TfrmMain.BitBtnInjectClick(Sender: TObject);
var
  F: TfrmSelectProcess;
begin
  F := TfrmSelectProcess.Create(Self);
  try
    F.ShowModal;
    if F.ProcessID > 0 then
      Inject(F.ProcessId, '');
  finally
    F.Free;
  end;
end;

procedure TfrmMain.CheckBoxAutoInjectClick(Sender: TObject);
begin
  TimerInject.Enabled := CheckBoxAutoInject.Checked;

  FLogListBox.Log(IfThen<string>(TimerInject.Enabled, 'Process monitor started', 'Process monitor stopped'));

  FAdapterComboBox.Enabled := not TimerInject.Enabled;

  CheckBoxWriteLog.Enabled := not TimerInject.Enabled;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FMMF := TMMF.Create;
  FMMF.WindowHandle := Handle;
  FMMF.LogFile := ConcatPaths([GetTempDir, LOG_FILE_NAME]);
  FMMF.Write;

  SysUtils.DeleteFile(FMMF.LogFile);

  FInjectedPIDs := TList<Cardinal>.Create;

  SetPropW(Handle, WNDPROC_PROPNAME, Windows.HANDLE(Self));

  FPrevWndProc := Pointer(SetWindowLongPtrW(Handle, GWLP_WNDPROC, LONG_PTR(@CustomWndProcWrapper)));
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FInterfaceChangesNotifier) then
  begin
    FInterfaceChangesNotifier.Terminate;
    FInterfaceChangesNotifier.WaitFor;
    FreeAndNil(FInterfaceChangesNotifier);
  end;

  FMMF.Free;

  RemovePropW(Handle, WNDPROC_PROPNAME);

  SetWindowLongPtrW(Handle, GWLP_WNDPROC, LONG_PTR(@FPrevWndProc));
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  FLogListBox := TLogListBox.Create(Self);
  FLogListBox.Align := alClient;
  FLogListBox.Parent := GroupBoxLog;

  FAdapterComboBox := TAdapterComboBox.Create(Self);
  FAdapterComboBox.OnSelect := AdapterComboBoxSelect;
  FAdapterComboBox.Top := 100;
  FAdapterComboBox.SetAdapters(TNetworkAdapters.GetAdapters);
  FAdapterComboBox.Align := alTop;
  FAdapterComboBox.Parent := PanelNetworkAdapter;
  AdapterComboBoxSelect(FAdapterComboBox);

  FInterfaceChangesNotifier := TInterfaceChangesNotifier.Create(Handle);
end;

procedure TfrmMain.TimerInjectTimer(Sender: TObject);
var
  FullscreenWindow: TWindowRes;
begin
  FullscreenWindow := TExeFunctions.GetFullscreenWindow;

  if (not FullscreenWindow.Success) or (FInjectedPIDs.Contains(FullscreenWindow.PID)) then
    Exit;

  FInjectedPIDs.Add(FullscreenWindow.PID);

  Inject(FullscreenWindow.PID, FullscreenWindow.WindowText);
end;

end.


