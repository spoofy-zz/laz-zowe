unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Menus, ComCtrls, ExtCtrls, ClipBrd, LCLType, ImgList,
  uZoweOps, uJobsForm;

type
  TMainForm = class(TForm)
  private
    { Core widgets }
    FMemo:      TMemo;
    FStatusBar: TStatusBar;

    { Dialogs }
    FOpenDlg: TOpenDialog;
    FSaveDlg: TSaveDialog;

    { State }
    FCurrentFile:    string;
    FCurrentDataset: string;
    FLastJobID:      string;
    FModified:       Boolean;

    { ---- Toolbar ---- }
    procedure BuildToolbar;

    { ---- Menu building ---- }
    procedure BuildMenu;

    { ---- UI helpers ---- }
    procedure SetModified(AValue: Boolean);
    procedure UpdateTitle;
    procedure SetBusy(const Msg: string);
    procedure SetReady;

    { ---- File operations ---- }
    procedure DoNew;
    procedure DoOpen(const AFileName: string);
    function  DoSave: Boolean;
    function  DoSaveAs: Boolean;
    function  ConfirmSave: Boolean;

    { ---- Zowe helpers ---- }
    function TempFile(const Ext: string): string;

    { ---- Menu handlers – File ---- }
    procedure MnuFileNew    (Sender: TObject);
    procedure MnuFileOpen   (Sender: TObject);
    procedure MnuFileSave   (Sender: TObject);
    procedure MnuFileSaveAs (Sender: TObject);
    procedure MnuFileExit   (Sender: TObject);

    { ---- Menu handlers – Edit ---- }
    procedure MnuEditCut       (Sender: TObject);
    procedure MnuEditCopy      (Sender: TObject);
    procedure MnuEditPaste     (Sender: TObject);
    procedure MnuEditSelectAll (Sender: TObject);

    { ---- Menu handlers – Zowe ---- }
    procedure MnuZoweDownload  (Sender: TObject);
    procedure MnuZoweUpload    (Sender: TObject);
    procedure MnuZoweSubmit    (Sender: TObject);
    procedure MnuZoweViewSpool (Sender: TObject);
    procedure MnuZoweCheck     (Sender: TObject);

    { ---- Menu handlers – Help ---- }
    procedure MnuHelpAbout (Sender: TObject);

    { ---- Memo / Form events ---- }
    procedure MemoChange     (Sender: TObject);
    procedure FormCloseQuery (Sender: TObject; var CanClose: Boolean);

  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

const
  APP_TITLE = 'Zowe MVS Editor';
  UNTITLED  = 'Untitled';

{ ================================================================== }
constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Caption      := APP_TITLE + ' – ' + UNTITLED;
  Width        := 1000;
  Height       := 700;
  Position     := poScreenCenter;
  OnCloseQuery := @FormCloseQuery;

  { ---- Menu (always at top, OS-managed) ---- }
  BuildMenu;

  { ---- Status bar – alBottom must be created before alTop/alClient ---- }
  FStatusBar             := TStatusBar.Create(Self);
  FStatusBar.Parent      := Self;
  FStatusBar.SimplePanel := False;
  with FStatusBar.Panels do
  begin
    with Add do begin Width := 200; Text := 'Ready'; end;
    with Add do begin Width := 280; Text := 'File: ' + UNTITLED; end;
    with Add do begin Width := 320; Text := 'Dataset: (none)'; end;
  end;

  { ---- Toolbar – alTop, sits just below the menu bar ---- }
  BuildToolbar;

  { ---- Memo – alClient, fills the remaining space ---- }
  FMemo             := TMemo.Create(Self);
  FMemo.Parent      := Self;
  FMemo.Align       := alClient;
  FMemo.ScrollBars  := ssBoth;
  FMemo.WordWrap    := False;
  FMemo.Font.Name   := 'Monospace';
  FMemo.Font.Size   := 11;
  FMemo.OnChange    := @MemoChange;

  { ---- File dialogs ---- }
  FOpenDlg        := TOpenDialog.Create(Self);
  FOpenDlg.Title  := 'Open file';
  FOpenDlg.Filter :=
    'All files (*.*)|*.*|Text files (*.txt)|*.txt|' +
    'JCL files (*.jcl)|*.jcl|COBOL (*.cbl;*.cob)|*.cbl;*.cob';

  FSaveDlg         := TSaveDialog.Create(Self);
  FSaveDlg.Title   := 'Save file';
  FSaveDlg.Filter  := FOpenDlg.Filter;
  FSaveDlg.Options := [ofOverwritePrompt];

  { ---- Initial state ---- }
  FCurrentFile    := '';
  FCurrentDataset := '';
  FLastJobID      := '';
  FModified       := False;
