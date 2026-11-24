unit OTel.Instrumentation.FireDAC;

interface

uses
  OTel.Instrumentation.FireDAC.Binding, OTel.Instrumentation.FireDAC.Query,
  OTel.Instrumentation.FireDAC.StoredProc;

type
  IOTelFireDACInstrumentation = OTel.Instrumentation.FireDAC.Binding.IOTelFireDACInstrumentation;
  IOTelFireDACDataSet = OTel.Instrumentation.FireDAC.Binding.IOTelFireDACDataSet;
  TOTelFireDACInstrumentation = OTel.Instrumentation.FireDAC.Binding.TOTelFireDACInstrumentation;
  TFDOtelQuery = OTel.Instrumentation.FireDAC.Query.TFDOtelQuery;
  TFDOtelStoredProc = OTel.Instrumentation.FireDAC.StoredProc.TFDOtelStoredProc;

implementation

end.
