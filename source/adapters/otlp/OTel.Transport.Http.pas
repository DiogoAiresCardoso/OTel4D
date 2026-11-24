unit OTel.Transport.Http;

interface

uses
  System.Classes, System.SysUtils, System.SyncObjs, System.Net.URLClient, System.Net.HttpClient,
  OTel.Application.Ports, OTel.Transport.Contracts, OTel.View.ProtobufResponse;

type
  TOTelHttpTransport = class(TInterfacedObject, IOTelRequestTransport)
  strict private
    FEndpoint: string;
    FHeaders: TNetHeaders;
    FClock: IOTelClock;
    FDecoder: IOTelResponseDecoder;
    FAbort: TEvent;
    FDeadline: UInt64;
    FBudgetMs: Cardinal;
    FResponseAborted: Boolean;
    function MakeHeaders(const Settings: string): TNetHeaders;
    function RetryDelay(const RetryAfter: string; Backoff: Cardinal): UInt64;
    procedure Receiving(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
  public
    constructor Create(const Endpoint, Headers: string; const Clock: IOTelClock;
      const Decoder: IOTelResponseDecoder; BudgetMs: Integer = 10000);
    destructor Destroy; override;
    function Deadline: UInt64;
    function Post(const Payload: TBytes; Count: Integer; BatchDeadline: UInt64;
      out Warning: Boolean): Integer;
    procedure Cancel;
  end;

implementation

uses
  Winapi.Windows, Winapi.WinHTTP, System.StrUtils, System.NetEncoding,
  OTel.Model.Dto.Configuration, OTel.Transport.ResponseStream;

const
  ProtobufType = 'application/x-protobuf';

function TOTelHttpTransport.MakeHeaders(const Settings: string): TNetHeaders;
var
  Entry, Key, Value: string;
  Ch: Char;
  I, N, Separator: Integer;
begin
  SetLength(Result, 2);
  Result[0] := TNetHeader.Create('Content-Type', ProtobufType);
  Result[1] := TNetHeader.Create('Accept', ProtobufType);
  if Settings = '' then Exit;
  if Length(Settings) > 16384 then raise EOTelConfiguration.Create('OTLP headers exceed the size limit.');
  for Entry in Settings.Split([',']) do
  begin
    Separator := Pos('=', Entry);
    if Separator < 2 then raise EOTelConfiguration.Create('Invalid OTLP header assignment.');
    Key := Trim(Copy(Entry, 1, Separator - 1));
    if Key = '' then raise EOTelConfiguration.Create('Empty OTLP header name.');
    for Ch in Key do
      if not CharInSet(Ch, ['a'..'z','A'..'Z','0'..'9','!','#','$','%','&','''','*','+','-','.','^','_',#96,'|','~']) then
        raise EOTelConfiguration.Create('Invalid OTLP header name.');
    if MatchText(Key, ['Host','Content-Length','Transfer-Encoding','Content-Type','Content-Encoding',
      'Connection','Accept','Accept-Encoding']) then raise EOTelConfiguration.Create('Reserved OTLP header.');
    for I := 2 to High(Result) do
      if SameText(Result[I].Name, Key) then raise EOTelConfiguration.Create('Duplicate OTLP header.');
    Value := Trim(Copy(Entry, Separator + 1, MaxInt));
    for I := 1 to Length(Value) do
      if Value[I] = '%' then
      begin
        if I + 2 > Length(Value) then raise EOTelConfiguration.Create('Invalid OTLP header encoding.');
        if not CharInSet(Value[I+1], ['0'..'9','a'..'f','A'..'F']) or
           not CharInSet(Value[I+2], ['0'..'9','a'..'f','A'..'F']) then
          raise EOTelConfiguration.Create('Invalid OTLP header encoding.');
      end;
    Value := TNetEncoding.URL.Decode(StringReplace(Value, '+', '%2B', [rfReplaceAll]));
    for Ch in Value do
      if (Ch < ' ') or (Ch = #127) then raise EOTelConfiguration.Create('Invalid OTLP header value.');
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := TNetHeader.Create(Key, Value);
  end;
end;

constructor TOTelHttpTransport.Create(const Endpoint, Headers: string; const Clock: IOTelClock;
      const Decoder: IOTelResponseDecoder; BudgetMs: Integer);
begin
  inherited Create;
  if BudgetMs < 0 then raise EOTelConfiguration.Create('A trace timeout must be nonnegative.');
  FClock := Clock;
  FDecoder := Decoder;
  if BudgetMs = 0 then FBudgetMs := High(Integer) else FBudgetMs := BudgetMs;
  FEndpoint := Endpoint;
  FHeaders := MakeHeaders(Headers);
  FAbort := TEvent.Create(nil, True, False, '');
end;

destructor TOTelHttpTransport.Destroy;
begin
  FAbort.Free;
  inherited;
end;

function TOTelHttpTransport.Deadline: UInt64;
begin
  Result := FClock.MonotonicMs + FBudgetMs;
end;

procedure TOTelHttpTransport.Cancel;
begin
  FAbort.SetEvent;
end;

procedure TOTelHttpTransport.Receiving(const Sender: TObject; ContentLength, ReadCount: Int64; var Abort: Boolean);
begin
  Abort := (ContentLength > MaxResponseBytes) or (ReadCount > MaxResponseBytes)
    or (FClock.MonotonicMs >= FDeadline) or (FAbort.WaitFor(0) = wrSignaled);
  if Abort then FResponseAborted := True;
end;

function TOTelHttpTransport.RetryDelay(const RetryAfter: string; Backoff: Cardinal): UInt64;
var
  Seconds, Difference: Int64;
  Utc: TSystemTime;
  FutureTime, NowTime: TFileTime;
begin
  Result := Backoff + Cardinal(Random(Backoff div 2 + 1));
  if RetryAfter = '' then Exit;
  if TryStrToInt64(RetryAfter, Seconds) and (Seconds >= 0) then
  begin
    if Seconds > High(Cardinal) div 1000 then Exit(High(Cardinal));
    if UInt64(Seconds * 1000) > Result then Result := Seconds * 1000;
  end
  else if WinHttpTimeToSystemTime(PChar(RetryAfter), Utc) and SystemTimeToFileTime(Utc, FutureTime) then
  begin
    GetSystemTimeAsFileTime(NowTime);
    Difference := (PInt64(@FutureTime)^ - PInt64(@NowTime)^) div 10000;
    if (Difference > 0) and (UInt64(Difference) > Result) then Result := Difference;
  end;
end;

function TOTelHttpTransport.Post(const Payload: TBytes; Count: Integer; BatchDeadline: UInt64;
  out Warning: Boolean): Integer;
var
  Client: THTTPClient;
  Request: TBytesStream;
  Body: TResponseStream;
  Response: IHTTPResponse;
  Bytes: TBytes;
  Rejected, Delay, NowTick: UInt64;
  Backoff, Remaining: Cardinal;
  Status, Separator: Integer;
  RetryAfter, MediaType: string;
begin
  Result := Count;
  Warning := False;
  FDeadline := BatchDeadline;
  Backoff := 200;
  Request := TBytesStream.Create(Payload);
  Body := nil;
  Client := nil;
  try
    Body := TResponseStream.Create;
    Client := THTTPClient.Create;
    Client.HandleRedirects := False;
    Client.OnReceiveData := Receiving;
    while FAbort.WaitFor(0) <> wrSignaled do
    begin
      NowTick := FClock.MonotonicMs;
      if NowTick >= FDeadline then Exit;
      Remaining := Cardinal(FDeadline - NowTick);
      if Remaining > 3000 then Remaining := 3000;
      Client.ConnectionTimeout := Remaining;
      Client.ResponseTimeout := Remaining;
      Request.Position := 0;
      Response := nil;
      Body.Clear;
      RetryAfter := '';
      FResponseAborted := False;
      try
        Response := Client.Post(FEndpoint, Request, Body, FHeaders);
        if FResponseAborted then Exit;
        Status := Response.StatusCode;
        if Status = 200 then
        begin
          MediaType := Response.HeaderValue['Content-Type'];
          Separator := Pos(';', MediaType);
          if Separator > 0 then SetLength(MediaType, Separator - 1);
          MediaType := Trim(MediaType);
          if (MediaType <> '') and not SameText(MediaType, ProtobufType) then Exit;
          if (Body.Size > 0) and (MediaType = '') then Exit;
          SetLength(Bytes, Body.Size);
          if Body.Size > 0 then Move(Body.Memory^, Bytes[0], Body.Size);
          if FDecoder.Decode(Bytes, Rejected, Warning) and (Rejected <= UInt64(Count)) then
            Result := Integer(Rejected);
          Exit;
        end;
        if (Status <> 429) and (Status <> 502) and (Status <> 503) and (Status <> 504) then Exit;
        RetryAfter := Response.HeaderValue['Retry-After'];
      except
        on E: ENetHTTPCertificateException do Exit;
        on E: ENetException do begin { Connection failures follow the same bounded retry path. } end;
      end;
      Delay := RetryDelay(RetryAfter, Backoff);
      if FClock.MonotonicMs + Delay >= FDeadline then Exit;
      if FAbort.WaitFor(Cardinal(Delay)) = wrSignaled then Exit;
      if Backoff < 1600 then Backoff := Backoff * 2;
    end;
  finally
    Response := nil;
    Client.Free;
    Body.Free;
    Request.Free;
  end;
end;

end.
