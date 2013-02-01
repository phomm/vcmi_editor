{ This file is a part of Map editor for VCMI project

  Copyright (C) 2013 Alexander Shishkin alexvins@users.sourceforge,net

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
unit map_format;

{$I compilersetup.inc}
{$INTERFACES COM}

interface

uses
  Classes, SysUtils, Map, terrain;

type
  //make it managed object
  IMapReader = interface
    function Read(AStream: TStream):TVCMIMap;
  end;



  { TBaseMapFormatHandler }

  TBaseMapFormatHandler = class abstract (TInterfacedObject)
  protected
    FTM: TTerrainManager;
  public
     constructor Create(tm: TTerrainManager); virtual;

  end;

  TBaseMapFormatHandlerClass = class of TBaseMapFormatHandler;

implementation

{ TBaseMapFormatHandler }

constructor TBaseMapFormatHandler.Create(tm: TTerrainManager);
begin
  FTM := tm;
end;

end.