end;

{ ================================================================== }
{ Menu construction                                                    }
{ ================================================================== }
procedure TMainForm.BuildMenu;

  function NewItem(ACaption: string; AHandler: TNotifyEvent;
                   AShortKey: Word = 0;
                   AShift: TShiftState = []): TMenuItem;
  begin
    Result         := TMenuItem.Create(Self);
    Result.Caption := ACaption;
    Result.OnClick := AHandler;
    if AShortKey <> 0 then
      Result.ShortCut := ShortCut(AShortKey, AShift);
  end;

  function Sep: TMenuItem;
  begin
    Result         := TMenuItem.Create(Self);
    Result.Caption := '-';
  end;

var
  MM:                     TMainMenu;
  MFile, MEdit, MZowe, MHelp: TMenuItem;
begin
  MM := TMainMenu.Create(Self);

  { ---- File ---- }
  MFile         := TMenuItem.Create(Self);
  MFile.Caption := '&File';
  MFile.Add(NewItem('&New',        @MnuFileNew,    Ord('N'), [ssCtrl]));
  MFile.Add(NewItem('&Open...',    @MnuFileOpen,   Ord('O'), [ssCtrl]));
  MFile.Add(NewItem('&Save',       @MnuFileSave,   Ord('S'), [ssCtrl]));
  MFile.Add(NewItem('Save &As...', @MnuFileSaveAs, Ord('S'), [ssCtrl, ssShift]));
  MFile.Add(Sep);
  MFile.Add(NewItem('E&xit',       @MnuFileExit,   VK_F4,   [ssAlt]));
  MM.Items.Add(MFile);

  { ---- Edit ---- }
  MEdit         := TMenuItem.Create(Self);
  MEdit.Caption := '&Edit';
  MEdit.Add(NewItem('Cu&t',        @MnuEditCut,       Ord('X'), [ssCtrl]));
  MEdit.Add(NewItem('&Copy',       @MnuEditCopy,      Ord('C'), [ssCtrl]));
  MEdit.Add(NewItem('&Paste',      @MnuEditPaste,     Ord('V'), [ssCtrl]));
  MEdit.Add(Sep);
  MEdit.Add(NewItem('Select &All', @MnuEditSelectAll, Ord('A'), [ssCtrl]));
  MM.Items.Add(MEdit);

  { ---- Zowe ---- }
  MZowe         := TMenuItem.Create(Self);
  MZowe.Caption := '&Zowe';
  MZowe.Add(NewItem('&Download Dataset from MVS...', @MnuZoweDownload));
  MZowe.Add(NewItem('&Upload Dataset to MVS...',     @MnuZoweUpload));
  MZowe.Add(Sep);
  MZowe.Add(NewItem('&Submit JCL Job',               @MnuZoweSubmit,    VK_F5, []));
  MZowe.Add(NewItem('&View Jobs && Spool...',        @MnuZoweViewSpool, VK_F6, []));
  MZowe.Add(Sep);
  MZowe.Add(NewItem('Check Zowe &Connection',        @MnuZoweCheck));
  MM.Items.Add(MZowe);

  { ---- Help ---- }
  MHelp         := TMenuItem.Create(Self);
  MHelp.Caption := '&Help';
  MHelp.Add(NewItem('&About', @MnuHelpAbout));
  MM.Items.Add(MHelp);

  Menu := MM;
end;

