(*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) Alexey Torgashin
*)
unit proc_editor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, StrUtils,
  Controls,
  Dialogs, Forms,
  Clipbrd,
  ATSynEdit,
  ATSynEdit_CanvasProc,
  ATSynEdit_Carets,
  ATSynEdit_Markers,
  ATSynEdit_Ranges,
  ATSynEdit_Commands,
  ATSynEdit_CharSizer,
  ATSynEdit_Edits,
  ATSynEdit_Gutter_Decor,
  ATSynEdit_Adapter_EControl,
  ATSynEdit_Finder,
  ATStrings,
  ATStringProc,
  proc_globdata,
  proc_colors,
  proc_msg,
  ec_SyntAnal,
  ec_syntax_format,
  math;

type
  TATEditorTempOps = record
    FontSize: integer;
    WrapMode: TATSynWrapMode;
    ShowMinimap: boolean;
    ShowMicromap: boolean;
    ShowRuler: boolean;
    ShowNumbers: boolean;
    ShowUnprinted: boolean;
  end;

procedure EditorSaveTempOptions(Ed: TATSynEdit; var Ops: TATEditorTempOps);
procedure EditorRestoreTempOptions(Ed: TATSynEdit; const Ops: TATEditorTempOps);
procedure EditorFocus(C: TWinControl);
procedure EditorMouseClick_AtCursor(Ed: TATSynEdit; AAndSelect: boolean);
procedure EditorMouseClick_NearCaret(Ed: TATSynEdit; const AParams: string; AAndSelect: boolean);

procedure EditorClear(Ed: TATSynEdit);
function EditorGetCurrentChar(Ed: TATSynEdit): Widechar;
procedure EditorApplyOps(Ed: TATSynEdit; const Op: TEditorOps;
  AApplyUnprintedAndWrap, AApplyTabSize, AApplyCentering: boolean);

function EditorGetFoldString(Ed: TATSynEdit): string;
procedure EditorSetFoldString(Ed: TATSynEdit; const AText: string);

function EditorGetLinkAtScreenCoord(Ed: TATSynEdit; P: TPoint): atString;
function EditorGetLinkAtCaret(Ed: TATSynEdit): atString;

type
  TEdSelType = (selNo, selSmall, selStream, selCol, selCarets);

function EditorGetStatusType(ed: TATSynEdit): TEdSelType;
function EditorFormatStatus(ed: TATSynEdit; const str: string): string;
procedure EditorDeleteNewColorAttribs(ed: TATSynEdit);
procedure EditorGotoLastEditingPos(Ed: TATSynEdit; AIndentHorz, AIndentVert: integer);
function EditorGotoFromString(Ed: TATSynEdit; SInput: string): boolean;

procedure EditorApplyTheme(Ed: TATSynedit);
procedure EditorSetColorById(Ed: TATSynEdit; const Id: string; AColor: TColor);
function EditorGetColorById(Ed: TATSynEdit; const Id: string): TColor;

function EditorIsAutocompleteCssPosition(Ed: TATSynEdit; AX, AY: integer): boolean;
function EditorAutoCloseBracket(Ed: TATSynEdit; CharBegin: atChar): boolean;
procedure EditorCopySelToPrimarySelection(Ed: TATSynEdit; AMaxLineCount: integer);

procedure EditorCaretPropsFromString(Props: TATCaretProps; const AText: string);
procedure EditorCaretPropsFromPyTuple(Props: TATCaretProps; const AText: string);

type
  TATEditorBracketKind = (
    bracketUnknown,
    bracketOpening,
    bracketClosing
    );

  TATEditorBracketAction = (
    bracketActionHilite,
    bracketActionJump,
    bracketActionSelect,
    bracketActionSelectInside
    );

const
  cEditorTagForBracket = 1;

type
  TATEditorGetTokenKind = function(Ed: TATSynEdit; AX, AY: integer): TATFinderTokenKind of object;

function EditorBracket_GetPairForClosingBracketOrQuote(ch: char): char;
procedure EditorBracket_ClearHilite(Ed: TATSynEdit);
procedure EditorBracket_FindBoth(Ed: TATSynEdit;
  var PosX, PosY: integer;
  const AllowedSymbols: string;
  MaxDistance: integer;
  out FoundX, FoundY: integer;
  out CharFrom, CharTo: atChar;
  out Kind: TATEditorBracketKind);
procedure EditorBracket_Action(Ed: TATSynEdit;
  Action: TATEditorBracketAction;
  const AllowedSymbols: string;
  MaxDistance: integer);
procedure EditorBracket_FindOpeningBracketBackward(Ed: TATSynEdit;
  PosX, PosY: integer;
  const AllowedSymbols: string;
  MaxDistance: integer;
  out FoundX, FoundY: integer);

function EditorGetTokenKind(Ed: TATSynEdit; AX, AY: integer): TATFinderTokenKind;


implementation

procedure EditorApplyOps(Ed: TATSynEdit; const Op: TEditorOps;
  AApplyUnprintedAndWrap, AApplyTabSize, AApplyCentering: boolean);
var
  Sep: TATStringSeparator;
  N: integer;
