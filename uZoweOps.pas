unit uZoweOps;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  TZoweResult = record
    Success:  Boolean;
    Output:   string;
    ErrorMsg: string;
    ExitCode: Integer;
  end;

  TJobInfo = record
    JobName: string;
    JobID:   string;
    Owner:   string;
    Status:  string;
    RetCode: string;
  end;

  TJobInfoArray = array of TJobInfo;

{ Core runner }
function ZoweRunCommand(const Args: array of string): TZoweResult;

{ File / dataset operations }
function ZoweDownloadDataset(const Dataset, LocalFile: string): TZoweResult;
function ZoweUploadDataset(const LocalFile, Dataset: string): TZoweResult;

{ Job operations }
function ZoweSubmitLocalFile(const LocalFile: string): TZoweResult;
function ZoweListJobs(const OwnerFilter: string): TZoweResult;
function ZoweViewAllSpool(const JobID: string): TZoweResult;
function ZoweViewSpoolFile(const JobID: string; SpoolID: Integer): TZoweResult;
function ZoweListSpoolFiles(const JobID: string): TZoweResult;

{ Utilities }
function ZoweIsAvailable: Boolean;
{ Zowe CLI v3 wraps responses in an envelope with "success" and "data"
  fields. This helper returns the "data" portion as a JSON string, or
  the original text unchanged if it is already a bare array/object. }
function ZoweUnwrapData(const JsonText: string): string;
function ExtractJobID(const SubmitOutput: string): string;
procedure ParseJobList(const JsonText: string; out Jobs: TJobInfoArray);

implementation

uses
  fpjson, jsonparser;

{ ------------------------------------------------------------------ }
{ On macOS, .app bundles start with a minimal PATH that omits        }
{ /usr/local/bin, /opt/homebrew/bin, and nvm/fnm directories.       }
{ We run every zowe call through the user's login+interactive shell  }
{ so that ~/.bashrc / ~/.zshrc (where nvm/fnm initialise both        }
{ 'node' and 'zowe') are sourced before the command executes.       }
{ -i makes the shell source the rc file; without it only             }
{ ~/.bash_profile / ~/.zprofile would be read (-l alone).            }
{ ------------------------------------------------------------------ }
{$IFDEF DARWIN}
function ShellSingleQuote(const S: string): string;
begin
  { Wrap S in single quotes; escape any embedded single quote as '"'"' }
  Result := #39 + StringReplace(S, #39, #39 + #34 + #39 + #34 + #39,
                                 [rfReplaceAll]) + #39;
end;
{$ENDIF}

{ ------------------------------------------------------------------ }
{ Core process runner – polls stdout while running to avoid deadlock  }
{ ------------------------------------------------------------------ }
function ZoweRunCommand(const Args: array of string): TZoweResult;
const
  READ_BUF_SIZE = 4096;
var
  Proc:   TProcess;
  RawBuf: array[0..READ_BUF_SIZE - 1] of Byte;
  TmpStr: string;
  N:      LongInt;
  I:      Integer;
  {$IFDEF DARWIN}
  Cmd:   string;
  Shell: string;
  {$ENDIF}
begin
  Result.Success  := False;
  Result.Output   := '';
  Result.ErrorMsg := '';
  Result.ExitCode := -1;

  Proc := TProcess.Create(nil);
  try
    {$IFDEF DARWIN}
    { Run through the user's login+interactive shell so that nvm/fnm
      (and therefore both 'node' and 'zowe') are on PATH.
      -i  → sources ~/.bashrc / ~/.zshrc  (nvm lives here)
      -l  → sources ~/.bash_profile / ~/.zprofile
      -c  → execute the following command string }
    Cmd := 'zowe';
    for I := 0 to High(Args) do
      Cmd := Cmd + ' ' + ShellSingleQuote(Args[I]);
    Shell := GetEnvironmentVariable('SHELL');
    if Shell = '' then Shell := '/bin/bash';
    Proc.Executable := Shell;
    Proc.Parameters.Add('-ilc');
    Proc.Parameters.Add(Cmd);
    {$ELSE}
    Proc.Executable := 'zowe';
    for I := 0 to High(Args) do
      Proc.Parameters.Add(Args[I]);
    {$ENDIF}
    { Merge stderr into stdout so we only need to read one pipe }
    Proc.Options := [poUsePipes, poStderrToOutPut];

    try
      Proc.Execute;

      { Read while the process is running to prevent the pipe buffer filling }
      while Proc.Running do
      begin
        if Proc.Output.NumBytesAvailable > 0 then
        begin
          N := Proc.Output.Read(RawBuf[0], READ_BUF_SIZE);
          if N > 0 then
          begin
            SetLength(TmpStr, N);
            Move(RawBuf[0], TmpStr[1], N);
            Result.Output := Result.Output + TmpStr;
          end;
        end
        else
          Sleep(20);
      end;

      { Drain remaining bytes after the process exits }
      repeat
        N := Proc.Output.Read(RawBuf[0], READ_BUF_SIZE);
        if N > 0 then
        begin
          SetLength(TmpStr, N);
          Move(RawBuf[0], TmpStr[1], N);
          Result.Output := Result.Output + TmpStr;
        end;
      until N <= 0;

      Result.ExitCode := Proc.ExitCode;
      Result.Success  := (Proc.ExitCode = 0);
      if not Result.Success then
        Result.ErrorMsg := Result.Output;

    except
      on E: Exception do
        Result.ErrorMsg := 'Failed to execute zowe: ' + E.Message;
    end;
  finally
    Proc.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ Dataset operations                                                   }
{ ------------------------------------------------------------------ }
function ZoweDownloadDataset(const Dataset, LocalFile: string): TZoweResult;
begin
  Result := ZoweRunCommand(['zos-files', 'download', 'data-set',
                            Dataset, '--file', LocalFile]);
