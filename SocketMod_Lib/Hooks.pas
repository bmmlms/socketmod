unit Hooks;

interface

uses
  Classes,
  DDetours,
  Generics.Collections,
  GUILog,
  MMF,
  Log,
  SysUtils,
  Windows,
  WinSock2;

type
  Tbind = function(const s: TSocket; addr: PSockAddr; const namelen: Longint): Longint; stdcall;
  Tsetsockopt = function(s: TSocket; level, optname: Longint; optval: Pointer; optlen: Longint): Longint; stdcall;
  TTsocket = function(af, struct, protocol: Longint): TSocket; stdcall;
  Tclosesocket = function(const s: TSocket): Longint; stdcall;
  Trecvfrom = function(s: TSocket; Buf: Pointer; len, flags: Longint; from: PSockAddr; fromlen: PLongint): Longint; stdcall;
  Tsendto = function(s: TSocket; Buf: Pointer; len, flags: Longint; addrto: PSockAddr; tolen: Longint): Longint; stdcall;

  Tconnect = function(const s: TSocket; Name: PSockAddr; namelen: Longint): Longint; stdcall;
  Tgethostbyname = function(Name: PChar): PHostEnt; stdcall;

  { THooks }

  THooks = class
  private
    class var
    FLog: TFileLog;
    FGUILog: TGUILog;
    FMMF: TMMF;
    FInitialized: Boolean;

    Obind: Tbind;
    Osetsockopt: Tsetsockopt;
    Osocket: TTsocket;
    Oclosesocket: Tclosesocket;
    Orecvfrom: Trecvfrom;
    Osendto: Tsendto;

    Oconnect: Tconnect;
    Ogethostbyname: Tgethostbyname;

    class function BufToHexStr(buf: Pointer; len: Longint): string; static;

    class function Hbind(const s: TSocket; addr: PSockAddr; const namelen: Longint): Longint; stdcall; static;
    class function Hsetsockopt(s: TSocket; level, optname: Longint; optval: Pointer; optlen: Longint): Longint; stdcall; static;
    class function Hsocket(af, struct, protocol: Longint): TSocket; stdcall; static;
    class function Hclosesocket(const s: TSocket): Longint; stdcall; static;
    class function Hrecvfrom(s: TSocket; buf: Pointer; len, flags: Longint; from: PSockAddr; fromlen: PLongint): Longint; stdcall; static;
    class function Hsendto(s: TSocket; buf: Pointer; len, flags: Longint; addrto: PSockAddr; tolen: Longint): Longint; stdcall; static;

    class function Hconnect(const s: TSocket; Name: PSockAddr; namelen: Longint): Longint; stdcall; static;
    class function Hgethostbyname(Name: PChar): PHostEnt; stdcall; static;
  public
    class procedure Initialize(const Log: TFileLog; const GUILog: TGUILog; const MMF: TMMF); static;
    class procedure Uninitialize; static;
  end;

implementation

{ THooks }

class procedure THooks.Initialize(const Log: TFileLog; const GUILog: TGUILog; const MMF: TMMF);
begin
  FLog := Log;
  FGUILog := GUILog;
  FMMF := MMF;

  @Obind := InterceptCreate(@bind, @Hbind);
  @Osetsockopt := InterceptCreate(@setsockopt, @Hsetsockopt);
  @Osocket := InterceptCreate(@socket, @Hsocket);
  @Oclosesocket := InterceptCreate(@closesocket, @Hclosesocket);
  @Orecvfrom := InterceptCreate(@recvfrom, @Hrecvfrom);
  @Osendto := InterceptCreate(@sendto, @Hsendto);
  @Oconnect := InterceptCreate(@connect, @Hconnect);
  @Ogethostbyname := InterceptCreate(@gethostbyname, @Hgethostbyname);

  FInitialized := True;

  GUILog.Info('Initialization succeeded');
end;

class procedure THooks.Uninitialize;
begin
  if not FInitialized then
    Exit;

  InterceptRemove(@Obind);
  InterceptRemove(@Osetsockopt);
  InterceptRemove(@Osocket);
  InterceptRemove(@Oclosesocket);
  InterceptRemove(@Orecvfrom);
  InterceptRemove(@Osendto);
  InterceptRemove(@Oconnect);
  InterceptRemove(@Ogethostbyname);
end;

class function THooks.BufToHexStr(buf: Pointer; len: Longint): string;
var
  B: PByte;
begin
  if Buf = nil then
    Exit('NULL');

  Result := '';

  B := Buf;
  while B < Buf + len do
  begin
    Result += IntToHex(B^, 2) + ' ';
    Inc(B);
  end;

  Result := Result.Trim;
end;