begin
  Ed.Font.Name:= Op.OpFontName;
  Ed.FontItalic.Name:= Op.OpFontName_i;
  Ed.FontBold.Name:= Op.OpFontName_b;
  Ed.FontBoldItalic.Name:= Op.OpFontName_bi;

  Ed.Font.Size:= Op.OpFontSize;
  Ed.FontItalic.Size:= Op.OpFontSize_i;
  Ed.FontBold.Size:= Op.OpFontSize_b;
  Ed.FontBoldItalic.Size:= Op.OpFontSize_bi;

  Ed.Font.Quality:= Op.OpFontQuality;
  Ed.OptShowFontLigatures:= Op.OpFontLigatures;

  Ed.OptCharSpacingY:= Op.OpSpacingY;

  if AApplyTabSize then
  begin
    Ed.OptTabSize:= Op.OpTabSize;
    Ed.OptTabSpaces:= Op.OpTabSpaces;
  end;

  Ed.OptOverwriteSel:= Op.OpOverwriteSel;
  Ed.OptOverwriteAllowedOnPaste:= Op.OpOverwriteOnPaste;

  Ed.OptGutterVisible:= Op.OpGutterShow;
  Ed.OptGutterShowFoldAlways:= Op.OpGutterFoldAlways;
  Ed.OptGutterIcons:= TATGutterIconsKind(Op.OpGutterFoldIcons);
  Ed.Gutter[Ed.GutterBandBookmarks].Visible:= Op.OpGutterBookmarks;
  Ed.Gutter[Ed.GutterBandFolding].Visible:= Op.OpGutterFold;
  Ed.Gutter[Ed.GutterBandNumbers].Visible:= Op.OpNumbersShow;
  Ed.Gutter.Update;

  if Op.OpNumbersStyle<=Ord(High(TATSynNumbersStyle)) then
    Ed.OptNumbersStyle:= TATSynNumbersStyle(Op.OpNumbersStyle);
  Ed.OptNumbersShowCarets:= Op.OpNumbersForCarets;
  if Op.OpNumbersCenter then
    Ed.OptNumbersAlignment:= taCenter
  else
    Ed.OptNumbersAlignment:= taRightJustify;

  Ed.OptRulerVisible:= Op.OpRulerShow;
  Ed.OptRulerNumeration:= TATRulerNumeration(Op.OpRulerNumeration);
  Ed.OptRulerMarkSizeCaret:= Op.OpRulerMarkCaret;

  Ed.OptMinimapVisible:= Op.OpMinimapShow;
  Ed.OptMinimapShowSelAlways:= Op.OpMinimapShowSelAlways;
  Ed.OptMinimapShowSelBorder:= Op.OpMinimapShowSelBorder;
  Ed.OptMinimapCharWidth:= Op.OpMinimapCharWidth;
  Ed.OptMinimapAtLeft:= Op.OpMinimapAtLeft;
  Ed.OptMinimapTooltipVisible:= Op.OpMinimapTooltipShow;
  Ed.OptMinimapTooltipLinesCount:= Op.OpMinimapTooltipLineCount;
  Ed.OptMinimapTooltipWidthPercents:= Op.OpMinimapTooltipWidth;

  Ed.OptMicromapVisible:= Op.OpMicromapShow;

  Ed.OptMarginRight:= Op.OpMarginFixed;
  Ed.OptMarginString:= Op.OpMarginString;

  Ed.OptShowURLs:= Op.OpLinks;
  Ed.OptShowURLsRegex:= Op.OpLinksRegex;

  if AApplyUnprintedAndWrap then
  begin
    Ed.OptUnprintedVisible:= Op.OpUnprintedShow;
    Ed.OptUnprintedSpaces:=         Pos('s', Op.OpUnprintedContent)>0;
    Ed.OptUnprintedSpacesTrailing:= Pos('t', Op.OpUnprintedContent)>0;
    Ed.OptUnprintedSpacesBothEnds:= Pos('l', Op.OpUnprintedContent)>0;
    Ed.OptUnprintedSpacesOnlyInSelection:= Pos('x', Op.OpUnprintedContent)>0;
    Ed.OptUnprintedEnds:=           Pos('e', Op.OpUnprintedContent)>0;
    Ed.OptUnprintedEndsDetails:=    Pos('d', Op.OpUnprintedContent)>0;
  end;

  //global options
  OptMaxTabPositionToExpand:= Op.OpTabMaxPosExpanded;
  OptHexChars:= OptHexCharsDefault + Op.OpHexChars;

  OptUnprintedEndArrowOrDot:= Pos('.', Op.OpUnprintedContent)=0;
  OptUnprintedTabCharLength:= Op.OpUnprintedTabArrowLen;
  OptUnprintedSpaceDotScale:= Op.OpUnprintedSpaceDotScale;
  OptUnprintedEndDotScale:= Op.OpUnprintedEndDotScale;
  OptUnprintedEndFontScale:= Op.OpUnprintedEndFontScale;
  OptUnprintedTabPointerScale:= Op.OpUnprintedTabPointerScale;
  OptUnprintedReplaceSpec:= Op.OpUnprintedReplaceSpec;
  OptUnprintedReplaceSpecToCode:= StrToInt('$'+Op.OpUnprintedReplaceToCode);

  if AApplyUnprintedAndWrap then
  begin
    if Op.OpWrapMode<=Ord(High(TATSynWrapMode)) then
      Ed.OptWrapMode:= TATSynWrapMode(Op.OpWrapMode);
  end;
  Ed.OptWrapIndented:= Op.OpWrapIndented;
  Ed.OptWrapEnabledForMaxLines:= Op.OpWrapEnabledMaxLines;

  Ed.OptUndoLimit:= Op.OpUndoLimit;
  Ed.OptUndoGrouped:= Op.OpUndoGrouped;
  Ed.OptUndoAfterSave:= Op.OpUndoAfterSave;

  Ed.OptCaretBlinkTime:= Op.OpCaretBlinkTime;
  Ed.OptCaretBlinkEnabled:= Op.OpCaretBlinkEn;

  EditorCaretPropsFromString(Ed.CaretPropsNormal, Op.OpCaretViewNormal);
  EditorCaretPropsFromString(Ed.CaretPropsOverwrite, Op.OpCaretViewOverwrite);
  EditorCaretPropsFromString(Ed.CaretPropsReadonly, Op.OpCaretViewReadonly);

  if Op.OpCaretAfterPasteColumn<=Ord(High(TATPasteCaret)) then
    Ed.OptCaretPosAfterPasteColumn:= TATPasteCaret(Op.OpCaretAfterPasteColumn);

  Ed.OptCaretVirtual:= Op.OpCaretVirtual;
  Ed.OptCaretManyAllowed:= Op.OpCaretMulti;
  Ed.OptCaretsAddedToColumnSelection:= Op.OpCaretsAddedToColumnSel;
  Ed.OptScrollLineCommandsKeepCaretOnScreen:= Op.OpCaretKeepVisibleOnScroll;

  Ed.OptShowCurLine:= Op.OpShowCurLine;
  Ed.OptShowCurLineMinimal:= Op.OpShowCurLineMinimal;
  Ed.OptShowCurLineOnlyFocused:= Op.OpShowCurLineOnlyFocused;
  Ed.OptShowCurColumn:= Op.OpShowCurCol;
  Ed.OptLastLineOnTop:= Op.OpShowLastLineOnTop;
  Ed.OptShowFullWidthForSelection:= Op.OpShowFullBackgroundSel;
  Ed.OptShowFullWidthForSyntaxHilite:= Op.OpShowFullBackgroundSyntax;
  Ed.OptShowMouseSelFrame:= Op.OpShowMouseSelFrame;
  Ed.OptCopyLinesIfNoSel:= Op.OpCopyLineIfNoSel;
  Ed.OptCutLinesIfNoSel:= Op.OpCutLineIfNoSel;
  Ed.OptCopyColumnBlockAlignedBySpaces:= Op.OpCopyColumnAlignedBySpaces;
  Ed.OptSavingTrimSpaces:= Op.OpSavingTrimSpaces;
  Ed.OptSavingTrimFinalEmptyLines:= Op.OpSavingTrimFinalEmptyLines;
  Ed.OptSavingForceFinalEol:= Op.OpSavingForceFinalEol;
  Ed.OptShowScrollHint:= Op.OpShowHintOnVertScroll;
  Ed.OptScrollSmooth:= Op.OpSmoothScroll;
  Ed.OptScrollStyleHorz:= TATSynEditScrollStyle(Op.OpScrollStyleHorz);
  Ed.OptTextCenteringCharWidth:= IfThen(AApplyCentering, Op.OpCenteringWidth, 0);
  Ed.OptNonWordChars:= Op.OpNonWordChars;
  Ed.OptFoldStyle:= TATFoldStyle(Op.OpFoldStyle);
  Ed.OptFoldTooltipVisible:= Op.OpFoldTooltipShow;

  Ed.OptStapleStyle:= TATLineStyle(Op.OpStaplesStyle);

  Sep.Init(Op.OpStaplesProps);
  Sep.GetItemInt(N, 0);
  Ed.OptStapleIndent:= N;
  Sep.GetItemInt(N, 40);
  Ed.OptStapleWidthPercent:= N;
  Sep.GetItemInt(N, 1);
  Ed.OptStapleEdge1:= TATStapleEdge(N);
  Sep.GetItemInt(N, 1);
  Ed.OptStapleEdge2:= TATStapleEdge(N);

  Ed.OptAutoIndent:= Op.OpIndentAuto;
  if Op.OpIndentAutoKind<=Ord(High(TATAutoIndentKind)) then
    Ed.OptAutoIndentKind:= TATAutoIndentKind(Op.OpIndentAutoKind);
  Ed.OptAutoIndentBetterBracketsCurly:= Op.OpIndentAuto; //no separate option
  Ed.OptAutoIndentRegexRule:= Op.OpIndentAutoRule;

  Ed.OptZebraActive:= Op.OpZebra>0;
  if Ed.OptZebraActive then
    Ed.OptZebraAlphaBlend:= Op.OpZebra;

  Ed.OptIndentSize:= Op.OpIndentSize;
  Ed.OptIndentKeepsAlign:= Op.OpUnIndentKeepsAlign;
  Ed.OptIndentMakesWholeLinesSelection:= Op.OpIndentMakesWholeLineSel;

  Ed.OptMouse2ClickDragSelectsWords:= Op.OpMouse2ClickDragSelectsWords;
  Ed.OptMouseDragDrop:= Op.OpMouseDragDrop;
  ATSynEdit.OptMouseDragDropFocusesTargetEditor:= Op.OpMouseDragDropFocusTarget;
  Ed.OptMouseNiceScroll:= Op.OpMouseMiddleClickNiceScroll;
  Ed.OptMouseRightClickMovesCaret:= Op.OpMouseRightClickMovesCaret;
  Ed.OptMouseEnableColumnSelection:= Op.OpMouseEnableColumnSelection;
  Ed.OptMouseHideCursorOnType:= Op.OpMouseHideCursorOnType;
  Ed.OptMouseClickNumberSelectsLine:= Op.OpMouseGutterClickSelectedLine;
  Ed.OptMouseWheelZooms:= Op.OpMouseWheelZoom;
  Ed.OptMouseWheelScrollVertSpeed:= Op.OpMouseWheelSpeedVert;
  Ed.OptMouseWheelScrollHorzSpeed:= Op.OpMouseWheelSpeedHorz;
  Ed.OptMouseClickNumberSelectsLineWithEOL:= Op.OpMouseClickNumberSelectsEol;

  Ed.OptKeyBackspaceUnindent:= Op.OpKeyBackspaceUnindent;
  Ed.OptKeyTabIndents:= Op.OpKeyTabIndents;
  Ed.OptKeyHomeToNonSpace:= Op.OpKeyHomeToNonSpace;
  Ed.OptKeyHomeEndNavigateWrapped:= Op.OpKeyHomeEndNavigateWrapped;
  Ed.OptKeyEndToNonSpace:= Op.OpKeyEndToNonSpace;
  Ed.OptKeyPageKeepsRelativePos:= Op.OpKeyPageKeepsRelativePos;
  if Op.OpKeyPageUpDownSize<=Ord(High(TATPageUpDownSize)) then
    Ed.OptKeyPageUpDownSize:= TATPageUpDownSize(Op.OpKeyPageUpDownSize);
  Ed.OptKeyUpDownKeepColumn:= Op.OpKeyUpDownKeepColumn;
  Ed.OptKeyUpDownNavigateWrapped:= Op.OpKeyUpDownNavigateWrapped;
  Ed.OptKeyLeftRightSwapSel:= Op.OpKeyLeftRightSwapSel;
  Ed.OptKeyLeftRightSwapSelAndSelect:= Op.OpKeyLeftRightSwapSelAndSelect;
