unit ExeFunctions;

interface

uses
  Forms,
  LCLType,
  StrUtils,
  SysUtils,
  Windows;

type
  BITMAPV5HEADER = record
    bV5Size: DWORD;
    bV5Width: Longint;
    bV5Height: Longint;
    bV5Planes: Word;
    bV5BitCount: Word;
    bV5Compression: DWORD;
    bV5SizeImage: DWORD;
    bV5XPelsPerMeter: Longint;
    bV5YPelsPerMeter: Longint;
    bV5ClrUsed: DWORD;
    bV5ClrImportant: DWORD;
    bV5RedMask: DWORD;
    bV5GreenMask: DWORD;
    bV5BlueMask: DWORD;
    bV5AlphaMask: DWORD;
    bV5CSType: DWORD;
    bV5Endpoints: TCIEXYZTriple;
    bV5GammaRed: DWORD;
    bV5GammaGreen: DWORD;
    bV5GammaBlue: DWORD;
    bV5Intent: DWORD;
    bV5ProfileData: DWORD;
    bV5ProfileSize: DWORD;
    bV5Reserved: DWORD;
  end;

  TCreateDIBSection = function(_para1: HDC; const _para2: BITMAPV5HEADER; _para3: UINT; var _para4: Pointer; _para5: HANDLE; _para6: DWORD): HBITMAP; stdcall;

  TWindowRes = record
    PID: Cardinal;
    WindowHandle: THandle;
    WindowText: string;
    Success: Boolean;
  end;

  { TExeFunctions }

  TExeFunctions = class
  public
    class function GetFullscreenWindow: TWindowRes; static;
    class function ExtractIcon(const Source: UnicodeString; const Index: Integer): HICON; static;
    class function GrayscaleIcon(const Icon: HICON): HICON; static;
  end;

implementation

function ExtractIconExW(lpszFile: PWideChar; nIconIndex: Integer; phiconLarge: PHANDLE; phiconSmall: PHANDLE; nIcons: UINT): UINT; stdcall; external 'shell32.dll';

{ TExeFunctions }

class function TExeFunctions.GetFullscreenWindow: TWindowRes;
var
  i, Len: Integer;
  R: TRect;
  Str: UnicodeString;
begin
  Result.Success := False;

  Screen.UpdateMonitors;

  Result.WindowHandle := GetForegroundWindow;

  SetLength(Str, 256);
  Len := GetClassNameW(Result.WindowHandle, @Str[1], 256);
  if Len = 0 then
    Exit;
  SetLength(Str, Len);

  if (Result.WindowHandle <> GetDesktopWindow) and (Result.WindowHandle <> GetShellWindow) and
    // Lockscreen, Mstsc
    (Str <> 'Windows.UI.Core.CoreWindow') and (Str <> 'TscShellContainerClass') then
  begin
    GetWindowRect(Result.WindowHandle, R);
    for i := 0 to Screen.MonitorCount - 1 do
      if Screen.Monitors[i].Primary and (Screen.Monitors[i].BoundsRect = R) then
      begin
        if GetWindowThreadProcessId(Result.WindowHandle, Result.PID) = 0 then
          Exit;

        SetLength(Str, 256);
        Len := GetWindowTextW(Result.WindowHandle, @Str[1], 256);
        SetLength(Str, Len);

        Result.WindowText := Str;
        Result.Success := True;

        Exit;
      end;
  end;
end;

class function TExeFunctions.ExtractIcon(const Source: UnicodeString; const Index: Integer): HICON;
begin
  if ExtractIconExW(PWideChar(Source), Index, nil, @Result, 1) = UINT($FFFFFFFF) then
    Result := 0;
end;

class function TExeFunctions.GrayscaleIcon(const Icon: HICON): HICON;
var
  DC, Bmp: Handle;
  BitmapStart, BitmapEnd: Pointer;
  IconInfo: TIconInfo;
  BitmapHeader: BITMAPV5HEADER;
  BitmapInfo: BITMAP;

  procedure Grayscale;
  var
    RGBQuad: PRGBAQuad;
    Gray: Byte;
  begin
    RGBQuad := BitmapStart;
    while RGBQuad < BitmapEnd do
    begin
      Gray := Round((0.299 * RGBQuad.Red) + (0.587 * RGBQuad.Green) + (0.114 * RGBQuad.Blue));
      RGBQuad.Red := Gray;
      RGBQuad.Green := Gray;
      RGBQuad.Blue := Gray;
      RGBQuad.Alpha := Round(0.5 * RGBQuad.Alpha);

      RGBQuad := Pointer(NativeUInt(RGBQuad) + SizeOf(TRGBQUAD));
    end;
  end;

begin
  GetIconInfo(Icon, IconInfo);

  GetObject(IconInfo.hbmColor, SizeOf(BitmapInfo), @BitmapInfo);

  DeleteObject(IconInfo.hbmColor);
  DeleteObject(IconInfo.hbmMask);

  ZeroMemory(@BitmapHeader, SizeOf(BitmapHeader));
  BitmapHeader.bV5Size := SizeOf(BitmapHeader);
  BitmapHeader.bV5Width := BitmapInfo.bmWidth;
  BitmapHeader.bV5Height := -BitmapInfo.bmHeight;
  BitmapHeader.bV5Planes := 1;
  BitmapHeader.bV5BitCount := 32;
  BitmapHeader.bV5Compression := BI_RGB;

  DC := CreateCompatibleDC(0);
  Bmp := TCreateDIBSection(@CreateDIBSection)(DC, BitmapHeader, DIB_RGB_COLORS, BitmapStart, 0, 0);
  BitmapEnd := BitmapStart + (BitmapInfo.bmWidth * BitmapInfo.bmHeight * SizeOf(TRGBQUAD));

  SelectObject(DC, Bmp);
  DrawIconEx(DC, 0, 0, Icon, BitmapInfo.bmWidth, BitmapInfo.bmHeight, 0, 0, DI_NORMAL);

  GrayScale;

  IconInfo.fIcon := True;
  IconInfo.xHotspot := 0;
  IconInfo.yHotspot := 0;
  IconInfo.hbmColor := Bmp;
  IconInfo.hbmMask := Bmp;
  Result := CreateIconIndirect(IconInfo);

  DeleteDC(DC);
  DeleteObject(Bmp);
end;

end.
