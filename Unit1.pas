unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Memo1: TMemo;
    ProgressBar1: TProgressBar;
    OpenDialog1: TOpenDialog;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    procedure Log(const Msg: string);
    function Swap32(Value: LongWord): LongWord;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Log(const Msg: string);
begin
  Memo1.Lines.Add(Msg);
  Application.ProcessMessages;
end;

function TForm1.Swap32(Value: LongWord): LongWord;
begin
  Result := ((Value and $FF000000) shr 24) or
            ((Value and $00FF0000) shr 8)  or
            ((Value and $0000FF00) shl 8)  or
            ((Value and $000000FF) shl 24);
end;

// ==========================================
// ПОСЛЕДОВАТЕЛЬНАЯ РАСПАКОВКА С УЧЕТОМ BSP
// ==========================================
procedure TForm1.Button1Click(Sender: TObject);
var
  FS, OutFile: TFileStream;
  Manifest: TStringList;
  NameCounters: TStringList;
  GlobalSign: array[0..3] of Char;
  GlobalSizeBE: LongWord;
  
  Tag8: array[0..7] of Char;
  Tag4: array[0..3] of Char;
  CurrentTag, Ext, SavedName, LevelPath: string;
  
  ChunkSizeBE, ChunkSizeLE: LongWord;
  Idx, Count, i: Integer;
  PaddingByte: Byte;
  StartOffset: Int64;
  IsFirstFile: Boolean;
  IsBSP: Boolean;
begin
  OpenDialog1.Title := 'Выберите файл Vigilante 8 для распаковки';
  OpenDialog1.Filter := 'Файлы данных (*.EXP)|*.EXP|Все файлы (*.*)|*.*';

  if not OpenDialog1.Execute then Exit;

  Memo1.Clear;
  Log('--- Начало распаковки архива V8 ---');
  
  LevelPath := ExtractFilePath(Application.ExeName) + 'level\';
  ForceDirectories(LevelPath);

  FS := TFileStream.Create(OpenDialog1.FileName, fmOpenRead or fmShareDenyNone);
  Manifest := TStringList.Create;
  NameCounters := TStringList.Create;
  NameCounters.Sorted := True;
  ProgressBar1.Max := FS.Size;

  try
    if FS.Size < 8 then Exit;

    FS.ReadBuffer(GlobalSign, 4);
    FS.ReadBuffer(GlobalSizeBE, 4);
    
    Log('Глобальный заголовок: ' + Copy(GlobalSign, 1, 4));
    Log('Размер данных: ' + IntToStr(Swap32(GlobalSizeBE)) + ' байт');
    Log('----------------------------------------------------');

    IsFirstFile := True;

    while FS.Position <= FS.Size - 8 do
    begin
      StartOffset := FS.Position;
      CurrentTag := '';
      IsBSP := False;

      // 1. ОПРЕДЕЛЯЕМ ИМЯ И ТИП ТЕГА
      if IsFirstFile then
      begin
        FS.ReadBuffer(Tag8, 8);
        for i := 0 to 7 do
          if Tag8[i] <> #0 then CurrentTag := CurrentTag + Tag8[i];
        CurrentTag := Trim(CurrentTag);
        IsFirstFile := False;
      end
      else
      begin
        // Читаем сначала 4 байта, чтобы проверить, не BSP ли это
        FS.ReadBuffer(Tag4, 4);
        for i := 0 to 3 do
          if Tag4[i] <> #0 then CurrentTag := CurrentTag + Tag4[i];
        
        // УНИКАЛЬНОЕ УТОЧНЕНИЕ: Если встретили тег BSP (с пробелом или без)
        if (Trim(CurrentTag) = 'BSP') then
        begin
          CurrentTag := 'BSP ';
          IsBSP := True;
          // Указатель FS.Position сейчас стоит идеально: сразу после 4 байт 'BSP ' 
          // и указывает прямо на 4 байта размера! Ничего дочитывать не нужно.
        end
        else
        begin
          // Для обычных файлов имя имеет длину 4 байта, считываем дальше как обычно
          CurrentTag := Trim(CurrentTag);
        end;
      end;

      if CurrentTag = '' then Break;

      // 2. ЧИТАЕМ РАЗМЕР БЛОКА
      FS.ReadBuffer(ChunkSizeBE, 4);
      ChunkSizeLE := Swap32(ChunkSizeBE);

      if (FS.Position + ChunkSizeLE > FS.Size) then
      begin
        Log(Format('[0x%8.8X] Ошибка фазы чтения на теге %s. Размер: %d', [StartOffset, CurrentTag, ChunkSizeLE]));
        Break;
      end;

      // 3. СЧИТАЕМ ИНДЕКС ДЛЯ ИМЕНИ
      Idx := NameCounters.IndexOf(CurrentTag);
      if Idx = -1 then
      begin
        Count := 0;
        NameCounters.AddObject(CurrentTag, TObject(Count));
      end else
      begin
        Count := Integer(NameCounters.Objects[Idx]) + 1;
        NameCounters.Objects[Idx] := TObject(Count);
      end;

      // Выставляем расширения
      if (CurrentTag = 'TERRTITL') or (CurrentTag = 'TEXT') then Ext := '.txt'
      else if (CurrentTag = 'XBMP') or (CurrentTag = 'XBGM') then Ext := '.tim'
      else if (CurrentTag = 'COLS') then Ext := '.clr'
      else if (CurrentTag = 'FORM') then Ext := '.dat'
      else if (CurrentTag = 'ZMAP') then Ext := '.map'
      else if (CurrentTag = 'ZONE') then Ext := '.zon'
      else Ext := '';

      SavedName := Format('%s%.4d%s', [Trim(CurrentTag), Count, Ext]);
      Log(Format('[0x%8.8X] Извлечение: %s (%d байт)', [StartOffset, SavedName, ChunkSizeLE]));

      // Записываем в манифест признак BSP, чтобы пакер знал, как собирать
      if IsBSP then
        Manifest.Add(SavedName + '=BSP_SPECIAL')
      else
        Manifest.Add(SavedName + '=' + CurrentTag);

      // 4. СОХРАНЯЕМ НА ДИСК
      OutFile := TFileStream.Create(LevelPath + SavedName, fmCreate);
      try
        if ChunkSizeLE > 0 then
          OutFile.CopyFrom(FS, ChunkSizeLE);
      finally
        OutFile.Free;
      end;

      // Выравнивание по четной границе (модифицировано под вашу логику)
      if (ChunkSizeLE mod 2) <> 0 then
      begin
        if FS.Position < FS.Size then
        begin
          FS.ReadBuffer(PaddingByte, 1);
          if PaddingByte <> 0 then
            FS.Position := FS.Position - 1;
        end;
      end;

      ProgressBar1.Position := FS.Position;
    end;

    Manifest.SaveToFile(LevelPath + '!files.cfg');
    ProgressBar1.Position := ProgressBar1.Max;
    Log('=== РАСПАКОВКА УСПЕШНО ЗАВЕРШЕНА! ===');

  finally
    NameCounters.Free;
    Manifest.Free;
    FS.Free;
  end;
