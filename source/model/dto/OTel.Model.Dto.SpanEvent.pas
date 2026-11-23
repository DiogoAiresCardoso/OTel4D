unit OTel.Model.Dto.SpanEvent;

interface

type
  TOTelEvent = class
  public
    Name, ExceptionType, ExceptionMessage: string;
    TimeNanos: UInt64;
  end;

implementation

end.
