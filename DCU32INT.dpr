{$A+,B-,C+,D+,E-,F-,G+,H+,I+,J+,K-,L+,M-,N+,O+,P+,Q-,R-,S-,T-,U-,V+,W-,X+,Y+,Z1}
{$APPTYPE CONSOLE}
program dcu32int;
(*
The main module of the DCU32INT utility by Alexei Hmelnov.
----------------------------------------------------------------------------
E-Mail: alex@icc.ru
http://hmelnov.icc.ru/DCU/
----------------------------------------------------------------------------

See the file "readme.txt" for more details.

------------------------------------------------------------------------
                             IMPORTANT NOTE:
This software is provided 'as-is', without any expressed or implied warranty.
In no event will the author be held liable for any damages arising from the
use of this software.
Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:
1. The origin of this software must not be misrepresented, you must not
   claim that you wrote the original software.
2. Altered source versions must be plainly marked as such, and must not
   be misrepresented as being the original software.
3. This notice may not be removed or altered from any source
   distribution.
*)
//  {$IFNDEF LINUX}Windows,{$ELSE}LinuxFix,{$ENDIF}

uses
  SysUtils,
  DCU32 in 'DCU32.pas',
  DCUTbl in 'DCUTbl.pas',
  DCU_In in 'DCU_In.pas',
  DCU_Out in 'DCU_Out.pas',
  FixUp in 'FixUp.pas',
  DCURecs in 'DCURecs.pas',
  DasmDefs in 'DasmDefs.pas',
  DasmCF in 'DasmCF.pas',
  DCP in 'DCP.pas',
  DasmX86 in 'DasmX86.pas',
  DasmMSIL in 'DasmMSIL.pas';

{$R *.res}

procedure WriteUsage;
begin
  Writeln(
  'Usage:'#13#10+
  '  DCU32INT <Source file> <Flags> [<Destination file>]'#13#10+
  'Destination file may contain * to be replaced by unit name or name and extension'#13#10+
  'Destination file = "-" => write to stdout.'#13#10+
 {$IFNDEF LINUX}
  'Flags (start with "/" or "-"):'#13#10+
 {$ELSE}
  'Flags (start with "-"):'#13#10+
 {$ENDIF}
  ' -S<show flag>* - Show flags (-S - show all), default: (+) - on, (-) - off'#13#10+
  '    A(-) - show Address table'#13#10+
  '    C(-) - don''t resolve Constant values'#13#10+
  '    D(-) - show Data block'#13#10+
  '    d(-) - show dot types'#13#10+
  '    F(-) - show Fixups'#13#10+
  '    I(+) - show Imported names'#13#10+
  '    L(-) - show table of Local variables'#13#10+
  '    M(-) - don''t resolve class Methods'#13#10+
  '    O(-) - show file Offsets'#13#10+
  '    T(-) - show Type table'#13#10+
  '    U(-) - show Units of imported names'#13#10+
  '    V(-) - show auxiliary Values'#13#10+
  '    v(-) - show VMT'#13#10+
  ' -O<option>* - code generation options, default: (+) - on, (-) - off'#13#10+
  '    V(-) - typed constants as variables'#13#10+
  ' -I - interface part only'#13#10+
  ' -U<paths> - Unit directories'#13#10+
  ' -P<paths> - Pascal source directories (just "-P" means: "seek for *.pas in'#13#10+
  '    the unit directory"). Without this parameter src lines won''t be reported'#13#10+
  ' -R<Alias>=<unit>[;<Alias>=<unit>]* - set unit aliases'#13#10+
  ' -N<Prefix> - No Name Prefix ("%" - Scope char)'#13#10+
  ' -D<Prefix> - Dot Name Prefix ("%" - Scope char)'#13#10+
  ' -A<Mode> - disAssembler mode'#13#10+
  '    S(+) - simple Sequential (all memory is a sequence of ops)'#13#10+
  '    C(-) - control flow'#13#10
  );
end ;

const
  DCUName: String = '';
  FNRes: String = '';

function ProcessParms: boolean;
var
  i,j: integer;
  PS: String;
  Ch: Char;
