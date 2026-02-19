unit UdEd;

(*=================================================================*)
(*                                                                 *)
(*                     модуль Редактора                            *)
(*                     версия dEd (dialogEditor)                   *)
(*                                                                 *)
(*     TCustomControl +                                            *)
(*     ini-system     +                                            *)
(*     Macro          + ...                                        *)
(*                                                                 *)
(*                                                                 *)
(*=================================================================*)


interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, StdCtrls, ExtCtrls,
  Menus, IniFiles;

type

// элементы, которые кладём в FlMacro
TNamedMacro = record
  Ch : char; (* код текущей команды *)
  sMacro : string; (* тело (=строка) макрокоманды *)
  sHint  : string; (* описание команды *)
end;

TMacroList = class(TList);

 // Добавить константу для пользовательского сообщения
    const WM_EXECUTE_COMMAND = WM_USER + 100;


type
  TdEd = class(TCustomControl)
  private

    FLines: TStringList;

    FKW: byte; (* режим в момент записи: 0-ветка символов, 1-ветка команд *)

{
  FRecording := False;
  FLastCmdIdx := 0;
  FLastExecIdx := 0;
}
    FKR: byte; (* режим в момент выполнения: 0-ветка символов, 1-ветка команд *)
    FqMacro: boolean; (* режим записи макрокоманды *)
    FsCom: string;    (* текущая команда *)
    FiExe: integer;   (* номер последней отработанной команды *)
    FiCom: integer;   (* номер последней записанной команды = length(FsCom) *)
    FsMacro: string;  (* текущая макрокоманда *)
    FlMacro: TMacroList; (* список макрокоманд *)

    FInitialized: Boolean;
    FInsertMode: Boolean;
    FCaretVisible: Boolean;
    FMaxLength: Integer;  (* Макс.длина строки текста *)

    (* привязка окна *)
    FTopLine: Integer;
    FLeftColumn: Integer;

    (* управление кареткой и размеры символов на экране *)
    FCaretX, FCaretY: Integer;
    FCaretTimer: TTimer;
    FCharWidth: Integer;
    FCharHeight: Integer;

    (* фонт *)
    FEditorFont: TFont;
    FEditorColor: TColor;
    FOnInsertModeChange: TNotifyEvent;
    (*-----------------------------------------------------------------------*)
    procedure CaretTimerHandler(Sender: TObject);
    procedure SetLines(const Value: TStringList);
    procedure SetTopLine(Value: Integer);
    procedure SetEditorFont(const Value: TFont);
    procedure SetEditorColor(const Value: TColor);
    procedure UpdateMetrics;
    function GetVisibleLines: Integer;
    procedure EnsureCaretVisible;
    procedure CaretReCharge;
    procedure SetInsertMode(Value: Boolean);
    procedure ExecKey(Key: Char);
    procedure ExecCom(Key: Char);
    procedure WMExecuteCommand(var Message: TMessage); message WM_EXECUTE_COMMAND;

  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Paint; override;

    (* управление *)
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MouseWheel;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);
    property PopupMenu;
    property Lines: TStringList read FLines write SetLines;
    property InsertMode: Boolean read FInsertMode write SetInsertMode;
    property jsTop: Integer read FTopLine write SetTopLine;
    property MaxLength: Integer read FMaxLength write FMaxLength default 4000;
    property EditorFont: TFont read FEditorFont write SetEditorFont;
    property EditorColor: TColor read FEditorColor write SetEditorColor;
    property OnInsertModeChange: TNotifyEvent read FOnInsertModeChange
                                             write FOnInsertModeChange;
  end;

implementation

uses Forms,Math,UStr,
      UFdEd;      // временно для отладки

function KeyToChar(VKey: Word; Shift: TShiftState): Char;
var
  KeyBoardState: TKeyBoardState;
  AsciiResult: Integer;
  Buffer: array[0..1] of Char;
begin
  Result := #0;
  GetKeyBoardState(KeyBoardState);

  //Учитываем нажатые модификаторы
  if ssShift in Shift then
    KeyBoardState[VK_SHIFT] := $80;
  if ssCtrl in Shift then
    KeyBoardState[VK_CONTROL] := $80;
  if ssAlt in Shift then
    KeyBoardState[VK_MENU] := $80;

  AsciiResult := ToAscii(VKey,MapVirtualKey(VKey, 0), KeyBoardState,
                         @Buffer, 0);
  if AsciiResult = 1 then
    Result := Buffer[0];
