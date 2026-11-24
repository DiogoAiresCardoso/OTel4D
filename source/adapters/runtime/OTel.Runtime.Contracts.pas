unit OTel.Runtime.Contracts;

interface

type
  IOTelWorkerTask = interface
    procedure Execute;
  end;

  IOTelBackgroundWorker = interface
    function WaitUntil(Deadline: UInt64): Boolean;
  end;

implementation

end.
