unit Mainm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, StrUtils,
  System.JSON, Math, System.IOUtils,
  Controls, Forms, uniGUITypes, uniGUIAbstractClasses, DBAccess, MyAccess,
  uniGUIClasses, uniGUImClasses, uniGUIRegClasses, uniGUIForm, uniGUImForm,
  uniGUImJSForm,
  uniGUIBaseClasses, uniPanel, uniHTMLFrame, uniBasicGrid, uniDBGrid,
  unimDBListGrid, unimDBGrid, unimPanel, unimHTMLFrame, uSettings, Web.HTTPApp,
  Data.DB, MemDS, Vcl.Imaging.pngimage, uniImage, unimImage;

type
  TQREquipAction = (qraNone, qraService, qraStart, qraStop, qraBlock);

  TEquipAction = (eqaStart, eqaStop);

  TEquipFixStatus = (efsNone, efsFixBegin, efsFixEnd);

  TUserMode = (umNone, umAdmin, umPrint, umBlock, umOTP, umLegacy);

  TPersonWorkflowStatus = (pwsNone, pwsStarted, pwsFinished);

  TQRData = record
    UserId: string;
    EquipId: string;
    RollId: string;
    OrderId: string;
    BlockId: Integer;
    RawBlockId: string;
    Action: TQREquipAction;
    ActionCode: string;
    IsValid: Boolean;
    class function Parse(const ARawData: string): TQRData; static;
  end;

  TRollStatusInfo = record
    StatusId: Integer;
    StatusName: string;
    IsFinished: Boolean;
  end;

  TMainmForm = class(TUnimForm)
    pnlScan: TUnimPanel;
    qryRashodnik: TMyQuery;
    qryEquipment: TMyQuery;
    qryEquipServiceList: TMyQuery;
    qryStatusMap: TMyQuery;
    qryUpdateStatus: TMyQuery;
    qryRollInfo: TMyQuery;
    qryPresonName: TMyQuery;
    qryEquipName: TMyQuery;
    qryGetStatus: TMyQuery;
    qryLastRollStatus: TMyQuery;
    qryProfName: TMyQuery;
    qryRollBlockInfo: TMyQuery;
    qryUpdRollBlockInfo: TMyQuery;
    qryBlocksWorkflowInfo: TMyQuery;
    qryUpdBlocksWorkflow: TMyQuery;
    qryLastRollBlockInfo: TMyQuery;
    imgBg: TUnimImage;
    qryEquipFixList: TMyQuery;
    qryEquipFixStatuses: TMyQuery;
    procedure pnlScanAjaxEvent(Sender: TComponent; EventName: string;
      Params: TUniStrings);
    procedure UnimFormCreate(Sender: TObject);
    procedure UnimFormAjaxEvent(Sender: TComponent; EventName: string;
      Params: TUniStrings);
  private
    FSettings: TSettings;
    FConnection: TMyConnection;
    FQRUserId, FPersonFio, FPersonProfName: string;
    FPersonProfId: Integer;
    FUserMode: TUserMode;
    FMadUser, FRollMode, FEquipMode, FMadPrinter: Boolean;
    FCurrentRollId, FCurrentUniqRollID, FCurrentOrderId, FCurrentEquipId, FCurrentEquipName: string;
    FLastRollAction, FCurrentBlockId: Integer;
    FLastRollIsFinished, FBlockIsAssignedBegin, FBlockIsAssignedEnd,
      FBlocksWorkflowIsStarted: Boolean;
    FCurrentEquipAction, FCurrentEquipActionPrefix, FFixComment: string;
    FRollInfoJson, FRollStatusJson, FBlockInfoJson, FEquipFixListJson,
     FEquipFixStatusesJson: string;
    FIsAfterLogin: Boolean;
    FRashodnikId, FFixId, FServiceTab: Integer;
    FInfoMode, FBlockMode, FBlockAssignMode, FBlockWorkflowMode: Boolean;
    procedure FastExecSql(ASQL: string);
    procedure FastShowCustomScanner;
    procedure FastShowInitScanner;
    procedure FastShowEquipServicePanel;
    procedure FastShowEquipFixPanel;
    procedure HandleScanSuccess(const ACode, AMode, ASubMode: string);
    procedure DoServiceAction(const AEquipId: string);
    procedure SetMadStatus(const AStatusType: string; AEnabled: Boolean);
    procedure UpdateInfoBadge(const AText: string);
    procedure ResetChainState;
    function GetUserMode(const AUserId: string): TUserMode;
    procedure SetHTMLNodeText(ANodeName, AText: string);
    procedure SetElementText(const AID, AText: string);
    procedure SetRollCaption(AText: string);
    procedure SetEquipCaption(AText: string);
    procedure SetInfoMode;
    procedure ReSetInfoMode;
    procedure SetBlockAssignMode(ABeginAssign: Boolean);
    procedure SetBlockWorkflowMode(ABegin: Boolean);
    //procedure ReSetBlockAssignMode;
    procedure RollCompleteEffect;
    procedure UpdateEquipService(AParams: TUniStrings);
    procedure UpdateEquipFix(AParams: TUniStrings);
    procedure ToggleCamera(AOnOff: Boolean);
    //procedure ShowInfoPanel(ATableDataJson: string);
    procedure SetNodeStatus(AStatus: string; ANodeName: string);
    procedure SetElementSvg(const AID, ASvgCode: string);
    procedure RollActionButtons(ABeginBtn, AEndBtn: Boolean);
    procedure ShowProcessPanel(AShow: Boolean);
    procedure ShowAddInfoPanel;
    procedure HideAddInfoPanel;
    procedure EquipStatusOn;
    procedure EquipStatusOff;
    procedure RollStatusOn;
    procedure RollStatusOff;
    procedure BlockModeOn;
    procedure BlockModeOff;
    procedure BlockWorkFlowModeOn;
    procedure BlockWorkFlowModeOff;
    function EquipEventToRollStatus(AEventActionId: Integer): Integer;
    function GetRollInfo(ARollId, AOrderId: Integer; ARollFullId: string): string;
    function GetBlockInfo(ABlockId: Integer; ARollUniqId: String = ''): string;
    function GetBlockWorkflowInfo(AEquipId: string; ABlockId: string = ''): string;
    procedure LoadDataToInfoTable(ARollInfoDataJson: string);
    function IsValidUser(AQRUserId: string): Boolean;
    function GetEquipName(AEqipId: string):string;
    procedure UpdateRollSataus(ARollUniqId, ARollPerson, AEquipId: string; ARollStatus, ARollOrderId: Integer);
    procedure UpdateBlockAssignInfo(ABlockId: Integer; AUniqRollId: string; AIsBegin: Boolean);
    procedure UpdateBlockWorkflow(AEquipId, ABlockId: string; AIsFinished: Boolean);
    procedure GetRollStatus(AEquipId: string);
    function GetPersonProf: Boolean;
    function IsRollFinished: Boolean;
    //function IsLastRollFinished(AEquipId, AUnicRollId: string): Boolean;
    //function IsDataMatrixEnabled: Boolean;
    //function IsLastBlockAssigned: Boolean;
    procedure CheckIsLocalAccess;
    procedure SetWorkflowCaption(ACaption: string);
    procedure GetEquipFixList(AEquipId: string);
    procedure UpdatePersonWorkflow(AStatus: TPersonWorkflowStatus);
  end;

  TDatasetHelper = class helper for TMyQuery
    function ToJSON(const AFields: TArray<string> = []): string;
  end;

