object Form1: TForm1
  Left = 192
  Top = 125
  Width = 345
  Height = 384
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 8
    Top = 8
    Width = 75
    Height = 25
    Caption = 'UNPACK'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 248
    Top = 8
    Width = 75
    Height = 25
    Caption = 'PACK'
    TabOrder = 1
    OnClick = Button2Click
  end
  object Memo1: TMemo
    Left = 8
    Top = 72
    Width = 313
    Height = 265
    Lines.Strings = (
      'Memo1')
    TabOrder = 2
  end
  object ProgressBar1: TProgressBar
    Left = 8
    Top = 40
    Width = 313
    Height = 17
    TabOrder = 3
  end
  object OpenDialog1: TOpenDialog
    Left = 96
    Top = 8
  end
end
