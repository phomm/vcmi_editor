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
unit editor_graphics;

{$I compilersetup.inc}

interface

uses
  Classes, SysUtils, Math,
  gvector, fgl,
  Gl,
  editor_types, editor_utils, filesystem_base, editor_gl;

const
  TILE_SIZE = 32; //in pixels

  PLAYER_FLAG_COLORS: array[TPlayer] of TRBGAColor = (
    (r: 128; g: 128; b:128; a: 255),//NONE
    (r: 255; g: 0;   b:0;   a: 255),//RED
    (r: 0;   g: 0;   b:255; a: 255),//BLUE
    (r: 120; g: 180; b:140; a: 255),//TAN
    (r: 0;   g: 255; b:0;   a: 255),//GREEN
    (r: 255; g: 165; b:0;   a: 255),//ORANGE
    (r: 128; g: 0;   b:128; a: 255),//PURPLE
    (r: 0;   g: 255; b:255; a: 255),//TEAL
    (r: 255; g: 192; b:203; a: 255) //PINK
  );

type
  TRBGAColor = editor_gl.TRBGAColor;

  TRGBAPalette = packed array[0..255] of TRBGAColor;

  { TBaseSprite }

  TBaseSprite = object
    TextureId: GLuint;
    procedure UnBind; inline;
  end;

  PDefEntry = ^TDefEntry;

  { TDefEntry }

  TDefEntry = object (TBaseSprite)
    TopMagin: int32;
    LeftMargin: int32;
    SpriteWidth: Int32;
    SpriteHeight: Int32;
  end;

  TDefEntries = specialize gvector.TVector<TDefEntry>;


  { TDef }

  TDef = class (IResource)
  strict private
    FPaletteID: GLuint;

    typ: UInt32;
    FWidth: UInt32;
    FHeight: UInt32;
    blockCount: UInt32;
    palette: TRGBAPalette;
    entries: TDefEntries;

    FTexturesBinded: boolean;

    //FBuffer: packed array of TRBGAColor;
    FBuffer: packed array of byte;
    procedure ResizeBuffer(w,h: Integer);

    function GetFrameCount: Integer; inline;

    procedure LoadSprite(AStream: TStream; const SpriteIndex: UInt8; ATextureID: GLuint; offset: Uint32);
    procedure MayBeUnBindTextures; inline;
    procedure UnBindTextures;
  private //for internal use
     (*H3 def format*)
    procedure LoadFromStream(AStream: TStream);

  public
    constructor Create;
    destructor Destroy; override;

    (*
      X,Y: map coords of topleft tile
    *)
    procedure Render(const SpriteIndex: UInt8; X,Y: Integer; dim:integer; color: TPlayer = TPlayer.none);
    procedure RenderF(const SpriteIndex: UInt8; X,Y: Integer; flags:UInt8);

    procedure RenderO (const SpriteIndex: UInt8; X,Y: Integer; color: TPlayer = TPlayer.none);

    property FrameCount: Integer read GetFrameCount;

    procedure RenderBorder(TileX,TileY: Integer);

    property Width: UInt32 read FWidth;
    property Height: UInt32 read FHeight;
  end;

  TDefMapBase = specialize fgl.TFPGMap<string,TDef>;

  { TDefMap }

  TDefMap = class (TDefMapBase)
  protected
    procedure Deref(Item: Pointer); override;
  public
    constructor Create;
  end;

  { TGraphicsManager }

  TGraphicsManager = class (TFSConsumer)
  private
    FNameToDefMap: TDefMap;

    FHeroFlagDefs: array[TPlayerColor] of TDef;

    FBuffer: TMemoryStream;

    procedure LoadDef(const AResourceName:string; ADef: TDef);

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function GetGraphics (const AResourceName:string): TDef;


    function GetHeroFlagDef(APlayer: TPlayer): TDef;
  end;

  { TGraphicsCosnumer }

  TGraphicsCosnumer = class abstract (TFSConsumer)
  private
    FGraphicsManager: TGraphicsManager;
    procedure SetGraphicsManager(AValue: TGraphicsManager);
  public
    constructor Create(AOwner: TComponent); override;
    property GraphicsManager:TGraphicsManager read FGraphicsManager write SetGraphicsManager;
  end;

implementation


