unit OTel.Transport.ResponseStream;

interface

uses
  System.Classes, System.SysUtils;

const
  MaxResponseBytes = 4 * 1024 * 1024;

type
  TResponseStream = class(TMemoryStream)
  private
    procedure CheckSize(Count: Integer);
  public
    function Write(const Buffer; Count: Longint): Longint; overload; override;
    function Write(const Buffer: TBytes; Offset, Count: Longint): Longint; overload; override;
  end;

implementation

uses
  OTel.Transport.ResponseLimit;

procedure TResponseStream.CheckSize(Count: Integer);
begin
  if Count > MaxResponseBytes - Position then raise EResponseLimit.Create('OTLP response exceeded the limit.');
end;

function TResponseStream.Write(const Buffer; Count: Longint): Longint;
begin
  CheckSize(Count);
  Result := inherited Write(Buffer, Count);
end;

function TResponseStream.Write(const Buffer: TBytes; Offset, Count: Longint): Longint;
begin
  CheckSize(Count);
  Result := inherited Write(Buffer, Offset, Count);
end;

end.
