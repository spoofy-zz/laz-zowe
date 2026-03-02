unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, Graphics, Dialogs,
  Menus, ComCtrls, ExtCtrls, ClipBrd, LCLType, ImgList,
  SynEdit, SynEditTypes,
  uSynHighlighter, uZoweOps, uJobsForm, uConfig, uProfileForm;

type
  TMainForm = class(TForm)
    { ---- Status bar ---- }
    StatusBar1: TStatusBar;

    { ---- Toolbar ---- }
    ToolBar1:   TToolBar;
    BtnNew:     TToolButton;
    BtnOpen:    TToolButton;
    BtnSave:    TToolButton;
    BtnSaveAs:  TToolButton;
    BtnClear:   TToolButton;
    BtnSep1:    TToolButton;
    BtnDown:    TToolButton;
    BtnUp:      TToolButton;
    BtnUpLocal: TToolButton;
    BtnSep2:    TToolButton;
    BtnSubmit:  TToolButton;
    BtnSpool:   TToolButton;
    BtnSep3:    TToolButton;
    BtnCheck:   TToolButton;

    { ---- Ruler ---- }
    RulerBox: TPaintBox;

    { ---- Editor ---- }
    SynEdit1: TSynEdit;

    { ---- Menu ---- }
    MainMenu1:       TMainMenu;
    MFile:           TMenuItem;
    MnuFileNew:      TMenuItem;
    MnuFileOpen:     TMenuItem;
    MnuFileSave:     TMenuItem;
    MnuFileSaveAs:   TMenuItem;
    MnuFileClear:    TMenuItem;
    MnuFileSep1:     TMenuItem;
    MnuFileExit:     TMenuItem;
    MEdit:           TMenuItem;
    MnuEditCut:      TMenuItem;
    MnuEditCopy:     TMenuItem;
    MnuEditPaste:    TMenuItem;
    MnuEditSep1:     TMenuItem;
    MnuEditSelectAll: TMenuItem;
    MnuEditSep3:     TMenuItem;
    MnuEditFind:     TMenuItem;
    MnuEditFindNext: TMenuItem;
    MnuEditReplace:  TMenuItem;
    MnuEditSep2:     TMenuItem;
    MnuEditFont:     TMenuItem;
    MZowe:                TMenuItem;
    MnuZoweDownload:      TMenuItem;
    MnuZoweUpload:        TMenuItem;
    MnuZoweUploadLocal:   TMenuItem;
    MnuZoweSep1:          TMenuItem;
    MnuZoweSubmit:      TMenuItem;
    MnuZoweViewSpool:   TMenuItem;
    MnuZoweSep2:        TMenuItem;
    MnuZoweCheck:       TMenuItem;
    MnuZoweSep3:        TMenuItem;
    MnuZoweProfile:     TMenuItem;
    MHelp:         TMenuItem;
    MnuHelpAbout:  TMenuItem;

    { ---- Image list ---- }
    ImageList1: TImageList;

    { ---- Dialogs ---- }
    OpenDialog1:   TOpenDialog;
    SaveDialog1:   TSaveDialog;
    UploadDialog:  TOpenDialog;
    FontDialog1:   TFontDialog;
    FindDialog1:   TFindDialog;
    ReplaceDialog1: TReplaceDialog;

    { ---- Event handlers (referenced from LFM) ---- }
    procedure FormCreate      (Sender: TObject);
    procedure FormActivate    (Sender: TObject);
    procedure FormCloseQuery  (Sender: TObject; var CanClose: Boolean);
    procedure RulerBoxPaint         (Sender: TObject);
    procedure SynEdit1Change        (Sender: TObject);
    procedure SynEdit1StatusChange  (Sender: TObject; Changes: TSynStatusChanges);

    procedure MnuFileNewClick     (Sender: TObject);
    procedure MnuFileOpenClick    (Sender: TObject);
    procedure MnuFileSaveClick    (Sender: TObject);
    procedure MnuFileSaveAsClick  (Sender: TObject);
    procedure MnuFileClearClick   (Sender: TObject);
    procedure MnuFileExitClick    (Sender: TObject);

    procedure MnuEditCutClick       (Sender: TObject);
    procedure MnuEditCopyClick      (Sender: TObject);
    procedure MnuEditPasteClick     (Sender: TObject);
    procedure MnuEditSelectAllClick (Sender: TObject);
    procedure MnuEditFontClick      (Sender: TObject);
    procedure MnuEditFindClick      (Sender: TObject);
    procedure MnuEditFindNextClick  (Sender: TObject);
    procedure MnuEditReplaceClick   (Sender: TObject);
    procedure FindDialog1Find       (Sender: TObject);
    procedure ReplaceDialog1Find    (Sender: TObject);
    procedure ReplaceDialog1Replace (Sender: TObject);

    procedure MnuZoweDownloadClick      (Sender: TObject);
    procedure MnuZoweUploadClick        (Sender: TObject);
    procedure MnuZoweUploadLocalClick   (Sender: TObject);
    procedure MnuZoweSubmitClick        (Sender: TObject);
    procedure MnuZoweViewSpoolClick (Sender: TObject);
    procedure MnuZoweCheckClick     (Sender: TObject);
    procedure MnuZoweProfileClick   (Sender: TObject);

    procedure MnuHelpAboutClick (Sender: TObject);

  private
    { ---- State ---- }
    FCurrentFile:       string;
    FCurrentDataset:    string;
    FLastJobID:         string;
    FLastUploadDataset: string;   { shared "last used" for both upload actions }
    FModified:          Boolean;

    { ---- Zowe profile ---- }
    FUseDefaultProfile: Boolean;
    FActiveProfileName: string;

    { ---- Highlighters (owned by this form) ---- }
    FJCLHlr:   TSynJCLHighlighter;
    FCOBOLHlr: TSynCOBOLHighlighter;

    { ---- Last find state (for Find Next) ---- }
    FLastFindText: string;
    FLastFindOpts: TSynSearchOptions;

    { ---- Focus restoration timer ---- }
    FRestoreFocusTimer: TTimer;

    { ---- Internal helpers ---- }
    procedure PopulateImageList;
    procedure SetModified(AValue: Boolean);
    procedure UpdateTitle;
    procedure UpdateProfilePanel;
    procedure SetBusy(const Msg: string);
    procedure SetReady;
    procedure DetectAndApplyHighlighter;
    procedure DoRestoreFocus(Sender: TObject);
    procedure TriggerFocusRestore;

    procedure ApplyEditorFont(const AName: string; ASize: Integer);
    procedure UpdateMaxWidth;

    procedure DoNew;
    procedure DoOpen(const AFileName: string);
    function  DoSave: Boolean;
    function  DoSaveAs: Boolean;
    function  ConfirmSave: Boolean;
    function  TempFile(const Ext: string): string;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

