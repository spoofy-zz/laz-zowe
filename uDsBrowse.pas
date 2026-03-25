unit uDsBrowse;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs;

{ Show a dataset browser dialog.
  Datasets: list of dataset names to display in the listbox.
  AInitial: pre-fills the editable text field.
  out Selected: the final dataset name (from list or typed by hand).
  "Members..." button lets the user expand a PDS and pick a member,
  which fills the field as DSN(MEMBER).
  Returns True when OK is clicked with a non-empty name. }
function ShowDatasetBrowser(const ATitle, APrompt: string;
                            const Datasets: TStringList;
                            const AInitial: string;
                            out Selected: string): Boolean;

{ List members of ADSN and let the user pick one.
  On success returns True and sets Selected to DSN(MEMBER).
  Shows hourglass cursor while fetching from Zowe. }
function ShowMemberBrowser(const ADSN: string; out Selected: string): Boolean;

implementation

uses
  uZoweOps;

{ ==================================================================== }
{ TMemberBrowseForm – simple listbox for picking a PDS member          }
{ ==================================================================== }
type
  TMemberBrowseForm = class(TForm)
  private
    FListBox:   TListBox;
    FBtnNew:    TButton;
    FBtnOK:     TButton;
    FBtnCancel: TButton;
    FNewMember: string;   { set by New Member... when user creates a name }
    procedure ListBoxDblClick(Sender: TObject);
    procedure BtnNewClick(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
  public
    constructor CreateBrowser(AOwner: TComponent;
                              const ADSN: string;
                              const Members: TStringList);
    function SelectedMember: string;
  end;

constructor TMemberBrowseForm.CreateBrowser(AOwner: TComponent;
                                            const ADSN: string;
                                            const Members: TStringList);
var
  Lbl: TLabel;
begin
  inherited CreateNew(AOwner);
  Caption     := 'Members of ' + ADSN;
  Width       := 380;
  Height      := 420;
  Position    := poMainFormCenter;
  BorderStyle := bsDialog;
  FNewMember  := '';

  Lbl := TLabel.Create(Self);
  Lbl.Parent  := Self;
  Lbl.Left    := 8;
  Lbl.Top     := 8;
  Lbl.Caption := 'Select a member:';

  FListBox := TListBox.Create(Self);
  FListBox.Parent  := Self;
  FListBox.Left    := 8;
  FListBox.Top     := 28;
  FListBox.Width   := 364;
  FListBox.Height  := 340;
  FListBox.Items.Assign(Members);
  FListBox.OnDblClick := @ListBoxDblClick;

  FBtnNew := TButton.Create(Self);
  FBtnNew.Parent  := Self;
  FBtnNew.Caption := 'New Member...';
  FBtnNew.Width   := 110;
  FBtnNew.Left    := 8;
  FBtnNew.Top     := 378;
  FBtnNew.OnClick := @BtnNewClick;

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent  := Self;
  FBtnOK.Caption := 'OK';
  FBtnOK.Width   := 80;
  FBtnOK.Left    := 196;
  FBtnOK.Top     := 378;
  FBtnOK.Default := True;
  FBtnOK.OnClick := @BtnOKClick;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent      := Self;
  FBtnCancel.Caption     := 'Cancel';
  FBtnCancel.Width       := 80;
  FBtnCancel.Left        := 284;
  FBtnCancel.Top         := 378;
  FBtnCancel.ModalResult := mrCancel;

  ModalResult := mrNone;
end;

procedure TMemberBrowseForm.ListBoxDblClick(Sender: TObject);
begin
  if FListBox.ItemIndex >= 0 then
    ModalResult := mrOK;
end;

procedure TMemberBrowseForm.BtnNewClick(Sender: TObject);
var
  MbrName: string;
  I:       Integer;
  Valid:   Boolean;
  Ch:      Char;
begin
  MbrName := UpperCase(Trim(InputBox('New Member',
    'Enter new member name (1-8 chars, A-Z 0-9 @ # $):', '')));
  if MbrName = '' then Exit;

  if Length(MbrName) > 8 then
  begin
    ShowMessage('Member name must be 1-8 characters.');
    Exit;
  end;
  if not (MbrName[1] in ['A'..'Z', '@', '#', '$']) then
  begin
    ShowMessage('Member name must start with A-Z, @, #, or $.');
    Exit;
  end;
  Valid := True;
  for I := 1 to Length(MbrName) do
  begin
    Ch := MbrName[I];
    if not (Ch in ['A'..'Z', '0'..'9', '@', '#', '$']) then
    begin
      Valid := False;
      Break;
    end;
  end;
  if not Valid then
  begin
    ShowMessage('Member name may only contain A-Z, 0-9, @, #, $.');
    Exit;
  end;

  FNewMember  := MbrName;
  ModalResult := mrOK;
end;

procedure TMemberBrowseForm.BtnOKClick(Sender: TObject);
begin
  if FListBox.ItemIndex >= 0 then
    ModalResult := mrOK
  else
    ShowMessage('Please select a member or use "New Member...".');
end;

function TMemberBrowseForm.SelectedMember: string;
begin
  if FNewMember <> '' then
    Result := FNewMember
  else if FListBox.ItemIndex >= 0 then
    Result := FListBox.Items[FListBox.ItemIndex]
  else
    Result := '';
end;

{ ==================================================================== }
{ TDsBrowseForm – dataset browser with Members... expansion            }
{ ==================================================================== }
type
  TDsBrowseForm = class(TForm)
  private
    FListBox:    TListBox;
    FEdit:       TEdit;
    FBtnMembers: TButton;
    FBtnOK:      TButton;
    FBtnCancel:  TButton;
    procedure ListBoxClick(Sender: TObject);
    procedure ListBoxDblClick(Sender: TObject);
    procedure BtnMembersClick(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
    function  CurrentDSN: string;
  public
    constructor CreateBrowser(AOwner: TComponent;
                              const ATitle, APrompt: string;
                              const Datasets: TStringList;
                              const AInitial: string);
    function SelectedDataset: string;
  end;

constructor TDsBrowseForm.CreateBrowser(AOwner: TComponent;
                                        const ATitle, APrompt: string;
                                        const Datasets: TStringList;
                                        const AInitial: string);
var
  LblPrompt: TLabel;
  LblDs:     TLabel;
begin
  inherited CreateNew(AOwner);
  Caption     := ATitle;
  Width       := 500;
  Height      := 440;
  Position    := poMainFormCenter;
  BorderStyle := bsDialog;

  LblPrompt := TLabel.Create(Self);
  LblPrompt.Parent  := Self;
  LblPrompt.Left    := 8;
  LblPrompt.Top     := 8;
  LblPrompt.Width   := 484;
  LblPrompt.Caption := APrompt;

  FListBox := TListBox.Create(Self);
  FListBox.Parent  := Self;
  FListBox.Left    := 8;
  FListBox.Top     := 28;
  FListBox.Width   := 484;
  FListBox.Height  := 272;
  FListBox.Items.Assign(Datasets);
  FListBox.OnClick    := @ListBoxClick;
  FListBox.OnDblClick := @ListBoxDblClick;

  LblDs := TLabel.Create(Self);
  LblDs.Parent  := Self;
  LblDs.Left    := 8;
  LblDs.Top     := 308;
  LblDs.Caption := 'Dataset:';

  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.Left   := 8;
  FEdit.Top    := 326;
  FEdit.Width  := 484;
  FEdit.Text   := AInitial;

  { Members... – left-aligned, opens PDS member picker }
  FBtnMembers := TButton.Create(Self);
  FBtnMembers.Parent  := Self;
  FBtnMembers.Caption := 'Members...';
  FBtnMembers.Width   := 96;
  FBtnMembers.Left    := 8;
  FBtnMembers.Top     := 364;
  FBtnMembers.OnClick := @BtnMembersClick;

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent  := Self;
  FBtnOK.Caption := 'OK';
  FBtnOK.Width   := 80;
  FBtnOK.Left    := 316;
  FBtnOK.Top     := 364;
  FBtnOK.Default := True;
  FBtnOK.OnClick := @BtnOKClick;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent      := Self;
  FBtnCancel.Caption     := 'Cancel';
  FBtnCancel.Width       := 80;
  FBtnCancel.Left        := 404;
  FBtnCancel.Top         := 364;
  FBtnCancel.ModalResult := mrCancel;

  ModalResult := mrNone;
end;

{ Return base DSN from edit field (strips any existing (MEMBER) suffix) }
function TDsBrowseForm.CurrentDSN: string;
var
  P: Integer;
begin
  Result := Trim(FEdit.Text);
  P := Pos('(', Result);
  if P > 1 then Result := Trim(Copy(Result, 1, P - 1));
end;

procedure TDsBrowseForm.ListBoxClick(Sender: TObject);
begin
  if FListBox.ItemIndex >= 0 then
    FEdit.Text := FListBox.Items[FListBox.ItemIndex];
end;

procedure TDsBrowseForm.ListBoxDblClick(Sender: TObject);
begin
  if FListBox.ItemIndex >= 0 then
  begin
    FEdit.Text  := FListBox.Items[FListBox.ItemIndex];
    ModalResult := mrOK;
  end;
end;

procedure TDsBrowseForm.BtnMembersClick(Sender: TObject);
var
  DSN:     string;
  R:       TZoweResult;
  Members: TStringList;
  MForm:   TMemberBrowseForm;
  Member:  string;
  SaveCap: string;
begin
  DSN := CurrentDSN;
  if DSN = '' then
  begin
    ShowMessage('Select or enter a dataset name first.');
    Exit;
  end;

  Members := TStringList.Create;
  try
    SaveCap := FBtnMembers.Caption;
    FBtnMembers.Caption  := 'Loading...';
    FBtnMembers.Enabled  := False;
    Application.ProcessMessages;
    try
      R := ZoweListMembers(DSN);
    finally
      FBtnMembers.Caption := SaveCap;
      FBtnMembers.Enabled := True;
    end;

    ParseMemberList(R.Output, Members);

    if Members.Count = 0 then
    begin
      ShowMessage(DSN + ' has no members or is not a PDS.');
      Exit;
    end;

    MForm := TMemberBrowseForm.CreateBrowser(Self, DSN, Members);
    try
      if MForm.ShowModal = mrOK then
      begin
        Member := MForm.SelectedMember;
        if Member <> '' then
          FEdit.Text := DSN + '(' + Member + ')';
      end;
    finally
      MForm.Free;
    end;
  finally
    Members.Free;
  end;
end;

procedure TDsBrowseForm.BtnOKClick(Sender: TObject);
begin
  if Trim(FEdit.Text) = '' then
    ShowMessage('Please select or type a dataset name.')
  else
    ModalResult := mrOK;
end;

function TDsBrowseForm.SelectedDataset: string;
begin
  Result := Trim(FEdit.Text);
end;

{ ------------------------------------------------------------------ }

function ShowDatasetBrowser(const ATitle, APrompt: string;
                            const Datasets: TStringList;
                            const AInitial: string;
                            out Selected: string): Boolean;
var
  F: TDsBrowseForm;
begin
  Result   := False;
  Selected := '';
  F := TDsBrowseForm.CreateBrowser(nil, ATitle, APrompt, Datasets, AInitial);
  try
    if F.ShowModal = mrOK then
    begin
      Selected := F.SelectedDataset;
      Result   := (Selected <> '');
    end;
  finally
    F.Free;
  end;
end;

function ShowMemberBrowser(const ADSN: string; out Selected: string): Boolean;
var
  R:       TZoweResult;
  Members: TStringList;
  MForm:   TMemberBrowseForm;
  Member:  string;
begin
  Result   := False;
  Selected := '';
  Members  := TStringList.Create;
  try
    Screen.Cursor := crHourGlass;
    try
      R := ZoweListMembers(ADSN);
    finally
      Screen.Cursor := crDefault;
    end;
    ParseMemberList(R.Output, Members);
    if Members.Count = 0 then Exit;
    MForm := TMemberBrowseForm.CreateBrowser(nil, ADSN, Members);
    try
      if MForm.ShowModal = mrOK then
      begin
        Member := MForm.SelectedMember;
        if Member <> '' then
        begin
          Selected := ADSN + '(' + Member + ')';
          Result   := True;
        end;
      end;
    finally
      MForm.Free;
    end;
  finally
    Members.Free;
  end;
end;

end.
