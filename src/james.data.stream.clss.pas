{
  MIT License

  Copyright (c) 2017 Marcos Douglas B. Santos

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
}
unit James.Data.Stream.Clss;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, md5,
  synacode,
  James.Data,
  James.Data.Clss;

type
  TStreamBase64 = class sealed(TInterfacedObject, IDataStream)
  private
    FOrigin: IDataStream;
    function Base64Stream: IDataStream;
  public
    constructor Create(Origin: IDataStream); reintroduce;
    class function New(Origin: IDataStream): IDataStream;
    function Save(Stream: TStream): IDataStream; overload;
    function Save(const FileName: string): IDataStream; overload;
    function Save(Strings: TStrings): IDataStream; overload;
    function AsString: string;
    function Size: Int64;
  end;

  TStreamDivided = class sealed(TInterfacedObject, IDataStream)
  private
    FOrigin: IDataStream;
    FFromPos: Integer;
    FTotalPos: Integer;
    function GetStream: IDataStream;
  public
    constructor Create(Origin: IDataStream; FromPos, TotalPos: Integer); reintroduce;
    class function New(Origin: IDataStream; FromPos, TotalPos: Integer): IDataStream;
    function Save(Stream: TStream): IDataStream; overload;
    function Save(const FileName: string): IDataStream; overload;
    function Save(Strings: TStrings): IDataStream; overload;
    function AsString: string;
    function Size: Int64;
  end;

  TStreamPartialFromText = class sealed(TInterfacedObject, IDataStream)
  private
    FOrigin: IDataStream;
    FFromText: string;
    function GetStream: IDataStream;
  public
    constructor Create(Origin: IDataStream; const FromText: string); reintroduce;
    class function New(Origin: IDataStream; const FromText: string): IDataStream;
    function Save(Stream: TStream): IDataStream; overload;
    function Save(const FileName: string): IDataStream; overload;
    function Save(Strings: TStrings): IDataStream; overload;
    function AsString: string;
    function Size: Int64;
  end;

  TStreamMD5 = class sealed(TInterfacedObject, IDataStream)
  private
    FOrigin: IDataStream;
    function GetStream: IDataStream;
  public
    constructor Create(Origin: IDataStream); reintroduce;
    class function New(Origin: IDataStream): IDataStream;
    function Save(Stream: TStream): IDataStream; overload;
    function Save(const FileName: string): IDataStream; overload;
    function Save(Strings: TStrings): IDataStream; overload;
    function AsString: string;
    function Size: Int64;
  end;

implementation

{ TStreamBase64 }

function TStreamBase64.Base64Stream: IDataStream;
var
  Buf1, Buf2: TStringStream;
begin
  Buf2 := nil;
  Buf1 := TStringStream.Create('');
  try
    FOrigin.Save(Buf1);
    Buf1.Position := soFromBeginning;
    Buf2 := TStringStream.Create(EncodeBase64(Buf1.DataString));
    Result := TDataStream.New(Buf2);
  finally
    Buf1.Free;
    Buf2.Free;
  end;
end;

constructor TStreamBase64.Create(Origin: IDataStream);
begin
  inherited Create;
  FOrigin := Origin;
end;

class function TStreamBase64.New(Origin: IDataStream): IDataStream;
begin
  Result := Create(Origin);
end;

function TStreamBase64.Save(Stream: TStream): IDataStream;
begin
  Result := Base64Stream.Save(Stream);
end;

function TStreamBase64.Save(const FileName: string): IDataStream;
begin
  Result := Base64Stream.Save(FileName);
end;

function TStreamBase64.Save(Strings: TStrings): IDataStream;
begin
  Result := Base64Stream.Save(Strings);
end;

function TStreamBase64.AsString: string;
begin
  Result := Trim(Base64Stream.AsString);
end;

function TStreamBase64.Size: Int64;
begin
  Result := Base64Stream.Size;
end;

{ TStreamDivided }

function TStreamDivided.GetStream: IDataStream;
var
  M: TMemoryStream;
  B: TBytes;
  ParcelaBytes: Int64;
  Offset: Int64 = 0;
