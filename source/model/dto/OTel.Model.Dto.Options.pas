unit OTel.Model.Dto.Options;

interface

uses
  OTel.Model.Dto.SignalSettings;

type
  TOTelOptions = class
  strict private
    FSignals: array[0..1] of TOTelSignalSettings;
    FMetricsIntervalMs: Integer;
    FServiceName: string;
    FEndpoint: string;
    FTracesEndpoint: string;
    FTraceHeaders: string;
    FTraceProtocol: string;
    FTraceTimeoutMs: Integer;
    FSdkDisabled, FHasSdkDisabled: Boolean;
    function GetSignal(Index: Integer): TOTelSignalSettings;
    procedure SetMetricsInterval(Value: Integer);
    function GetSignalEndpoint(Index: Integer): string;
    procedure SetSignalEndpoint(Index: Integer; const Value: string);
    function GetSignalHeaders(Index: Integer): string;
    procedure SetSignalHeaders(Index: Integer; const Value: string);
    function GetSignalProtocol(Index: Integer): string;
    procedure SetSignalProtocol(Index: Integer; const Value: string);
    function GetSignalTimeoutMs(Index: Integer): Integer;
    procedure SetSignalTimeoutMs(Index: Integer; Value: Integer);
    procedure SetSdkDisabled(Value: Boolean);
    procedure SetTraceTimeoutMs(Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    property Logs: TOTelSignalSettings index 0 read GetSignal;
    property Metrics: TOTelSignalSettings index 1 read GetSignal;
    property LogsEndpoint: string index 0 read GetSignalEndpoint write SetSignalEndpoint;
    property LogsHeaders: string index 0 read GetSignalHeaders write SetSignalHeaders;
    property LogsProtocol: string index 0 read GetSignalProtocol write SetSignalProtocol;
    property LogsTimeoutMs: Integer index 0 read GetSignalTimeoutMs write SetSignalTimeoutMs;
    property MetricsEndpoint: string index 1 read GetSignalEndpoint write SetSignalEndpoint;
    property MetricsHeaders: string index 1 read GetSignalHeaders write SetSignalHeaders;
    property MetricsProtocol: string index 1 read GetSignalProtocol write SetSignalProtocol;
    property MetricsTimeoutMs: Integer index 1 read GetSignalTimeoutMs write SetSignalTimeoutMs;
    property MetricsIntervalMs: Integer read FMetricsIntervalMs write SetMetricsInterval;
    property ServiceName: string read FServiceName write FServiceName;
    property Endpoint: string read FEndpoint write FEndpoint;
    property TracesEndpoint: string read FTracesEndpoint write FTracesEndpoint;
    property TraceHeaders: string read FTraceHeaders write FTraceHeaders;
    property TraceProtocol: string read FTraceProtocol write FTraceProtocol;
    property TraceTimeoutMs: Integer read FTraceTimeoutMs write SetTraceTimeoutMs;
    property SdkDisabled: Boolean read FSdkDisabled write SetSdkDisabled;
    property HasSdkDisabled: Boolean read FHasSdkDisabled;
  end;

implementation

uses
  OTel.Model.Dto.ConfigurationError;

constructor TOTelOptions.Create;
begin
  inherited Create;
  FTraceTimeoutMs := -1;
  FSignals[0] := TOTelSignalSettings.Create;
  FSignals[1] := TOTelSignalSettings.Create;
end;

destructor TOTelOptions.Destroy;
begin
  FSignals[1].Free;
  FSignals[0].Free;
  inherited;
end;

function TOTelOptions.GetSignal(Index: Integer): TOTelSignalSettings;
begin
  Result := FSignals[Index];
end;

procedure TOTelOptions.SetMetricsInterval(Value: Integer);
begin
  if Value < 1 then raise EOTelConfiguration.Create('The metric export interval must be positive.');
  FMetricsIntervalMs := Value;
end;

function TOTelOptions.GetSignalEndpoint(Index: Integer): string;
begin
  Result := FSignals[Index].Endpoint;
end;

procedure TOTelOptions.SetSignalEndpoint(Index: Integer; const Value: string);
begin
  FSignals[Index].Endpoint := Value;
end;

function TOTelOptions.GetSignalHeaders(Index: Integer): string;
begin
  Result := FSignals[Index].Headers;
end;

procedure TOTelOptions.SetSignalHeaders(Index: Integer; const Value: string);
begin
  FSignals[Index].Headers := Value;
end;

function TOTelOptions.GetSignalProtocol(Index: Integer): string;
begin
  Result := FSignals[Index].Protocol;
end;

procedure TOTelOptions.SetSignalProtocol(Index: Integer; const Value: string);
begin
  FSignals[Index].Protocol := Value;
end;

function TOTelOptions.GetSignalTimeoutMs(Index: Integer): Integer;
begin
  Result := FSignals[Index].TimeoutMs;
end;

procedure TOTelOptions.SetSignalTimeoutMs(Index: Integer; Value: Integer);
begin
  if Value < 0 then raise EOTelConfiguration.Create('An export timeout must be nonnegative.');
  FSignals[Index].TimeoutMs := Value;
end;

procedure TOTelOptions.SetTraceTimeoutMs(Value: Integer);
begin
  if Value < 0 then raise EOTelConfiguration.Create('A trace timeout must be nonnegative.');
  FTraceTimeoutMs := Value;
end;

procedure TOTelOptions.SetSdkDisabled(Value: Boolean);
begin
  FSdkDisabled := Value;
  FHasSdkDisabled := True;
end;

end.