end;

function ZoweUploadDataset(const LocalFile, Dataset: string): TZoweResult;
begin
  Result := ZoweRunCommand(['zos-files', 'upload', 'file-to-data-set',
                            LocalFile, Dataset]);
end;

{ ------------------------------------------------------------------ }
{ Job operations                                                       }
{ ------------------------------------------------------------------ }
function ZoweSubmitLocalFile(const LocalFile: string): TZoweResult;
begin
  Result := ZoweRunCommand(['zos-jobs', 'submit', 'local-file',
                            LocalFile, '--response-format-json']);
end;

function ZoweListJobs(const OwnerFilter: string): TZoweResult;
begin
  Result := ZoweRunCommand(['zos-jobs', 'list', 'jobs',
                            '--owner', OwnerFilter,
                            '--response-format-json']);
end;

function ZoweViewAllSpool(const JobID: string): TZoweResult;
begin
  Result := ZoweRunCommand(['zos-jobs', 'view', 'all-spool-content', JobID]);
end;

function ZoweViewSpoolFile(const JobID: string; SpoolID: Integer): TZoweResult;
begin
  Result := ZoweRunCommand(['zos-jobs', 'view', 'spool-file-by-id',
                            JobID, IntToStr(SpoolID)]);
end;

function ZoweListSpoolFiles(const JobID: string): TZoweResult;
begin
  Result := ZoweRunCommand(['zos-jobs', 'list', 'spool-files-by-jobid',
                            JobID, '--response-format-json']);
end;

{ ------------------------------------------------------------------ }
{ Utilities                                                            }
{ ------------------------------------------------------------------ }
function ZoweIsAvailable: Boolean;
var
  R: TZoweResult;
begin
  R := ZoweRunCommand(['--version']);
  Result := R.Success;
end;

{ When the shell is launched with -i it may print noise to stderr
  (e.g. "bash: no job control in this shell") which is captured together
  with stdout via poStderrToOutPut.  This helper skips every byte before
  the first brace or bracket so the JSON parser only sees clean JSON. }
