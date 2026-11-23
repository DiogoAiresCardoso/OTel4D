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
  public
    property ServiceName: string read FServiceName write FServiceName;
    property Endpoint: string read FEndpoint write FEndpoint;
    property TracesEndpoint: string read FTracesEndpoint write FTracesEndpoint;
  end;

  TOTelConfiguration = class
  strict private
    FServiceName: string;
    FTracesEndpoint: string;
  public
    constructor Create(const AServiceName, ATracesEndpoint: string);
    property ServiceName: string read FServiceName;
    property TracesEndpoint: string read FTracesEndpoint;
  end;

  EOTelConfiguration = class(Exception);

implementation

constructor TOTelConfiguration.Create(const AServiceName, ATracesEndpoint: string);
begin
  inherited Create;
  FServiceName := AServiceName;
  FTracesEndpoint := ATracesEndpoint;
end;

end.
