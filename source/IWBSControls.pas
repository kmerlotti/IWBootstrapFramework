unit IWBSControls;

interface

uses Classes, SysUtils, Db,
     IWControl, IWRenderContext, IWMarkupLanguageTag, IWXMLTag, IWHTMLTag,
     IWDBCommon, IWBSCommon,
     IWBSCustomControl;

type
  TIWBSLabel = class(TIWBSCustomDbControl)
  private
    FForControl: TIWCustomControl;
    FRawText: boolean;
    FOldText: string;
    FTagType: string;
    function  RenderLabelText: string;
    procedure SetTagType(const Value: string);
    function IsTagTypeStored: Boolean;
  protected
    procedure CheckData(AContext: TIWCompContext); override;
    procedure InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext); override;
    procedure InternalRenderCss(var ACss: string); override;
    procedure InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag); override;
    procedure SetForControl(const Value: TIWCustomControl);
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption;
    property ForControl: TIWCustomControl read FForControl write SetForControl;
    property RawText: boolean read FRawText write FRawText default False;
    property TagType: string read FTagType write SetTagType stored IsTagTypeStored;
  end;

  TIWBSText = class(TIWBSCustomDbControl)
  private
    FLines: TStringList;
    FRawText: boolean;
    FOldText: string;
    FTagType: string;
    function  RenderText: string;
    procedure OnLinesChange(ASender : TObject);
    procedure SetLines(const AValue: TStringList);
    function IsTagTypeStored: Boolean;
    procedure SetTagType(const Value: string);
    procedure SetRawText(const Value: boolean);
  protected
    procedure CheckData(AContext: TIWCompContext); override;
    procedure InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext); override;
    procedure InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Lines: TStringList read FLines write SetLines;
    property RawText: boolean read FRawText write SetRawText default False;
    property TagType: string read FTagType write SetTagType stored IsTagTypeStored;
  end;

  TIWBSGlyphicon = class(TIWBSCustomControl)
  private
    FGlyphicon: string;
  protected
    procedure InternalRenderCss(var ACss: string); override;
    procedure InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property BSGlyphicon: string read FGlyphicon write FGlyphicon;
  end;

  TIWBSFile = class(TIWBSCustomControl)
  private
    FMultiple: boolean;
    procedure SetMultiple(const Value: boolean);
  protected
    procedure InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Multiple: boolean read FMultiple write SetMultiple default False;
  end;

implementation

uses IW.Common.System, IWBSInput, IWBSRegion, IWBSInputCommon, IWBSCustomEvents, IWBSRegionCommon;

{$region 'TIWBSLabel'}
constructor TIWBSLabel.Create(AOwner: TComponent);
begin
  inherited;
  FRawText := False;
  FTagType := 'span';
  Height := 25;
  Width := 200;
end;

procedure TIWBSLabel.SetForControl(const Value: TIWCustomControl);
begin
  FForControl := Value;
end;

procedure TIWBSLabel.SetTagType(const Value: string);
begin
  TIWBSCommon.ValidateTagName(Value);
  FTagType := Value;
  AsyncRefreshControl;
end;

function TIWBSLabel.RenderLabelText: string;
begin
  if RawText then
    Result := Caption
  else
    Result := TextToHTML(Caption);
end;

procedure TIWBSLabel.InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext);
begin
  inherited;
  SetAsyncHtml(AContext, AHTMLName, RenderLabelText, FOldText);
end;

procedure TIWBSLabel.InternalRenderCss(var ACss: string);
begin
  inherited;
  if Parent is TIWBSRegion then
    if TIWBSRegion(Parent).BSRegionType = bsrtModalHeader then
      TIWBSCommon.AddCssClass(ACss, 'modal-title')
    else if TIWBSRegion(Parent).BSRegionType = bsrtPanelHeading then
      TIWBSCommon.AddCssClass(ACss, 'panel-title');
end;

procedure TIWBSLabel.InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag);
begin
  inherited;
  FOldText := RenderLabelText;

  if Assigned(FForControl) then
    begin
      AHTMLTag := TIWHTMLTag.CreateTag('label');
      AHTMLTag.AddStringParam('for', ForControl.HTMLName);
    end
  else
    AHTMLTag := TIWHTMLTag.CreateTag(FTagType);
  AHTMLTag.AddStringParam('id', HTMLName);
  AHTMLTag.AddClassParam(ActiveCss);
  AHTMLTag.AddStringParam('style',ActiveStyle);
  AHTMLTag.Contents.AddText(FOldText);

  if Parent is TIWBSInputGroup then
    AHTMLTag := IWBSCreateInputGroupAddOn(AHTMLTag, HTMLName, 'addon');
end;

function TIWBSLabel.IsTagTypeStored: Boolean;
begin
  Result := FTagType <> 'span';
end;

procedure TIWBSLabel.CheckData(AContext: TIWCompContext);
var
  LField: TField;
begin
  if CheckDataSource(DataSource, DataField, LField) then
    Caption := LField.DisplayText;
end;
{$endregion}

{$region 'TIWBSText'}
constructor TIWBSText.Create(AOwner: TComponent);
begin
  inherited;
  FLines := TStringList.Create;
  FLines.OnChange := OnLinesChange;
  FRawText := False;
  FTagType := 'div';
  Height := 100;
  Width := 200;
end;

destructor TIWBSText.Destroy;
begin
  FLines.Free;
  inherited;
end;

