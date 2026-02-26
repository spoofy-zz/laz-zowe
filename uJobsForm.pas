unit uJobsForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, Buttons,
  uZoweOps;

type
  TJobsForm = class(TForm)
  private
    { Layout }
    FToolPanel:   TPanel;
    FSplitter:    TSplitter;
    FLeftPanel:   TPanel;
    FRightPanel:  TPanel;

    { Left – job list }
    FJobsLabel:   TLabel;
    FOwnerEdit:   TEdit;
    FOwnerLabel:  TLabel;
    FRefreshBtn:  TBitBtn;
    FJobList:     TListView;

    { Right – spool viewer }
    FSpoolLabel:  TLabel;
    FSpoolSelect: TComboBox;
    FViewBtn:     TBitBtn;
    FSpoolMemo:   TMemo;

    { Bottom }
    FBottomPanel: TPanel;
    FCloseBtn:    TBitBtn;
    FStatusLabel: TLabel;

    FJobs: TJobInfoArray;

    procedure BuildUI;
    procedure JobListSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure LoadSpoolFileList(const JobID: string);
    procedure SetStatus(const Msg: string);
    procedure ViewSpoolClick(Sender: TObject);

  public
    constructor Create(AOwner: TComponent); override;
    procedure RefreshJobs(Sender: TObject);
    procedure HighlightJob(const JobID: string);
  end;

implementation

uses
  fpjson, jsonparser;

{ ------------------------------------------------------------------ }
constructor TJobsForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BuildUI;
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.BuildUI;
var
  Strip: TPanel;
