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

{ Load/save editor font from/to the same config file.
  Defaults: FontName = 'Monospace', FontSize = 11. }
procedure LoadEditorFont(out FontName: string; out FontSize: Integer);
procedure SaveEditorFont(const FontName: string; FontSize: Integer);

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

  CFG_SECTION_EDITOR  = 'Editor';
  CFG_KEY_FONT_NAME   = 'FontName';
  CFG_KEY_FONT_SIZE   = 'FontSize';
  DEFAULT_FONT_NAME   = 'Monospace';
  DEFAULT_FONT_SIZE   = 11;

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

{ ------------------------------------------------------------------ }
procedure LoadEditorFont(out FontName: string; out FontSize: Integer);
var
  Ini:  TIniFile;
  Path: string;
begin
  FontName := DEFAULT_FONT_NAME;
  FontSize := DEFAULT_FONT_SIZE;
  Path := GetConfigFilePath;
  if not FileExists(Path) then Exit;
  Ini := TIniFile.Create(Path);
  try
    FontName := Ini.ReadString (CFG_SECTION_EDITOR, CFG_KEY_FONT_NAME, DEFAULT_FONT_NAME);
    FontSize := Ini.ReadInteger(CFG_SECTION_EDITOR, CFG_KEY_FONT_SIZE, DEFAULT_FONT_SIZE);
    if FontName = '' then FontName := DEFAULT_FONT_NAME;
    if FontSize < 6   then FontSize := DEFAULT_FONT_SIZE;
  finally
    Ini.Free;
  end;
end;

{ ------------------------------------------------------------------ }
procedure SaveEditorFont(const FontName: string; FontSize: Integer);
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
    Ini.WriteString (CFG_SECTION_EDITOR, CFG_KEY_FONT_NAME, FontName);
    Ini.WriteInteger(CFG_SECTION_EDITOR, CFG_KEY_FONT_SIZE, FontSize);
  finally
    Ini.Free;
  end;
end;

end.
