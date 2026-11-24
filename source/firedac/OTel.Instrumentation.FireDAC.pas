unit OTel.Instrumentation.FireDAC;

interface

uses
  OTel.Instrumentation.FireDAC.Binding, OTel.Instrumentation.FireDAC.Query,
  OTel.Instrumentation.FireDAC.StoredProc;

type
  TOTelFireDACInstrumentation = OTel.Instrumentation.FireDAC.Binding.TOTelFireDACInstrumentation;
  TFDOtelQuery = OTel.Instrumentation.FireDAC.Query.TFDOtelQuery;
  TFDOtelStoredProc = OTel.Instrumentation.FireDAC.StoredProc.TFDOtelStoredProc;

implementation

end.