begin
  Caption    := 'Zowe – Jobs && Spool Viewer';
  Width      := 940;
  Height     := 620;
  Position   := poMainFormCenter;
  KeyPreview := True;

  { ---- Bottom panel ---- }
  FBottomPanel            := TPanel.Create(Self);
  FBottomPanel.Parent     := Self;
  FBottomPanel.Align      := alBottom;
  FBottomPanel.Height     := 36;
  FBottomPanel.BevelOuter := bvNone;

  FCloseBtn           := TBitBtn.Create(Self);
  FCloseBtn.Parent    := FBottomPanel;
  FCloseBtn.Kind      := bkClose;
  FCloseBtn.Caption   := 'Close';
  FCloseBtn.Width     := 90;
  FCloseBtn.Height    := 26;
  FCloseBtn.Top       := 5;
  FCloseBtn.Anchors   := [akRight, akTop];
  FCloseBtn.Left      := FBottomPanel.Width - FCloseBtn.Width - 8;

  FStatusLabel          := TLabel.Create(Self);
  FStatusLabel.Parent   := FBottomPanel;
  FStatusLabel.Left     := 8;
  FStatusLabel.Top      := 10;
  FStatusLabel.Caption  := 'Ready';
  FStatusLabel.AutoSize := True;

  { ---- Toolbar panel ---- }
  FToolPanel            := TPanel.Create(Self);
  FToolPanel.Parent     := Self;
  FToolPanel.Align      := alTop;
  FToolPanel.Height     := 36;
  FToolPanel.BevelOuter := bvNone;

  FOwnerLabel          := TLabel.Create(Self);
  FOwnerLabel.Parent   := FToolPanel;
  FOwnerLabel.Caption  := 'Owner filter:';
  FOwnerLabel.Left     := 8;
  FOwnerLabel.Top      := 10;
  FOwnerLabel.AutoSize := True;

  FOwnerEdit        := TEdit.Create(Self);
  FOwnerEdit.Parent := FToolPanel;
  FOwnerEdit.Left   := 90;
  FOwnerEdit.Top    := 6;
  FOwnerEdit.Width  := 120;
  FOwnerEdit.Height := 22;
  FOwnerEdit.Text   := '*';

  FRefreshBtn         := TBitBtn.Create(Self);
  FRefreshBtn.Parent  := FToolPanel;
  FRefreshBtn.Caption := 'Refresh Jobs';
  FRefreshBtn.Left    := 220;
  FRefreshBtn.Top     := 5;
  FRefreshBtn.Width   := 110;
  FRefreshBtn.Height  := 26;
  FRefreshBtn.OnClick := @RefreshJobs;

  { ---- Left panel – job list ---- }
  FLeftPanel            := TPanel.Create(Self);
  FLeftPanel.Parent     := Self;
  FLeftPanel.Align      := alLeft;
  FLeftPanel.Width      := 380;
  FLeftPanel.BevelOuter := bvNone;

  FJobsLabel         := TLabel.Create(Self);
  FJobsLabel.Parent  := FLeftPanel;
  FJobsLabel.Align   := alTop;
  FJobsLabel.Caption := ' Jobs';
  FJobsLabel.Height  := 20;

  FJobList               := TListView.Create(Self);
  FJobList.Parent        := FLeftPanel;
  FJobList.Align         := alClient;
  FJobList.ViewStyle     := vsReport;
  FJobList.ReadOnly      := True;
  FJobList.RowSelect     := True;
  FJobList.GridLines     := True;
  FJobList.HideSelection := False;
  FJobList.OnSelectItem  := @JobListSelect;

  with FJobList.Columns.Add do begin Caption := 'Job Name'; Width := 90;  end;
  with FJobList.Columns.Add do begin Caption := 'Job ID';   Width := 90;  end;
  with FJobList.Columns.Add do begin Caption := 'Status';   Width := 80;  end;
  with FJobList.Columns.Add do begin Caption := 'Ret Code'; Width := 80;  end;
  with FJobList.Columns.Add do begin Caption := 'Owner';    Width := 70;  end;

  { ---- Splitter ---- }
  FSplitter        := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align  := alLeft;
  FSplitter.Width  := 5;

  { ---- Right panel – spool viewer ---- }
  FRightPanel            := TPanel.Create(Self);
  FRightPanel.Parent     := Self;
  FRightPanel.Align      := alClient;
  FRightPanel.BevelOuter := bvNone;

  FSpoolLabel         := TLabel.Create(Self);
  FSpoolLabel.Parent  := FRightPanel;
  FSpoolLabel.Align   := alTop;
  FSpoolLabel.Caption := ' Spool content';
  FSpoolLabel.Height  := 20;

  { Thin strip for the spool-file selector + view button }
  Strip             := TPanel.Create(Self);
  Strip.Parent      := FRightPanel;
  Strip.Align       := alTop;
  Strip.Height      := 32;
  Strip.BevelOuter  := bvNone;

  FSpoolSelect           := TComboBox.Create(Self);
  FSpoolSelect.Parent    := Strip;
  FSpoolSelect.Left      := 4;
  FSpoolSelect.Top       := 4;
  FSpoolSelect.Width     := 260;
  FSpoolSelect.Height    := 22;
  FSpoolSelect.Style     := csDropDownList;
  FSpoolSelect.Items.Add('(select a job first)');
  FSpoolSelect.ItemIndex := 0;

  FViewBtn         := TBitBtn.Create(Self);
  FViewBtn.Parent  := Strip;
  FViewBtn.Caption := 'View Spool';
  FViewBtn.Left    := 274;
  FViewBtn.Top     := 3;
  FViewBtn.Width   := 100;
  FViewBtn.Height  := 26;
  FViewBtn.OnClick := @ViewSpoolClick;

  FSpoolMemo            := TMemo.Create(Self);
  FSpoolMemo.Parent     := FRightPanel;
  FSpoolMemo.Align      := alClient;
  FSpoolMemo.ScrollBars := ssBoth;
  FSpoolMemo.ReadOnly   := True;
  FSpoolMemo.WordWrap   := False;
  FSpoolMemo.Font.Name  := 'Monospace';
  FSpoolMemo.Font.Size  := 9;
  FSpoolMemo.Color      := clBlack;
  FSpoolMemo.Font.Color := clLime;
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.SetStatus(const Msg: string);
begin
  FStatusLabel.Caption := Msg;
  Application.ProcessMessages;
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.RefreshJobs(Sender: TObject);
var
  R:          TZoweResult;
  Item:       TListItem;
  I:          Integer;
  OwnerFilter: string;
