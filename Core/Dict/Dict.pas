unit Dict;

interface

uses Windows, Classes, SysUtils, IOProcs, DictInterface;

type
  TDict = class(TInterfacedObject, IDict)
  private
    FIndex: String;
    FDict: String;
    FWords: TStrings;
    FName: String;
    FPath: String;
    FiLines: TStrings;
    Fii: Integer;
    Filinecount: Integer;
    FInitialized: Boolean;
  public
    constructor Create;
    destructor Destroy(); override;
    function Initialize(IndexFile, DictFile: String; background: boolean = false): boolean;
    function Lookup(aWord: String): String; // lookup a word in dictionary...

    property Initialized: boolean read FInitialized;
    property Words: TStrings read FWords;
    property Name: String read FName;
    property Path: String read FPath;
    property Dict: String read FDict;

    function GetWordCount(): Cardinal;
    function GetWord(aIndex: Cardinal): String;
    function GetName(): String;
    function GetDictPath(): String;

  end;

implementation

uses BibleQuoteUtils;

constructor TDict.Create;
begin
  inherited Create;

  FName := '';
  FIndex := '';
  FDict := '';

  FWords := TStringList.Create;
end;

destructor TDict.Destroy;
begin
  FWords.Free();
  inherited;
end;

function TDict.GetDictPath: String;
begin
  Result:= FDict;
end;

function TDict.GetName: String;
begin
  Result := FName;
end;

function TDict.GetWord(aIndex: Cardinal): String;
begin
  Result := FWords[aIndex];
end;

function TDict.GetWordCount(): Cardinal;
begin
  Result := FWords.Count;
end;

function TDict.Initialize(IndexFile, DictFile: String; background: boolean = false): boolean;
begin
  if IndexFile = FIndex then
  begin
    Result := true;
    exit
  end;

  result := false;
  // if not assigned(FiLines) then begin
  if (FileExistsEx(IndexFile) < 0) or (FileExistsEx(DictFile) < 0) then
  begin
    exit;
  end;

  FIndex := IndexFile;
  FDict := DictFile;
  FPath := ExtractFileName(IndexFile);
  FPath := Copy(FPath, 1, Length(FPath) - 3);

  FiLines := ReadTextFileLines(FIndex, TEncoding.GetEncoding(1251));

  FName := FiLines[0];
  FiLines.Delete(0);
  FWords.Clear;
  Filinecount := (FiLines.Count div 2) - 1;
  FWords.Capacity := Filinecount;
  Fii := 0;
  if background then
    exit;

  if (not background) or (Fii <= Filinecount) then
    repeat
      FWords.InsertObject(Fii, Trim(FiLines[2 * Fii]), Pointer(StrToIntDef(Trim(FiLines[2 * Fii + 1]), 0)));
      Inc(Fii);
    until (Fii > Filinecount) or (background and ((Fii and $3FF) = $3FF));

  result := Fii > Filinecount;
  if not result then
    exit;
  FInitialized := true;
  result := (FWords.Count > 0);
  FreeandNil(FiLines);
  Fii := 0;
end;

function TDict.Lookup(aWord: String): String;
var
  dDictSize: integer;
  dOffset: integer;
  dCount: integer;
  dExcludeWord: string;
  i: integer;

begin
  i := FWords.IndexOf(aWord);

  if i = -1 then
  begin
    Result := '';

  end
  else
  begin
    dDictSize := ReadFileSize(FDict);
    dOffset := Integer(FWords.Objects[i]);

    if i < FWords.Count - 1 then
      dCount := Integer(FWords.Objects[i + 1]) - dOffset
    else
      dCount := dDictSize - dOffset;

    Result := ReadDictFragment(FDict, dOffset, dCount, TEncoding.GetEncoding(1251));

  end;

  dExcludeWord := LowerCase('<h4>' + aWord + '</h4>');
  if LowerCase(Copy(Result, 1, Length(dExcludeWord))) = dExcludeWord then
    Result := Copy(Result, Length(dExcludeWord) + 1, Length(Result));

end;

end.