type

  TH3DefColor = packed record
    r,g,b : UInt8;
  end;

  TH3Palette = packed array [0..255] of TH3DefColor;

  TH3DefHeader = packed record
    typ: UInt32;
    width: UInt32;
    height: UInt32;
    blockCount: UInt32;
    palette: TH3Palette;
  end;

  TH3DefEntryBlockHeader = packed record
    unknown1: UInt32;
    totalInBlock: UInt32;
    unknown2: UInt32;
    unknown3: UInt32;

//  char *names[length];
//  uint32_t offsets[length];

     //folowed by sprites
  end;

  TH3SpriteHeader = packed record
    prSize: UInt32;
    defType2: UInt32;
    FullWidth: UInt32;
    FullHeight: UInt32;
    SpriteWidth: UInt32;
    SpriteHeight: UInt32;
    LeftMargin: UInt32;
    TopMargin: UInt32;
  end;
const

  H3_SPECAIL_COLORS: array[0..7] of TH3DefColor = (
   {0} (r: 0; g: 255; b:255),
   {1} (r: 255; g: 150; b:255),
   {2} (r: 255; g: 100; b:255),
   {3} (r: 255; g: 50; b:255),
   {4} (r: 255; g: 0; b:255),
   {5} (r: 255; g: 255; b:0),
   {6} (r: 180; g: 0; b:255),
   {7} (r: 0; g: 255; b:0));

const
  STANDARD_COLORS: array[0..7] of TRBGAColor = (
    (r: 0; g: 0; b:0; a: 0), //Transparency
    (r: 0; g: 0; b:0; a: 64),//Shadow border (75% transparent)
    (r: 0; g: 0; b:0; a: 128), //shadow
    (r: 0; g: 0; b:0; a: 128), //shadow
    (r: 0; g: 0; b:0; a: 128), //shadow 50%
    (r: 255; g: 255; b:0; a: 0),  //player color | Selection highlight (creatures)
    (r: 0; g: 0; b:0; a: 128), //Selection + shadow body
    (r: 0; g: 0; b:0; a: 64)); // Selection + shadow border

  PLAYER_COLOR_INDEX = 5;



  //DEF_TYPE_MAP_OBJECT = $43;

function CompareDefs(const d1,d2: TDef): integer;
begin
  Result := PtrInt(d1) - PtrInt(d2);
end;


{ TBaseSprite }

procedure TBaseSprite.UnBind;
begin
  editor_gl.Unbind(TextureId);
end;

{ TGraphicsCosnumer }

constructor TGraphicsCosnumer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  if AOwner is TGraphicsManager then
  begin
    GraphicsManager := (AOwner as TGraphicsManager);
  end;
end;

procedure TGraphicsCosnumer.SetGraphicsManager(AValue: TGraphicsManager);
begin
  if FGraphicsManager = AValue then Exit;
  FGraphicsManager := AValue;
end;

{ TGraphicsManager }

constructor TGraphicsManager.Create(AOwner: TComponent);
const
  FMT = 'AF0%dE';
var
  i: TPlayer;
begin
  inherited Create(AOwner);
  FNameToDefMap := TDefMap.Create;
  FBuffer := TMemoryStream.Create;

  for i in TPlayerColor do
  begin
    FHeroFlagDefs[i] := GetGraphics(Format(FMT,[Integer(i)]));
  end;
end;

destructor TGraphicsManager.Destroy;
begin
  FBuffer.Free;
  FNameToDefMap.Free;
  inherited Destroy;
end;

function TGraphicsManager.GetGraphics(const AResourceName: string): TDef;
var
  res_index: Integer;
begin

  res_index :=  FNameToDefMap.IndexOf(AResourceName);

  if res_index >= 0 then
  begin
    Result := FNameToDefMap.Data[res_index];
  end
  else begin
    Result := TDef.Create;
    LoadDef(AResourceName,Result);
    FNameToDefMap.Add(AResourceName,Result);
  end;

end;

function TGraphicsManager.GetHeroFlagDef(APlayer: TPlayer): TDef;
begin
  Result := FHeroFlagDefs[APlayer];
end;

procedure TGraphicsManager.LoadDef(const AResourceName: string; ADef: TDef);
begin
  ResourceLoader.LoadResource(Adef,TResourceType.Animation,'SPRITES/'+AResourceName);
end;


{ TDefMap }

constructor TDefMap.Create;
begin
  inherited Create;
  OnKeyCompare := @CompareStr;
  OnDataCompare := @CompareDefs;

  Sorted := True;
end;

procedure TDefMap.Deref(Item: Pointer);
begin
  //inherited Deref(Item);
  Finalize(string(Item^));
  TDef(Pointer(PByte(Item)+KeySize)^).Free;
