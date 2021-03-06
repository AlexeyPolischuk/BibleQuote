unit GoCommand;

interface

uses
  Winapi.Windows, Winapi.Messages, CommandInterface, CommandBase, MainFrm,
  BookFra, TabData, LinksParserIntf, BibleQuoteUtils, SysUtils, AppIni,
  ExceptionFrm, Bible, DockTabsFrm, ScriptureProvider;

type
  TGoCommand = class(TCommandBase)
  private
  protected

  public
    constructor Create(MainView: TMainForm; Workspace: IWorkspace; BookView: TBookFrame; BookTabInfo: TBookTabInfo; Command: String);
    destructor Destroy(); override;

    function Execute(hlVerses: TbqHLVerseOption): Boolean; override;
  end;

implementation

constructor TGoCommand.Create(MainView: TMainForm; Workspace: IWorkspace; BookView: TBookFrame; BookTabInfo: TBookTabInfo; Command: String);
begin
  inherited Create(MainView, Workspace, BookView, BookTabInfo, Command);
end;

destructor TGoCommand.Destroy;
begin
  inherited;
end;

function TGoCommand.Execute(hlVerses: TbqHLVerseOption): Boolean;
var
  BibleLink: TBibleLinkEx;
  Value, ConcreteCmd, Path: String;
  Status: Integer;
  navRslt: TNavigateResult;
  dup, S: String;
  ScripProvider: TScriptureProvider;
begin
  dup := FCommand;

  bibleLink.FromBqStringLocation(dup);
  if BibleLink.IsAutoBible() then
  begin
    if FBookTabInfo.Bible.isBible then
      Value := FBookTabInfo.Bible.ShortPath
    else if FBookTabInfo.SecondBible.isBible then
      Value := FBookTabInfo.SecondBible.ShortPath
    else
      Value := '';

    ScripProvider := TScriptureProvider.Create(FMainView);
    try
      Status := ScripProvider.PreProcessAutoCommand(dup, Value, ConcreteCmd);
    finally
      ScripProvider.Free;
    end;

    if Status <= -2 then
    begin
      Result := False;
      Exit; // fail
    end;

    BibleLink.FromBqStringLocation(ConcreteCmd);
  end;

  Path := ResolveFullPath(bibleLink.GetIniFileShortPath());

  if Length(path) < 1 then
  begin
    Result := True;
    Exit;
  end;

  // try to load module
  if Path <> ResolveFullPath(FBookTabInfo.Bible.Info.FileName) then
    try
      FBookTabInfo.Bible.SetInfoSource(Path);
    except // revert to old location if something goes wrong
      RevertLocation(BibleLink);
    end;

  try
    // read and display
    navRslt := FBookView.GoAddress(FBookTabInfo, bibleLink.book, bibleLink.chapter, bibleLink.vstart, bibleLink.vend, hlVerses);

    with FBookTabInfo.Bible do
      if (bibleLink.vstart = 0) or (navRslt > nrEndVerseErr) then
        // if the final verse is not specified
        // looks like
        // "go module_folder book_no Chapter_no verse_start_no 0 mod_shortname

        FCommand := Format('go %s %d %d %d 0 $$$%s %s',
          [ShortPath, CurBook, CurChapter, 0,
          // history comment
          FullPassageSignature(CurBook, CurChapter, bibleLink.vstart, 0), Info.BibleShortName])
      else
        FCommand := Format('go %s %d %d %d %d $$$%s %s',
          [ShortPath, CurBook, CurChapter, bibleLink.vstart, bibleLink.vend,
          // history comment
          FullPassageSignature(CurBook, CurChapter, bibleLink.vstart, bibleLink.vend), Info.BibleShortName]);

    FBookView.HistoryAdd(FCommand);

    // here we set proper name to tab
    with FBookTabInfo.Bible, FWorkspace.ChromeTabs do
    begin
      if ActiveTabIndex >= 0 then
        try
          // save the context
          FBookTabInfo.Location := FCommand;
          FBookTabInfo.LocationType := vtlModule;

          FBookTabInfo.IsCompareTranslation := false;
          FBookTabInfo.CompareTranslationText := '';

          if navRslt <= nrEndVerseErr then
            FBookTabInfo[vtisHighLightVerses] := hlVerses = hlTrue
          else
            FBookTabInfo[vtisHighLightVerses] := false;

          if (CurBook >= 0) then
          begin
            S := GetShortNames(CurBook);
            if (S.IsEmpty) then
              S := Lang.SayDefault(Format('StrMyBibleBook%d', [CurBook]), '');

            FBookTabInfo.Title := Format(
              '%.6s-%.6s:%d', [Info.BibleShortName, S, CurChapter - ord(Trait[bqmtZeroChapter])])
          end
          else
            FBookTabInfo.Title := Format('%.6s', [Info.BibleShortName])

        except
          on E: Exception do
            BqShowException(E);
        end;
    end;

    if (bibleLink.book >= 0) then
    begin
      with FBookTabInfo.Bible do
      begin
        ReferenceToInternal(bibleLink, FMainView.LastLink);
        if (FBookTabInfo.Bible.isBible) then
        begin
          FMainView.LastBiblePath := FBookTabInfo.Bible.ShortPath;
          ReferenceToInternal(bibleLink, FMainView.LastBibleLink);
        end;
        FMainView.LastIsBible := FBookTabInfo.Bible.isBible;
      end;
    end;

    AppConfig.LastCommand := FCommand;
    if (FBookTabInfo.Bible.isBible) then
      AppConfig.LastBibleCommand := FCommand;

  except
    on E: TBQException do
    begin
      MessageBox(FBookView.Handle, PChar(Pointer(E.mMessage)), nil, MB_ICONERROR or MB_OK);
      RevertLocation(BibleLink);
    end
    else
      RevertLocation(BibleLink); // in any case
  end;

  Result := True;
end;

end.