begin
  OwnerFilter := Trim(FOwnerEdit.Text);
  if OwnerFilter = '' then OwnerFilter := '*';

  SetStatus('Fetching job list from MVS...');
  Self.Enabled := False;
  try
    R := ZoweListJobs(OwnerFilter);
  finally
    Self.Enabled := True;
  end;

  FJobList.Items.Clear;
  FSpoolSelect.Items.Clear;
  FSpoolSelect.Items.Add('(select a job first)');
  FSpoolSelect.ItemIndex := 0;
  FSpoolMemo.Clear;

  if not R.Success then
  begin
    SetStatus('Error fetching jobs');
    ShowMessage('Failed to list jobs:'#10 + R.ErrorMsg);
    Exit;
  end;

  ParseJobList(R.Output, FJobs);

  if Length(FJobs) = 0 then
  begin
    { Zowe returned success but no jobs – show raw output so the user can
      diagnose connection / permission issues without needing a debugger. }
    SetStatus('No jobs returned');
    FSpoolMemo.Lines.Text :=
      '== No jobs were returned by Zowe. Raw output below =='#10#10 +
      R.Output;
    Exit;
  end;

  for I := 0 to High(FJobs) do
  begin
    Item         := FJobList.Items.Add;
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
  FSpoolSelect.Items.Clear;
  FSpoolSelect.Items.Add('-- All spool (concatenated) --');

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
    FSpoolSelect.ItemIndex := 0;
    Exit;
  end;

  try
    { ZoweUnwrapData handles the Zowe CLI v3 envelope format }
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
          FSpoolSelect.Items.Add(
            Format('%d: %s  [%s]', [SpoolFileID, DDN, StepName]));
        end;
      end;
    finally
      J.Free;
    end;
  except
    { keep the "All spool" entry on parse errors }
  end;

  FSpoolSelect.ItemIndex := 0;
  SetStatus('Ready');
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.ViewSpoolClick(Sender: TObject);
var
  R:      TZoweResult;
  Idx:    Integer;
  JobID:  string;
  SelIdx: Integer;
  S:      string;
  ColPos: Integer;
  SpoolID: Integer;
begin
  if FJobList.Selected = nil then
  begin
    ShowMessage('Please select a job first.');
    Exit;
  end;

  Idx := Integer(PtrInt(FJobList.Selected.Data));
  if (Idx < 0) or (Idx >= Length(FJobs)) then Exit;
  JobID := FJobs[Idx].JobID;

  SelIdx := FSpoolSelect.ItemIndex;

  SetStatus('Fetching spool for ' + JobID + '...');
  Self.Enabled := False;
  try
    if SelIdx <= 0 then
    begin
      R := ZoweViewAllSpool(JobID);
    end
    else
    begin
      S      := FSpoolSelect.Items[SelIdx];
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

  FSpoolMemo.Lines.BeginUpdate;
  try
    FSpoolMemo.Lines.Text := R.Output;
  finally
    FSpoolMemo.Lines.EndUpdate;
  end;
  SetStatus(Format('Spool for %s  –  %d lines', [JobID, FSpoolMemo.Lines.Count]));
end;

{ ------------------------------------------------------------------ }
procedure TJobsForm.HighlightJob(const JobID: string);
var
  I: Integer;
begin
  for I := 0 to FJobList.Items.Count - 1 do
  begin
    if FJobList.Items[I].SubItems.Count > 0 then
      if FJobList.Items[I].SubItems[0] = JobID then
      begin
        FJobList.Items[I].Selected := True;
        FJobList.Items[I].MakeVisible(False);
        Break;
      end;
  end;
end;

end.