function MainmForm: TMainmForm;

implementation

{$R *.dfm}

uses
  uniGUIVars, MainModule, uniGUIApplication, uJsGUI;

const
  ICON_PATH = '/files/src-media/ico.png';
  JSON_EMPTY = '[]';
  ACCESS_RIGHTS = '67:madsticker;61:smola;1:smola';
  QR_SERVICE_CODE = 's';
  QR_CODE_VAL_DELIM = '*';
  QR_CODE_USER_DELIM = 'p';
  QR_CODE_EQID_DELIM = 'e';
  QR_CODE_ROLL_DELIM = 'r';
  QR_CODE_BLOCK_DELIM = 'b';

  QR_CODE_ACTION_START = '1';
  QR_CODE_ACTION_STOP = '0';

  QR_CODE_PRINT_START = '21';
  QR_CODE_PRINT_STOP = '20';

  INSERT_EQUIP_SERVICE_LIST_SQL =
    'INSERT INTO EquipmentServiceList (equipmentId, rashodnikId, serviceDate) ' +
    'VALUES (''%s'', %d, %s)';

  INSERT_EQUIP_FIX_LIST_SQL = 'INSERT INTO equipment_fix_list (equip_id, equip_fix_id, datecreate, comment) ' +
    'VALUES (''%s'', %d, NOW(), ''%s'')';

  INSERT_PERSON_WORKFLOW_STATUS = 'INSERT INTO person_workflow (person_id, status, datecreate) ' +
    'VALUES (''%s'', %d, NOW())';

  LAST_ERROR_ROLL_UPDATE_SQL =
    'UPDATE rolls_workflow rw' +
    'LEFT JOIN roll_statuses rs ON rs.roll_statuses_id = rw.roll_status' +
    'SET roll_status = roll_status + 1' +
    'WHERE rs.roll_statuses_equipment_event_id % 10 = 1 AND roll_unic_id = :rid AND roll_equipment_id <> :eqid' +
    'ORDER BY roll_date_time DESC' +
    'LIMIT 1';

  SVG_STICKER_BLOCK = '<svg viewBox="0 0 24 24" width="51" height="51" fill="none" stroke="currentColor" stroke-width="1.5">' +
    // Основная рамка (как в SVG_EQUIP)
    '<rect x="3" y="3" width="18" height="18" rx="2"/>' +
    // Внутренние стикеры 4x8 (пропорционально сетке 24x24)
    // Группа с заливкой, чтобы соответствовать стилю "наполнения"
    '<g fill="currentColor" stroke="none">' +
    // Ряд 1
    '<rect x="5" y="5" width="3" height="6" rx="0.5"/>' +
    '<rect x="10.5" y="5" width="3" height="6" rx="0.5"/>' +
    '<rect x="16" y="5" width="3" height="6" rx="0.5"/>' +
    // Ряд 2
    '<rect x="5" y="13" width="3" height="6" rx="0.5"/>' +
    '<rect x="10.5" y="13" width="3" height="6" rx="0.5"/>' +
    '<rect x="16" y="13" width="3" height="6" rx="0.5"/>' +
    '</g></svg>';

  SVG_EQUIP = '<svg viewBox="0 0 24 24" width="51" height="51" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M9 9h6v6H9zM9 1v3M15 1v3M9 20v3M15 20v3M20 9h3M20 15h3M1 9h3M1 15h3"/></svg>';
  SVG_ROLL = '<svg viewBox="0 0 24 24" width="51" height="51" fill="none" stroke="currentColor" stroke-width="1.5"><ellipse cx="12" cy="6" rx="8" ry="3"></ellipse><path d="M4 6v12c0 1.66 3.58 3 8 3s8-1.34 8-3V6"></path></svg>';

  DATAMATRIX_PROF_ID = 9;

procedure AddGyroRotation(APanel: TUnimPanel; AMaxDeg: Integer = 5);
var
  JS: string;
  PName: string;
begin
  PName := APanel.JSName;

  JS :=
    'try { ' +
    '  var pnl = ' + PName + '; ' +
    '  if (pnl && pnl.element) { ' +
         // Устанавливаем перспективу напрямую через JS метод компонента
    '    pnl.setStyle("perspective", "1000px"); ' +
    '    var el = pnl.element.dom; ' +
    '    el.style.transition = "transform 0.1s ease-out"; ' +
    '    el.style.transformStyle = "preserve-3d"; ' +

    '    var gyroHandler = function(event) { ' +
    '      var b = event.beta; ' + // Наклон вперед-назад
    '      var g = event.gamma; ' + // Наклон влево-вправо
    '      if (b !== null && g !== null) { ' +
    '        var max = ' + IntToStr(AMaxDeg) + '; ' +
    '        var rx = Math.max(-max, Math.min(max, (b / 5) * -1)); ' +
    '        var ry = Math.max(-max, Math.min(max, (g / 5) * -1)); ' +
    '        el.style.transform = "rotateX(" + rx + "deg) rotateY(" + ry + "deg)"; ' +
    '      } ' +
    '    }; ' +
         // Очистка старого обработчика и установка нового
    '    window.removeEventListener("deviceorientation", gyroHandler); ' +
    '    window.addEventListener("deviceorientation", gyroHandler); ' +
    '  } ' +
    '} catch (e) { console.error("Gyro Error: " + e.message); }';

  APanel.UniSession.AddJS(JS);
end;

procedure FadeOutAndDestroy(AImage: TUnimImage; ADurationMS: Integer = 500);
var
  JS: string;
begin
  // На всякий случай проверяем, существует ли объект
  if not Assigned(AImage) then Exit;

  JS :=
    'try { ' +
    '  var img = ' + AImage.JSName + '; ' +
    '  if (img && img.element) { ' +
    '    var el = img.element.dom; ' +
         // Устанавливаем стиль перехода для прозрачности
    '    el.style.transition = "opacity ' + IntToStr(ADurationMS) + 'ms ease-out"; ' +
    '    el.style.opacity = "0"; ' +

         // Ждем окончания анимации, затем удаляем объект
    '    setTimeout(function() { ' +
    '      if (img && typeof img.destroy === "function") { ' +
    '        img.destroy(); ' +
    '        console.log("Image destroyed"); ' +
    '      } ' +
    '    }, ' + IntToStr(ADurationMS) + '); ' +
    '  } ' +
    '} catch (e) { console.error("FadeOut Error: " + e.message); }';

  AImage.UniSession.AddJS(JS);
end;

