unit UFdEd;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Menus, IniFiles, UdEd;

const
  cIniFile = 'dEd.ini';

type
  TFdEd = class(TForm)
    Panel1: TPanel;
    btnLoad: TButton;
    btnSave: TButton;
    btnClear: TButton;
    lblMode: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure UpdateModeIndicator;
    procedure EditorInsertModeChange(Sender: TObject);
    procedure LoadSettings;
    procedure SaveSettings;
  private
    FEd: TdEd;
//  mmMain: TMainMenu;
    pmEditor: TPopupMenu;
    miFont: TMenuItem;
    miFontName: TMenuItem;
    miFontSize: TMenuItem;
    miColor: TMenuItem;
    miTextColor: TMenuItem;
    miBackColor: TMenuItem;
    N1: TMenuItem;  // Разделитель
    miExit: TMenuItem;
    procedure InitializeEditor;
    procedure miFontNameClick(Sender: TObject);
    procedure miFontSizeClick(Sender: TObject);
    procedure miTextColorClick(Sender: TObject);
    procedure miBackColorClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
  public
  end;

var
  FdEd: TFdEd;

implementation

{$R *.dfm}

procedure TFdEd.FormCreate(Sender: TObject);
begin
  InitializeEditor;
{
  // Создаем главное меню
  mmMain := TMainMenu.Create(Self);
  Menu := mmMain;
}
  // Создаем контекстное меню
  pmEditor := TPopupMenu.Create(Self);

  miFont := TMenuItem.Create(Self);
  miFont.Caption := 'Шрифт';
//mmMain.Items.Add(miFont);
  pmEditor.Items.Add(miFont);

  miFontName := TMenuItem.Create(Self);
  miFontName.Caption := 'Выбрать шрифт...';
  miFontName.OnClick := miFontNameClick;
  miFont.Add(miFontName);

  miFontSize := TMenuItem.Create(Self);
  miFontSize.Caption := 'Размер шрифта...';
  miFontSize.OnClick := miFontSizeClick;
  miFont.Add(miFontSize);

  miColor := TMenuItem.Create(Self);
  miColor.Caption := 'Цвет';
  pmEditor.Items.Add(miColor);

  miTextColor := TMenuItem.Create(Self);
  miTextColor.Caption := 'Цвет текста...';
  miTextColor.OnClick := miTextColorClick;
  miColor.Add(miTextColor);

  miBackColor := TMenuItem.Create(Self);
  miBackColor.Caption := 'Цвет фона...';
  miBackColor.OnClick := miBackColorClick;
  miColor.Add(miBackColor);

  N1 := TMenuItem.Create(Self);
  N1.Caption := '-';
  pmEditor.Items.Add(N1);

  miExit := TMenuItem.Create(Self);
  miExit.Caption := 'Выход';
  miExit.OnClick := miExitClick;
//mmMain.Items.Add(miExit);
  pmEditor.Items.Add(miExit);

//Назначаем меню редактору
  FEd.PopupMenu := pmEditor;

  // Загружаем настройки после создания редактора
  LoadSettings;
end;

procedure TFdEd.FormDestroy(Sender: TObject);
begin
  SaveSettings;  // Сохраняем настройки перед выходом
  FEd.Free;
end;

procedure TFdEd.InitializeEditor;
begin
  FEd := TdEd.Create(Self);
  FEd.Parent := Self;
  FEd.Align := alClient;
  FEd.EditorFont.Name := 'Courier New';
  FEd.EditorFont.Size := 10;
  FEd.EditorColor := clWhite;
  FEd.OnInsertModeChange := EditorInsertModeChange;

  // Добавляем тестовые строки
  FEd.Lines.BeginUpdate;
  try
    FEd.Lines.Add('Это тестовый редактор');
    FEd.Lines.Add('Строка 2: короткая');
    FEd.Lines.Add('Строка 3: очень длинная строка для проверки прокрутки и курсора');
    FEd.Lines.Add('Строка 4: еще одна строка');
    FEd.Lines.Add('Строка 5: последняя строка');
  finally
    FEd.Lines.EndUpdate;
  end;

end;

procedure TFdEd.btnLoadClick(Sender: TObject);
var
  OpenDialog: TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(nil);
  try
    OpenDialog.Filter := 'Text files (*.txt)|*.txt|All files (*.*)|*.*';
    if OpenDialog.Execute then
    begin
      FEd.LoadFromFile(OpenDialog.FileName);
      Caption := 'Simple Editor - ' + ExtractFileName(OpenDialog.FileName);
    end;
  finally
    OpenDialog.Free;
  end;
end;

