unit Geomod32;

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  FileCtrl, Math, DocFileEngine, Idrisi32_tlb, Idr_Support_Lib;

// Next are definitions about global variables.
type
  TByteMap = array of array of byte;
  TIntMap = array of array of integer;
  TSingleMap = array of array of Single;

const
  IDR_AREACONV = 1E6; { Used to convert square m to square km }

  IDR_DIMINCR = 1;
  { For compatiblity of Delphi and VB/Fortran about the declaration of dynamic array }
  IDR_MAXMAPNUM = 101; { For defining the maps }
  IDR_RSTEXT = 1; { always use Idrisi type files }

  IDR_OCEANRGN = 0; { The variable OCEANRGN would always be 0 }
  IDR_OCEAN = 0; { The variable OCEAN would always be 0 }
  IDR_STUDYOUT = 0; { The variable STUDYOUT would always be 0 }

  IDR_DSRTVALU = 0;
  { DSRTVALU, constaint area value in constraint map, always be 0 }
  IDR_DSRTOUT = 0;
  { DSRTOUT, constraint area value assigned to output maps, always be 0 }

  IDR_NTYPE = 2; { NTYPE would always be 2. }
  IDR_NODATA = 0; { NODATA category in the initial landuse map always be 0 }
  IDR_CBNDIV = 1; { CBNDIV always be 1 }
  IDR_NLOOPS = 1; { NLOOPS always be 1 }

  IDR_VLDOUT = 0; { VLDOUT always be 0 }
  ROW_RANGE = 100; { INDICATE AT LEAST PROCESS 50 ROWS THEN STOP }

const
  READ_FILE = 0;
  WRITE_FILE = 1;
  COMP_SUIT = 0;
  READ_SUIT = 1;
  GMF_EXT = '.gmd';

type
  TSingle = array of Single;
  TContiguity = array of boolean;
  TEdge = array of boolean;
  TMapCross = array of array of integer;

procedure Main_Prog;
function CheckAndReadMap(Fname: string; NumRowCheck, NumColCheck: integer;
  FirstRowID, LastRowID: integer; var OutputMap: TSingleMap): boolean;
function RetrieveRDCParameter(imgfilename: string; var Rdoc: TImgDoc): boolean;
function GetRstFileName(Fname: string): string;
procedure GetInputFileNames(projectname: string);
// read input files names from the project file
function CreateImgDocFile(var OutputImageDoc: string; DocTitle: string;
  OutDataType: integer; MaxV, MinV: Single; refimg: string; flag : boolean; flagval : single): boolean;  //T - 12/17/19 - added last 2 parameters
function ReturnCompleteFileName(ReadOrWrite: integer; filename: string;
  const Extension: string): string;

procedure Geomod_Main;
procedure Sreader;
procedure Sflux(IRGN: integer);
procedure Sfrict(IMAP: integer);
procedure Swriter;
function NINT(a: double): integer;
procedure Snewera;
procedure Sinitial;
procedure Sconvert(IRGN: integer);
procedure Swhere(IRGN: integer);
procedure CreateOutputImageGroupFiles;
procedure CleanUp;

procedure Get_Windows_Cmdln;
// procedure ReadInputFile1;

implementation

uses IDRISX32k, PseudoMercury_32k;
// Uses Sreader_procedure;

{ The following defines the global variables shared in the whole project }
var
  SimulationDirection: Smallint; { +1 indicates Forward, while -1 Backward }
  FMAPNAME: array of string;
  FRICTIONMAPNAME: array of string;
  FRGNNAME: array of string[22];
  FMAPE: array of array of string;
  GNORTH, GSOUTH, GEAST, GWEST: string;

  CBNDIV: integer;
  CBNCAT: array of Smallint; // Category value in Biomass Map.
  CBN: array of array of double;
  RCBN2BIO: array of double;
  CBNBIORATEMAP, FluxPercMap: TSingleMap; // can change to local arrays?
  ERABGN, ERAEND: array of Smallint;
  FMAPEX: array of array of Smallint;
  FMAPXT: array of Smallint;
  HISEPSLN: integer;
  BLANKMAP: byte; { Boolean }
  IERA, NERA: Smallint;
  NMAPC, NMAPP, NMAPE, NMAPVLD: Smallint;
  NRGN: integer;
  IYEAREND, IYEARSTP, NLOOPS: Smallint;
  MAPCBN: array of array of array of Single;
  MAPYEAR: array of array of Smallint;

  MAPIN: TSingleMap;
  // MAPVLD{, MAPDSRT}: TIntMap; // array of array of Byte;
  MAPLND1, MAPLND2, MAPRGN: TIntMap; // array of array of Byte/SmallInt;

  NDCATMAX: Smallint;
  NCCAT: array of Smallint;
  NCOL, NROW: integer;
  NEIGHB, NODATA, DOCBN { boolean } , DSRTMAP, DSRTVALU, DSRTOUT { boolean } ,
    DEBUGOUT { boolean } : Smallint;
  NYEARWRT: Smallint;
  YEARWRT: array of Smallint;
  OCEAN, NPERCLAS, LUBIDO { boolean } , LUBISTOP { boolean } ,
    OCEANRGN: integer;
  RGNV, STUDYOUT: integer;
  RGNVAL: array of Smallint;
  CONTIG: array of Smallint; { boolean }
  HASEDGE: TEdge; { boolean }
  TYPEVAL: array of Smallint;
  NTYPE: Smallint;
  USEVALID, VALIDYR, VLDOUT: integer;
  WRTOPEN: byte;
  WRTRST: array [1 .. 4] of byte; { boolean, Integer; }
  PREFIXFINAL: array [1 .. 3] of string; // output images' prefixes
  OUTPUTFINAL: array [1 .. 3] of string;
  // finally output images, actually there are only 3 outputs at most
  YEARBGN, YEAREND: Smallint;
  SEED: integer;

  CELLAREA: array of double;
  DRIVEWT: array of array of double;
  // been modified as two-dimensional for multiple loops
  FMAPPWTT: array of double;
  // been modified as one-dimensional for multiple loops
  FMAPPWT: array of array of double;
  // been modified as two-dimensional for multiple loops
  FMAPEWT: array of array of double;
  FRIC: array of array of array of double;
  YEARWAIT: array of Smallint;
  YEAR, DRCOUNT: Smallint;
  // **    MAPLUBI: array of array of integer;      //Lubrication map
  MAPFLXCU, MAPFLXYR: TSingleMap; // array of array of Single;
  MAPFRCP: TSingleMap;
  // array of array of Single;        //Friction map, Idrisi single image
  MATTRA: array of array of array of double;
  MATCBN: array of array of array of double;

  ResultImagesPath: string;
  LubricationFile: string;
  ReadSuccess: boolean;

  TMP_FMAPXT: array of integer;
  // examine if the inputs about map extensions in InputMultiple sheet is identical to those in Input1 sheet.
  TMP_FMAPNAME: array of string;
  // examine if the inputs about map names in InputMultiple sheet is identical to those in Input1 sheet.

  CREATE: Smallint;
  HISTOT: Int64;
  HISTAR: array of integer; { maybe Int64 }
  HISMAP: array of array of integer;
  HISRGN: array of integer;

  HISDELT: double;
  TTYPE: Smallint;
  TYPEBGN: array of array of double; // TYPERAT(NRGN, NTYPE)
  AREA: array of array of double;
  TYPERAT: array of array of double; // TYPERAT(NRGN, NTYPE)
  RGNEAST, RGNNORTH, RGNSOUTH, RGNWEST: array of integer;

  { the next variables are for Swriter }
  HISVLD: array of array of integer;
  HISVLDR: array of integer;
  HISVLDT: array of integer;
  HISVLDRS: integer;

  HISINI: array of array of integer;
  HISINIT: array of integer;
  HISSUM: array of integer;
  HISSUMR: array of double;
  HMAPT: integer;
  NVLDFREE: integer;
  NVLDYES: integer;
  NVLDYESS: integer;
  NNONCAN: array of integer;
  NNONCANR: integer;
  NVLDMIN: integer;
  NVLDEX: array of double;
  NVLDEXS: double;
  NVLDEXST: double;

  VALIDP, VALIDEXP, VALUE, VALUET: double; { ??VALIDEXP() }
  WRTLUBI: Smallint; { boolean }
  SUITOPTION: Smallint; // read or compute suitability scores.

  GmParameterFileName, GmInputFile1, GmInputFile2: string;
  // geomod project and inputfiles names
  Fa, Fb, Fc, Fw { Fp2, geomod.se2 } : TextFile;
  NCELLBGN, NCELLEND: TMapCross; // array of array of integer;

  IfFixedCBrate, IfFixedFluxRate, IFDISPLAY: integer;
  ContinueYearLoop: boolean;

  CBrateImage, FluxrateImage: string;
  bTerminateApplication: boolean;

procedure CleanUp;
begin
  FMAPNAME := nil;
  FRICTIONMAPNAME := nil;
  FRGNNAME := nil;
  FMAPE := nil;

  CBNCAT := nil;
  CBN := nil;
  RCBN2BIO := nil;
  CBNBIORATEMAP := nil;
  FluxPercMap := nil;
  ERABGN := nil;
  ERAEND := nil;;
  FMAPEX := nil;
  FMAPXT := nil;
  MAPCBN := nil;
  MAPYEAR := nil;

  // MAPIN := nil;  //it has been released in above
  // MAPVLD := nil;
  // MAPDSRT := nil;
  MAPLND1 := nil;
  MAPLND2 := nil;
  MAPRGN := nil;

  NCCAT := nil;
  YEARWRT := nil;
  RGNVAL := nil;
  CONTIG := nil;
  HASEDGE := nil;
  TYPEVAL := nil;

  CELLAREA := nil;
  // DRIVEWT := nil;
  FMAPPWTT := nil;
  FMAPPWT := nil;
  FMAPEWT := nil;
  FRIC := nil;
  YEARWAIT := nil;
  MAPFLXCU := nil;
  MAPFLXYR := nil;
  MAPFRCP := nil;
  MATTRA := nil;
  MATCBN := nil;

  TMP_FMAPXT := nil;
  TMP_FMAPNAME := nil;

  HISTAR := nil;
  HISMAP := nil;
  HISRGN := nil;

  TYPEBGN := nil;
  AREA := nil;
  TYPERAT := nil;
  RGNEAST := nil;
  RGNNORTH := nil;
  RGNSOUTH := nil;
  RGNWEST := nil;

  HISVLD := nil;
  HISVLDR := nil;
  HISVLDT := nil;

  HISINI := nil;
  HISINIT := nil;
  HISSUM := nil;
  HISSUMR := nil;
  NNONCAN := nil;
  NVLDEX := nil;
end;

function CrossTableCompute(F1, F2, MaskImage: string;
  var CrossArray: TMapCross): boolean;
var
  Inf1, Inf2, Mf: file;
  F1Doc: TImgDoc;
  F2Doc: TImgDoc;
  MaskImgDoc: TImgDoc;
  i, j, irow, icol: integer;
  ReadFileSuccess1, ReadFileSuccess2: boolean;
  NumRows, NumCols: integer;
  ByteBuf1, ByteBuf2, ByteMaskbuf: array of byte;
  IntBuf1, IntBuf2, IntMaskbuf: array of Smallint;
  TmpF1Buf, TmpF2Buf, TmpMaskBuf: array of Smallint;

begin
  Result := false;
  F1Doc := TImgDoc.CREATE;
  F2Doc := TImgDoc.CREATE;
  MaskImgDoc := TImgDoc.CREATE;

  ReadFileSuccess1 := RetrieveRDCParameter(F1, F1Doc);
  ReadFileSuccess2 := RetrieveRDCParameter(F2, F2Doc);

  if (not ReadFileSuccess1) or (not ReadFileSuccess2) then
  begin
    F1Doc.Free;
    F2Doc.Free;
    Exit;
  end;

  if (not(F1Doc.DataType in [0, 2])) then
  begin
    beep;
    ShowMessage
      ('The data type of the beginning land use image should be either byte or integer binary.');
    F1Doc.Free;
    F2Doc.Free;
    Exit;
  end;

  if (not(F2Doc.DataType in [0, 2])) then
  begin
    beep;
    ShowMessage
      ('The data type of the validation image should be either byte or integer binary.');
    F1Doc.Free;
    F2Doc.Free;
    Exit;
  end;

  if (F1Doc.Rows <> F2Doc.Rows) or (F1Doc.Cols <> F2Doc.Cols) then
  begin
    beep;
    ShowMessage
      ('The numbers of columns and/or rows of the validation image do not match the beginning land use image.');
    F1Doc.Free;
    F2Doc.Free;
    Exit;
  end;

  if Trim(MaskImage) <> '' then
  begin
    if not RetrieveRDCParameter(MaskImage, MaskImgDoc) then
    begin
      F1Doc.Free;
      F2Doc.Free;
      MaskImgDoc.Free;
      Exit;
    end;

    if not(MaskImgDoc.DataType in [0, 2]) then
    begin
      beep;
      // ShowMessage('The exclusion/mask image should be byte or integer binary.');
      F1Doc.Free;
      F2Doc.Free;
      MaskImgDoc.Free;
      Exit;
    end;

    if (MaskImgDoc.Rows <> F2Doc.Rows) or (MaskImgDoc.Cols <> F2Doc.Cols) then
    begin
      beep;
      // ShowMessage('The row/col number of the exclusion(mask) image is not equal to that of the input files.');
      F1Doc.Free;
      F2Doc.Free;
      MaskImgDoc.Free;
      Exit;
    end;
  end;

  try
    SetLength(CrossArray, Round(F1Doc.MaxValue) + 1, Round(F2Doc.MaxValue) + 1);
    for i := 0 to Round(F1Doc.MaxValue) do
      for j := 0 to Round(F2Doc.MaxValue) do
        CrossArray[i, j] := 0; // every time initilize again as 0

    NumRows := F1Doc.Rows;
    NumCols := F1Doc.Cols;

    AssignFile(Inf1, F1);
    AssignFile(Inf2, F2);

    if F1Doc.DataType = DATA_TYPE_BYTE then
    begin
      Reset(Inf1, 1); { byte file would be computed }
      SetLength(ByteBuf1, NumCols);
    end
    else
    begin
      Reset(Inf1, 2); { Idrisi integer file would be computed }
      SetLength(IntBuf1, NumCols);
    end;
    SetLength(TmpF1Buf, NumCols);

    if F2Doc.DataType = DATA_TYPE_BYTE then
    begin
      Reset(Inf2, 1); { byte file would be computed }
      SetLength(ByteBuf2, NumCols);
    end
    else
    begin
      Reset(Inf2, 2); { Idrisi integer file would be computed }
      SetLength(IntBuf2, NumCols);
    end;
    SetLength(TmpF2Buf, NumCols);

    if Trim(MaskImage) <> '' then
    begin
      AssignFile(Mf, MaskImage);
      if MaskImgDoc.DataType = DATA_TYPE_BYTE then
      begin
        Reset(Mf, 1); { byte file would be computed }
        SetLength(ByteMaskbuf, NumCols);
      end
      else
      begin
        Reset(Mf, 2); { Idrisi integer file would be computed }
        SetLength(IntMaskbuf, NumCols);
      end;
      SetLength(TmpMaskBuf, NumCols);
    end;

    for irow := 0 to NumRows - 1 do
    begin
      if F1Doc.DataType = DATA_TYPE_BYTE then
      begin
        BlockRead(Inf1, ByteBuf1[0], NumCols);
        for icol := 0 to NumCols - 1 do
          TmpF1Buf[icol] := ByteBuf1[icol];
      end
      else
      begin
        BlockRead(Inf1, IntBuf1[0], NumCols);
        for icol := 0 to NumCols - 1 do
          TmpF1Buf[icol] := IntBuf1[icol];
      end;

      if F2Doc.DataType = DATA_TYPE_BYTE then
      begin
        BlockRead(Inf2, ByteBuf2[0], NumCols);
        for icol := 0 to NumCols - 1 do
          TmpF2Buf[icol] := ByteBuf2[icol];
      end
      else
      begin
        BlockRead(Inf2, IntBuf2[0], NumCols);
        for icol := 0 to NumCols - 1 do
          TmpF2Buf[icol] := IntBuf2[icol];
      end;

      if Trim(MaskImage) <> '' then
      begin
        if MaskImgDoc.DataType = DATA_TYPE_BYTE then
        begin
          BlockRead(Mf, ByteMaskbuf[0], NumCols);
          for icol := 0 to NumCols - 1 do
            TmpMaskBuf[icol] := ByteMaskbuf[icol];
        end
        else
        begin
          BlockRead(Mf, IntMaskbuf[0], NumCols);
          for icol := 0 to NumCols - 1 do
            TmpMaskBuf[icol] := IntMaskbuf[icol];
        end;
      end;

      for icol := 0 to NumCols - 1 do
        if Trim(MaskImage) = '' then // no mask
          CrossArray[TmpF1Buf[icol], TmpF2Buf[icol]] :=
            CrossArray[TmpF1Buf[icol], TmpF2Buf[icol]] + 1
        else // with mask
        begin
          if TmpMaskBuf[icol] <> 0 then
            CrossArray[TmpF1Buf[icol], TmpF2Buf[icol]] :=
              CrossArray[TmpF1Buf[icol], TmpF2Buf[icol]] + 1;
        end;
    end;
    ByteBuf1 := nil;
    ByteBuf2 := nil;
    IntBuf1 := nil;
    IntBuf2 := nil;
    ByteMaskbuf := nil;
    IntMaskbuf := nil;
    TmpF1Buf := nil;
    TmpF2Buf := nil;
    TmpMaskBuf := nil;

    CloseFile(Inf1);
    CloseFile(Inf2);

    if Trim(MaskImage) <> '' then
      CloseFile(Mf);

    F1Doc.Free;
    F2Doc.Free;
    if Trim(MaskImage) <> '' then
      MaskImgDoc.Free;
    Result := true;
  except
    on Exception do
    begin
      ShowMessage
        ('Unexpected I/O error: Please recheck the input beginning land use and validation images.');
      ByteBuf1 := nil;
      ByteBuf2 := nil;
      IntBuf1 := nil;
      IntBuf2 := nil;
      ByteMaskbuf := nil;
      IntMaskbuf := nil;
      TmpF1Buf := nil;
      TmpF2Buf := nil;
      TmpMaskBuf := nil;

      CloseFile(Inf1);
      CloseFile(Inf2);
      if Trim(MaskImage) <> '' then
        CloseFile(Mf);

      F1Doc.Free;
      if Trim(MaskImage) <> '' then
        MaskImgDoc.Free;
      F2Doc.Free;
      Exit;
    end;
  end;
end;

function CalcLandTypeQuantityWithoutRegionImg(F1: string;
  var TypeQuantity: TMapCross): boolean;
var
  Inf1: file;
  F1Doc: TImgDoc;
  i, j, irow, icol: integer;
  ByteBuf1: array of byte;
  IntBuf1: array of Smallint;
  TmpF1Buf: array of Smallint;

begin
  Result := false;
  F1Doc := TImgDoc.CREATE;

  if not RetrieveRDCParameter(F1, F1Doc) then
  begin
    F1Doc.Free;
    Exit;
  end;

  if (not(F1Doc.DataType in [0, 2])) then
  begin
    beep;
    ShowMessage
      ('The data type of the beginning land use image should be either byte or integer binary.');
    F1Doc.Free;
    Exit;
  end;

  if (F1Doc.Rows <> NROW) or (F1Doc.Cols <> NCOL) then
  begin
    beep;
    ShowMessage
      ('The numbers of columns and/or rows of the input image do not match the beginning land use image.');
    F1Doc.Free;
    Exit;
  end;

  try
    SetLength(TypeQuantity, NRGN + 1, NTYPE + 1);
    for i := 0 to NRGN do
      for j := 0 to NTYPE do
        TypeQuantity[i, j] := 0; // every time initilize again as 0

    AssignFile(Inf1, F1);

    if F1Doc.DataType = DATA_TYPE_BYTE then
    begin
      Reset(Inf1, 1); { byte file would be computed }
      SetLength(ByteBuf1, F1Doc.Cols);
    end
    else
    begin
      Reset(Inf1, 2); { Idrisi integer file would be computed }
      SetLength(IntBuf1, F1Doc.Cols);
    end;
    SetLength(TmpF1Buf, F1Doc.Cols);

    for irow := 0 to F1Doc.Rows - 1 do
    begin
      if F1Doc.DataType = DATA_TYPE_BYTE then
      begin
        BlockRead(Inf1, ByteBuf1[0], F1Doc.Cols);
        for icol := 0 to F1Doc.Cols - 1 do
          TmpF1Buf[icol] := ByteBuf1[icol];
      end
      else
      begin
        BlockRead(Inf1, IntBuf1[0], F1Doc.Cols);
        for icol := 0 to F1Doc.Cols - 1 do
          TmpF1Buf[icol] := IntBuf1[icol];
      end;

      for icol := 0 to F1Doc.Cols - 1 do
        TypeQuantity[1, TmpF1Buf[icol]] := TypeQuantity[1, TmpF1Buf[icol]] + 1;
    end;
    ByteBuf1 := nil;
    IntBuf1 := nil;
    TmpF1Buf := nil;

    CloseFile(Inf1);
    F1Doc.Free;
    Result := true;
  except
    on Exception do
    begin
      ShowMessage
        ('Unexpected I/O error: Please recheck the input beginning land use and validation images.');
      ByteBuf1 := nil;
      IntBuf1 := nil;
      TmpF1Buf := nil;
      CloseFile(Inf1);
      F1Doc.Free;
    end;
  end;
end;

function CreateTempImage_Int(Source, Target: string;
  SourceImgDoc: TImgDoc): boolean;
type
  TByteBuf = array [0 .. 0] of byte;
  TpByteBuf = ^TByteBuf;
  TIntbuf = array [0 .. 0] of Smallint;
  TpIntbuf = ^TIntbuf;
var
  Inf1, outf1: file;
  i, j: integer;
  Bytebufin: TpByteBuf;
  intbufin, intbufout: TpIntbuf;
  transfer: integer;
begin
  with SourceImgDoc do
  begin
    if DataType = DATA_TYPE_BYTE then
    begin
      AssignFile(Inf1, changeFileExt(Source, '.rst'));
      Reset(Inf1, 1);
      AssignFile(outf1, Target);
      ReWrite(outf1, 2);
      Getmem(Bytebufin, Cols * sizeof(byte));
      Getmem(intbufout, Cols * sizeof(Smallint));
      for i := 0 to Rows - 1 do
      begin
        BlockRead(Inf1, Bytebufin^, Cols);
        for j := 0 to Cols - 1 do
          intbufout[j] := Bytebufin[j];
        BlockWrite(outf1, intbufout^, Cols);
      end;
      Freemem(Bytebufin);
      Freemem(intbufout);
      CloseFile(Inf1);
      CloseFile(outf1);
    end
    else if DataType = DATA_TYPE_INTEGER then
    begin
      AssignFile(Inf1, changeFileExt(Source, '.rst'));
      Reset(Inf1, 2);
      AssignFile(outf1, Target);
      ReWrite(outf1, 2);
      Getmem(intbufin, Cols * sizeof(Smallint));
      for i := 0 to Rows - 1 do
      begin
        BlockRead(Inf1, intbufin^, Cols);
        BlockWrite(outf1, intbufin^, Cols);
      end;
      CloseFile(Inf1);
      CloseFile(outf1);
      Freemem(intbufin);
    end;
  end;
end;

procedure LandTypeEdgeAnalyst(StrataImage, LandImage: string;
  var HasEdgeList: TEdge);
const
  LAND_TYPE_NUM = 2;
var
  i, j, k: integer;
  StrataImgDoc, LandImgDoc: TImgDoc;
  SInf, LInf: file;
  SInfBufByte, LInfBufByte: array of byte;
  SInfBufInt, LInfBufInt: array of Smallint;
  RegMark: array of array of byte;
  nTransferred: integer;
  nRows, nCols: integer;