procedure RegisterPWA(AIconPath: string);
begin
  UniSession.AddJS(
    'var origin = window.location.origin;' +
    'var manifest = {' +
    '  "short_name": "BadSticker",' +
    '  "name": "BadSticker",' +
    '  "icons": [{' +
    '    "src": origin + "'+AIconPath+'",' +
    '    "sizes": "512x512",' +
    '    "type": "image/png",' +
    '    "purpose": "any"' +
    '  }],' +
    '  "start_url": origin + "/",' +
    '  "display": "standalone",' +
    '  "background_color": "#ffffff",' +
    '  "theme_color": "#000000"' +
    '};' +
    'var manifestBlob = new Blob([JSON.stringify(manifest)], {type: "application/json"});' +
    'var manifestURL = URL.createObjectURL(manifestBlob);' +
    'var link = document.createElement("link");' +
    'link.rel = "manifest";' +
    'link.href = manifestURL;' +
    'document.head.appendChild(link);' +

    'var swCode = "self.addEventListener(''fetch'', function(e) { e.respondWith(fetch(e.request)); });";' +
    'var swBlob = new Blob([swCode], {type: "text/javascript"});' +
    'var swURL = URL.createObjectURL(swBlob);' +
    'if ("serviceWorker" in navigator) {' +
    '  navigator.serviceWorker.register(swURL, {scope: "/"});' +
    '}'
  );
end;


function GetSettingValue(const AKey: string; const AFileName: string = 'settings.set'): string;
var
  Lines: TArray<string>;
  Line: string;
  SeparatorPos: Integer;
  FullPath: string;
begin
  Result := '';
  FullPath := ExtractFilePath(ParamStr(0)) + AFileName;
  if not TFile.Exists(FullPath) then
    Exit;
  Lines := TFile.ReadAllLines(FullPath, TEncoding.UTF8);
  for Line in Lines do
  begin
    SeparatorPos := Pos('=', Line);
    if SeparatorPos > 0 then
    begin
      if SameText(Trim(Copy(Line, 1, SeparatorPos - 1)), AKey) then
      begin
        Result := Trim(Copy(Line, SeparatorPos + 1, MaxInt));
        Break;
      end;
    end;
  end;
end;

procedure TMainmForm.CheckIsLocalAccess;
var
  LImagePath: string;
begin
  LImagePath := GetSettingValue('PingPath', 'settings.set');
    UniSession.AddJS(
      'var img = new Image(); ' +
      'img.onload = function() { ' +
      '  ajaxRequest(' + Self.JSInterface.JSName + ', ''pingStatus'', [''status=OK'']); ' +
      '}; ' +
      'img.onerror = function() { ' +
      '  ajaxRequest(' + Self.JSInterface.JSName + ', ''pingStatus'', [''status=ERR'']); ' +
      '}; ' +
      'img.src = "' + StringReplace(LImagePath, '\', '/', [rfReplaceAll]) + '?t=' + IntToStr(GetTickCount) + '";'
    );
end;

function MainmForm: TMainmForm;
begin
  Result := TMainmForm(UniMainModule.GetFormInstance(TMainmForm));
end;

function Cookie(const AKey: string; const AValue: string = ''): string;
begin
  if AValue = '-' then
    UniApplication.Cookies.SetCookie(AKey, '', Date - 1)
  else if not AValue.IsEmpty then
    UniApplication.Cookies.SetCookie(AKey, AValue, Date + 180);
  Result := UniApplication.Cookies.GetCookie(AKey);
end;

procedure DestroyArkanoid(APanel: TUnimPanel);
begin
  UniSession.AddJS(APanel.JSName + '.destroyArkanoid()');
end;

class function TQRData.Parse(const ARawData: string): TQRData;
var
  LParts: TArray<string>;
begin
  Result.IsValid := False;
  Result.Action := qraNone;
  Result.UserId := '';
  Result.EquipId := '';
  Result.RollId := '';
  Result.OrderId := '';
  Result.BlockId := 0;
  Result.RawBlockId := '';

  if ARawData.Trim.StartsWith(QR_CODE_BLOCK_DELIM) then
  begin
    Result.BlockId := 0;
    TryStrToInt(ARawData.Substring(1).Replace(QR_CODE_BLOCK_DELIM, ''), Result.BlockId);
    Result.RawBlockId := ARawData.Trim;
    if Result.BlockId <> 0 then
      Result.Action := qraBlock;
    Result.IsValid := True;
  end
  else
  if ARawData.StartsWith(QR_CODE_USER_DELIM) then
  begin
    Result.UserId := ARawData.Substring(1);
    Result.IsValid := True;
  end
  else
  if ARawData.StartsWith(QR_CODE_ROLL_DELIM) then
  begin
    LParts := ARawData.Substring(1).Split([QR_CODE_VAL_DELIM]);
    Result.RollId := LParts[0];
    if Length(LParts) > 1 then
      Result.OrderId := LParts[1];
    Result.IsValid := True;
  end
  else
  if ARawData.Contains(QR_CODE_VAL_DELIM) then
  begin
    LParts := ARawData.Split([QR_CODE_VAL_DELIM]);
    if LParts[0] = QR_SERVICE_CODE then
    begin
      Result.Action := qraService;
      if (Length(LParts) > 1) and LParts[1].Contains(QR_CODE_EQID_DELIM) then
        Result.EquipId := LParts[1];
    end
    else
    begin
      if LParts[0].Contains(QR_CODE_EQID_DELIM) then
        Result.EquipId := LParts[0];
      if Length(LParts) > 1 then
      begin
        Result.ActionCode := LParts[1];
        if LParts[1].EndsWith(QR_CODE_ACTION_START) then
          Result.Action := qraStart
        else if LParts[1].EndsWith(QR_CODE_ACTION_STOP) then
          Result.Action := qraStop;
      end;
    end;
    Result.IsValid := not Result.EquipId.IsEmpty;
  end
  else if not ARawData.IsEmpty then
    Result.IsValid := True;
end;

procedure TMainmForm.SetElementText(const AID, AText: string);
begin
  // AID — это суффикс после LCID, например 'block_title' или 'btn_action_start'
  UniSession.AddJS(pnlScan.JSName + '.setElementText("' + AID + '", "' + AText + '");');
end;

procedure TMainmForm.SetEquipCaption(AText: string);
begin
  SetHTMLNodeText('eq', AText);
end;

procedure TMainmForm.SetRollCaption(AText: string);
begin
  SetHTMLNodeText('roll', AText);
end;

procedure TMainmForm.SetWorkflowCaption(ACaption: string);
begin
  SetElementText('block_end_title', ACaption);
end;

procedure TMainmForm.SetHTMLNodeText(ANodeName, AText: string);
begin
  UniSession.AddJS(pnlScan.JSName + '.setNodeText("'+ANodeName+'", "'+AText+'");');
end;

procedure TMainmForm.SetMadStatus(const AStatusType: string; AEnabled: Boolean);
var
  LCID, LColor, LOpacity: string;
begin
  LCID := pnlScan.JSName + '_status_' + AStatusType;
  if AEnabled then
  begin
    if AStatusType = 'user' then
      LColor := '#4ade80'
    else if AStatusType = 'equip' then
      LColor := '#60a5fa'
    else if AStatusType = 'start' then
      LColor := '#fbbf24'
    else
      LColor := '#f87171';
    LOpacity := '1';
  end
  else
  begin
    LColor := '#94a3b8';
    LOpacity := '0.3';
  end;
  UniSession.AddJS
    (Format('var e=document.getElementById("%s");if(e){e.style.color="%s";e.style.opacity="%s";}',
    [LCID, LColor, LOpacity]));
end;

procedure TMainmForm.SetNodeStatus(AStatus: string; ANodeName: string);
begin
  UniSession.AddJS(pnlScan.JSName + '.setNodeActive("'+ANodeName+'", '+AStatus+');');
end;

procedure TMainmForm.SetBlockWorkflowMode(ABegin: Boolean);
begin
  SetElementText('block_end_title', 'Работа с блоками');
  if not ABegin then
  begin
    RollActionButtons(True, False);
    SetElementText('btn_action_start', 'Начать');
    FBlockWorkflowMode := True;
  end
  else
  begin
    RollActionButtons(False, True);
    FBlockWorkflowMode := True;
  end;
end;

procedure TMainmForm.SetBlockAssignMode(ABeginAssign: Boolean);
begin
  SetElementText('block_end_title', 'Привязка блоков');
  if not ABeginAssign then
  begin
    RollActionButtons(True, False);
    SetElementText('btn_action_start', 'Начать');
  end
  else
  begin
    RollActionButtons(False, True);
  end;
  FBlockAssignMode := True;
end;

{
procedure TMainmForm.ReSetBlockAssignMode;
begin
  SetElementText('block_end_title', 'Статус рулона');
  FBlockAssignMode := False;
end;
}

procedure TMainmForm.ReSetInfoMode;
begin
  SetElementText('block_end_title', 'Работа с рулоном');
  SetElementText('btn_action_start', 'Начать');
  FInfoMode := False;
end;

procedure TMainmForm.SetInfoMode;
begin
  SetElementText('block_end_title', 'Инфо');
  SetElementText('btn_action_start', 'Показать');
  FInfoMode := True;
end;

procedure TMainmForm.UpdateBlockAssignInfo(ABlockId: Integer; AUniqRollId: string;
  AIsBegin: Boolean);
begin
  qryUpdRollBlockInfo.ParamByName('blockId').AsInteger := ABlockId;
  qryUpdRollBlockInfo.ParamByName('rollId').AsString := AUniqRollId;
  qryUpdRollBlockInfo.ParamByName('isBegin').AsInteger := IfThen(AIsBegin, 1, 0);
  qryUpdRollBlockInfo.ExecSQL;
  GetBlockInfo(ABlockId);
end;

procedure TMainmForm.UpdateBlockWorkflow(AEquipId, ABlockId: string;
  AIsFinished: Boolean);
begin
  qryUpdBlocksWorkflow.Close;
  qryUpdBlocksWorkflow.ParamByName('eid').AsString := AEquipId;
  qryUpdBlocksWorkflow.ParamByName('bid').AsString := ABlockId;
  qryUpdBlocksWorkflow.ParamByName('fin').AsInteger := Integer(AIsFinished);
  qryUpdBlocksWorkflow.ParamByName('bp').AsString := Concat(QR_CODE_USER_DELIM, FQRUserId);
  qryUpdBlocksWorkflow.ParamByName('date').AsDateTime := Now;
  qryUpdBlocksWorkflow.ExecSQL;
end;

procedure TMainmForm.UpdateEquipService(AParams: TUniStrings);
begin
  qryRashodnik.Locate('id', AParams['id'].Value, []);
  FRashodnikId := qryRashodnik.FieldByName('id').AsInteger;
  FastExecSQL(Format(INSERT_EQUIP_SERVICE_LIST_SQL, [FCurrentEquipId, FRashodnikId, QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now))]));
