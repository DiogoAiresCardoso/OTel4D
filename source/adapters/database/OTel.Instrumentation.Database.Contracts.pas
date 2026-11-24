unit OTel.Instrumentation.Database.Contracts;

interface

uses
  System.SysUtils, OTel.Api;

type
  IOTelDatabaseMetadata = interface
    ['{9EE2D1C7-6BE2-478A-9164-EC09C5E3B5C1}']
    // The arguments contain safe defaults. Set only names known to the adapter.
    procedure ReadNames(var DatabaseName, OperationName: string);
  end;

  IOTelDatabaseOperation = interface
    ['{A9FCD3B9-7FD4-4246-A104-3BD7E3FF9E3B}']
    procedure Failed(const Error: Exception);
    // Finish on the same thread as the underlying call. Repeated calls are safe.
    procedure Finish;
  end;

  IOTelDatabaseCapture = interface
    ['{E39C5181-A99F-46AD-BC50-7C968FB91286}']
    function BeginOperation(const FallbackName: string;
      const Metadata: IOTelDatabaseMetadata): IOTelDatabaseOperation;
  end;

  IOTelDatabaseRecorder = interface(IOTelDatabaseCapture)
    ['{638717AC-3590-44E5-A884-83BECF377F7F}']
    // Borrowed compatibility handles. The recorder retains ownership.
    function GetTracer: TOTelTracer;
    function GetDuration: TOTelHistogram;
  end;

implementation

end.
