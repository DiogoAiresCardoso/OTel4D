object TelemetryDemoForm: TTelemetryDemoForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'OTel4D Telemetry Lab'
  ClientHeight = 393
  ClientWidth = 664
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 17
  object TitleLabel: TLabel
    Left = 24
    Top = 19
    Width = 344
    Height = 31
    Caption = 'Run a telemetry scenario'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -23
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object SummaryLabel: TLabel
    Left = 24
    Top = 58
    Width = 616
    Height = 17
    Caption = 'Send correlated logs, traces and metrics for a simulated order.'
  end
  object ConnectionGroup: TGroupBox
    Left = 24
    Top = 96
    Width = 616
    Height = 97
    Caption = 'Local Collector'
    TabOrder = 0
    object PortLabel: TLabel
      Left = 18
      Top = 25
      Width = 130
      Height = 17
      Caption = 'http://127.0.0.1 port'
      FocusControl = PortEdit
    end
    object PortEdit: TEdit
      Left = 18
      Top = 49
      Width = 78
      Height = 25
      MaxLength = 5
      NumbersOnly = True
      TabOrder = 0
      Text = '4318'
    end
    object ScenarioLabel: TLabel
      Left = 155
      Top = 25
      Width = 52
      Height = 17
      Caption = 'Sce&nario'
      FocusControl = ScenarioCombo
    end
    object ScenarioCombo: TComboBox
      Left = 155
      Top = 49
      Width = 245
      Height = 25
      Style = csDropDownList
      TabOrder = 1
    end
    object SendButton: TButton
      Left = 450
      Top = 44
      Width = 146
      Height = 35
      Caption = '&Run scenario'
      Default = True
      TabOrder = 2
      OnClick = SendButtonClick
    end
  end
  object ResultGroup: TGroupBox
    Left = 24
    Top = 212
    Width = 616
    Height = 157
    Caption = 'Delivery result'
    TabOrder = 1
    object StatusLabel: TLabel
      Left = 18
      Top = 27
      Width = 578
      Height = 45
      AutoSize = False
      Caption = 'Ready to send.'
      WordWrap = True
    end
    object TraceIdLabel: TLabel
      Left = 18
      Top = 84
      Width = 47
      Height = 17
      Caption = '&Trace ID'
      FocusControl = TraceIdEdit
    end
    object SpanIdLabel: TLabel
      Left = 18
      Top = 119
      Width = 45
      Height = 17
      Caption = 'S&pan ID'
      FocusControl = SpanIdEdit
    end
    object TraceIdEdit: TEdit
      Left = 92
      Top = 79
      Width = 504
      Height = 25
      ReadOnly = True
      TabOrder = 0
    end
    object SpanIdEdit: TEdit
      Left = 92
      Top = 114
      Width = 504
      Height = 25
      ReadOnly = True
      TabOrder = 1
    end
  end
  object CompletionTimer: TTimer
    Enabled = False
    Interval = 100
    OnTimer = CompletionTimerTimer
    Left = 616
    Top = 20
  end
end.