end;

procedure TMainmForm.UpdateEquipFix(AParams: TUniStrings);
begin
  FFixId := AParams['id'].AsInteger;
  FastExecSQL(Format(INSERT_EQUIP_FIX_LIST_SQL, [FCurrentEquipId, FFixId, FFixComment]));
end;

procedure TMainmForm.UpdateInfoBadge(const AText: string);
begin
  UniSession.AddJS
    (Format('var e=document.getElementById("%s_info_badge");if(e)e.innerText="%s";',
    [pnlScan.JSName, AText]));
end;

procedure TMainmForm.UpdatePersonWorkflow(AStatus: TPersonWorkflowStatus);
begin
  FConnection.ExecSQL(Format(INSERT_PERSON_WORKFLOW_STATUS, [Concat(QR_CODE_USER_DELIM, FQRUserId), Ord(AStatus)]));
end;

procedure TMainmForm.UpdateRollSataus(ARollUniqId, ARollPerson,
  AEquipId: string; ARollStatus, ARollOrderId: Integer);
begin
  qryUpdateStatus.ParamByName('rid').AsString := Concat(QR_CODE_ROLL_DELIM, ARollUniqId, QR_CODE_VAL_DELIM, ARollOrderId.ToString);
  qryUpdateStatus.ParamByName('rpers').AsString := ARollPerson;
  qryUpdateStatus.ParamByName('reqid').AsString := AEquipId;
  qryUpdateStatus.ParamByName('rstat').AsInteger := ARollStatus;
  qryUpdateStatus.ParamByName('rordid').AsInteger := ARollOrderId;
  qryUpdateStatus.ParamByName('rdate').AsDateTime := Now;
  qryUpdateStatus.ExecSQL;
  GetRollStatus(AEquipId);
end;

