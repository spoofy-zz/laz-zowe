unit uAllocForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs;

type
  TAllocForm = class(TForm)
    { Dataset identification }
    LblDatasetName: TLabel;
    EdtDatasetName: TEdit;
    LblDsType:      TLabel;
    CmbDsType:      TComboBox;

    { Section headers }
    LblRecAttr:  TLabel;
    LblSpaceHdr: TLabel;

    { Record attributes (left column) }
    LblRecfm:   TLabel;
    CmbRecfm:   TComboBox;
    LblLrecl:   TLabel;
    EdtLrecl:   TEdit;
    LblBlksize: TLabel;
    EdtBlksize: TEdit;

    { Space allocation (right column) }
    LblSpaceUnit: TLabel;
    CmbSpaceUnit: TComboBox;
    LblPrimary:   TLabel;
    EdtPrimary:   TEdit;
    LblSecondary: TLabel;
    EdtSecondary: TEdit;

    { Hint + buttons }
    LblHint:   TLabel;
    BtnOK:     TButton;
    BtnCancel: TButton;

    procedure FormCreate(Sender: TObject);
    procedure CmbRecfmChange(Sender: TObject);
    procedure BtnOKClick(Sender: TObject);
  end;

var
  AllocForm: TAllocForm;

implementation

{$R *.lfm}

procedure TAllocForm.FormCreate(Sender: TObject);
begin
  CmbDsType.Items.Add('Sequential (PS)');
  CmbDsType.Items.Add('Partitioned (PO)');
  CmbDsType.Items.Add('Partitioned Extended (PDSE)');
  CmbDsType.ItemIndex := 0;

  CmbRecfm.Items.Add('FB');
  CmbRecfm.Items.Add('FBA');
  CmbRecfm.Items.Add('VB');
  CmbRecfm.Items.Add('VBA');
  CmbRecfm.Items.Add('U');
  CmbRecfm.Items.Add('F');
  CmbRecfm.Items.Add('V');
  CmbRecfm.ItemIndex := 0;

  CmbSpaceUnit.Items.Add('TRK');
  CmbSpaceUnit.Items.Add('CYL');
  CmbSpaceUnit.Items.Add('BLK');
  CmbSpaceUnit.ItemIndex := 0;

  EdtLrecl.Text    := '80';
  EdtBlksize.Text  := '6160';
  EdtPrimary.Text  := '10';
  EdtSecondary.Text := '5';
end;

procedure TAllocForm.CmbRecfmChange(Sender: TObject);
var
  Recfm: string;
begin
  Recfm := CmbRecfm.Text;
  if (Recfm = 'VB') or (Recfm = 'VBA') or (Recfm = 'V') then
  begin
    EdtLrecl.Text   := '255';
    EdtBlksize.Text := '27998';
  end
  else if Recfm = 'U' then
  begin
    EdtLrecl.Text   := '0';
    EdtBlksize.Text := '6144';
  end
  else
  begin
    EdtLrecl.Text   := '80';
    EdtBlksize.Text := '6160';
  end;
end;

procedure TAllocForm.BtnOKClick(Sender: TObject);
var
  Dsn: string;
  Lrecl, Blksize, Primary, Secondary, Code: Integer;
begin
  Dsn := Trim(EdtDatasetName.Text);
  if Dsn = '' then
  begin
    ShowMessage('Please enter a dataset name.');
    EdtDatasetName.SetFocus;
    Exit;
  end;

  Val(EdtLrecl.Text, Lrecl, Code);
  if (Code <> 0) or (Lrecl < 0) or (Lrecl > 32760) then
  begin
    ShowMessage('LRECL must be a number between 0 and 32760.');
    EdtLrecl.SetFocus;
    Exit;
  end;

  Val(EdtBlksize.Text, Blksize, Code);
  if (Code <> 0) or (Blksize < 0) or (Blksize > 32760) then
  begin
    ShowMessage('Block size must be a number between 0 and 32760 (0 = system default).');
    EdtBlksize.SetFocus;
    Exit;
  end;

  Val(EdtPrimary.Text, Primary, Code);
  if (Code <> 0) or (Primary < 1) then
  begin
    ShowMessage('Primary space must be a positive number.');
    EdtPrimary.SetFocus;
    Exit;
  end;

  Val(EdtSecondary.Text, Secondary, Code);
  if (Code <> 0) or (Secondary < 0) then
  begin
    ShowMessage('Secondary space must be 0 or a positive number.');
    EdtSecondary.SetFocus;
    Exit;
  end;

  ModalResult := mrOK;
end;

end.