end;

function KeyDownShift(Shift: TShiftState):byte;
var
  b2: byte;
begin
  b2 := 0;
  if ssShift in Shift then
    b2 := b2 or $01;       // Бит 0: Shift
  if ssCtrl in Shift then
    b2 := b2 or $02;       // Бит 1: Ctrl
  if GetAsyncKeyState(VK_LMENU) < 0 then
    b2 := b2 or $04;       // Бит 2: LeftAlt Or LeftAlt+RightAlt
  if ((GetAsyncKeyState(VK_RMENU) <  0)  and
      (GetAsyncKeyState(VK_LMENU) >= 0)) then
    b2 := b2 or $08;      // Бит 3: RightAlt БЕЗ LeftAlt
  if ((GetKeyState(VK_CAPITAL) and 1) <> 0) then
    b2 := b2 or $10;      // Бит 4: Caps Lock
  if GetKeyState(VK_NUMLOCK) and 1 <> 0 then
    b2 := b2 or $20;      // Бит 5: Num Lock
  if GetAsyncKeyState(VK_LBUTTON) < 0 then
    b2 := b2 or $40;      // Бит 6: Левая кнопка мыши
  if GetAsyncKeyState(VK_RBUTTON) < 0 then
    b2 := b2 or $80;      // Бит 7: Правая кнопка мыши
  Result := b2;
end;

(*============================================================*)


constructor TdEd.Create(AOwner: TComponent);
begin
  inherited;
  FLines := TStringList.Create;
  FKW := 0;
  FKR := 0;
  FqMacro := false;
  FInsertMode := True;
  FEditorFont := TFont.Create;
  FEditorFont.Name := 'Courier New';
  FEditorFont.Size := 10;
  FEditorFont.Style := [];
  FEditorColor := clWhite;
  FMaxLength := 1000;
  FTopLine := 0;
  FLeftColumn := 0;
  FCaretX := 0;
  FCaretY := 0;
  TabStop := True;

  FCaretVisible := True;
  FCaretTimer := TTimer.Create(Self);
  FCaretTimer.Interval := 500;  // 500 мс
  FCaretTimer.OnTimer := CaretTimerHandler;
  FCaretTimer.Enabled := True;

  FInitialized := False;
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  DoubleBuffered := True;
  Width := 600;
  Height := 400;
end;

destructor TdEd.Destroy;
begin
  FEditorFont.Free;
  FLines.Free;
  inherited;
end;

procedure TdEd.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.Style := Params.Style or WS_TABSTOP;
  Params.Style := Params.Style and (not WS_HSCROLL) and (not WS_VSCROLL);
end;

procedure TdEd.CreateWnd;
begin
  inherited;
  FInitialized := True;
  UpdateMetrics;
end;

procedure TdEd.UpdateMetrics;
begin
  if not FInitialized then Exit;

  Canvas.Font := FEditorFont;
  FCharHeight := Canvas.TextHeight('Wg');  // 'Wg' даёт полную высоту строки
  FCharWidth := Canvas.TextWidth('W');

  // Минимальные значения на всякий случай
  if FCharHeight < 1 then FCharHeight := 16;
  if FCharWidth < 1 then FCharWidth := 8;
end;



function TdEd.GetVisibleLines: Integer;
begin
  if FCharHeight > 0 then
    Result := ClientHeight div FCharHeight
  else
    Result := 1;
end;


procedure TdEd.SetEditorFont(const Value: TFont);
begin
  FEditorFont.Assign(Value);
  if FInitialized then
  begin
    // Принудительно пересчитываем метрики через Canvas
    Canvas.Font := FEditorFont;
    FCharHeight := Canvas.TextHeight('Wg');  // Высота с учётом выносных элементов
    FCharWidth := Canvas.TextWidth('W');     // Ширина символа
    
    // Перерисовываем всё
    Invalidate;
    
    // Принудительно обновляем позицию курсора
    if FCaretY >= FLines.Count then
      FCaretY := FLines.Count - 1;
    if FCaretY < 0 then
      FCaretY := 0;
      
    EnsureCaretVisible;
  end;
end;

procedure TdEd.SetEditorColor(const Value: TColor);
begin
  if FEditorColor <> Value then
  begin
    FEditorColor := Value;
    if FInitialized then
      Invalidate;
  end;
end;

