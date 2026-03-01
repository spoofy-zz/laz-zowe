unit uProfileForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs,
  uConfig;

type
  TProfileForm = class(TForm)
    LblDesc:     TLabel;
    RbDefault:   TRadioButton;
    RbNamed:     TRadioButton;
    EdtProfile:  TEdit;
    LblProfiles: TLabel;
    LstProfiles: TListBox;
    BtnRefresh:  TButton;
    BtnOK:       TButton;
    BtnCancel:   TButton;

    procedure FormCreate      (Sender: TObject);
    procedure RbDefaultClick  (Sender: TObject);
    procedure RbNamedClick    (Sender: TObject);
    procedure LstProfilesClick(Sender: TObject);
    procedure BtnRefreshClick (Sender: TObject);
    procedure BtnOKClick      (Sender: TObject);

  private
    procedure LoadProfileList;
    procedure UpdateControls;

  public
    { Call InitSettings before ShowModal; read UseDefault / ProfileName
      after a mrOK result. }
    UseDefault:  Boolean;
    ProfileName: string;
    procedure InitSettings(AUseDefault: Boolean; const AProfileName: string);
  end;

var
  ProfileForm: TProfileForm;

implementation

{$R *.lfm}

{ ==================================================================== }
procedure TProfileForm.FormCreate(Sender: TObject);
begin
  UseDefault  := True;
  ProfileName := '';
  LoadProfileList;
  UpdateControls;
end;

{ ==================================================================== }
procedure TProfileForm.InitSettings(AUseDefault: Boolean;
  const AProfileName: string);
begin
  UseDefault  := AUseDefault;
  ProfileName := AProfileName;
  RbDefault.Checked := AUseDefault;
  RbNamed.Checked   := not AUseDefault;
  EdtProfile.Text   := AProfileName;
  UpdateControls;
end;

{ ==================================================================== }
procedure TProfileForm.UpdateControls;
begin
  EdtProfile.Enabled  := RbNamed.Checked;
  LstProfiles.Enabled := RbNamed.Checked;
end;

{ ==================================================================== }
procedure TProfileForm.LoadProfileList;
var
  SL: TStringList;
  I:  Integer;
begin
  LstProfiles.Items.Clear;
  SL := GetAvailableProfiles;
  try
    for I := 0 to SL.Count - 1 do
      LstProfiles.Items.Add(SL[I]);
  finally
    SL.Free;
  end;
end;

{ ==================================================================== }
procedure TProfileForm.RbDefaultClick(Sender: TObject);
begin
  UpdateControls;
end;

procedure TProfileForm.RbNamedClick(Sender: TObject);
begin
  UpdateControls;
end;

{ ==================================================================== }
procedure TProfileForm.LstProfilesClick(Sender: TObject);
begin
  if LstProfiles.ItemIndex >= 0 then
  begin
    EdtProfile.Text   := LstProfiles.Items[LstProfiles.ItemIndex];
    RbNamed.Checked   := True;
    UpdateControls;
  end;
end;

{ ==================================================================== }
procedure TProfileForm.BtnRefreshClick(Sender: TObject);
begin
  LoadProfileList;
end;

{ ==================================================================== }
procedure TProfileForm.BtnOKClick(Sender: TObject);
begin
  UseDefault  := RbDefault.Checked;
  ProfileName := Trim(EdtProfile.Text);
  if (not UseDefault) and (ProfileName = '') then
  begin
    ShowMessage(
      'Please enter a profile name, or select "Use default Zowe profile".');
    Exit;
  end;
  ModalResult := mrOK;
end;

end.
