unit AdapterComboBox;

interface

uses
  Classes,
  Controls,
  ExeFunctions,
  Graphics,
  LCLType,
  Math,
  NetworkAdapter,
  StdCtrls,
  SysUtils,
  functions,
  Windows,
  WinSock2;

type

  { TAdapterComboBox }

  TAdapterComboBox = class(TCustomComboBox)
  private
    FSelectedAdapterName: string;
    FAdapters: TList;
    FLineHeight: Integer;
    FIconConnected, FIconDisconnected: HICON;

    function FGetSelectedAdapter: TAdapter;
  protected
    procedure DrawItem(Index: Integer; ARect: TRect; State: LCLType.TOwnerDrawState); override;
    procedure MeasureItem(Index: Integer; var TheHeight: Integer); override;
    procedure Select; override;
    procedure SetItemIndex(const Val: integer); override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetParent(NewParent: TWinControl); override;
    procedure SetAdapters(Adapters: TAdapterArray);

    property SelectedAdapter: TAdapter read FGetSelectedAdapter;

    property OnSelect;
  end;

implementation

{ TAdapterComboBox }

procedure TAdapterComboBox.DrawItem(Index: Integer; ARect: TRect; State: LCLType.TOwnerDrawState);
var
  Adapter: TAdapter;
  TextStyle: TTextStyle;
  TextRect: TRect;
begin
  Canvas.Brush.Color := SysUtils.IfThen<TColor>(LCLType.odSelected in State, clHighlight, clWindow);
  Canvas.Font.Color := SysUtils.IfThen<TColor>(LCLType.odSelected in State, clHighlightText, clWindowText);

  Adapter := FAdapters[SysUtils.IfThen<Integer>(Index = -1, ItemIndex, Index)];

  if not (odBackgroundPainted in State) then
    Canvas.FillRect(ARect);

  TextStyle := Canvas.TextStyle;
  TextStyle.EndEllipsis := True;

  TextRect := TRect.Create(ARect.Left + 22, ARect.Top, ARect.Right, ARect.Bottom);

  if TextRect.Height < ClientHeight then
  begin
    TextStyle.Layout := tlCenter;
    Canvas.TextRect(TextRect, TextRect.Left, TextRect.Top, Adapter.FriendlyName, TextStyle);
  end else
  begin
    Canvas.Font.Style := [fsBold];
    Canvas.TextRect(TextRect, TextRect.Left, TextRect.Top, Adapter.FriendlyName, TextStyle);
    Canvas.Font.Style := [];

    TextRect.Top := TextRect.Top + FLineHeight;

    Canvas.TextRect(TextRect, TextRect.Left, TextRect.Top, Adapter.Description, TextStyle);

    TextRect.Top := TextRect.Top + FLineHeight;

    if Adapter.Up and (Length(Adapter.Addresses) > 0) then
      Canvas.TextRect(TextRect, TextRect.Left, TextRect.Top, inet_ntoa(TInAddr(Adapter.Addresses[0])), TextStyle)
    else
    begin
      Canvas.Font.Style := [fsItalic];
      Canvas.TextRect(TextRect, TextRect.Left, TextRect.Top, 'Not connected', TextStyle);
      Canvas.Font.Style := [];
    end;
  end;

  DrawIconEx(Canvas.Handle, ARect.Left + 2, ARect.Top + 1, SysUtils.IfThen<HICON>(Adapter.Up and (Length(Adapter.Addresses) > 0), FIconConnected, FIconDisconnected), 16, 16, 0, 0, DI_NORMAL);
end;

procedure TAdapterComboBox.MeasureItem(Index: Integer; var TheHeight: Integer);
var
  Adapter: TAdapter;
begin
  if (Index = -1) then
    Exit;

  Adapter := TAdapter(FAdapters[Index]);

  FLineHeight := Max(Canvas.TextHeight(Adapter.FriendlyName), Canvas.TextHeight(Adapter.Description)) + 2;

  TheHeight := FLineHeight * 3;
end;

procedure TAdapterComboBox.Select;
begin
  inherited;

  if ItemIndex > -1 then
    FSelectedAdapterName := TAdapter(FAdapters[ItemIndex]).Name;
end;

procedure TAdapterComboBox.SetItemIndex(const Val: integer);
begin
  inherited SetItemIndex(Val);

  Select;
end;

constructor TAdapterComboBox.Create(TheOwner: TComponent);
begin
  inherited;

  FAdapters := TList.Create;

  FIconConnected := TExeFunctions.ExtractIcon('netshell.dll', 0);
  FIconDisconnected := TExeFunctions.GrayscaleIcon(FIconConnected);
end;

destructor TAdapterComboBox.Destroy;
var
  Adapter: TAdapter;
begin
  DestroyIcon(FIconConnected);
  DestroyIcon(FIconDisconnected);

  for Adapter in FAdapters do
    Adapter.Free;
  FAdapters.Free;

  inherited Destroy;
end;

procedure TAdapterComboBox.SetParent(NewParent: TWinControl);
begin
  inherited;

  SetStyle(csOwnerDrawVariable);
end;

function SortAdapters(A, B: TAdapter): LongInt; register;
begin
  Result := CompareByte(A.Up, B.Up, SizeOf(Boolean)) * -1;
  if Result = 0 then
    Result := CompareText(A.FriendlyName, B.FriendlyName);
end;

procedure TAdapterComboBox.SetAdapters(Adapters: TAdapterArray);
var
  Adapter: TAdapter;
begin
  ItemIndex := -1;
  Items.Clear;

  for Adapter in FAdapters do
    Adapter.Free;
  FAdapters.Clear;

  for Adapter in Adapters do
    FAdapters.Add(Adapter);

  FAdapters.Sort(@SortAdapters);

  for Adapter in FAdapters do
  begin
    AddItem('', Adapter);
    if ((FSelectedAdapterName = '') and Adapter.Up) or (FSelectedAdapterName = Adapter.Name) then
      ItemIndex := Items.Count - 1;
  end;

  if (FSelectedAdapterName = '') and (ItemIndex = -1) and (Items.Count > 0) then
    ItemIndex := 0;
end;

function TAdapterComboBox.FGetSelectedAdapter: TAdapter;
begin
  if (ItemIndex < 0) or (not TAdapter(FAdapters[ItemIndex]).Up) or (Length(TAdapter(FAdapters[ItemIndex]).Addresses) = 0) then
    Exit(nil);

  Result := FAdapters[ItemIndex];
end;

end.
