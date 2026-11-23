object DatabaseFixture: TDatabaseFixture
  object Connection: TFDConnection
    LoginPrompt = False
  end
  object Instrumentation: TOTelFireDACInstrumentation
  end
  object Query: TFDOtelQuery
    Instrumentation = Instrumentation
    Connection = Connection
    AfterOpen = QueryAfterOpen
    object QueryAmount: TIntegerField
      FieldName = 'amount'
    end
  end
  object Proc: TFDOtelStoredProc
    Instrumentation = Instrumentation
    Connection = Connection
  end
end
