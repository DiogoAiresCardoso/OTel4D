unit OTel.View.TraceEndpoint;

interface

uses
  OTel.Model.Dto.Configuration;

function RenderTracesEndpoint(const Options: TOTelOptions): string;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.RegularExpressions,
  Winapi.Winsock2;

procedure InvalidEndpoint;
begin
  // A configured URL can contain credentials. Keep its value out of diagnostics.
  raise EOTelConfiguration.Create('The traces destination must be an absolute HTTP or HTTPS URL with a valid host and port.');
end;

procedure ValidateAuthority(const Authority: string);
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
  if Authority[1] = '[' then
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

function RenderTracesEndpoint(const Options: TOTelOptions): string;
var
  SignalSpecific: Boolean;
  QueryStart, AuthorityStart, AuthorityEnd, PathStart: Integer;
  Path, Query: string;
  Ch: Char;
begin
  SignalSpecific := Options.TracesEndpoint <> '';
  if SignalSpecific then
    Result := Options.TracesEndpoint
  else
    Result := Options.Endpoint;
  if not (StartsText('http://', Result) or StartsText('https://', Result)) then
    InvalidEndpoint;
  for Ch in Result do
    if (Ch <= ' ') or (Ch = #127) or (Ch = '\') or (Ch = '#') then
      InvalidEndpoint;

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
  if (PathStart = 0) or (not SignalSpecific and (Path[Length(Path)] <> '/')) then
    Path := Path + '/';
  if not SignalSpecific then
    Path := Path + 'v1/traces';
  Result := Path + Query;
end;

end.
