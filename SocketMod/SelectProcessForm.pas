unit SelectProcessForm;

interface

uses
  Buttons,
  Classes,
  Controls,
  Dialogs,
  StdCtrls,
  ExeFunctions,
  ExtCtrls,
  Forms,
  Functions,
  Windows,
  Graphics,
  SysUtils;

type

  { TfrmSelectProcess }

  TfrmSelectProcess = class(TForm)
    BitBtnInject: TBitBtn;
    ListBoxProcesses: TListBox;
    PanelActions: TPanel;
    procedure BitBtnInjectClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ListBoxProcessesDblClick(Sender: TObject);
    procedure ListBoxProcessesDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure ListBoxProcessesSelectionChange(Sender: TObject; User: boolean);
  private
    FProcessIcon: HICON;
    FProcessId: Cardinal;
  public
    property ProcessId: Cardinal read FProcessId;
  end;

implementation

{$R *.lfm}

{ TfrmSelectProcess }

procedure TfrmSelectProcess.FormCreate(Sender: TObject);
begin
  FProcessIcon := TExeFunctions.ExtractIcon('shell32.dll', 2);
end;

procedure TfrmSelectProcess.BitBtnInjectClick(Sender: TObject);
begin
  FProcessId := Cardinal(ListBoxProcesses.Items.Objects[ListBoxProcesses.ItemIndex]);
  Close;
end;

procedure TfrmSelectProcess.FormDestroy(Sender: TObject);
begin
  DestroyIcon(FProcessIcon);
end;

procedure TfrmSelectProcess.FormShow(Sender: TObject);
var
  Process: TProcess;
begin
  ListBoxProcesses.ItemHeight := Max(Canvas.TextHeight('yW'), 16) + 4;

  for Process in TFunctions.GetProcesses do
    ListBoxProcesses.AddItem(Process.Exe, TObject(Process.Pid));
end;

procedure TfrmSelectProcess.ListBoxProcessesDblClick(Sender: TObject);
begin
  BitBtnInject.Click;
end;

procedure TfrmSelectProcess.ListBoxProcessesDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  TextRect: TRect;
  TextStyle: TTextStyle;
begin
  ListBoxProcesses.Canvas.Brush.Color := SysUtils.IfThen<TColor>(odSelected in State, clHighlight, clWindow);
  ListBoxProcesses.Canvas.Font.Color := SysUtils.IfThen<TColor>(odSelected in State, clHighlightText, clWindowText);

  ListBoxProcesses.Canvas.FillRect(ARect);

  if (Index < 0) or (Index >= ListBoxProcesses.Items.Count) then
    Exit;

  TextRect := TRect.Create(ARect.Left + 22, ARect.Top, ARect.Right, ARect.Bottom);

  TextStyle := ListBoxProcesses.Canvas.TextStyle;
  TextStyle.Layout := tlCenter;
  TextStyle.EndEllipsis := True;

  ListBoxProcesses.Canvas.TextRect(TextRect, TextRect.Left, TextRect.Top, ListBoxProcesses.Items[Index], TextStyle);

  DrawIconEx(ListBoxProcesses.Canvas.Handle, ARect.Left + 2, ARect.Top + Trunc(ARect.Height / 2 - 16 / 2), FProcessIcon, 16, 16, 0, 0, DI_NORMAL);
end;

procedure TfrmSelectProcess.ListBoxProcessesSelectionChange(Sender: TObject; User: boolean);
begin
  BitBtnInject.Enabled := True;
end;

end.
