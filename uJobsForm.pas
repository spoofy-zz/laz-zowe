unit uJobsForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, Buttons, LCLType,
  uZoweOps;

type
  TJobsForm = class(TForm)
    { ---- Toolbar panel ---- }
    ToolPanel:   TPanel;
    OwnerLabel:  TLabel;
    OwnerEdit:   TEdit;
    RefreshBtn:  TBitBtn;
    DeleteBtn:   TBitBtn;

    { ---- Bottom panel ---- }
    BottomPanel:  TPanel;
    StatusLabel:  TLabel;
    CloseBtn:     TBitBtn;

    { ---- Left panel – job list ---- }
    LeftPanel:  TPanel;
    JobsLabel:  TLabel;
    JobList:    TListView;

    { ---- Splitter ---- }
    Splitter1: TSplitter;

    { ---- Right panel – spool viewer ---- }
    RightPanel:  TPanel;
    SpoolLabel:  TLabel;
    SpoolStrip:  TPanel;
    SpoolSelect: TComboBox;
    ViewBtn:     TBitBtn;
    SpoolMemo:   TMemo;

    { ---- Event handlers ---- }
    procedure FormCreate      (Sender: TObject);
    procedure RefreshJobs     (Sender: TObject);
    procedure JobListSelect   (Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure JobListDblClick (Sender: TObject);
    procedure JobListKeyDown  (Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DeleteJobClick  (Sender: TObject);
    procedure ViewSpoolClick  (Sender: TObject);

  private
    FJobs: TJobInfoArray;

    procedure LoadSpoolFileList(const JobID: string);
    procedure SetStatus(const Msg: string);

  public
    procedure HighlightJob(const JobID: string);
  end;

implementation

{$R *.lfm}

uses
  fpjson, jsonparser;

{ ------------------------------------------------------------------ }
procedure TJobsForm.FormCreate(Sender: TObject);
begin
  { CloseBtn is right-aligned; set Left after the panel lays out }
  CloseBtn.Left := BottomPanel.ClientWidth - CloseBtn.Width - 8;

  { Seed the spool selector with the initial placeholder }
  SpoolSelect.Items.Clear;
  SpoolSelect.Items.Add('(select a job first)');
  SpoolSelect.ItemIndex := 0;
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.SetStatus(const Msg: string);
begin
  StatusLabel.Caption := Msg;
  Application.ProcessMessages;
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.RefreshJobs(Sender: TObject);
var
  R:           TZoweResult;
  Item:        TListItem;
  I, J:        Integer;
  Tmp:         TJobInfo;
  OwnerFilter: string;
begin
  OwnerFilter := Trim(OwnerEdit.Text);
  if OwnerFilter = '' then OwnerFilter := '*';

  SetStatus('Fetching job list from MVS...');
  Self.Enabled := False;
  try
    R := ZoweListJobs(OwnerFilter);
  finally
    Self.Enabled := True;
  end;

  JobList.Items.Clear;
  SpoolSelect.Items.Clear;
  SpoolSelect.Items.Add('(select a job first)');
  SpoolSelect.ItemIndex := 0;
  SpoolMemo.Clear;

  if not R.Success then
  begin
    SetStatus('Error fetching jobs');
    ShowMessage('Failed to list jobs:'#10 + R.ErrorMsg);
    Exit;
  end;

  ParseJobList(R.Output, FJobs);

  { Sort ascending by Job ID (bubble sort – job lists are small) }
  for I := 0 to High(FJobs) - 1 do
    for J := 0 to High(FJobs) - I - 1 do
      if FJobs[J].JobID > FJobs[J + 1].JobID then
      begin
        Tmp         := FJobs[J];
        FJobs[J]    := FJobs[J + 1];
        FJobs[J + 1] := Tmp;
      end;

  if Length(FJobs) = 0 then
  begin
    SetStatus('No jobs returned');
    SpoolMemo.Lines.Text :=
      '== No jobs were returned by Zowe. Raw output below =='#10#10 +
      R.Output;
    Exit;
  end;

  for I := 0 to High(FJobs) do
  begin
    Item         := JobList.Items.Add;
    Item.Caption := FJobs[I].JobName;
    Item.SubItems.Add(FJobs[I].JobID);
    Item.SubItems.Add(FJobs[I].Status);
    Item.SubItems.Add(FJobs[I].RetCode);
    Item.SubItems.Add(FJobs[I].Owner);
    Item.Data := Pointer(PtrInt(I));
  end;

  SetStatus(Format('%d job(s) loaded', [Length(FJobs)]));
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.JobListSelect(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  Idx: Integer;
begin
  if not Selected then Exit;
  if Item = nil then Exit;
  Idx := Integer(PtrInt(Item.Data));
  if (Idx < 0) or (Idx >= Length(FJobs)) then Exit;
  LoadSpoolFileList(FJobs[Idx].JobID);
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.LoadSpoolFileList(const JobID: string);
var
  R:           TZoweResult;
  J:           TJSONData;
  JArr:        TJSONArray;
  JObj:        TJSONObject;
  I:           Integer;
  DDN:         string;
  StepName:    string;
  SpoolFileID: Int64;
begin
  SpoolSelect.Items.Clear;
  SpoolSelect.Items.Add('-- All spool (concatenated) --');

  SetStatus('Loading spool file list for ' + JobID + '...');
  Self.Enabled := False;
  try
    R := ZoweListSpoolFiles(JobID);
  finally
    Self.Enabled := True;
  end;

  if not R.Success then
  begin
    SetStatus('Could not list spool files');
    SpoolSelect.ItemIndex := 0;
    Exit;
  end;

  try
    J := GetJSON(ZoweUnwrapData(R.Output));
    try
      if J is TJSONArray then
      begin
        JArr := J as TJSONArray;
        for I := 0 to JArr.Count - 1 do
        begin
          JObj        := JArr.Items[I] as TJSONObject;
          DDN         := JObj.Get('ddname',   IntToStr(I + 1));
          StepName    := JObj.Get('stepname', '');
          SpoolFileID := JObj.Get('id',       Int64(I + 1));
          SpoolSelect.Items.Add(
            Format('%d: %s  [%s]', [SpoolFileID, DDN, StepName]));
        end;
      end;
    finally
      J.Free;
    end;
  except
    { keep the "All spool" entry on parse errors }
  end;

  SpoolSelect.ItemIndex := 0;
  SetStatus('Ready');
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.ViewSpoolClick(Sender: TObject);
var
  R:       TZoweResult;
  Idx:     Integer;
  JobID:   string;
  SelIdx:  Integer;
  S:       string;
  ColPos:  Integer;
  SpoolID: Integer;
begin
  if JobList.Selected = nil then
  begin
    ShowMessage('Please select a job first.');
    Exit;
  end;

  Idx := Integer(PtrInt(JobList.Selected.Data));
  if (Idx < 0) or (Idx >= Length(FJobs)) then Exit;
  JobID := FJobs[Idx].JobID;

  SelIdx := SpoolSelect.ItemIndex;

  SetStatus('Fetching spool for ' + JobID + '...');
  Self.Enabled := False;
  try
    if SelIdx <= 0 then
    begin
      R := ZoweViewAllSpool(JobID);
    end
    else
    begin
      S      := SpoolSelect.Items[SelIdx];
      ColPos := Pos(':', S);
      if ColPos > 1 then
        SpoolID := StrToIntDef(Copy(S, 1, ColPos - 1), SelIdx)
      else
        SpoolID := SelIdx;
      R := ZoweViewSpoolFile(JobID, SpoolID);
    end;
  finally
    Self.Enabled := True;
  end;

  if not R.Success then
  begin
    SetStatus('Error fetching spool');
    ShowMessage('Failed to fetch spool:'#10 + R.ErrorMsg);
    Exit;
  end;

  SpoolMemo.Lines.BeginUpdate;
  try
    SpoolMemo.Lines.Text := R.Output;
  finally
    SpoolMemo.Lines.EndUpdate;
  end;
  SetStatus(Format('Spool for %s  –  %d lines', [JobID, SpoolMemo.Lines.Count]));
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.JobListDblClick(Sender: TObject);
begin
  ViewSpoolClick(Sender);
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.JobListKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_DELETE then
  begin
    Key := 0;
    DeleteJobClick(Sender);
  end;
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.DeleteJobClick(Sender: TObject);
var
  Idx:     Integer;
  JobID:   string;
  JobName: string;
  R:       TZoweResult;
begin
  if JobList.Selected = nil then
  begin
    ShowMessage('Please select a job to delete.');
    Exit;
  end;

  Idx := Integer(PtrInt(JobList.Selected.Data));
  if (Idx < 0) or (Idx >= Length(FJobs)) then Exit;

  JobID   := FJobs[Idx].JobID;
  JobName := FJobs[Idx].JobName;

  if MessageDlg('Delete Job',
    'Delete job ' + JobName + ' (' + JobID + ')?' + #10 +
    'This cannot be undone.',
    mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

  SetStatus('Deleting ' + JobID + '...');
  Self.Enabled := False;
  try
    R := ZoweDeleteJob(JobID);
  finally
    Self.Enabled := True;
  end;

  if not R.Success then
  begin
    SetStatus('Delete failed');
    ShowMessage('Failed to delete job ' + JobID + ':'#10 + R.ErrorMsg);
    Exit;
  end;

  SetStatus(JobID + ' deleted – refreshing list...');
  RefreshJobs(nil);
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.HighlightJob(const JobID: string);
var
  I: Integer;
begin
  for I := 0 to JobList.Items.Count - 1 do
  begin
    if JobList.Items[I].SubItems.Count > 0 then
      if JobList.Items[I].SubItems[0] = JobID then
      begin
        JobList.Items[I].Selected := True;
        JobList.Items[I].MakeVisible(False);
        Break;
      end;
  end;
end;

end.