end;

function EditorGetSelLines(ed: TATSynEdit): integer;
var
  n1, n2, i: integer;
begin
  result:= 0;

  if not ed.IsSelRectEmpty then
  begin
    result:= ed.SelRect.Bottom-ed.SelRect.Top+1;
    exit
  end;

  for i:= 0 to ed.carets.count-1 do
  begin
    ed.carets[i].GetSelLines(n1, n2);
    if n1<0 then Continue;
    inc(result, n2-n1+1);
  end;
end;

function EditorFormatStatus(ed: TATSynEdit; const str: string): string;
var
  caret: TATCaretItem;
  cols, n, x_b, y_b, x_e, y_e: integer;
  bSel: boolean;
  char_str, temp_str: UnicodeString;
  char_code: integer;
begin
  result:= '';
  if ed.Carets.Count=0 then exit;
  caret:= ed.Carets[0];

  caret.GetRange(x_b, y_b, x_e, y_e, bSel);

  //make {cols} work for column-sel and small-sel
  cols:= 0;
  //column-sel?
  if not ed.IsSelRectEmpty then
    cols:= ed.SelRect.Right-ed.SelRect.Left
  else
  //small-sel?
  if (ed.Carets.Count=1) and (caret.PosY=caret.EndY) then
    cols:= Abs(caret.PosX-caret.EndX);

  result:= str;
  result:= stringreplace(result, '{x}', inttostr(caret.PosX+1), []);
  result:= stringreplace(result, '{y}', inttostr(caret.PosY+1), []);
  result:= stringreplace(result, '{y2}', inttostr(ed.carets[ed.carets.count-1].PosY+1), []);
  result:= stringreplace(result, '{yb}', inttostr(y_b+1), []);
  result:= stringreplace(result, '{ye}', inttostr(y_e+1), []);
  result:= stringreplace(result, '{count}', inttostr(ed.strings.count), []);
  result:= stringreplace(result, '{carets}', inttostr(ed.carets.count), []);
  result:= stringreplace(result, '{cols}', inttostr(cols), []);

  result:= stringreplace(result, '{_ln}', msgStatusbarTextLine, []);
  result:= stringreplace(result, '{_col}', msgStatusbarTextCol, []);
  result:= stringreplace(result, '{_sel}', msgStatusbarTextSel, []);
  result:= stringreplace(result, '{_linesel}', msgStatusbarTextLinesSel, []);
  result:= stringreplace(result, '{_carets}', msgStatusbarTextCarets, []);

  if pos('{sel}', result)>0 then
    result:= stringreplace(result, '{sel}', inttostr(EditorGetSelLines(ed)), []);

  if pos('{xx}', result)>0 then
    if ed.Strings.IsIndexValid(caret.PosY) then
    begin
      //optimized for huge lines
      n:= ed.Strings.CharPosToColumnPos(caret.PosY, caret.PosX, ed.TabHelper)+1;
      result:= stringreplace(result, '{xx}', inttostr(n), []);
    end;

  if pos('{char', result)>0 then
  begin
    char_str:= '';
    char_code:= -1;

    if ed.Strings.IsIndexValid(y_b) then
      if (x_b>=0) and (x_b<ed.Strings.LinesLen[y_b]) then
      begin
        char_str:= ed.Strings.LineSub(y_b, x_b+1, 1);
        if char_str<>'' then
          char_code:= Ord(char_str[1]);
      end;

    result:= stringreplace(result, '{char}', char_str, []);

    if char_code>=0 then
      temp_str:= IntToStr(char_code)
    else
      temp_str:= '';
    result:= stringreplace(result, '{char_dec}', temp_str, []);

    if char_code>=0 then
      temp_str:= IntToHex(char_code, 2)
    else
      temp_str:= '';
    result:= stringreplace(result, '{char_hex}', temp_str, []);

    if char_code>=0 then
      temp_str:= IntToHex(char_code, 4)
    else
      temp_str:= '';
    result:= stringreplace(result, '{char_hex4}', temp_str, []);
  end;
end;

procedure EditorDeleteNewColorAttribs(ed: TATSynEdit);
begin
  ed.Attribs.Clear;
  ed.Update;
end;

function EditorGetStatusType(ed: TATSynEdit): TEdSelType;
var
  NFrom, NTo: integer;
begin
  if not Ed.IsSelRectEmpty then
    result:= selCol
  else
  if Ed.Carets.Count>1 then
    result:= selCarets
  else
  if Ed.Carets.IsSelection then
  begin
    Ed.Carets[0].GetSelLines(NFrom, NTo);
    if NTo>NFrom then
      result:= selStream
    else
      result:= selSmall;
  end
  else
    result:= selNo;
end;


