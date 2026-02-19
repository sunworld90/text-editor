program dEd;

uses
  Forms,
  UFdEd in 'UFdEd.pas' {FdEd},
  UdEd in 'UdEd.pas',
  swEd in '..\..\..\MB\LID\swEd.pas',
  UStr in 'UStr.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFdEd, FdEd);
  Application.Run;
end.
