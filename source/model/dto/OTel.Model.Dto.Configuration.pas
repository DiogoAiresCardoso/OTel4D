unit OTel.Model.Dto.Configuration;

interface

uses
  System.SysUtils;

type
  TOTelOptions = class
  strict private
    FServiceName: string;
    FEndpoint: string;
    FTracesEndpoint: string;
    FTraceHeaders: string;
    FTraceProtocol: string;
    FTraceTimeoutMs: Integer;
    FSdkDisabled, FHasSdkDisabled: Boolean;
    procedure SetSdkDisabled(Value: Boolean);
    procedure SetTraceTimeoutMs(Value: Integer);
  public
    constructor Create;
    property ServiceName: string read FServiceName write FServiceName;
    property Endpoint: string read FEndpoint write FEndpoint;
    property TracesEndpoint: string read FTracesEndpoint write FTracesEndpoint;
    property TraceHeaders: string read FTraceHeaders write FTraceHeaders;
    property TraceProtocol: string read FTraceProtocol write FTraceProtocol;
    property TraceTimeoutMs: Integer read FTraceTimeoutMs write SetTraceTimeoutMs;
    property SdkDisabled: Boolean read FSdkDisabled write SetSdkDisabled;
    property HasSdkDisabled: Boolean read FHasSdkDisabled;
  end;

  TOTelConfiguration = class
  strict private
    FServiceName: string;
    FTracesEndpoint: string;
    FTraceHeaders: string;
    FSdkDisabled: Boolean;
    FTraceTimeoutMs: Integer;
  public
    constructor Create(const AServiceName, ATracesEndpoint: string); overload;
    constructor Create(const AServiceName, ATracesEndpoint, ATraceHeaders: string;
      ASdkDisabled: Boolean; ATraceTimeoutMs: Integer = 10000); overload;
    property ServiceName: string read FServiceName;
    property TracesEndpoint: string read FTracesEndpoint;
    property TraceHeaders: string read FTraceHeaders;
    property SdkDisabled: Boolean read FSdkDisabled;
    property TraceTimeoutMs: Integer read FTraceTimeoutMs;
  end;

  EOTelConfiguration = class(Exception);

implementation

constructor TOTelOptions.Create;
begin
  inherited Create;
  FTraceTimeoutMs := -1;
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

constructor TOTelConfiguration.Create(const AServiceName, ATracesEndpoint: string);
begin
  Create(AServiceName, ATracesEndpoint, '', False);
end;

constructor TOTelConfiguration.Create(const AServiceName, ATracesEndpoint, ATraceHeaders: string;
  ASdkDisabled: Boolean; ATraceTimeoutMs: Integer);
begin
  inherited Create;
  if ATraceTimeoutMs < 0 then raise EOTelConfiguration.Create('A trace timeout must be nonnegative.');
  FServiceName := AServiceName;
  FTracesEndpoint := ATracesEndpoint;
  FTraceHeaders := ATraceHeaders;
  FSdkDisabled := ASdkDisabled;
  FTraceTimeoutMs := ATraceTimeoutMs;
end;

end.