end;

{ TDef }

constructor TDef.Create;
begin
  entries := TDefEntries.Create;
  FTexturesBinded := false;
end;

destructor TDef.Destroy;
begin
  MayBeUnBindTextures;

  entries.Destroy;
  inherited Destroy;
end;

function TDef.GetFrameCount: Integer;
begin
  Result := entries.Size;
end;

procedure TDef.LoadFromStream(AStream: TStream);
var
  id_s: array of GLuint;

  procedure GenerateTextureIds;
    var
      count: LongWord;
    begin
      count := entries.Size;
      SetLength(id_s,count);
      glGenTextures(count, @id_s[0]);
    end;
var
  offsets : packed array of UInt32;
  total_entries: Integer;
  block_nomber: Integer;

  current_block_head: TH3DefEntryBlockHeader;
  total_in_block: Integer;

  current_offcet: UInt32;

  i: Uint8;


  header: TH3DefHeader;
  orig_position: Int32;
begin
  if FTexturesBinded then
    UnBindTextures;
  FTexturesBinded := false;

  orig_position := AStream.Position;

  AStream.Read(header{%H-},SizeOf(header));

  typ := LEtoN(header.typ);
  FHeight := LEtoN(header.height);
  blockCount := LEtoN(header.blockCount);
  FWidth := LEtoN(header.width);

  //TODO: use color comparison instead of index

  for i := 0 to 7 do
  begin
    palette[i] := STANDARD_COLORS[i];
  end;

  for i := 8 to 255 do
  begin
    palette[i].a := 255; //no alpha in h3 def
    palette[i].b := header.palette[i].b;
    palette[i].g := header.palette[i].g;
    palette[i].r := header.palette[i].r;
  end;

  glGenTextures(1,@FPaletteID);
  BindPalette(FPaletteID,@palette);

  total_entries := 0;

  for block_nomber := 0 to header.blockCount - 1 do
  begin
     AStream.Read(current_block_head{%H-},SizeOf(current_block_head));

     total_in_block := current_block_head.totalInBlock;

     SetLength(offsets, total_entries + total_in_block);

     //entries.Resize(total_entries + total_in_block);

     //names
     AStream.Seek(13*total_in_block,soCurrent);

     //offcets
     for i := 0 to total_in_block - 1 do
     begin
       AStream.Read(current_offcet{%H-},SizeOf(current_offcet));
       offsets[total_entries+i] := current_offcet+UInt32(orig_position);

       //todo: use block_nomber to load heroes defs from mods

       //entries.Mutable[total_entries+i]^.group := block_nomber;
     end;

     total_entries += total_in_block;
  end;

  entries.Resize(total_entries);

  GenerateTextureIds;

  for i := 0 to entries.Size - 1 do
  begin
    LoadSprite(AStream, i, id_s[i], offsets[i]);
  end;

  SetLength(FBuffer,0); //clear
end;

procedure TDef.LoadSprite(AStream: TStream; const SpriteIndex: UInt8;
  ATextureID: GLuint; offset: Uint32);
var
  ftcp: Int32;
  procedure Skip(Count: Int32); inline;
  begin
    ftcp +=Count;
  end;

  procedure SkipIfPositive(Count: Int32); inline;
  begin
    if Count > 0 then
      Skip(Count);
  end;