const
  APP_TITLE = 'Zowe MVS Editor';
  UNTITLED  = 'Untitled';

{ ==================================================================== }
{ Form creation                                                         }
{ ==================================================================== }
procedure TMainForm.FormCreate(Sender: TObject);
var
  SavedFontName: string;
  SavedFontSize: Integer;
begin
  Caption  := APP_TITLE + ' – ' + UNTITLED;
  Position := poScreenCenter;

  { ---- Highlighters ---- }
  FJCLHlr   := TSynJCLHighlighter.Create(Self);
  FCOBOLHlr := TSynCOBOLHighlighter.Create(Self);

  { ---- Editor font (load saved, fall back to Monospace 11) ---- }
  LoadEditorFont(SavedFontName, SavedFontSize);
  ApplyEditorFont(SavedFontName, SavedFontSize);

  { ---- Toolbar images (canvas-drawn) ---- }
  PopulateImageList;

  { ---- Initial state ---- }
  FCurrentFile       := '';
  FCurrentDataset    := '';
  FLastJobID         := '';
  FLastUploadDataset := '';
  FModified          := False;

  { ---- Load stored Zowe profile ---- }
  FUseDefaultProfile := True;
  FActiveProfileName := '';
  LoadZoweProfile(FUseDefaultProfile, FActiveProfileName);
  if FUseDefaultProfile then
    ActiveZoweProfile := ''
  else
    ActiveZoweProfile := FActiveProfileName;

  StatusBar1.Panels[0].Text := 'Ready';
  StatusBar1.Panels[1].Text := 'File: ' + UNTITLED;
  StatusBar1.Panels[2].Text := 'Syntax: –';
  UpdateProfilePanel;

  { One-shot timer: restores SynEdit focus after any dialog closes.
    Fires 80 ms after being enabled, by which time Cocoa has finished
    resetting firstResponder following a runModal session. }
  FRestoreFocusTimer := TTimer.Create(Self);
  FRestoreFocusTimer.Interval := 80;
  FRestoreFocusTimer.Enabled  := False;
  FRestoreFocusTimer.OnTimer  := @DoRestoreFocus;

  SynEdit1.SetDefaultKeystrokes;   { not called during LFM loading; must be set here }
  ActiveControl := SynEdit1;
  TriggerFocusRestore;   { focus editor on startup }
