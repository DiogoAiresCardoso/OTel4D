unit OTel.Controller.Configuration;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TOTelConfigurationController = class
  private
    class function Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration; static;
  public
    // Borrows Overrides for this call. The caller owns the returned snapshot.
    class function LoadConfiguration(const Overrides: TOTelOptions = nil): TOTelConfiguration; static;
    class function LoadForClient(const Overrides: TOTelOptions): TOTelConfiguration; static;
  end;

implementation

uses
  OTel.Bootstrap;

class function TOTelConfigurationController.LoadConfiguration(const Overrides: TOTelOptions): TOTelConfiguration;
begin
  Result := Resolve(Overrides, False);
end;

class function TOTelConfigurationController.Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration;
var
  Bootstrap: IOTelBootstrap;
begin
  Bootstrap := TOTelBootstrap.Create;
  Result := Bootstrap.ResolveConfiguration(Overrides, ForClient);
end;

class function TOTelConfigurationController.LoadForClient(const Overrides: TOTelOptions): TOTelConfiguration;
begin
  Result := Resolve(Overrides, True);
end;

end.