{ ================================================================== }
{ UI helpers                                                           }
{ ================================================================== }
procedure TMainForm.SetModified(AValue: Boolean);
begin
  FModified := AValue;
  UpdateTitle;
end;

procedure TMainForm.UpdateTitle;
var
  N: string;
begin
  if FCurrentFile <> '' then
    N := ExtractFileName(FCurrentFile)
  else if FCurrentDataset <> '' then
    N := FCurrentDataset
  else
    N := UNTITLED;

  if FModified then
    Caption := APP_TITLE + ' – ' + N + ' *'
  else
    Caption := APP_TITLE + ' – ' + N;
end;

procedure TMainForm.SetBusy(const Msg: string);
begin
  FStatusBar.Panels[0].Text := Msg;
  Self.Enabled := False;
  Application.ProcessMessages;
end;

procedure TMainForm.SetReady;
begin
  Self.Enabled := True;
  FStatusBar.Panels[0].Text := 'Ready';
end;

{ ================================================================== }
{ File operations                                                      }
{ ================================================================== }
procedure TMainForm.DoNew;
begin
  if not ConfirmSave then Exit;
  FMemo.Clear;
  FCurrentFile    := '';
  FCurrentDataset := '';
  FLastJobID      := '';
  SetModified(False);
  FStatusBar.Panels[1].Text := 'File: ' + UNTITLED;
  FStatusBar.Panels[2].Text := 'Dataset: (none)';
  UpdateTitle;
end;

