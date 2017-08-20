{
    License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Copyright(c) (2016-2020) Steve Chekblain
}

PROGRAM BMPMaze;
{$IOCHECKS OFF}
{$LONGSTRINGS ON}
USES
  SysUtils,Windows,WinCrt;
TYPE
  TPoint = record
    x,y : Longint;
  End;
CONST
  C_Up      = 0;
  C_Right   = 1;
  C_Down    = 2;
  C_Left    = 3;
  C_Wall    = 0;
  C_Space   = 1;
  C_Visited = 2;
VAR
  _LogFile, _SolveFile    : Text;
  _BMPFile, _SolveBMP     : File of Byte;
  _Maze                   : Array of Array of 0..3;
  _Stack                  : Array of TPoint;
  _Start, _Exit, _Now     : TPoint;
  _Height, _Width, _StackTop, _FileSize, _DataPos,
  _HeadLen, _DataLen      : Longword;
  _SolveResult            : Longint;

//-------------------------------------------
// Forward

PROCEDURE Init; forward;
PROCEDURE RunMaze; forward;
PROCEDURE Solve; forward;
PROCEDURE SaveSolution; forward;
PROCEDURE stopAll; forward;
PROCEDURE logWrite(lstr: string); forward;
PROCEDURE qRead(var qdata: longword); forward;
PROCEDURE dRead(var ddata: word); forward;
PROCEDURE bRead(var bdata: byte); forward;
FUNCTION fHex(x: qword): string; forward;
FUNCTION loadBMP: string; forward;
FUNCTION findSpace(x1, x2, y1, y2: word): TPoint; forward;

//-------------------------------------------

OPERATOR =(a, b: TPoint)equ: boolean;
Begin
  Exit((a.x = b.x) and (a.y = b.y));
End;

//-------------------------------------------

OPERATOR <>(a, b: TPoint)neq: boolean;
Begin
  Exit((a.x <> b.x) or (a.y <> b.y));
End;

//-------------------------------------------

FUNCTION fHex(x: qword): string;
Begin
  Exit(IntToHex(x,2));
End;

//-------------------------------------------

FUNCTION findSpace(x1, x2, y1, y2: word): TPoint;
Var
  i, j: longint;
Begin
  findSpace.x := -1;
  for i := x1 to x2 do
    for j := y1 to y2 do
      if _Maze[i, j] = C_Space then
      begin
        findSpace.x := i;
        findSpace.y := j;
        exit;
      end;
End;

//-------------------------------------------

FUNCTION loadBMP: string;
Var
  btmp1, btmp2: byte;
  dtmp: word;
  qtmp: longword;
  i, j, k: longint;
  ktmp : string;
Begin
  assign(_BMPFile, ParamStr(1));
  reset(_BMPFile);
  read(_BMPFile, btmp1, btmp2);
  if chr(btmp1)+chr(btmp2) <> 'BM' then
    exit('Invalid BMP File!');
  qRead(_FileSize);
  qRead(qtmp);
  if qtmp <> 0 then
    logWrite('Warning: Reserved Bits aren''t 0.');
  qRead(_DataPos);
  qRead(_HeadLen);
  if _HeadLen <> $28 then
    exit('Invalid BMP Type!');
  qRead(_Width);
  qRead(_Height);
  if _Width * _Height > 1000000 then
  begin
    writeln('This maze is very LARGE, loading it may take up a lot of MEMORY and TIME, DO YOU WANT TO CONTINUE?(Y/N):');
    ktmp := '';
    while not (ktmp[1] in ['y', 'Y', 'n', 'N']) do readln(ktmp);
  end;
  dRead(dtmp);
  if dtmp <> 1 then
    logWrite('Warning: Bits Page Bit aren''t 1.');
  dRead(dtmp);
  if dtmp <> 1 then
    exit('Not a B&W BMP File!');
  qRead(qtmp);
  if qtmp <> 0 then
    exit('Not a BI_RGB BMP File!');
  qRead(_DataLen);
  if _DataLen mod 4 <> 0 then
    logWrite('Warning: Data Length should be a multiple of 4.');
  if _DataLen + _DataPos <> _FileSize then
    logWrite('Warning: Data Size Dismatch.');
  for i := 1 to 6 do qRead(qtmp);
  SetLength(_Maze, _Height + 100, _Width + 100);
  for i := _Height downto 1 do
  begin
    for j := 1 to (_Width - 1) div 8 + 1 do
    begin
      bRead(btmp1);
      for k := 8 downto 1 do
      begin
        _Maze[i, (j - 1) * 8 + k] := btmp1 and 1;
        btmp1 := btmp1 shr 1;
      end;
    end;
    for j := 1 to ((((_Width - 1) div 8 + 1) - 1) div 4 + 1) * 4 - ((_Width - 1) div 8 + 1) do
      bRead(btmp1);
  end;
  exit('Success!');
End;

//-------------------------------------------

PROCEDURE logWrite(lstr: string);
Var
  yy, mm, dd, h, m, s, ss: word;
Begin
  DecodeDate(Date,yy,mm,dd);
  DecodeTime(Time,h,m,s,ss);
  writeln(_LogFile, yy, '.', mm, '.', dd, ' ', copy('0' + IntToStr(h), length(IntToStr(h)), 2), ':', copy('0' + IntToStr(m), length(IntToStr(m)), 2), ':', copy('0' + IntToStr(s), length(IntToStr(s)), 2), '     ', lstr);
End;

//-------------------------------------------

PROCEDURE stopAll;
Begin
  logWrite('Program End.');
  close(_LogFile);
  close(_SolveBMP);
  close(_BMPFile);
  close(_SolveFile);
  halt;
