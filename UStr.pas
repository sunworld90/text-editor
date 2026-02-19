unit UStr;

interface

type
  THexChars = array [0..$F] of char; // таблица 16-ричных цифр

const
  hexChars: THexChars = '0123456789ABCDEF';  (* 16-ричные числа *)

function HexB(B:byte):string;
function HexW(W:word):string;

implementation

function HexB(B:byte):string;
begin HexB:=hexChars[B shr 4]+hexChars[B and $F]; end;

function HexW(W:word):string;
begin HexW:=HexB(Hi(W))+HexB(Lo(W)) end;


end.