function StripShellNoise(const S: string): string;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if S[I] in ['{', '['] then
    begin
      Result := Copy(S, I, MaxInt);
      Exit;
    end;
  Result := S;
end;

{ Zowe CLI v3 wraps --response-format-json output in an envelope with
  "success", "exitCode", and "data" fields. This helper returns the
  "data" value as a JSON string. If the root is already an array it
  is returned unchanged. }
function ZoweUnwrapData(const JsonText: string): string;
var
  Root: TJSONData;
  Data: TJSONData;
begin
  Result := Trim(StripShellNoise(JsonText));
  if Result = '' then Exit;
  try
    Root := GetJSON(Result);
    try
      if Root is TJSONObject then
      begin
        Data := (Root as TJSONObject).Find('data');
        if Data <> nil then
          Result := Data.AsJSON;
      end;
      { If root is already TJSONArray, leave Result unchanged }
    finally
      Root.Free;
    end;
  except
    { On any parse error just return the original text }
  end;
end;

{ Extract jobid from a Zowe v3 JSON envelope or plain-text submit output }
function ExtractJobID(const SubmitOutput: string): string;
var
  DataJson: string;
  Root:     TJSONData;
  Obj:      TJSONObject;
  Lines:    TStringList;
  I:        Integer;
  L:        string;
  P:        Integer;
begin
  Result := '';
  if Trim(SubmitOutput) = '' then Exit;

  { Try JSON – strip shell noise, unwrap v3 envelope, look for "jobid" }
  try
    DataJson := ZoweUnwrapData(StripShellNoise(SubmitOutput));
    Root := GetJSON(DataJson);
    try
      if Root is TJSONObject then
      begin
        Obj    := Root as TJSONObject;
        Result := Obj.Get('jobid', '');
      end;
    finally
      Root.Free;
    end;
  except
    Result := '';
  end;

  { Plain-text fallback: look for a line starting with "jobid" }
  if Result = '' then
  begin
    Lines := TStringList.Create;
    try
      Lines.Text := SubmitOutput;
      for I := 0 to Lines.Count - 1 do
      begin
        L := LowerCase(Trim(Lines[I]));
        if Copy(L, 1, 5) = 'jobid' then
        begin
          P := Pos(':', Lines[I]);
          if P > 0 then
            Result := Trim(Copy(Lines[I], P + 1, MaxInt));
          Break;
        end;
      end;
    finally
      Lines.Free;
    end;
  end;
end;

{ Parse the job array from "zowe zos-jobs list jobs --response-format-json".
  Handles both a bare JSON array and the Zowe CLI v3 envelope. }
procedure ParseJobList(const JsonText: string; out Jobs: TJobInfoArray);
var
  DataJson: string;
  Root:     TJSONData;
  JArr:     TJSONArray;
  JObj:     TJSONObject;
  I:        Integer;
begin
  SetLength(Jobs, 0);
  if Trim(JsonText) = '' then Exit;

  DataJson := ZoweUnwrapData(JsonText);

  try
    Root := GetJSON(DataJson);
    try
      if not (Root is TJSONArray) then Exit;
      JArr := Root as TJSONArray;
      SetLength(Jobs, JArr.Count);
      for I := 0 to JArr.Count - 1 do
      begin
        if JArr.Items[I] is TJSONObject then
        begin
          JObj := JArr.Items[I] as TJSONObject;
          Jobs[I].JobName := JObj.Get('jobname', '');
          Jobs[I].JobID   := JObj.Get('jobid',   '');
          Jobs[I].Owner   := JObj.Get('owner',   '');
          Jobs[I].Status  := JObj.Get('status',  '');
          Jobs[I].RetCode := JObj.Get('retcode', '');
        end;
      end;
    finally
      Root.Free;
    end;
  except
    SetLength(Jobs, 0);
  end;
end;

end.