procedure EditorApplyTheme(Ed: TATSynedit);
begin
  Ed.Colors.TextFont:= GetAppColor('EdTextFont');
  Ed.Colors.TextBG:= GetAppColor('EdTextBg');
  Ed.Colors.TextSelFont:= GetAppColor('EdSelFont');
  Ed.Colors.TextSelBG:= GetAppColor('EdSelBg');

  Ed.Colors.TextDisabledFont:= GetAppColor('EdDisableFont');
  Ed.Colors.TextDisabledBG:= GetAppColor('EdDisableBg');
  Ed.Colors.Caret:= GetAppColor('EdCaret');
  Ed.Colors.Markers:= GetAppColor('EdMarkers');
  Ed.Colors.CurrentLineBG:= GetAppColor('EdCurLineBg');
  Ed.Colors.IndentVertLines:= GetAppColor('EdIndentVLine');
  Ed.Colors.UnprintedFont:= GetAppColor('EdUnprintFont');
  Ed.Colors.UnprintedBG:= GetAppColor('EdUnprintBg');
  Ed.Colors.UnprintedHexFont:= GetAppColor('EdUnprintHexFont');
  Ed.Colors.MinimapBorder:= GetAppColor('EdMinimapBorder');
  Ed.Colors.MinimapSelBG:= GetAppColor('EdMinimapSelBg');
  Ed.Colors.MinimapTooltipBG:= GetAppColor('EdMinimapTooltipBg');
  Ed.Colors.MinimapTooltipBorder:= GetAppColor('EdMinimapTooltipBorder');
  Ed.Colors.StateChanged:= GetAppColor('EdStateChanged');
  Ed.Colors.StateAdded:= GetAppColor('EdStateAdded');
  Ed.Colors.StateSaved:= GetAppColor('EdStateSaved');
  Ed.Colors.BlockStaple:= GetAppColor('EdBlockStaple');
  Ed.Colors.BlockStapleForCaret:= GetAppColor('EdBlockStapleActive');
  Ed.Colors.BlockSepLine:= GetAppColor('EdBlockSepLine');
  Ed.Colors.Links:= GetAppColor('EdLinks');
  Ed.Colors.LockedBG:= GetAppColor('EdLockedBg');
  Ed.Colors.ComboboxArrow:= GetAppColor('EdComboArrow');
  Ed.Colors.ComboboxArrowBG:= GetAppColor('EdComboArrowBg');
  Ed.Colors.CollapseLine:= GetAppColor('EdFoldMarkLine');
  Ed.Colors.CollapseMarkFont:= GetAppColor('EdFoldMarkFont');
  Ed.Colors.CollapseMarkBorder:= GetAppColor('EdFoldMarkBorder');
  Ed.Colors.CollapseMarkBG:= GetAppColor('EdFoldMarkBg');

  Ed.Colors.GutterFont:= GetAppColor('EdGutterFont');
  Ed.Colors.GutterBG:= GetAppColor('EdGutterBg');
  Ed.Colors.GutterCaretFont:= GetAppColor('EdGutterCaretFont');
  Ed.Colors.GutterCaretBG:= GetAppColor('EdGutterCaretBg');

  Ed.Colors.BookmarkBG:= GetAppColor('EdBookmarkBg');
  Ed.Colors.RulerFont:= GetAppColor('EdRulerFont');
  Ed.Colors.RulerBG:= GetAppColor('EdRulerBg');

  Ed.Colors.GutterFoldLine:= GetAppColor('EdFoldLine');
  Ed.Colors.GutterFoldBG:= GetAppColor('EdFoldBg');
  Ed.Colors.GutterPlusBorder:= GetAppColor('EdFoldPlusLine');
  Ed.Colors.GutterPlusBG:= GetAppColor('EdFoldPlusBg');

  Ed.Colors.MarginRight:= GetAppColor('EdMarginFixed');
  Ed.Colors.MarginCaret:= GetAppColor('EdMarginCaret');
  Ed.Colors.MarginUser:= GetAppColor('EdMarginUser');

  Ed.Colors.MarkedLinesBG:= GetAppColor('EdMarkedRangeBg');
  Ed.Colors.BorderLine:= GetAppColor('EdBorder');
  Ed.Colors.BorderLineFocused:= GetAppColor('EdBorderFocused');

  Ed.Update;
end;


procedure EditorSetColorById(Ed: TATSynEdit; const Id: string; AColor: TColor);
begin
  if Id='EdTextFont' then Ed.Colors.TextFont:= AColor else
  if Id='EdTextBg' then Ed.Colors.TextBG:= AColor else
  if Id='EdSelFont' then Ed.Colors.TextSelFont:= AColor else
  if Id='EdSelBg' then Ed.Colors.TextSelBG:= AColor else
  if Id='EdDisableFont' then Ed.Colors.TextDisabledFont:= AColor else
  if Id='EdDisableBg' then Ed.Colors.TextDisabledBG:= AColor else
  if Id='EdCaret' then Ed.Colors.Caret:= AColor else
  if Id='EdMarkers' then Ed.Colors.Markers:= AColor else
  if Id='EdCurLineBg' then Ed.Colors.CurrentLineBG:= AColor else
  if Id='EdIndentVLine' then Ed.Colors.IndentVertLines:= AColor else
  if Id='EdUnprintFont' then Ed.Colors.UnprintedFont:= AColor else
  if Id='EdUnprintBg' then Ed.Colors.UnprintedBG:= AColor else
  if Id='EdUnprintHexFont' then Ed.Colors.UnprintedHexFont:= AColor else
  if Id='EdMinimapBorder' then Ed.Colors.MinimapBorder:= AColor else
  if Id='EdMinimapSelBg' then Ed.Colors.MinimapSelBG:= AColor else
  if Id='EdMinimapTooltipBg' then Ed.Colors.MinimapTooltipBG:= AColor else
  if Id='EdMinimapTooltipBorder' then Ed.Colors.MinimapTooltipBorder:= AColor else
  if Id='EdStateChanged' then Ed.Colors.StateChanged:= AColor else
  if Id='EdStateAdded' then Ed.Colors.StateAdded:= AColor else
  if Id='EdStateSaved' then Ed.Colors.StateSaved:= AColor else
  if Id='EdBlockStaple' then Ed.Colors.BlockStaple:= AColor else
  if Id='EdBlockStapleActive' then Ed.Colors.BlockStapleForCaret:= AColor else
  if Id='EdBlockSepLine' then Ed.Colors.BlockSepLine:= AColor else
  if Id='EdLinks' then Ed.Colors.Links:= AColor else
  if Id='EdLockedBg' then Ed.Colors.LockedBG:= AColor else
  if Id='EdComboArrow' then Ed.Colors.ComboboxArrow:= AColor else
  if Id='EdComboArrowBg' then Ed.Colors.ComboboxArrowBG:= AColor else
  if Id='EdFoldMarkLine' then Ed.Colors.CollapseLine:= AColor else
  if Id='EdFoldMarkFont' then Ed.Colors.CollapseMarkFont:= AColor else
  if Id='EdFoldMarkBorder' then Ed.Colors.CollapseMarkBorder:= AColor else
  if Id='EdFoldMarkBg' then Ed.Colors.CollapseMarkBG:= AColor else
  if Id='EdGutterFont' then Ed.Colors.GutterFont:= AColor else
  if Id='EdGutterBg' then Ed.Colors.GutterBG:= AColor else
  if Id='EdGutterCaretFont' then Ed.Colors.GutterCaretFont:= AColor else
  if Id='EdGutterCaretBg' then Ed.Colors.GutterCaretBG:= AColor else
  if Id='EdBookmarkBg' then Ed.Colors.BookmarkBG:= AColor else
  if Id='EdRulerFont' then Ed.Colors.RulerFont:= AColor else
  if Id='EdRulerBg' then Ed.Colors.RulerBG:= AColor else
  if Id='EdFoldLine' then Ed.Colors.GutterFoldLine:= AColor else
  if Id='EdFoldBg' then Ed.Colors.GutterFoldBG:= AColor else
  if Id='EdFoldPlusLine' then Ed.Colors.GutterPlusBorder:= AColor else
  if Id='EdFoldPlusBg' then Ed.Colors.GutterPlusBG:= AColor else
  if Id='EdMarginFixed' then Ed.Colors.MarginRight:= AColor else
  if Id='EdMarginCaret' then Ed.Colors.MarginCaret:= AColor else
  if Id='EdMarginUser' then Ed.Colors.MarginUser:= AColor else
  if Id='EdMarkedRangeBg' then Ed.Colors.MarkedLinesBG:= AColor else
  if Id='EdBorder' then Ed.Colors.BorderLine:= AColor else
  if Id='EdBorderFocused' then Ed.Colors.BorderLineFocused:= AColor else
  ;
end;


