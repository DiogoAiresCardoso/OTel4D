unit OTel.Model.Dto.Configuration;

interface

uses
  System.SysUtils;

type
  TOTelOptions = record
    ServiceName: string;
    Endpoint: string;
    TracesEndpoint: string;
  end;

  TOTelConfiguration = record
  private
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
  FServiceName := AServiceName;
  FTracesEndpoint := ATracesEndpoint;
end;

end.
