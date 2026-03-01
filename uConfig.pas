unit uConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, IniFiles, Classes;

{ Load/save the active Zowe profile setting from/to the local config file.
  Returns True if the config file was found; False on first run
  (UseDefault = True, ProfileName = '' are returned as defaults). }
function  LoadZoweProfile(out UseDefault: Boolean; out ProfileName: string): Boolean;
procedure SaveZoweProfile(UseDefault: Boolean; const ProfileName: string);

{ Return a list of profile names found in ~/.zowe/zowe.config.json.
  Caller must free the returned TStringList. }
function GetAvailableProfiles: TStringList;

implementation

uses
  fpjson, jsonparser;

const
  CFG_SECTION         = 'Zowe';
  CFG_KEY_USE_DEFAULT = 'UseDefault';
  CFG_KEY_PROFILE     = 'Profile';

function GetConfigFilePath: string;
begin
  Result := GetUserDir + '.config' + PathDelim +
            'laz-zowe' + PathDelim + 'config.ini';
end;

{ ------------------------------------------------------------------ }
function LoadZoweProfile(out UseDefault: Boolean; out ProfileName: string): Boolean;
var
  Ini:  TIniFile;
  Path: string;
begin
  UseDefault  := True;
  ProfileName := '';
  Path := GetConfigFilePath;
  if not FileExists(Path) then
  begin
    Result := False;
    Exit;
  end;
  Ini := TIniFile.Create(Path);
  try
    UseDefault  := Ini.ReadBool  (CFG_SECTION, CFG_KEY_USE_DEFAULT, True);
    ProfileName := Ini.ReadString(CFG_SECTION, CFG_KEY_PROFILE,     '');
    Result := True;
  finally
    Ini.Free;
  end;
end;

{ ------------------------------------------------------------------ }
procedure SaveZoweProfile(UseDefault: Boolean; const ProfileName: string);
var
  Ini:  TIniFile;
  Dir:  string;
  Path: string;
begin
  Path := GetConfigFilePath;
  Dir  := ExtractFilePath(Path);
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Ini := TIniFile.Create(Path);
  try
    Ini.WriteBool  (CFG_SECTION, CFG_KEY_USE_DEFAULT, UseDefault);
    Ini.WriteString(CFG_SECTION, CFG_KEY_PROFILE,     ProfileName);
  finally
    Ini.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{ Parse top-level profile names from ~/.zowe/zowe.config.json        }
{ ------------------------------------------------------------------ }
function GetAvailableProfiles: TStringList;
var
  CfgPath:  string;
  FileText: TStringList;
  Root:     TJSONData;
  Node:     TJSONData;
  Profiles: TJSONObject;
  I:        Integer;
begin
  Result  := TStringList.Create;
  CfgPath := GetUserDir + '.zowe' + PathDelim + 'zowe.config.json';
  if not FileExists(CfgPath) then Exit;

  FileText := TStringList.Create;
  try
    FileText.LoadFromFile(CfgPath);
    try
      Root := GetJSON(FileText.Text);
      try
        if Root is TJSONObject then
        begin
          Node := TJSONObject(Root).Find('profiles');
          if (Node <> nil) and (Node is TJSONObject) then
          begin
            Profiles := TJSONObject(Node);
            for I := 0 to Profiles.Count - 1 do
              Result.Add(Profiles.Names[I]);
          end;
        end;
      finally
        Root.Free;
      end;
    except
      { JSON parse error – return empty list }
    end;
  finally
    FileText.Free;
  end;
end;

end.