procedure TMainForm.DoOpen(const AFileName: string);
begin
  if not ConfirmSave then Exit;
  try
    FMemo.Lines.LoadFromFile(AFileName);
    FCurrentFile := AFileName;
    SetModified(False);
    FStatusBar.Panels[1].Text := 'File: ' + ExtractFileName(AFileName);
    FStatusBar.Panels[0].Text := 'Loaded: ' + AFileName;
    UpdateTitle;
  except
    on E: Exception do
      ShowMessage('Failed to open file:'#10 + E.Message);
  end;
end;

function TMainForm.DoSave: Boolean;
begin
  Result := False;
  if FCurrentFile = '' then
  begin
    Result := DoSaveAs;
    Exit;
  end;
  try
    FMemo.Lines.SaveToFile(FCurrentFile);
    SetModified(False);
    FStatusBar.Panels[0].Text := 'Saved: ' + FCurrentFile;
    Result := True;
  except
    on E: Exception do
      ShowMessage('Failed to save:'#10 + E.Message);
  end;
end;

function TMainForm.DoSaveAs: Boolean;
begin
  Result := False;
  FSaveDlg.FileName := ExtractFileName(FCurrentFile);
  if not FSaveDlg.Execute then Exit;
  FCurrentFile := FSaveDlg.FileName;
  FStatusBar.Panels[1].Text := 'File: ' + ExtractFileName(FCurrentFile);
  Result := DoSave;
end;

function TMainForm.ConfirmSave: Boolean;
var
  Ans: Integer;
begin
  Result := True;
  if not FModified then Exit;
  Ans := MessageDlg('Unsaved changes',
    'The current content has unsaved changes.'#10 +
    'Do you want to save before continuing?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  case Ans of
    mrYes:    Result := DoSave;
    mrNo:     Result := True;
    mrCancel: Result := False;
  end;
end;

{ ================================================================== }
{ Zowe helpers                                                         }
{ ================================================================== }
function TMainForm.TempFile(const Ext: string): string;
begin
  Result := GetTempDir + 'zowe_ed_' +
            FormatDateTime('hhnnsszzz', Now) + '.' + Ext;
end;

{ ================================================================== }
{ Menu handlers – File                                                 }
{ ================================================================== }
procedure TMainForm.MnuFileNew    (Sender: TObject); begin DoNew;    end;
procedure TMainForm.MnuFileSave   (Sender: TObject); begin DoSave;   end;
procedure TMainForm.MnuFileSaveAs (Sender: TObject); begin DoSaveAs; end;
procedure TMainForm.MnuFileExit   (Sender: TObject); begin Close;    end;

procedure TMainForm.MnuFileOpen(Sender: TObject);
begin
  FOpenDlg.FileName := '';
  if FOpenDlg.Execute then
    DoOpen(FOpenDlg.FileName);
end;

{ ================================================================== }
{ Menu handlers – Edit                                                 }
{ ================================================================== }
procedure TMainForm.MnuEditCut       (Sender: TObject); begin FMemo.CutToClipboard;    end;
procedure TMainForm.MnuEditCopy      (Sender: TObject); begin FMemo.CopyToClipboard;   end;
procedure TMainForm.MnuEditPaste     (Sender: TObject); begin FMemo.PasteFromClipboard; end;
procedure TMainForm.MnuEditSelectAll (Sender: TObject); begin FMemo.SelectAll;          end;

{ ================================================================== }
{ Menu handlers – Zowe                                                 }
{ ================================================================== }

procedure TMainForm.MnuZoweDownload(Sender: TObject);
var
  Dataset: string;
  TF:      string;
  R:       TZoweResult;
begin
  Dataset := InputBox('Download from MVS',
    'Enter dataset name (e.g. HLQ.MYJCL  or  HLQ.PDS(MEMBER)):',
    FCurrentDataset);
  if Trim(Dataset) = '' then Exit;
  if not ConfirmSave then Exit;

  TF := TempFile('txt');
  SetBusy('Downloading ' + Dataset + ' from MVS...');
  try
    R := ZoweDownloadDataset(Dataset, TF);
  finally
    SetReady;
  end;

  if not R.Success then
  begin
    ShowMessage('Download failed:'#10 + R.ErrorMsg);
    Exit;
  end;

  try
    FMemo.Lines.LoadFromFile(TF);
  except
    on E: Exception do
    begin
      ShowMessage('Downloaded but could not load local file:'#10 + E.Message);
      Exit;
    end;
  end;
  try SysUtils.DeleteFile(TF); except end;

  FCurrentDataset := UpperCase(Trim(Dataset));
  FCurrentFile    := '';
  SetModified(False);
  FStatusBar.Panels[1].Text := 'File: (MVS dataset)';
  FStatusBar.Panels[2].Text := 'Dataset: ' + FCurrentDataset;
  FStatusBar.Panels[0].Text := 'Downloaded: ' + FCurrentDataset;
  UpdateTitle;
end;

procedure TMainForm.MnuZoweUpload(Sender: TObject);
var
  Dataset: string;
  TF:      string;
  R:       TZoweResult;
begin
  Dataset := InputBox('Upload to MVS',
    'Enter target dataset name (e.g. HLQ.MYJCL):',
    FCurrentDataset);
  if Trim(Dataset) = '' then Exit;

  TF := TempFile('txt');
  try
    FMemo.Lines.SaveToFile(TF);
  except
    on E: Exception do
    begin
      ShowMessage('Could not write temp file:'#10 + E.Message);
      Exit;
    end;
  end;

  SetBusy('Uploading to ' + Dataset + ' on MVS...');
  try
    R := ZoweUploadDataset(TF, Dataset);
  finally
    SetReady;
  end;
  try SysUtils.DeleteFile(TF); except end;

  if not R.Success then
  begin
    ShowMessage('Upload failed:'#10 + R.ErrorMsg);
    Exit;
  end;

  FCurrentDataset := UpperCase(Trim(Dataset));
  FStatusBar.Panels[2].Text := 'Dataset: ' + FCurrentDataset;
  FStatusBar.Panels[0].Text := 'Uploaded to ' + FCurrentDataset;
  ShowMessage('Dataset uploaded successfully to ' + FCurrentDataset);
end;

procedure TMainForm.MnuZoweSubmit(Sender: TObject);
var
  TF:    string;
  R:     TZoweResult;
  JobID: string;
  Ans:   Integer;
begin
  Ans := MessageDlg('Submit JCL',
    'Submit the current editor content as a JCL job on MVS?',
    mtConfirmation, [mbYes, mbNo], 0);
  if Ans <> mrYes then Exit;

  TF := TempFile('jcl');
  try
    FMemo.Lines.SaveToFile(TF);
  except
    on E: Exception do
    begin
      ShowMessage('Could not write temp file:'#10 + E.Message);
      Exit;
    end;
  end;

  SetBusy('Submitting JCL to MVS...');
  try
    R := ZoweSubmitLocalFile(TF);
  finally
    SetReady;
  end;
  try SysUtils.DeleteFile(TF); except end;

  if not R.Success then
  begin
    ShowMessage('Job submission failed:'#10 + R.ErrorMsg);
    Exit;
  end;

  JobID      := ExtractJobID(R.Output);
  FLastJobID := JobID;

  if JobID <> '' then
  begin
    FStatusBar.Panels[0].Text := 'Job submitted: ' + JobID;
    ShowMessage('Job submitted successfully!'#10 +
                'Job ID: ' + JobID + #10#10 +
                'Use Zowe > View Jobs & Spool (F6) to check the output.');
  end
  else
    ShowMessage('Job submitted.'#10 + R.Output);
end;

procedure TMainForm.MnuZoweViewSpool(Sender: TObject);
var
  F: TJobsForm;
begin
  F := TJobsForm.Create(Self);
  try
    F.RefreshJobs(nil);
    if FLastJobID <> '' then
      F.HighlightJob(FLastJobID);
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TMainForm.MnuZoweCheck(Sender: TObject);
var
  R: TZoweResult;
begin
  SetBusy('Checking Zowe connection...');
  try
    R := ZoweRunCommand(['zosmf', 'check', 'status']);
  finally
    SetReady;
  end;

  if R.Success then
    ShowMessage('Zowe connection OK.'#10 + R.Output)
  else
    ShowMessage('Zowe connection issue:'#10 + R.ErrorMsg);
end;

{ ================================================================== }
{ Menu handlers – Help                                                 }
{ ================================================================== }
procedure TMainForm.MnuHelpAbout(Sender: TObject);
begin
  ShowMessage(
    APP_TITLE + #10#10 +
    'A lightweight text editor with IBM z/OS (MVS) integration'#10 +
    'via the Zowe CLI.'#10#10 +
    'Keyboard shortcuts:'#10 +
    '  Ctrl+N  –  New file'#10 +
    '  Ctrl+O  –  Open file'#10 +
    '  Ctrl+S  –  Save'#10 +
    '  Ctrl+Shift+S  –  Save As'#10 +
    '  F5  –  Submit JCL job'#10 +
    '  F6  –  View Jobs & Spool'#10#10 +
    'Zowe menu:'#10 +
    '  Download Dataset from MVS'#10 +
    '  Upload Dataset to MVS'#10 +
    '  Submit JCL Job'#10 +
    '  View Jobs & Spool output'#10#10 +
    'Built with Lazarus / Free Pascal'
  );
end;

{ ================================================================== }
{ Memo / Form events                                                   }
{ ================================================================== }
procedure TMainForm.MemoChange(Sender: TObject);
begin
  if not FModified then
    SetModified(True);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ConfirmSave;
end;

{ ================================================================== }
{ Toolbar with canvas-drawn icons                                      }
{ ================================================================== }
procedure TMainForm.BuildToolbar;
const
  SZ = 24; { icon pixel size }
  { Background colours (Pascal TColor = BGR) }
  C_NEW   = $BB7755;  { warm orange-brown  }
  C_OPEN  = $2266AA;  { medium blue        }
  C_SAVE  = $AA3322;  { dark orange-red    }
  C_SAVAS = $AA6600;  { amber              }
  C_DOWN  = $225577;  { dark navy          }
  C_UP    = $553366;  { dark violet        }
  C_SUBM  = $227733;  { dark green         }
  C_SPOOL = $553388;  { purple             }
  C_CHECK = $556677;  { steel blue         }
var
  IL:    TImageList;
  TB:    TToolBar;
  Bmp:   TBitmap;
  BgClr: TColor;

  { ---- icon helpers ---- }
  procedure StartIcon(C: TColor);
  begin
    BgClr := C;
    Bmp   := TBitmap.Create;
    Bmp.PixelFormat := pf24bit;
    Bmp.Width  := SZ;
    Bmp.Height := SZ;
    with Bmp.Canvas do
    begin
      Brush.Color := C;
      Pen.Color   := C;
      FillRect(0, 0, SZ, SZ);
      Pen.Color   := clWhite;
      Brush.Color := clWhite;
      Pen.Width   := 1;
    end;
  end;

  function DoneIcon: Integer;
  begin
    Result := IL.Add(Bmp, nil);
    FreeAndNil(Bmp);
  end;

  procedure WPoly(const P: array of TPoint);
  begin
    with Bmp.Canvas do begin Pen.Color := clWhite; Brush.Color := clWhite; Polygon(P); end;
  end;

  procedure WFill(X1, Y1, X2, Y2: Integer);
  begin
    with Bmp.Canvas do begin Pen.Color := clWhite; Brush.Color := clWhite; FillRect(X1,Y1,X2,Y2); end;
  end;

  procedure BgFill(X1, Y1, X2, Y2: Integer);
  begin
    with Bmp.Canvas do
    begin
      Pen.Color := BgClr; Brush.Color := BgClr; FillRect(X1,Y1,X2,Y2);
      Pen.Color := clWhite; Brush.Color := clWhite;
    end;
  end;

  procedure BgPoly(const P: array of TPoint);
  begin
    with Bmp.Canvas do
    begin
      Pen.Color := BgClr; Brush.Color := BgClr; Polygon(P);
      Pen.Color := clWhite; Brush.Color := clWhite;
    end;
  end;

  procedure WLine(X1, Y1, X2, Y2, W: Integer);
  begin
    with Bmp.Canvas do
    begin Pen.Color := clWhite; Pen.Width := W; MoveTo(X1,Y1); LineTo(X2,Y2); Pen.Width := 1; end;
  end;

  { ---- toolbar helpers ---- }
  procedure AddButton(Idx: Integer; const Hint: string; Handler: TNotifyEvent);
  var B: TToolButton;
  begin
    B            := TToolButton.Create(TB);
    B.Parent     := TB;
    B.Style      := tbsButton;
    B.ImageIndex := Idx;
    B.Hint       := Hint;
    B.ShowHint   := True;
    B.OnClick    := Handler;
  end;

  procedure AddSep;
  var B: TToolButton;
  begin
    B        := TToolButton.Create(TB);
    B.Parent := TB;
    B.Style  := tbsDivider;
  end;

var
  iNew, iOpen, iSave, iSaveAs,
  iDown, iUp, iSubm, iSpool, iCheck: Integer;
begin
  IL := TImageList.Create(Self);
  IL.Width  := SZ;
  IL.Height := SZ;
  Bmp := nil;

  { ─── New file: white page with dog-eared corner ─── }
  StartIcon(C_NEW);
  WPoly([Point(4,2),Point(16,2),Point(16,6),Point(20,6),Point(20,22),Point(4,22)]);
  with Bmp.Canvas do
  begin
    Pen.Color := $CCBBAA; Brush.Color := $CCBBAA;
    Polygon([Point(16,2),Point(20,6),Point(16,6)]);
  end;
  iNew := DoneIcon;

  { ─── Open file: folder ─── }
  StartIcon(C_OPEN);
  WPoly([Point(2,10),Point(2,8),Point(8,8),Point(10,10)]);      { tab    }
  WPoly([Point(2,10),Point(22,10),Point(22,21),Point(2,21)]);   { body   }
  with Bmp.Canvas do
  begin
    Pen.Color := $4488CC; Brush.Color := $4488CC; FillRect(3,13,21,20); { interior }
    Pen.Color := clWhite; Brush.Color := clWhite;
  end;
  iOpen := DoneIcon;

  { ─── Save: floppy disk ─── }
  StartIcon(C_SAVE);
  WPoly([Point(2,2),Point(22,2),Point(22,22),Point(2,22)]);  { body         }
  BgFill(4,13,20,21);                                         { label window }
  BgFill(7, 2,17, 9);                                         { shutter slot }
  with Bmp.Canvas do begin Pen.Color := clWhite; Brush.Color := clWhite; Ellipse(10,3,14,8); end;
  iSave := DoneIcon;

  { ─── Save As: floppy + "+" notch ─── }
  StartIcon(C_SAVAS);
  WPoly([Point(2,2),Point(22,2),Point(22,22),Point(2,22)]);  { body         }
  BgFill(4,13,20,21);                                         { label window }
  BgFill(7, 2,17, 9);                                         { shutter slot }
  with Bmp.Canvas do begin Pen.Color := clWhite; Brush.Color := clWhite; Ellipse(10,3,14,8); end;
  BgFill(15,15,22,17);  { "+" horizontal }
  BgFill(17,13,19,21);  { "+" vertical   }
  iSaveAs := DoneIcon;

  { ─── Download from MVS: down-arrow + server marks ─── }
  StartIcon(C_DOWN);
  WPoly([Point(10,3),Point(14,3),Point(14,13),Point(17,13),
         Point(12,21),Point(7,13),Point(10,13)]);
  WLine(3,5,8,5,2);
  WLine(3,8,8,8,2);
  iDown := DoneIcon;

  { ─── Upload to MVS: up-arrow + server marks ─── }
  StartIcon(C_UP);
  WPoly([Point(12,3),Point(17,11),Point(14,11),Point(14,21),
         Point(10,21),Point(10,11),Point(7,11)]);
  WLine(3,16,8,16,2);
  WLine(3,19,8,19,2);
  iUp := DoneIcon;

  { ─── Submit JCL: play triangle ─── }
  StartIcon(C_SUBM);
  WPoly([Point(5,3),Point(5,21),Point(20,12)]);
  iSubm := DoneIcon;

  { ─── View Spool: document with text lines ─── }
  StartIcon(C_SPOOL);
  WPoly([Point(3,2),Point(16,2),Point(16,6),Point(20,6),Point(20,22),Point(3,22)]);
  BgPoly([Point(16,2),Point(20,6),Point(16,6)]);  { fold corner }
  BgFill(6, 9,18,11);  { text line 1 }
  BgFill(6,13,18,15);  { text line 2 }
  BgFill(6,17,18,19);  { text line 3 }
  iSpool := DoneIcon;

  { ─── Check connection: tick / checkmark ─── }
  StartIcon(C_CHECK);
  WPoly([Point(3,12),Point(8,18),Point(21,5),Point(21,9),Point(8,22),Point(3,16)]);
  iCheck := DoneIcon;

  { ════ Build the toolbar ════ }
  TB              := TToolBar.Create(Self);
  TB.Parent       := Self;
  TB.Align        := alTop;
  TB.Images       := IL;
  TB.ShowHint     := True;
  TB.Flat         := True;
  TB.Height       := SZ + 14;  { container must be set explicitly on GTK2 }
  TB.ButtonWidth  := SZ + 8;
  TB.ButtonHeight := SZ + 6;

  AddButton(iNew,    'New file  (Ctrl+N)',         @MnuFileNew);
  AddButton(iOpen,   'Open file  (Ctrl+O)',         @MnuFileOpen);
  AddButton(iSave,   'Save  (Ctrl+S)',              @MnuFileSave);
  AddButton(iSaveAs, 'Save As  (Ctrl+Shift+S)',     @MnuFileSaveAs);
  AddSep;
  AddButton(iDown,   'Download Dataset from MVS',   @MnuZoweDownload);
  AddButton(iUp,     'Upload Dataset to MVS',        @MnuZoweUpload);
  AddSep;
  AddButton(iSubm,   'Submit JCL Job  (F5)',         @MnuZoweSubmit);
  AddButton(iSpool,  'View Jobs && Spool  (F6)',     @MnuZoweViewSpool);
  AddSep;
  AddButton(iCheck,  'Check Zowe Connection',        @MnuZoweCheck);
end;

end.