procedure TdEd.SetLines(const Value: TStringList);
begin
  FLines.Assign(Value);
  if FInitialized then
  begin
    if FCaretY >= FLines.Count then
      FCaretY := FLines.Count - 1;
    if FCaretY < 0 then
      FCaretY := 0;
    Invalidate;
  end;
end;

procedure TdEd.SetTopLine(Value: Integer);
var
  VisibleLines: Integer;
begin
  if not FInitialized then Exit;

  VisibleLines := GetVisibleLines;

  if Value < 0 then
    Value := 0;

  if FLines.Count > 0 then
  begin
    if Value > FLines.Count - VisibleLines then
      Value := Max(0, FLines.Count - VisibleLines);
  end;

  if FTopLine <> Value then
  begin
    FTopLine := Value;
    Invalidate;
  end;
end;


procedure TdEd.Paint;
var
  I, Y, X: Integer;
  S: string;
  JS: Integer;
begin
  if not FInitialized then Exit;

  // Очищаем фон
  Canvas.Brush.Color := FEditorColor;
  Canvas.FillRect(ClientRect);

  // Устанавливаем шрифт
  Canvas.Font := FEditorFont;

  // Рисуем видимые строки
  for I := 0 to GetVisibleLines - 1 do
  begin
    JS := FTopLine + I;
    if JS < FLines.Count then
    begin
      S := FLines[JS];
      Y := I * FCharHeight;
      Canvas.TextOut(2 - FLeftColumn * FCharWidth, Y, S);
    end;
  end;

  // Рисуем курсор
  if Focused and FCaretVisible and
     (FCaretY >= FTopLine) and
     (FCaretY < FTopLine + GetVisibleLines) and
     (FCaretY < FLines.Count) then
  begin
    X := 2 + (FCaretX - FLeftColumn) * FCharWidth;
    Y := (FCaretY - FTopLine) * FCharHeight;

    // Вместо вертикальной линии рисуем:
    if FInsertMode then
    begin
      // Вертикальная линия (режим вставки)
      Canvas.Pen.Color := clBlack;
      Canvas.MoveTo(X, Y);
      Canvas.LineTo(X, Y + FCharHeight - 1);
    end
    else
    begin
      // Инвертированный прямоугольник (режим замены)
      Canvas.CopyMode := cmNotSrcCopy;  // <-- Инверсия
      Canvas.CopyRect(Rect(X, Y, X + FCharWidth, Y + FCharHeight - 1),
                     Canvas, Rect(X, Y, X + FCharWidth, Y + FCharHeight - 1));
      Canvas.CopyMode := cmSrcCopy;     // <-- Восстановить режим
    end;
  end;
end;

procedure TdEd.EnsureCaretVisible;
var
  VisibleLines: Integer;
  VisibleColumns: Integer;
begin
  if not FInitialized then Exit;

  VisibleLines := GetVisibleLines;
  VisibleColumns := ClientWidth div FCharWidth;

  // Вертикальная прокрутка
  if FCaretY < FTopLine then
    jsTop := FCaretY
  else if FCaretY >= FTopLine + VisibleLines then
    jsTop := FCaretY - VisibleLines + 1;

  // Горизонтальная прокрутка <-- Добавить этот блок
  if FCaretX < FLeftColumn then
    FLeftColumn := FCaretX
  else if FCaretX >= FLeftColumn + VisibleColumns then
    FLeftColumn := FCaretX - VisibleColumns + 1;
end;

procedure TdEd.KeyDown(var Key: Word; Shift: TShiftState);
var
  sPrefix : string;
  S: string;
  VisibleLines: Integer;
  Ch: char;
  wKey: Word;
  w3Key: Word;
  b2  : byte;
  sDebug: string;

  Msg: TMessage;
begin
  inherited;

  if not FInitialized then Exit;


  sDebug := 'Shift= $'+HexB(Byte(Shift))+' Key=$'+HexW(Key);
  FdEd.Caption := sDebug;


  b2 := KeyDownShift(Shift);


  Ch := KeyToChar(Key, Shift);
  if Ch <> #0 then begin
//  ExecKey(Ch);