end;

{ ==================================================================== }
{ Toolbar image list – canvas-drawn mainframe-style icons               }
{ ==================================================================== }
procedure TMainForm.PopulateImageList;
const
  SZ      = 24;
  C_NEW   = $BB7755;
  C_OPEN  = $2266AA;
  C_SAVE  = $AA3322;
  C_SAVAS = $AA6600;
  C_DOWN  = $225577;
  C_UP    = $553366;
  C_SUBM  = $227733;
  C_SPOOL = $553388;
  C_CHECK = $556677;
var
  Bmp:   TBitmap;
  BgClr: TColor;

  procedure StartIcon(C: TColor);
  begin
    BgClr := C;
    Bmp   := TBitmap.Create;
    Bmp.PixelFormat := pf24bit;
    Bmp.Width  := SZ;
    Bmp.Height := SZ;
    with Bmp.Canvas do
    begin
      Brush.Color := C; Pen.Color := C;
      FillRect(0, 0, SZ, SZ);
      Pen.Color := clWhite; Brush.Color := clWhite;
      Pen.Width := 1;
    end;
  end;

  procedure DoneIcon;
  begin
    ImageList1.Add(Bmp, nil);
    FreeAndNil(Bmp);
  end;

  procedure WPoly(const P: array of TPoint);
  begin
    with Bmp.Canvas do
    begin Pen.Color := clWhite; Brush.Color := clWhite; Polygon(P); end;
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
    begin Pen.Color := clWhite; Pen.Width := W;
      MoveTo(X1,Y1); LineTo(X2,Y2); Pen.Width := 1; end;
  end;

begin
  ImageList1.Width  := SZ;
  ImageList1.Height := SZ;
  Bmp := nil;

  { 0 – New: page with dog-eared corner }
  StartIcon(C_NEW);
  WPoly([Point(4,2),Point(16,2),Point(16,6),Point(20,6),Point(20,22),Point(4,22)]);
  with Bmp.Canvas do
  begin Pen.Color := $CCBBAA; Brush.Color := $CCBBAA;
    Polygon([Point(16,2),Point(20,6),Point(16,6)]); end;
  DoneIcon;

  { 1 – Open: folder }
  StartIcon(C_OPEN);
  WPoly([Point(2,10),Point(2,8),Point(8,8),Point(10,10)]);
  WPoly([Point(2,10),Point(22,10),Point(22,21),Point(2,21)]);
  with Bmp.Canvas do
  begin Pen.Color := $4488CC; Brush.Color := $4488CC; FillRect(3,13,21,20);
    Pen.Color := clWhite; Brush.Color := clWhite; end;
  DoneIcon;

  { 2 – Save: floppy disk }
  StartIcon(C_SAVE);
  WPoly([Point(2,2),Point(22,2),Point(22,22),Point(2,22)]);
  BgFill(4,13,20,21);
  BgFill(7, 2,17, 9);
  with Bmp.Canvas do
  begin Pen.Color := clWhite; Brush.Color := clWhite; Ellipse(10,3,14,8); end;
  DoneIcon;

  { 3 – Save As: floppy + plus notch }
  StartIcon(C_SAVAS);
  WPoly([Point(2,2),Point(22,2),Point(22,22),Point(2,22)]);
  BgFill(4,13,20,21);
  BgFill(7, 2,17, 9);
  with Bmp.Canvas do
  begin Pen.Color := clWhite; Brush.Color := clWhite; Ellipse(10,3,14,8); end;
  BgFill(15,15,22,17);
  BgFill(17,13,19,21);
  DoneIcon;

  { 4 – Download: down-arrow + server marks }
  StartIcon(C_DOWN);
  WPoly([Point(10,3),Point(14,3),Point(14,13),Point(17,13),
         Point(12,21),Point(7,13),Point(10,13)]);
  WLine(3,5,8,5,2);
  WLine(3,8,8,8,2);
  DoneIcon;

  { 5 – Upload: up-arrow + server marks }
  StartIcon(C_UP);
  WPoly([Point(12,3),Point(17,11),Point(14,11),Point(14,21),
         Point(10,21),Point(10,11),Point(7,11)]);
  WLine(3,16,8,16,2);
  WLine(3,19,8,19,2);
  DoneIcon;

  { 6 – Upload Local File: document page + upward arrow }
  StartIcon($226644);   { dark forest green }
  { Small page outline on the left }
  WPoly([Point(2,10),Point(9,10),Point(9,13),Point(12,13),Point(12,22),Point(2,22)]);
  with Bmp.Canvas do
  begin
    Pen.Color   := $113322;  Brush.Color := $113322;
    Polygon([Point(9,10),Point(12,13),Point(9,13)]);   { dog-ear }
  end;
  { Up arrow on the right }
  WPoly([Point(17,3),Point(21,9),Point(19,9),Point(19,17),
         Point(15,17),Point(15,9),Point(13,9)]);
  DoneIcon;

  { 7 – Submit JCL: play triangle }
  StartIcon(C_SUBM);
  WPoly([Point(5,3),Point(5,21),Point(20,12)]);
  DoneIcon;

  { 8 – View Spool: document with text lines  }
  StartIcon(C_SPOOL);
  WPoly([Point(3,2),Point(16,2),Point(16,6),Point(20,6),Point(20,22),Point(3,22)]);
  BgPoly([Point(16,2),Point(20,6),Point(16,6)]);
  BgFill(6, 9,18,11);
  BgFill(6,13,18,15);
  BgFill(6,17,18,19);
  DoneIcon;

  { 9 – Check connection: tick / checkmark }
  StartIcon(C_CHECK);
  WPoly([Point(3,12),Point(8,18),Point(21,5),Point(21,9),Point(8,22),Point(3,16)]);
  DoneIcon;

  { 10 – Clear editor: eraser body + trail lines }
  StartIcon($AA2222);    { crimson }
  { Eraser body (rectangle outline) }
  WPoly([Point(2,8),Point(16,8),Point(16,21),Point(2,21)]);
  BgFill(3,9,15,20);
  { Band across the bottom quarter of the eraser }
  WPoly([Point(2,16),Point(16,16),Point(16,21),Point(2,21)]);
  { Trail marks to the right suggesting swept-away content }
  WLine(18,11,22,11,2);
  WLine(18,16,22,16,2);
  DoneIcon;