begin
  Result := false;
  for i:=1 to ParamCount do begin
    PS := ParamStr(i);
    if (Length(PS)>1)and({$IFNDEF LINUX}(PS[1]='/')or{$ENDIF}(PS[1]='-')) then begin
      Ch := UpCase(PS[2]);
      case Ch of
        'H','?': begin
          WriteUsage;
          Exit;
         end ;
        'S': begin
          if Length(PS)=2 then
            SetShowAll
          else begin
            for j:=3 to Length(PS) do begin
              Ch := {UpCase(}PS[j]{)};
              case Ch of
                'A': ShowAddrTbl := true;
                'C': ResolveConsts := false;
                'D': ShowDataBlock := true;
                'd': ShowDotTypes := true;
                'F': ShowFixupTbl := true;
                'I': ShowImpNames := false;
                'T': ShowTypeTbl := true;
                'L': ShowLocVarTbl := true;
                'M': ResolveMethods := false;
                'O': ShowFileOffsets := true;
                'U': ShowImpNamesUnits := true;
                'V': ShowAuxValues := true;
                'v': ShowVMT := true;
              else
                Writeln('Unknown show flag: "',Ch,'"');
                Exit;
              end ;
            end ;
          end ;
        end ;
        'O':
          for j:=3 to Length(PS) do begin
            Ch := {UpCase(}PS[j]{)};
            case Ch of
              'V': GenVarCAsVars := true;
            else
              Writeln('Unknown code generation option: "',Ch,'"');
              Exit;
            end ;
          end ;
        'I': InterfaceOnly := true;
        'U': begin
          Delete(PS,1,2);
          DCUPath := PS;
        end ;
        'R': begin
          Delete(PS,1,2);
          SetUnitAliases(PS);
        end ;
        'P': begin
          Delete(PS,1,2);
          PASPath := PS;
        end ;
        'N': begin
          Delete(PS,1,2);
          NoNamePrefix := PS;
        end ;
        'D': begin
          Delete(PS,1,2);
          DotNamePrefix := PS;
        end ;
        'A': begin
           if Length(PS)=2 then
             Ch := 'C'
           else
             Ch := UpCase(PS[3]);
           case Ch of
            'S': DasmMode := dasmSeq;
            'C': DasmMode := dasmCtlFlow;
           else
             Writeln('Unknown disassembler mode: "',Ch,'"');
             Exit;
           end ;
        end ;
      else
        Writeln('Unknown flag: "',Ch,'"');
        Exit;
      end ;
      Continue;
    end ;
    if DCUName='' then
      DCUName := PS
    else if FNRes='' then
      FNRes := PS
    else
      Exit;
  end ;
  Result := DCUName<>'';
end ;

function ReplaceStar(FNRes,FN: String): String;
var
  CP: PChar;
begin
  CP := StrScan(PChar(FNRes),'*');
  if CP=Nil then begin
    Result := FNRes;
    Exit;
  end ;
  if StrScan(CP+1,'*')<>Nil then
    raise Exception.Create('2nd "*" is not allowed');
  FN := ExtractFilename(FN);
  if (CP+1)^=#0 then begin
    Result := Copy(FNRes,1,CP-PChar(FNRes))+ChangeFileExt(FN,'.int');
    Exit;
  end;
  Result := Copy(FNRes,1,CP-PChar(FNRes))+ChangeFileExt(FN,'')+Copy(FNRes,CP-PChar(FNRes)+2,MaxInt);
end ;

function ProcessFile(FN: String): integer {ErrorLevel};
var
  U: TUnit;
  NS,ExcS: String;
  OutRedir: boolean;
  CP: PChar;
begin
  Result := 0;
  OutRedir := false;
  if FNRes='-' then
    FNRes := ''
  else begin
    Writeln{(StdErr)};
    Writeln('File: "',FN,'"');
    NS := ExtractFileName(FN);
    CP := StrScan(PChar(NS),PkgSep);
    if CP<>Nil then
      NS := StrPas(CP+1);
    if FNRes='' then
      FNRes := ExtractFilePath(FN)+ChangeFileExt(NS,'.int')
    else
      FNRes := ReplaceStar(FNRes,FN);
    Writeln('Result: "',FNRes,'"');
//    CloseFile(Output);
    Flush(Output);
    OutRedir := true;
  end ;
  AssignFile(FRes,FNRes);
  TTextRec(FRes).Mode := fmClosed;
  try
    try
      Rewrite(FRes); //Test whether the FNRes is a correct file name
      try
        InitOut;
        FN := ExpandFileName(FN);
        U := Nil;
        try
          U := GetDCUByName(FN,'',0,false,0){TUnit.Create(FN)};
        finally
          if U=Nil then
            U := MainUnit;
          if U<>Nil then
            U.Show;
        end ;
      finally
        FreeDCU;
      end ;
    except
      on E: Exception do begin
        Result := 1;
        ExcS := Format('%s: "%s"',[E.ClassName,E.Message]);
        if TTextRec(FRes).Mode<>fmClosed then begin
          Writeln(FRes);
          Writeln(FRes,ExcS);
          Flush(FRes);
        end ;
        if OutRedir then
          Writeln(ExcS);
      end ;
    end ;
  finally
    if TTextRec(FRes).Mode<>fmClosed then
      Close(FRes);
    if OutRedir then begin
      Writeln(Format('Total %d lines generated.',[OutLineNum]));
      Close(Output);
    end ;
  end ;
end ;

begin
  if not ProcessParms then begin
    Writeln('Call this program with -? or -h parameters for help on usage.');//WriteUsage;
    Exit;
  end ;
  Halt(ProcessFile(DCUName));
end.
