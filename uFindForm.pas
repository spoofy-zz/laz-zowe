unit uFindForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, LCLType,
  SynEdit, SynEditTypes;

type
  TFindForm = class(TForm)
    FindLabel:    TLabel;
    ReplaceLabel: TLabel;
    StatusLabel:  TLabel;
    FindEdit:     TEdit;
    ReplaceEdit:  TEdit;
    CaseCB:       TCheckBox;
    WordCB:       TCheckBox;
    FindNextBtn:  TButton;
    ReplaceBtn:   TButton;
    ReplaceAllBtn: TButton;
    CloseBtn:     TButton;

    procedure FindNextBtnClick   (Sender: TObject);
    procedure ReplaceBtnClick    (Sender: TObject);
    procedure ReplaceAllBtnClick (Sender: TObject);
    procedure CloseBtnClick      (Sender: TObject);
    procedure EditKeyDown        (Sender: TObject; var Key: Word;
                                  Shift: TShiftState);
  private
    FSynEdit: TSynEdit;
    procedure DoSearch(AReplace, AReplaceAll: Boolean);
  public
    procedure Setup(ASynEdit: TSynEdit; const ALastSearch: string;
                    AMatchCase, AWholeWord: Boolean);
    function FindText:  string;
    function MatchCase: Boolean;
    function WholeWord: Boolean;
  end;

implementation

{$R *.lfm}

{ ------------------------------------------------------------------ }
procedure TFindForm.Setup(ASynEdit: TSynEdit; const ALastSearch: string;
                           AMatchCase, AWholeWord: Boolean);
begin
  FSynEdit       := ASynEdit;
  FindEdit.Text  := ALastSearch;
  CaseCB.Checked := AMatchCase;
  WordCB.Checked := AWholeWord;
  StatusLabel.Caption := '';
  FindEdit.SelectAll;
  ActiveControl := FindEdit;
end;

function TFindForm.FindText:  string;  begin Result := FindEdit.Text;  end;
function TFindForm.MatchCase: Boolean; begin Result := CaseCB.Checked; end;
function TFindForm.WholeWord: Boolean; begin Result := WordCB.Checked; end;

{ ------------------------------------------------------------------ }
procedure TFindForm.DoSearch(AReplace, AReplaceAll: Boolean);
var
  Opts:  TSynSearchOptions;
  Count: Integer;
begin
  if Trim(FindEdit.Text) = '' then Exit;
  Opts := [];
  if CaseCB.Checked then Include(Opts, ssoMatchCase);
  if WordCB.Checked then Include(Opts, ssoWholeWord);
  if AReplace then
  begin
    if AReplaceAll then
    begin
      Include(Opts, ssoReplaceAll);
      Include(Opts, ssoEntireScope);
    end
    else
      Include(Opts, ssoReplace);
  end;
  Count := FSynEdit.SearchReplace(FindEdit.Text, ReplaceEdit.Text, Opts);
  if Count = 0 then
    StatusLabel.Caption := '"' + FindEdit.Text + '" not found.'
  else if AReplaceAll then
    StatusLabel.Caption := IntToStr(Count) + ' replacement(s) made.'
  else
    StatusLabel.Caption := '';
end;

{ ------------------------------------------------------------------ }
procedure TFindForm.FindNextBtnClick   (Sender: TObject); begin DoSearch(False, False); end;
procedure TFindForm.ReplaceBtnClick    (Sender: TObject); begin DoSearch(True,  False); end;
procedure TFindForm.ReplaceAllBtnClick (Sender: TObject); begin DoSearch(True,  True);  end;
procedure TFindForm.CloseBtnClick      (Sender: TObject); begin Close; end;

procedure TFindForm.EditKeyDown(Sender: TObject; var Key: Word;
                                Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    DoSearch(False, False);
  end;
end;

end.