procedure TIWBSText.OnLinesChange( ASender : TObject );
begin
  Invalidate;
  if Script.Count > 0 then
    AsyncRefreshControl;
end;

procedure TIWBSText.SetLines(const AValue: TStringList);
begin
  FLines.Assign(AValue);
end;

procedure TIWBSText.SetRawText(const Value: boolean);
begin
  FRawText := Value;
  AsyncRefreshControl;
end;

procedure TIWBSText.SetTagType(const Value: string);
begin
  TIWBSCommon.ValidateTagName(Value);
  FTagType := Value;
  AsyncRefreshControl;
end;

function TIWBSText.RenderText: string;
var
  i: integer;
  LLines: TStringList;
begin
  if RawText then
    begin
      LLines := TStringList.Create;
      try
        LLines.Assign(FLines);

        // replace params before custom events
        LLines.Text := TIWBSCommon.ReplaceParams(Self, LLines.Text);

        // replace inner events calls
        if IsStoredCustomAsyncEvents then
          for i := 0 to CustomAsyncEvents.Count-1 do
            TIWBSCustomAsyncEvent(CustomAsyncEvents.Items[i]).ParseParam(LLines);

        // replace inner events calls
        if IsStoredCustomRestEvents then
          for i := 0 to CustomRestEvents.Count-1 do
            TIWBSCustomRestEvent(CustomRestEvents.Items[i]).ParseParam(LLines);

        Result := LLines.Text;
      finally
        LLines.Free;
      end;
    end
  else
    Result := TextToHTML(Lines.Text);
end;

procedure TIWBSText.InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext);
begin
  inherited;
  SetAsyncHtml(AContext, AHTMLName, RenderText, FOldText);
end;

procedure TIWBSText.InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag);
begin
  inherited;
  FOldText := RenderText;

  AHTMLTag := TIWHTMLTag.CreateTag(FTagType);
  AHTMLTag.AddStringParam('id', HTMLName);
  AHTMLTag.AddClassParam(ActiveCss);
  AHTMLTag.AddStringParam('style',ActiveStyle);
  AHTMLTag.Contents.AddText(FOldText);
end;

function TIWBSText.IsTagTypeStored: Boolean;
begin
  Result := FTagType <> 'div';
end;

procedure TIWBSText.CheckData(AContext: TIWCompContext);
var
  LField: TField;
begin
  if CheckDataSource(DataSource, DataField, LField) then
    Lines.Text := LField.DisplayText;
end;
{$endregion}

{$region 'TIWBSGlyphicon'}
constructor TIWBSGlyphicon.Create(AOwner: TComponent);
begin
  inherited;
  Height := 25;
  Width := 25;
end;

procedure TIWBSGlyphicon.InternalRenderCss(var ACss: string);
begin
  inherited;
  if FGlyphicon <> '' then
    TIWBSCommon.AddCssClass(ACss, 'glyphicon glyphicon-'+FGlyphicon);
end;

procedure TIWBSGlyphicon.InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag);
begin
  inherited;
  AHTMLTag := TIWHTMLTag.CreateTag('span');
  try
    AHTMLTag.AddStringParam('id', AHTMLName);
    AHTMLTag.AddClassParam(ActiveCss);
    AHTMLTag.AddStringParam('style',ActiveStyle);
    if FGlyphicon <> '' then
      AHTMLTag.AddBoolParam('aria-hidden',true)
    else
      AHTMLTag.Contents.AddText('&times;');
  except
    FreeAndNil(AHTMLTag);
    raise;
  end;
  if Parent is TIWBSInputGroup then
    AHTMLTag := IWBSCreateInputGroupAddOn(AHTMLTag, AHTMLName, 'addon');
end;
{$endregion}

{$region 'TIWBSFile' }
constructor TIWBSFile.Create(AOwner: TComponent);
begin
  inherited;
  FMultiple := False;
  Height := 25;
  Width := 121;
end;

procedure TIWBSFile.InternalRenderHTML(const AHTMLName: string;
  AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag);
begin
  inherited;

  AHTMLTag := TIWHTMLTag.CreateTag('input');
  try
    AHTMLTag.AddClassParam(ActiveCss);
    AHTMLTag.AddStringParam('id', AHTMLName);
    AHTMLTag.AddStringParam('name', AHTMLName+iif(FMultiple,'[]'));
    AHTMLTag.AddStringParam('type', 'file');
    if ShowHint and (Hint <> '') then
      AHTMLTag.AddStringParam('title', Hint);
    if FMultiple then
      AHTMLTag.Add('multiple');

//    if AutoFocus then
//      AHTMLTag.Add('autofocus');
//    if IsReadOnly then
//      AHTMLTag.Add('readonly');
    if IsDisabled then
      AHTMLTag.Add('disabled');
//    AHTMLTag.AddStringParam('value', TextToHTML(FText));
//    if Required then
//      AHTMLTag.Add('required');
//    if PlaceHolder <> '' then
//      AHTMLTag.AddStringParam('placeholder', TextToHTML(PlaceHolder));
    AHTMLTag.AddStringParam('style', ActiveStyle);
  except
    FreeAndNil(AHTMLTag);
    raise;
  end;

  AHTMLTag := IWBSCreateFormGroup(Parent, IWBSFindParentInputForm(Parent), AHTMLTag, AHTMLName, True);
end;

procedure TIWBSFile.SetMultiple(const Value: boolean);
begin
  FMultiple := Value;
  AsyncRefreshControl;
end;

end.