begin
  M := TMemoryStream.Create;
  try
    FOrigin.Save(M);
    ParcelaBytes := M.Size div FTotalPos;
    Offset := ParcelaBytes * (Int64(FFromPos)-1);
    M.Seek(Offset, soFromBeginning);
    if (FFromPos = 1) and (FTotalPos = 1) then
      SetLength(B, M.Size)
    else if FFromPos < FTotalPos then
      SetLength(B, ParcelaBytes)
    else if FFromPos = FTotalPos then
      SetLength(B, M.Size - Offset);
    M.ReadBuffer(Pointer(B)^, Length(B));
    M.Clear;
    M.WriteBuffer(Pointer(B)^, Length(B));
    Result := TDataStream.New(M);
  finally
    M.Free;
  end;
end;

constructor TStreamDivided.Create(Origin: IDataStream;
  FromPos, TotalPos: Integer);
begin
  inherited Create;
  FOrigin := Origin;
  FFromPos := FromPos;
  FTotalPos := TotalPos;
end;

class function TStreamDivided.New(Origin: IDataStream;
  FromPos, TotalPos: Integer): IDataStream;
begin
  Result := Create(Origin, FromPos, TotalPos);
end;

function TStreamDivided.Save(Stream: TStream): IDataStream;
begin
  Result := GetStream.Save(Stream);
end;

function TStreamDivided.Save(const FileName: string): IDataStream;
begin
  Result := GetStream.Save(FileName);
end;

function TStreamDivided.Save(Strings: TStrings): IDataStream;
begin
  Result := GetStream.Save(Strings);
end;

function TStreamDivided.AsString: string;
begin
  Result := GetStream.AsString;
end;

function TStreamDivided.Size: Int64;
begin
  Result := GetStream.Size;
end;

{ TStreamPartialFromText }

function TStreamPartialFromText.GetStream: IDataStream;
var
  M: TMemoryStream;
  S: AnsiString;
  P: SizeInt;
begin
  S := '';
  M := TMemoryStream.Create;
  try
    FOrigin.Save(M);
    SetLength(S, M.Size);
    M.ReadBuffer(S[1], M.Size);
    P := Pos(FFromText, S);
    if P = -1 then
      Exit;
    S := Trim(Copy(S, P, Length(S)));
  finally
    Result := TDataStream.New(S);
    M.Free;
  end;
end;

constructor TStreamPartialFromText.Create(Origin: IDataStream;
  const FromText: string);
begin
  inherited Create;
  FOrigin := Origin;
  FFromText := FromText;
end;

class function TStreamPartialFromText.New(Origin: IDataStream;
  const FromText: string): IDataStream;
begin
  Result := Create(Origin, FromText);
end;

function TStreamPartialFromText.Save(Stream: TStream): IDataStream;
begin
  Result := GetStream.Save(Stream);
end;

function TStreamPartialFromText.Save(const FileName: string): IDataStream;
begin
  Result := GetStream.Save(FileName);
end;

function TStreamPartialFromText.Save(Strings: TStrings): IDataStream;
begin
  Result := GetStream.Save(Strings);
end;

function TStreamPartialFromText.AsString: string;
begin
  Result := GetStream.AsString;
end;

function TStreamPartialFromText.Size: Int64;
begin
  Result := GetStream.Size;
end;

{ TStreamMD5 }

function TStreamMD5.GetStream: IDataStream;
begin
  Result := TDataStream.New(
    MD5Print(
      MD5String(
        FOrigin.AsString
      )
    )
  );
end;

constructor TStreamMD5.Create(Origin: IDataStream);
begin
  inherited Create;
  FOrigin := Origin;
end;

class function TStreamMD5.New(Origin: IDataStream): IDataStream;
begin
  Result := Create(Origin);
end;

function TStreamMD5.Save(Stream: TStream): IDataStream;
begin
  Result := GetStream.Save(Stream);
end;

function TStreamMD5.Save(const FileName: string): IDataStream;
begin
  Result := GetStream.Save(FileName);
end;

function TStreamMD5.Save(Strings: TStrings): IDataStream;
begin
  Result := GetStream.Save(Strings);
end;

function TStreamMD5.AsString: string;
begin
  Result := GetStream.AsString;
end;

function TStreamMD5.Size: Int64;
begin
  Result := GetStream.Size;
end;

end.