procedure TFdEd.btnSaveClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
begin
  SaveDialog := TSaveDialog.Create(nil);
  try
    SaveDialog.Filter := 'Text files (*.txt)|*.txt|All files (*.*)|*.*';
    SaveDialog.DefaultExt := 'txt';
    if SaveDialog.Execute then
    begin
      FEd.SaveToFile(SaveDialog.FileName);
      Caption := 'Simple Editor - ' + ExtractFileName(SaveDialog.FileName);
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TFdEd.btnClearClick(Sender: TObject);
begin
  FEd.Lines.Clear;
  FEd.Lines.Add('');
  FEd.SetFocus;
end;

procedure TFdEd.UpdateModeIndicator;
begin
  if FEd.InsertMode then
    lblMode.Caption := 'ВСТАВКА'
  else
    lblMode.Caption := 'ЗАМЕНА';
end;

procedure TFdEd.EditorInsertModeChange(Sender: TObject);
begin
  if FEd.InsertMode then
    lblMode.Caption := 'ВСТАВКА'
  else
    lblMode.Caption := 'ЗАМЕНА';
end;

procedure TFdEd.miFontNameClick(Sender: TObject);
var
  FontDialog: TFontDialog;
  NewFont: TFont;
begin
  FontDialog := TFontDialog.Create(Self);
  try
    FontDialog.Font := FEd.EditorFont;  // Берем текущий шрифт
    FontDialog.Options := [fdForceFontExist, fdLimitSize];
    FontDialog.MinFontSize := 8;
    FontDialog.MaxFontSize := 72;
    
    if FontDialog.Execute then
    begin
      // Создаем временный шрифт
      NewFont := TFont.Create;
      try
        NewFont.Assign(FontDialog.Font);
        // Присваиваем через свойство, чтобы вызвался SetEditorFont
        FEd.EditorFont := NewFont;
      finally
        NewFont.Free;
      end;
    end;
  finally
    FontDialog.Free;
  end;
  FEd.SetFocus;
end;

procedure TFdEd.miFontSizeClick(Sender: TObject);
var
  sSize: string;
  iSize: Integer;
  NewFont: TFont;
begin
  sSize := IntToStr(FEd.EditorFont.Size);
  if InputQuery('Размер шрифта', 'Введите размер шрифта (8-72):', sSize) then
  begin
    iSize := StrToIntDef(sSize, 0);
    if (iSize >= 8) and (iSize <= 72) then
    begin
      // Создаем временный шрифт с новым размером
      NewFont := TFont.Create;
      try
        NewFont.Assign(FEd.EditorFont);
        NewFont.Size := iSize;
        // Присваиваем через свойство
        FEd.EditorFont := NewFont;
      finally
        NewFont.Free;
      end;
    end
    else
      MessageDlg('Недопустимый размер шрифта!', mtError, [mbOK], 0);
  end;
  FEd.SetFocus;
end;

procedure TFdEd.miTextColorClick(Sender: TObject);
var
  ColorDialog: TColorDialog;
  NewFont: TFont;
begin
  ColorDialog := TColorDialog.Create(Self);
  try
    ColorDialog.Color := FEd.EditorFont.Color;
    ColorDialog.Options := [cdFullOpen];
    
    if ColorDialog.Execute then
    begin
      // Создаем временный шрифт с новым цветом
      NewFont := TFont.Create;
      try
        NewFont.Assign(FEd.EditorFont);
        NewFont.Color := ColorDialog.Color;
        // Присваиваем через свойство
        FEd.EditorFont := NewFont;
      finally
        NewFont.Free;
      end;
    end;
  finally
    ColorDialog.Free;
  end;
  FEd.SetFocus;
end;

{
procedure TFdEd.miTextColorClick(Sender: TObject);
var
  ColorDialog: TColorDialog;
begin
  ColorDialog := TColorDialog.Create(Self);
  try
    ColorDialog.Color := FEd.EditorFont.Color;
    ColorDialog.Options := [cdFullOpen];

    if ColorDialog.Execute then
    begin
      FEd.EditorFont.Color := ColorDialog.Color;
      FEd.SetFocus;
    end;
  finally
    ColorDialog.Free;
  end;
end;
}

procedure TFdEd.miBackColorClick(Sender: TObject);
var
  ColorDialog: TColorDialog;
begin
  ColorDialog := TColorDialog.Create(Self);
  try
    ColorDialog.Color := FEd.EditorColor;
    ColorDialog.Options := [cdFullOpen];

    if ColorDialog.Execute then
    begin
      FEd.EditorColor := ColorDialog.Color;
      FEd.SetFocus;
    end;
  finally
    ColorDialog.Free;
  end;
