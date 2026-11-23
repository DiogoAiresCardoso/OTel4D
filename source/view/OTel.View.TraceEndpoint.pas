unit OTel.View.TraceEndpoint;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TTraceEndpointView = class
  strict private
    class procedure InvalidEndpoint; static;
    class procedure ValidateUrlText(const Url: string); static;
    class procedure ValidateAuthority(const Authority: string); static;
  public
    class function Render(const Options: TOTelOptions): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.RegularExpressions,
  Winapi.Winsock2;

class procedure TTraceEndpointView.InvalidEndpoint;
begin
  // A configured URL can contain credentials. Keep its value out of diagnostics.
  raise EOTelConfiguration.Create('The trace endpoint must be a valid absolute HTTP or HTTPS URL.');
end;

class procedure TTraceEndpointView.ValidateUrlText(const Url: string);
const
  HexDigits = ['0'..'9', 'A'..'F', 'a'..'f'];
var
  Index: Integer;
begin
  if not (StartsText('http://', Url) or StartsText('https://', Url)) then
    InvalidEndpoint;
  for Index := Low(Url) to High(Url) do
    case Url[Index] of
      #0..' ', #127, '\', '#':
        InvalidEndpoint;
      '%':
        begin
          if Index > High(Url) - 2 then
            InvalidEndpoint;
          if not CharInSet(Url[Index + 1], HexDigits) or
             not CharInSet(Url[Index + 2], HexDigits) then
            InvalidEndpoint;
        end;
    end;
end;

class procedure TTraceEndpointView.ValidateAuthority(const Authority: string);
const
  RegName = '(?:[A-Za-z0-9._~!$&''()*+,;=-]|%[0-9A-Fa-f]{2})+';
  IpLiteral = '\[(?<ip>[0-9A-Fa-f:.]+)(?:%25(?:[A-Za-z0-9._~-]|%[0-9A-Fa-f]{2})+)?\]';
  AuthorityPattern = '\A(?:' + RegName + '|' + IpLiteral + ')(?<port>:[0-9]*|)\z';
var
  Parts: TMatch;
  Address: AnsiString;
  AddressBytes: array[0..15] of Byte;
  PortText: string;
  Port: Integer;
begin
  Parts := TRegEx.Match(Authority, AuthorityPattern);
  if not Parts.Success then
    InvalidEndpoint;
  if Authority[Low(Authority)] = '[' then
  begin
    Address := AnsiString(Parts.Groups['ip'].Value);
    if inet_pton(AF_INET6, PAnsiChar(Address), @AddressBytes) <> 1 then
      InvalidEndpoint;
  end;
  PortText := Parts.Groups['port'].Value;
  if (Length(PortText) > 1) and
     (not TryStrToInt(Copy(PortText, 2, MaxInt), Port) or (Port < 1) or (Port > 65535)) then
    InvalidEndpoint;
end;

class function TTraceEndpointView.Render(const Options: TOTelOptions): string;
var
  SignalSpecific: Boolean;
  QueryStart, AuthorityStart, AuthorityEnd, PathStart: Integer;
  Path, Query: string;
begin
  if Options = nil then
    raise EArgumentNilException.Create('Options must be assigned.');
  SignalSpecific := Options.TracesEndpoint <> '';
  if SignalSpecific then
    Result := Options.TracesEndpoint
  else
    Result := Options.Endpoint;
  ValidateUrlText(Result);

  // Preserve the receiver's path and query byte for byte when inserting a suffix.
  QueryStart := Pos('?', Result);
  if QueryStart = 0 then
    QueryStart := Length(Result) + 1;
  Path := Copy(Result, 1, QueryStart - 1);
  Query := Copy(Result, QueryStart, MaxInt);
  AuthorityStart := Pos('://', Path) + 3;
  PathStart := PosEx('/', Path, AuthorityStart);
  AuthorityEnd := PathStart;
  if AuthorityEnd = 0 then
    AuthorityEnd := Length(Path) + 1;
  ValidateAuthority(Copy(Path, AuthorityStart, AuthorityEnd - AuthorityStart));
  if (PathStart = 0) or (not SignalSpecific and (Path[High(Path)] <> '/')) then
    Path := Path + '/';
  if not SignalSpecific then
    Path := Path + 'v1/traces';
  Result := Path + Query;
end;

end.
