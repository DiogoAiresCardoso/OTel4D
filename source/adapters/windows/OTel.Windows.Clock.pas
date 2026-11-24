unit OTel.Windows.Clock;

interface

uses
  OTel.Application.Ports;

type
  TOTelWindowsClock = class(TInterfacedObject, IOTelClock)
  public
    function MonotonicMs: UInt64;
    function UnixNanos: UInt64;
  end;

implementation

uses
  Winapi.Windows;

function TOTelWindowsClock.MonotonicMs: UInt64;
begin
  Result := GetTickCount64;
end;

function TOTelWindowsClock.UnixNanos: UInt64;
const
  UnixEpochTicks: UInt64 = 116444736000000000;
var
  Time: TFileTime;
begin
  GetSystemTimeAsFileTime(Time);
  Result := (((UInt64(Time.dwHighDateTime) shl 32) or Time.dwLowDateTime) - UnixEpochTicks) * 100;
end;

end.
