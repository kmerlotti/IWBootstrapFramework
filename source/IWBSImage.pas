unit IWBSImage;

interface

uses Classes, SysUtils, StrUtils, Graphics, Db,
     IWScriptEvents, IWBaseInterfaces,
     IWRenderContext, IWHTMLTag, IWBSCustomControl, IWCompExtCtrls;


type
  TIWBSImageOption = (iwbsimResponsive, iwbsimCircle, iwbsimRounded, iwbsimThumbnail);
  TIWBSImageOptions = set of TIWBSImageOption;

  TIWBSImage = class(TIWBSCustomDbControl)
  private
    FActiveSrc: string;
    FOldSrc: string;

    FAltText: string;
    FEmbedBase64: boolean;
    FImageFile: string;
    FImageOptions: TIWBSImageOptions;
    FimageSrc: string;
    FMimeType: string;
    FPicture: TPicture;
    FUseSize: Boolean;

    procedure SetImageFile(const AValue: string);
    procedure SetImageSrc(const AValue: string);
    function GetPicture: TPicture;
    procedure SetPicture(AValue: TPicture);
    procedure SetUseSize(const AValue: Boolean);
  protected
    procedure CheckData(AContext: TIWCompContext); override;
    procedure PictureChanged(ASender: TObject);
    procedure InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext); override;
    procedure InternalRenderCss(var ACss: string); override;
    procedure InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag); override;
    procedure InternalRenderStyle(AStyle: TStringList); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property ActiveSrc: string read FActiveSrc;
    procedure Refresh;
    function GetFixedFilePath: string;
  published
    property AltText: string read FAltText write FAltText;
    property BSImageOptions: TIWBSImageOptions read FImageOptions write FImageOptions default [iwbsimResponsive];
    property EmbedBase64: boolean read FEmbedBase64 write FEmbedBase64 default False;
    property Enabled default True;
    property ImageFile: string read FImageFile write SetImageFile;
    property ImageSrc: string read FImageSrc write SetImageSrc;
    property MimeType: string read FMimeType write FMimeType;
    property Picture: TPicture read GetPicture write SetPicture;
    property UseSize: Boolean read FUseSize write SetUseSize default False;
  end;

implementation

uses IW.Common.System, IW.Common.Strings, IWTypes, IWForm, IWAppCache, IW.CacheStream,
     IWDbCommon, IWURL, IWFilePath, IWGlobal, InCoderMIME,
     IWBSCommon;

{$region 'FieldBlobStream'}
// this comes from TBlobField.SaveToStreamPersist, is the only way to directly obtain a valid image without usen a TPicture
type
  TGraphicHeader = record
    Count: Word;                { Fixed at 1 }
    HType: Word;                { Fixed at $0100 }
    Size: Longint;              { Size not including header }
  end;

function GetFieldBlobStream(ADataSet: TDataSet; AField: TBlobField): TStream;
var
  Size: Longint;
  GraphicHeader: TGraphicHeader;
begin
  Result := ADataSet.CreateBlobStream(AField, bmRead);
  Size := Result.Size;
  if Size >= SizeOf(TGraphicHeader) then begin
    Result.Read(GraphicHeader, SizeOf(GraphicHeader));
    if (GraphicHeader.Count <> 1) or (GraphicHeader.HType <> $0100) or
      (GraphicHeader.Size <> Size - SizeOf(GraphicHeader)) then
      Result.Position := 0;
  end;
end;
{
function GetFieldBlobStream(ADataSet: TDataSet; AField: TBlobField): TStream;
var
  Size: Longint;
  Header: TBytes;
  GraphicHeader: TGraphicHeader;
begin
  Result := ADataSet.CreateBlobStream(AField, bmRead);
  Size := Result.Size;
  if Size >= SizeOf(TGraphicHeader) then begin
    SetLength(Header, SizeOf(TGraphicHeader));
    Result.Read(Header, 0, Length(Header));
    Move(Header[0], GraphicHeader, SizeOf(TGraphicHeader));
    if (GraphicHeader.Count <> 1) or (GraphicHeader.HType <> $0100) or
      (GraphicHeader.Size <> Size - SizeOf(GraphicHeader)) then
      Result.Position := 0;
  end;
end;
}
{$endregion}

{$region 'TIWBSImage'}
constructor TIWBSImage.Create(AOwner: TComponent);
begin
  inherited;
  FAltText := '';
  ImageFile := '';
  FImageOptions := [iwbsimResponsive];
  ImageSrc := '';
  FMimeType := '';
  FPicture := nil;
  FUseSize := False;
  Width := 89;
  Height := 112;
end;

destructor TIWBSImage.Destroy;
begin
  FreeAndNil(FPicture);
  inherited;
end;

function TIWBSImage.GetPicture: TPicture;
begin
  if not Assigned(FPicture) then begin
    FPicture := TPicture.Create;
    FPicture.OnChange := PictureChanged;
  end;
  Result := FPicture;
end;

procedure TIWBSImage.SetImageFile(const AValue: string);
begin
  FImageFile := AValue;
  FActiveSrc := '';
  Invalidate;
end;

procedure TIWBSImage.SetImageSrc(const AValue: string);
begin
  FImageSrc := AValue;
  FActiveSrc := '';
  Invalidate;
end;

procedure TIWBSImage.SetPicture(AValue: TPicture);
begin
  Picture.Assign(AValue);
  FActiveSrc := '';
end;

procedure TIWBSImage.PictureChanged(ASender: TObject);
begin
  if not IsLoading then begin
    FActiveSrc := '';
    Invalidate;
  end;
