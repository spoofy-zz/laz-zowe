program editor;

{$mode objfpc}{$H+}
{$IFDEF DARWIN}
{$modeswitch objectivec1}  { required for NSApp.methodName() call syntax }
{$ENDIF}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF DARWIN}
  CocoaAll,     { NSApp.activateIgnoringOtherApps – needed when run outside .app }
  {$ENDIF}
  Interfaces,   { LCL widget set }
  Forms,
  uMain,
  uZoweOps,
  uJobsForm;

begin
  Application.Scaled    := True;
  Application.Initialize;
  {$IFDEF DARWIN}
  { When launched as a raw binary from the terminal (not via "open editor.app")
    macOS does not activate the process as a foreground GUI app, so the menu
    bar is hidden and keyboard events stay in the terminal.
    activateIgnoringOtherApps brings the app to the front and fixes both. }
  NSApp.activateIgnoringOtherApps(True);
  {$ENDIF}
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
