program editor;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,   { LCL widget set }
  Forms,
  uMain,
  uZoweOps,
  uJobsForm;

begin
  Application.Scaled    := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