//    #8,
//    #13,
//    #32-255

    if FKW <> 0 then begin
      FsCom := FsCom + #6 + #0;
      FKW := 0;
    end;
    FsCom := FsCom + Ch;

    (* "взвести" КОМАНДУ *)
    // Создаём событие для выполнения
    Msg.Msg := WM_EXECUTE_COMMAND;
    Msg.WParam := Ord(Ch);  // Передаём символ команды
    Msg.LParam := 0;
    PostMessage(Handle, WM_EXECUTE_COMMAND, Ord(Ch), 0);

    Key := 0;

    if (b2 or (2+4+8)) = 0 then Exit;
  end;

  wKey := Key + b2*256;
  w3Key := wKey and $CFFF; (* выключить биты Caps и Num *)

  sPrefix := '';
  if (FKW = 0) then begin
    sPrefix := #6 + #1;
  end;

  Ch := #0;
  case w3Key of
   $0008: Ch := '<';
   $000D: Ch := 'E';
   $0021: Ch := 'U';
   $0022: Ch := 'D';
   $0023: Ch := 'e';
   $0024: Ch := 'b';
   $0025: Ch := 'l';
   $0026: Ch := 'u';
   $0027: Ch := 'r';
   $0028: Ch := 'd';
   $002D: Ch := 'ж';
   $002E: Ch := 'x';
  end;

  if (Ch <> #0) then begin
    FsCom := FsCom + sPrefix + Ch;
    FKW := 1;

   (* "взвести" КОМАНДУ *)
    // Создаём событие для выполнения
    Msg.Msg := WM_EXECUTE_COMMAND;
    Msg.WParam := Ord(Ch);  // Передаём символ команды
    Msg.LParam := 0;
    PostMessage(Handle, WM_EXECUTE_COMMAND, Ord(Ch), 0);

    Key := 0;
    Exit;
  end;


{
          sDebug := 'WKey = $'+HexW(wKey);
          FdEd.Caption := sDebug;
}

  case Key of
    VK_UP:
      begin
        if FCaretY > 0 then
        begin
          Dec(FCaretY);
          EnsureCaretVisible;
          Invalidate;
        end;
      end;

    VK_DOWN:
      begin
        if FCaretY < FLines.Count - 1 then
        begin
          Inc(FCaretY);
          EnsureCaretVisible;
          Invalidate;
        end;
      end;

    VK_LEFT:
      begin
        if FCaretX > 0 then
          Dec(FCaretX)
        else if FCaretY > 0 then
        begin
          Dec(FCaretY);
          S := FLines[FCaretY];
          FCaretX := Length(S);
        end;
        EnsureCaretVisible;
        Invalidate;
      end;

    VK_RIGHT:
      begin
        if FCaretY < FLines.Count then
        begin
            Inc(FCaretX);
        end;
        EnsureCaretVisible;
        Invalidate;
      end;

    VK_HOME:
      begin
        if ssCtrl in Shift then
          jsTop := 0
        else
          FCaretX := 0;
        EnsureCaretVisible;
        Invalidate;
      end;

    VK_END:
      begin
        if ssCtrl in Shift then
        begin
          VisibleLines := GetVisibleLines;
          jsTop := Max(0, FLines.Count - VisibleLines);
          FCaretY := FLines.Count - 1;
        end;
        if FCaretY < FLines.Count then
        begin
          S := FLines[FCaretY];
          FCaretX := Length(S);
        end;
        EnsureCaretVisible;
        Invalidate;
      end;

    VK_PRIOR: // Page Up
      begin
        VisibleLines := GetVisibleLines;
        FCaretY := Max(0, FCaretY - VisibleLines);
        jsTop := Max(0, jsTop - VisibleLines);
        EnsureCaretVisible;
        Invalidate;
      end;

    VK_NEXT: // Page Down
      begin
        VisibleLines := GetVisibleLines;
        FCaretY := Min(FLines.Count - 1, FCaretY + VisibleLines);
        jsTop := Min(Max(0, FLines.Count - VisibleLines), jsTop + VisibleLines);
        EnsureCaretVisible;
        Invalidate;
      end;

    VK_INSERT:  // Off/On Insert
      begin
        InsertMode := not InsertMode;
      end;


    else (*case*)
      begin
          sDebug := 'WKey = $'+HexW(wKey);
          FdEd.Caption := sDebug;
      end;


  end; (* case *)
  CaretReCharge;

end;



procedure TdEd.WMExecuteCommand(var Message: TMessage);
var
  Ch,Ch2: Char;
  qTextMode: Boolean;  // Режим ввода текста (true) или команд (false)
begin
//Ch := Char(Message.WParam);

  repeat

  Ch := FsCom[FiExe];
  inc(FiExe);

//qTextMode := (Message.LParam = 1);

  if (Ch = #6) then begin
    Ch2 := FsCom[FiExe]; // не может отсутствовать, т.к. #6
                         // всегда кладётся парой с '0' или '1'
    inc(FiExe);
    if Ch2 = '0'
      then FKR := 0
      else FKR := 1;
//  FKR := Ch2;
  end;

  if FKR = 0 then
  begin
    // Ввод текста - вставляем символ в текущую позицию
    ExecKey(Ch);
  end
  else
  begin
    // Выполнение команды
    ExecCom(Ch);
  end;

  CaretReCharge;


  // Обновляем индекс последней выполненной команды
//FLastExecIdx := Length(FCmdStr);


  until (FiExe >= FiCom);
  // Если есть отложенные команды, запускаем таймер для продолжения
//  if FiExe < FiCom then
//    StartMacroTimer;  // Таймер для выполнения следующих команд
end;





procedure TdEd.ExecCom(Key: Char);
  procedure UpDate; begin
             EnsureCaretVisible;
             Invalidate;
  end;
  procedure Up; begin
    FiCom := Length(FsCom);
  end;

begin
  // Здесь обрабатываем символы команд
  case Key of
    'u': begin // Курсор вверх
           if FCaretY > 0 then begin
             Dec(FCaretY);
             UpDate;
           end;
           Up;
         end;

    'd': begin // Курсор вниз
           if FCaretY < FLines.Count - 1 then
           begin
             Inc(FCaretY);
             UpDate;
           end;
           Up;
         end;

    'l': begin // Курсор влево
           if FCaretX > 0 then
             Dec(FCaretX)
           else if FCaretY > 0 then
           begin
             Dec(FCaretY);
             FCaretX := Length(FLines[FCaretY]);
           end;
           UpDate;
           Up;
         end;

    'r': begin // Курсор вправо
           Inc(FCaretX);
           EnsureCaretVisible;
           UpDate;
           Up;
         end;

    'U': begin // PageUp
           FCaretY := Max(0, FCaretY - GetVisibleLines);
           jsTop := Max(0, jsTop - GetVisibleLines);
           UpDate;
           Up;
         end;

    'D': begin // PageDown
           FCaretY := Min(FLines.Count - 1, FCaretY + GetVisibleLines);
           jsTop := Min(Max(0, FLines.Count - GetVisibleLines),
                       jsTop + GetVisibleLines);
           UpDate;
           Up;
         end;

    'b': begin // В начало строки
           FCaretX := 0;
           UpDate;
           Up;
         end;

    'e': begin // В конец строки
           if FCaretY < FLines.Count then
             FCaretX := Length(FLines[FCaretY]);
           UpDate;
           Up;
         end;

    'B': begin // В начало текста (Ctrl-Home)
           FCaretY := 0;
           FCaretX := 0;
           jsTop := 0;
           UpDate;
           Up;
         end;

    'K': begin // В конец текста (Ctrl-End)
           FCaretY := FLines.Count - 1;
           if FCaretY >= 0 then
             FCaretX := Length(FLines[FCaretY]);
           jsTop := Max(0, FLines.Count - GetVisibleLines);
           UpDate;
           Up;
         end;

    'm': begin // Начало/конец записи макроса
           if not FqMacro then
  //           StartRecord
           else
  //           StopRecord;
           Up;
         end;

    'M': begin // Выполнить макрос (следующий символ - имя)
           // Будет обработано в KeyPress после 'M'
         end;

    'з': InsertMode := True;      // Включить вставку
    'З': InsertMode := False;     // Выключить вставку
    'ж': InsertMode := not InsertMode;  // Сменить режим
  end;
end; (* ExecCom *)











procedure TdEd.ExecKey(Key: Char);
var
  S: String;
begin
  if Key = #13 then // Enter
  begin
    if FLines.Count = 0 then
      FLines.Add('');

    FLines.Insert(FCaretY + 1, '');
    Inc(FCaretY);
    FCaretX := 0;
    EnsureCaretVisible;
    Invalidate;
  end
  else if Key = #8 then // Backspace
  begin
    if FCaretY < FLines.Count then
    begin
      if FCaretX > 0 then
      begin
        S := FLines[FCaretY];
        Delete(S, FCaretX, 1);
        Dec(FCaretX);
        FLines[FCaretY] := S;
      end
      else if FCaretY > 0 then
      begin
        S := FLines[FCaretY - 1] + FLines[FCaretY];
        FLines[FCaretY - 1] := S;
        FLines.Delete(FCaretY);
        Dec(FCaretY);
        if FCaretY < FLines.Count then
          FCaretX := Length(FLines[FCaretY]);
      end;
      Invalidate;
    end;
  end
  else if (Key >= #32) and (Key <= #255) then // Печатный символ
  begin

    if FLines.Count = 0 then
      FLines.Add('');

    if FCaretY >= FLines.Count then
      FCaretY := FLines.Count - 1;

    S := FLines[FCaretY];

    if FCaretX > Length(S) then
    begin
      S := S + StringOfChar(' ', FCaretX - Length(S));
      FLines[FCaretY] := S;
    end;

    if Length(S) < FMaxLength then
    begin
      if FInsertMode then
        Insert(Key, S, FCaretX + 1)  // Вставка
      else if FCaretX < Length(S) then
        S[FCaretX + 1] := Key        // Замена
      else
        Insert(Key, S, FCaretX + 1); // В конец строки - вставка

      Inc(FCaretX);
      FLines[FCaretY] := S;
      Invalidate;
    end;

  end;
end;

procedure TdEd.KeyPress(var Key: Char);
begin
  Exit;
  inherited;
  if not FInitialized then Exit;
//ExecKey(Key);
end;

procedure TdEd.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  if not FInitialized then Exit;

  SetFocus;

  if Button = mbLeft then
  begin

    FCaretY := (Y div FCharHeight) + FTopLine;
    if FCaretY >= FLines.Count then
      FCaretY := FLines.Count - 1;
    if FCaretY < 0 then
      FCaretY := 0;

    FCaretX := ((X - 2) div FCharWidth) + FLeftColumn;
    if FCaretX < 0 then
      FCaretX := 0;

    EnsureCaretVisible;
    Invalidate;
  end
  else
  if Button = mbRight then
  begin
    // Для правой кнопки - показываем контекстное меню
    if Assigned(PopupMenu) then
    begin
      PopupMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
    end;
  end;


  CaretReCharge;
end;

procedure TdEd.WMMouseWheel(var Message: TWMMouseWheel);
var
  kDelta: Integer; // Направление прокрутки
  ns:     Integer; // Количество строк для прокрутки
begin
  kDelta := Message.WheelDelta;
  ns := 3;

  if ssShift in KeysToShiftState(Message.Keys) then
  begin
    // Горизонтальная прокрутка
    if kDelta > 0 then begin
      FLeftColumn := FLeftColumn - ns;
      FCaretX := FCaretX - ns;
    end
    else begin
      FLeftColumn := FLeftColumn + ns;
      FCaretX := FCaretX + ns;
    end;

    if FLeftColumn < 0 then
      FLeftColumn := 0;

    if FCaretX < 0 then
      FCaretX := 0;

    Invalidate;
    Message.Result := 1;
  end
  else
  begin
    // Вертикальная прокрутка
    if kDelta > 0 then
      jsTop := jsTop - ns
    else
      jsTop := jsTop + ns;
    Message.Result := 1;
  end;
end;

procedure TdEd.WMSize(var Message: TWMSize);
begin
  inherited;
  if FInitialized then
  begin
    UpdateMetrics;
    EnsureCaretVisible;
    Invalidate;
  end;
end;

procedure TdEd.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS;
end;

procedure TdEd.LoadFromFile(const FileName: string);
begin
  FLines.LoadFromFile(FileName);
  FTopLine := 0;
  FCaretY := 0;
  FCaretX := 0;
  Invalidate;
end;

procedure TdEd.SaveToFile(const FileName: string);
begin
  FLines.SaveToFile(FileName);
end;

procedure TdEd.SetInsertMode(Value: Boolean);
begin
  if FInsertMode <> Value then
  begin
    FInsertMode := Value;
    if Assigned(FOnInsertModeChange) then
      FOnInsertModeChange(Self);
    CaretReCharge;
    Invalidate;
  end;
end;

procedure TdEd.CaretTimerHandler(Sender: TObject);
begin
  FCaretVisible := not FCaretVisible;
  Invalidate;
end;

procedure TdEd.CaretReCharge;
begin
  FCaretVisible := True;
  FCaretTimer.Enabled := False;
  FCaretTimer.Enabled := True;
end;

end.