begin
  if UpperCase(Trim(StrataImage)) <> 'N/A' then
  begin
    StrataImgDoc := TImgDoc.CREATE;
    if not RetrieveRDCParameter(StrataImage, StrataImgDoc) then
    begin
      StrataImgDoc.Free;
      Exit;
    end;
    AssignFile(SInf, ReturnCompleteFileName(READ_FILE, StrataImage, '.rst'));
    Reset(SInf, 1);
  end;

  SetLength(RegMark, Length(HasEdgeList), LAND_TYPE_NUM + 1);

  LandImgDoc := TImgDoc.CREATE;
  if not RetrieveRDCParameter(LandImage, LandImgDoc) then
  begin
    LandImgDoc.Free;
    Exit;
  end;

  nRows := LandImgDoc.Rows;
  nCols := LandImgDoc.Cols;

  SetLength(LInfBufByte, nCols);
  SetLength(LInfBufInt, nCols);

  SetLength(SInfBufByte, nCols); // these two must be equal
  SetLength(SInfBufInt, nCols);

  AssignFile(LInf, ReturnCompleteFileName(READ_FILE, LandImage, '.rst'));
  Reset(LInf, 1);

  for i := 0 to nRows - 1 do
  begin
    if UpperCase(Trim(StrataImage)) <> 'N/A' then
    begin
      if StrataImgDoc.DataType = DATA_TYPE_BYTE then
      begin
        BlockRead(SInf, SInfBufByte[0], nCols * sizeof(byte), nTransferred);
        for j := 0 to nCols - 1 do
          SInfBufInt[j] := SInfBufByte[j];
      end
      else if StrataImgDoc.DataType = DATA_TYPE_INTEGER then
        BlockRead(SInf, SInfBufInt[0], nCols * sizeof(Smallint), nTransferred);
    end
    else
    begin
      for j := 0 to nCols - 1 do
        SInfBufInt[j] := 1;
    end;

    if LandImgDoc.DataType = DATA_TYPE_BYTE then
    begin
      BlockRead(LInf, LInfBufByte[0], nCols * sizeof(byte), nTransferred);
      for j := 0 to nCols - 1 do
        LInfBufInt[j] := LInfBufByte[j];
    end
    else if LandImgDoc.DataType = DATA_TYPE_INTEGER then
      BlockRead(LInf, LInfBufInt[0], nCols * sizeof(Smallint), nTransferred);

    for j := 0 to Length(SInfBufInt) - 1 do
      RegMark[SInfBufInt[j], LInfBufInt[j]] := 1; // The current type exists
  end;

  for k := 1 to Length(HasEdgeList) - 1 do
    HasEdgeList[k] := ((RegMark[k, 1] = 1) and (RegMark[k, 2] = 1));
  // indicates both types are there

  SInfBufByte := nil;
  LInfBufByte := nil;
  SInfBufInt := nil;
  LInfBufInt := nil;
  RegMark := nil;
end;

function SpatialContiguityAnalyst(Fname: string;
  var Contiguity: TContiguity): boolean;
const
  nRowsReadEveryTime: Smallint = 3;
var
  hUpdated: file;
  InfDoc: TImgDoc;
  IntBuf: array of Smallint;
  k, i, j: integer;
  irow, icol: integer;
  bContinue: boolean;
  ReadFileSuccess: boolean;
  bFound: boolean;
  Cmdstring: string;
  Tmp_UpdatedImageName: string;
  Failed: longbool;
  nCenter, nNeighbor, tmpint: Smallint;
  nProcRows: integer;
  nReadCount: integer;
  nTransfered: integer;
  nNextRowPosition, nOldPosition: integer;
  DoneTag: array of byte;
  intvarbuf: array of Smallint;
  nReadRows: integer;

