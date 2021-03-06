{ This file is a part of Map editor for VCMI project

  Copyright (C) 2015-2016 Alexander Shishkin alexvins@users.sourceforge.net

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
unit object_link_frame;

{$I compilersetup.inc}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, StdCtrls, map,
  object_options;

type

  { TObjectLinkFrame }

  TObjectLinkFrame = class(TFrame)
    ObjectList: TListBox;
  private
    FMap: TVCMIMap;
    FTypeFilter: TObjectOptionsClass;
    procedure SetMap(AValue: TVCMIMap);
    procedure SetTypeFilter(AValue: TObjectOptionsClass);
  public
    function SelectedObject: TMapObject;
    function SelectedIdentifier: AnsiString;
    procedure Load(AIdentifier: String);

    property Map: TVCMIMap read FMap write SetMap;

    property TypeFilter: TObjectOptionsClass read FTypeFilter write SetTypeFilter;
  end;

implementation

uses editor_consts;

{$R *.lfm}

{ TObjectLinkFrame }

procedure TObjectLinkFrame.SetMap(AValue: TVCMIMap);
begin
  FMap:=AValue;
end;

procedure TObjectLinkFrame.SetTypeFilter(AValue: TObjectOptionsClass);
begin
  FTypeFilter:=AValue;
end;

function TObjectLinkFrame.SelectedObject: TMapObject;
begin
  if ObjectList.ItemIndex < 0 then
  begin
    Result := nil;
  end
  else begin
    Result := (ObjectList.Items.Objects[ObjectList.ItemIndex] as TMapObject);
  end;
end;

function TObjectLinkFrame.SelectedIdentifier: AnsiString;
var
  o: TMapObject;
begin
  o := SelectedObject;
  if Assigned(o) then
    Result := o.Identifier
  else
    Result := '';
end;

procedure TObjectLinkFrame.Load(AIdentifier: String);
var
  map_object: TMapObject;
  item: TCollectionItem;
begin
  for item in FMap.Objects do
  begin
    map_object := TMapObject(item);

    if map_object.Options is FTypeFilter then
      ObjectList.AddItem(map_object.DisplayName, map_object)
    else
      Continue;

    if (AIdentifier <> '') and (map_object.Identifier = AIdentifier) then
      ObjectList.ItemIndex := ObjectList.Count-1; //select recently added object
  end;

  //ObjectList.Invalidate;
end;

end.