class function THooks.Hbind(const s: TSocket; addr: PSockAddr; const namelen: Longint): Longint; stdcall;
begin
  FLog.Debug(Format('bind(s %d, addr %s, namelen %d)', [s, inet_ntoa(addr.sin_addr), namelen]));

  Result := Obind(s, addr, namelen);
end;

class function THooks.Hsetsockopt(s: TSocket; level, optname: Longint; optval: Pointer; optlen: Longint): Longint; stdcall;
begin
  FLog.Debug(Format('setsockopt(s %d, level %d, optname %d, optval %s, optlen %d)', [s, level, optname, BufToHexStr(optval, optlen), optlen]));

  Result := Osetsockopt(s, level, optname, optval, optlen);
end;

class function THooks.Hsocket(af, struct, protocol: Longint): TSocket; stdcall;
begin
  FLog.Debug(Format('socket(af %d, type %d, protocol %d)', [af, struct, protocol]));

  Result := Osocket(af, struct, protocol);
end;

class function THooks.Hclosesocket(const s: TSocket): Longint; stdcall;
begin
  FLog.Debug(Format('closesocket(s %d)', [s]));

  Result := Oclosesocket(s);
end;

class function THooks.Hrecvfrom(s: TSocket; buf: Pointer; len, flags: Longint; from: PSockAddr; fromlen: PLongint): Longint; stdcall;
begin
  Result := Orecvfrom(s, buf, len, flags, from, fromlen);

  FLog.Debug(Format('recvfrom(s %d, buf %p, len %d, flags %d)', [s, buf, len, flags]));

  {
  if (Result <> 0) and (Result <> SOCKET_ERROR) then
  begin
    FLog.Debug(Format('  Buf: %s', [BufToHexStr(buf, Result)]));
    if from <> nil then
      FLog.Debug(Format('  From: %s', [inet_ntoa(from.sin_addr)]));
  end else
    FLog.Debug(Format('  Error %d / WSAGetLastError %d', [Result, WSAGetLastError]));
  }
end;

class function THooks.Hsendto(s: TSocket; buf: Pointer; len, flags: Longint; addrto: PSockAddr; tolen: Longint): Longint; stdcall;
begin
  FLog.Debug(Format('sendto(s %d, buf %p, len %d, flags %d, addrto %s, tolen %d)', [s, buf, len, flags, inet_ntoa(addrto.sin_addr), tolen]));

  // FLog.Debug(Format('  Buf: %s', [BufToHexStr(buf, len)]));

  Result := Osendto(s, Buf, len, flags, addrto, tolen);
end;

class function THooks.Hconnect(const s: TSocket; Name: PSockAddr; namelen: Longint): Longint; stdcall;
begin
  FLog.Debug(Format('connect(s %d, name %s, namelen %d)', [s, inet_ntoa(Name.sin_addr), namelen]));

  Result := Oconnect(s, Name, namelen);
end;

class function THooks.Hgethostbyname(Name: PChar): PHostEnt; stdcall;
type
  TPInAddrArray = array[0..32] of PInAddr;
  PPInAddrArray = ^TPInAddrArray;
  PPInAddr = ^PInAddr;
var
  P: PPInAddr;
  LocalHostname: AnsiString;
  LocalHostnameLen: Integer;
  AddressesToRemove: array of string;
begin
  FLog.Debug(Format('gethostbyname(name %s)', [Name]));

  LocalHostnameLen := 256;
  SetLength(LocalHostname, LocalHostnameLen);
  if gethostname(PAnsiChar(LocalHostname), LocalHostnameLen) <> 0 then
  begin
    FLog.Error('  Error');
    Exit(Ogethostbyname(Name));
  end;

  LocalHostname := PAnsiChar(LocalHostname);

  Result := Ogethostbyname(Name);

  if (Result <> nil) and (Result.h_addrtype = AF_INET) and LocalHostname.ToLower.Equals(AnsiString(Name).ToLower) then
  begin
    AddressesToRemove := [];

    P := PPInAddr(Result^.h_addr_list);
    while P^ <> nil do
    begin
      if P^^.S_addr <> FMMF.Address then
      begin
        SetLength(AddressesToRemove, Length(AddressesToRemove) + 1);
        AddressesToRemove[High(AddressesToRemove)] := inet_ntoa(P^^);
      end;

      P := PPInAddr(NativeUInt(P) + SizeOf(Pointer));
    end;

    if (Length(AddressesToRemove) > 0) then
    begin
      FGUILog.Action(Format('gethostbyname(): Hiding address(es) %s', [string.Join(', ', AddressesToRemove)]));

      P := PPInAddr(Result^.h_addr_list);
      P^^.S_addr := FMMF.Address;
      P := PPInAddr(NativeUInt(P) + SizeOf(Pointer));

      while P^ <> nil do
      begin
        P^ := nil;
        P := PPInAddr(NativeUInt(P) + SizeOf(Pointer));
      end;
    end;
  end;
end;

end.
