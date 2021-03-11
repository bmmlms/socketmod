unit NetworkAdapter;

{$mode delphi}

interface

uses
  Classes,
  JwaWindows,
  SysUtils;

type
  TInAddrArray = array of TInAddr;

  { TAdapter }

  TAdapter = class
  private
    FName: string;
    FFriendlyName: string;
    FDescription: string;
    FUp: Boolean;
    FAddresses: TInAddrArray;
  public
    constructor Create(const Name, FriendlyName, Description: string; const Up: Boolean; const Addresses: TInAddrArray);

    property Name: string read FName;
    property FriendlyName: string read FFriendlyName;
    property Description: string read FDescription;
    property Up: Boolean read FUp;
    property Addresses: TInAddrArray read FAddresses;
  end;

  TAdapterArray = array of TAdapter;

  { TNetworkAdapters }

  TNetworkAdapters = class
  public
    class function GetAdapters: TAdapterArray; static;
  end;

implementation

const
  IP_ADAPTER_IPV4_ENABLED = $0080;

{ TAdapter }

constructor TAdapter.Create(const Name, FriendlyName, Description: string; const Up: Boolean; const Addresses: TInAddrArray);
begin
  FName := Name;
  FFriendlyName := FriendlyName;
  FDescription := Description;
  FUp := Up;
  FAddresses := Addresses;
end;

{ TNetworkAdapters }

class function TNetworkAdapters.GetAdapters: TAdapterArray;
var
  Ret: DWORD;
  BufLen: ULONG;
  CurrentAdapter, Adapters: PIP_ADAPTER_ADDRESSES;
  Adapter: TAdapter;
  UnicastAddr: PIP_ADAPTER_UNICAST_ADDRESS;
  IPAddresses: TInAddrArray;
begin
  Result := [];

  BufLen := 1024 * 15;
  GetMem(Adapters, BufLen);
  try
    repeat
      Ret := GetAdaptersAddresses(PF_INET, GAA_FLAG_SKIP_ANYCAST or GAA_FLAG_SKIP_MULTICAST or GAA_FLAG_SKIP_DNS_SERVER, nil, Adapters, @BufLen);
      case Ret of
        ERROR_SUCCESS:
        begin
          if BufLen = 0 then
            raise Exception.Create('No network interfaces found.');
          Break;
        end;
        ERROR_NOT_SUPPORTED,
        ERROR_NO_DATA,
        ERROR_ADDRESS_NOT_ASSOCIATED:
          raise Exception.Create('No network interfaces found.');
        ERROR_BUFFER_OVERFLOW:
          ReallocMem(Adapters, BufLen);
        else
          raise Exception.Create('No network interfaces found.');
      end;
    until False;

    if Ret = ERROR_SUCCESS then
    begin
      CurrentAdapter := Adapters;
      while Assigned(CurrentAdapter) do
      begin
        if (CurrentAdapter.IfType <> IF_TYPE_SOFTWARE_LOOPBACK) and ((CurrentAdapter.Flags and IP_ADAPTER_RECEIVE_ONLY) = 0) and ((CurrentAdapter.Flags and IP_ADAPTER_IPV4_ENABLED) = IP_ADAPTER_IPV4_ENABLED) then
        begin
          IPAddresses := [];

          UnicastAddr := CurrentAdapter^.FirstUnicastAddress;
          while Assigned(UnicastAddr) do
          begin
            begin
              case UnicastAddr^.Address.lpSockaddr.sa_family of
                AF_INET:
                begin
                  SetLength(IPAddresses, Length(IPAddresses) + 1);
                  IPAddresses[High(IPAddresses)] := PSockAddrIn(UnicastAddr^.Address.lpSockaddr)^.sin_addr;
                end;
              end;
            end;

            UnicastAddr := UnicastAddr^.Next;
          end;

          Adapter := TAdapter.Create(CurrentAdapter.AdapterName, CurrentAdapter.FriendlyName, CurrentAdapter.Description, CurrentAdapter.OperStatus = IF_OPER_STATUS.IfOperStatusUp, IPAddresses);
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := Adapter;
        end;

        CurrentAdapter := CurrentAdapter^.Next;
      end;
    end;
  finally
    FreeMem(Adapters);
  end;
end;

end.