end;

{ ==================================================================== }
{ UI helpers                                                            }
{ ==================================================================== }
procedure TMainForm.ApplyEditorFont(const AName: string; ASize: Integer);
begin
  SynEdit1.Font.BeginUpdate;
  try
    SynEdit1.Font.Name  := AName;
    SynEdit1.Font.Size  := ASize;
    SynEdit1.Font.Style := [];
  finally
    SynEdit1.Font.EndUpdate;
  end;
  UpdateMaxWidth;
  RulerBox.Invalidate;
end;

procedure TMainForm.UpdateMaxWidth;
var
  CharW, GutterW, NonClientW: Integer;
begin
  CharW := SynEdit1.CharWidth;
  if CharW <= 0 then Exit;
  if SynEdit1.Gutter.Visible then
    GutterW := SynEdit1.Gutter.Width
  else
    GutterW := 0;
  NonClientW := Width - ClientWidth;
  Constraints.MaxWidth := 123 * CharW + GutterW + NonClientW;
end;

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
  StatusBar1.Panels[0].Text := Msg;
  SynEdit1.ReadOnly := True;
  Screen.Cursor := crHourglass;
  Application.ProcessMessages;
end;

procedure TMainForm.SetReady;
begin
  SynEdit1.ReadOnly := False;
  Screen.Cursor := crDefault;
  StatusBar1.Panels[0].Text := 'Ready';
end;

procedure TMainForm.FormActivate(Sender: TObject);
begin
  UpdateMaxWidth;
  TriggerFocusRestore;
end;

procedure TMainForm.TriggerFocusRestore;
begin
  FRestoreFocusTimer.Enabled := True;
end;

procedure TMainForm.DoRestoreFocus(Sender: TObject);
begin
  FRestoreFocusTimer.Enabled := False;
  if SynEdit1.CanFocus then
    SynEdit1.SetFocus;
end;

procedure TMainForm.UpdateProfilePanel;
begin
  if FUseDefaultProfile or (FActiveProfileName = '') then
    StatusBar1.Panels[3].Text := 'Profile: default'
  else
    StatusBar1.Panels[3].Text := 'Profile: ' + FActiveProfileName;
end;