begin
  Result := true;

  InfDoc := TImgDoc.CREATE;

  ReadFileSuccess := RetrieveRDCParameter(Fname, InfDoc);

  if not ReadFileSuccess then
  begin
    InfDoc.Free;
    Result := false;
    Exit;
  end;

  with InfDoc do
  begin
    if DataType = DATA_TYPE_REAL then
    begin
      ShowMessage
        ('The data type of region image should be either integer or byte binary.');
      Result := false;
      Free;
      Exit;
    end;
  end;

  try
    SetLength(Contiguity, Round(InfDoc.MaxValue) + 1);
    Tmp_UpdatedImageName := ExtractFilePath(Fname) +
      changeFileExt('Tmp_updated' + ExtractFileName(Fname), '.$id');
    // Tmp_UpdatedImageName := ExtractFilePath(Fname) + 'haohaohao.rst';

    Failed := false;

    if InfDoc.DataType = DATA_TYPE_BYTE then
      CreateTempImage_Int(Fname, Tmp_UpdatedImageName, InfDoc)
    else if InfDoc.DataType = DATA_TYPE_INTEGER then
      CreateTempImage_Int(Fname, Tmp_UpdatedImageName, InfDoc);

    filemode := 2; // read-write only
    AssignFile(hUpdated, Tmp_UpdatedImageName);
    // which has been converted to smallint image
    Reset(hUpdated, sizeof(Smallint));

    SetLength(DoneTag, Round(InfDoc.MaxValue) + 1);
    SetLength(intvarbuf, InfDoc.Cols);
    for i := 0 to InfDoc.Rows - 1 do { Scan the entire image }
    begin
      begin
        BlockRead(hUpdated, intvarbuf[0], InfDoc.Cols);
        // Read into an integer variable.
        for j := 0 to InfDoc.Cols - 1 do
          if DoneTag[intvarbuf[j]] = 0 then
          begin
            DoneTag[intvarbuf[j]] := 1;
            intvarbuf[j] := -intvarbuf[j];
          end;
        Seek(hUpdated, i * InfDoc.Cols);
        // set the file pointer back to the beginning of the row
        BlockWrite(hUpdated, intvarbuf[0], InfDoc.Cols);
        // dynamically update the image
      end;
    end;
    DoneTag := nil;
    intvarbuf := nil;
    SetLength(IntBuf, nRowsReadEveryTime * InfDoc.Cols);

    repeat
      bContinue := false;
      nProcRows := 0;
      nReadCount := 0;
      nTransfered := 0;
      nNextRowPosition := 0;
      // 1. up-down seeking
      while nProcRows < InfDoc.Rows do
      begin
        if not IdrisiAPI.IsValidProcId(process_id) then
        begin
          bTerminateApplication := true; // quit the entire application
          Exit;
        end;

        nOldPosition := nNextRowPosition; // save the current file pointer
        Seek(hUpdated, nNextRowPosition);
        BlockRead(hUpdated, IntBuf[0], nRowsReadEveryTime * InfDoc.Cols,
          nTransfered); // Read into an integer variable.
        nReadCount := nReadCount + 1;

        if nTransfered = nRowsReadEveryTime * InfDoc.Cols then
        begin
          nNextRowPosition := nReadCount * (nRowsReadEveryTime - 1) *
            InfDoc.Cols;
          nProcRows := nReadCount * (nRowsReadEveryTime - 1) + 1;
        end
        else if nTransfered < nRowsReadEveryTime * InfDoc.Cols then
        begin
          nProcRows := (nReadCount - 1) * (nRowsReadEveryTime - 1) +
            Round(nTransfered / InfDoc.Cols);
        end;

        nReadRows := Round(nTransfered / InfDoc.Cols);
        for i := 0 to nReadRows - 1 do
          for j := 0 to InfDoc.Cols - 1 do
          begin
            // look at its 8 neighbors
            if IntBuf[i * InfDoc.Cols + j] > 0 then
            begin
              if (i - 1 >= 0) then // Upper
              begin
                if (IntBuf[(i - 1) * InfDoc.Cols + j]
                  = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;
              end;

              if (i + 1 <= nReadRows - 1) then // lower
              begin
                if (IntBuf[(i + 1) * InfDoc.Cols + j]
                  = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;
              end;

              if (j - 1 >= 0) then // left
              begin
                if (IntBuf[i * InfDoc.Cols + (j - 1)
                  ] = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;
              end;

              if (j + 1 <= InfDoc.Cols - 1) then // right
              begin
                if (IntBuf[i * InfDoc.Cols + (j + 1)
                  ] = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;
              end;

              if (i - 1 >= 0) and (j + 1 <= InfDoc.Cols - 1) then // right upper
              begin
                if (IntBuf[(i - 1) * InfDoc.Cols + (j + 1)
                  ] = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;
              end;

              if (i + 1 <= nReadRows - 1) and (j + 1 <= InfDoc.Cols - 1) then
              // right lower
              begin
                if (IntBuf[(i + 1) * InfDoc.Cols + (j + 1)
                  ] = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;
              end;

              if (i + 1 <= nReadRows - 1) and (j - 1 >= 0) then // Left lower
              begin
                if (IntBuf[(i + 1) * InfDoc.Cols + (j - 1)
                  ] = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;

              end;

              if (i - 1 >= 0) and (j - 1 >= 0) then // Left upper
              begin
                if (IntBuf[(i - 1) * InfDoc.Cols + (j - 1)
                  ] = -(IntBuf[i * InfDoc.Cols + j])) then
                begin
                  IntBuf[i * InfDoc.Cols + j] := -(IntBuf[i * InfDoc.Cols + j]);
                  bContinue := true;
                  continue;
                end;
              end;

            end;
          end;
        Seek(hUpdated, nOldPosition);
        // set back the previous reading position for a writing update process
        BlockWrite(hUpdated, IntBuf[0], nRowsReadEveryTime * InfDoc.Cols,
          nTransfered); // Read into an integer variable.
      end;

      // 2. bottom-up seeking
      if bContinue then
      begin
        nNextRowPosition := (InfDoc.Rows - nRowsReadEveryTime) * InfDoc.Cols;
        nReadCount := 1;
        nProcRows := 0;
        while nProcRows < InfDoc.Rows do
        begin
          if not IdrisiAPI.IsValidProcId(process_id) then
          begin
            bTerminateApplication := true; // quit the entire application
            Exit;
          end;

          nOldPosition := nNextRowPosition; // save the current file pointer
          Seek(hUpdated, nNextRowPosition); // (i * InfDoc.Cols + j) * FIXLEN);
          BlockRead(hUpdated, IntBuf[0], nRowsReadEveryTime * InfDoc.Cols,
            nTransfered); // Read into an integer variable.
          nReadCount := nReadCount + 1;
          if nTransfered = nRowsReadEveryTime * InfDoc.Cols then
          begin
            nNextRowPosition :=
              (InfDoc.Rows - nReadCount * (nRowsReadEveryTime - 1) - 1) *
              InfDoc.Cols;
            if nNextRowPosition >= 0 then
              nProcRows := (nReadCount - 1) * (nRowsReadEveryTime - 1) + 1
            else
            begin
              nNextRowPosition := 0;
              nProcRows := InfDoc.Rows;
            end;
          end;

          nReadRows := Round(nTransfered / InfDoc.Cols);
          for i := nReadRows - 1 downto 0 do
            for j := InfDoc.Cols - 1 downto 0 do
            begin
              // look at its 8 neighbors
              if IntBuf[i * InfDoc.Cols + j] > 0 then
              begin
                if (i - 1 >= 0) then // Upper
                begin
                  if (IntBuf[(i - 1) * InfDoc.Cols + j]
                    = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;

                if (i + 1 <= nReadRows - 1) then // lower
                begin
                  if (IntBuf[(i + 1) * InfDoc.Cols + j]
                    = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;

                if (j - 1 >= 0) then // left
                begin
                  if (IntBuf[i * InfDoc.Cols + (j - 1)
                    ] = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;

                if (j + 1 <= InfDoc.Cols - 1) then // right
                begin
                  if (IntBuf[i * InfDoc.Cols + (j + 1)
                    ] = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;

                if (i - 1 >= 0) and (j + 1 <= InfDoc.Cols - 1) then
                // right upper
                begin
                  if (IntBuf[(i - 1) * InfDoc.Cols + (j + 1)
                    ] = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;

                if (i + 1 <= nReadRows - 1) and (j + 1 <= InfDoc.Cols - 1) then
                // right lower
                begin
                  if (IntBuf[(i + 1) * InfDoc.Cols + (j + 1)
                    ] = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;

                if (i + 1 <= nReadRows - 1) and (j - 1 >= 0) then // Left lower
                begin
                  if (IntBuf[(i + 1) * InfDoc.Cols + (j - 1)
                    ] = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;

                if (i - 1 >= 0) and (j - 1 >= 0) then // Left upper
                begin
                  if (IntBuf[(i - 1) * InfDoc.Cols + (j - 1)
                    ] = -(IntBuf[i * InfDoc.Cols + j])) then
                  begin
                    IntBuf[i * InfDoc.Cols + j] :=
                      -(IntBuf[i * InfDoc.Cols + j]);
                    bContinue := true;
                    continue;
                  end;
                end;
              end;
            end;
          Seek(hUpdated, nOldPosition);
          // set back the previous reading position for a writing update process
          BlockWrite(hUpdated, IntBuf[0], nRowsReadEveryTime * InfDoc.Cols,
            nTransfered); // Read into an integer variable.
        end;
      end;
    until not bContinue;

    IntBuf := nil;

    { The next step will rescan the updated image for figuring out if the region K is contiguous. }
    for k := 0 to Length(Contiguity) - 1 do
      Contiguity[k] := true; // initialized as trues
    SetLength(intvarbuf, InfDoc.Cols);
    Seek(hUpdated, 0); // set the file pointer to the head
    for i := 0 to InfDoc.Rows - 1 do { Rescan the entire image }
    begin
      BlockRead(hUpdated, intvarbuf[0], InfDoc.Cols);
      // Read into an integer variable.
      for j := 0 to InfDoc.Cols - 1 do
        if intvarbuf[j] > 0 then
          // if the region is contiguous, no possitive values exist any more.
          Contiguity[abs(intvarbuf[j])] := false;
    end;

    intvarbuf := nil;
    CloseFile(hUpdated);
    InfDoc.Free;
    filemode := 0; // read-only
    DeleteFile(Tmp_UpdatedImageName);
  except
    on Exception do
    begin
      ShowMessage
        ('Unexpected I/O error: Unable to automatically calculate the spatial contiguities of the regions in region image, '
        + Fname + '.');
      IntBuf := nil;
      CloseFile(hUpdated);
      Result := false;
      InfDoc.Free;
      if FileExists(Tmp_UpdatedImageName) then
        DeleteFile(Tmp_UpdatedImageName);
      Exit;
    end;
  end;
end;

procedure Main_Prog;

// var i : Integer;
// Starttime, endtime: Tdatetime;

begin

  Init;

  try

    Notify_Working;

    Get_Windows_Cmdln;

    // starttime := time;

    Geomod_Main; // geomod main subroutine.

    // endtime := time;

    // ShowMessage('Geomod successful for mask option! Total time used = ' + TimeToStr(endtime - starttime));

    Go_To_Heaven;

    Application.Terminate;

  except

    Error_Message(-999); { unknown run-time error }
    IdrisiAPI := nil;
    Application.Terminate;

  end;

end; { main_prog }

procedure Geomod_Main;
{ This is the main program which calls subroutines.
  Within the main time loop is a loop which cycles thru the regions.
  The structure of the main program is illustrated in a diagram (see Gil). }

var
  IYEAR: integer;
  IYEARWRT: integer;
  ID_RGN: integer;
  // **    ContinueYearLoop: boolean;
  // ProID: Integer;
  // BeginningTime, EndingTime;

  { Next is for cleaning up the previous contents of all output sheets. }

begin
  { DRCOUNT counts # of different sets of drivers for which geomod repeats.
    DRCOUNT is incremented in SREADER. }

  // BeginningTime = Time
  // Application.StatusBar = 'Hello, the beginning time is ' + Time

  if IdrisiAPI = nil then
    IdrisiAPI := CoIdrisiApiServer.CREATE;

  DRCOUNT := 0;

  { The SREADER subroutine reads all values necessary to start geomod.pas }
  /// /    Sreader;

  // ProID := IdrisiAPI.AllocateProcess;

  // IdrisiAPI.NotifyWorking(ProID);

  // just need to read one time for all loops.
  bTerminateApplication := false;

  repeat

    WRTOPEN := 0; // This is a flag used to open the output file.
    DRCOUNT := DRCOUNT + 1; // DRCOUNT counts # times GEOMOD loops.
    Sreader; { Call Sreader subroutine to read required parameters }
    if bTerminateApplication then
    begin
      CleanUp;
      Halt;
    end;

    if (LUBISTOP = 1) then
    begin
      // ShowMessage('Stopped after SREADER computed Lubrication Values');
      Exit;
    end; { End if }

    { Starting the time loop. }
    ContinueYearLoop := false; // True;  {Initialize}
    IYEAR := YEARBGN; { Initialize }

    repeat // (IYEAR < IYEAREND)

      // IdrisiAPI.PassProportion(ProID, (IYEAR - YEARBGN), (YEAREND - YEARBGN), (IYEAR - YEARBGN)/(YEAREND - YEARBGN));
      // IdrisiAPI.ProportionDone(ProID, (IYEAR - YEARBGN)/(YEAREND - YEARBGN));

      // If (IYEAR - YEARBGN)/(YEAREND - YEARBGN) <= 100.0 then proportion_done((IYEAR - YEARBGN)/(YEAREND - YEARBGN));

      YEAR := IYEAR;
      // YEAR := YEARBGN + IYEAR - 1;

      { If the new YEAR marks a new ERA, then call SNEWERA.
        The SNEWERA subroutine reads the geomod.se2 file which
        contains parameters that are specific to an era. }
      if (YEAR = YEARBGN) then
        IERA := 1; { modify here! use CURERA to replace IERA }
      // **          If ((IYEARSTP > 0) And (YEAR > ERAEND[IERA])) Or
      // **             ((IYEARSTP < 0) And (YEAR < ERAEND[IERA])) Or
      // **             (YEAR = YEARBGN) Then Snewera;

      { The IRGN loop cycles thru all regions, and calls the SCONVERT
        subroutine and the SFLUX subroutines for sucessive regions.
        The SCONVERT subroutine determines which land cells to change
        to which land use.
        The SFLUX subroutine uses the old land use and the new land use
        maps to create maps of cummulative and annual net carbon flux. }
      /// modify for sharings
      for ID_RGN := 1 to NRGN do
      begin
        Sconvert(ID_RGN);
        Sflux(ID_RGN);
        if bTerminateApplication then
        begin
          CleanUp;
          Halt;
        end;
      end;

      { The IYEARWRT loop with the SWRITER subroutine writes output files
        for the years requested in the geomod.se1 file. }
      if NYEARWRT <> 0 then
      begin
        for IYEARWRT := 1 to NYEARWRT do
          if (YEAR = YEARWRT[IYEARWRT]) or (YEAR = VALIDYR) or (YEAR = YEAREND)
          then
          begin
            if (YEAR = YEAREND) then  IfDisplay := 1; //T  - 12/19/19 - Display the results of the ending files, even if not displaying intermediate files
            Swriter; { Call Swriter procedure for output }
            if bTerminateApplication then
            begin
              CleanUp;
              Halt;
            end;
            break;
          end; { End If }
      end
      else
      begin
        if (YEAR = YEAREND) then
          begin
            IfDisplay := 1; //T  - 12/19/19 - Display the results of the ending files
            Swriter;
          end;
      end;

      if IYEARSTP > 0 then
      begin
        if YEAR < YEAREND then
          ContinueYearLoop := true
        else
          ContinueYearLoop := false;
      end
      else if IYEARSTP < 0 then
      begin
        if YEAR > YEAREND then
          ContinueYearLoop := true
        else
          ContinueYearLoop := false;
      end;
      IYEAR := IYEAR + IYEARSTP;

      if (YEAR - YEARBGN) / (YEAREND - YEARBGN) <= 1 then
      begin
        //proportion_done((YEAR - YEARBGN) / (YEAREND - YEARBGN));  //T - 11/1/19 - commented out; Doesn't make sense to use 2 different methods of progress reporting at once
        Pass_Proportion((YEAR - YEARBGN) / (YEAREND - YEARBGN),
          DRCOUNT, NLOOPS);
      end
      else
      begin
        //proportion_done(1);              //T - 11/1/19 - commented out; Doesn't make sense to use 2 different methods of progress reporting at once
        Pass_Proportion(1, DRCOUNT, NLOOPS);
      end;

    until not ContinueYearLoop; { Next IYEAR }

    // **CloseFile(Fp2);     //Close the Geomod.se2 file for this round of loop.
    { Gives option to run program again with different driver weights. }
  until DRCOUNT = NLOOPS;

  // Create Output image group files

  CreateOutputImageGroupFiles;
  CleanUp;

  { Write the completion message. }

  // Showmessage('Ha..Ha..., Congradulation! End of Geomod simulation');

end; { End of main program. }

procedure CreateOutputImageGroupFiles;
var
  IYEARWRT, IMAP, ILOOPS: integer;
  hGroupFile: TextFile;
  filename: string;
begin
  if NYEARWRT <> 0 then
  begin
    for IMAP := 1 to 4 do { 4 Kinds of output maps: LND, CBNYR, CBNCU, LUBI. }
      // FNUM = 30 + IMAP * 10
      if (WRTRST[IMAP] <> 0) then
      begin
        for ILOOPS := 1 to NLOOPS do
        begin
          filename := Trim(ResultImagesPath) +
            Copy(ExtractFileName(GmParameterFileName), 1,
            Length(ExtractFileName(GmParameterFileName)) -
            Length(ExtractFileExt(GmParameterFileName))) + '_' + PREFIXFINAL
            [IMAP] + '_' + inttostr(YEARBGN) + 'to' + inttostr(YEAREND) + '_' +
            inttostr(ILOOPS) + '.RGF';
          AssignFile(hGroupFile, filename);
          ReWrite(hGroupFile);

          Writeln(hGroupFile, NYEARWRT + 2);
          // add INITIAL and ENDYEAR landuse images
          Writeln(hGroupFile, Copy(ExtractFileName(FMAPNAME[3]), 1,
            Length(ExtractFileName(FMAPNAME[3])) -
            Length(ExtractFileExt(FMAPNAME[3])))); // initial landuse map
          for IYEARWRT := 1 to NYEARWRT do
            Writeln(hGroupFile, PREFIXFINAL[IMAP] + inttostr(YEARWRT[IYEARWRT])
              + '_' + inttostr(ILOOPS));

          Writeln(hGroupFile, PREFIXFINAL[IMAP] + inttostr(YEAREND) + '_' +
            inttostr(ILOOPS));

          CloseFile(hGroupFile);
        end;
      end;
  end;
end;

procedure Sflux(IRGN: integer);

{ ************************************************************
  subroutine Sflux
  ************************************************************
  This SFLUX subroutine determines the amount of carbon
  flux to the atmosphere by comparing the old land use map to
  the new land use map.
  This subroutine computes only ONE carbon map, and
  it is important also because it copies MAPLND1 into MAPLND2. }

{ Variable Declaration. }

var
  i: integer;
  // ICCAT: Integer;
  MAXFLXYR, MAXFLXCU: Single;
  FLXYR, FLXCU: array of Single;
  // F: Textfile; //**change it as public varible
  row, col: integer;

begin
  // ShowMessage('Calling Sflux...');
  try
    SetLength(MAPFLXYR, NROW + 1, NCOL + 1);
    SetLength(MAPFLXCU, NROW + 1, NCOL + 1);
    SetLength(FLXYR, NRGN + 1);
    SetLength(FLXCU, NRGN + 1);

    // Application.StatusBar = 'Calling SFLUX...'
    if (DOCBN <> 0) then
    begin
      { If it is the 1st time thru the loop, then initialize variables. }
      if (YEAR = YEARBGN) and (IRGN = 1) then
      begin
        if DRCOUNT = 1 then
        begin
          Assign(Fc, Trim(ResultImagesPath) +
            changeFileExt(ExtractFileName(GmParameterFileName), '.wkc'));
          ReWrite(Fc);
          { Header for Lotus output. }
          Writeln(Fc, 'This output file (*.wkc) shows simulated carbon flux');
          { The first row }
          Writeln(Fc, 'in 1000 tons of carbon per year by region by year.');
          Writeln(Fc, 'Postive  values indicate fluxes to the atmosphere.');
          Writeln(Fc, 'Negative values indicate fluxes from atmosphere.x');
        end
        else
        begin
          Assign(Fc, Trim(ResultImagesPath) +
            changeFileExt(ExtractFileName(GmParameterFileName), '.wkc'));
          append(Fc);
        end;

        Writeln(Fc);
        Writeln(Fc, '--------------------------------------------------');
        Writeln(Fc, '//the following is for run # ' + inttostr(DRCOUNT));

        Writeln(Fc, '        REGION NAMES');
        Write(Fc, 'YEAR  ');

        for i := 1 to NRGN do
        begin
          Write(Fc, Format('%12s', [FRGNNAME[i]])); { Header for Lotus output }
          FLXCU[i] := 0;
        end; { Next i }
        Writeln(Fc); { Wirte a line-end mark at the 5th row }

        for row := 1 to NROW do
        begin
          if (row mod ROW_RANGE) = 0 then
            if not IdrisiAPI.IsValidProcId(process_id) then
            begin
              bTerminateApplication := true; // quit the entire application
              Exit;
            end;

          for col := 1 to NCOL do
          begin
            if (MAPLND1[row, col] = TYPEVAL[1]) or
              (MAPLND1[row, col] = TYPEVAL[2]) then
            begin
              MAPFLXYR[row, col] := 0;
              MAPFLXCU[row, col] := 0;
            end
            else
            begin
              MAPFLXYR[row, col] := MAPLND1[row, col];
              MAPFLXCU[row, col] := MAPLND1[row, col];
            end;
          end; { Next col }
        end; { Next row }
        MAXFLXYR := 0;
        MAXFLXCU := 0;
      end; { End If }
      FLXYR[IRGN] := 0;

      { Next two loops compute all cells within IRGN. }
      // **Setlength(CBN, NRGN + 1, 40 + 1); //remove it in the new version.

      MAXFLXYR := 0; // initialize
      MAXFLXCU := 0; // initialize

      if IfFixedCBrate <> 1 then
        SetLength(CBNBIORATEMAP, 2, NCOL + 1);

      for row := RGNNORTH[IRGN] to RGNSOUTH[IRGN] do
      begin
        if (row mod ROW_RANGE) = 0 then
          if not IdrisiAPI.IsValidProcId(process_id) then
          begin
            bTerminateApplication := true; // quit the entire application
            Exit;
          end;

        if IfFixedCBrate <> 1 then
          CheckAndReadMap(CBrateImage, NROW, NCOL, row - 1, row - 1,
            CBNBIORATEMAP);

        for col := RGNWEST[IRGN] to RGNEAST[IRGN] do
        begin
          if not((MAPRGN[row, col] <> RGNVAL[IRGN]) or
            (MAPLND1[row, col] = NODATA) { Or
              ((DSRTMAP = 1) And (MAPDSRT[row, col] = DSRTVALU)) } ) then
          begin
            { The next loop searches for the correct carbon category.
              As of 3 February 1993, GEOMOD does only 1 carbon map. }

            // Note: here the meaning of MAPCBN[1, rol, col] has been change to the amount of biomass rather than the type of vegetation.
            { The next lines compute the carbon release. }
            // MAPFLXYR[row, col] := CBN[IRGN, ICCAT] * CELLAREA[IRGN] *
            // MATCBN[IRGN, MAPLND1[row, col], MAPLND2[row, col]] / 100;

            if IfFixedCBrate = 1 then
              MAPFLXYR[row, col] := RCBN2BIO[IRGN] * MAPCBN[1, row, col] *
                CELLAREA[IRGN] * MATCBN[IRGN, MAPLND1[row, col],
                MAPLND2[row, col]]
            else
              MAPFLXYR[row, col] := CBNBIORATEMAP[1, col] * MAPCBN[1, row, col]
                * CELLAREA[IRGN] * MATCBN[IRGN, MAPLND1[row, col],
                MAPLND2[row, col]];

            // MAPFLXYR[row, col] := CBNBIORATEMAP[row, col] * MAPCBN[1, row, col] * CELLAREA[IRGN] *
            // MATCBN[IRGN, MAPLND1[row, col], MAPLND2[row, col]];

            MAPFLXCU[row, col] := MAPFLXCU[row, col] + MAPFLXYR[row, col];

            FLXYR[IRGN] := FLXYR[IRGN] + MAPFLXYR[row, col];

            FLXCU[IRGN] := FLXCU[IRGN] + FLXYR[IRGN];

            { The next lines write to the screen the maximum change in
              any cell of the carbon map.  The max is important to make
              pretty picutres. }

            if (MAXFLXYR < MAPFLXYR[row, col]) then
              MAXFLXYR := MAPFLXYR[row, col];

            if (MAXFLXCU > MAPFLXCU[row, col]) then
              MAXFLXCU := MAPFLXCU[row, col];

            (*
              For ICCAT := 1 To NCCAT[4] do
              begin
              //here the meaning of MAPCBN[1, rol, col] has been change to the amount of biomass rather than the type of vegetation.
              If (MAPCBN[1, row, col] = CBNCAT[ICCAT]) Then
              begin
              {The next lines compute the carbon release.}
              MAPFLXYR[row, col] := CBN[IRGN, ICCAT] * CELLAREA[IRGN] *
              MATCBN[IRGN, MAPLND1[row, col], MAPLND2[row, col]] / 100;

              MAPFLXCU[row, col] := MAPFLXCU[row, col] + MAPFLXYR[row, col];

              FLXYR[IRGN] := FLXYR[IRGN] + MAPFLXYR[row, col];

              FLXCU[IRGN] := FLXCU[IRGN] + FLXYR[IRGN];

              {The next lines write to the screen the maximum change in
              any cell of the carbon map.  The max is important to make
              pretty picutres.}

              If (MAXFLXYR < MAPFLXYR[row, col]) Then MAXFLXYR := MAPFLXYR[row, col];

              If (MAXFLXCU > MAPFLXCU[row, col]) Then MAXFLXCU := MAPFLXCU[row, col];

              Break; {Exit for loop}

              End; {End If}

              end; {Next ICCAT}
            *)
            { Next is an end of year update of the land use maps. }
            MAPLND1[row, col] := MAPLND2[row, col];

            { Next line increments the map of # years since last land change. }
            MAPYEAR[row, col] := MAPYEAR[row, col] + 1;

            { The next 4 lines scale the carbon output map down to make pretty pictures. }
            MAPFLXYR[row, col] := MAPFLXYR[row, col] / CBNDIV;
            if (YEAR = YEAREND) then
              MAPFLXCU[row, col] := MAPFLXCU[row, col] / CBNDIV;
          end; { End If }
        end; { Next col }
      end; { Next row }

      if IfFixedCBrate <> 1 then
        CBNBIORATEMAP := nil;

      { The following writes the GEOMODC.WKS file, start with the 6th row. }
      if (IRGN = NRGN) then
      begin
        Write(Fc, YEAR);
        for i := 1 to NRGN do
          Write(Fc, Format('%12.2f', [FLXYR[i]]));
        Writeln(Fc);
        Writeln(Fc); { The 7th row is a blank row }
        if (YEAR = YEAREND) then
        begin
          Writeln(Fc, 'Final MAXFLXYR = ', Format('%12.2f', [MAXFLXYR]));
          Writeln(Fc, 'Final MAXFLXCU = ', Format('%12.2f', [MAXFLXCU]));
          Writeln(Fc, 'Units in MAPFLXYR and final MAPFLXCU are:');
          Writeln(Fc, '  ', Format('%12.2f', [1000 / CBNDIV]),
            ' tons of carbon per raster.');
          CloseFile(Fc);
        end; { End If }
      end; { End If }

      // IF (YEAR = YEAREND) then CloseFile(Fc);
      // IF (DRCOUNT = NLOOPS) then CloseFile(Fc);
    end;
  except
    on EOutOfMemory do
    begin
      Application.MessageBox
        ('The modeling failed due to the size of the input images appears to be too large. Please reduce the input image size and/or the number of driver images in use.!',
        'Error in GEOMOD');
      Halt;
    end;
  end;
end; { end of Sflux precedure }

procedure Sreader;
{ ++++++++++++++++++++++++++++++++++++++++++++++++++++++
  Start Subroutines.
  Each subroutine writes its contents to a s*.out file.
  **************************************
  subroutine SREADER
  **************************************
  The SREADER subroutine reads the file geomod.se1, and
  the political region map, the initial land use map,
  the initial carbon map, the permanent driver map(s), any
  era specific maps, and the validation map.
  READER initializes other variables by calling subroutines
  entitled SBOARDER, SINITIAL, and SFRICT. }

var
  GMParaFile: TextFile;
  Lubfilehandle: TextFile;
  Head: array [1 .. 5] of string;
  TmpStr: string[42];
  TmpLongStr: string;
  TmpPos: integer;
  // Head: array[1..5] of String;
  IERA, IRGN, i, IMAP, ILOOPS: integer;
  row, col: integer;
  // NMAPVLD: integer;
  found: boolean;
  IDCAT: integer;
  ITYPE: integer;
  ImgDoc: TImgDoc;
  RegionContig: TContiguity;
  CellUnitArea: double;
  FixedCBrate, FixedFluxrate: Single;
  CBrateDoc, RegionDoc, FluxrateDoc: TImgDoc;
  tmpimage: TSingleMap;
  FROM, TTO: integer;
  { TO be changed into TOO, because of the variable conflict }
  NAME2: string[21];
  HISRGN2: integer;
  // IMAPC: Integer;
  ERABGNS, ERAENDS: integer;
  // CBN() As Single   // Carbon within carbon category (1000 tons/square kilometer 40*40)
  ErrInfo: string;
  //PErrInfo: PChar; //T - 11/1/19 - commented out; changing to our usual error reporting methods

label Map_Reading;

begin

  // **DRCOUNT := DRCOUNT + 1;    //DRCOUNT counts # times GEOMOD loops.
  if (DRCOUNT = 1) then
    LUBIDO := 0;

  try
    if (DRCOUNT > 1) then
      goto Map_Reading;
    // **If (DRCOUNT > 1) Then Exit; //skip sreader

    if IdrisiAPI = nil then
      IdrisiAPI := CoIdrisiApiServer.CREATE;
    // ******** Read Part 1 ******************
    ReadSuccess := true; { Initialize }

    AssignFile(GMParaFile, GmParameterFileName);
    // AssignFile(GMParaFile, 'c:\temp\geomodtrail01.txt');
    /// /   AssignFile(GMParaFile, 'D:\hao\geomaps\geomod.se1');
    Reset(GMParaFile);

    { First to read general simulation parameters }
    for i := 1 to 5 do
      Readln(GMParaFile, Head[i]);

    Readln(GMParaFile);
    Readln(GMParaFile, TmpStr,
      { 'JULIAN YEAR TO BEGIN GEOMOD, INCLUSIVE:    ', } YEARBGN);
    Readln(GMParaFile, TmpStr,
      { 'JULIAN YEAR TO END   GEOMOD, INCLUSIVE:    ', } YEAREND);
    Readln(GMParaFile, TmpStr,
      { 'TIME STEP IN JULIAN YEARS             :    ', } IYEARSTP);

    NERA := 1; // always = 1 in the new version
    SetLength(ERABGN, NERA + 1);
    { compatible with Delphi about dynamic array definition }
    SetLength(ERAEND, NERA + 1); { Leave ERAEND[0] not used for compatibility }
    ERABGN[1] := YEARBGN;
    ERAEND[1] := YEAREND;

    Readln(GMParaFile);
    Readln(GMParaFile, TmpStr,
      { '# NEIGHBORS AWAY TO SEARCH,0=NO NIBBLE:    ', } NEIGHB);
    HISEPSLN := 0; // always be 0 now
    Readln(GMParaFile, TmpStr,
      { 'WANT TO WRITE DEBUGGING OUTPUT,YES=1  :    ', } DEBUGOUT);

    // ******** Read Part 2 ******************
    { Next is to read the region map parameters }
    SetLength(FMAPXT, IDR_MAXMAPNUM);
    SetLength(FMAPNAME, IDR_MAXMAPNUM);
    for i := 0 to Length(FMAPXT) - 1 do
      FMAPXT[1] := 1; // Extension always be 1, meaning the .rst file.
    Readln(GMParaFile, TmpStr,
      { 'EXTENSION, AND NAME OF THE REGION MAP :    ', } FMAPNAME[1]);
    // exteinsion of image file will be always .rst idrisi raster file.

    if UpperCase(Trim(FMAPNAME[1])) <> 'N/A' then
    begin
      TmpStr := Trim(FMAPNAME[1]);
      FMAPNAME[1] := ReturnCompleteFileName(READ_FILE, Trim(FMAPNAME[1]),
        '.rst'); // Convert to .rst file.
      // following to compute the paramters about regions, such as number of row, colunm, and regions.
      if FMAPNAME[1] = '' then
      begin
        ErrInfo := 'Strata/Mask image, ' + TmpStr + ', not found';
        //PErrInfo := PChar(ErrInfo);
        //Application.MessageBox(PErrInfo, 'Error in GEOMOD');
        mercury_send_string1(ErrInfo);
        error_message(-1164);
        CleanUp;
        Halt;
      end;

      ImgDoc := TImgDoc.CREATE;
      if not RetrieveRDCParameter(FMAPNAME[1], ImgDoc) then
      begin
        CleanUp;
        Halt;
      end;

      with ImgDoc do
      begin
        NROW := Rows;
        NCOL := Cols;
        if LegendCats > 0 then
        begin
          if Legend_Code[0] = 0 then
            NRGN := LegendCats - 1
          else
            NRGN := LegendCats;
        end
        else
          NRGN := Round(MaxValue);
      end;
    end
    else
      NRGN := 1;

    { Set the demensions of dynamic arrays about region info }
    SetLength(RGNVAL, NRGN + 1);
    // NRGN + 1 just for compatible with VB and Fortran
    SetLength(CONTIG, NRGN + 1);
    SetLength(HASEDGE, NRGN + 1);
    SetLength(CELLAREA, NRGN + 1);
    SetLength(FRGNNAME, NRGN + 1);
    if UpperCase(Trim(FMAPNAME[1])) <> 'N/A' then
    begin
      with ImgDoc do
      begin
        if LegendCats = 0 then
          for i := 1 to NRGN do
          begin
            FRGNNAME[i] := 'Region ' + inttostr(i);
            RGNVAL[i] := i;
          end
        else
        begin
          if Legend_Code[0] = 0 then
            for i := 1 to NRGN do
            begin
              FRGNNAME[i] := Legend_Caption[i];
              RGNVAL[i] := Legend_Code[i];
            end
          else
            for i := 1 to NRGN do
            begin
              FRGNNAME[i] := Legend_Caption[i - 1];
              RGNVAL[i] := Legend_Code[i - 1];
            end;
        end;

        if Trim(RefUnits) = 'm' then
          CellUnitArea := Power(Round(((MaxX - MinX) / Cols) * 0.001), 2)
          // square kilometer
        else
          CellUnitArea := 1.0; // Unit, square kilometer

        if CellUnitArea = 0 then
          CellUnitArea := 1.0;

        for i := 1 to NRGN do
          CELLAREA[i] := CellUnitArea;

        if NEIGHB = 0 then
          for i := 1 to NRGN do
            CONTIG[i] := 0
        else
        begin
          SpatialContiguityAnalyst(FMAPNAME[1], RegionContig);
          for i := 1 to NRGN do
            CONTIG[i] := ord(RegionContig[i]);
        end;
      end;
    end
    else
    begin
      FRGNNAME[1] := 'Region 1';
      RGNVAL[1] := 1;
      CELLAREA[1] := 1.0;
      CONTIG[1] := ord(not(NEIGHB = 0));
    end;

    OCEANRGN := 0; // always be 0 as default
    OCEAN := 0; // always be 0 as default
    STUDYOUT := 0; // always be 0 as default

    { Next is to write the constraint map parameters }
    DSRTMAP := 0; // always no desert map
    FMAPNAME[2] := ''; // empty to desert image.
    DSRTVALU := 0;
    DSRTOUT := 0;

    { Next is to write the initial landuse map parameters }
    Readln(GMParaFile, TmpStr,
      { 'EXTENSION, INITIAL LAND USE MAP       :    ', } FMAPNAME[3]);

    TmpStr := Trim(FMAPNAME[3]);
    FMAPNAME[3] := ReturnCompleteFileName(READ_FILE, Trim(FMAPNAME[3]), '.rst');
    // Convert to .rst file.
    if FMAPNAME[3] = '' then
    begin
      ErrInfo := 'Initial landuse image, ' + TmpStr + ', not found';
      //PErrInfo := PChar(ErrInfo);
      //Application.MessageBox(PErrInfo, 'Error in GEOMOD');
      mercury_send_string1(ErrInfo); //T - 11/1/19
      error_message(-1164);          //T - 11/1/19
      CleanUp;
      Halt;
    end;

    // added in August
    if UpperCase(Trim(FMAPNAME[1])) = 'N/A' then
    begin
      // following to compute the paramters about regions, such as number of row, colunm, and regions.
      ImgDoc := TImgDoc.CREATE;
      if not RetrieveRDCParameter(FMAPNAME[3], ImgDoc) then
      begin
        CleanUp;
        Halt;
      end;

      NROW := ImgDoc.Rows;
      NCOL := ImgDoc.Cols;
    end;
    NTYPE := 2; // currently always be 2.

    // ADDED IN NOVEMBER 8, 2003 TO DEAL WITH NO-EDGE PROBLEM
    if NEIGHB = 0 then
      for i := 1 to NRGN do
        HASEDGE[i] := false
    else
      LandTypeEdgeAnalyst(FMAPNAME[1], FMAPNAME[3], HASEDGE);

    SetLength(TYPEVAL, NTYPE + 1);
    TYPEVAL[1] := 1; // as default (forest) it is always equal to 1 or 2.
    TYPEVAL[2] := 2; // non forest area
    NODATA := 0;
    BLANKMAP := 0;
    if NEIGHB = 0 then
      SEED := 0
    else
      SEED := 1;

    { Next is to write bimass map parameters }
    { Here makes an adjustment for the output order }
    Readln(GMParaFile, TmpStr,
      { 'DO CARBON ANALYSIS? 1=YES, 0=NO       :    ', } DOCBN);
    if DOCBN = 1 then
    begin
      NMAPC := 1;
      Readln(GMParaFile, TmpStr,
        { 'NAME OF INITIAL BIOMAS MAP :    ', } FMAPNAME[4]); // May be 'N/A'

      TmpStr := Trim(FMAPNAME[4]);
      FMAPNAME[4] := ReturnCompleteFileName(READ_FILE, Trim(FMAPNAME[4]),
        '.rst'); // Convert to .rst file.
      if FMAPNAME[4] = '' then
      begin
        ErrInfo := 'Environmental resource image, ' + TmpStr + ', not found';
        //PErrInfo := PChar(ErrInfo);
        //Application.MessageBox(PErrInfo, 'Error in GEOMOD');
        mercury_send_string1(ErrInfo); //T - 11/1/19
        error_message(-1164);          //T - 11/1/19
        CleanUp;
        Halt;
      end;

      // ** the following is moved from the parameter file 2 for being more integrated.
      CBrateDoc := TImgDoc.CREATE;
      FluxrateDoc := TImgDoc.CREATE;

      SetLength(MATCBN, NRGN + 1, NTYPE + 1, NTYPE + 1);
      SetLength(RCBN2BIO, NRGN + 1);
      Readln(GMParaFile, TmpStr,
        { 'USE FIXED Carb-Bio RATIO?(1=YES, 0=NO):' } IfFixedCBrate);
      if IfFixedCBrate = 1 then
      begin
        Readln(GMParaFile, TmpStr,
          { 'IF YES ABOVE, THE FIXED C/B RATIO IS   : } FixedCBrate);
        for IRGN := 1 to NRGN do
          RCBN2BIO[IRGN] := FixedCBrate;
      end
      else
      begin
        Readln(GMParaFile, TmpStr,
          { 'IF NO ABOVE, C/B RATIO READ FROM IMAGE:' } CBrateImage);
        // must be referred to the region image FMAPNAME[1];
        CBrateImage := ReturnCompleteFileName(READ_FILE,
          Trim(CBrateImage), '.rst');
        if not RetrieveRDCParameter(CBrateImage, CBrateDoc) then
        begin
          CleanUp;
          Halt;
        end;
        if (CBrateDoc.Rows <> NROW) or (CBrateDoc.Cols <> NCOL) then
        begin
          ShowMessage
            ('The numbers of rows and/or columns of the carbon-biomass image do not match the region image.');
          CleanUp;
          Halt;
        end;
        // Setlength(CBNBIORATEMAP, NROW + 1, NCOL + 1);
        // CheckAndReadMap(CBrateImage, NROW, NCOL, CBNBIORATEMAP);
      end;

      Readln(GMParaFile, TmpStr,
        { 'USE FIXED CARBON FLUX RATE?(1=Y, 0=N): ' } IfFixedFluxRate);
      if IfFixedFluxRate = 1 then
      begin
        Readln(GMParaFile, TmpStr,
          { 'IF YES ABOVE, FIXED FLUX RATE IS        :' } FixedFluxrate);
        for IRGN := 1 to NRGN do
          for FROM := 1 to NTYPE do
            for TTO := 1 to NTYPE do
              if (FROM = TTO) then
                // MATCBN[IRGN, FROM, TTO] := 1.0
                MATCBN[IRGN, FROM, TTO] := 0.0
              else
              begin
                if FROM = 1 then
                  MATCBN[IRGN, FROM, TTO] := abs(FixedFluxrate)
                  // type 1 convered to type 2 always accompany the possitive release of carbon into the atmoaphere.
                else if FROM = 2 then
                  MATCBN[IRGN, FROM, TTO] := -abs(FixedFluxrate);
              end;
      end
      else
      begin
        Readln(GMParaFile, TmpStr,
          { 'IF NO ABOVE, FLUX RATE READ FROM IMAGE:' } FluxrateImage);
        // must be referred to the region image FMAPNAME[1];
        FluxrateImage := ReturnCompleteFileName(READ_FILE,
          Trim(FluxrateImage), '.rst');
        if not RetrieveRDCParameter(FluxrateImage, FluxrateDoc) then
        begin
          CleanUp;
          Halt;
        end;

        if (FluxrateDoc.Rows <> NROW) or (FluxrateDoc.Cols <> NCOL) then
        begin
          ShowMessage
            ('The numbers of rows and/or columns of the carbon flux rate image do not match the region image.');
          CleanUp;
          Halt;
        end;
        // Setlength(FluxPercMap, NROW + 1, NCOL + 1);
        // CheckAndReadMap(FluxrateImage, NROW, NCOL, FluxPercMap);
      end;
      CBrateDoc.Free;
      FluxrateDoc.Free;
      // *******, incorporation finished.
    end
    else
    begin
      NMAPC := 0;
      FMAPNAME[4] := '';
    end;

    // need to think more about it here.
    // **       SetLength(NCCAT, 4 + IDR_DIMINCR);  // currently, just support a biomass/carbon map;
    // **       Readln(GMParaFile, TmpStr, {'# CATEGORIES OF INITIAL BIOMASS MAP   :    ',} NCCAT[4]);
    // **       NCCAT[4] := 255;

    // If NMAPC <> 0 then
    // Readln(GMParaFile, '# CATEGORIES OF INITIAL BIOMASS MAP   :    ', NCCAT[4])
    // Else
    // Readln(GMParaFile, '# CATEGORIES OF INITIAL BIOMASS MAP   :    ', '0');

    // **       Readln(GMParaFile, TmpStr, {'ADJUSTMENT TO DIVIDE CARBON OUTPUT MAP:    ',} CBNDIV);
    CBNDIV := 1; // always 1

    { Next is to write driver maps parameters }
    { Here makes an adjustment for the output order }
    Readln(GMParaFile, TmpStr,
      { 'READ/CMP SUITABILITY SCORES(0=RD,1=CP):    ', } SUITOPTION);
    Readln(GMParaFile, TmpStr,
      { '# OF RUNS AT ONE TIME                 :    ', } NLOOPS);
    if SUITOPTION = READ_SUIT then
    begin
      SetLength(FRICTIONMAPNAME, NLOOPS + 1);
      for i := 1 to NLOOPS do
      begin
        Readln(GMParaFile, TmpStr, FRICTIONMAPNAME[i]);

        TmpStr := Trim(FRICTIONMAPNAME[i]);
        FRICTIONMAPNAME[i] := ReturnCompleteFileName(READ_FILE,
          Trim(FRICTIONMAPNAME[i]), '.rst'); // Convert to .rst file.
        if FRICTIONMAPNAME[i] = '' then
        begin
          ErrInfo := 'Suitability image, ' + TmpStr + ', not found';
          //PErrInfo := PChar(ErrInfo);
          //Application.MessageBox(PErrInfo, 'Error in GEOMOD');
          mercury_send_string1(ErrInfo); //T - 11/1/19
          error_message(-1164);          //T - 11/1/19
          CleanUp;
          Halt;
        end;
      end;
      NMAPP := 0;
    end
    else
    begin
      Readln(GMParaFile, TmpStr,
        { 'NUMBER OF PERMANENT DRIVER MAPS       :    ', } NMAPP);
      NDCATMAX := 0;
      for IMAP := 4 + NMAPC to 3 + NMAPC + NMAPP do
      begin
        Readln(GMParaFile, TmpStr,
          { 'EXTENSION, 1ST DRIVER MAP             :    ', } FMAPNAME[IMAP]);

        TmpStr := Trim(FMAPNAME[IMAP]);
        FMAPNAME[IMAP] := ReturnCompleteFileName(READ_FILE,
          Trim(FMAPNAME[IMAP]), '.rst'); // Convert to .rst file.
        if FMAPNAME[IMAP] = '' then
        begin
          ErrInfo := 'Driver image, ' + TmpStr + ', not found';
          //PErrInfo := PChar(ErrInfo);
          //Application.MessageBox(PErrInfo, 'Error in GEOMOD');
          mercury_send_string1(ErrInfo); //T - 11/1/19
          error_message(-1164);          //T - 11/1/19
          CleanUp;
          Halt;
        end;

        if not RetrieveRDCParameter(FMAPNAME[IMAP], ImgDoc) then
          Exit;
        if ImgDoc.MaxValue > NDCATMAX then
          NDCATMAX := Round(ImgDoc.MaxValue);
      end;

      Readln(GMParaFile); { 'SET OF DRIVER WEIGHTS FOR EACH LOOP THRU GEOMOD' }
      Readln(GMParaFile); { for skip the row about the description of drivers }

      { Set the demensions of the dynamic array, drivewt }
      SetLength(DRIVEWT, NLOOPS + 1, 3 + NMAPC + NMAPP + 1);
      { adding 1 demension just for compatibility }
      for ILOOPS := 1 to NLOOPS do { Current only allow a loop }
      begin
        for IMAP := 1 to NMAPP do
          Read(GMParaFile, DRIVEWT[ILOOPS, IMAP]);
        Readln(GMParaFile);
        { Read(GMParaFile, Format(' %7.4f   ', [DRIVEWT[DRCOUNT, IMAP]])); Readln(GMParaFile); }
      end;

      { The loop below is to compute FMAPPWTT - the sum of all weights. }
      { The original code here seems a little redundant?! }

      // FMAPPWTT := 0;
      SetLength(FMAPPWT, NLOOPS + 1, 3 + NMAPC + NMAPP + 1);
      SetLength(FMAPPWTT, NLOOPS + 1);
      for ILOOPS := 1 to NLOOPS do { Current only allow a loop }
        for IMAP := 4 + NMAPC to 3 + NMAPC + NMAPP do
        begin
          FMAPPWT[ILOOPS, IMAP] := DRIVEWT[ILOOPS, IMAP - 3 - NMAPC]; // DRCOUNT
          FMAPPWTT[ILOOPS] := FMAPPWTT[ILOOPS] + FMAPPWT[ILOOPS, IMAP];
          { Records sum of all weights. }
        end;
    end;

    DRIVEWT := nil;
    { Next is to write era specific maps parameters }
    // Readln(GMParaFile);
    // Readln(GMParaFile); {'---INFORMATION ON ERA SPECIFIC MAPS(e.g. Roads)---'}
    // **       Readln(GMParaFile, TmpStr, {'# OF ERA SPECIFIC MAPS EVERY ONE ERA  :    ',} NMAPE);
    NMAPE := 0; // always be 1 in the current version.
    (*
      If (NMAPE > 0) then
      begin
      {To set the demensions of the dynamic arrays about era specific maps, although currently they will not be used in the model}
      SetLength(FMAPEX, 3 + NMAPC + NMAPP + NMAPE + 1, NERA + 1); {adding an extra demesion is for compatibility with VB/Fortran code. the array element[0, 0] is left unused.}
      SetLength(FMAPE, 3 + NMAPC + NMAPP + NMAPE + 1, NERA + 1);
      SetLength(FMAPEWT, 3 + NMAPC + NMAPP + NMAPE + 1, NERA + 1);

      For IERA := 1 to NERA do
      For IMAP := 4 + NMAPC + NMAPP To 3 + NMAPC + NMAPP + NMAPE do
      If (IMAP = 4 + NMAPC + NMAPP) then
      begin
      Readln(GMParaFile, TmpStr, {'EXT, NAME, WEIGHT OF 1ST MAP IN ERA ' + IntToStr(IERA)+ ' :    ',}
      FMAPEX[IMAP, IERA], {'  ',} TmpLongStr);
      TmpPos := Pos('.rst', TmpLongStr);
      If TmpPos = 0 then
      begin
      beep;
      ShowMessage('found error in input parameter file 1. The extension of Specific Map '
      + IntToStr(IMAP - 3 - NMAPC - NMAPP) + ' of ' + 'era ' + IntToStr(IERA)
      + ' should be ''.rst''.');
      ReadSuccess := False;
      Exit; {anormal termination}
      end;
      FMAPE[IMAP, IERA] := Copy(TmpLongStr, 1, TmpPos + 4);
      FMAPEWT[IMAP, IERA] := StrToInt(Copy(TmpLongStr, TmpPos + 5, Length(TmpLongStr) - TmpPos - 5));
      end;
      end;
    *)
    { Next is to read validation map parameters }
    // Readln(GMParaFile);
    Readln(GMParaFile, TmpStr,
      { 'WHETHER TO DO VALIDATION, 1=YES, 0=NO :    ', } USEVALID);
    if USEVALID = 1 then
      VALIDYR := YEAREND
    else
      VALIDYR := 0;
    // as default, always take the ending year as the validation year.
    if (VALIDYR <> 0) then
    begin
      NMAPVLD := 1;
      Readln(GMParaFile, TmpStr,
        { 'EXT & NAME OF VALIDATION MAP          :    ', }
        FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1]);

      TmpStr := Trim(FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1]);
      FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1] :=
        ReturnCompleteFileName(READ_FILE,
        Trim(FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1]), '.rst');
      // Convert to .rst file.
      if FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1] = '' then
      begin
        ErrInfo := 'Validation image, ' + TmpStr + ', not found';
        //PErrInfo := PChar(ErrInfo);
        //Application.MessageBox(PErrInfo, 'Error in GEOMOD');
        mercury_send_string1(ErrInfo); //T - 11/1/19
        error_message(-1164);          //T - 11/1/19
        CleanUp;
        Halt;
      end;

      VLDOUT := 0;
      if UpperCase(Trim(FMAPNAME[1])) <> 'N/A' then
      begin
        CrossTableCompute(FMAPNAME[1], FMAPNAME[3], '', NCELLBGN);
        CrossTableCompute(FMAPNAME[1], FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1],
          '', NCELLEND);
      end
      else
      begin
        CalcLandTypeQuantityWithoutRegionImg(FMAPNAME[3], NCELLBGN);
        CalcLandTypeQuantityWithoutRegionImg
          (FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1], NCELLEND);
      end;
    end
    else
    begin
      NMAPVLD := 0;
      SetLength(NCELLBGN, NRGN + 1, NTYPE + 1);
      SetLength(NCELLEND, NRGN + 1, NTYPE + 1);
      Readln(GMParaFile, TmpStr);
      // , tmpstr); // 'TABLE 1     //ERA LAND USE CHANGE INFORMATION'
      Readln(GMParaFile, TmpStr);
      // , tmpstr); {, '                                      ', // 38 spaces, 16 spaces for region name
      // 'LAND USE TYPE 1', '     ', 'LAND USE TYPE 2'}
      Readln(GMParaFile, TmpStr);
      // , tmpstr); { 'RGNVAL  ', '     REGION NAME  ', '# CELLS     ',
      // 'BEGIN       ', 'END     ', 'BEGIN       ', 'END');}
      // to read the quantity information of landuse change entered by the user.

      for IRGN := 1 to NRGN do
      begin
        // ShowMessage('Stop SNEWERA...');
        read(GMParaFile, RGNV, NAME2, HISRGN2);
        for ITYPE := 1 to NTYPE do
          Read(GMParaFile, NCELLBGN[IRGN, ITYPE], NCELLEND[IRGN, ITYPE]);
        Readln(GMParaFile);
        if (RGNV <> RGNVAL[IRGN]) or (Trim(NAME2) <> Trim(FRGNNAME[IRGN])) then
        begin
          ShowMessage
            ('Errors: The information about regions defined in the landuse change matrix is not exactly identical to the region image.');
          CleanUp;
          Halt; { Stop running }
        end; { End If }
      end;
    end;

    // ******** Read Part 3 ******************

    { Next is to read the output maps setup parameters }
    Readln(GMParaFile); { '****** OUTPUT FILE SPECIFICATION ******    '); }
    Readln(GMParaFile, TmpStr,
      { '# OF YEARS OF OUTPUT BESIDE END YEAR  :    ', } NYEARWRT);
    IFDISPLAY := 0; // initialize
    if NYEARWRT > 0 then
    begin
      SetLength(YEARWRT, NYEARWRT + IDR_DIMINCR);
      Read(GMParaFile,
        TmpStr { 'DESIRED JULIAN YEARS FOR OUTPUT       :    ' } );
      for i := 1 to NYEARWRT do
        Read(GMParaFile, YEARWRT[i] { , '  ' } );
      Readln(GMParaFile);

      if DOCBN <> 0 then
      begin
        WRTRST[1] := 1;
        Readln(GMParaFile, TmpStr, PREFIXFINAL[1]);
        PREFIXFINAL[1] := Trim(PREFIXFINAL[1]);
        WRTRST[2] := 1;
        Readln(GMParaFile, TmpStr, PREFIXFINAL[2]);
        PREFIXFINAL[2] := Trim(PREFIXFINAL[2]);
        WRTRST[3] := 1;
        Readln(GMParaFile, TmpStr, PREFIXFINAL[3]);
        PREFIXFINAL[3] := Trim(PREFIXFINAL[3]);
        WRTRST[4] := 0; // removed this option already
        NPERCLAS := 10; // modified in August
      end
      else
      begin
        WRTRST[1] := 1;
        Readln(GMParaFile, TmpStr, PREFIXFINAL[1]);
        PREFIXFINAL[1] := Trim(PREFIXFINAL[1]);
        WRTRST[2] := 0;
        WRTRST[3] := 0;
        WRTRST[4] := 0; // removed this option already
        NPERCLAS := 10;
      end;
      Readln(GMParaFile, TmpStr, IFDISPLAY);
    end
    else
    begin
      if DOCBN <> 0 then
      begin
        WRTRST[1] := 1;
        Readln(GMParaFile, TmpStr, OUTPUTFINAL[1]);
        OUTPUTFINAL[1] := Trim(OUTPUTFINAL[1]);
        WRTRST[2] := 1;
        Readln(GMParaFile, TmpStr, OUTPUTFINAL[2]);
        OUTPUTFINAL[2] := Trim(OUTPUTFINAL[2]);
        WRTRST[3] := 1;
        Readln(GMParaFile, TmpStr, OUTPUTFINAL[3]);
        OUTPUTFINAL[3] := Trim(OUTPUTFINAL[3]);
        WRTRST[4] := 0; // removed this option already
        NPERCLAS := 10;
      end
      else
      begin
        WRTRST[1] := 1;
        Readln(GMParaFile, TmpStr, OUTPUTFINAL[1]);
        OUTPUTFINAL[1] := Trim(OUTPUTFINAL[1]);
        WRTRST[2] := 0;
        WRTRST[3] := 0;
        WRTRST[4] := 0; // removed this option already
        NPERCLAS := 10;
      end;
    end;

    { Next to read lubrication parameters }
    // Readln(GMParaFile);
    // Readln(GMParaFile);
    // Readln(GMParaFile); {'* DRIVER LUBRICATION VALUE SPECIFICATION *    ');}
    // **       Readln(GMParaFile, TmpStr, {'MAXIMUM CATEGORY VALUE IN DRIVER MAPS :    ',} NDCATMAX);   {Calculated in Step 2}
    // **       Readln(GMParaFile, TmpStr, {'COMPUTE/READ LUBI VALUES? (1=CP, 0=RD):    ',} LUBIDO);
    // **       If LUBIDO = 0 then
    // **          Readln(GMParaFile, TmpStr, {'IF NOT COMPUTE, LUBRI. VALUES READ FROM  :    ',} LubricationFile);

    LUBIDO := 1; // always compute the friction, if necessary.
    { Next to output overall output control parameter }
    ResultImagesPath := IdrisiAPI.GetWorkingDir;
    LUBISTOP := 0; // always continue;

    CloseFile(GMParaFile);

    // ********** The following is to read lubrication value from the lubrication file, if not to compute them **********

  Map_Reading:
    SetLength(FRIC, NRGN + IDR_DIMINCR, 3 + NMAPC + NMAPP + IDR_DIMINCR,
      NDCATMAX + 1 + IDR_DIMINCR);
    // IF (LUBIDO.EQ.0 .OR. DRCOUNT.NE.1) then

    // If Not ((LUBIDO = 1) And (DRCOUNT = 1)) Then  {otherwise, skip to the next section to comp. Lubrication Values.}
    // NOTE: THE FOLLOWING ABOUT READING LUBRICATION FILE HAS ACTUALLY BEEN REMOVED SINCE ALWAYS TO COMPUTE FRICTION IF NECESSARAY

    if (LUBIDO = 0)
    then { otherwise, skip to the next section to comp. Lubrication Values. }
    begin
      { The next routine reads the Lubrication Values. }
      AssignFile(Lubfilehandle, Trim(LubricationFile));
      Reset(Lubfilehandle);

      for IRGN := 1 to NRGN do
      begin
        Readln(Lubfilehandle, TmpStr,
          { 'REGION VALUE                          :    ', } RGNVAL[IRGN]);

        Readln(Lubfilehandle); { skip the drv_i row }

        for IDCAT := 1 to NDCATMAX + 1 do { need to add 1 ?? }
        begin
          // Read(LubFileHandle, IDCAT);
          Read(Lubfilehandle, i);
          for IMAP := 4 + NMAPC to 3 + NMAPC + NMAPP do
            Read(Lubfilehandle, FRIC[IRGN, IMAP, IDCAT]);
          Readln(Lubfilehandle);

          // If ((IDCAT <> i And IDCAT <= NDCATMAX) Or
          // (i > NDCATMAX And IDCAT <> 0) Or
          // RGNV <> RGNVAL(IRGN)) Then
          // MsgBox "Error Reading Friction Weights"
          // Stop
          // End If
        end;
      end;
      CloseFile(Lubfilehandle);
    end;


    // ********Next is to read maps data, output the lubrication file if it has been recomputed*****

    { Next, SREADER reads the maps. }
    { In the following Do loop,
      IMAP = 1 indicates the Political Region map.
      IMAP = 2 indicates the desert map.
      IMAP = 3 indicates the initial land use map.
      IMAP = 4, . . . . , 3+NMAP'       indicates carbon maps.
      IMAP = 4+NMAPC,..., 3+NMAPC+NMAPP indicates Permanent Driver maps.
      IMAP = 4+NMAPC+NMAPP,..., 3+NMAPC+NMAPP+NMAPE indicates Era maps.
      IMAP = 3+NMAPC+NMAPP+NMAPE+1 indicates Validation map. }

    // SetLength(FMAPNAME, 3 + NMAPC + NMAPP + NMAPE + NMAPVLD + IDR_DIMINCR);
    // SetLength(FMAPXT, 3 + NMAPC + NMAPP + NMAPE + NMAPVLD + IDR_DIMINCR);

    SetLength(MAPIN, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);

    for IMAP := 1 to 3 + NMAPC + NMAPP + NMAPE + NMAPVLD do
    begin

      // Reads Idrisi documentation files {to check again about the type of files?}

      { Check and Read Idrisi Raster files }
      SetLength(MAPRGN, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);

      if (IMAP = 1) and (UpperCase(Trim(FMAPNAME[1])) = 'N/A') then
      begin
        for row := 1 to NROW do
        begin
          if (row mod ROW_RANGE) = 0 then
            if not IdrisiAPI.IsValidProcId(process_id) then
            begin
              bTerminateApplication := true; // quit the entire application
              Exit;
            end;

          for col := 1 to NCOL do
            MAPRGN[row, col] := 1;
        end;
        continue;
      end;

      if ((IMAP = 2) and (Trim(FMAPNAME[IMAP]) = '')) then
        continue;

      // **          FMAPNAME[IMAP] := GetRstFileName(trim(FMAPNAME[IMAP]));
      if not CheckAndReadMap(FMAPNAME[IMAP], NROW, NCOL, 0, NROW - 1, MAPIN)
      then
      begin
        ReadSuccess := false;
        Exit;
      end;
      { The following series of IF, THEN, ELSEIF statements puts the
        MAPIN matrix into the appropriate map, and calls some subroutines.
        The SINITIAL subroutine finds the ROW and COL boarders of the
        rectangular area which contains a political region, and
        initializes the land use histograms.
        The SFRICT subroutine sets the permanent friction map. }

      // SetLength(MAPDSRT, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
      SetLength(MAPYEAR, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
      SetLength(MAPLND1, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
      SetLength(MAPLND2, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
      // SetLength(MAPCBN, NMAPC + IDR_DIMINCR, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
      // SetLength(MAPVLD, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
      SetLength(MAPFRCP, NROW + 1, NCOL + 1);
      if (IMAP = 1) then // Put into Political Region map.
      begin
        for row := 1 to NROW do
        begin
          if (row mod ROW_RANGE) = 0 then
            if not IdrisiAPI.IsValidProcId(process_id) then
            begin
              bTerminateApplication := true; // quit the entire application
              Exit;
            end;

          for col := 1 to NCOL do
            MAPRGN[row, col] := Round(MAPIN[row, col]);
        end;

        // if not fixed flux rate,
        if (DOCBN = 1) and (IfFixedFluxRate <> 1) then
        begin
          // Setlength(FluxPercMap, NROW + 1, NCOL + 1);
          SetLength(FluxPercMap, 2, NCOL + 1);
          for row := 1 to NROW do
          begin
            if (row mod ROW_RANGE) = 0 then
              if not IdrisiAPI.IsValidProcId(process_id) then
              begin
                bTerminateApplication := true; // quit the entire application
                Exit;
              end;

            CheckAndReadMap(FluxrateImage, NROW, NCOL, row - 1, row - 1,
              FluxPercMap);
            for col := 1 to NCOL do
            begin
              // If MAPRGN[row, col] <> 0 then
              for FROM := 1 to NTYPE do
                for TTO := 1 to NTYPE do
                  if (FROM = TTO) then
                    // MATCBN[MAPRGN[row, col], FROM, TTO] := 1.0
                    MATCBN[MAPRGN[row, col], FROM, TTO] := 0.0
                  else
                  begin
                    if FROM = 1 then
                      // MATCBN[MAPRGN[row, col], FROM, TTO] := Abs(FluxPercMap[row, col])    // type 1 convered to type 2 always accompany the possitive release of carbon into the atmoaphere.
                      MATCBN[MAPRGN[row, col], FROM, TTO] :=
                        abs(FluxPercMap[1, col])
                      // type 1 convered to type 2 always accompany the possitive release of carbon into the atmoaphere.
                    else if FROM = 2 then
                      MATCBN[MAPRGN[row, col], FROM, TTO] :=
                        -abs(FluxPercMap[1, col]);
                  end;
            end;
          end;
          FluxPercMap := nil;
        end;
      end
      else if (IMAP = 2) and (DSRTMAP = 1) then // Put in Desert map.
      begin
        (*
          SetLength(MAPDSRT, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
          For row := 1 To NROW do
          For col := 1 To NCOL do
          MAPDSRT[row, col] := Round(MAPIN[row, col]);
        *)
      end
      else if (IMAP = 3) then // Put into current and past land use map.
      begin
        for row := 1 to NROW do
        begin
          if (row mod ROW_RANGE) = 0 then
            if not IdrisiAPI.IsValidProcId(process_id) then
            begin
              bTerminateApplication := true; // quit the entire application
              Exit;
            end;

          for col := 1 to NCOL do
          begin
            MAPYEAR[row, col] := 1; // Set map of year since last change.
            MAPLND1[row, col] := NODATA;
            // here to simplify the following code, because as default, the values of nodata, desert, and ocean are same as 0.
            if not((MAPRGN[row, col] = OCEANRGN) { or
                ((DSRTMAP = 1) And (MAPDSRT[row, col] = DSRTVALU)) } ) then
              MAPLND1[row, col] := Round(MAPIN[row, col]);
            MAPLND2[row, col] := MAPLND1[row, col];
          end; { Next col }
        end;
        Sinitial; // Initializes input values by region.
        if bTerminateApplication then
        begin
          CleanUp;
          Halt;
        end;
      end
      else if (IMAP >= 4) and (IMAP <= 3 + NMAPC) and (DOCBN = 1) then
      begin
        SetLength(MAPCBN, NMAPC + IDR_DIMINCR, NROW + IDR_DIMINCR,
          NCOL + IDR_DIMINCR);
        for row := 1 to NROW do // Put into Biomass map.
        begin
          if (row mod ROW_RANGE) = 0 then
            if not IdrisiAPI.IsValidProcId(process_id) then
            begin
              bTerminateApplication := true; // quit the entire application
              Exit;
            end;

          for col := 1 to NCOL do
            MAPCBN[IMAP - 3, row, col] := MAPIN[row, col];
        end;
      end
      else if (IMAP > 3 + NMAPC) and
      // if directly read MAPFRCP[row, col] from the image, NMAPP=0, As the result, this branch will not be executed forever.
        (IMAP < 3 + NMAPC + NMAPP + NMAPE + 1) then
      begin
        Sfrict(IMAP); // Sets permanent friction map, that is MAPFRCP[row, col]
        if bTerminateApplication then
        begin
          CleanUp;
          Halt;
        end;
      end
      { Note: !!!GEOMOD does not yet have the need to incorporate Era specific maps. }
      else if (NMAPVLD = 1) and (IMAP = 3 + NMAPC + NMAPP + NMAPE + NMAPVLD)
      then // Put in Validation map.  //the final map always be the validation map, if use it.
      begin
        // the following has been eliminated..., Aug, 2002
        (*
          SetLength(MAPVLD, NROW + IDR_DIMINCR, NCOL + IDR_DIMINCR);
          For row := 1 To NROW do
          For col := 1 To NCOL do
          MAPVLD[row, col] := Round(MAPIN[row, col]);
        *)
      end;
    end; { Next IMAP }

    MAPIN := nil; // release the memory

    // Here to add an option to directly read suitability/friction values from the exsiting images instend of computing them from the permenent facoters
    if SUITOPTION = READ_SUIT then
      if not CheckAndReadMap(FRICTIONMAPNAME[DRCOUNT], NROW, NCOL, 0, NROW - 1,
        MAPFRCP) then
      begin
        CleanUp;
        Halt;
      end;

    { This next section initializes the land use map and histograms when
      geomod starts with a completely undeveloped landscape. }

    if (BLANKMAP = 1) then // if start with a completely undeveloped landscape.
    begin
      for row := 1 to NROW do
      begin
        if (row mod ROW_RANGE) = 0 then
          if not IdrisiAPI.IsValidProcId(process_id) then
          begin
            bTerminateApplication := true; // quit the entire application
            Exit;
          end;

        for col := 1 to NCOL do
          for ITYPE := 2 to NTYPE do
            if (MAPLND1[row, col] = TYPEVAL[ITYPE]) then
            begin
              MAPLND1[row, col] := TYPEVAL[1];
              MAPLND2[row, col] := MAPLND1[row, col];
              break;
            end;
      end;
      Sinitial;
    end;

    { DRIVER LUBRICATION VALUE }
    if (DRCOUNT = 1) and (LUBIDO = 1) then
    begin
      { Write the Lubricaiton Values if GEOMOD computed them. }
      LubricationFile :=
        Trim(ResultImagesPath + changeFileExt
        (ExtractFileName(GmParameterFileName), '.lub'));
      // update LubricationFile file name
      AssignFile(Lubfilehandle, LubricationFile);
      ReWrite(Lubfilehandle);

      for IRGN := 1 to NRGN do
      begin
        Writeln(Lubfilehandle, 'REGION VALUE                          :    ',
          RGNVAL[IRGN]);

        Write(Lubfilehandle, 'CATEGORY  ');
        for i := 1 to NMAPP do
          Write(Lubfilehandle, Format('%8s', ['Drv_' + inttostr(i)]));
        Writeln(Lubfilehandle);

        for IDCAT := 1 to NDCATMAX do
        begin
          Write(Lubfilehandle, Format('%5d     ', [IDCAT]));
          for IMAP := 4 + NMAPC to 3 + NMAPC + NMAPP do
            Write(Lubfilehandle, Format('%8.2f', [FRIC[IRGN, IMAP, IDCAT]]));
          Writeln(Lubfilehandle);
        end;

        IDCAT := 0;
        Write(Lubfilehandle, Format('%5d     ', [IDCAT]));
        for IMAP := 4 + NMAPC to 3 + NMAPC + NMAPP do
          Write(Lubfilehandle, Format('%8.2f',
            [FRIC[IRGN, IMAP, NDCATMAX + 1]]));
        Writeln(Lubfilehandle);

      end;
      CloseFile(Lubfilehandle);
    end;

    { The next loop computes the rates of land use change, and
      the percentages for the Nth land use type. }

    SetLength(TYPERAT, NRGN + 1, NTYPE + 1);
    // adding 1 for compatibility with VB/Fortran code.
    SetLength(TYPEBGN, NRGN + 1, NTYPE + 1);
    for IRGN := 1 to NRGN do
    begin
      NCELLBGN[IRGN, NTYPE] := HISRGN[IRGN];
      { Initialize the beginning #Cell for landuse type Ntype to be computed }
      NCELLEND[IRGN, NTYPE] := HISRGN[IRGN];
      { Initialize the ending #Cell for landuse type Ntype to be computed }
      for ITYPE := 1 to NTYPE do
      begin
        if (ITYPE <> NTYPE) then
        begin
          NCELLBGN[IRGN, NTYPE] := NCELLBGN[IRGN, NTYPE] -
            NCELLBGN[IRGN, ITYPE];
          NCELLEND[IRGN, NTYPE] := NCELLEND[IRGN, NTYPE] -
            NCELLEND[IRGN, ITYPE];
        end;

        { Following is a linear reduction/increase relationship for any single landuse type.
          and acturally just predict the change of landuse type NTYPE, tha last one }
        ERABGNS := YEARBGN;
        ERAENDS := YEAREND;
        { Sets land use change rate, slope. that is km2/year }
        TYPERAT[IRGN, ITYPE] := (NCELLEND[IRGN, ITYPE] - NCELLBGN[IRGN, ITYPE])
          * CELLAREA[IRGN] / (ERAENDS - ERABGNS);
        { Sets land use area at beginning of IERA, intercept. km2 }
        TYPEBGN[IRGN, ITYPE] := CELLAREA[IRGN] * NCELLBGN[IRGN, ITYPE];
      end; { Next ITYPE }
    end; { Next IRGN }

    // then, to define the transmision likelihood matrix by defaults, this part is incorporated from the part 2 of the data file 2

    SetLength(MATTRA, NRGN + 1, NTYPE + 1, NTYPE + 1);
    // adding 1 for compatibility with VB/Fortran code.
    SetLength(YEARWAIT, NRGN + 1);

    // the following has been modified for the new version, using the default values rather than defined by the user.
    for IRGN := 1 to NRGN do
    begin
      YEARWAIT[IRGN] := 0; // always give it to 0, meaning no wait
      for FROM := 1 to NTYPE do
        for TTO := 1 to NTYPE do
          MATTRA[IRGN, FROM, TTO] := 1.0;
    end; { Next IRGN }

    // IYEAREND := YEAREND - YEARBGN + 1;

    WRTOPEN := 0; // This is a flag used to open the output file.

    if (LUBISTOP = 1) then
    begin
      ShowMessage
        ('Stopped after automatically generating a series of required input files');
      CleanUp;
      Halt;
      // Application.terminate;
    end;
  except
    on EOutOfMemory do
    begin
      Application.MessageBox
        ('The modeling failed due to the size of the input images appears to be too large. Please reduce the input image size and/or the number of driver images in use.!',
        'Error in GEOMOD');
      Halt;
    end;
    else
    begin
      ShowMessage
        ('Unable to read the input parameter file. Please provide a correct input file.');
      ReadSuccess := false;
      CleanUp;
      CloseFile(GMParaFile);
      Halt;
    end;
  end;
end;

procedure Swhere(IRGN: integer);

{ ************************************************************
  Subroutine Swhere
  ************************************************************
  This subroutine determines the one cell (TIEROW,TIECOL) where the
  land conversion occurs.
  Of all cells of the appropriate TYPE to be changed,
  the cell selected for change is the one which is has the
  maximum product of matrix value and REFER(TYPE) of all cells which
  are within NEIGHBW cells of a cell with the same value as the new value.
  For 2 land use types, there is no need for transistion matrix, so all
  matrix values are set to 1.
  If a cell is chosen for a land use change,
  it is not a candidate for future change until YEARWAIT years have past.
  This algorithm assumes that smaller TYPEVALs represent less intensive
  human disturbance than greater TYPEVALs. }

{ Declare Variables and common blocks.
  Delcaration of next line should be as per Ye's trick to minimize space. }
var
  TIECOL, TIEROW, TIETYPE: array of Smallint; // array[1..1000000] of Integer;
  JMPSTP, NTIE, ITIE: integer;
  NEIGHBW: integer; { Long }
  NEICOL, NEIROW: integer;
  SEED2: Smallint;
  FRICT: Single;
  MAX: Single;
  row, col: integer;
  ITYPE: Smallint;
  GreastWide: integer;
  NCOUNTS, RCOUNTS: integer; // New temporary variables
  bWiderSearch, bRedundacy: boolean;

label Start_5, Start_10, Start_20, Start_40, Start_90, Start_200;
label { line_5, } line_10, line_20, line_30, line_40, line_50, line_90,
  line_100, line_200, line_300;

begin

  SetLength(TIECOL, NROW * NCOL + 1);
  SetLength(TIEROW, NROW * NCOL + 1);
  SetLength(TIETYPE, NROW * NCOL + 1);

  { The ROW and COL loops examine all cells in IRGN. }
  MAX := -1.0; { Initialize }
  SEED2 := 0;
  { seed2 indicates if it is a global search, seed2 = 0 means no global, whith equals seed = 1 that in turn indicates nibble seeking }
  FRICT := 0; // Initialize
  NTIE := 0; // initialize

  NEIGHBW := NEIGHB;
  { The next line in is invoked only when GEOMOD trys to create
    a land use type which does not exist in the region
    or if the nation is discontiguous. }
  if ((CREATE = 1) and (HISMAP[IRGN, TTYPE] = 0))
  { TType does not exist in this region }
    or (CONTIG[IRGN] <> 1) or (HASEDGE[IRGN] = false) then
    SEED2 := 1; { turn to the global seeking. }

  { The ROW and COL loops examine all cells in IRGN. }

  { If there is no acceptable candidate for change, then ERROR message. }
  if NROW > NCOL then
    GreastWide := NROW // initialize
  else
    GreastWide := NCOL;

  repeat
    // ** {5}Start_5:
    // MAX := -1.0;  {Initialize}
    // SEED2 := 0;   {initialize, same as seed = 1, indicating nibble seeking}
    // FRICT := 0; //Initialize
    // NTIE := 0;  //initialize

    for row := RGNNORTH[IRGN] to RGNSOUTH[IRGN] do
    begin
      if not IdrisiAPI.IsValidProcId(process_id) then
      begin
        bTerminateApplication := true; // quit the entire application
        Exit;
      end;

      for col := RGNWEST[IRGN] to RGNEAST[IRGN] do
      begin

        { The next 3 IFs test to see if the cell is a candidate for change. }
        { The 1st IF is to check if the cell within the rectangle is not a cell in region IRGN
          or it is outside of the study area. Otherwise skip to the next cell }
        if (MAPRGN[row, col] <> RGNVAL[IRGN]) or (MAPLND1[row, col] = NODATA)
        then
          continue; { skip to the next cell }
        { The 2nd IF is to check if # of years of this cell is not less than
          the defined waiting years to change, o/w skip to the next cell }
        if (MAPYEAR[row, col] <= YEARWAIT[IRGN]) then
          continue; { skip to the next cell }
        // {when using desert map, check if the cell is a desert cell. IF it it, skip to the next}
        // If (MAPDSRT[row, col] = DSRTVALU) And (DSRTMAP = 1) Then Continue; {skip to the next cell}
        { when to create, check if the cell's landuse type is different from the type to be created.
          If yes, it is a candidate, otherwise skip to the next cell }
        { in the current GEOMOD modeling logic, TTYPE is always type 2 (non-forest),
          and create = 1 always means to create TTYPE (type 2) land cells, a typical 2-categoried
          calculation logic }
        if (CREATE = 1) and (MAPLND2[row, col] = TYPEVAL[TTYPE]) then
          continue;
        { If to duplicate/replace(create=0), check if the cell's type is equal to the type to be duplicated/replaced.
          If not, go to the next cell. }
        if (CREATE = 0) and (MAPLND2[row, col] <> TYPEVAL[TTYPE]) then
          continue; { goto 200 }

        { seed = 1 means nibble search, seed2 = 1 means global search }

        { The next 2 loops search the neighbors of the candidate cell. }
        for NEIROW :=
          -NEIGHBW to NEIGHBW
          do { If NEIGHBW = 0, the loop just one time, 0 to 0 }
        begin
          for NEICOL := -NEIGHBW to NEIGHBW do
          begin

            { If seeding or ignoring neighbors, don't look at neighbors.
              seed = 1 means just change the neighbours of initial landuse map;
              seed = 0 means no limitation. NEIGHB = 0 means no nibble;
              seed2 = 1 means the nation is discontiguous or to create a new type }
            if ((YEAR = YEARBGN) and (SEED = 0)) or (NEIGHB = 0) or (SEED2 = 1)
            then
              goto Start_10; { global seeking }

            { If neighbor is self or is off map, then GO TO next neighbor. }
            if ((NEIROW = 0) and (NEICOL = 0)) or (row + NEIROW < 1) or
              (row + NEIROW > NROW) or (col + NEICOL < 1) or
              (col + NEICOL > NCOL) then
              continue; { GoTo the next neighbor }

            { If neighbor is out of region, then GO TO next neighbor. }
            if (MAPRGN[row + NEIROW, col + NEICOL] <> RGNVAL[IRGN]) or
              (MAPLND1[row + NEIROW, col + NEICOL] = NODATA) then
              continue; { skip to next neighbor };

            { 10 } Start_10:
            if (CREATE = 1) then // ITYPE -> TTYPE, that is land use type 2
            begin
              { The THEN is executed when SWHERE aims to change the candidate
                from an ITYPE cell to a TTYPE cell. always indicates from type 1 to type 2 transformation }

              { If seeding or ignoring neighbors, don't look at neighbors. }
              { seed = 0 indicates to look for in the entire map; }
              { NEIGHB = 0 means no nibble for this region; }
              { seed2 = 1 is same as seed = 0, meaning look for any cell in the map }
              if ((YEAR = YEARBGN) and (SEED = 0)) or (NEIGHB = 0) or (SEED2 = 1)
              then
                goto Start_20; { If Global seeking }
              { The candidate cell (ROW,COL) must neighbor a TTYPE cell.
                If the candidate does not neighbor any TTYPE cell, this candidate is not a real candidate,
                and move to the next possible candidate, a pixel of ITYPE.
                If the global search, it does not make sense to look at the neighbors. }

              { used to check the candicate cell must be a cell which neighbor a TTYPE (type 2) cell }
              if (MAPLND1[row + NEIROW, col + NEICOL] <> TYPEVAL[TTYPE]) then
                continue; { Go to the next neighbor }

              { The next For identifies the ITYPE of the candidate cell. }

              { 20 } Start_20:
              for ITYPE := 1 to NTYPE do
              begin
                { You know that MAPLND2.NE.TTYPE, due to above IFs.
                  If ITYPE is the TYPE in MAPLND2, then compute FRICT. }
                if (TYPEVAL[ITYPE] <> MAPLND2[row, col]) then
                  continue; { ascertain the type of MAPLND2[row, col], If not, Go to next ITYPE }
                { In fact, in the above sentence, MAPLND2[row, col] must not be TTYPE, but type 1, in terms of the current logic }

                { Compute FRICT to change candidate from ITYPE to TTYPE.
                  !!! Here, we improve the module by using the result of Markov analysis to acquire the transforming possibility matrix, MATTRA[IRGN, ITYPE, TTYPE] }
                FRICT := MAPFRCP[row, col] * MATTRA[IRGN, ITYPE, TTYPE];

                { If human impact is decreasing/dt, take 100-FRICT.
                  These (-) adjustments needs more thought for NTYPE>2. }
                { here always assume if TTYPE < ITYPE, meaning TTYPE is less disturbed than ITYPE, that is TTYPE is forext, e.g., ITYPE is non-forest. }
                if (TTYPE < ITYPE) then
                  FRICT := 100 - FRICT;
                // meaning type 2 to type 1, a reforesting process.
                { in fact, TTYPE always greater then ITYPE }

                if (FRICT > MAX) then
                begin
                  { Record the minimum FRICT and location of candidate. }
                  MAX := FRICT;
                  NTIE := 1;
                  TIETYPE[NTIE] := ITYPE; { ITYPE == type 1 }
                  TIEROW[NTIE] := row;
                  TIECOL[NTIE] := col;
                end
                else if (FRICT = MAX) then
                begin
                  { Record location of candidate. }
                  NTIE := NTIE + 1;
                  TIETYPE[NTIE] := ITYPE;
                  TIEROW[NTIE] := row;
                  TIECOL[NTIE] := col;
                end;

                { If seeding or ignoring neighbors, then go to next cell,
                  else go to next neighbor. }
                // If ((YEAR = YEARBGN) And (SEED = 0)) Or
                // (NEIGHB = 0) Or (NTYPE = 2) Or (SEED2 = 1) Then  //? NTYPE = 2, always true

                // A critical bug in the source code has been fixed, which results in the wrong quantity prediction in the land types
                if ((YEAR = YEARBGN) and (SEED = 0)) or (NEIGHB = 0) or
                  (SEED2 = 1) then
                  goto Start_200 { go to next cell }
                  // for the global search, no consideration for neighbors
                else
                  goto Start_200;
                // Here is a big bug in the original source code, Break; //GoTo 90, {go to next neighor}
                // the original code is Goto Start_90 (for the next neighor), actually which results in the wrong quantity.

                (*
                  If ((YEAR = YEARBGN) And (SEED = 0)) Or
                  (NEIGHB = 0) Or (SEED2 = 1) Then
                  GoTo Start_200 {go to next cell}
                  Else
                  GoTo Start_90; {go to next neighbor}
                  //                             GoTo Start_200; //break; // {break from ITYPE loop, go to next neighbor)
                *)

              end; { Next ITYPE      'Next ITYPE }
            end
            else { Create = 0 } // TTYPE -> ITYPE, change
            begin
              { The ELSE is executed when SWHERE aims to change the candidate
                from a TTYPE cell to an ITYPE cell.
                SWHERE finds (TIEROW,TIECOL) & TIETYPE to replace/reduce TTYPE cell.
                An ITYPE cell must neighbor the candidate, thus SWHERE searches
                neighbors for alternative ITYPEs.
                You know that MAPLND2.EQ.TTYPE, due to above IFs.
                The next DO looks for the ITYPE of a neighboring cell. }
              for ITYPE := 1 to NTYPE do
              begin
                { The next IF prevents TTYPE to be replaced with TTYPE. }

                if (ITYPE = TTYPE) then
                  continue; { go to next ITYPE }

                SEED2 := 0; // nibble search, same as SEED = 1;
                { The next line in is invoked only when GEOMOD trys to
                  create a land use type which does not exist in region. }
                if (HISMAP[IRGN, ITYPE] = 0) or (CONTIG[IRGN] <> 1) or
                  (HASEDGE[IRGN] = false) then
                  SEED2 := 1;
                { If seeding or ignoring neighbors, don't look @ neighbors. }
                if ((YEAR = YEARBGN) and (SEED = 0)) or (NEIGHB = 0) or
                  (SEED2 = 1) then
                  goto Start_40;
                { If neighbor is a TTYPE cell, then GO TO next neighbor.
                  If the type of the neighbors around this cell is same as that of this cell,
                  it means that the cell is not on boundary, and it is not a real candidate }
                if (MAPLND1[row + NEIROW, col + NEICOL] = TYPEVAL[TTYPE]) then
                  break; { break from the ITYPE loop, to line 90 to look for the next neighbor }
                { If neighbor's land is ITYPE, or
                  seeding or ignoring neighbors, then compute FRICT. }
                { 40 } Start_40:
                if (MAPLND1[row + NEIROW, col + NEICOL] = TYPEVAL[ITYPE]) or
                  ((YEAR = YEARBGN) and (SEED = 0)) or (NEIGHB = 0) or
                  (SEED2 = 1) then
                  FRICT := MAPFRCP[row, col] * MATTRA[IRGN, TTYPE, ITYPE];
                // the friction value at the very candicate cell
                { If human impact is decreasing/dt, take 100-FRICT.
                  These (-) adjustments needs more thought for NTYPE>2. }
                if (ITYPE < TTYPE) then
                  FRICT := 100 - FRICT;

                if (FRICT > MAX) then
                begin
                  { Record the minimum FRICT and location of candidate. }
                  MAX := FRICT;
                  NTIE := 1;
                  TIETYPE[NTIE] := ITYPE;
                  TIEROW[NTIE] := row;
                  TIECOL[NTIE] := col;
                end
                else if (FRICT = MAX) then
                begin
                  { Record location of candidate. }
                  (*
                    If NTIE > 0 then
                    For ITIE := 1 to NTIE do
                    If (TIEROW[ITIE] = row) or (TIECOL[ITIE] = col) then
                    begin
                    bRedundacy := true;
                    break;
                    end;
                    If Not bRedundacy then
                  *)
                  begin
                    NTIE := NTIE + 1;
                    TIETYPE[NTIE] := ITYPE;
                    TIEROW[NTIE] := row;
                    TIECOL[NTIE] := col;
                  end;
                end; { End If }

                { If seeding or ignoring neighbors,
                  then go to next cell, else go to next neighbor. }
                // If ((YEAR = YEARBGN) And (SEED = 0)) Or
                // (NEIGHB = 0) Or (NTYPE = 2) Or
                // (SEED2 = 1) Then

                // A critical bug in the source code has been fixed, which results in the wrong quantity prediction in the land types
                if ((YEAR = YEARBGN) and (SEED = 0)) or (NEIGHB = 0) or
                  (SEED2 = 1) then
                  goto Start_200
                  // for the global search, no consideration for neighbors
                else
                  goto Start_200;
                // Here is a big bug in the original source code, Break; //GoTo 90, {go to next neighor}
                // the original code is Goto Start_90 (for the next neighor), actually which results in the wrong quantity.

              end; { Next ITYPE     'Next ITYPE }
            end; { End If create = 1 }
          Start_90: { 90 } // modified Nov. 25, 2002
          end; { Next NEICOL 'Next neighbor column }
        end; { Next NEIROW 'Next neighbor row }
      Start_200:
      end; { Next col 'Next cell comumn }
    end; { Next row 'Next cell row }

    // note: Swhere will change one cell very time, that will guarantee the highest friction cell to be changed.
    // but the code can be optimized if NTIE > 1 and NTIE <= Abs(HISMAP[IRGN, TTYPE] - HISTAR[TTYPE]). When it happnes, we
    // can change multiple cells at one time, because they have same friction value.

    if (MAX = -1.0) then
    // because no real candidate is tied; for the global search MAX will be always greater than -1.
    begin
      NEIGHBW := NEIGHBW + 1;
      if NEIGHBW <= GreastWide then
        bWiderSearch := true
      else
        bWiderSearch := false;
      // GoTo Start_5;  //for NEIGHB = 0, this will be skipped, because max of frict should be always greater than -1.
    end
    else
      bWiderSearch := false;

  until not bWiderSearch;
  { JMPSTP determines how many tied cells to convert. }
  // JMPSTP := Int(NTIE / Abs(HISMAP[IRGN, TTYPE] - HISTAR[TTYPE]));

  JMPSTP := Round(NTIE / abs(HISMAP[IRGN, TTYPE] - HISTAR[TTYPE]));
  { The next line rounds JMPSTP up. }
  if (JMPSTP <> NTIE / abs(HISMAP[IRGN, TTYPE] - HISTAR[TTYPE])) then
    // ADD A CONDITION FOR REMOVING INFINITE LOOP.
    JMPSTP := JMPSTP + 1;
  { Convert every JMPSTPth cell. }
  if (CREATE = 1) then // ITYPE -> TTYPE, use TTYPE to replace ITYPE
  begin
    ITIE := JMPSTP;
    if JMPSTP <> 0 then // prevent dead loop
      while (ITIE <= NTIE) do
      begin
        MAPLND2[TIEROW[ITIE], TIECOL[ITIE]] := TYPEVAL[TTYPE];
        HISMAP[IRGN, TTYPE] := HISMAP[IRGN, TTYPE] + 1;
        HISMAP[IRGN, TIETYPE[ITIE]] := HISMAP[IRGN, TIETYPE[ITIE]] - 1;
        if (YEAR <> YEARBGN) then
          MAPYEAR[TIEROW[ITIE], TIECOL[ITIE]] := 0;
        ITIE := ITIE + JMPSTP;
      end;
  end
  else { CREATE = 0, replace/reduce not to create }
  // TTYPE -> ITYPE, TIETYPE[ITIE]
  begin
    ITIE := JMPSTP;
    if JMPSTP <> 0 then
      while (ITIE <= NTIE) do
      begin
        MAPLND2[TIEROW[ITIE], TIECOL[ITIE]] := TYPEVAL[TIETYPE[ITIE]];
        HISMAP[IRGN, TTYPE] := HISMAP[IRGN, TTYPE] - 1;
        HISMAP[IRGN, TIETYPE[ITIE]] := HISMAP[IRGN, TIETYPE[ITIE]] + 1;
        if (YEAR <> YEARBGN) then
          MAPYEAR[TIEROW[ITIE], TIECOL[ITIE]] := 0;
        ITIE := ITIE + JMPSTP;
      end;
  end; { End If for CREATE }

  (*
    JMPSTP := 1; //Round(NTIE / Abs(HISMAP[IRGN, TTYPE] - HISTAR[TTYPE]));
    NCOUNTS := Abs(HISMAP[IRGN, TTYPE] - HISTAR[TTYPE]);

    {Convert every JMPSTPth cell.}
    If (CREATE = 1) Then   //ITYPE -> TTYPE, use TTYPE to replace ITYPE
    begin
    ITIE := JMPSTP;
    If NTIE <= NCOUNTS then RCOUNTS := NTIE Else RCOUNTS := NCOUNTS;
    While (ITIE <= RCOUNTS) do
    begin
    MAPLND2[TIEROW[ITIE], TIECOL[ITIE]] := TYPEVAL[TTYPE];
    HISMAP[IRGN, TTYPE] := HISMAP[IRGN, TTYPE] + 1;
    HISMAP[IRGN, TIETYPE[ITIE]] := HISMAP[IRGN, TIETYPE[ITIE]] - 1;
    If (YEAR <> YEARBGN) Then MAPYEAR[TIEROW[ITIE], TIECOL[ITIE]] := 0;
    ITIE := ITIE + JMPSTP;
    end;
    end
    Else  {CREATE = 0, replace/reduce not to create}    //TTYPE -> ITYPE, TIETYPE[ITIE]
    begin
    ITIE :=JMPSTP;
    If NTIE <= NCOUNTS then RCOUNTS := NTIE Else RCOUNTS := NCOUNTS;
    While (ITIE <= RCOUNTS) do
    begin
    MAPLND2[TIEROW[ITIE], TIECOL[ITIE]] := TYPEVAL[TIETYPE[ITIE]];
    HISMAP[IRGN, TTYPE] := HISMAP[IRGN, TTYPE] - 1;
    HISMAP[IRGN, TIETYPE[ITIE]] := HISMAP[IRGN, TIETYPE[ITIE]] + 1;
    If (YEAR <> YEARBGN) Then MAPYEAR[TIEROW[ITIE], TIECOL[ITIE]] := 0;
    ITIE := ITIE + JMPSTP;
    end;
    end; {End If for CREATE}
  *)
  TIECOL := nil;
  TIEROW := nil;
  TIETYPE := nil;
end; { end of procedure Swhere }

procedure Sconvert(IRGN: integer);
{ ***************************************************
  subroutine Sconvert
  ***************************************************
  This subroutine decides which land use ITYPE to change.
  The Subroutine runs until the histogram for the land
  use map is the same as the target histogram obtained from the
  tabular data.  The program calls SWHERE to change one cell at a time.
  The type of cell to change is the type which has the largest
  discrepancy from the target histogram. }

var
  IsError: boolean;
  IsRepeatLoop: boolean;
  ITYPE: integer;
  HisDeltStart : integer; ///

begin
  { The next loop sets the AREA array for a new year or a new region,
    and computes the target histogram HISTAR. }

  // Note: TYPERAT has been difined in snewera subroutine;
  SetLength(HISTAR, NTYPE + 1);

  HISTOT := 0;
  for ITYPE := 1 to NTYPE do
  begin
    { Next line updates the AREA array. }
    AREA[IRGN, ITYPE] := TYPEBGN[IRGN, ITYPE] + TYPERAT[IRGN, ITYPE] *
      (YEAR - ERABGN[IERA]);
    HISTAR[ITYPE] := NINT(AREA[IRGN, ITYPE] / CELLAREA[IRGN]);
    HISTOT := HISTOT + HISTAR[ITYPE];
  end; { Next ITYPE }

  { The following IF trys to correct when too many cells are rounded the
    same way, up or down. }
  IsError := true;
  if (HISTOT = HISRGN[IRGN]) then
    IsError := false
  else
  begin
    for ITYPE := 1 to NTYPE do
    begin
      if (AREA[IRGN, ITYPE] / CELLAREA[IRGN] < HISTAR[ITYPE]) then
      begin
        { subtract 1 from HISTAR }
        HISTAR[ITYPE] := HISTAR[ITYPE] - 1;
        HISTOT := HISTOT - 1;
      end
      else if (HISTAR[ITYPE] < AREA[IRGN, ITYPE] / CELLAREA[IRGN]) then
      begin
        { add 1 to HISTAR }
        HISTAR[ITYPE] := HISTAR[ITYPE] + 1;
        HISTOT := HISTOT + 1;
      end; { End If }
      if (HISTOT = HISRGN[IRGN]) then
      begin
        // Application.StatusBar = 'ROUNDING ERROR IN SCONVERT HAS BEEN FIXED!'
        IsError := false;
        break; { Exit For }
      end; { End If }
    end; { Next ITYPE }
  end; { End If }

  if IsError then
  begin
    CleanUp;
    Halt;
  end
  else
  begin
    { Next, the program determines the land use type to change
      by comparing the target histogram with the map histogram. }
    repeat
      HISDELT := 0;
      for ITYPE := 1 to NTYPE do
      // here the primary logic seems problematic. may consider the multiple change here.
      begin
        if (abs(HISTAR[ITYPE] - HISMAP[IRGN, ITYPE]) > HISDELT) then
        begin
          HISDELT := abs(HISTAR[ITYPE] - HISMAP[IRGN, ITYPE]);
          TTYPE := ITYPE;
          // for 2 types, TTYPE will be always type 2, forest, since HISDELT has been changed from 0, due to this loop, which is more disturbed.
          if (HISTAR[ITYPE] > HISMAP[IRGN, ITYPE])
          then { HISTAR[2]>HISMAP[IRGN, ITYPE], means to increase/create type 2, create = 1 }
            CREATE := 1
          else if (HISTAR[ITYPE] < HISMAP[IRGN, ITYPE]) then
            // here ITYPE will be 2.
            CREATE := 0;
          { means to decrease type 2, congruent with increasing type 1 }
        end; { End If }
        // Note: If NTYPE is greater than 2, TTYPE would be always the type which has
        // the greatest quantity change during the simulation time period.
      end; { Next ITYPE }

      { Here: 'SCONVERT:ttype =',ttype,', create =',create }

      { If necessary, the program calls SWHERE to determine which
        land use cell to change.
        If the target histogram is the same as the map histogram, then
        the program returns to the main program. }
      if (HISDELT > HISEPSLN) then
      begin
        IsRepeatLoop := true; { loop will be continued. }
        {if (round(HISDELT) mod 10) = 0 then
          begin
            Pass_Proportion(((YEAR - YEARBGN) / (YEAREND - YEARBGN)) + ((HISDELT-HISEPSLN)/HISDELT),
              DRCOUNT, NLOOPS);
          end;}
        Swhere(IRGN);
        if bTerminateApplication then
        begin
          CleanUp;
          Halt;
        end;
      end
      else
        IsRepeatLoop := false;

    until IsRepeatLoop = false;
  end; { End If }
end; { End of Sconvert procedure }

procedure Sfrict(IMAP: integer);

{ **************************************
  Subroutine Sfrict
  **************************************
  Subroutine SFRICTP merges the Permanent Driver maps into
  one Friction map called MAPFRCP, here may consider directly reand MAPFRCP from a idrisi image. }

{ Loccal Variable declarations. }

var
  DCATDENO, DCATNUME: array { 0..299] } of integer;
  FRCINT: Single;
  found: boolean;
  F1: TextFile;
  F2: file of Single;
  buf: array of Single;
  IRGN, row, col: integer;
  IDCAT: integer;
  ITYPE: integer;
  IntFricImg, TmpStr, title, projectname: string;
  MaxValue, MinValue: double;

begin
  // **    Setlength(MAPLUBI, NROW + 1, NCOL + 1);    //adding 1 for compatibility with VB/Fortran code.

  { This region loop allows calculation one region at a time. }
  SetLength(DCATDENO, NDCATMAX + 2);
  SetLength(DCATNUME, NDCATMAX + 2);

  for IRGN := 1 to NRGN do
  begin

    { Initializes the Friction Maps.  Initial value
      =  0 for land in the study area, = -9 for other land, and
      = -1 for ocean. }
    if (IMAP = 4 + NMAPC) and (IRGN = 1) then
    begin
      for row := 1 to NROW do
      begin
        if (row mod ROW_RANGE) = 0 then
          if not IdrisiAPI.IsValidProcId(process_id) then
          begin
            bTerminateApplication := true; // quit the entire application
            Exit;
          end;

        for col := 1 to NCOL do
        begin
          if (MAPLND1[row, col] = STUDYOUT) then
          begin
            FRCINT := -1.0;
            // **                   MAPLUBI[row, col] := STUDYOUT;
          end
          else
          begin
            FRCINT := 0.0;
            // **                  MAPLUBI[row, col] := 0;
          end;

          MAPFRCP[row, col] := FRCINT;
          // here the map MAPFRCP will be initilized as -1 or 0;
          (*
            If (MAPLND1[row, col] = OCEAN) Then
            begin
            FRCINT := -1.0;
            MAPLUBI[row, col] := OCEAN;
            end
            Else If (MAPLND1[row, col] = STUDYOUT) Then
            begin
            FRCINT := -2.0;
            MAPLUBI[row, col] := STUDYOUT;
            end
            Else If (DSRTMAP = 1) And
            (MAPDSRT[row, col] = DSRTVALU) Then
            begin
            FRCINT := -3.0;
            MAPLUBI[row, col] := DSRTOUT;
            end
            Else
            begin
            FRCINT := -4.0;
            MAPLUBI[row, col] := NODATA;
            end; {End If}

            If (DSRTMAP <> 1) Or (MAPDSRT[row, col] <> DSRTVALU) Then
            begin
            For ITYPE := 1 To NTYPE do
            begin
            If (MAPLND1[row, col] = TYPEVAL[ITYPE]) Then
            begin
            FRCINT := 0.0;
            MAPLUBI[row, col] := 0;
            break; {Exit For}
            end; {End If}
            end; {Next ITYPE}
            end; {End If}

            MAPFRCP[row, col] := FRCINT;     //here the map MAPFRCP will be initilized as -1 or 0;
          *)
          // cc MAPFRC[row, col] := FRCINT;
          // cc MAPFRCE(ROW,COL) := FRCINT; !Will be used for ERA specific maps.
        end; { Next col }
      end; { Next row }
    end; { End If }

    if (LUBIDO <> 0) and (DRCOUNT = 1) then // just compute one time
    begin
      { Compute Lubrication Values. }
      for IDCAT := 1 to NDCATMAX + 1 do
      begin
        DCATNUME[IDCAT] := 0; // Initialize as 0;
        DCATDENO[IDCAT] := 0;
      end; { Next IDCAT }
      for row := RGNNORTH[IRGN] to RGNSOUTH[IRGN] do
      begin
        if (row mod ROW_RANGE) = 0 then
          if not IdrisiAPI.IsValidProcId(process_id) then
          begin
            bTerminateApplication := true; // quit the entire application
            Exit;
          end;

        for col := RGNWEST[IRGN] to RGNEAST[IRGN] do
        begin
          if not((MAPRGN[row, col] <> RGNVAL[IRGN]) or
            (MAPLND1[row, col] = NODATA) { Or
              ((DSRTMAP = 1) And (MAPDSRT[row, col] = DSRTVALU)) } ) then
            for IDCAT := 1 to NDCATMAX + 1 do
            begin
              if (MAPIN[row, col] = IDCAT) or // here MapIn is one of driver map
                ((IDCAT = NDCATMAX + 1) and (MAPIN[row, col] = 0)) then
              begin
                DCATDENO[IDCAT] := DCATDENO[IDCAT] + 1;
                // the total amount of this category with the current region.
                if (MAPLND1[row, col] = TYPEVAL[NTYPE]) then
                  // need think more here about the multi-landuse change scenario, since here NTYEP = 2 always defaultly indicate the non-forest area.
                  DCATNUME[IDCAT] := DCATNUME[IDCAT] + 1;
                // the total amount of land type NTYPE in the current category within the current region
              end; { End If }
            end; { Next IDCAT }
        end; { Next col }
      end; { Next row }

      for IDCAT := 1 to NDCATMAX + 1 do
      begin
        if (DCATDENO[IDCAT] = 0) then
          // if this catogory not exists in the region, assign a friction value of -1 to this category.
          FRIC[IRGN, IMAP, IDCAT] := -1.0
        else
          FRIC[IRGN, IMAP, IDCAT] := 100.0 * DCATNUME[IDCAT] / DCATDENO[IDCAT];
        // compute the percentage of land use Ntype (=2)'s pixels over this category's pixels as its friction.
      end; { Next IDCAT }
    end; { End If }

    { Generates Permanent Friction map. }
    if (FMAPPWT[DRCOUNT, IMAP] <> 0.0) then
      // consider impacts of driver weights
      for row := RGNNORTH[IRGN] to RGNSOUTH[IRGN] do
      begin
        if (row mod ROW_RANGE) = 0 then
          if not IdrisiAPI.IsValidProcId(process_id) then
          begin
            bTerminateApplication := true; // quit the entire application
            Exit;
          end;

        for col := RGNWEST[IRGN] to RGNEAST[IRGN] do
        begin
          { If Not ((DSRTMAP = 1) And (MAPDSRT[row, col] = DSRTVALU)) Then }
          if ((MAPRGN[row, col] = RGNVAL[IRGN]) and
            (MAPLND1[row, col] <> NODATA)) then
            if FMAPPWTT[DRCOUNT] <> 0 then
              MAPFRCP[row, col] := MAPFRCP[row, col] +
                FRIC[IRGN, IMAP, Round(MAPIN[row, col])] *
                FMAPPWT[DRCOUNT, IMAP] / FMAPPWTT[DRCOUNT];
          // like a vertical view for each pixel here
        end; { Next col }
      end; { Next row }
    { End If }
  end; { Next IRGN }

  { Writes the SFRICT.OUT file. }

  if (IMAP = 3 + NMAPC + NMAPP) then // have incorporate all the drivers
  begin
    // tmpstr := ExtractFileName(GmParameterFileName);
    // If ExtractFileExt(tmpstr) <> '' then  projectname := copy(tmpstr, 1, length(tmpstr) - 4);
    // Note: now, always output the integrated friction map, regardless of the value of debugout.
    // IntFricImg := ResultImagesPath + ChangeFileExt(tmpstr, '.rst');
    TmpStr := ExtractFileName(GmParameterFileName);
    if ExtractFileExt(TmpStr) <> '' then
      TmpStr := Copy(TmpStr, 1, Length(TmpStr) - 4);

    IntFricImg := Trim(ResultImagesPath + changeFileExt(TmpStr + '_suitability_'
      + inttostr(DRCOUNT), '.rst')); // update LubricationFile file name
    Assign(F2, IntFricImg);
    ReWrite(F2); { open it as a single type file }
    // Rewrite(F2, 2);  {open it as a single type file}
    // setlength(buf, sizeof(single)*NCOL);
    MaxValue := 0.0;
    MinValue := 0.0;
    for row := 1 to NROW do
    begin
      if (row mod ROW_RANGE) = 0 then
        if not IdrisiAPI.IsValidProcId(process_id) then
        begin
          bTerminateApplication := true; // quit the entire application
          Exit;
        end;

      BlockWrite(F2, MAPFRCP[row][1], NCOL);
      for col := 1 to NCOL do
      begin
        if MAPFRCP[row, col] > MaxValue then
          MaxValue := MAPFRCP[row, col];
        if MAPFRCP[row, col] < MinValue then
          MinValue := MAPFRCP[row, col];
      end;
    end;
    CloseFile(F2);
    title := 'Auto-created suitability image from driver images';
    CreateImgDocFile(IntFricImg, title, DATA_TYPE_REAL, MaxValue, MinValue,
      FMAPNAME[3], true, -1); //T - 12/17/19 - added last 2 parameters
  end; { End If }

  DCATDENO := nil;
  DCATNUME := nil;
end; { end of procedure frict }

procedure Sinitial;

{ **************************************
  **************************************
  The SINITIAL subroutine finds the ROW and COL boarders of the
  rectangular area which contains a political region.
  Those boarders are stored in RGNNORTH[IRGN], RGNSOUTH[IRGN],
  RGNEAST[IRGN], & RGNWEST[IRGN].
  The SINITIAL subroutine also initializes land use histogram for each
  IRGN, and the area per land use array, based on initial land use map. }

{ Declare Variables and common blocks. }

var
  F: TextFile;
  IRGN: integer;
  ITYPE: integer;
  row, col: integer;
  TmpStr: string;

begin

  SetLength(RGNEAST, NRGN + 1);
  // adding 1 for compatibility with VB/Fortran code.
  SetLength(RGNNORTH, NRGN + 1);
  SetLength(RGNSOUTH, NRGN + 1);
  SetLength(RGNWEST, NRGN + 1);
  SetLength(HISRGN, NRGN + 1);
  SetLength(AREA, NRGN + 1, NTYPE + 1);
  SetLength(HISMAP, NRGN + 1, NTYPE + 1);
  SetLength(HISINI, NRGN + 1, NTYPE + 1);

  // MsgBox 'Calling Sinitial now...'
  // Application.StatusBar = 'calling SINITIAL procedure...'
  for IRGN := 1 to NRGN do
  begin
    { Intializes the variables. }
    HISRGN[IRGN] := 0; { Histogram, # of pixels in region IRGN }
    RGNEAST[IRGN] := 0; { Eastern boundary of plitical region IRGN }
    RGNNORTH[IRGN] := 0; { Northern boundary of plitical region IRGN }
    RGNSOUTH[IRGN] := 0; { Southern boundary of plitical region IRGN }
    RGNWEST[IRGN] := NCOL; { Western boundary of plitical region IRGN }

    for ITYPE :=
      1 to NTYPE do { for landuse types, default = 2, forest/non-forest. }
    begin
      AREA[IRGN, ITYPE] := 0;
      HISMAP[IRGN, ITYPE] := 0;
      { Histogram, # of pixels in IRGN of land use ITYPE. }
    end; { Next ITYPE }

    { The next loops search the map for IRGN cells. }
    for row := 1 to NROW do
    begin
      if (row mod ROW_RANGE) = 0 then
        if not IdrisiAPI.IsValidProcId(process_id) then
        begin
          bTerminateApplication := true; // quit the entire application
          Exit;
        end;

      for col := 1 to NCOL do
      begin
        { MAPRGN(ROW,COL), Map of political region.
          MAPLND1(ROW,COL), Map of Land Use at beginning of year.
          RGNVAL[IRGN], Value in region map for IRGNth region.
          NODATA, Value to put in land use map for no data category.
          MAPDSRT(ROW,COL), Map of Desert land to eliminate from land conversion. }
        if UpperCase(Trim(FMAPNAME[1])) <> 'N/A' then
        begin
          if (MAPRGN[row, col] = RGNVAL[IRGN]) and (MAPLND1[row, col] <> NODATA)
          then
          { If (DSRTMAP <> 1) Or (MAPDSRT[row, col] <> DSRTVALU) Then }
          begin
            HISRGN[IRGN] := HISRGN[IRGN] + 1;
            { The following creates the regional boarder variables. }
            if (RGNEAST[IRGN] < col) then
              RGNEAST[IRGN] := col;
            if (RGNWEST[IRGN] > col) then
              RGNWEST[IRGN] := col;
            if (RGNSOUTH[IRGN] < row) then
              RGNSOUTH[IRGN] := row;
            if (RGNNORTH[IRGN] = 0) then
              RGNNORTH[IRGN] := row;
            for ITYPE := 1 to NTYPE do
            begin
              if (MAPLND1[row, col] = TYPEVAL[ITYPE]) then
              begin
                // Histogram, # of pixels in IRGN of land use ITYPE.
                HISMAP[IRGN, ITYPE] := HISMAP[IRGN, ITYPE] + 1;
                HISINI[IRGN, ITYPE] := HISMAP[IRGN, ITYPE];
                // HISINI(IRGN,ITYPE), Histogram of initial land use map.
                AREA[IRGN, ITYPE] := CELLAREA[IRGN] * HISMAP[IRGN, ITYPE];
                break; { Exit For ITYPE loop }
              end; { End If }
            end; { Next ITYPE }
          end; { End If }
        end
        else
        begin
          if (MAPLND1[row, col] <> NODATA) then
          { If (DSRTMAP <> 1) Or (MAPDSRT[row, col] <> DSRTVALU) Then }
          begin
            HISRGN[IRGN] := HISRGN[IRGN] + 1;
            { The following creates the regional boarder variables. }
            RGNEAST[IRGN] := NCOL;
            RGNWEST[IRGN] := 1;
            RGNSOUTH[IRGN] := NROW;
            RGNNORTH[IRGN] := 1;

            for ITYPE := 1 to NTYPE do
            begin
              if (MAPLND1[row, col] = TYPEVAL[ITYPE]) then
              begin
                // Histogram, # of pixels in IRGN of land use ITYPE.
                HISMAP[IRGN, ITYPE] := HISMAP[IRGN, ITYPE] + 1;
                HISINI[IRGN, ITYPE] := HISMAP[IRGN, ITYPE];
                // HISINI(IRGN,ITYPE), Histogram of initial land use map.
                AREA[IRGN, ITYPE] := CELLAREA[IRGN] * HISMAP[IRGN, ITYPE];
                break; { Exit For ITYPE loop }
              end; { End If }
            end; { Next ITYPE }
          end; { End If }
        end;
      end; { Next col }
    end; { Next row }
  end; { Next IRGN }

  { Writes the sinitial.Out file. }
  TmpStr := ExtractFileName(GmParameterFileName);
  if ExtractFileExt(TmpStr) <> '' then
    TmpStr := Copy(TmpStr, 1, Length(TmpStr) - 4);

  TmpStr := Trim(ResultImagesPath + changeFileExt
    (ExtractFileName(GmParameterFileName), '.log'));
  // CHANGE HERE, USE LOG FILE TO WRIETE THE DEBUG INFO, WHICH CONTAINS _SPRICT.OUT AND _INITIAL.OUT
  Assign(F, TmpStr);
  ReWrite(F);
  Writeln(F, 'Log file started on ' + DateToStr(Date) + ' at ' +
    TimeToStr(Time));
  Writeln(F, '------------------------------------------');
  Writeln(F);
  Writeln(F, 'GEOMOD  ' + ReturnCompleteFileName(READ_FILE, GmParameterFileName,
    GMF_EXT));
  Writeln(F);
  Writeln(F,
    'This log file contains the debugging information for the lastest geomod simulation, including the');
  Writeln(F,
    'initial information of the regions, warning information in running, and meanwhile a suitability image');
  Writeln(F,
    'has been automatically created by the module for the probably direct use in the future.');
  Writeln(F);
  Writeln(F, '#Rows = ', NROW, ',   #Cols = ', NCOL);

  if (DSRTMAP = 1) then
    Writeln(F, 'Desert was excluded!');
  if (DEBUGOUT <> 1) then
  begin
    Writeln(F);
    Writeln(F, 'DEBUGOUT <> 1 in order to save time');
    CloseFile(F);
    Exit; { Exit Sub }
  end; { End If }
  for IRGN := 1 to NRGN do
  begin
    { compute a new row shift for the next region's output }
    Writeln(F);
    Writeln(F, 'For region # ' + inttostr(RGNVAL[IRGN]) + ' = "' +
      Trim(UpperCase(FRGNNAME[IRGN])) + '"');
    Writeln(F, 'Boarders:', Format('%8s', ['North']), Format('%8s', ['South']),
      Format('%8s', ['East']), Format('%8s', ['West']));
    Writeln(F, '         ', Format('%8d', [RGNNORTH[IRGN]]),
      Format('%8d', [RGNSOUTH[IRGN]]), Format('%8d', [RGNEAST[IRGN]]),
      Format('%8d', [RGNWEST[IRGN]]));

    Writeln(F, 'Histogram by land use category:');

    Writeln(F, '          ', Format('%13s', ['Landuse value']),
      Format('%12s', ['# cells']), Format('%12s', ['area']));

    for ITYPE := 1 to NTYPE do
      Writeln(F, '          ', Format('%13d', [TYPEVAL[ITYPE]]),
        Format('%12d', [HISMAP[IRGN, ITYPE]]),
        Format('%12.2f', [AREA[IRGN, ITYPE]]));

    Writeln(F, '          ', Format('%13s', ['Total']),
      Format('%12d', [HISRGN[IRGN]]),
      Format('%12.2f', [HISRGN[IRGN] * CELLAREA[IRGN]]));

  end; { Next IRGN }
  CloseFile(F);
end; { end of procedure Snitial }

procedure Swriter;
{ ************************************************************
  subroutine Swriter
  ************************************************************
  This subroutine creates the spatial output files of
  land use, carbon storage and carbon flux for each cell.
  This subroutine writes .IMG, .SQG, and/or .SQR files to disk. }

{ Declare Variables }
var
  FYEAR: string[4];
  FOUT, title: string;
  FNUM: integer;
  F: file;
  rrow, rcol: integer;
  ITYPE: integer;
  i: integer;
  Tempint: byte;
  IMAP: integer;
  IRGN: integer;
  row, col: integer;
  Bytebuf: array of byte;
  IntBuf: array of Smallint;
  Realbuf: array of Single;
  MaxValue, MinValue: Single;

begin
  SetLength(HISVLD, NRGN + 1, NTYPE + 1);
  SetLength(HISVLDR, NRGN + 1);
  SetLength(HISVLDT, NTYPE + 1);
  SetLength(HISSUM, NTYPE + 1);
  SetLength(HISINIT, NTYPE + 1);
  SetLength(NNONCAN, NTYPE + 1);
  SetLength(NVLDEX, NRGN + 1);
  SetLength(HISSUMR, NTYPE + 1);

  { We convert the integer YEAR to character form.
    Initialize character variable. }
  FYEAR := inttostr(YEAR);
  (* According to Gil's proposal, the following statistical outputs are removed,
    for the kappa(s) calculation logic is not fully accordant with that used in the multi-validate module,
    which may incur unnecessary confusion to the user if we stick to using it. Thereby, only resultant
    images will be output.

    {The next section writes the end of year ledgers.
    Writes header for 1st time thru.}

    If (WRTOPEN = 0) Then
    //         If (DRCOUNT = 1) Then
    begin
    AssignFile(Fw, Trim(ResultImagesPath + ChangeFileExt(ExtractFileName(GmParameterFileName), '.log')));  //Store warning info in the log file.
    Append(Fw);
    Writeln(Fw);
    Writeln(Fw, '-------------------------------------------------------------');
    Writeln(Fw, '//Next contains possible warning information during simulation.');
    end;


    If (WRTOPEN = 0) Then
    If (DRCOUNT = 1) Then
    begin
    WRTLUBI := 0;
    {The '0' in FMAPNAME subscript represents NMAPE.}

    AssignFile(Fb, Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wkb'));
    rewrite(Fb);

    Writeln(Fb, 'This output file (*.wkb) contains information for');
    Writeln(Fb, 'each combination of driver weights.');

    Writeln(Fb);
    //            Writeln(Fb, 'INDEX OF LOOP                                  :  ', IntToStr(DRCOUNT));
    If FMAPNAME[3 + NMAPC + NMAPP + 0 + 1] <> '' then
    Begin
    Writeln(Fb, 'NAME OF VALIDATION IS                          :  ', FMAPNAME[3 + NMAPC + NMAPP + 0 + 1]);
    Writeln(Fb, 'YEAR OF VALIDATION IS                          :  ', IntToStr(VALIDYR));
    end
    Else
    begin
    Writeln(Fb, 'NAME OF VALIDATION IS                          :  ', 'NONE');
    Writeln(Fb, 'YEAR OF VALIDATION IS                          :  ', 'NONE');
    end;

    Writeln(Fb);
    Writeln(Fb, 'This file shows correspondence between the validation of ', IntToStr(VALIDYR));
    Writeln(Fb, 'This file is based on a search routine with');
    Writeln(Fb, 'Neighborhood searching window size: ', IntToStr(2 * NEIGHB + 1) + ' x ' + IntToStr(2 * NEIGHB + 1));

    If SUITOPTION = COMP_SUIT then
    begin
    Writeln(Fb, 'The factors are as follows:');
    Writeln(Fb, Format('  %-7s',['fac#']), Format('%-11s', ['FACTOR NAME']));

    For IMAP := 4 + NMAPC To 3 + NMAPC + NMAPP do   {Writes driver info to title.}
    Writeln(Fb, Format('    %-5s', [IntToStr(IMAP - 4)]), Format('%-32s', [FMAPNAME[IMAP]]));
    end
    Else
    begin
    //Writeln(Fb, '//The following statistics is for LOOP ' + IntToStr(DRCOUNT));
    Writeln(Fb, 'Geomod read landuse change suitability scores from the image, ' + FRICTIONMAPNAME[DRCOUNT] + '.');
    end;

    Writeln(Fb);
    If (LUBIDO = 1) Then
    Writeln(Fb, 'Geomod computed Lubrication values.')
    Else
    Writeln(Fb, 'Geomod read Lubrication values from geomod.se1.');

    If (BLANKMAP = 1) Then
    Writeln(Fb, 'Simulation started with Blank Map')
    Else
    Writeln(Fb, 'Geomod started w/', FMAPNAME[3], '; And SEED = ', IntToStr(SEED));

    Writeln(Fb);
    Writeln(Fb, 'Time Step in years                             :  ', IntToStr(IYEARSTP));

    If (DSRTMAP = 1) Then
    begin
    Writeln(Fb, 'Deserts have been excluded!');
    Writeln(Fb, '# of regions of stratification                 :', IntToStr(NRGN));
    Writeln(Fb, '************************************************'); //Writes a line under header.
    end;
    end {End If}
    Else
    begin
    AssignFile(Fb, Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wkb'));
    Append(Fb);
    end;

    If (WRTOPEN = 0) Then
    begin
    If DRCOUNT = 1 Then
    begin
    AssignFile(Fa, Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wka'));  {create a new textfile for output}
    rewrite(Fa);

    Writeln(Fa, 'This output file (*.wka) contains information for each year requested.');
    Writeln(Fa, 'This file is based on a search routine with');
    Writeln(Fa, 'Neighborhood searching window size: ', IntToStr(2 * NEIGHB + 1) + ' x ' + IntToStr(2 * NEIGHB + 1));
    end
    Else
    begin
    AssignFile(Fa, Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wka'));  {create a new textfile for output}
    Append(Fa);
    end;

    Writeln(Fa);
    Writeln(Fa);
    If SUITOPTION = COMP_SUIT then
    begin
    Writeln(Fa, '//The following statistics is for Run ' + IntToStr(DRCOUNT) + ', based on the following factor weights.');
    Writeln(Fa, Format('%-40s', ['FACTOR MAP']), format('%-8s',['WEIGHTS']));      // + DRCOUNT & ']'       {Writes title to output file.}

    {WRITE(31,9300) NEIGHB !Writes title to output file.}
    For IMAP := 4 + NMAPC To 3 + NMAPC + NMAPP  do {Writes driver info to title.}
    Writeln(Fa, format('%-40s',[FMAPNAME[IMAP]]), format('%-8.2f', [FMAPPWT[DRCOUNT, IMAP]]));

    Writeln(Fa);
    If (LUBIDO = 1) Then
    Writeln(Fa, 'Geomod computed suitability values.')
    Else
    Writeln(Fa, 'Geomod read Lubrication values from the bubrication files.');  //Input1_1 to Input1_n.
    // Writeln(Fa, 'Geomod read Lubrication values from geomod.se1.');
    end
    Else
    begin
    Writeln(Fa, '//The following statistics is for Run ' + IntToStr(DRCOUNT));
    Writeln(Fa, 'Geomod read landuse change suitability scores from the image, ' + FRICTIONMAPNAME[DRCOUNT] + '.');
    end;

    If (BLANKMAP = 1) Then
    Writeln(Fa, 'Simulation started with Blank Map.')
    Else
    Writeln(Fa, 'Geomod started with ', FMAPNAME[3], ' and SEED = ', IntToStr(SEED));

    Writeln(Fa);
    Writeln(Fa, 'Time Step in years = ', IntToStr(IYEARSTP));

    //If (DSRTMAP = 1) Then  //since deserts have always been excluded.
    //begin
    //   Writeln(Fa);
    //   Writeln(Fa, 'Deserts have been excluded!');
    //end;

    WRTOPEN := 1;

    end; {End If}

    Writeln(Fa);
    Writeln(Fa, '***************************************************'); {Writes a line between successive YEARs in the geomoda.wks.}
    Writeln(Fa, 'YEAR = ', YEAR);
    //Writeln(Fa, 'YEAR = ', YEAR, '    ERA INDEX = ', IntToStr(IERA), ':');

    {Initializes the HISSUM for Integer Sums, and HISSUMR for Real Sums.}
    For ITYPE := 1 To NTYPE do
    begin
    HISSUM[ITYPE] := 0;
    HISSUMR[ITYPE] := 0.0;
    HISINIT[ITYPE] := 0;
    end; {Next ITYPE}
    HMAPT := 0;

    {The next 4 WRITEs write the histograms for the land use cells.}
    Writeln(Fa);   {writes one blank line.}
    Writeln(Fa, 'HISTOGRAM OF  # OF CELLS OF LAND USE TYPE BY REGION');   {Writes title for histogram.}

    Writeln(Fa, Format('%44s', ['---- LAND USE TYPES ----']));

    Write(Fa, format('%-20s',['REGION']));
    For ITYPE := 1 To NTYPE do
    Write(Fa, format('%9d   ', [TYPEVAL[ITYPE]])); Writeln(Fa);  {Histogram header.}

    Writeln(Fa,'--------------------------------------------');

    For IRGN := 1 To NRGN do
    begin
    {Writes data for each region.}
    Write(Fa, format('%-20s', [Trim(FRGNNAME[IRGN])]));
    For ITYPE := 1 To NTYPE do
    Write(Fa, format('%12d', [HISMAP[IRGN, ITYPE]])); Writeln(Fa); {Histogram data.}

    For ITYPE := 1 To NTYPE do
    begin
    HISSUM[ITYPE] := HISSUM[ITYPE] + HISMAP[IRGN, ITYPE];
    HISINIT[ITYPE] := HISINIT[ITYPE] + HISINI[IRGN, ITYPE];
    HMAPT := HMAPT + HISMAP[IRGN, ITYPE];
    end; {Next ITYPE}
    end; {Next IRGN}

    Writeln(Fa,'--------------------------------------------');

    Write(Fa, format('%-20s', ['Total']));
    For ITYPE := 1 To NTYPE do
    Write(Fa, format('%12d', [HISSUM[ITYPE]])); Writeln(Fa);   {Total.}

    {Compute expected number of random successes without stratification.
    You must have perfectly overlaid validation map, GEOMOD will give
    you a warning if the validation histogram .ne. output histogram.
    This formula assumes two land use types.}
    If (BLANKMAP = 1) Then
    begin
    HISINIT[1] := HMAPT;
    HISINIT[2] := 0;
    end;

    If (HISSUM[1] <= HISINIT[1]) Then  {if cultivation increased.}
    begin
    NVLDFREE := HISINIT[2];
    NVLDEXST := HISINIT[2] +
    (Sqr(HISINIT[1] - HISSUM[1]) + Sqr(HISSUM[1])) / HISINIT[1];
    If (((HMAPT + HISINIT[2]) / 2.0) <= HISSUM[2]) Then
    NVLDMIN := 2 * HISSUM[2] - HMAPT
    Else
    NVLDMIN := HMAPT - 2 * (HISSUM[2] - HISINIT[2]);
    end
    Else   {if cultivation decreases.}
    begin
    NVLDFREE := HISINIT[1];
    NVLDEXST := HISINIT[1] +
    (Sqr(HISINIT[2] - HISSUM[2]) + Sqr(HISSUM[2])) / HISINIT[2];
    If ((HISINIT[2] / 2.0) <= HISSUM[2]) Then
    NVLDMIN := HMAPT + 2 * (HISSUM[2] + HISINIT[2])
    Else
    NVLDMIN := HMAPT - 2 * HISSUM[2];
    End; {End if}

    {The next 4 WRITEs write histograms for the landuse areas in the map.}
    Writeln(Fa); {Writes one blank line.}

    Writeln(Fa, 'HISTOGRAM OF AREA IN MAP OF LAND USE TYPE BY REGION');
    Writeln(Fa, 'AREA IS IN SQUARE KILOMETERS'); {Writes title for histogram.}

    Writeln(Fa, Format('%44s', ['---- LAND USE TYPES ----']));   {Histogram header.}

    Write(Fa, Format('%-20s', ['REGION']));  {Histogram header.}
    For ITYPE := 1 To NTYPE do
    Write(Fa, format('%9d   ', [TYPEVAL[ITYPE]])); Writeln(Fa);   {Histogram header.}

    Writeln(Fa,'--------------------------------------------');

    For IRGN := 1 To NRGN do
    begin
    Write(Fa, Format('%-20s', [Trim(FRGNNAME[IRGN])]));
    For ITYPE := 1 To NTYPE do
    Write(Fa, Format('%12.2f', [(CELLAREA[IRGN] * HISMAP[IRGN, ITYPE])])); Writeln(Fa); {data}

    For ITYPE := 1 To NTYPE do
    HISSUMR[ITYPE] := HISSUMR[ITYPE] +
    HISMAP[IRGN, ITYPE] * CELLAREA[IRGN];
    end; {Next IRGN}

    Writeln(Fa,'--------------------------------------------');

    Write(Fa, Format('%-20s', ['Total']));

    For ITYPE := 1 To NTYPE do
    Write(Fa, Format('%12.2f', [HISSUMR[ITYPE]])); Writeln(Fa);


    {?????, need to think more about it. Initializes the HISSUM and HISSUMR counters.}
    For ITYPE := 1 To NTYPE do
    HISSUMR[ITYPE] := 0.0;

    {The next 4 WRITEs write histograms for the target landuse areas.}
    Writeln(Fa);      {writes one blank line.}

    Writeln(Fa, 'HISTOGRAM OF TARGET AREAS OF LAND USE TYPE BY REGION');
    Writeln(Fa, 'AREA IS IN SQUARE KILOMETERS');

    Writeln(Fa, Format('%44s', ['---- LAND USE TYPES ----']));   {Histogram header.}

    Write(Fa, format('%-20s', ['REGION']));  {Histogram header.}
    For ITYPE := 1 To NTYPE do
    Write(Fa, format('%9d   ', [TYPEVAL[ITYPE]])); Writeln(Fa); {Histogram header.}

    Writeln(Fa,'--------------------------------------------');

    For IRGN := 1 To NRGN do
    begin
    Write(Fa, format('%-20s', [Trim(FRGNNAME[IRGN])]));
    For ITYPE := 1 To NTYPE do
    Write(Fa, format('%12.2f', [AREA[IRGN, ITYPE]])); Writeln(Fa);  {data}

    For ITYPE := 1 To NTYPE do
    HISSUMR[ITYPE] := HISSUMR[ITYPE] + AREA[IRGN, ITYPE];
    end; {Next IRGN}

    Writeln(Fa,'--------------------------------------------');

    Write(Fa, format('%-20s', ['Total']));
    For ITYPE := 1 To NTYPE do
    Write(Fa, format('%12.2f', [HISSUMR[ITYPE]])); Writeln(Fa); {Total}

    If (YEAR = VALIDYR) Then   {validation for only 1 year.}
    begin

    { Next, GEOMOD computes the correlation with the validation map, and
    creates the histogram for the validation map, and computes expected
    success rates for a random model.
    The next lines initialize the histograms for the validation map.}
    If (WRTOPEN <> 2) And (DRCOUNT = 1) Then     {Skip if already done. WRTOPEN = 2 WRITTEN}
    begin
    HISVLDRS := 0;    {HISVLDRS is # pixels in validation map (all nations).}
    NVLDEXS := 0.0;   {NVLDEXS  is # expected successes (all nations).}
    For IRGN := 1 To NRGN do
    begin
    HISVLDR[IRGN] := 0;          {is histogram for validation map by IRGN.}
    For ITYPE := 1 To NTYPE do
    begin
    HISVLD[IRGN, ITYPE] := 0; {is histogram for validation map.}
    HISVLDT[ITYPE] := 0;      {is histogram for validation map by ITYPE.}
    end; {Next ITYPE}
    end; {Next IRGN}
    end; {End If}


    { This next section computues # of successes.}

    If SUITOPTION = COMP_SUIT then
    begin
    Writeln(Fa);
    Write(Fa, format('%8s', ['tot#']));
    For i := 1 To NMAPP do {Writes driver coefficients to geomoda.wks.}
    Write(Fa, format('%6s', ['drv' + IntToStr(i)])); Writeln(Fa);

    Write(Fa, format('%8.2f', [FMAPPWTT[DRCOUNT]]));
    For i := 4 + NMAPC To 3 + NMAPC + NMAPP do
    Write(Fa, format('%6.2f', [FMAPPWT[DRCOUNT, i]])); Writeln(Fa);
    end
    Else
    begin
    Writeln(Fa);
    Writeln(Fa, 'Geomod read the suitability values from the self-provided suitability image #' + inttostr(DRCOUNT));
    end;

    { The '0' in FMAPNAME subscript represents NMAPE.}
    //''  WRITE(31,9360) FMAPNAME(3+NMAPC+NMAPP+0+1), VALIDYR, YEAR,
    //''  & 200.0/HMAPT, 100.0*NVLDFREE/HMAPT,
    //''  & 100.0*NVLDMIN/HMAPT, 100.0*NVLDEXST/HMAPT

    Writeln(Fa, 'NAME OF VALIDATION MAP IS                      :  ', FMAPNAME[3 + NMAPC + NMAPP + NMAPE + 1]);
    Writeln(Fa, 'YEAR OF VALIDATION MAP IS                      :  ', VALIDYR);

    Writeln(Fa);
    Writeln(Fa, 'This table shows correspondence between the validation');
    Writeln(Fa, 'map and GEOMOD''s simulated land use map of ', YEAR, '.');

    {????, Need to think more about it here}
    Writeln(Fa);
    Writeln(Fa, 'DELTA % SUCCESS DUE TO 1 MISCLASSIFIED PAIR    : ',
    format('%6.2f', [200.0 / HMAPT]));

    Writeln(Fa, '% OF RASTERS THAT ARE NOT CANDIDATES FOR CHANGE: ',
    format('%6.2f', [100.0 * NVLDFREE / HMAPT]));

    Writeln(Fa, 'MINIMUM % SUCCESS RATE DUE TO ONE WAY CHANGE   : ',
    format('%6.2f', [100.0 * NVLDMIN / HMAPT]));

    Writeln(Fa, 'RANDOM % SUCCESS RATE WITHOUT STRATIFICATION IS: ',
    format('%6.2f', [100.0 * NVLDEXST / HMAPT]));

    Writeln(Fa, 'The following table includes stratification;');
    Writeln(Fa, '                              GEOMOD''S  ', 'GEOMOD''S  ', 'RANDOM''S  ');
    Writeln(Fa, Format('%-20s', ['REGION']), Format('%8s',['#CELLS']),
    Format('%10s', ['#CORRECT']), Format('%10s', ['%CORRECT']),
    Format('%10s', ['%CORRECT']), Format('%10s', ['KAPPA']));
    Writeln(Fa, '---------------------------------------------------------------------');

    NVLDYESS := 0;   {NVLDYESS is # correctly simulated pixels (all nations).}
    For IRGN := 1 To NRGN do
    begin
    NVLDYES := 0;    {NVLDYES is # correctly simulated pixels (1 nation).}
    For row := RGNNORTH[IRGN] To RGNSOUTH[IRGN] do
    For col := RGNWEST[IRGN] To RGNEAST[IRGN] do
    begin
    If Not ((MAPRGN[row, col] <> RGNVAL[IRGN]) Or
    (MAPVLD[row, col] = VLDOUT) Or
    (MAPLND1[row, col] = NODATA) Or
    ((DSRTMAP = 1) And (MAPDSRT[row, col] = DSRTVALU))) Then
    begin

    If (MAPLND2[row, col] = MAPVLD[row, col]) Then
    begin
    NVLDYES := NVLDYES + 1;    {Sums #successes in IRGN for YEAR.}
    NVLDYESS := NVLDYESS + 1;  {Sums #successes in map  for YEAR.}
    End;

    If (WRTOPEN <> 2) And (DRCOUNT = 1) Then  {Else do HISVLD.}
    begin
    HISVLDR[IRGN] := HISVLDR[IRGN] + 1;  {#Cells in validation map.}
    HISVLDRS := HISVLDRS + 1;            {#Cells valid map (sum IRGN).}
    For ITYPE := 1 To NTYPE do
    begin
    If (MAPVLD[row, col] = TYPEVAL[ITYPE]) Then
    begin
    HISVLD[IRGN, ITYPE] := HISVLD[IRGN, ITYPE] + 1;  {Valid hist.}
    HISVLDT[ITYPE] := HISVLDT[ITYPE] + 1;            {Valid hist.}
    break; {Exit For}
    end;
    end; {Next ITYPE}
    end; {End If}
    end; {End If}
    end; {Next col}
    {Next row}

    {If this is the 1st time thru subroutine SWRITER, then compute
    the # successes expected from a random assignment.}
    If (WRTOPEN <> 2) And (DRCOUNT <= 1) Then
    begin
    NVLDEX[IRGN] := 0.0;   {initialize expected # successes in IRGN.}
    NNONCANR := 0;        {Counts # non-candidates in region.}
    {This next loop computes the number of candidates for change.}
    If (BLANKMAP <> 1) Then
    begin
    For ITYPE := 1 To NTYPE do
    begin
    If (HISINI[IRGN, ITYPE] <= HISVLD[IRGN, ITYPE]) Then
    begin
    NNONCAN[ITYPE] := HISINI[IRGN, ITYPE];
    NNONCANR := NNONCANR + NNONCAN[ITYPE];
    end
    Else
    NNONCAN[ITYPE] := 0;
    end; {Next ITYPE}
    end; {End If}

    {Next section computes number of expected successes in IRGN.}
    If (NNONCANR = HISVLDR[IRGN]) Then
    NVLDEX[IRGN] := NNONCANR
    Else
    begin
    For ITYPE := 1 To NTYPE do
    NVLDEX[IRGN] := NVLDEX[IRGN] + NNONCAN[ITYPE] +
    Sqr(HISVLD[IRGN, ITYPE] - NNONCAN[ITYPE]) /
    (HISVLDR[IRGN] - NNONCANR) {with stratification.}
    end; {End If}

    NVLDEXS := NVLDEXS + NVLDEX[IRGN]; {#expected wins with stratification.}
    If (IRGN = NRGN) And (DRCOUNT = 1) Then
    begin
    Writeln(Fb);
    Writeln(Fb, '//The following statistics is for Run ' + IntToStr(DRCOUNT));
    {Next line writes delta success due to 1 misclassification.}
    Writeln(Fb, 'DELTA % SUCCESS DUE TO 1 MISCLASSIFIED PAIR    : ',
    format('%6.2f', [100.0 * 2 / HMAPT]));
    {Next line writes guaranteed success rate.}
    Writeln(Fb, '% OF RASTERS THAT ARE NOT CANDIDATES FOR CHANGE: ',
    format('%6.2f', [100.0 * NVLDFREE / HMAPT]));
    {Next line writes minimum success rate.}
    Writeln(Fb, 'MINIMUM % SUCCESS RATE DUE TO ONE WAY CHANGE   : ',
    format('%6.2f', [100.0 * NVLDMIN / HMAPT]));
    {Next line writes random success rate without stratification.}
    Writeln(Fb, 'RANDOM % SUCCESS RATE WITHOUT STRATIFICATION IS: ',
    format('%6.2f', [100.0 * NVLDEXST / HMAPT]));
    {Next line writes random success rate with stratification.}
    Writeln(Fb, 'RANDOM % SUCCESS RATE WITH STRATIFICATION IS   : ',
    format('%6.2f', [100.0 * NVLDEXS / HISVLDRS]));

    Writeln(Fb);
    Writeln(Fb, '"KAPPA" PARAMETER BASED ON NO STRATIFICATION &');
    Writeln(Fb, '"KAPPAS" PARAMETER BASED ON STRATIFICATION;');
    Write(Fb, format('%8s', ['%correct']), format('%8s', ['Kappa']),
    format('%8s', ['Kappas']), format('%8s', ['tot#']));
    If SUITOPTION = COMP_SUIT then
    For i := 1 To NMAPP do {Writes Titles for driver weights.}
    Write(Fb, format('%8s', ['drv' + IntToStr(i)])); Writeln(Fb);
    end; {End If}
    end; {End If}

    {Compute actual success rate, expected success rate, and coefficient.}
    If HISVLDR[IRGN] <> 0 then
    begin
    VALIDP := 100.0 * NVLDYES / HISVLDR[IRGN];
    VALIDEXP := 100.0 * NVLDEX[IRGN] / HISVLDR[IRGN];
    end
    Else
    begin
    VALIDP := 0;
    VALIDEXP := 0;
    end;

    If (HISVLDR[IRGN] <> NVLDEX[IRGN]) Then
    Value := (NVLDYES - NVLDEX[IRGN]) / (HISVLDR[IRGN] - NVLDEX[IRGN])
    Else
    Value := 0.0;

    Writeln(Fa, format('%-20s', [Trim(FRGNNAME[IRGN])]),
    format('%8d', [HISVLDR[IRGN]]),
    format('%10d', [NVLDYES]),
    format('%10.2f', [VALIDP]),
    format('%10.2f', [VALIDEXP]),     {validex}
    format('%10.2f', [Value]));

    {Checking to see if actual histogram = validation histogram.}
    If (HISRGN[IRGN] <> HISVLDR[IRGN]) Then
    begin
    Writeln(Fw, 'Warnings for Run ', DRCOUNT);
    Writeln(Fw, 'Warning:(#cells) <> (validation #cells) in ', FRGNNAME[IRGN]);
    end
    Else
    begin
    For ITYPE := 1 To NTYPE do
    If (HISMAP[IRGN, ITYPE] <> HISVLD[IRGN, ITYPE]) Then
    begin
    Writeln(Fw, 'Warnings for run ', DRCOUNT);
    Writeln(Fw, FRGNNAME[IRGN], '! Warning:(#cells = ', HISMAP[IRGN, ITYPE],
    ') <> (validation #cells = ', HISVLD[IRGN, ITYPE], ') for ITYPE = ', ITYPE);
    end;
    end; {End If}
    end; {Next IRGN}

    {Writing the Bottom lines of validation information.}
    VALIDP := 100.0 * NVLDYESS / HISVLDRS;      {success rate in TOTAL.}
    VALIDEXP := 100.0 * NVLDEXS / HISVLDRS;
    If (HISVLDRS <> NVLDEXS) Then
    Value := (NVLDYESS - NVLDEXS) / (HISVLDRS - NVLDEXS)
    Else
    Value := 0.0;

    If (HISVLDRS <> NVLDEXST) Then
    VALUET := (NVLDYESS - NVLDEXST) / (HISVLDRS - NVLDEXST)
    Else
    VALUET := 0.0;

    Writeln(Fa, '---------------------------------------------------------------------');
    Writeln(Fa, format('%-20s', ['Total']),
    format('%8d', [HISVLDRS]),
    format('%10d', [NVLDYESS]),
    format('%10.2f', [VALIDP]),
    format('%10.2f', [VALIDEXP]),
    format('%10.2f', [VALUE]));

    Writeln(Fa);
    Writeln(Fa, 'KAPPA PARAMETER BASED ON NO STRATIFICATION = ', Format('%-6.2f', [VALUET]));
    Writeln(Fa);
    Writeln(Fa, '//End of Run ' + IntToStr(DRCOUNT) + '*******************************************************');  {Writes a line at bottom.}

    If SUITOPTION = COMP_SUIT then
    begin
    Write(Fb, format('%8.2f',[VALIDP]),
    format('%8.2f', [VALUET]),
    format('%8.2f', [VALUE]),
    format('%8.2f', [FMAPPWTT[DRCOUNT]]));
    For i := 4 + NMAPC To 3 + NMAPC + NMAPP do
    Write(Fb, format('%8.2f',[FMAPPWT[DRCOUNT, i]]));  Writeln(Fb);
    end
    Else
    begin
    Writeln(Fb, format('%8.2f',[VALIDP]),
    format('%8.2f', [VALUET]),
    format('%8.2f', [VALUE]));
    end;

    WRTOPEN := 2; {have written}

    end; {End If year = vldyear}
  *)
  { This concludes the GEOMOD*.WKS portion of this SWRITER subroutine. }

  { The next lines prevent Lubrication map from being written again. }
  if (WRTLUBI = 1)
  then { In this program, only idrisi format maps will be output }
    // WRTASC(4) := 0;  {skip}
    // WRTIMG(4) := 0;  {skip}
    // WRTSQG(4) := 0;  {skip}
    // WRTSQR(4) := 0;  {skip}
    WRTRST[4] := 0; { prepare to output Idrisi maps }

  { The next routine converts the real friction map to an integer
    friction percentile map. }

  // If Not ((WRTASC(4) = 0 And WRTIMG(4) = 0 And WRTSQG(4) = 0
  // And WRTSQR(4) = 0) Or WRTLUBI <> 0) Then

  (*
    If (WRTRST[4] <> 0) And (WRTLUBI = 0) Then
    begin
    {---computing the lubrication decile map---}
    For IRGN := 1 To NRGN do
    For row := RGNNORTH[IRGN] To RGNSOUTH[IRGN] do
    For col := RGNWEST[IRGN] To RGNEAST[IRGN] do
    begin
    If Not ((MAPRGN[row, col] <> RGNVAL[IRGN]) Or
    (MAPLND1[row, col] = NODATA) Or
    ((DSRTMAP = 1) And
    (MAPDSRT[row, col] = DSRTVALU))) Then
    begin
    For rrow := row To RGNSOUTH[IRGN] do
    For rcol := RGNWEST[IRGN] To RGNEAST[IRGN] do
    If Not (((MAPRGN[rrow, rcol] <> RGNVAL[IRGN]) Or
    (MAPLND1[rrow, rcol] = NODATA)) Or
    ((rrow = row) And (rcol <= col)) Or
    ((DSRTMAP = 1) And
    (MAPDSRT[rrow, rcol] = DSRTVALU))) Then
    begin
    If (MAPFRCP[rrow, rcol] = MAPFRCP[row, col]) Then
    begin
    MAPLUBI[row, col] := MAPLUBI[row, col] + 1;
    MAPLUBI[rrow, rcol] := MAPLUBI[rrow, rcol] + 1;
    end
    Else If (MAPFRCP[rrow, rcol] < MAPFRCP[row, col]) Then
    MAPLUBI[row, col] := MAPLUBI[row, col] + 1
    Else
    MAPLUBI[rrow, rcol] := MAPLUBI[rrow, rcol] + 1;
    end;
    {Next rcol}
    {Next rrow}
    MAPLUBI[row, col] := 1 + Round(NPERCLAS * MAPLUBI[row, col] / HISRGN[IRGN]);
    //MAPLUBI[row, col] := 1 + Int(NPERCLAS * MAPLUBI[row, col] / HISRGN[IRGN]);
    end; {End If}
    end; {Next col}
    {Next row}
    {Next IRGN}
    WRTLUBI := 1;
    end; {End If}
  *)
  // The MAPOUT loop, loops thru all the output vairables presented in maps.
  for IMAP := 1 to 3 do { 3 Kinds of output maps: LND, CBNYR, CBNCU }
  // FNUM = 30 + IMAP * 10
  begin
    { This section writes Idrisi's ".RST" maps. }
    MaxValue := 0;
    MinValue := 0;
    if (WRTRST[IMAP] <> 0) then
    begin
      if NYEARWRT = 0 then
      begin
        if (IMAP = 1) then
          FOUT := Trim(ResultImagesPath) + OUTPUTFINAL[1] + '_' +
            inttostr(DRCOUNT) + '.RST';
        if (IMAP = 2) then
          FOUT := Trim(ResultImagesPath) + OUTPUTFINAL[2] + '_' +
            inttostr(DRCOUNT) + '.RST';
        if (IMAP = 3) then
          FOUT := Trim(ResultImagesPath) + OUTPUTFINAL[3] + '_' +
            inttostr(DRCOUNT) + '.RST';
      end
      else
      begin
        if (IMAP = 1) then
          FOUT := Trim(ResultImagesPath) + PREFIXFINAL[1] + FYEAR + '_' +
            inttostr(DRCOUNT) + '.RST';
        if (IMAP = 2) then
          FOUT := Trim(ResultImagesPath) + PREFIXFINAL[2] + FYEAR + '_' +
            inttostr(DRCOUNT) + '.RST';
        if (IMAP = 3) then
          FOUT := Trim(ResultImagesPath) + PREFIXFINAL[3] + FYEAR + '_' +
            inttostr(DRCOUNT) + '.RST';
      end;

      AssignFile(F, FOUT);
      if IMAP = 1 then
        ReWrite(F, 1) { landuse map is byte type }
      else
        ReWrite(F, 4); { output Idirsi real images (4 bytes) }

      // Application.StatusBar = 'Writing Idrisi raster map ' + ''' + FOUT + ''' + '...'

      SetLength(Bytebuf, NCOL);
      SetLength(IntBuf, NCOL);
      SetLength(Realbuf, NCOL);
      for row := 1 to NROW do
      begin
        if (row mod ROW_RANGE) = 0 then
          if not IdrisiAPI.IsValidProcId(process_id) then
          begin
            bTerminateApplication := true; // quit the entire application
            Exit;
          end;

        { read into buf }
        for col := 1 to NCOL do
          if (IMAP = 1) then
          begin
            Bytebuf[col - 1] := MAPLND2[row, col]; // Idrisi byte

            if MAPLND2[row, col] > MaxValue then
              MaxValue := MAPLND2[row, col];

            if MAPLND2[row, col] < MinValue then
              MinValue := MAPLND2[row, col];
          end
          else if (IMAP = 2) then
          begin
            Realbuf[col - 1] := MAPFLXYR[row, col]; // Idrisi real

            if MAPFLXYR[row, col] > MaxValue then
              MaxValue := MAPFLXYR[row, col];

            if MAPFLXYR[row, col] < MinValue then
              MinValue := MAPFLXYR[row, col];
          end
          else if (IMAP = 3) then
          begin
            Realbuf[col - 1] := MAPFLXCU[row, col]; // Idrisi real

            if MAPFLXCU[row, col] > MaxValue then
              MaxValue := MAPFLXCU[row, col];

            if MAPFLXCU[row, col] < MinValue then
              MinValue := MAPFLXCU[row, col];
          end;
        // Else If (IMAP = 4) Then
        // begin
        // Intbuf[col - 1] := MAPLUBI[row, col];   //Idrisi integer
        //
        // If MAPLUBI[row, col] > MaxValue then
        // MaxValue := MAPLUBI[row, col];
        //
        // If MAPLUBI[row, col] < MinValue then
        // MinValue := MAPLUBI[row, col];
        // end;

        { write to file from the buffer }
        if (IMAP = 1) then
          BlockWrite(F, Bytebuf[0], NCOL)
        else if (IMAP = 2) or (IMAP = 3) then
          BlockWrite(F, Realbuf[0], NCOL); // WRITE(F, NINT(MAPFLXYR[ROW,COL]));
        // Else If (IMAP = 4) Then
        // BlockWrite(F, Intbuf[0], NCOL);   // WRITE(F, NINT(MAPFLXYR[ROW,COL]));

      end;

      // write documentation file
      case IMAP of
        1:
          begin
            title := FYEAR + ' land use/cover map';
            CreateImgDocFile(FOUT, title, DATA_TYPE_BYTE, MaxValue, MinValue,
              FMAPNAME[3], false, 0); // initial land-use map      //T - 12/17/19 - added last 2 parameters
          end;
        2:
          begin
            title := FYEAR + ' environmental impact map';
            CreateImgDocFile(FOUT, title, DATA_TYPE_REAL, MaxValue, MinValue,
              FMAPNAME[3], false, 0);   //T - 12/17/19 - added last 2 parameters
          end;
        3:
          begin
            title := FYEAR + ' cummulative environmental impact map';
            CreateImgDocFile(FOUT, title, DATA_TYPE_REAL, MaxValue, MinValue,
              FMAPNAME[3], false, 0);     //T - 12/17/19 - added last 2 parameters
          end;
        // 4: begin
        // title := FYEAR + ' lubrication percentile map';
        // CreateImgDocFile(FOUT, title, DATA_TYPE_INTEGER, MaxValue, MinValue, FMAPNAME[3]);
        // end;
      end;

      Bytebuf := nil;
      IntBuf := nil;
      Realbuf := nil;
      // Application.StatusBar = 'Complete Idrisi file writing...'
      CloseFile(F); // #FNUM + 4
      // **             If (IFDISPLAY <> 0) or (YEAR = YEAREND) then
      if (IFDISPLAY <> 0) then
        // always do not display the result as default setting.
        if IMAP = 1 then
          IdrisiAPI.DisplayFile(GetRstFileName(FOUT),
            IdrisiAPI.Get_DefaultQualPal, 0, 0, 0, 0, 0, true,
            getshortname(FOUT))
        else
          IdrisiAPI.DisplayFile(GetRstFileName(FOUT),
            IdrisiAPI.Get_DefaultQuantPal, 0, 0, 0, 0, 0, true,
            getshortname(FOUT));
    end;
  end;

  (* the statistical outputs have been removed for the unconstant computing logic
    with that used in the multivalidate module

    IF (YEAR = YEAREND) then
    begin
    CloseFile(Fa);
    CloseFile(Fb);
    CloseFile(Fw);
    end;

    If (DRCOUNT = NLOOPS) and (YEAR = YEAREND) then
    begin
    IdrisiAPI.ShowTextResults('Geomod''s Resultant Statistics #1: ' + Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wka'), Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wka'));
    IdrisiAPI.ShowTextResults('Geomod''s Resultant Statistics #2: ' + Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wkb'), Trim(ResultImagesPath) + ChangeFileExt(ExtractFileName(GmParameterFileName), '.wkb'));
    end;
  *)
end; { end of procedure Swriter }

function CreateImgDocFile(var OutputImageDoc: string; DocTitle: string;
  OutDataType: integer; MaxV, MinV: Single; refimg: string; flag : boolean; flagval : single): boolean;
var
  RefDoc: TImgDoc;

begin

  try
    Result := false;

    RefDoc := TImgDoc.CREATE;
    refimg := ReturnCompleteFileName(READ_FILE, refimg, '.rst');
    if refimg = '' then
      Exit;

    if not RetrieveRDCParameter(refimg, RefDoc) then
    begin
      RefDoc.Free;
      Exit;
    end;

    OutputImageDoc := changeFileExt(OutputImageDoc, '.rdc');

    RefDoc.title := DocTitle;
    RefDoc.FileType := FILE_TYPE_BINARY;
    RefDoc.DataType := OutDataType;
    RefDoc.Resolution := (RefDoc.MaxX - RefDoc.MinX) / RefDoc.Cols;

    RefDoc.MinValue := MinV;
    RefDoc.MaxValue := MaxV;

    RefDoc.DisplayMin := MinV;
    RefDoc.DisplayMax := MaxV;

    if OutDataType <> DATA_TYPE_BYTE then
      RefDoc.LegendCats := 0;

    if flag then //T - 12/17/19
      begin
        RefDoc.FlagFlag := true;
        RefDoc.FlagValue := flagval;
      end;

    writeRDCFile(OutputImageDoc, RefDoc);
    // write doc file due to the change of Max/Min values

    RefDoc.Free;

    Result := true;
  except
    on Exception do
    begin
      // ShowMessage('Writing documentation file failed. Please check the parameters input.');
      Result := false;
      Exit;
    end;
  end;
end;

function NINT(a: double): integer;
begin
  if a > 0 then
    Result := Round(Int(a + 0.5))
  else if a = 0 then
    Result := 0
  else
    Result := Round(Int(a - 0.5));
end; { end of Function }

function RetrieveRDCParameter(imgfilename: string; var Rdoc: TImgDoc): boolean;

var
  filename1, filename: string;
  SuccessFlag: integer;
  errcode: integer;
begin
  Result := false;
  { Read the Meta File }
  // If Not CheckInFile(IdrisiAPI, FILE_TYPE_BINARY, imgfilename, errcode) then
  // begin
  // Error_Message(errcode);
  // exit;
  // end;

  // filename := getdocname(imgfilename);
  filename := ReturnCompleteFileName(READ_FILE, imgfilename, '.rst');
  filename := getdocname(imgfilename);
  SuccessFlag := ReadImgDocFile(filename, Rdoc);
  if SuccessFlag <> 0 then
  begin
    ShowMessage('The file, ' + filename + ', not found.');
    Exit;
  end;

  Result := true;
end;

function CheckAndReadMap(Fname: string; NumRowCheck, NumColCheck: integer;
  FirstRowID, LastRowID: integer; var OutputMap: TSingleMap): boolean;
var
  Inf: file;
  Bytebuf: array of byte;
  IntBuf: array of Smallint;
  Realbuf: array of Single;
  InputMapDoc: TImgDoc;
  i, j: integer;
  ReadFileSuccess: boolean;
begin
  Result := true;

  InputMapDoc := TImgDoc.CREATE;
  ReadFileSuccess := RetrieveRDCParameter(Fname, InputMapDoc);

  if not ReadFileSuccess then
  begin
    InputMapDoc.Free;
    Result := false;
    Exit;
  end;

  if not(InputMapDoc.FileType in [1]) then // binary file type
  begin
    beep;
    ShowMessage('The file type should be binary.');
    InputMapDoc.Free;
    Result := false;
    Exit;
  end
  // Else If Not (InputMapDoc.DataType in [0, 2]) then
  // begin
  // beep;
  // ShowMessage('The data type of image, ' + Fname + ' should be byte or integer.');
  // InputMapDoc.Free;
  // Result := False;
  // Exit;
  // end
  else if (InputMapDoc.Rows <> NumRowCheck) or (InputMapDoc.Cols <> NumColCheck)
  then
  begin
    beep;
    ShowMessage('The numbers of rows and/or columns of image, ' + Fname +
      ', do not match the region image.');
    InputMapDoc.Free;
    Result := false;
    Exit;
  end;

  try
    AssignFile(Inf, Fname);
    if InputMapDoc.DataType = DATA_TYPE_BYTE then
    begin
      SetLength(Bytebuf, InputMapDoc.Cols);
      Reset(Inf, 1);
      Seek(Inf, FirstRowID * InputMapDoc.Cols);
      for i := 0 to LastRowID - FirstRowID do
      begin
        BlockRead(Inf, Bytebuf[0], InputMapDoc.Cols);
        for j := 0 to InputMapDoc.Cols - 1 do
          OutputMap[i + 1, j + 1] := Bytebuf[j];
      end;
      Bytebuf := nil;
    end
    else if InputMapDoc.DataType = DATA_TYPE_INTEGER then
    begin
      SetLength(IntBuf, InputMapDoc.Cols);
      Reset(Inf, 2);
      Seek(Inf, FirstRowID * InputMapDoc.Cols);

      // For i := 0 to inputmapdoc.rows - 1 do
      for i := 0 to LastRowID - FirstRowID do
      begin
        BlockRead(Inf, IntBuf[0], InputMapDoc.Cols);
        for j := 0 to InputMapDoc.Cols - 1 do
          OutputMap[i + 1, j + 1] := IntBuf[j];
      end;
      IntBuf := nil;
    end
    else if InputMapDoc.DataType = DATA_TYPE_REAL then
    begin
      SetLength(Realbuf, InputMapDoc.Cols);
      Reset(Inf, 4);
      Seek(Inf, FirstRowID * InputMapDoc.Cols);
      // For i := 0 to inputmapdoc.rows - 1 do
      for i := 0 to LastRowID - FirstRowID do
      begin
        BlockRead(Inf, Realbuf[0], InputMapDoc.Cols);
        for j := 0 to InputMapDoc.Cols - 1 do
          OutputMap[i + 1, j + 1] := Realbuf[j];
      end;
      Realbuf := nil;
    end;

    CloseFile(Inf);
    InputMapDoc.Free;
  except
    on Exception do
    begin
      CloseFile(Inf);
      ShowMessage('Unexpected I/O errors: unable to read the image, ' +
        Fname + '.');
      InputMapDoc.Free;
      Result := false;
      Exit;
    end;
  end;
end;

function GetRstFileName(Fname: string): string;
begin
  Result := Copy(Fname, 1, Length(Fname) - 4) + '.rst';
end;

function WithPath(filename: string): boolean;
begin
  Result := false;
  if Pos('\', filename) <> 0 then
    Result := true
  else if Pos(':', filename) <> 0 then
    Result := true;
end;

function ValidDirectory(filename: string): boolean;
begin
  Result := true;
  if not DirectoryExists(ExtractFilePath(filename)) then
    Result := false;
end;

function WithFileExtension(filename: string; const Extension: string): boolean;
begin
  Result := false;
  if Pos(Extension, filename) <> 0 then
    Result := true;
end;

function ReturnCompleteFileName(ReadOrWrite: integer; filename: string;
  const Extension: string): string;
var
  i: integer;
  found: boolean;
begin
  Result := '';
  found := false;

  if not WithPath(filename) then
  begin
    if not WithFileExtension(filename, Extension) then
    begin
      if ReadOrWrite = READ_FILE then
      begin
        if FileExists(IdrisiAPI.GetWorkingDir + filename + Extension) then
        begin
          found := true;
          Result := IdrisiAPI.GetWorkingDir + filename + Extension;
        end;

        if not found then
        begin
          for i := 1 to IdrisiAPI.GetResourceDirCount do
            if FileExists(IdrisiAPI.GetResourceDir(i) + filename + Extension)
            then
            begin
              found := true;
              Result := IdrisiAPI.GetResourceDir(i) + filename + Extension;
              break;
            end;
        end;
      end
      else if ReadOrWrite = WRITE_FILE then
        Result := IdrisiAPI.GetWorkingDir + filename + Extension;
    end
    else
    begin
      if ReadOrWrite = READ_FILE then
      begin
        if FileExists(IdrisiAPI.GetWorkingDir + filename) then
        begin
          found := true;
          Result := IdrisiAPI.GetWorkingDir + filename;
        end;

        if not found then
        begin
          for i := 1 to IdrisiAPI.GetResourceDirCount do
            if FileExists(IdrisiAPI.GetResourceDir(i) + filename) then
            begin
              found := true;
              Result := IdrisiAPI.GetResourceDir(i) + filename;
              break;
            end;
        end;
      end
      else if ReadOrWrite = WRITE_FILE then
        Result := IdrisiAPI.GetWorkingDir + filename;

    end;
  end
  else
  begin
    if not ValidDirectory(filename) then
    begin
      ShowMessage('The directory of file, ' + filename + ' not found.');
      Result := '';
    end
    else
    begin
      if WithFileExtension(filename, Extension) then
        Result := filename
      else
        Result := filename + Extension;
    end;
  end;

end;

procedure Get_Windows_Cmdln;

var
  TmpStr: string;

begin

  { access all macro parameters here }
  { eg. infile:=IdrParamStr(2); }
  { note that the first macro parameter is }
  { number 2 since number 1 contains the "x" }

  GmParameterFileName := IdrParamStr(2); // get project name
  TmpStr := ReturnCompleteFileName(READ_FILE, GmParameterFileName, GMF_EXT);
  if TmpStr = '' then
  begin
    ShowMessage('Geomod parameter file not found.');
    CleanUp;
    Halt;
  end
  else
    GmParameterFileName := TmpStr;
  // **GetInputFileNames(GmProjectName); // read input files names from the project file
end;

procedure GetInputFileNames(projectname: string);
// read input files names from the project file
var
  F: TextFile;
begin
  (*
    Try
    AssignFile(f, ProjectName);
    ReSet(f);

    Readln(f);
    Readln(f, GMInputFile1);
    Readln(f, GMInputFile2);
    CloseFile(f);
    Except
    on exception do
    begin
    ShowMessage('Unexpected errors in reading the project file.');
    CloseFile(f);
    Halt;
    end;
    end;
  *)
end;

procedure Snewera;
{ **************************************
  subroutine Snewera
  **************************************
  Since gemod.se2 has been incorporated into geomod.se1 in the new idrisi version,
  and number of eras is confined to just 1, SNEWERA reads geomod.se2. This subroutine
  has literally removed. The Regional set files contain parameters which are specific to an era.
  Such paramters are land use change rate, land use transistion likelihood
  matrix, and CO2 flux matrix. }

begin
  // This subroutine Snewera has been removed out of the new idrisi version for its being coupled into Sreader Subroutine.
  // Except the ending time landuse information, when no validation image provided, needs to be sepecified by the user, all other matrics
  // including transsition likelihood and co2 flux percentage, and the biomass per category will be automatically
  // generated by the module as long as the user can provide a couple of images about self-defined fixed ratio or percentage.

end; { end of procedure Snewera }

end.
