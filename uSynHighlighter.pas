unit uSynHighlighter;

{$mode objfpc}{$H+}

{ ====================================================================
  IBM Mainframe Syntax Highlighters for SynEdit
  - TSynJCLHighlighter   : IBM MVS JCL (Job Control Language)
  - TSynCOBOLHighlighter : COBOL (fixed + free format)
  ==================================================================== }

interface

uses
  SysUtils, Classes, Math, Graphics, SynEditHighlighter;

{ ==================================================================== }
{  JCL Highlighter                                                      }
{ ==================================================================== }

type
  TJCLTokenKind = (
    jtkDefault,    { in-stream data / unknown               }
    jtkComment,    { //* comment cards                      }
    jtkSlashSlash, { the // prefix on a statement card      }
    jtkName,       { job/step/DD name after //              }
    jtkKeyword,    { JOB EXEC DD PROC PEND IF ELSE …       }
    jtkParam,      { parameter keywords: DISP= DSN= PGM= … }
    jtkString,     { 'single-quoted strings'                }
    jtkOperator    { = , ( )                                }
  );

  TSynJCLHighlighter = class(TSynCustomHighlighter)
  private
    FLine:      string;
    FLineLen:   Integer;
    FRun:       Integer;   { 1-based current position          }
    FTokenPos:  Integer;   { 0-based start of current token    }
    FKind:      TJCLTokenKind;
    FAtEol:     Boolean;
    FLineState: Integer;
    { 0 = not a JCL statement
      1 = just scanned //
      2 = just scanned the name
      3 = after name+space, looking for keyword
      4 = in operand field                          }

    FAttrDefault:    TSynHighlighterAttributes;
    FAttrComment:    TSynHighlighterAttributes;
    FAttrSlashSlash: TSynHighlighterAttributes;
    FAttrName:       TSynHighlighterAttributes;
    FAttrKeyword:    TSynHighlighterAttributes;
    FAttrParam:      TSynHighlighterAttributes;
    FAttrString:     TSynHighlighterAttributes;
    FAttrOperator:   TSynHighlighterAttributes;

    procedure ScanToken;
    function  IsJCLKeyword(const S: string): Boolean;
    function  IsJCLParam(const S: string): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    class function GetLanguageName: string; override;

    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
    function GetEol: Boolean; override;
    function GetToken: string; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    function GetTokenPos: Integer; override;
    procedure Next; override;
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;

    property AttrComment:    TSynHighlighterAttributes read FAttrComment;
    property AttrKeyword:    TSynHighlighterAttributes read FAttrKeyword;
    property AttrParam:      TSynHighlighterAttributes read FAttrParam;
    property AttrString:     TSynHighlighterAttributes read FAttrString;
    property AttrName:       TSynHighlighterAttributes read FAttrName;
    property AttrSlashSlash: TSynHighlighterAttributes read FAttrSlashSlash;
  end;

{ ==================================================================== }
{  COBOL Highlighter                                                    }
{ ==================================================================== }

type
  TCOBOLTokenKind = (
    ctkDefault,   { plain identifiers / data                }
    ctkComment,   { indicator col = * or /                  }
    ctkKeyword,   { reserved words                          }
    ctkDivision,  { DIVISION / SECTION markers              }
    ctkString,    { 'quoted' or "quoted" literals           }
    ctkNumber,    { numeric literals                        }
    ctkLevel,     { level numbers 01 02 … 77 88             }
    ctkPicture    { PIC / PICTURE clauses                   }
  );

  TSynCOBOLHighlighter = class(TSynCustomHighlighter)
  private
    FLine:     string;
    FLineLen:  Integer;
    FRun:      Integer;
    FTokenPos: Integer;
    FKind:     TCOBOLTokenKind;
    FAtEol:    Boolean;
    FIsComment: Boolean;   { whole line is a comment }

    FAttrDefault:  TSynHighlighterAttributes;
    FAttrComment:  TSynHighlighterAttributes;
    FAttrKeyword:  TSynHighlighterAttributes;
    FAttrDivision: TSynHighlighterAttributes;
    FAttrString:   TSynHighlighterAttributes;
    FAttrNumber:   TSynHighlighterAttributes;
    FAttrLevel:    TSynHighlighterAttributes;
    FAttrPicture:  TSynHighlighterAttributes;

    procedure ScanToken;
    function  IsCOBOLKeyword(const S: string): Boolean;
    function  IsDivisionWord(const S: string): Boolean;
    function  IsPictureWord(const S: string): Boolean;
    function  IsLevelNumber(const S: string): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    class function GetLanguageName: string; override;

    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
    function GetEol: Boolean; override;
    function GetToken: string; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    function GetTokenPos: Integer; override;
    procedure Next; override;
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;

    property AttrComment:  TSynHighlighterAttributes read FAttrComment;
    property AttrKeyword:  TSynHighlighterAttributes read FAttrKeyword;
    property AttrDivision: TSynHighlighterAttributes read FAttrDivision;
    property AttrString:   TSynHighlighterAttributes read FAttrString;
    property AttrNumber:   TSynHighlighterAttributes read FAttrNumber;
    property AttrLevel:    TSynHighlighterAttributes read FAttrLevel;
    property AttrPicture:  TSynHighlighterAttributes read FAttrPicture;
  end;

{ Helper: detect syntax type from filename and first few content lines }
type
  TSyntaxType = (synNone, synJCL, synCOBOL);

function DetectSyntaxFromFile(const FileName: string;
                              const FirstLines: TStrings): TSyntaxType;

implementation

{ -------------------------------------------------------------------- }
{  JCL keyword / parameter tables                                       }
{ -------------------------------------------------------------------- }

const
  JCL_KEYWORDS: array[0..12] of string = (
    'JOB', 'EXEC', 'DD', 'PROC', 'PEND',
    'IF', 'THEN', 'ELSE', 'ENDIF', 'SET',
    'INCLUDE', 'JCLLIB', 'NOTIFY'
  );

  JCL_PARAMS: array[0..31] of string = (
    'DISP', 'DSN', 'DSNAME', 'VOL', 'VOLUME', 'UNIT',
    'SPACE', 'DCB', 'LRECL', 'BLKSIZE', 'RECFM', 'DSORG',
    'PGM', 'PROC', 'PARM', 'REGION', 'TIME', 'NOTIFY',
    'CLASS', 'MSGCLASS', 'MSGLEVEL', 'PRTY', 'RESTART',
    'COND', 'STEPLIB', 'JOBLIB', 'SYSOUT', 'SYSPRINT',
    'SYSIN', 'PATHMODE', 'PATHDISP', 'PATH'
  );

{ -------------------------------------------------------------------- }
{  COBOL keyword tables                                                 }
{ -------------------------------------------------------------------- }

const
  COBOL_DIVISIONS: array[0..7] of string = (
    'IDENTIFICATION', 'ENVIRONMENT', 'DATA', 'PROCEDURE',
    'DIVISION', 'SECTION', 'PROGRAM-ID', 'END'
  );

  COBOL_KEYWORDS: array[0..108] of string = (
    { Procedure verbs }
    'ACCEPT', 'ADD', 'CALL', 'CANCEL', 'CLOSE', 'COMPUTE',
    'CONTINUE', 'DELETE', 'DISPLAY', 'DIVIDE', 'EVALUATE',
    'EXIT', 'GO', 'GOBACK', 'IF', 'INITIALIZE', 'INSPECT',
    'MERGE', 'MOVE', 'MULTIPLY', 'OPEN', 'PERFORM', 'READ',
    'RELEASE', 'RETURN', 'REWRITE', 'SEARCH', 'SET', 'SORT',
    'START', 'STOP', 'STRING', 'SUBTRACT', 'UNSTRING', 'WRITE',
    { Scope terminators }
    'END-ADD', 'END-CALL', 'END-COMPUTE', 'END-DELETE',
    'END-DIVIDE', 'END-EVALUATE', 'END-IF', 'END-MULTIPLY',
    'END-PERFORM', 'END-READ', 'END-RETURN', 'END-REWRITE',
    'END-SEARCH', 'END-START', 'END-STRING', 'END-SUBTRACT',
    'END-UNSTRING', 'END-WRITE',
    { Clauses and modifiers }
    'AFTER', 'ALL', 'AND', 'AT', 'BEFORE', 'BY',
    'CORRESPONDING', 'ELSE', 'END', 'ERROR', 'FROM',
    'GIVING', 'IN', 'INTO', 'IS', 'JUST', 'JUSTIFIED',
    'NOT', 'OF', 'ON', 'OR', 'OTHER', 'OVERFLOW',
    'REMAINDER', 'REPLACING', 'RETURNING', 'ROUNDING',
    'SIZE', 'THAN', 'THEN', 'THROUGH', 'THRU', 'TO',
    'UNTIL', 'UPON', 'USING', 'VARYING', 'WHEN', 'WITH',
    { Data / environment }
    'FILE', 'FD', 'SD', 'SELECT', 'ASSIGN', 'SEQUENTIAL',
    'RANDOM', 'DYNAMIC', 'OPTIONAL', 'RECORDING', 'MODE',
    'LABEL', 'RECORDS', 'STANDARD', 'OMITTED', 'INDEXED',
    'KEY'
  );

  COBOL_PICTURE_WORDS: array[0..3] of string = (
    'PIC', 'PICTURE', 'REDEFINES', 'OCCURS'
  );

{ ==================================================================== }
{  Helper                                                               }
{ ==================================================================== }

function DetectSyntaxFromFile(const FileName: string;
                              const FirstLines: TStrings): TSyntaxType;
var
  Ext, DS, Line: string;
  I: Integer;
begin
  Result := synNone;
  Ext := LowerCase(ExtractFileExt(FileName));

  { --- by file extension --- }
  if (Ext = '.jcl') or (Ext = '.proc') or (Ext = '.jclproc') then
  begin
    Result := synJCL;
    Exit;
  end;
  if (Ext = '.cbl') or (Ext = '.cob') or (Ext = '.cpy') or
     (Ext = '.pco') or (Ext = '.cobol') then
  begin
    Result := synCOBOL;
    Exit;
  end;

  { --- by dataset name (FileName is used as the dataset name too) --- }
  DS := UpperCase(FileName);
  if (Pos('.JCL', DS) > 0) or (Pos('.PROC', DS) > 0) or
     (Pos('.JCLLIB', DS) > 0) then
  begin
    Result := synJCL;
    Exit;
  end;
  if (Pos('.CBL', DS) > 0) or (Pos('.COB', DS) > 0) or
     (Pos('.COBOL', DS) > 0) then
  begin
    Result := synCOBOL;
    Exit;
  end;

  { --- by content: scan first 10 lines --- }
  if FirstLines = nil then Exit;
  for I := 0 to Min(9, FirstLines.Count - 1) do
  begin
    Line := FirstLines[I];
    if Length(Line) < 2 then Continue;

    { JCL: lines starting with // }
    if (Line[1] = '/') and (Line[2] = '/') then
    begin
      Result := synJCL;
      Exit;
    end;

    { COBOL: IDENTIFICATION DIVISION or PROCEDURE DIVISION }
    if (Pos('IDENTIFICATION DIVISION', UpperCase(Line)) > 0) or
       (Pos('PROCEDURE DIVISION',      UpperCase(Line)) > 0) or
       (Pos('WORKING-STORAGE SECTION', UpperCase(Line)) > 0) then
    begin
      Result := synCOBOL;
      Exit;
    end;
  end;
end;

{ ==================================================================== }
{  TSynJCLHighlighter – implementation                                  }
{ ==================================================================== }

class function TSynJCLHighlighter.GetLanguageName: string;
begin
  Result := 'IBM MVS JCL';
end;

constructor TSynJCLHighlighter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FAttrDefault := TSynHighlighterAttributes.Create('Default', 'Default text');
  FAttrDefault.Foreground := $00C8C8C8;  { light gray }
  AddAttribute(FAttrDefault);

  FAttrComment := TSynHighlighterAttributes.Create('Comment', 'Comment (//*...)');
  FAttrComment.Foreground := clLime;
  FAttrComment.Style      := [fsItalic];
  AddAttribute(FAttrComment);

  FAttrSlashSlash := TSynHighlighterAttributes.Create('StatPrefix', '// statement prefix');
  FAttrSlashSlash.Foreground := clWhite;
  FAttrSlashSlash.Style      := [fsBold];
  AddAttribute(FAttrSlashSlash);

  FAttrName := TSynHighlighterAttributes.Create('Name', 'Job / step / DD name');
  FAttrName.Foreground := clAqua;
  AddAttribute(FAttrName);

  FAttrKeyword := TSynHighlighterAttributes.Create('Keyword', 'JCL keywords (JOB EXEC DD …)');
  FAttrKeyword.Foreground := clYellow;
  FAttrKeyword.Style      := [fsBold];
  AddAttribute(FAttrKeyword);

  FAttrParam := TSynHighlighterAttributes.Create('Param', 'Parameter keywords (DISP= DSN= …)');
  FAttrParam.Foreground := $0066FFFF;   { bright orange-yellow }
  AddAttribute(FAttrParam);

  FAttrString := TSynHighlighterAttributes.Create('String', 'Quoted string literals');
  FAttrString.Foreground := $00FF88FF;  { bright magenta/pink }
  AddAttribute(FAttrString);

  FAttrOperator := TSynHighlighterAttributes.Create('Operator', 'Operators (= , ( ))');
  FAttrOperator.Foreground := clSilver;
  AddAttribute(FAttrOperator);

  SetAttributesOnChange(@DefHighlightChange);
end;

destructor TSynJCLHighlighter.Destroy;
begin
  { Attributes are freed by the parent class }
  inherited;
end;

function TSynJCLHighlighter.IsJCLKeyword(const S: string): Boolean;
var
  I: Integer;
begin
  for I := Low(JCL_KEYWORDS) to High(JCL_KEYWORDS) do
    if JCL_KEYWORDS[I] = S then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

function TSynJCLHighlighter.IsJCLParam(const S: string): Boolean;
var
  I: Integer;
begin
  for I := Low(JCL_PARAMS) to High(JCL_PARAMS) do
    if JCL_PARAMS[I] = S then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

procedure TSynJCLHighlighter.ScanToken;
var
  WordStart: Integer;
  Word:      string;
begin
  case FLine[FRun] of

    '/':
    begin
      if (FLineState = 0) and (FRun = 1) and
         (FRun < FLineLen) and (FLine[FRun + 1] = '/') then
      begin
        { Opening // of a JCL statement card }
        Inc(FRun, 2);
        FKind := jtkSlashSlash;
        FLineState := 1;
        { Peek: if next char is * this is a comment card }
        if (FRun <= FLineLen) and (FLine[FRun] = '*') then
        begin
          { Re-colour the // as comment too and consume whole line }
          FKind      := jtkComment;
          FRun       := FLineLen + 1;
          FLineState := 0;
        end;
      end
      else
      begin
        Inc(FRun);
        FKind := jtkDefault;
      end;
    end;

    '''':  { single-quoted string }
    begin
      Inc(FRun);
      while FRun <= FLineLen do
      begin
        if FLine[FRun] = '''' then
        begin
          Inc(FRun);
          if (FRun <= FLineLen) and (FLine[FRun] = '''') then
            Inc(FRun)   { escaped quote }
          else
            Break;
        end
        else
          Inc(FRun);
      end;
      FKind := jtkString;
    end;

    '=', ',', '(', ')':
    begin
      Inc(FRun);
      FKind := jtkOperator;
    end;

    ' ', #9:
    begin
      while (FRun <= FLineLen) and (FLine[FRun] in [' ', #9]) do
        Inc(FRun);
      FKind := jtkDefault;
      { Advance state: after // name → look for keyword }
      if (FLineState = 1) or (FLineState = 2) then
        FLineState := 3;
    end;

    'A'..'Z', 'a'..'z', '0'..'9',
    '@', '#', '$', '-', '_', '.':
    begin
      WordStart := FRun;
      while (FRun <= FLineLen) and
            (FLine[FRun] in ['A'..'Z', 'a'..'z', '0'..'9',
                              '@', '#', '$', '-', '_', '.']) do
        Inc(FRun);
      Word := UpperCase(Copy(FLine, WordStart, FRun - WordStart));

      case FLineState of
        0: FKind := jtkDefault;
        1: begin
             FKind      := jtkName;
             FLineState := 2;
           end;
        3: begin
             if IsJCLKeyword(Word) then
             begin
               FKind      := jtkKeyword;
               FLineState := 4;
             end
             else
             begin
               FKind      := jtkDefault;
               FLineState := 4;
             end;
           end;
        else  { 2, 4 }
          begin
            { In operand field: check for trailing '=' to identify param name }
            if (FRun <= FLineLen) and (FLine[FRun] = '=') then
              FKind := jtkParam
            else if IsJCLParam(Word) then
              FKind := jtkParam
            else
              FKind := jtkDefault;
          end;
      end;
    end;

    else
    begin
      Inc(FRun);
      FKind := jtkDefault;
    end;
  end;
end;

procedure TSynJCLHighlighter.SetLine(const NewValue: string; LineNumber: Integer);
begin
  inherited;
  FLine     := NewValue;
  FLineLen  := Length(FLine);
  FRun      := 1;
  FAtEol    := False;
  FLineState := 0;
  Next;
end;

procedure TSynJCLHighlighter.Next;
begin
  FTokenPos := FRun - 1;
  if FRun > FLineLen then
  begin
    FAtEol := True;
    FKind  := jtkDefault;
    Inc(FRun);
    Exit;
  end;
  FAtEol := False;
  ScanToken;
end;

function TSynJCLHighlighter.GetEol: Boolean;
begin
  Result := FAtEol;
end;

function TSynJCLHighlighter.GetToken: string;
begin
  Result := Copy(FLine, FTokenPos + 1, FRun - FTokenPos - 1);
end;

procedure TSynJCLHighlighter.GetTokenEx(out TokenStart: PChar;
  out TokenLength: Integer);
begin
  TokenLength := FRun - FTokenPos - 1;
  TokenStart  := PChar(FLine) + FTokenPos;
end;

function TSynJCLHighlighter.GetTokenPos: Integer;
begin
  Result := FTokenPos;
end;

function TSynJCLHighlighter.GetTokenKind: Integer;
begin
  Result := Ord(FKind);
end;

function TSynJCLHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
begin
  case FKind of
    jtkComment:    Result := FAttrComment;
    jtkSlashSlash: Result := FAttrSlashSlash;
    jtkName:       Result := FAttrName;
    jtkKeyword:    Result := FAttrKeyword;
    jtkParam:      Result := FAttrParam;
    jtkString:     Result := FAttrString;
    jtkOperator:   Result := FAttrOperator;
    else           Result := FAttrDefault;
  end;
end;

function TSynJCLHighlighter.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT:    Result := FAttrComment;
    SYN_ATTR_IDENTIFIER: Result := FAttrName;
    SYN_ATTR_KEYWORD:    Result := FAttrKeyword;
    SYN_ATTR_STRING:     Result := FAttrString;
    SYN_ATTR_WHITESPACE: Result := FAttrDefault;
    else                 Result := FAttrDefault;
  end;
end;

{ ==================================================================== }
{  TSynCOBOLHighlighter – implementation                                }
{ ==================================================================== }

class function TSynCOBOLHighlighter.GetLanguageName: string;
begin
  Result := 'IBM COBOL';
end;

constructor TSynCOBOLHighlighter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FAttrDefault := TSynHighlighterAttributes.Create('Default', 'Default text');
  FAttrDefault.Foreground := $00C8C8C8;
  AddAttribute(FAttrDefault);

  FAttrComment := TSynHighlighterAttributes.Create('Comment', 'Comment (* in col 7)');
  FAttrComment.Foreground := clLime;
  FAttrComment.Style      := [fsItalic];
  AddAttribute(FAttrComment);

  FAttrKeyword := TSynHighlighterAttributes.Create('Keyword', 'Reserved words');
  FAttrKeyword.Foreground := clYellow;
  FAttrKeyword.Style      := [fsBold];
  AddAttribute(FAttrKeyword);

  FAttrDivision := TSynHighlighterAttributes.Create('Division', 'DIVISION / SECTION headers');
  FAttrDivision.Foreground := $00FF9966;  { bright blue-white }
  FAttrDivision.Style      := [fsBold];
  AddAttribute(FAttrDivision);

  FAttrString := TSynHighlighterAttributes.Create('String', 'String literals');
  FAttrString.Foreground := $00FF88FF;
  AddAttribute(FAttrString);

  FAttrNumber := TSynHighlighterAttributes.Create('Number', 'Numeric literals');
  FAttrNumber.Foreground := clAqua;
  AddAttribute(FAttrNumber);

  FAttrLevel := TSynHighlighterAttributes.Create('Level', 'Level numbers (01 77 88 …)');
  FAttrLevel.Foreground := $0066FFFF;
  FAttrLevel.Style      := [fsBold];
  AddAttribute(FAttrLevel);

  FAttrPicture := TSynHighlighterAttributes.Create('Picture', 'PIC / PICTURE clause');
  FAttrPicture.Foreground := $00AAFFAA;  { soft green }
  AddAttribute(FAttrPicture);

  SetAttributesOnChange(@DefHighlightChange);
end;

destructor TSynCOBOLHighlighter.Destroy;
begin
  inherited;
end;

function TSynCOBOLHighlighter.IsCOBOLKeyword(const S: string): Boolean;
var
  I: Integer;
begin
  for I := Low(COBOL_KEYWORDS) to High(COBOL_KEYWORDS) do
    if COBOL_KEYWORDS[I] = S then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

function TSynCOBOLHighlighter.IsDivisionWord(const S: string): Boolean;
var
  I: Integer;
begin
  for I := Low(COBOL_DIVISIONS) to High(COBOL_DIVISIONS) do
    if COBOL_DIVISIONS[I] = S then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

function TSynCOBOLHighlighter.IsPictureWord(const S: string): Boolean;
var
  I: Integer;
begin
  for I := Low(COBOL_PICTURE_WORDS) to High(COBOL_PICTURE_WORDS) do
    if COBOL_PICTURE_WORDS[I] = S then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

function TSynCOBOLHighlighter.IsLevelNumber(const S: string): Boolean;
var
  N: Integer;
  E: Integer;
begin
  Val(S, N, E);
  if E <> 0 then
  begin
    Result := False;
    Exit;
  end;
  Result := ((N >= 1) and (N <= 49)) or (N = 66) or (N = 77) or (N = 88);
end;

procedure TSynCOBOLHighlighter.ScanToken;
var
  WordStart: Integer;
  Word:      string;
  QChar:     Char;
begin
  { If the entire line is a comment, consume the rest }
  if FIsComment then
  begin
    FKind := ctkComment;
    FRun  := FLineLen + 1;
    Exit;
  end;

  case FLine[FRun] of

    '''', '"':
    begin
      { String literal }
      QChar := FLine[FRun];
      Inc(FRun);
      while FRun <= FLineLen do
      begin
        if FLine[FRun] = QChar then
        begin
          Inc(FRun);
          Break;
        end;
        Inc(FRun);
      end;
      FKind := ctkString;
    end;

    '0'..'9':
    begin
      while (FRun <= FLineLen) and
            (FLine[FRun] in ['0'..'9', '.', '+', '-', 'E', 'e']) do
        Inc(FRun);
      FKind := ctkNumber;
    end;

    ' ', #9:
    begin
      while (FRun <= FLineLen) and (FLine[FRun] in [' ', #9]) do
        Inc(FRun);
      FKind := ctkDefault;
    end;

    'A'..'Z', 'a'..'z', '-', '_':
    begin
      WordStart := FRun;
      while (FRun <= FLineLen) and
            (FLine[FRun] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']) do
        Inc(FRun);
      Word := UpperCase(Copy(FLine, WordStart, FRun - WordStart));

      if IsDivisionWord(Word) then
        FKind := ctkDivision
      else if IsPictureWord(Word) then
        FKind := ctkPicture
      else if IsCOBOLKeyword(Word) then
        FKind := ctkKeyword
      else if IsLevelNumber(Word) then
        FKind := ctkLevel
      else
        FKind := ctkDefault;
    end;

    else
    begin
      Inc(FRun);
      FKind := ctkDefault;
    end;
  end;
end;

procedure TSynCOBOLHighlighter.SetLine(const NewValue: string; LineNumber: Integer);
var
  IndChar: Char;
begin
  inherited;
  FLine    := NewValue;
  FLineLen := Length(FLine);
  FRun     := 1;
  FAtEol   := False;

  { Detect comment lines.
    Fixed-format COBOL: col 7 is the indicator area.
    If the line is shorter than 7 chars or col 7 = '*' or '/' → comment.
    Free-format COBOL: lines starting with '*>' are comments.
    We support both. }
  FIsComment := False;
  if FLineLen = 0 then
    { blank line, not a comment }
  else if (FLineLen >= 7) and (FLine[7] in ['*', '/']) then
    FIsComment := True
  else if (FLineLen >= 2) and (FLine[1] = '*') and (FLine[2] = '>') then
    FIsComment := True;

  Next;
end;

procedure TSynCOBOLHighlighter.Next;
begin
  FTokenPos := FRun - 1;
  if FRun > FLineLen then
  begin
    FAtEol := True;
    FKind  := ctkDefault;
    Inc(FRun);
    Exit;
  end;
  FAtEol := False;
  ScanToken;
end;

function TSynCOBOLHighlighter.GetEol: Boolean;
begin
  Result := FAtEol;
end;

function TSynCOBOLHighlighter.GetToken: string;
begin
  Result := Copy(FLine, FTokenPos + 1, FRun - FTokenPos - 1);
end;

procedure TSynCOBOLHighlighter.GetTokenEx(out TokenStart: PChar;
  out TokenLength: Integer);
begin
  TokenLength := FRun - FTokenPos - 1;
  TokenStart  := PChar(FLine) + FTokenPos;
end;

function TSynCOBOLHighlighter.GetTokenPos: Integer;
begin
  Result := FTokenPos;
end;

function TSynCOBOLHighlighter.GetTokenKind: Integer;
begin
  Result := Ord(FKind);
end;

function TSynCOBOLHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
begin
  case FKind of
    ctkComment:  Result := FAttrComment;
    ctkKeyword:  Result := FAttrKeyword;
    ctkDivision: Result := FAttrDivision;
    ctkString:   Result := FAttrString;
    ctkNumber:   Result := FAttrNumber;
    ctkLevel:    Result := FAttrLevel;
    ctkPicture:  Result := FAttrPicture;
    else         Result := FAttrDefault;
  end;
end;

function TSynCOBOLHighlighter.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT:    Result := FAttrComment;
    SYN_ATTR_KEYWORD:    Result := FAttrKeyword;
    SYN_ATTR_STRING:     Result := FAttrString;
    SYN_ATTR_WHITESPACE: Result := FAttrDefault;
    else                 Result := FAttrDefault;
  end;
end;

end.
