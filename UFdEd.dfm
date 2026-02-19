object FdEd: TFdEd
  Left = 1468
  Top = 436
  Width = 808
  Height = 531
  Caption = 'dEd'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 41
    Align = alTop
    TabOrder = 0
    object lblMode: TLabel
      Left = 260
      Top = 12
      Width = 51
      Height = 13
      Caption = #1042#1057#1058#1040#1042#1050#1040
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnLoad: TButton
      Left = 8
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Load'
      TabOrder = 0
      OnClick = btnLoadClick
    end
    object btnSave: TButton
      Left = 89
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Save'
      TabOrder = 1
      OnClick = btnSaveClick
    end
    object btnClear: TButton
      Left = 170
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Clear'
      TabOrder = 2
      OnClick = btnClearClick
    end
  end
end