end;

procedure TFdEd.miExitClick(Sender: TObject);
begin
  Close;
end;


{
procedure TFdEd.LoadSettings;
var
  Ini: TIniFile;
  sFontName: string;
  iFontSize: Integer;
  iFontColor: Integer;
  iBackColor: Integer;
  iFontStyle: Integer;
  NewFont: TFont;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + cIniFile);
  try
    // Читаем настройки шрифта
    sFontName := Ini.ReadString('Font', 'Name', 'Courier New');
    iFontSize := Ini.ReadInteger('Font', 'Size', 10);
    iFontColor := Ini.ReadInteger('Font', 'Color', clBlack);
    iFontStyle := Ini.ReadInteger('Font', 'Style', 0);

    // Читаем цвет фона
    iBackColor := Ini.ReadInteger('Editor', 'BackColor', clWhite);

    // Применяем настройки
    NewFont := TFont.Create;
    try
      NewFont.Name := sFontName;
      NewFont.Size := iFontSize;
      NewFont.Color := iFontColor;
      NewFont.Style := TFontStyles(Byte(iFontStyle));  // Преобразуем byte в set

      FEd.EditorFont := NewFont;
    finally
      NewFont.Free;
    end;

    FEd.EditorColor := iBackColor;

  finally
    Ini.Free;
  end;
end;
}

procedure TFdEd.LoadSettings;
var
  Ini: TIniFile;
  sFontName: string;
  iFontSize: Integer;
  sFontColor: string;
  sBackColor: string;
  iFontStyle: Integer;
  NewFont: TFont;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + cIniFile);
  try
    // Читаем настройки шрифта
    sFontName := Ini.ReadString('Font', 'Name', 'Courier New');
    iFontSize := Ini.ReadInteger('Font', 'Size', 10);
    sFontColor := Ini.ReadString('Font', 'Color', '000000');  // Черный по умолчанию
    iFontStyle := Ini.ReadInteger('Font', 'Style', 0);
    
    // Читаем цвет фона (HEX)
    sBackColor := Ini.ReadString('Editor', 'BackColor', 'FFFFFF');  // Белый по умолчанию
    
    // Применяем настройки
    NewFont := TFont.Create;
    try
      NewFont.Name := sFontName;
      NewFont.Size := iFontSize;
      
      // Преобразуем HEX строку в TColor
      if sFontColor <> '' then
        NewFont.Color := TColor(StrToInt('$' + sFontColor));
        
      NewFont.Style := TFontStyles(Byte(iFontStyle));
      
      FEd.EditorFont := NewFont;
    finally
      NewFont.Free;
    end;
    
    // Устанавливаем цвет фона из HEX
    if sBackColor <> '' then
      FEd.EditorColor := TColor(StrToInt('$' + sBackColor));
    
  finally
    Ini.Free;
  end;
end;

procedure TFdEd.SaveSettings;
var
  Ini: TIniFile;
  bStyle: Byte;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + cIniFile);
  try
    // Сохраняем настройки шрифта
    Ini.WriteString('Font', 'Name', FEd.EditorFont.Name);
    Ini.WriteInteger('Font', 'Size', FEd.EditorFont.Size);
    
    // Сохраняем цвет текста в HEX (без префикса $)
    Ini.WriteString('Font', 'Color',
      IntToHex(ColorToRGB(FEd.EditorFont.Color), 6));

    // TFontStyle - это set, сохраняем как byte
    bStyle := Byte(FEd.EditorFont.Style);
    Ini.WriteInteger('Font', 'Style', bStyle);

    // Сохраняем цвет фона в HEX
    Ini.WriteString('Editor', 'BackColor',
      IntToHex(ColorToRGB(FEd.EditorColor), 6));

  finally
    Ini.Free;
  end;
end;

{
procedure TFdEd.SaveSettings;
var
  Ini: TIniFile;
  bStyle: Byte;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + cIniFile);
  try
    // Сохраняем настройки шрифта
    Ini.WriteString('Font', 'Name', FEd.EditorFont.Name);
    Ini.WriteInteger('Font', 'Size', FEd.EditorFont.Size);
    Ini.WriteInteger('Font', 'Color', FEd.EditorFont.Color);

    // TFontStyle - это set, сохраняем как byte
    bStyle := Byte(FEd.EditorFont.Style);
    Ini.WriteInteger('Font', 'Style', bStyle);

    // Сохраняем цвет фона
    Ini.WriteInteger('Editor', 'BackColor', FEd.EditorColor);

  finally
    Ini.Free;
  end;
end;
}
end.