procedure TMainmForm.LoadDataToInfoTable(ARollInfoDataJson: string);
begin
  UniSession.AddJS(pnlScan.JSName + '.renderTable(''' + ARollInfoDataJson + ''');');
end;

procedure TMainmForm.ShowAddInfoPanel;
begin
  SetSidePanelState(True)
end;

procedure TMainmForm.HideAddInfoPanel;
begin
  SetSidePanelState(False)
end;

{
procedure TMainmForm.ShowInfoPanel(ATableDataJson: string);
begin
  UniSession.AddJS(pnlScan.JSName + '.renderTable(''' + ATableDataJson + ''');');
end;
}

procedure TMainmForm.ShowProcessPanel(AShow: Boolean);
begin
  UniSession.AddJS(pnlScan.JSName + '.showProcessPanel('+ IfThen(AShow, 'true', 'false') +');');
end;

procedure TMainmForm.ToggleCamera(AOnOff: Boolean);
begin
  UniSession.AddJS(pnlScan.JSName + '.toggleCam('+ IfThen(AOnOff, 'true', 'false') +');');
end;

{ TMainmForm }
procedure TMainmForm.UnimFormCreate(Sender: TObject);

  procedure RegisterFormReady;
  begin
    JSInterface.JSAddListener(
      'painted',
      'function(sender){ setTimeout(function(){ if (sender && sender.nm) ajaxRequest(sender, "FormReady", []); }, 222); }'
    );
  end;

begin
  FSettings := TSettings.Create;
  try
    FSettings.ReadSettingsFromIni;
    FConnection := TMyConnection.Create(Self);
    FConnection.Database := FSettings.sDatabaseName;
    FConnection.Server := FSettings.sDatabaseServerPath;
    FConnection.Username := GetSettingValue('username');
    FConnection.Password := GetSettingValue('password');
    FConnection.Port := 3307;
    FConnection.LoginPrompt := False;
    qryRashodnik.Connection := FConnection;
    qryEquipServiceList.Connection := FConnection;
    qryEquipment.Connection := FConnection;
    qryRollInfo.Connection := FConnection;
    qryEquipName.Connection := FConnection;
    qryPresonName.Connection := FConnection;
    qryStatusMap.Connection := FConnection;
    qryUpdateStatus.Connection := FConnection;
    qryGetStatus.Connection := FConnection;
    qryLastRollStatus.Connection := FConnection;
    qryProfName.Connection := FConnection;
    qryRollBlockInfo.Connection := FConnection;
    qryUpdRollBlockInfo.Connection := FConnection;
    qryBlocksWorkflowInfo.Connection := FConnection;
    qryUpdBlocksWorkflow.Connection := FConnection;
    qryLastRollBlockInfo.Connection := FConnection;
    qryEquipFixList.Connection := FConnection;
    qryEquipFixStatuses.Connection := FConnection;
    RegisterFormReady;
  finally
    FSettings.Free;
  end;
  RegisterPWA(ICON_PATH);
  CheckIsLocalAccess;
end;

procedure TMainmForm.UnimFormAjaxEvent(Sender: TComponent; EventName: string;
  Params: TUniStrings);
begin
  if EventName = 'pingStatus' then
  begin
    if Params['status'].AsString.Equals('ERR') then
    begin
      Toast('Доступ вне работы <br> <br> ЗАПРЕЩЕН <br> <br> Не балуйся 🤡', alClient);
      MainmForm.Color := clBlack;
      pnlScan.Visible := False
    end
    else
      FadeOutAndDestroy(imgBg, 2000);
  end
  else
  if EventName = 'FormReady' then
  begin
    FQRUserId := Cookie('_username');
    GetPersonProf;
    if not FQRUserId.IsEmpty and IsValidUser(FQRUserId) then
    begin
      FUserMode := GetUserMode(FQRUserId);
      ShowWorkTracker(pnlScan, '#000000', 'Cera Round', 'rgba(40, 40, 40, 0.9)', 5, 0.50);
      FastShowCustomScanner;
    end
    else
    begin
      FastShowInitScanner;
    end;
  end
  else if EventName = 'resetChain' then
    ResetChainState;
end;

procedure TMainmForm.ResetChainState;
begin
  FRollMode := False;
  FEquipMode := False;
  FMadPrinter := False;
  SetMadStatus('roll', False);
  SetMadStatus('start', False);
  SetMadStatus('stop', False);
  SetMadStatus('equip', False);
  UpdateInfoBadge('СОСТОЯНИЕ СБРОШЕНО');
end;

procedure TMainmForm.RollActionButtons(ABeginBtn, AEndBtn: Boolean);
begin
  UniSession.AddJS(pnlScan.JSName + '.setButtonsState('+ IfThen(ABeginBtn, 'true', 'false') +', '+   IfThen(AEndBtn, 'true', 'false') +');');
end;

procedure TMainmForm.RollCompleteEffect;
begin
  UniSession.AddJS(pnlScan.JSName + '.fireConfetti();');
end;

procedure TMainmForm.RollStatusOn;
begin
  SetNodeStatus('true', 'roll');
end;

procedure TMainmForm.RollStatusOff;
begin
  SetNodeStatus('false', 'roll');
end;

procedure TMainmForm.GetEquipFixList(AEquipId: string);
begin
  qryEquipFixList.Close;
  qryEquipFixList.ParamByName('eqId').AsString := AEquipId;
  qryEquipFixList.Open;
  qryEquipFixStatuses.Close;
  qryEquipFixStatuses.Open;
  FEquipFixListJson := qryEquipFixList.ToJSON(['equipment_name', 'name', 'datecreate']);
  qryEquipFixList.First;
  FFixId := qryEquipFixList.FieldByName('equip_fix_id').AsInteger;
  FEquipFixStatusesJson := qryEquipFixStatuses.ToJSON(['id', 'name']);
end;

function TMainmForm.GetEquipName(AEqipId: string): string;
begin
  qryEquipName.ParamByName('eqId').AsString := AEqipId;
  qryEquipName.Open;
  Result := qryEquipName.FieldByName('eqname').AsString;
end;

function TMainmForm.GetPersonProf: Boolean;
begin
  qryProfName.Close;
  qryProfName.ParamByName('pid').AsString := Concat(QR_CODE_USER_DELIM, FQRUserId);
  qryProfName.Open;
  Result := not qryProfName.IsEmpty;
  if Result then
  begin
    FPersonProfName := qryProfName.FieldByName('profName').AsString;
    FPersonProfId :=  qryProfName.FieldByName('profId').AsInteger;
  end;
end;

function TMainmForm.GetBlockInfo(ABlockId: Integer; ARollUniqId: String = ''): string;
begin
  qryRollBlockInfo.Close;
  qryRollBlockInfo.ParamByName('blockId').AsInteger := ABlockId;
  qryRollBlockInfo.Open;
  qryLastRollBlockInfo.Close;
  qryLastRollBlockInfo.ParamByName('ruid').AsString := ARollUniqId;
  qryLastRollBlockInfo.Open;
  FBlockIsAssignedBegin := qryLastRollBlockInfo.FieldByName('fbid').AsInteger > 0;
  FBlockIsAssignedEnd := qryLastRollBlockInfo.FieldByName('lbid').AsInteger > 0;
  Result := qryRollBlockInfo.ToJSON(['Рулон', 'Заказ', 'Диапазон']);
end;

function TMainmForm.GetBlockWorkflowInfo(AEquipId: string; ABlockId: string = ''): string;
begin
  qryBlocksWorkflowInfo.Close;
  qryBlocksWorkflowInfo.ParamByName('eid').AsString := AEquipId;
  qryBlocksWorkflowInfo.ParamByName('bid').AsString := ABlockId;
  qryBlocksWorkflowInfo.Open;
  // Если ид блока пустой, значит ищем инф по последней записи на данном оборудовании
  FBlocksWorkflowIsStarted := not qryBlocksWorkflowInfo.IsEmpty;
  if not qryBlocksWorkflowInfo.IsEmpty then
  begin
    FBlocksWorkflowIsStarted := not qryBlocksWorkflowInfo.FieldByName('finished').AsBoolean;
  end;
end;

function TMainmForm.GetRollInfo(ARollId, AOrderId: Integer; ARollFullId: string): string;
begin
  qryRollInfo.Close;
  qryRollInfo.ParamByName('rolls_in_orders_roll_id').AsString := ARollFullId;
  qryRollInfo.ParamByName('parent_id').AsInteger := ARollId;
  qryRollInfo.ParamByName('order_id').AsInteger := AOrderId;
  qryRollInfo.Open;
  Result := qryRollInfo.ToJSON(['Код', 'Артикул', 'Имя', 'Кол-во', 'Название заказа', 'Дата создания', 'Кол-во блоков']);
end;

procedure TMainmForm.GetRollStatus(AEquipId: string);
begin
  qryGetStatus.Close;
  qryGetStatus.ParamByName('eqid').AsString := AEquipId;
  qryGetStatus.Open;
  FLastRollAction := IfThen(qryGetStatus.RecordCount > 0, qryGetStatus.FieldByName('roll_status').AsInteger, 0);
  FLastRollIsFinished := qryGetStatus.FieldByName('finished').AsInteger = 1;
  FRollStatusJson := qryGetStatus.ToJSON(['Статус', 'Оборудование', 'Оператор', 'Дата']);
end;

function TMainmForm.GetUserMode(const AUserId: string): TUserMode;
//var
//  LRights: TArray<string>;
//  R: string;
begin
  Result := umAdmin;
//  LRights := ACCESS_RIGHTS.Split([';']);
//  for R in LRights do
//    if R.StartsWith(AUserId + ':') then
//    begin
//      Result := R.Split([':'])[1];
//      Break;
//    end;
end;

procedure TMainmForm.FastShowInitScanner;
begin
  uJsGUI.ShowCustomScanner(pnlScan, 'Вход: отсканируйте пропуск', '#989FC0',
    'Cera Round', 'white', '#556890', 17, 'login');
  AddArkanoidToPanel(pnlScan);
  FIsAfterLogin := True;
end;

procedure TMainmForm.FastExecSql(ASQL: string);
begin
  FConnection.StartTransaction;
  FConnection.ExecSQL(ASQL);
  FConnection.Commit;
end;

procedure TMainmForm.FastShowCustomScanner;
begin
  uJsGUI.ShowCustomScanner(pnlScan, Format('%s (%s)', [FPersonFio, IfThen(FPersonProfName.IsEmpty, '🤡', FPersonProfName)]),
    '#989FC0', 'Cera Round', 'white', '#556890', 17);
  if FIsAfterLogin then
    DestroyArkanoid(pnlScan);
end;

procedure TMainmForm.FastShowEquipServicePanel;
begin
  ShowServicePanel(pnlScan, qryEquipServiceList.ToJSON(['equipment_name',
    'name', 'serviceDate']), qryRashodnik.ToJSON(['id', 'name']), '#989FC0',
    'Cera Round', 'white', FCurrentEquipName, '#343F50');
end;

procedure TMainmForm.FastShowEquipFixPanel;
begin
  GetEquipFixList(FCurrentEquipId);
  ShowServicePanel(pnlScan, FEquipFixListJson, FEquipFixStatusesJson, '#989FC0',
    'Cera Round', 'white', FCurrentEquipName, '#343F50', 1);
end;

procedure TMainmForm.pnlScanAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);

  procedure RollComplete;
  begin
    ShowProcessPanel(True);
    RollStatusOff;
    EquipStatusOff;
    SetRollCaption('-');
    SetEquipCaption('-');
    ToggleCamera(True);
    FRollMode := False;
    FEquipMode := False;
  end;

  procedure AfterStart;
  begin
    RollStatusOff;
    EquipStatusOff;
    SetRollCaption('-');
    SetEquipCaption('-');
    ToggleCamera(False);
    FRollMode := False;
    FEquipMode := False;
    FBlockMode := False;
  end;

  procedure AterInfo;
  begin
    ShowAddInfoPanel;
    ToggleCamera(False);
    BlockModeOff;
    EquipStatusOff;
    RollStatusOff;
    SetRollCaption('-');
    SetEquipCaption('-');
    FCurrentRollId := EmptyStr;
    FCurrentEquipName := EmptyStr;
    FCurrentBlockId := 0;
    FInfoMode := False;
    FRollMode := False;
    FEquipMode := False;
  end;

begin
  if EventName = 'workFinished' then
  begin
    UpdatePersonWorkflow(pwsFinished);
  end
  else
  if EventName = 'workStarted' then
  begin
    UpdatePersonWorkflow(pwsStarted);
  end;
  if EventName = 'tabChanged' then
  begin
    FServiceTab := Params['index'].AsInteger;
    if FServiceTab = 0 then
      FastShowEquipServicePanel
    else
      FastShowEquipFixPanel
  end
  else
  if EventName = '_camLongPress' then
    // сброс после долгого нажатия
    AfterStart
  else
  if EventName = 'scanSuccess' then
  begin
    HandleScanSuccess(Params['code'].Value, Params['mode'].Value, Params['submode'].Value);
  end
  else
  if EventName = 'exitScanner' then
  begin
    Cookie('_username', '-');
    FQRUserId := '';
    FastShowInitScanner;
    DestroyWorkTracker(pnlScan);
  end
  else
  if EventName = 'resetChain' then
    ResetChainState
  else
  if EventName = 'itemAdded' then
  begin
    if FServiceTab = 0 then
    begin
      UpdateEquipService(Params);
      ToggleCamera(False);
    end
    else
    begin
      UpdateEquipFix(Params);
      ToggleCamera(True);
    end;
  end
  else
  if EventName = 'reqTab' then
  begin
    case Params['tab'].AsInteger of
      1:
        begin
          LoadDataToInfoTable(FRollInfoJson);
        end;
      2:
        begin;
          LoadDataToInfoTable(FRollStatusJson);
        end;
    end;
  end
  else
  // принудительное закрытие
  if EventName = 'actionEndForce' then
  begin
    RollComplete
  end
  else
  // обычное закрытие
  if EventName = 'actionEndNormal' then
  begin
    if FBlockAssignMode then
    begin
      UpdateBlockAssignInfo(FCurrentBlockId, FCurrentUniqRollID, False);
      FBlockAssignMode := False;
      FBlockMode := False;
    end
    else
    if FBlockWorkflowMode then
    begin
      UpdateBlockWorkflow(FCurrentEquipId, Concat(QR_CODE_BLOCK_DELIM, FCurrentBlockId.ToString), True);
      FBlockWorkflowMode := False;
      BlockWorkFlowModeOff;
    end
    else
    begin
      if not FEquipMode then
      begin
        ToggleCamera(False);
        ShowMessage('Вы действительно хотите завершить не начатый рулон?' + #13#10 +' Тогда зажмите и держите кнопку "закончить"');
        Exit;
      end;
      UpdateRollSataus(FCurrentRollId, Concat(QR_CODE_USER_DELIM, FQRUserId), FCurrentEquipId,
        EquipEventToRollStatus(FCurrentEquipAction.ToInteger - 1), FCurrentOrderId.ToInteger);
    end;
    RollCompleteEffect;
    RollComplete;
    ToggleCamera(False);
  end
  else
  // "начать" рулет; если FInfoMode, обаратываем нажатие на кнопку Начать как отображение информации
  if EventName = 'actionStart' then
  begin
    if FInfoMode then
    begin
      AterInfo
    end
    else
    if FBlockAssignMode then
    begin
      UpdateBlockAssignInfo(FCurrentBlockId, FCurrentUniqRollID, True);
      AfterStart;
    end
    else
    if FBlockWorkflowMode then
    begin
      UpdateBlockWorkflow(FCurrentEquipId, Concat(QR_CODE_BLOCK_DELIM, FCurrentBlockId.ToString), False);
      AfterStart;
      BlockWorkFlowModeOff;
    end
    else
    begin
      RollActionButtons(False, True);
      UpdateRollSataus(FCurrentRollId, Concat(QR_CODE_USER_DELIM, FQRUserId), FCurrentEquipId,
        EquipEventToRollStatus(FCurrentEquipAction.ToInteger), FCurrentOrderId.ToInteger);
      AfterStart;
    end;
    ToggleCamera(False);
  end
  else
  if EventName = 'srvPanelClosed' then
  begin
    ToggleCamera(False);
  end
  else
  if (EventName = 'camStubClick') and (not FCurrentRollId.IsEmpty) and (not FCurrentEquipName.IsEmpty) then
  begin
    RollComplete;
    FRollInfoJson := '{[]}';
    FRollStatusJson := '{[]}';
  end
  else
  if EventName = 'camStubClick' then
  begin
    ToggleCamera(True);
  end
  else if EventName = 'sheetClosed' then
  begin
    HideAddInfoPanel;
  end;
end;

procedure TMainmForm.HandleScanSuccess(const ACode, AMode, ASubMode: string);

  procedure RunBlockWork;
  begin
    FInfoMode := False;
    BlockWorkFlowModeOn;
    SetRollCaption('БЛОК: №' + FCurrentBlockId.ToString);
    SetEquipCaption(FCurrentEquipName);
    GetBlockWorkflowInfo(FCurrentEquipId);
    SetBlockWorkflowMode(FBlocksWorkflowIsStarted);
    Exit;
  end;

var
  LQR: TQRData;
  LMode: TUserMode;
begin
  LQR := TQRData.Parse(ACode);
  if FQRUserId.IsEmpty then
  begin
    if not LQR.UserId.IsEmpty then
    begin
      LMode := GetUserMode(LQR.UserId);
      LQR.IsValid := IsValidUser(LQR.UserId);
      if LQR.IsValid then
      begin
        FQRUserId := LQR.UserId;
        GetPersonProf;
        FUserMode := LMode;
        Cookie('_username', FQRUserId);
        ShowWorkTracker(pnlScan, '#000000', 'Cera Round', 'rgba(40, 40, 40, 0.9)', 5, 0.50);
        FastShowCustomScanner;
      end
      else
        Toast('Доступ запрещен. Ты что хакер? 😡');
    end
    else
      ShowMessage('Ошибка: Требуется код сотрудника (p)');
    Exit;
  end;
  { MadSticker Mode Logic }
  if FUserMode > umNone then
  begin
    { 1. User Flip-Flop }
    if (LQR.UserId = FQRUserId) then
    begin
      ShowProcessPanel(True);
      FMadUser := not FMadUser;
      SetMadStatus('user', FMadUser);
      if FMadUser then
        UpdateInfoBadge('ЮЗЕР: ' + FQRUserId)
      else
        ResetChainState;
      Exit;
    end;
    { 2. Roll Scan }
    if not LQR.RollId.IsEmpty then
    begin
      FCurrentRollId := LQR.RollId;
      FCurrentOrderId := LQR.OrderId;
      FCurrentUniqRollId := Concat(QR_CODE_ROLL_DELIM, FCurrentRollId, QR_CODE_VAL_DELIM, FCurrentOrderId);
      FRollInfoJson := GetRollInfo(0, 0, FCurrentUniqRollId);
      if FRollInfoJson.Equals(JSON_EMPTY) then
      begin
        uJsGUI.Toast('Рулон не найден');
        ToggleCamera(False);
        Exit;
      end;
      SetRollCaption('РУЛОН: №' + FCurrentRollId);
      RollStatusOn;
      FRollMode := True;
      SetMadStatus('roll', True);
      UpdateInfoBadge('РУЛОН: №' + FCurrentRollId + ' (ЗАКАЗ: ' + FCurrentOrderId + ')');
      RollActionButtons(True, False);
      SetInfoMode;
      LoadDataToInfoTable(FRollInfoJson);
      FBlockMode := False;
    end;
    if LQR.Action = qraBlock then
    begin
      FCurrentBlockId := LQR.BlockId;
      FBlockMode := True;
      if LQR.BlockId = 0 then
      begin
        ShowMessage('Не верный формат кода для блока');
        Exit;
      end;
      FBlockInfoJson := GetBlockInfo(FCurrentBlockId);
      // Если отсканировали оборудования и блок, то значит предпологается работа с блоком
      if FBlockInfoJson.Equals(JSON_EMPTY) and not FEquipMode and not FRollMode then
      begin
        uJsGUI.Toast('Блок не найден');
        ToggleCamera(False);
      end
      else
      if not FEquipMode then
      begin
        BlockModeOn;
        SetEquipCaption('БЛОК: №' + FCurrentBlockId.ToString);
        SetInfoMode;
        RollActionButtons(True, False);;
        //FEquipMode := False;
        LoadDataToInfoTable(FBlockInfoJson);
        FBlockInfoJson := '';
      end;
      if FEquipMode then
        RunBlockWork;
    end;
    if (LQR.Action = qraStart) or (LQR.Action = qraStop) then
    begin
      if FEquipMode then
        Exit; { Защита от дублей в журнале }
      FEquipMode := True;
      SetElementSvg('node_eq', SVG_EQUIP);
      FCurrentEquipAction := LQR.ActionCode;
      EquipEventToRollStatus(FCurrentEquipAction.ToInteger - 1);
      FCurrentEquipId := LQR.EquipId;
      GetEquipFixList(FCurrentEquipId);
      if FFixId = Ord(efsFixBegin) then
      begin
        Toast('Оборудование в ремонте');
        FBlockMode := False;
        ToggleCamera(False);
        FFixId := 0;
        Exit;
      end;
      FCurrentEquipName := GetEquipName(FCurrentEquipId);
      SetEquipCaption(FCurrentEquipName);
      RollActionButtons(True, False);
      SetInfoMode;
      UpdateInfoBadge('СТАРТ: ' + FCurrentEquipId + ' | РУЛОН: ' + FCurrentRollId);
      EquipStatusOn;
      GetRollStatus(FCurrentEquipId);
      LoadDataToInfoTable(FRollStatusJson);
      if FBlockMode then
        RunBlockWork;
    end;
    if FEquipMode and FRollMode then
    begin
      if not IsRollFinished then
        RollActionButtons(False, True)
      else
      begin
        RollActionButtons(True, False)
      end;
      EquipStatusOn;
      SetEquipCaption(FCurrentEquipName);
      ReSetInfoMode;
      SetWorkflowCaption(FCurrentEquipActionPrefix);
      FRollMode := False;
      FBlockMode := False;
      Exit;
    end;

    if FRollMode and FBlockMode then
    begin
      GetBlockInfo(FCurrentBlockId, FCurrentUniqRollID);
//      if IsLastBlockAssigned then
//      begin
//        uJsGUI.Toast('Рулон уже связан');
//      end
//      else
      {
      if FBlockEndLessThanBegin then
      begin
        uJsGUI.Toast('Номер конечного блока не может быть меньше начального 🤣');
      end
      else
      }
      begin
        SetBlockAssignMode(FBlockIsAssignedBegin);
        FInfoMode := False;
        Exit;
      end;
      FRollMode := False;
      FBlockMode := False;
      RollStatusOff;
      EquipStatusOff;
      SetRollCaption('-');
      SetEquipCaption('-');
      Exit;
    end;

    { 3. Service Block }
    if (LQR.Action = qraService) then
    begin
      FCurrentEquipId := LQR.EquipId;
      DoServiceAction(LQR.EquipId);
      Exit;
    end;
    Exit;
  end;

  if FUserMode = umLegacy then
  begin
    if LQR.Action = qraService then
    begin
      ShowMessage('Сервис доступен только в MadSticker');
      Exit;
    end;
    if not LQR.RollId.IsEmpty then
      UniSession.AddJS(pnlScan.JSName + '._updateHistory("РУЛОН: ' + LQR.RollId
        + ' (Заказ: ' + LQR.OrderId + ')");')
    else if not LQR.EquipId.IsEmpty then
      UniSession.AddJS(pnlScan.JSName + '._updateHistory("СТАНОК: ' +
        LQR.EquipId + ' | Действие: ' + IntToStr(Ord(LQR.Action)) + '");')
    else
      UniSession.AddJS(pnlScan.JSName + '._updateHistory("' + ACode + '");');
    Exit;
  end;
end;

{

function TMainmForm.IsDataMatrixEnabled: Boolean;
begin
  Result := FPersonProfId = DATAMATRIX_PROF_ID;
end;

}

{
function TMainmForm.IsLastBlockAssigned: Boolean;
begin
  Result := FBlockIsAssignedBegin
end;

}

{

function TMainmForm.IsLastRollFinished(AEquipId, AUnicRollId: string): Boolean;
begin
  Result := False;
  // 1. Сначала проверяем текущее состояние
  qryLastRollStatus.Close;
  qryLastRollStatus.ParamByName('rid').AsString := AUnicRollId;
  qryLastRollStatus.ParamByName('eqid').AsString := AEquipId;
  qryLastRollStatus.Open;
  if not qryLastRollStatus.IsEmpty then
  begin
    Result := qryLastRollStatus.FieldByName('finished').AsInteger = 1;
    if not Result then
    begin
      qryLastRollStatus.Connection.ExecSQL(LAST_ERROR_ROLL_UPDATE_SQL, [AUnicRollId, AEquipId]);
    end;
  end;
end;

}

function TMainmForm.IsRollFinished: Boolean;
begin
  Result := FLastRollIsFinished
end;

function TMainmForm.IsValidUser(AQRUserId: string): Boolean;
var
  LUserId: string;
begin
  qryPresonName.Close;
  LUserId := Concat(QR_CODE_USER_DELIM, AQRUserId);
  qryPresonName.ParamByName('person_id').AsString := LUserId;
  qryPresonName.Open;
  Result := qryPresonName.FieldByName('person_id').AsString = LUserId;
  if Result then
    FPersonFio := qryPresonName.FieldByName('person_fio').AsString;
end;

procedure TMainmForm.SetElementSvg(const AID, ASvgCode: string);
begin
  UniSession.AddJS(pnlScan.JSName + '.setElementSvg("' + AID + '", `' + ASvgCode + '`);');
end;

procedure TMainmForm.BlockModeOff;
begin
  EquipStatusOff;
  SetElementSvg('node_eq', SVG_EQUIP);
  FBlockMode := False;
end;

procedure TMainmForm.BlockModeOn;
begin
  EquipStatusOn;
  SetElementSvg('node_eq', SVG_STICKER_BLOCK);
end;

procedure TMainmForm.BlockWorkFlowModeOff;
begin
  RollStatusOff;
  SetElementSvg('node_roll', SVG_ROLL);
end;

procedure TMainmForm.BlockWorkFlowModeOn;
begin
  RollStatusOn;
  SetElementSvg('node_roll', SVG_STICKER_BLOCK);
  SetElementSvg('node_eq', SVG_EQUIP);
end;

procedure TMainmForm.DoServiceAction(const AEquipId: string);
begin
  qryEquipServiceList.Close;
  qryEquipServiceList.ParamByName('pEqId').AsString := AEquipId;
  qryEquipServiceList.Open;
  FCurrentEquipName := qryEquipServiceList.FieldByName('equipment_name').AsString;
  FCurrentEquipId := AEquipId;
  qryRashodnik.Close;
  qryRashodnik.ParamByName('pEqId').AsString := AEquipId;
  qryRashodnik.Open;
  GetEquipFixList(AEquipId);
  ShowServicePanel(pnlScan, qryEquipServiceList.ToJSON(['equipment_name',
    'name', 'serviceDate']), qryRashodnik.ToJSON(['id', 'name']), '#989FC0',
    'Cera Round', 'white', FCurrentEquipName, '#343F50');
  ToggleCamera(False);
end;

function TMainmForm.EquipEventToRollStatus(AEventActionId: Integer): Integer;
begin
  qryStatusMap.Close;
  qryStatusMap.ParamByName('rsEqId').AsInteger := AEventActionId;
  qryStatusMap.Open;
  FCurrentEquipActionPrefix := qryStatusMap.FieldByName('rsname').AsString;
  Result := qryStatusMap.FieldByName('rid').AsInteger;
end;

procedure TMainmForm.EquipStatusOn;
begin
  SetNodeStatus('true', 'eq');
end;

procedure TMainmForm.EquipStatusOff;
begin
  SetNodeStatus('false', 'eq');
end;

function TDatasetHelper.ToJSON(const AFields: TArray<string>): string;
var
  LJSONArray: TJSONArray;
  LJSONObject: TJSONObject;
  I: Integer;
  LFieldName: string;
begin
  LJSONArray := TJSONArray.Create;
  try
    DisableControls;
    try
      First;
      while not Eof do
      begin
        LJSONObject := TJSONObject.Create;
        if Length(AFields) = 0 then
          for I := 0 to FieldCount - 1 do
            LJSONObject.AddPair(Fields[I].FieldName, Fields[I].AsString)
        else
          for LFieldName in AFields do
            if Assigned(FindField(LFieldName)) then
              LJSONObject.AddPair(LFieldName, FindField(LFieldName).AsString);
        LJSONArray.AddElement(LJSONObject);
        Next;
      end;
    finally
      EnableControls;
    end;
    Result := LJSONArray.ToJSON;
  finally
    LJSONArray.Free;
  end;
end;

initialization

RegisterAppFormClass(TMainmForm);

end.


