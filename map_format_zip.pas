{ This file is a part of Map editor for VCMI project

  Copyright (C) 2013-2016 Alexander Shishkin alexvins@users.sourceforge.net

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}


{
  Multiple JSON files in zip archive format
}

unit map_format_zip;

{$I compilersetup.inc}

interface

uses
  Classes, SysUtils, contnrs, map, map_format, terrain,
  vcmi_json, fpjson, lists_manager, map_format_json,
  editor_consts, zipper;

type

  { TMapReaderZIP }

  TMapReaderZIP = class(TMapReaderJson, IMapReader)
  private
    FUnZipper: TUnZipper;
    FInStream:TStream;
    FFreeList: TFPObjectList;

    FJsonBuffer: TStringList;

    FHeaderJson, FTemplatesJson, FObjectsJson: TJSONData;

    procedure UnZipperOnOpenInputStream(Sender: TObject; var AStream: TStream);
    procedure UnZipperOnCloseInputStream(Sender: TObject; var AStream: TStream);

    procedure UnZipperOnCreateStream(Sender: TObject; var AStream: TStream; AItem : TFullZipFileEntry);
    procedure UnZipperOnDoneStream(Sender: TObject; var AStream: TStream; AItem : TFullZipFileEntry);

    procedure CheckArchive(ARequiredFiles: array of string);

  public
    constructor Create(AMapEnv: TMapEnvironment); override;
    destructor Destroy; override;
    function Read(AStream: TStream): TVCMIMap;
  end;

  { TMapWriterZIP }

  TMapWriterZIP = class(TMapWriterJson, IMapWriter)
  private
    FZipper: TZipper;
    FFreeList: TFPObjectList;
    procedure WriteHeader(AMap: TVCMIMap);
    procedure WriteObjects(AMap: TVCMIMap);
    procedure WriteTerrain(AMap: TVCMIMap);

    procedure AddArchiveEntry(var AData: TJSONData; AFilename: AnsiString);
  public
    constructor Create(AMapEnv: TMapEnvironment); override;
    destructor Destroy; override;
    procedure Write(AStream: TStream; AMap: TVCMIMap);
  end;

implementation

uses LazLoggerBase;

const
  HEADER_FILENAME = 'header.json';
  TEMPLATES_FILENAME = 'templates.json';
  OBJECTS_FILENAME = 'objects.json';

{ TMapReaderZIP }

procedure TMapReaderZIP.UnZipperOnOpenInputStream(Sender: TObject; var AStream: TStream);
begin
  AStream := FInStream;
end;

procedure TMapReaderZIP.UnZipperOnCloseInputStream(Sender: TObject;
  var AStream: TStream);
begin
  AStream := nil;
end;

procedure TMapReaderZIP.UnZipperOnCreateStream(Sender: TObject;
  var AStream: TStream; AItem: TFullZipFileEntry);
begin
  AStream := TMemoryStream.Create;
end;

procedure TMapReaderZIP.UnZipperOnDoneStream(Sender: TObject;
  var AStream: TStream; AItem: TFullZipFileEntry);
var
  tmp: TJSONData;
  ArchiveFileName, ext: String;
begin

  ArchiveFileName := trim(LowerCase(AItem.ArchiveFileName));

  case ArchiveFileName of
    HEADER_FILENAME:
    begin
      FHeaderJson := FDestreamer.JSONStreamToJson(AStream);
      FFreeList.Add(FHeaderJson);
    end;
    TEMPLATES_FILENAME:
    begin
      FTemplatesJson := FDestreamer.JSONStreamToJson(AStream);
      FFreeList.Add(FTemplatesJson);
    end;
    OBJECTS_FILENAME:
    begin
      FObjectsJson := FDestreamer.JSONStreamToJson(AStream);
      FFreeList.Add(FObjectsJson);
    end;
  else
    begin
      ext := ExtractFileExt(ArchiveFileName);

      if ext = '.json' then
      begin
        tmp := FDestreamer.JSONStreamToJson(AStream);
        FJsonBuffer.AddObject(ArchiveFileName, tmp);
        FFreeList.Add(tmp);
      end
      else
      begin
         DebugLn('Unknown file in map archive ',AItem.ArchiveFileName);
      end;
    end;
  end;

  AStream.Free;
end;

procedure TMapReaderZIP.CheckArchive(ARequiredFiles: array of string);
var
  f: String;
  i: Integer;
  found: Boolean;
begin
  for f in ARequiredFiles do
  begin
    found := false;
    for i := 0 to FUnZipper.Entries.Count - 1 do
    begin
      if FUnZipper.Entries.FullEntries[i].ArchiveFileName = f then
      begin
        found := true;
        Break;
      end;
    end;
    if not found then
    begin
      raise Exception.Create('Invalid map archive. Required file '+f+' not found');
    end;
  end;
end;

