unit OTel.Example.LogBridge;

interface

uses
  OTel.Api;

type
  TOrderLogBridge = class
  strict private
    FLogger: TOTelLogger;
  public
    constructor Create(Client: TOTelTraceClient);
    destructor Destroy; override;
    procedure OnOrderFailure(const ExceptionClass: string);
  end;

implementation

constructor TOrderLogBridge.Create(Client: TOTelTraceClient);
begin
  inherited Create;
  FLogger := Client.GetLogger('orders.host-logger', '1.0');
end;

destructor TOrderLogBridge.Destroy;
begin
  FLogger.Free;
  inherited;
end;

procedure TOrderLogBridge.OnOrderFailure(const ExceptionClass: string);
var
  Attributes: TOTelAttributes;
begin
  Attributes := TOTelAttributes.Create;
  try
    Attributes.Put('exception.type', ExceptionClass);
    // Forward an allowlisted message instead of the host logger's raw arguments.
    FLogger.Emit(llError, 'Order processing failed', Attributes);
  finally
    Attributes.Free;
  end;
end;

end.