{ ==================================================================== }
{ Syntax detection                                                      }
{ ==================================================================== }
procedure TMainForm.DetectAndApplyHighlighter;
var
  ST: TSyntaxType;
begin
  ST := DetectSyntaxFromFile(
    IfThen(FCurrentFile <> '', FCurrentFile, FCurrentDataset),
    SynEdit1.Lines);

  case ST of
    synJCL:
    begin
      SynEdit1.Highlighter      := FJCLHlr;
      StatusBar1.Panels[2].Text := 'Syntax: JCL';
    end;
    synCOBOL:
    begin
      SynEdit1.Highlighter      := FCOBOLHlr;
      StatusBar1.Panels[2].Text := 'Syntax: COBOL';
    end;
    else
    begin
      SynEdit1.Highlighter      := nil;
      StatusBar1.Panels[2].Text := 'Syntax: –';
    end;
  end;
end;

{ ==================================================================== }
{ File operations                                                       }
{ ==================================================================== }
procedure TMainForm.DoNew;
begin
  if not ConfirmSave then Exit;
  SynEdit1.Clear;
  SynEdit1.Highlighter      := nil;
  FCurrentFile              := '';
  FCurrentDataset           := '';
  FLastJobID                := '';
  SetModified(False);
  StatusBar1.Panels[1].Text := 'File: ' + UNTITLED;
  StatusBar1.Panels[2].Text := 'Syntax: –';
  UpdateTitle;
end;