end;

procedure TIWBSImage.SetUseSize(const AValue: Boolean);
begin
  if FUseSize <> AValue then begin
    FUseSize := AValue;
    Invalidate;
  end;
end;

procedure TIWBSImage.Refresh;
begin
  FActiveSrc := '';
  Invalidate;
end;

function TIWBSImage.GetFixedFilePath: string;
begin
  if not TFilePath.IsAbsolute(FImageFile) and Assigned(gSC) then
    begin
      Result := TFilePath.Concat(gSC.ContentPath, FImageFile);
      if not FileExists(Result) then
        Result := FImageFile;
    end
  else
    Result := FImageFile;
end;

procedure TIWBSImage.CheckData(AContext: TIWCompContext);
var
  LField: TField;
  LMimeType: string;
  LFile: string;
  LStream: TStream;
  LFileStream: TFileStream;
  LParentForm: TIWForm;
begin
  LFile := '';

  if FMimeType <> '' then
    LMimeType := FMimeType
  else
    LMimeType := 'image';

  // if there is field data we show it, if not we fallback to other sources
  if CheckDataSource(DataSource, DataField, LField) then begin
    FActiveSrc := '';
    if Assigned(FPicture) then
      FPicture.Graphic := nil;
    if (LField is TBlobField) and not LField.IsNull then begin
      LStream := GetFieldBlobStream(DataSource.DataSet, TBlobField(LField));
      try
        if FEmbedBase64 then
          FActiveSrc := 'data:image;base64, '+TIdEncoderMIME.EncodeStream(LStream)
        else
          begin
            LFile := TIWAppCache.NewTempFileName;
            LFileStream := TFileStream.Create(LFile, fmCreate);
            try
              LFileStream.CopyFrom(LStream, LStream.Size-LStream.Position);
            finally
              LFileStream.Free;
            end;
            FActiveSrc := TIWAppCache.AddFileToCache(AContext.WebApplication, LFile, LMimeType);
          end;
      finally
        LStream.Free;
      end;
    end;
  end;

  if FActiveSrc = '' then begin

    if Assigned(FPicture) and Assigned(FPicture.Graphic) and (not FPicture.Graphic.Empty) then
      begin
        if FEmbedBase64 then
          begin
            LStream := TMemoryStream.Create;
            try
              FPicture.Graphic.SaveToStream(LStream);
              LStream.Position := 0;
              FActiveSrc := 'data:image;base64, '+TIdEncoderMIME.EncodeStream(LStream)
            finally
              LStream.Free;
            end;
          end
        else
          begin
            LFile := TIWAppCache.NewTempFileName;
            FPicture.SaveToFile(LFile);
          end;
      end

    else if FImageFile <> ''  then
      LFile := GetFixedFilePath

    else if FImageSrc <> '' then
      begin
        if AnsiStartsStr('//', FImageSrc) or AnsiContainsStr('://', FImageSrc) then
          FActiveSrc := FImageSrc
        else
          FActiveSrc := TURL.MakeValidFileUrl(AContext.WebApplication.AppUrlBase, FImageSrc);
      end;

    if LFile <> '' then begin
      LParentForm := TIWForm.FindParentForm(Self);
      if LParentForm <> nil then
        FActiveSrc := TIWAppCache.AddFileToCache(LParentForm, LFile, LMimeType, ctForm)
      else
        FActiveSrc := TIWAppCache.AddFileToCache(AContext.WebApplication, LFile, LMimeType);
    end;
  end;
end;

procedure TIWBSImage.InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext);
begin
  inherited;
  if FActiveSrc <> FOldSrc then begin
    AContext.WebApplication.CallBackResponse.AddJavaScriptToExecute('$("#'+AHTMLName+'").attr("src","'+FActiveSrc+'");');
    FOldSrc := FActiveSrc;
  end;
end;

procedure TIWBSImage.InternalRenderCss(var ACss: string);
begin
  if iwbsimResponsive in FImageOptions then
    TIWBSCommon.AddCssClass(ACss, 'img-responsive');
  if iwbsimCircle in FImageOptions then
    TIWBSCommon.AddCssClass(ACss, 'img-circle');
  if iwbsimRounded in FImageOptions then
    TIWBSCommon.AddCssClass(ACss, 'img-rounded');
  if iwbsimThumbnail in FImageOptions then
    TIWBSCommon.AddCssClass(ACss, 'img-thumbnail');
end;

procedure TIWBSImage.InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag);
begin
  inherited;
  FOldSrc := FActiveSrc;

  AHTMLTag := TIWHTMLTag.CreateTag('img');
  AHTMLTag.AddClassParam(ActiveCss);
  AHTMLTag.AddStringParam('id', AHTMLName);
  AHTMLTag.AddStringParam('style', ActiveStyle);
  AHTMLTag.AddStringParam('src', FActiveSrc);
  if AltText <> '' then
    AHTMLTag.AddStringParam('alt', AltText, True)
  else
    AHTMLTag.AddStringParam('alt', FActiveSrc, True);
  if not AutoSize then begin
    AHTMLTag.AddIntegerParam('width', Width);
    AHTMLTag.AddIntegerParam('height', Height);
  end;
  if not Enabled then
    AContext.AddToInitProc('setEnabled("' + HTMLName + '", false);');
end;

procedure TIWBSImage.InternalRenderStyle(AStyle: TStringList);
begin
  inherited;
  if Assigned(FOnAsyncClick) and (Cursor = crAuto) then
    AStyle.Values['cursor'] := 'pointer';
end;
{$endregion}

end.