function EditorGetColorById(Ed: TATSynEdit; const Id: string): TColor;
begin
  Result:= -1;
  if Id='EdTextFont' then exit(Ed.Colors.TextFont);
  if Id='EdTextBg' then exit(Ed.Colors.TextBG);
  if Id='EdSelFont' then exit(Ed.Colors.TextSelFont);
  if Id='EdSelBg' then exit(Ed.Colors.TextSelBG);
  if Id='EdDisableFont' then exit(Ed.Colors.TextDisabledFont);
  if Id='EdDisableBg' then exit(Ed.Colors.TextDisabledBG);
  if Id='EdCaret' then exit(Ed.Colors.Caret);
  if Id='EdMarkers' then exit(Ed.Colors.Markers);
  if Id='EdCurLineBg' then exit(Ed.Colors.CurrentLineBG);
  if Id='EdIndentVLine' then exit(Ed.Colors.IndentVertLines);
  if Id='EdUnprintFont' then exit(Ed.Colors.UnprintedFont);
  if Id='EdUnprintBg' then exit(Ed.Colors.UnprintedBG);
  if Id='EdUnprintHexFont' then exit(Ed.Colors.UnprintedHexFont);
  if Id='EdMinimapBorder' then exit(Ed.Colors.MinimapBorder);
  if Id='EdMinimapSelBg' then exit(Ed.Colors.MinimapSelBG);
  if Id='EdMinimapTooltipBg' then exit(Ed.Colors.MinimapTooltipBG);
  if Id='EdMinimapTooltipBorder' then exit(Ed.Colors.MinimapTooltipBorder);
  if Id='EdStateChanged' then exit(Ed.Colors.StateChanged);
  if Id='EdStateAdded' then exit(Ed.Colors.StateAdded);
  if Id='EdStateSaved' then exit(Ed.Colors.StateSaved);
  if Id='EdBlockStaple' then exit(Ed.Colors.BlockStaple);
  if Id='EdBlockStapleActive' then exit(Ed.Colors.BlockStapleForCaret);
  if Id='EdBlockSepLine' then exit(Ed.Colors.BlockSepLine);
  if Id='EdLinks' then exit(Ed.Colors.Links);
  if Id='EdLockedBg' then exit(Ed.Colors.LockedBG);
  if Id='EdComboArrow' then exit(Ed.Colors.ComboboxArrow);
  if Id='EdComboArrowBg' then exit(Ed.Colors.ComboboxArrowBG);
  if Id='EdFoldMarkLine' then exit(Ed.Colors.CollapseLine);
  if Id='EdFoldMarkFont' then exit(Ed.Colors.CollapseMarkFont);
  if Id='EdFoldMarkBorder' then exit(Ed.Colors.CollapseMarkBorder);
  if Id='EdFoldMarkBg' then exit(Ed.Colors.CollapseMarkBG);
  if Id='EdGutterFont' then exit(Ed.Colors.GutterFont);
  if Id='EdGutterBg' then exit(Ed.Colors.GutterBG);
  if Id='EdGutterCaretFont' then exit(Ed.Colors.GutterCaretFont);
  if Id='EdGutterCaretBg' then exit(Ed.Colors.GutterCaretBG);
  if Id='EdBookmarkBg' then exit(Ed.Colors.BookmarkBG);
  if Id='EdRulerFont' then exit(Ed.Colors.RulerFont);
  if Id='EdRulerBg' then exit(Ed.Colors.RulerBG);
  if Id='EdFoldLine' then exit(Ed.Colors.GutterFoldLine);
  if Id='EdFoldBg' then exit(Ed.Colors.GutterFoldBG);
  if Id='EdFoldPlusLine' then exit(Ed.Colors.GutterPlusBorder);
  if Id='EdFoldPlusBg' then exit(Ed.Colors.GutterPlusBG);
  if Id='EdMarginFixed' then exit(Ed.Colors.MarginRight);
  if Id='EdMarginCaret' then exit(Ed.Colors.MarginCaret);
  if Id='EdMarginUser' then exit(Ed.Colors.MarginUser);
  if Id='EdMarkedRangeBg' then exit(Ed.Colors.MarkedLinesBG);
  if Id='EdBorder' then exit(Ed.Colors.BorderLine);
  if Id='EdBorderFocused' then exit(Ed.Colors.BorderLineFocused);
end;

procedure EditorClear(Ed: TATSynEdit);
begin
  Ed.Strings.Clear;
  Ed.Strings.ActionAddFakeLineIfNeeded;
  Ed.DoCaretSingle(0, 0);
  Ed.Update(true);
  Ed.Modified:= false;
end;

function EditorGetCurrentChar(Ed: TATSynEdit): Widechar;
var
  Caret: TATCaretItem;
  Str: atString;
begin
  Result:= #0;
  if Ed.Carets.Count<>1 then exit;
  Caret:= Ed.Carets[0];
  if not Ed.Strings.IsIndexValid(Caret.PosY) then exit;
  if (Caret.PosX<0) then exit;
  Str:= Ed.Strings.LineSub(Caret.PosY, Caret.PosX+1, 1);
  if Str<>'' then
    Result:= Str[1];
end;


function EditorGetFoldString(Ed: TATSynEdit): string;
var
  i: integer;
  R: TATSynRange;
begin
  Result:= '';
  for i:= 0 to Ed.Fold.Count-1 do
  begin
    R:= Ed.Fold[i];
    if R.Folded then
      Result:= Result+(IntToStr(R.Y)+',');
  end;
end;

procedure EditorSetFoldString(Ed: TATSynEdit; const AText: string);
var
  Sep: TATStringSeparator;
  ScrollInfo: TATSynScrollInfo;
  n: integer;
begin
  Ed.DoCommand(cCommand_UnfoldAll);

  Sep.Init(AText);
  repeat
    if not Sep.GetItemInt(n, -1) then Break;

    if not Ed.Strings.IsIndexValid(n) then Continue;

    n:= Ed.Fold.FindRangeWithPlusAtLine(n);
    if n<0 then Continue;

    Ed.DoRangeFold(n);
  until false;

  //fix changed horz scroll, https://github.com/Alexey-T/CudaText/issues/1439
  ScrollInfo:= Ed.ScrollHorz;
  ScrollInfo.NPos:= 0;
  Ed.ScrollHorz:= ScrollInfo;

  Ed.Update;
end;


procedure EditorMouseClick_AtCursor(Ed: TATSynEdit; AAndSelect: boolean);
var
  Pnt: TPoint;
  Details: TATPosDetails;
  Caret: TATCaretItem;
begin
  if Ed.Carets.Count=0 then exit;
  Caret:= Ed.Carets[0];

  Pnt:= Mouse.CursorPos;
  Pnt:= Ed.ScreenToClient(Pnt);
  Pnt:= Ed.ClientPosToCaretPos(Pnt, Details);

  Ed.DoCaretSingle(
    Pnt.X,
    Pnt.Y,
    IfThen(AAndSelect, Caret.PosX, -1),
    IfThen(AAndSelect, Caret.PosY, -1)
    );
  Ed.Update;
end;

procedure EditorMouseClick_NearCaret(Ed: TATSynEdit; const AParams: string; AAndSelect: boolean);
var
  X, Y: integer;
  Caret: TATCaretItem;
  Sep: TATStringSeparator;
begin
  Sep.Init(AParams);
  Sep.GetItemInt(X, MaxInt);
  Sep.GetItemInt(Y, MaxInt);
  if X=MaxInt then exit;
  if Y=MaxInt then exit;

  if Ed.Carets.Count=0 then exit;
  Caret:= Ed.Carets[0];

  if Y=0 then
    Ed.DoCaretSingle(
      Caret.PosX+X,
      Caret.PosY,
      IfThen(AAndSelect, Caret.PosX, -1),
      IfThen(AAndSelect, Caret.PosY, -1)
      )
  else
    Ed.DoCaretSingle(
      X,
      Caret.PosY+Y,
      IfThen(AAndSelect, Caret.PosX, -1),
      IfThen(AAndSelect, Caret.PosY, -1)
      );

  Ed.Update;
end;


function EditorGetLinkAtScreenCoord(Ed: TATSynEdit; P: TPoint): atString;
var
  Details: TATPosDetails;
begin
  Result:= '';
  P:= Ed.ScreenToClient(P);
  P:= Ed.ClientPosToCaretPos(P, Details);
  Result:= Ed.DoGetLinkAtPos(P.X, P.Y);
  if SBeginsWith(Result, 'www') then
    Result:= 'http://'+Result;
