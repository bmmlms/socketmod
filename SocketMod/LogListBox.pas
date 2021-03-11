unit LogListBox;

interface

uses
  Windows, Classes, SysUtils, LCLType, Controls, StdCtrls, Graphics, Math, GUILog, ExeFunctions, functions;

type

  { TLogListBox }

  TLogListBox = class(TCustomListBox)
  private
    FIconInfo, FIconError, FIconAction: HICON;
  protected
    procedure DrawItem(Index: Integer; ARect: TRect; State: TOwnerDrawState); override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetParent(NewParent: TWinControl); override;

    procedure Log(const Message: string; const MsgType: TMessageTypes = mtInfo);
  end;

implementation

{ TLogListBox }

constructor TLogListBox.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);

  Style := lbOwnerDrawFixed;
  Options := [];

  FIconInfo := TExeFunctions.ExtractIcon('shell32.dll', 277);
  FIconError := TExeFunctions.ExtractIcon('shell32.dll', 131);
  FIconAction := TExeFunctions.ExtractIcon('netshell.dll', 97);
end;

destructor TLogListBox.Destroy;
begin
  DestroyIcon(FIconInfo);
  DestroyIcon(FIconError);
  DestroyIcon(FIconAction);

  inherited Destroy;
end;

procedure TLogListBox.SetParent(NewParent: TWinControl);
begin
  inherited;

  if NewParent <> nil then
    ItemHeight := Max(Canvas.TextHeight('yW'), 16) + 4;
end;

procedure TLogListBox.Log(const Message: string; const MsgType: TMessageTypes);
begin
  AddItem(Format('%s - %s', [FormatDateTime('hh:nn:ss', Now), Message]), TObject(MsgType));
  TopIndex := Items.Count - 1;
end;

procedure TLogListBox.DrawItem(Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  TextRect: TRect;
  TextStyle: TTextStyle;
  Icon: HICON;
begin
  Canvas.Brush.Color := SysUtils.IfThen<TColor>(Focused and (odSelected in State), clHighlight, clWindow);
  Canvas.Font.Color := SysUtils.IfThen<TColor>(Focused and (odSelected in State), clHighlightText, clWindowText);

  Canvas.FillRect(ARect);

  if (Index < 0) or (Index >= Items.Count) then
    Exit;

  TextRect := TRect.Create(ARect.Left + 22, ARect.Top, ARect.Right, ARect.Bottom);

  TextStyle := Canvas.TextStyle;
  TextStyle.Layout := tlCenter;
  TextStyle.EndEllipsis := True;

  Canvas.TextRect(TextRect, TextRect.Left, TextRect.Top, Items[Index], TextStyle);

  case TMessageTypes(Items.Objects[Index]) of
    mtInfo:
      Icon := FIconInfo;
    mtError:
      Icon := FIconError;
    mtAction:
      Icon := FIconAction;
    else
      raise Exception.Create('Unknown MessageType');
  end;

  DrawIconEx(Canvas.Handle, ARect.Left + 2, ARect.Top + Trunc(ARect.Height / 2 - 16 / 2), Icon, 16, 16, 0, 0, DI_NORMAL);
end;

end.