var
  h: TH3SpriteHeader;

  LeftMargin,TopMargin,
  RightMargin, BottomMargin: Int32;
  SpriteHeight, SpriteWidth: Int32;

  add: Int32;

  BaseOffset: Int32;
  BaseOffsetor: Int32;

  PEntry: PDefEntry;

  procedure ReadType0;
  var
    row: Int32;
  begin
    for row:=0 to SpriteHeight - 1 do
    begin
      SkipIfPositive(LeftMargin);

      AStream.Read(FBuffer[ftcp+row * Int32(h.FullWidth)],SpriteWidth);

      SkipIfPositive(RightMargin);
    end;
  end;

  procedure ReadType1;
  var
    //RWEntriesLoc: Int32;
    row: Int32;
    TotalRowLength : Int32;
    RowAdd: UInt32;
    SegmentLength: Int32;
    SegmentType: UInt8;
  begin
    //const ui32 * RWEntriesLoc = reinterpret_cast<const ui32 *>(FDef+BaseOffset);

    //BaseOffset += sizeof(int) * SpriteHeight;
    for row := 0 to SpriteHeight - 1 do
    begin
      AStream.Seek(BaseOffsetor + SizeOf(UInt32)*row, soFromBeginning);
      AStream.Read(BaseOffset,SizeOf(BaseOffset));


      SkipIfPositive(LeftMargin);
      TotalRowLength :=  0;
      repeat
         SegmentType := AStream.ReadByte;
         SegmentLength := AStream.ReadByte + 1;

         if SegmentType = $FF then
         begin
           AStream.Seek(BaseOffsetor+Int32(BaseOffset), soFromBeginning);
           AStream.Read(FBuffer[ftcp],SegmentLength);
           BaseOffset += SegmentLength;
         end
         else begin
           FillChar(FBuffer[ftcp],SegmentLength,SegmentType);
         end;

         Skip(SegmentLength);

         TotalRowLength += SegmentLength;
       until TotalRowLength>=(SpriteWidth);
       RowAdd := Uint32(SpriteWidth) - TotalRowLength;

       SkipIfPositive(RightMargin);

       if add >0 then
         Skip(add+Int32(RowAdd));
     end;
  end;

  procedure ReadType2();
  var
    row: Integer;
    TotalRowLength: Integer;
    SegmentType, code, value: Byte;
    RowAdd: Int32;
  begin
    BaseOffset := BaseOffsetor + AStream.ReadWord();
    AStream.Seek(BaseOffset,soBeginning);

    for row := 0 to SpriteHeight - 1 do
    begin
      SkipIfPositive(LeftMargin);

      TotalRowLength:=0;
      repeat
         SegmentType := AStream.ReadByte();
         code := SegmentType div 32;
         value := (SegmentType and 31) + 1;

         if code=7 then
         begin
           AStream.Read(FBuffer[ftcp],value);
         end
         else begin
           FillChar(FBuffer[ftcp],value,code);
         end;
         Skip(Value);
         TotalRowLength+=value;

      until TotalRowLength >= SpriteWidth ;


      SkipIfPositive(RightMargin);

      RowAdd := SpriteWidth-TotalRowLength;

      if (add>0) then
         ftcp += add+RowAdd;
    end;
  end;

  procedure ReadType3();
  var
    row: Int32;
    tmp: UInt16;
    TotalRowLength : Int32;

    SegmentType, code, value: UInt8;
    len: Integer;
    RowAdd: Int32;
  begin
    for row := 0 to SpriteHeight - 1 do
    begin
      AStream.Seek(BaseOffsetor+row*2*(SpriteWidth div 32),soBeginning);
      tmp := AStream.ReadWord();
      BaseOffset := BaseOffsetor + tmp;
      SkipIfPositive(LeftMargin);
      TotalRowLength := 0;

      AStream.Seek(BaseOffset,soBeginning);

      repeat
         SegmentType := AStream.ReadByte;
         code := SegmentType div 32;
         value := (SegmentType and 31) + 1;

         len := Min(Int32(value), SpriteWidth - TotalRowLength) - Max(0, -LeftMargin);

         len := Max(0,len);

         if code = 7 then
         begin
           AStream.Read(FBuffer[ftcp],len);
         end
         else begin
           FillChar(FBuffer[ftcp],len,code);
         end;
         Skip(len);

         TotalRowLength += ifthen(LeftMargin>=0,value, value+LeftMargin );

      until TotalRowLength>=SpriteWidth;

      SkipIfPositive(RightMargin);

      RowAdd := SpriteWidth-TotalRowLength;

      if (add>0) then
         ftcp += add+RowAdd;

    end;
  end;