constructor TMapReaderZIP.Create(AMapEnv: TMapEnvironment);
begin
  inherited Create(AMapEnv);
  FUnZipper := TUnZipper.Create;
  FUnZipper.OnOpenInputStream:=@UnZipperOnOpenInputStream;
  FUnZipper.OnCloseInputStream:=@UnZipperOnCloseInputStream;
  FUnZipper.OnCreateStream := @UnZipperOnCreateStream;
  FUnZipper.OnDoneStream := @UnZipperOnDoneStream;

  FFreeList := TFPObjectList.Create(true);
  FJsonBuffer := TStringList.Create;
  FJsonBuffer.Sorted:=true;
  FJsonBuffer.Duplicates:=dupError;
end;

destructor TMapReaderZIP.Destroy;
begin
  FJsonBuffer.Free;
  FFreeList.Free;
  FUnZipper.Free;
  inherited Destroy;
end;

function TMapReaderZIP.Read(AStream: TStream): TVCMIMap;
var
  map_o: TJSONObject;
  i: Integer;
  level: TMapLevel;

  buffer: TJSONData;
  terrain_file_name: String;
  idx: Integer;
begin
  FInStream := AStream;
  FUnZipper.Examine;

  CheckArchive([HEADER_FILENAME, OBJECTS_FILENAME]);

  FUnZipper.UnZipAllFiles;

  map_o := FHeaderJson as TJSONObject;

  Result := TVCMIMap.CreateEmpty(FMapEnv);

  FDestreamer.JSONToObjectEx(map_o, Result);

  FDestreamer.JSONToCollection(FObjectsJson,Result.Objects);

  for i := 0 to Result.MapLevels.Count - 1 do
  begin
    level := Result.MapLevels[i];

    terrain_file_name := Trim(LowerCase(level.Identifier+'_terrain.json'));

    if(terrain_file_name = '') then
      raise Exception.CreateFmt('Level %d: terrain filename empty',[i]);

    idx := FJsonBuffer.IndexOf(terrain_file_name);

    if idx < 0 then
      raise Exception.CreateFmt('Level %d: terrain file %s missing ',[i, terrain_file_name]);

    buffer := FJsonBuffer.Objects[idx] as TJSONData;

    DeStreamTilesLevel(buffer as TJSONArray, Result, i);
  end;

  FJsonBuffer.Clear;
  FFreeList.Clear;
  Result.Loaded;
end;

{ TMapWriterZIP }

procedure TMapWriterZIP.WriteHeader(AMap: TVCMIMap);
var
  header_data: TJSONData;
begin
  header_data := FStreamer.ObjectToJsonEx(AMap);
  (header_data as TJSONObject).Integers['versionMajor'] := MAP_FORMAT_MAJOR;
  (header_data as TJSONObject).Integers['versionMinor'] := MAP_FORMAT_MINOR;
  AddArchiveEntry( header_data, HEADER_FILENAME);
end;

procedure TMapWriterZIP.WriteObjects(AMap: TVCMIMap);
var
  objects_data: TJSONData;
begin
  objects_data :=  FStreamer.StreamCollection(AMap.Objects);
  AddArchiveEntry(objects_data,OBJECTS_FILENAME);
end;

procedure TMapWriterZIP.WriteTerrain(AMap: TVCMIMap);
var
  i: Integer;
  Stream: TMemoryStream;
begin
  for i := 0 to AMap.MapLevels.Count - 1 do
  begin
    Stream := TMemoryStream.Create();
    StreamTilesLevel(Stream, AMap, i);
    Stream.Seek(0, soBeginning);
    FZipper.Entries.AddFileEntry(Stream, AMap.MapLevels[i].Identifier + '_terrain.json');
    FFreeList.Add(Stream);
  end;
end;

procedure TMapWriterZIP.AddArchiveEntry(var AData: TJSONData;
  AFilename: AnsiString);
var
  json_text: TJSONStringType;
  Stream: TStringStream;
begin
  json_text := AData.FormatJSON([foUseTabchar], 1);

  Stream := TStringStream.Create(json_text);

  Stream.Seek(0, soBeginning);
  FZipper.Entries.AddFileEntry(Stream, AFilename);

  FFreeList.Add(Stream);

  FreeAndNil(AData);
end;

constructor TMapWriterZIP.Create(AMapEnv: TMapEnvironment);
begin
  inherited Create(AMapEnv);
  FZipper := TZipper.Create;
  FFreeList := TFPObjectList.Create(true);
end;

destructor TMapWriterZIP.Destroy;
begin
  FFreeList.Free;
  FZipper.Free;
  inherited Destroy;
end;

procedure TMapWriterZIP.Write(AStream: TStream; AMap: TVCMIMap);
begin
  WriteHeader(AMap);
  WriteObjects(AMap);
  WriteTerrain(AMap);
  FZipper.SaveToStream(AStream);
end;

end.