procedure TMainForm.DoOpen(const AFileName: string);
begin
  if not ConfirmSave then Exit;
  try
    SynEdit1.Lines.LoadFromFile(AFileName);
    FCurrentFile    := AFileName;
    FCurrentDataset := '';
    SetModified(False);
    StatusBar1.Panels[1].Text := 'File: ' + ExtractFileName(AFileName);
    StatusBar1.Panels[0].Text := 'Loaded: ' + AFileName;
    DetectAndApplyHighlighter;
    UpdateTitle;
    TriggerFocusRestore;
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
    SynEdit1.Lines.SaveToFile(FCurrentFile);
    SetModified(False);
    StatusBar1.Panels[0].Text := 'Saved: ' + FCurrentFile;
    Result := True;
  except
    on E: Exception do
      ShowMessage('Failed to save:'#10 + E.Message);
  end;
end;

function TMainForm.DoSaveAs: Boolean;
begin
  Result := False;
  SaveDialog1.FileName := ExtractFileName(FCurrentFile);
  if not SaveDialog1.Execute then Exit;
  FCurrentFile := SaveDialog1.FileName;
  StatusBar1.Panels[1].Text := 'File: ' + ExtractFileName(FCurrentFile);
  DetectAndApplyHighlighter;
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

function TMainForm.TempFile(const Ext: string): string;
begin
  Result := GetTempDir + 'zowe_ed_' +
            FormatDateTime('hhnnsszzz', Now) + '.' + Ext;
end;

{ ==================================================================== }
{ Event handlers – File                                                 }
{ ==================================================================== }
procedure TMainForm.MnuFileNewClick    (Sender: TObject); begin DoNew;    end;
procedure TMainForm.MnuFileSaveClick   (Sender: TObject); begin DoSave;   end;
procedure TMainForm.MnuFileSaveAsClick (Sender: TObject); begin DoSaveAs; end;
procedure TMainForm.MnuFileClearClick  (Sender: TObject); begin DoNew;    end;
procedure TMainForm.MnuFileExitClick   (Sender: TObject); begin Close;    end;

procedure TMainForm.MnuFileOpenClick(Sender: TObject);
begin
  OpenDialog1.FileName := '';
  if OpenDialog1.Execute then
    DoOpen(OpenDialog1.FileName);
end;

{ ==================================================================== }
{ Event handlers – Edit                                                 }
{ ==================================================================== }
procedure TMainForm.MnuEditCutClick       (Sender: TObject); begin SynEdit1.CutToClipboard;    end;
procedure TMainForm.MnuEditCopyClick      (Sender: TObject); begin SynEdit1.CopyToClipboard;   end;
procedure TMainForm.MnuEditPasteClick     (Sender: TObject); begin SynEdit1.PasteFromClipboard; end;
procedure TMainForm.MnuEditSelectAllClick (Sender: TObject); begin SynEdit1.SelectAll;          end;

{ ---- Find / Replace ---- }

procedure TMainForm.MnuEditFindClick(Sender: TObject);
begin
  FindDialog1.Execute;
end;

procedure TMainForm.MnuEditFindNextClick(Sender: TObject);
begin
  if FLastFindText = '' then
  begin
    FindDialog1.Execute;
    Exit;
  end;
  if SynEdit1.SearchReplace(FLastFindText, '', FLastFindOpts) = 0 then
    ShowMessage('"' + FLastFindText + '" not found.');
end;

procedure TMainForm.MnuEditReplaceClick(Sender: TObject);
begin
  ReplaceDialog1.FindText := FindDialog1.FindText;
  ReplaceDialog1.Execute;
end;

procedure TMainForm.FindDialog1Find(Sender: TObject);
var
  Opts: TSynSearchOptions;
begin
  Opts := [];
  if frMatchCase in FindDialog1.Options then Include(Opts, ssoMatchCase);
  if frWholeWord in FindDialog1.Options then Include(Opts, ssoWholeWord);
  if not (frDown in FindDialog1.Options) then Include(Opts, ssoBackwards);
  FLastFindText := FindDialog1.FindText;
  FLastFindOpts := Opts;
  if SynEdit1.SearchReplace(FLastFindText, '', Opts) = 0 then
    ShowMessage('"' + FLastFindText + '" not found.');
end;

procedure TMainForm.ReplaceDialog1Find(Sender: TObject);
var
  Opts: TSynSearchOptions;
begin
  Opts := [];
  if frMatchCase in ReplaceDialog1.Options then Include(Opts, ssoMatchCase);
  if frWholeWord in ReplaceDialog1.Options then Include(Opts, ssoWholeWord);
  if not (frDown in ReplaceDialog1.Options) then Include(Opts, ssoBackwards);
  FLastFindText := ReplaceDialog1.FindText;
  FLastFindOpts := Opts;
  if SynEdit1.SearchReplace(FLastFindText, '', Opts) = 0 then
    ShowMessage('"' + FLastFindText + '" not found.');
end;

procedure TMainForm.ReplaceDialog1Replace(Sender: TObject);
var
  Opts:  TSynSearchOptions;
  Count: Integer;
begin
  Opts := [];
  if frMatchCase  in ReplaceDialog1.Options then Include(Opts, ssoMatchCase);
  if frWholeWord  in ReplaceDialog1.Options then Include(Opts, ssoWholeWord);
  if not (frDown  in ReplaceDialog1.Options) then Include(Opts, ssoBackwards);
  if frReplaceAll in ReplaceDialog1.Options then
  begin
    Include(Opts, ssoReplaceAll);
    Include(Opts, ssoEntireScope);
  end
  else
    Include(Opts, ssoReplace);
  FLastFindText := ReplaceDialog1.FindText;
  FLastFindOpts := Opts - [ssoReplace, ssoReplaceAll, ssoEntireScope];
  Count := SynEdit1.SearchReplace(
    ReplaceDialog1.FindText, ReplaceDialog1.ReplaceText, Opts);
  if Count = 0 then
    ShowMessage('"' + ReplaceDialog1.FindText + '" not found.')
  else if frReplaceAll in ReplaceDialog1.Options then
    ShowMessage(IntToStr(Count) + ' replacement(s) made.');
end;

procedure TMainForm.MnuEditFontClick(Sender: TObject);
begin
  FontDialog1.Font.Assign(SynEdit1.Font);
  if not FontDialog1.Execute then Exit;
  ApplyEditorFont(FontDialog1.Font.Name, FontDialog1.Font.Size);
  SaveEditorFont(SynEdit1.Font.Name, SynEdit1.Font.Size);
  TriggerFocusRestore;
end;

{ ==================================================================== }
{ Event handlers – Zowe                                                 }
{ ==================================================================== }
procedure TMainForm.MnuZoweDownloadClick(Sender: TObject);
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
    SynEdit1.Lines.LoadFromFile(TF);
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
  StatusBar1.Panels[1].Text := 'Dataset: ' + FCurrentDataset;
  StatusBar1.Panels[0].Text := 'Downloaded: ' + FCurrentDataset;
  DetectAndApplyHighlighter;
  UpdateTitle;
  TriggerFocusRestore;
end;

procedure TMainForm.MnuZoweUploadClick(Sender: TObject);
var
  Dataset: string;
  TF:      string;
  R:       TZoweResult;
  Default: string;
begin
  { Prefer the last-used upload target; fall back to the current dataset }
  Default := FLastUploadDataset;
  if Default = '' then Default := FCurrentDataset;

  Dataset := InputBox('Upload Editor Content to MVS',
    'Enter target dataset or PDS member' + #10 +
    '(e.g. HLQ.DATA  or  HLQ.PDS(MEMBER)):',
    Default);
  if Trim(Dataset) = '' then Exit;

  TF := TempFile('txt');
  try
    SynEdit1.Lines.SaveToFile(TF);
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

  FCurrentDataset     := UpperCase(Trim(Dataset));
  FLastUploadDataset  := FCurrentDataset;
  StatusBar1.Panels[1].Text := 'Dataset: ' + FCurrentDataset;
  StatusBar1.Panels[0].Text := 'Uploaded to ' + FCurrentDataset;
  ShowMessage('Dataset uploaded successfully to ' + FCurrentDataset);
end;

{ ------------------------------------------------------------------ }
procedure TMainForm.MnuZoweUploadLocalClick(Sender: TObject);
var
  LocalFile: string;
  Dataset:   string;
  R:         TZoweResult;
  Ans:       Integer;
  Binary:    Boolean;
begin
  { Step 1: choose local file }
  UploadDialog.FileName := '';
  if not UploadDialog.Execute then Exit;
  LocalFile := UploadDialog.FileName;

  { Step 2: choose MVS target, defaulting to last used name }
  Dataset := InputBox('Upload Local File to MVS',
    'File: ' + ExtractFileName(LocalFile) + #10 +
    'Enter target dataset or PDS member' + #10 +
    '(e.g. HLQ.DATA  or  HLQ.PDS(MEMBER)):',
    FLastUploadDataset);
  if Trim(Dataset) = '' then Exit;

  Dataset := UpperCase(Trim(Dataset));

  { Step 3: choose transfer mode }
  Ans := QuestionDlg('Transfer Mode',
    'Upload "' + ExtractFileName(LocalFile) + '" in text or binary mode?' + #10#10 +
    'Text   – converts line endings; use for JCL, COBOL, scripts.' + #10 +
    'Binary – uploads byte-for-byte; use for load modules, ZIPs, images.',
    mtConfirmation,
    [mrYes, '&Text', mrNo, '&Binary', mrCancel, 'Cancel'], 0);
  if Ans = mrCancel then Exit;
  Binary := (Ans = mrNo);

  SetBusy('Uploading ' + ExtractFileName(LocalFile) + ' to ' + Dataset +
          IfThen(Binary, ' (binary)...', ' (text)...'));
  try
    R := ZoweUploadDataset(LocalFile, Dataset, Binary);
  finally
    SetReady;
  end;

  if not R.Success then
  begin
    ShowMessage('Upload failed:'#10 + R.ErrorMsg);
    Exit;
  end;

  FLastUploadDataset        := Dataset;
  StatusBar1.Panels[0].Text := 'Uploaded to ' + Dataset;
  ShowMessage(ExtractFileName(LocalFile) + #10 +
              'uploaded successfully to ' + Dataset);
end;

procedure TMainForm.MnuZoweSubmitClick(Sender: TObject);
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
    SynEdit1.Lines.SaveToFile(TF);
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
    StatusBar1.Panels[0].Text := 'Job submitted: ' + JobID;
    ShowMessage('Job submitted successfully!'#10 +
                'Job ID: ' + JobID + #10#10 +
                'Use Zowe > View Jobs & Spool (F6) to check the output.');
  end
  else
    ShowMessage('Job submitted.'#10 + R.Output);
end;

procedure TMainForm.MnuZoweViewSpoolClick(Sender: TObject);
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

procedure TMainForm.MnuZoweCheckClick(Sender: TObject);
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

procedure TMainForm.MnuZoweProfileClick(Sender: TObject);
var
  F: TProfileForm;
begin
  F := TProfileForm.Create(Self);
  try
    F.InitSettings(FUseDefaultProfile, FActiveProfileName);
    if F.ShowModal = mrOK then
    begin
      FUseDefaultProfile := F.UseDefault;
      FActiveProfileName := F.ProfileName;
      if FUseDefaultProfile then
        ActiveZoweProfile := ''
      else
        ActiveZoweProfile := FActiveProfileName;
      SaveZoweProfile(FUseDefaultProfile, FActiveProfileName);
      UpdateProfilePanel;
    end;
  finally
    F.Free;
  end;
end;

{ ==================================================================== }
{ Event handlers – Help                                                 }
{ ==================================================================== }
procedure TMainForm.MnuHelpAboutClick(Sender: TObject);
begin
  ShowMessage(
    APP_TITLE + #10#10 +
    'A lightweight text editor with IBM z/OS (MVS) integration'#10 +
    'via the Zowe CLI.  Syntax highlighting for JCL and COBOL.'#10#10 +
    'Keyboard shortcuts:'#10 +
    '  Ctrl+N        – New file'#10 +
    '  Ctrl+O        – Open file'#10 +
    '  Ctrl+S        – Save'#10 +
    '  Ctrl+Shift+S  – Save As'#10 +
    '  F5            – Submit JCL job'#10 +
    '  F6            – View Jobs & Spool'#10#10 +
    'Zowe menu:'#10 +
    '  Download Dataset from MVS'#10 +
    '  Upload Dataset to MVS'#10 +
    '  Submit JCL Job'#10 +
    '  View Jobs & Spool output'#10#10 +
    'Built with Lazarus / Free Pascal'
  );
end;

{ ==================================================================== }
{ Column ruler                                                          }
{ ==================================================================== }
procedure TMainForm.RulerBoxPaint(Sender: TObject);
const
  COL_GUIDE = 80;    { soft convention guide – red }
  COL_LIMIT = 123;   { hard window limit – blue    }
var
  CharW, GutterW, FirstCol, LastCol, Col, X, H: Integer;
  S: string;
  IsGuide, IsLimit: Boolean;
begin
  H := RulerBox.Height;
  with RulerBox.Canvas do
  begin
    { Background – match toolbar / statusbar }
    Brush.Color := clBtnFace;
    Pen.Color   := clBtnFace;
    FillRect(0, 0, RulerBox.Width, H);

    CharW := SynEdit1.CharWidth;
    if CharW <= 0 then Exit;

    { Account for gutter if visible }
    if SynEdit1.Gutter.Visible then
      GutterW := SynEdit1.Gutter.Width
    else
      GutterW := 0;

    Font.Name  := SynEdit1.Font.Name;
    Font.Size  := 7;
    Font.Style := [];

    FirstCol := SynEdit1.LeftChar;   { 1-based first visible column }
    LastCol  := FirstCol + ((RulerBox.Width - GutterW) div CharW) + 2;

    for Col := FirstCol to LastCol do
    begin
      X := GutterW + (Col - FirstCol) * CharW;
      if X > RulerBox.Width then Break;

      IsGuide := (Col = COL_GUIDE);
      IsLimit := (Col = COL_LIMIT);

      if IsLimit then
      begin
        { Hard limit at col 123 – light blue background, blue tick }
        Brush.Color := $00FFDCC8;   { RGB(200,220,255) light blue }
        FillRect(X, 0, X + CharW, H - 1);
        Pen.Color  := $00C06000;   { RGB(0,96,192) medium blue }
        Font.Color := $00C06000;
      end
      else if IsGuide then
      begin
        { Convention guide at col 80 – light salmon, red tick }
        Brush.Color := $00C8DCFF;   { light salmon }
        FillRect(X, 0, X + CharW, H - 1);
        Pen.Color  := clRed;
        Font.Color := clRed;
      end
      else
      begin
        Brush.Color := clBtnFace;
        Pen.Color   := $00909090;
        Font.Color  := $00505050;
      end;

      { Tick height: long + label for special columns and multiples of 10,
        medium for multiples of 5, short otherwise }
      if IsGuide or IsLimit or ((Col mod 10) = 0) then
      begin
        MoveTo(X, H - 7); LineTo(X, H - 1);
        S := IntToStr(Col);
        TextOut(X - TextWidth(S) div 2 + 1, 1, S);
      end
      else if (Col mod 5) = 0 then
      begin
        MoveTo(X, H - 5); LineTo(X, H - 1);
      end
      else
      begin
        MoveTo(X, H - 3); LineTo(X, H - 1);
      end;
    end;

    { Bottom separator line }
    Pen.Color := $00A0A0A0;
    MoveTo(0, H - 1); LineTo(RulerBox.Width, H - 1);
  end;
end;

procedure TMainForm.SynEdit1StatusChange(Sender: TObject; Changes: TSynStatusChanges);
begin
  RulerBox.Invalidate;
end;

{ ==================================================================== }
{ Form / Editor events                                                  }
{ ==================================================================== }
procedure TMainForm.SynEdit1Change(Sender: TObject);
begin
  if not FModified then
    SetModified(True);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ConfirmSave;
end;

end.