end;

// ==========================================
// СБОРКА С УЧЕТОМ УНИКАЛЬНОГО BSP
// ==========================================
procedure TForm1.Button2Click(Sender: TObject);
var
  FS, InFile: TFileStream;
  Manifest: TStringList;
  GlobalSign: array[0..3] of Char;
  GlobalSizeBE: LongWord;
  SizePos: Int64;
  Line, SavedName, OriginalTag, LevelPath: string;
  ChunkSizeBE, ChunkSizeLE: LongWord;
  PaddingByte: Byte;
  i, j, EqualPos: Integer;
  Tag8: array[0..7] of Char;
  Tag4: array[0..3] of Char;
  IsFirstFile: Boolean;
begin
  LevelPath := ExtractFilePath(Application.ExeName) + 'level\';

  if not FileExists(LevelPath + '!files.cfg') then
  begin
    ShowMessage('Ошибка: Не найден файл манифеста level/!files.cfg!');
    Exit;
  end;

  Memo1.Clear;
  Log('--- Начало сборки архива ---');

  Manifest := TStringList.Create;
  FS := TFileStream.Create(ExtractFilePath(Application.ExeName) + 'NEW_LEVEL.EXP', fmCreate);
  PaddingByte := 0;

  try
    Manifest.LoadFromFile(LevelPath + '!files.cfg');
    ProgressBar1.Max := Manifest.Count;

    GlobalSign := 'FORM';
    GlobalSizeBE := 0; 

    FS.WriteBuffer(GlobalSign, 4);
    SizePos := FS.Position; 
    FS.WriteBuffer(GlobalSizeBE, 4);

    IsFirstFile := True;

    for i := 0 to Manifest.Count - 1 do
    begin
      Line := Manifest[i];
      EqualPos := Pos('=', Line);
      if EqualPos = 0 then Continue;
      
      SavedName := Copy(Line, 1, EqualPos - 1);
      OriginalTag := Copy(Line, EqualPos + 1, Length(Line) - EqualPos);

      if not FileExists(LevelPath + SavedName) then Continue;

      Log('Упаковка: ' + SavedName);

      // ЗАПИСЬ ЗАГОЛОВКА
      if IsFirstFile then
      begin
        FillChar(Tag8, 8, #0);
        for j := 1 to Length(OriginalTag) do
          if j <= 8 then Tag8[j-1] := OriginalTag[j];
        FS.WriteBuffer(Tag8, 8);
        IsFirstFile := False;
      end
      else if OriginalTag = 'BSP_SPECIAL' then
      begin
        // Если это наш уникальный BSP блок, пишем ровно 4 байта 'BSP '
        Tag4 := 'BSP ';
        FS.WriteBuffer(Tag4, 4);
      end
      else
      begin
        FillChar(Tag4, 4, #0);
        for j := 1 to Length(OriginalTag) do
          if j <= 4 then Tag4[j-1] := OriginalTag[j];
        FS.WriteBuffer(Tag4, 4);
      end;

      // ЗАПИСЬ РАЗМЕРА И ТЕЛА
      InFile := TFileStream.Create(LevelPath + SavedName, fmOpenRead or fmShareDenyNone);
      try
        ChunkSizeLE := InFile.Size;
        ChunkSizeBE := Swap32(ChunkSizeLE);
        FS.WriteBuffer(ChunkSizeBE, 4);

        if InFile.Size > 0 then
          FS.CopyFrom(InFile, InFile.Size);
      finally
        InFile.Free;
      end;

      if (ChunkSizeLE mod 2) <> 0 then
        FS.WriteBuffer(PaddingByte, 1);
        
      ProgressBar1.Position := i + 1;
    end;

    GlobalSizeBE := Swap32(FS.Size - 8);
    FS.Position := SizePos;
    FS.WriteBuffer(GlobalSizeBE, 4);

    ProgressBar1.Position := ProgressBar1.Max;
    Log('=== СБОРКА УСПЕШНО ЗАВЕРШЕНА! ===');

  finally
    Manifest.Free;
    FS.Free;
  end;
end;

end.