End;

//-------------------------------------------

PROCEDURE qRead(var qdata: longword);
Var
  b1, b2, b3, b4: byte;
Begin
  bRead(b1);
  bRead(b2);
  bRead(b3);
  bRead(b4);
  qdata := b4 shl 24 + b3 shl 16 + b2 shl 8 + b1;
End;

//-------------------------------------------

PROCEDURE dRead(var ddata: word);
Var
  b1, b2: byte;
Begin
  bRead(b1);
  bRead(b2);
  ddata := b2 shl 8 + b1;
End;

//-------------------------------------------

PROCEDURE bRead(var bdata: byte);
Begin
  read(_BMPFile, bdata);
  If IOResult <> 0 then
  begin
    logWrite('Unexpected EOF!');
    writeln('Unexpected EOF!');
    stopAll;
  end;
End;

//-------------------------------------------

PROCEDURE Init;
Var
  stmp: string;
Begin
  writeln('Loading File...');
  if not FileExists(ParamStr(1)) then
  begin
    writeln('Invalid FileName!');
    writeln('Usage:');
    writeln('  ' + ExtractFileName(ParamStr(0)) ' <bmpfile>');
    stopAll;
  end;
  assign(_LogFile, 'log.txt');
  rewrite(_LogFile);

  stmp := loadBMP;
  If stmp <> 'Success!' then
  begin
    writeln(stmp);
    logWrite('Loading Error: ' + stmp);
    stopAll;
  end;
  writeln('File Successfully Loaded.');

  writeln('Loading Maze...');
  with _Start do
  begin
    _Start := findSpace(1, 1, 1, _Width);
    if x <= 0 then
      _Start := findSpace(1, _Height, 1, 1);
    if x <= 0 then
      _Start := findSpace(_Height, _Height, 1, _Width);
    if x <= 0 then
      _Start := findSpace(1, _Height, _Width, _Width);
    if x <= 0 then
    begin
      logWrite('Unable to Find Start Point!');
      writeln('Unable to Find Start Point! Input X(1 ~ ', _Height, ') and Y(1 ~ ', _Width, '):');
      repeat
        readln(x, y);
        if (IOResult = 0) and (x > 0) and (y > 0) and (x <= _Height) and (y <= _Width) and (_Maze[x, y] = C_Space) then break;
        writeln('Invalid Input! Input Again:');
      until false;
    end;
    logWrite('Found Start Point at ' + IntToStr(x) + ',' + IntToStr(y) + '.');
  end;

  with _Exit do
  begin
    _Exit := findSpace(1, _Height, _Width, _Width);
    if (x <= 0) or (_Exit = _Start) then
      _Exit := findSpace(_Height, _Height, 1, _Width);
    if (x <= 0) or (_Exit = _Start) then
      _Exit := findSpace(1, _Height, 1, 1);
    if (x <= 0) or (_Exit = _Start) then
      _Exit := findSpace(1, 1, 1, _Width);
    if (x <= 0) or (_Exit = _Start) then
    begin
      logWrite('Unable to Find Exit Point!');
      writeln('Unable to Find Exit Point! Input X(1 ~ ', _Height, ') and Y(1 ~ ', _Width, '):');
      repeat
        readln(x, y);
        if (IOResult = 0) and (x > 0) and (y > 0) and (x <= _Height) and (y <= _Width) and (_Maze[x, y] = C_Space) then break;
        writeln('Invalid Input! Input Again:');
      until false;
    end;
    logWrite('Found Exit Point at ' + IntToStr(x) + ',' + IntToStr(y) + '.');
  end;
  logWrite('Init Done.');
  writeln('Init Done.');
End;

//-------------------------------------------

PROCEDURE Solve;
//Var

Begin
  while _SolveResult <> 0 do;
  logWrite('Solving Process Started.');
  setlength(_Stack, 1000);
  logWrite('Set Stack Size at 1000.');
  _StackTop := 1;
  _Stack[_StackTop] := _Start;

  while _StackTop > 0 do
  begin
    _Now := _Stack(_StackTop);
    
    inc(_StackTop);
    _Stack[_StackTop] := _Now;
    if _StackTop + 100 > length(_Stack) then
      setlength(_Stack, _StackTop + 1000);

  end;

End;

//-------------------------------------------

PROCEDURE SaveSolution;
//Var

Begin
  assign(_SolveFile, 'Solve_' + ParamStr(1) + '.slv');
  rewrite(_SolveFile);
End.

//-------------------------------------------

PROCEDURE RunMaze;
Var
  flag: boolean;
  pid: longword;
  gd,gm: integer;
Begin
  logWrite('Start Solving Maze...');
  writeln('Start Solving Maze...');
  writeln('Start at (', _Start.x, ', ', _Start.y, ').');
  _Now := _Start;

  logWrite('Creating Process...');
  writeln('Creating Process...');
  _SolveResult := -1;
  CreateThread(nil, 0, @Solve, nil, 0, pid);
  if pid = 0 then
  begin
    writeln('Error Creating Thread!');
    logWrite('Error Creating Thread!');
    stopAll;
  end;
  _SolveResult := 0;
  while _SolveResult = 0 do
  begin
    Sleep(100);

  end;
  SaveSolution;
  writeln('Maze Solved!');
  writeln('Solution File Saved As "', 'Solve_' + ParamStr(1) + '.slv', '".');
  writeln('Solution Picture Saved As "', 'Solve_' + ParamStr(1) + '.bmp', '".');
  writeln('Press Enter to Exit.');
  readln;
End;

//-------------------------------------------
// Main

BEGIN
  Init;
  RunMaze;
END.