begin
  PEntry := entries.Mutable[SpriteIndex];

  BaseOffset := offset;

  AStream.Seek(BaseOffset,soBeginning);
  AStream.Read(h{%H-},SizeOf(h));

  BaseOffset := AStream.Position;
  BaseOffsetor := BaseOffset;

  with h do
  begin
    LeToNInPlase(prSize);
    LeToNInPlase(defType2);
    LeToNInPlase(FullHeight);
    LeToNInPlase(FullWidth);
    LeToNInPlase(SpriteHeight);
    LeToNInPlase(SpriteWidth);
    LeToNInPlase(LeftMargin);
    LeToNInPlase(TopMargin);
  end;

  //TODO: use margins to decrease decompressed sprite size

  PEntry^.LeftMargin := h.LeftMargin;
  PEntry^.TopMagin := h.TopMargin;
  PEntry^.TextureId := ATextureID;
  PEntry^.SpriteHeight := h.SpriteHeight;
  PEntry^.SpriteWidth := h.SpriteWidth;

  LeftMargin := h.LeftMargin;
  TopMargin := h.TopMargin;

  SpriteHeight := h.SpriteHeight;
  SpriteWidth := h.SpriteWidth;

  RightMargin := Int32(h.FullWidth) - SpriteWidth - LeftMargin;
  BottomMargin := Int32(h.FullHeight) - SpriteHeight - TopMargin;

  if LeftMargin<0 then
     SpriteWidth+=LeftMargin;
  if RightMargin<0 then
     SpriteWidth+=RightMargin;

  add := 4 - (h.FullWidth mod 4);
  if add = 4 then
     add :=0;

  ResizeBuffer(h.FullWidth,h.FullHeight);


  if (TopMargin > 0) or (BottomMargin > 0) or (LeftMargin > 0) or (RightMargin > 0) then
    FillChar(FBuffer[0], Length(FBuffer) ,0); //todo: use marging in texture coords

  ftcp := 0;

  // Skip top margin
  if TopMargin > 0 then
  begin
    Skip(TopMargin*(Int32(h.FullWidth)+add));
  end;

  case h.defType2 of
    0:begin
      ReadType0();
    end;
    1:begin
      ReadType1(); //TODO: test format 1
    end;
    2:begin
      ReadType2();
    end;
    3:begin
      ReadType3();
    end
  else
    raise Exception.Create('Unknown sprite compression format');
  end;

  BindUncompressedPaletted(ATextureID,h.FullWidth,h.FullHeight, @FBuffer[0]);
  //BindUncompressedRGBA(ATextureID,h.FullWidth,h.FullHeight, FBuffer[0]);

end;

procedure TDef.MayBeUnBindTextures;
begin
  if FTexturesBinded then
    UnBindTextures;
  FTexturesBinded := False;
end;

procedure TDef.Render(const SpriteIndex: UInt8; X, Y: Integer; dim: integer;
  color: TPlayer);
var
  Sprite: TGLSprite;
begin
  Sprite.TextureID := entries[SpriteIndex].TextureId;
  Sprite.PaletteID := FPaletteID;
  Sprite.X := X;
  Sprite.Y := Y;
  Sprite.Height := height;
  Sprite.Width := width;

  ShaderContext.SetFlagColor(PLAYER_FLAG_COLORS[color]);

  editor_gl.RenderSprite(Sprite, dim);

end;

procedure TDef.RenderBorder(TileX, TileY: Integer);
var
  cx: Integer;
  cy: Integer;
begin
  cx := (TileX+1) * TILE_SIZE;
  cy := (TileY+1) * TILE_SIZE;

  editor_gl.RenderRect(cx,cy,-width,-height);
end;

procedure TDef.RenderF(const SpriteIndex: UInt8; X, Y: Integer; flags: UInt8);
var
  mir: UInt8;
  Sprite: TGLSprite;
begin
  Sprite.X := X;
  Sprite.Y := Y;
  Sprite.Height := height;
  Sprite.Width := width;
  Sprite.TextureID := entries[SpriteIndex].TextureId;
  Sprite.PaletteID := FPaletteID;

  CheckGLErrors('RenderF enter');

  mir := flags mod 4;

  ShaderContext.SetFlagColor(PLAYER_FLAG_COLORS[TPlayer.none]);

  editor_gl.RenderSprite(Sprite,-1,mir);


end;

procedure TDef.RenderO(const SpriteIndex: UInt8; X, Y: Integer; color: TPlayer);
var
  Sprite: TGLSprite;
begin
  Sprite.X := X - width;
  Sprite.Y := Y - height;
  Sprite.Height := height;
  Sprite.Width := width;
  Sprite.TextureID := entries[SpriteIndex].TextureId;
  Sprite.PaletteID := FPaletteID;

  ShaderContext.SetFlagColor(PLAYER_FLAG_COLORS[color]);

  editor_gl.RenderSprite(Sprite);

end;

procedure TDef.ResizeBuffer(w, h: Integer);
var
  old_len, new_len: Integer;
begin
  old_len := Length(FBuffer);
  new_len := h * w;
  new_len := Max(old_len,new_len);
  SetLength(FBuffer, new_len);
end;

procedure TDef.UnBindTextures;
var
  SpriteIndex: Integer;
begin
  for SpriteIndex := 0 to entries.Size - 1 do
  begin
    entries.Mutable[SpriteIndex]^.UnBind();
  end;
  glDeleteTextures(1,@FPaletteID);
end;

end.