end;

function EditorGetLinkAtCaret(Ed: TATSynEdit): atString;
begin
  Result:= '';
  if Ed.Carets.Count=0 then exit;
  Result:= Ed.DoGetLinkAtPos(Ed.Carets[0].PosX, Ed.Carets[0].PosY);
end;

function EditorIsAutocompleteCssPosition(Ed: TATSynEdit; AX, AY: integer): boolean;
//function finds 1st nonspace char before AX:AY and if it's ";" or "{" then it's OK position
  //
  function IsSepChar(ch: Widechar): boolean;
  begin
    Result:= (ch=';') or (ch='{');
  end;
  function IsSpaceChar(ch: Widechar): boolean;
  begin
    Result:= (ch=' ') or (ch=#9);
  end;
  //
var
  str: atString;
  ch: Widechar;
  i: integer;
begin
  Result:= false;
  if not Ed.Strings.IsIndexValid(AY) then exit;

  //find char in line AY before AX
  str:= Ed.Strings.Lines[AY];
  for i:= AX downto 1 do
  begin
    ch:= str[i];
    if IsSpaceChar(ch) then Continue;
    exit(IsSepChar(ch));
  end;

  //find char in line AY-1 from end
  if AY=0 then exit;
  str:= Ed.Strings.Lines[AY-1];
  for i:= Length(str) downto 1 do
  begin
    ch:= str[i];
    if IsSpaceChar(ch) then Continue;
    exit(IsSepChar(ch));
  end;
end;


function Editor_NextCharAllowed_AutoCloseBracket(ch: char): boolean;
begin
  Result:= Pos(ch, ' ])};:.,=>'#9)>0;
end;


function EditorAutoCloseBracket(Ed: TATSynEdit; CharBegin: atChar): boolean;
var
  Caret: TATCaretItem;
  X1, Y1, X2, Y2: integer;
  NPos, NCaret: integer;
  bSel, bBackwardSel: boolean;
  CharEnd: atChar;
  Str: atString;
  Shift, PosAfter: TPoint;
begin
  Result:= false;

  //makes no sense to auto-close brackets in overwrite mode
  if Ed.ModeOverwrite then exit;

  if CharBegin='(' then CharEnd:= ')' else
   if CharBegin='[' then CharEnd:= ']' else
    if CharBegin='{' then CharEnd:= '}' else
     if CharBegin='"' then CharEnd:= '"' else
      if CharBegin='''' then CharEnd:= '''' else
       if CharBegin='`' then CharEnd:= '`' else
        exit;

  //cancel vertical selection
  Ed.DoSelect_ClearColumnBlock;

  Ed.Strings.BeginUndoGroup;
  for NCaret:= Ed.Carets.Count-1 downto 0 do
  begin
    Caret:= Ed.Carets[NCaret];
    if not Ed.Strings.IsIndexValid(Caret.PosY) then Continue;
    Caret.GetRange(X1, Y1, X2, Y2, bSel);
    bBackwardSel:= not Caret.IsForwardSelection;

    if not bSel then
    begin
      NPos:= Caret.PosX;
      Str:= Ed.Strings.Lines[Caret.PosY];
      //don't do, if before caret is \
      if (NPos>=1) and (NPos<=Length(Str)) and (Str[NPos]='\') then Continue;
      //don't do, if caret before text
      if (NPos<Length(Str)) and
        not Editor_NextCharAllowed_AutoCloseBracket(Str[NPos+1]) then Continue;
    end;

    if not bSel then
    begin
      Ed.Strings.TextInsert(X1, Y1, CharBegin+CharEnd, false, Shift, PosAfter);
      Ed.DoCaretsShift(NCaret, X1, Y1, Shift.X, Shift.Y, PosAfter);

      Caret.PosX:= Caret.PosX+1;
    end
    else
    begin
      Ed.Strings.TextInsert(X2, Y2, CharEnd, false, Shift, PosAfter);
      Ed.DoCaretsShift(NCaret, X2, Y2, Shift.X, Shift.Y, PosAfter);

      Ed.Strings.TextInsert(X1, Y1, CharBegin, false, Shift, PosAfter);
      Ed.DoCaretsShift(NCaret, X1, Y1, Shift.X, Shift.Y, PosAfter);

      Caret.EndX:= X1+1;
      Caret.EndY:= Y1;
      Caret.PosX:= X2+IfThen(Y1=Y2, 1);
      Caret.PosY:= Y2;

      if bBackwardSel then
        Caret.SwapSelection;
    end;

    Result:= true;
  end;
  Ed.Strings.EndUndoGroup;

  if Result then
  begin
    Ed.Modified:= true;
    Ed.Update(true);
  end;
end;


procedure EditorFocus(C: TWinControl);
var
  Form: TCustomForm;
begin
  Form:= GetParentForm(C);
  if not Form.Focused then
    if Form.CanFocus then
      Form.SetFocus;

  try
    if Form.Visible and Form.Enabled then
    begin
      Form.ActiveControl:= C;
      if C.CanFocus then
        C.SetFocus;
    end;
  except
  end;
end;


procedure EditorGotoLastEditingPos(Ed: TATSynEdit;
  AIndentHorz, AIndentVert: integer);
var
  Caret: TATCaretItem;
begin
  Ed.Strings.DoGotoLastEditPos;
  if Ed.Carets.Count>0 then
  begin
    Caret:= Ed.Carets[0];
    Ed.DoGotoPos(
      Point(Caret.PosX, Caret.PosY),
      Point(-1, -1),
      AIndentHorz,
      AIndentVert,
      true,
      true
      );
  end;
end;


function EditorGotoFromString(Ed: TATSynEdit; SInput: string): boolean;
var
  NumCount, NumLine, NumCol: integer;
  Pnt: TPoint;
  bExtend: boolean;
  Caret: TATCaretItem;
  Sep: TATStringSeparator;
begin
  NumCount:= Ed.Strings.Count;
  if NumCount<2 then exit(false);

  bExtend:= SEndsWith(SInput, '+');
  if bExtend then
    SetLength(SInput, Length(SInput)-1);

  if SEndsWith(SInput, '%') then
  begin
    NumLine:= StrToIntDef(Copy(SInput, 1, Length(SInput)-1), 0);
    if NumLine<0 then
      NumLine:= NumCount-1 + (NumCount * NumLine div 100)
    else
      NumLine:= NumCount * NumLine div 100;
    NumCol:= 0;
  end
  else
  if SBeginsWith(SInput, 'd') then
  begin
    Pnt:= Ed.Strings.OffsetToPosition(
      StrToIntDef(Copy(SInput, 2, MaxInt), -1));
    NumLine:= Pnt.Y;
    NumCol:= Pnt.X;
  end
  else
  if SBeginsWith(SInput, 'x') then
  begin
    Pnt:= Ed.Strings.OffsetToPosition(
      StrToIntDef('$'+Copy(SInput, 2, MaxInt), -1));
    NumLine:= Pnt.Y;
    NumCol:= Pnt.X;
  end
  else
  begin
    Sep.Init(SInput, ':');
    Sep.GetItemInt(NumLine, 0);
    Sep.GetItemInt(NumCol, 0);
    if NumLine<0 then
      NumLine:= NumCount+NumLine
    else
      Dec(NumLine);
    Dec(NumCol);
  end;

  Result:= NumLine>=0;
  if not Result then exit;

  NumLine:= Min(NumLine, NumCount-1);
  NumCol:= Max(0, NumCol);

  Pnt:= Point(-1, -1);
  if bExtend then
  begin
    if Ed.Carets.Count=0 then exit;
    Caret:= Ed.Carets[0];
    //set end of selection to previous caret pos
    Pnt:= Point(Caret.PosX, Caret.PosY);
    //make it like SynWrite: jump extends previous selection (below and above)
    if Caret.EndY>=0 then
      if IsPosSorted(Caret.PosX, Caret.PosY, NumCol, NumLine, true) then
      begin
        //jump below
        if Caret.IsForwardSelection then
          Pnt:= Point(Caret.EndX, Caret.EndY);
      end
      else
      begin
        //jump above
        if not Caret.IsForwardSelection then
          Pnt:= Point(Caret.EndX, Caret.EndY);
      end;
  end;

  Ed.DoGotoPos(
    Point(NumCol, NumLine),
    Pnt,
    UiOps.FindIndentHorz,
    UiOps.FindIndentVert,
    true,
    true
    );
  Ed.Update;
end;


procedure EditorCaretPropsFromString(Props: TATCaretProps; const AText: string);
var
  Sep: TATStringSeparator;
  S: string;
begin
  Sep.Init(AText);
  Sep.GetItemInt(Props.Width, 1);
  Sep.GetItemInt(Props.Height, -100);
  Sep.GetItemStr(S);
  Props.EmptyInside:= S='_';
end;


procedure EditorCaretPropsFromPyTuple(Props: TATCaretProps; const AText: string);
var
  Sep: TATStringSeparator;
  S: string;
begin
  Sep.Init(AText);
  Sep.GetItemInt(Props.Width, 1);
  Sep.GetItemInt(Props.Height, -100);
  Sep.GetItemStr(S);
  Props.EmptyInside:= S='1';
end;

function EditorBracket_GetPairForClosingBracketOrQuote(ch: char): char;
begin
  case ch of
    ')': Result:= '(';
    ']': Result:= '[';
    '}': Result:= '{';
    '"': Result:= '"';
    '''': Result:= '''';
    '`': Result:= '`';
    else Result:= #0;
  end;
end;

procedure EditorBracket_GetCharKind(ch: atChar; out Kind: TATEditorBracketKind; out PairChar: atChar);
begin
  case ch of
    '(': begin Kind:= bracketOpening; PairChar:= ')'; end;
    '[': begin Kind:= bracketOpening; PairChar:= ']'; end;
    '{': begin Kind:= bracketOpening; PairChar:= '}'; end;
    '<': begin Kind:= bracketOpening; PairChar:= '>'; end;
    ')': begin Kind:= bracketClosing; PairChar:= '('; end;
    ']': begin Kind:= bracketClosing; PairChar:= '['; end;
    '}': begin Kind:= bracketClosing; PairChar:= '{'; end;
    '>': begin Kind:= bracketClosing; PairChar:= '<'; end;
    else begin Kind:= bracketUnknown; PairChar:= #0; end;
  end;
end;

procedure EditorBracket_FindOpeningBracketBackward(Ed: TATSynEdit;
  PosX, PosY: integer;
  const AllowedSymbols: string;
  MaxDistance: integer;
  out FoundX, FoundY: integer);
var
  Level: integer;
  Kind: TATEditorBracketKind;
  ch, ch2: atChar;
  iLine, iChar, nChar: integer;
  S: atString;
begin
  FoundX:= -1;
  FoundY:= -1;
  Level:= 0;

  for iLine:= PosY downto Max(0, PosY-MaxDistance) do
  begin
    S:= Ed.Strings.Lines[iLine];
    if S='' then Continue;
    if iLine=PosY then
      nChar:= Min(PosX, Length(S)-1)
    else
      nChar:= Length(S)-1;
    for iChar:= nChar downto 0 do
    begin
      ch:= S[iChar+1];
      if Pos(ch, AllowedSymbols)=0 then Continue;
      EditorBracket_GetCharKind(ch, Kind, ch2);
      if Kind=bracketUnknown then Continue;

      //ignore brackets in comments/strings, because of constants '{', '(' etc
      if EditorGetTokenKind(Ed, iChar, iLine)<>cTokenKindOther then Continue;

      if Kind=bracketClosing then
      begin
        Dec(Level);
      end
      else
      if Kind=bracketOpening then
      begin
        Inc(Level);
        if Level>0 then
        begin
          FoundX:= iChar;
          FoundY:= iLine;
          exit;
        end;
      end;
    end;
  end;
end;

procedure EditorBracket_FindPair(
  Ed: TATSynEdit;
  CharFrom, CharTo: atChar;
  Kind: TATEditorBracketKind;
  MaxDistance: integer;
  FromX, FromY: integer;
  out FoundX, FoundY: integer);
var
  St: TATStrings;
  S: atString;
  IndexX, IndexY, IndexXBegin, IndexXEnd: integer;
  Level: integer;
  ch: atChar;
begin
  FoundX:= -1;
  FoundY:= -1;
  Level:= 0;
  St:= Ed.Strings;

  if Kind=bracketOpening then
  begin
    for IndexY:= FromY to Min(Int64(St.Count-1), Int64(FromY)+MaxDistance) do
    begin
      S:= St.Lines[IndexY];
      if S='' then Continue;
      if IndexY=FromY then
        IndexXBegin:= FromX+1
      else
        IndexXBegin:= 0;
      IndexXEnd:= Length(S)-1;
      for IndexX:= IndexXBegin to IndexXEnd do
      begin
        ch:= S[IndexX+1];
        if (ch=CharFrom) and (EditorGetTokenKind(Ed, IndexX, IndexY)=cTokenKindOther) then
          Inc(Level)
        else
        if (ch=CharTo) and (EditorGetTokenKind(Ed, IndexX, IndexY)=cTokenKindOther) then
        begin
          if Level>0 then
            Dec(Level)
          else
          begin
            FoundX:= IndexX;
            FoundY:= IndexY;
            Exit
          end;
        end;
      end;
    end;
  end
  else
  begin
    for IndexY:= FromY downto Max(0, Int64(FromY)-MaxDistance) do
    begin
      S:= St.Lines[IndexY];
      if S='' then Continue;
      if IndexY=FromY then
        IndexXEnd:= FromX-1
      else
        IndexXEnd:= Length(S)-1;
      IndexXBegin:= 0;
      for IndexX:= IndexXEnd downto IndexXBegin do
      begin
        ch:= S[IndexX+1];
        if (ch=CharFrom) and (EditorGetTokenKind(Ed, IndexX, IndexY)=cTokenKindOther) then
          Inc(Level)
        else
        if (ch=CharTo) and (EditorGetTokenKind(Ed, IndexX, IndexY)=cTokenKindOther) then
        begin
          if Level>0 then
            Dec(Level)
          else
          begin
            FoundX:= IndexX;
            FoundY:= IndexY;
            Exit
          end;
        end;
      end;
    end;
  end;
end;

procedure EditorBracket_ClearHilite(Ed: TATSynEdit);
begin
  Ed.Attribs.DeleteWithTag(cEditorTagForBracket);
  Ed.GutterDecor.DeleteByTag(cEditorTagForBracket);
end;

procedure EditorBracket_FindBoth(Ed: TATSynEdit;
  var PosX, PosY: integer;
  const AllowedSymbols: string;
  MaxDistance: integer;
  out FoundX, FoundY: integer;
  out CharFrom, CharTo: atChar;
  out Kind: TATEditorBracketKind);
var
  S: atString;
begin
  FoundX:= -1;
  FoundY:= -1;

  if PosX<0 then exit;
  if not Ed.Strings.IsIndexValid(PosY) then exit;

  S:= Ed.Strings.Lines[PosY];
  if (PosX=Length(S)) and (PosX>0) then
    Dec(PosX);

  Kind:= bracketUnknown;
  if PosX<Length(S) then
  begin
    CharFrom:= S[PosX+1];
    if Pos(CharFrom, AllowedSymbols)>0 then
      if EditorGetTokenKind(Ed, PosX, PosY)=cTokenKindOther then
        EditorBracket_GetCharKind(CharFrom, Kind, CharTo);
  end;

  if Kind=bracketUnknown then
  begin
    //test char before caret
    if (PosX>0) and (PosX<Length(S)) then
    begin
      Dec(PosX);
      CharFrom:= S[PosX+1];
      if Pos(CharFrom, AllowedSymbols)>0 then
      begin
        if EditorGetTokenKind(Ed, PosX, PosY)=cTokenKindOther then
          EditorBracket_GetCharKind(CharFrom, Kind, CharTo);
      end
      else
        Kind:= bracketUnknown;
    end;

    //find opening bracket backwards
    if Kind=bracketUnknown then
    begin
      EditorBracket_FindOpeningBracketBackward(Ed,
        PosX, PosY,
        AllowedSymbols,
        MaxDistance,
        FoundX, FoundY);
      if FoundY<0 then exit;
      PosX:= FoundX;
      PosY:= FoundY;
      S:= Ed.Strings.Lines[PosY];
      CharFrom:= S[PosX+1];
      EditorBracket_GetCharKind(CharFrom, Kind, CharTo);
    end;

    if Kind=bracketUnknown then exit;
  end;

  EditorBracket_FindPair(Ed, CharFrom, CharTo, Kind,
    MaxDistance, PosX, PosY, FoundX, FoundY);
end;


procedure EditorBracket_Action(Ed: TATSynEdit;
  Action: TATEditorBracketAction;
  const AllowedSymbols: string;
  MaxDistance: integer);
var
  Caret: TATCaretItem;
  CharFrom, CharTo: atChar;
  Kind: TATEditorBracketKind;
  PartObj: TATLinePartClass;
  Decor: TATGutterDecorData;
  PosX, PosY, FoundX, FoundY: integer;
  Pnt1, Pnt2: TPoint;
begin
  EditorBracket_ClearHilite(Ed);

  if Ed.Carets.Count<>1 then exit;
  Caret:= Ed.Carets[0];
  PosX:= Caret.PosX;
  PosY:= Caret.PosY;
  //don't work if selection
  if Caret.EndY>=0 then exit;

  EditorBracket_FindBoth(Ed,
    PosX, PosY,
    AllowedSymbols,
    MaxDistance,
    FoundX, FoundY,
    CharFrom, CharTo,
    Kind);
  if FoundY<0 then exit;

  case Action of
    bracketActionHilite:
      begin
        PartObj:= TATLinePartClass.Create;
        ApplyPartStyleFromEcontrolStyle(PartObj.Data, AppStyleBrackets);
        Ed.Attribs.Add(PosX, PosY, cEditorTagForBracket, 1, 0, PartObj);

        PartObj:= TATLinePartClass.Create;
        ApplyPartStyleFromEcontrolStyle(PartObj.Data, AppStyleBrackets);
        Ed.Attribs.Add(FoundX, FoundY, cEditorTagForBracket, 1, 0, PartObj);

        FillChar(Decor, SizeOf(Decor), 0);
        Decor.DeleteOnDelLine:= true;
        Decor.ImageIndex:= -1;
        Decor.Tag:= cEditorTagForBracket;
        Decor.TextBold:= fsBold in AppStyleSymbols.Font.Style;
        Decor.TextItalic:= fsItalic in AppStyleSymbols.Font.Style;
        Decor.TextColor:= AppStyleSymbols.Font.Color;

        if PosY<>FoundY then
        begin
          Decor.LineNum:= PosY;
          Decor.Text:= CharFrom;
          Ed.GutterDecor.Add(Decor);

          Decor.LineNum:= FoundY;
          Decor.Text:= CharTo;
          Ed.GutterDecor.Add(Decor);
        end
        else
        begin
          Decor.LineNum:= PosY;
          if Kind=bracketOpening then
            Decor.Text:= CharFrom+CharTo
          else
            Decor.Text:= CharTo+CharFrom;
          Ed.GutterDecor.Add(Decor);
        end;
      end;

    bracketActionJump:
      begin
        Ed.DoGotoPos(
          Point(FoundX, FoundY),
          Point(-1, -1),
          UiOps.FindIndentHorz,
          UiOps.FindIndentVert,
          true,
          true
          );
      end;

    bracketActionSelect:
      begin
        if IsPosSorted(PosX, PosY, FoundX, FoundY, true) then
        begin
          Pnt1:= Point(FoundX+1, FoundY);
          Pnt2:= Point(PosX, PosY);
        end
        else
        begin
          Pnt1:= Point(FoundX, FoundY);
          Pnt2:= Point(PosX+1, PosY);
        end;
        if Pnt1<>Pnt2 then
          Ed.DoGotoPos(
            Pnt1,
            Pnt2,
            UiOps.FindIndentHorz,
            UiOps.FindIndentVert,
            true,
            true
            )
      end;

    bracketActionSelectInside:
      begin
        if IsPosSorted(PosX, PosY, FoundX, FoundY, true) then
        begin
          Pnt1:= Point(FoundX, FoundY);
          Pnt2:= Point(PosX+1, PosY);
        end
        else
        begin
          Pnt1:= Point(FoundX+1, FoundY);
          Pnt2:= Point(PosX, PosY);
        end;
        if Pnt1<>Pnt2 then
          Ed.DoGotoPos(
            Pnt1,
            Pnt2,
            UiOps.FindIndentHorz,
            UiOps.FindIndentVert,
            true,
            true
            )
      end;
  end;
end;

function _StringToPython(const S: string): string; inline;
begin
  Result:= StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result:= StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result:= '"'+Result+'"';
end;

procedure EditorSaveTempOptions(Ed: TATSynEdit; var Ops: TATEditorTempOps);
begin
  Ops.FontSize:= Ed.Font.Size;
  Ops.WrapMode:= Ed.OptWrapMode;
  Ops.ShowMinimap:= Ed.OptMinimapVisible;
  Ops.ShowMicromap:= Ed.OptMicromapVisible;
  Ops.ShowRuler:= Ed.OptRulerVisible;
  Ops.ShowNumbers:= Ed.Gutter.Items[Ed.GutterBandNumbers].Visible;
  Ops.ShowUnprinted:= Ed.OptUnprintedVisible;
end;

procedure EditorRestoreTempOptions(Ed: TATSynEdit; const Ops: TATEditorTempOps);
begin
  Ed.Font.Size:= Ops.FontSize;
  Ed.OptWrapMode:= Ops.WrapMode;
  Ed.OptMinimapVisible:= Ops.ShowMinimap;
  Ed.OptMicromapVisible:= Ops.ShowMicromap;
  Ed.OptRulerVisible:= Ops.ShowRuler;
  Ed.Gutter.Items[Ed.GutterBandNumbers].Visible:= Ops.ShowNumbers;
  Ed.OptUnprintedVisible:= Ops.ShowUnprinted;
end;

procedure EditorCopySelToPrimarySelection(Ed: TATSynEdit; AMaxLineCount: integer);
var
  Caret: TATCaretItem;
  NFrom, NTo: integer;
begin
  if Ed.Carets.Count<>1 then exit;
  Caret:= Ed.Carets[0];
  if Caret.EndY<0 then exit;
  Caret.GetSelLines(NFrom, NTo, false);
  if NTo-NFrom<=AMaxLineCount then
    SClipboardCopy(Ed.TextSelected, PrimarySelection);
end;

function EditorGetTokenKind(Ed: TATSynEdit; AX, AY: integer): TATFinderTokenKind;
var
  Pnt1, Pnt2: TPoint;
  STokenText, STokenStyle: string;
  An: TecSyntAnalyzer;
begin
  Result:= cTokenKindOther;

  if not (Ed.AdapterForHilite is TATAdapterEControl) then exit;
  TATAdapterEControl(Ed.AdapterForHilite).GetTokenAtPos(
    Point(AX, AY),
    Pnt1,
    Pnt2,
    STokenText,
    STokenStyle
    );
  if STokenStyle='' then exit;

  An:= TATAdapterEControl(Ed.AdapterForHilite).Lexer;
  if An=nil then exit;

  if An.StylesOfComments<>'' then
    if Pos(','+STokenStyle+',', ','+An.StylesOfComments+',')>0 then
      exit(cTokenKindComment);

  if An.StylesOfStrings<>'' then
    if Pos(','+STokenStyle+',', ','+An.StylesOfStrings+',')>0 then
      exit(cTokenKindString);
end;


end.

