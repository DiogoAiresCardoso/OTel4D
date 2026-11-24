unit OTel.Transport.Contracts;

interface

uses
  System.SysUtils;

type
  IOTelRequestTransport = interface
    function Deadline: UInt64;
    function Post(const Payload: TBytes; Count: Integer; BatchDeadline: UInt64;
      out Warning: Boolean): Integer;
    procedure Cancel;
  end;

implementation

end.
