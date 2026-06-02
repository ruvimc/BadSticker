unit uJsGUI;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, StrUtils,
  System.JSON, Math, System.IOUtils, System.NetEncoding, unimPanel, uniGUIApplication, Vcl.Controls;


procedure AddArkanoidToPanel(APanel: TUnimPanel);

procedure Toast(const AText: string; AAlign: TAlign = alBottom);
procedure SetSidePanelState(AOpen: Boolean);

procedure ShowServicePanel(APanel: TUnimPanel; const ADataJSON, AComboBoxJSON,
  ABgColor, AFontName, AFontColor, ACaption, ACaptionColor: string; AActiveTabIndex: Integer = 0);

procedure ShowCustomScanner(APanel: TUnimPanel;
  const ATitle, ABgColor, AFontName, AFontColor, AThemeColor: string;
  AFontSize: Integer; const AMode: string = ''; AScale: Double = 1.0; ARollInfoJson: string = '';
  ACurrentEquipId: string = ''; ACurrentRollId: string = ''; AScanAreaScale: Double = 0.50);

procedure ApplyScannerProfileConfig(APanel: TUnimPanel; const AJsonConfig: string;
  ARestartCamera: Boolean = True);
procedure SaveScannerProfileConfig(const AJsonConfig: string);
function LoadScannerProfileFromFile: string;
function ScannerProfileFilePath: string;

procedure ShowWorkTracker(APanel: TUnimPanel;
  const ABgColor, AFontName, APanelColor: string;
  AOffset: Integer; AScale: Double);

procedure DestroyWorkTracker(APanel: TUnimPanel);

implementation

procedure ShowWorkTracker(APanel: TUnimPanel;
  const ABgColor, AFontName, APanelColor: string;
  AOffset: Integer; AScale: Double);
var
  LJS, LCID: string;
  LScaleStr: string;
begin
  LCID := APanel.JSName + '_wtr';
  LScaleStr := FloatToStr(AScale).Replace(',', '.');

  LJS := Format(
    // Удаляем старую версию, если она была
    'var old=document.getElementById("%0:s_msk"); if(old)old.remove();' +

    // Внедряем стили
    'var style = document.createElement("style");' +
    'style.innerHTML = `' +
    // Маска (оверлей)
    '  .wtr-mask { position:fixed; top:0; left:0; width:100vw; height:100vh; background:rgba(0,0,0,0.8); backdrop-filter:blur(15px); z-index:999990; transition:all 0.5s ease; display:flex; justify-content:center; align-items:center; }' +
    '  .wtr-mask.hidden { background:rgba(0,0,0,0); backdrop-filter:blur(0px); pointer-events:none; }' +

    // Контейнер (Панель)
    '  .wtr-container { position:fixed; display:flex; align-items:center; transition:all 0.6s cubic-bezier(0.34, 1.56, 0.64, 1); z-index:999999; pointer-events:auto; box-sizing:border-box; }' +

    // Центрированное состояние (Старт)
    '  .wtr-container.centered { top:50%%; left:50%%; transform: translate(-50%%, -50%%) scale(1); flex-direction:column; gap:20px; background:transparent; border:none; box-shadow:none; }' +

    // Минимизированное состояние (Угол)
    '  .wtr-container.minimized { ' +
    '    top:%3:dpx; left:%3:dpx; transform: scale(%4:s); transform-origin: top left; ' +
    '    flex-direction:row; gap:18px; padding:8px 24px 8px 8px; ' + // Внутренние отступы для кнопки
    '    background:%2:s; border-radius:100px; ' +
    '    box-shadow:0 15px 40px rgba(0,0,0,0.4); border:1px solid rgba(255,255,255,0.1); ' +
    '  }' +

    // Кнопка (Сама геометрия)
    '  .wtr-btn { ' +
    '    width:160px; height:160px; border-radius:50%%; background:#10b981; color:white; ' +
    '    border:none; cursor:pointer; font-weight:800; font-family:%1:s; font-size:16px; ' +
    '    box-shadow:0 15px 30px rgba(16,185,129,0.3); ' +
    '    display:flex; align-items:center; justify-content:center; text-align:center; ' +
    '    text-transform:uppercase; letter-spacing:1px; outline:none; -webkit-tap-highlight-color:transparent; ' +
    '    /* Включаем GPU: */' +
    '    transform: translateZ(0); ' +
    '    will-change: transform, opacity; ' +
    '    backface-visibility: hidden; ' +
    '    /* Оптимизируем анимацию: */' +
    '    transition: transform 0.4s cubic-bezier(0.4, 0, 0.2, 1), background 0.4s ease; ' +
    '  }'  +

    '  .wtr-btn:active { transform: scale(0.95); }' +

    // Кнопка в свернутом виде (СТОП)
    '  .wtr-container.minimized .wtr-btn { ' +
    '    width:48px; height:48px; font-size:9px; background:#ef4444; ' +
    '    box-shadow:0 4px 12px rgba(239,68,68,0.3); flex-shrink:0; ' +
    '  }' +

    // Таймер
    '  .wtr-timer { color:white; font-family:%1:s; font-size:48px; font-weight:900; display:none; line-height:1; letter-spacing:-1px; }' +
    '  .wtr-container.minimized .wtr-timer { display:block; font-size:28px; }' +
    '`;' +
    'document.head.appendChild(style);' +

    // HTML структура
    'document.body.insertAdjacentHTML("beforeend", `' +
    '  <div id="%0:s_msk" class="wtr-mask">' +
    '    <div id="%0:s_cont" class="wtr-container centered">' +
    '      <button id="%0:s_btn" class="wtr-btn">Начать<br>работу</button>' +
    '      <div id="%0:s_tmr" class="wtr-timer">00:00:00</div>' +
    '    </div>' +
    '  </div>' +
    '`);' +

    'var msk=document.getElementById("%0:s_msk"), btn=document.getElementById("%0:s_btn"), ' +
    '    cont=document.getElementById("%0:s_cont"), tmr=document.getElementById("%0:s_tmr");' +
    'var interval = null;' +

    // Форматирование
    'function fmt(ms){ ' +
    '  var s=Math.floor(ms/1000), m=Math.floor(s/60), h=Math.floor(m/60);' +
    '  return [h, m%%60, s%%60].map(v=>v.toString().padStart(2,"0")).join(":");' +
    '};' +

    // Запуск интервала
    'function startTmr(startTime){' +
    '  if(interval) clearInterval(interval);' +
    '  interval = setInterval(()=>{' +
    '    var diff = Date.now() - startTime;' +
    '    if (diff >= 16 * 3600000) { stopWork(); return; }' +
    '    tmr.innerText = fmt(diff);' +
    '  }, 1000);' +
    '};' +

    // Остановка
    'function stopWork(){' +
    '  clearInterval(interval);' +
    '  localStorage.removeItem("wtr_start");' +
    '  cont.classList.replace("minimized", "centered");' +
    '  btn.innerHTML="Начать<br>работу"; btn.style.background="#10b981";' +
    '  msk.classList.remove("hidden"); ' +
    '  ajaxRequest(%5:s, "workFinished", ["time="+tmr.innerText]);' +
    '};' +

    // Проверка при запуске (Синхронизация)
    'var saved = localStorage.getItem("wtr_start");' +
    'if(saved){' +
    '  var startTs = parseInt(saved);' +
    '  var passed = Date.now() - startTs;' +
    '  if(passed < 16 * 3600000){' +
    '    cont.classList.replace("centered", "minimized");' +
    '    btn.innerText="СТОП"; btn.style.background="#ef4444";' +
    '    msk.classList.add("hidden");' +
    '    startTmr(startTs);' +
    '  } else { localStorage.removeItem("wtr_start"); }' +
    '}' +

    // Клик по кнопке
    'btn.onclick = function(e){' +
    '  e.stopPropagation();' +
    '  if(cont.classList.contains("centered")){' +
    '    var now = Date.now();' +
    '    localStorage.setItem("wtr_start", now);' +
    '    cont.classList.replace("centered", "minimized");' +
    '    btn.innerText="СТОП"; btn.style.background="#ef4444";' +
    '    msk.classList.add("hidden");' +
    '    startTmr(now);' +
    '    ajaxRequest(%5:s, "workStarted", ["timestamp="+now]);' +
    '  } else {' +
    '    stopWork();' +
    '  }' +
    '};',
    [LCID, AFontName, APanelColor, AOffset, LScaleStr, APanel.JSName]
  );

  UniSession.AddJS(LJS);
end;

procedure DestroyWorkTracker(APanel: TUnimPanel);
var
  LJS, LCID: string;
begin
  // Используем тот же префикс ID, что и в основной процедуре
  LCID := APanel.JSName + '_wtr';

  LJS :=
    ' (function() { ' +
    // 1. Очищаем локальное хранилище (удаляем метку времени)
    '   localStorage.removeItem("wtr_start"); ' +

    // 2. Ищем маску и контейнер
    '   var msk = document.getElementById("' + LCID + '_msk"); ' +
    '   var cont = document.getElementById("' + LCID + '_cont"); ' +

    // 3. Останавливаем таймер, если он запущен
    // Мы не можем напрямую обратиться к переменной interval из другой процедуры,
    // но при удалении элементов из DOM и очистке ссылок браузер со временем приберет интервал.
    // Однако, лучше всего принудительно очистить все интервалы, если мы знаем их ID.
    // В JS нашей основной процедуры мы можем привязать интервал к window для доступа отсюда.
    '   if (window._wtrInterval) { ' +
    '     clearInterval(window._wtrInterval); ' +
    '     window._wtrInterval = null; ' +
    '   } ' +

    // 4. Удаляем элементы с анимацией затухания (опционально)
    '   if (msk) { ' +
    '     msk.style.opacity = "0"; ' +
    '     setTimeout(function() { msk.remove(); }, 500); ' +
    '   } ' +
    ' })(); ';

  UniSession.AddJS(LJS);
end;


procedure Toast(const AText: string; AAlign: TAlign = alBottom);
var
  SafeText: string;
  ShowClass: string;
begin
  // Очистка текста для JS
  SafeText := AText.Replace('"', '\"').Replace(#13, ' ').Replace(#10, ' ');

  case AAlign of
    alTop:    ShowClass := 'shw-top';
    alBottom: ShowClass := 'shw-bottom';
  else      ShowClass := 'shw-center';
  end;

  UniSession.AddJS(
    '(function(){ ' +
    '  var sId="fire_tst_style"; ' +
    '  if(!document.getElementById(sId)){ ' +
    '    var css = ".fire-tst { visibility:hidden; min-width:200px; color:#fff; font-family:sans-serif; '+'text-align:center; border-radius:15px; padding:15px 25px; position:fixed; z-index:999999; opacity:0; transition: opacity 0.4s, visibility 0.4s, top 0.4s, bottom 0.4s; background:#111; border:2px solid #ff4500; font-weight:bold;'+' box-shadow: 0 0 20px #ff4500, 0 0 40px #ff8c00, inset 0 0 10px #ff0000; animation: fire-pulse 1.5s infinite alternate; } " + ' +
    '              ".fire-tst.shw-top { visibility:visible; opacity:1; top:10%; left:50%; transform:translateX(-50%); } " + ' +
    '              ".fire-tst.shw-bottom { visibility:visible; opacity:1; bottom:10%; left:50%; transform:translateX(-50%); } " + ' +
    '              ".fire-tst.shw-center { visibility:visible; opacity:1; top:50%; left:50%; transform:translate(-50%, -50%); } " + ' +
    '              "@keyframes fire-pulse { 0% { box-shadow: 0 0 20px #ff4500, 0 0 40px #ff8c00; } 50% { box-shadow: 0 0 40px #ff0000, 0 0 70px #ff4500; } 100% { box-shadow: 0 0 20px #ff8c00, 0 0 40px #ff4500; } }"; ' +
    '    var h=document.head, s=document.createElement("style"); s.id=sId; s.appendChild(document.createTextNode(css)); h.appendChild(s); ' +
    '  } ' +
    '  var t=document.getElementById("u_fire_tst"); ' +
    '  if(!t){ t=document.createElement("div"); t.id="u_fire_tst"; document.body.appendChild(t); } ' +
    '  t.className = "fire-tst"; ' +
    '  t.innerHTML = "' + SafeText + '"; ' +
    '  setTimeout(function(){ t.classList.add("' + ShowClass + '"); }, 10); ' +
    '  setTimeout(function(){ t.classList.remove("' + ShowClass + '"); }, 3500); ' +
    '})();'
  );
end;

procedure AddArkanoidToPanel(APanel: TUnimPanel);
var
  LJSName: string;
begin
  LJSName := APanel.JSName;

  UniSession.AddJS(
    '(function() {' +
    '  const targetPanel = ' + LJSName + '.el.dom;' +
    '  if (!targetPanel) return;' +
    '  targetPanel.style.position = "relative";' +

    '  ' + LJSName + '.destroyArkanoid = function() {' +
    '    const root = document.getElementById("' + LJSName + '_game_root");' +
    '    if (root) root.remove();' +
    '    this.gameActive = false;' +
    '  };' +

    '  const gameHTML = ' +
    '    `<div id="' + LJSName + '_game_root" style="position:absolute; top:0; left:0; right:0; display:flex; flex-direction:column; align-items:center; width:100%; user-select:none; font-family:monospace; padding:15px 0; background: transparent; z-index: 9999; pointer-events: none;">' +
    '      <style>' +
    '        .crt-screen::before { content: " "; display: block; position: absolute; top: 0; left: 0; bottom: 0; right: 0; background: linear-gradient(rgba(18, 16, 16, 0) 50%,'+' rgba(0, 0, 0, 0.25) 50%), linear-gradient(90deg, rgba(255, 0, 0, 0.06), rgba(0, 255, 0, 0.02), rgba(0, 0, 255, 0.06)); z-index: 2; background-size: 100% 2px, 3px 100%; pointer-events: none; border-radius: 18px; }' +
    '        .crt-screen::after { content: " "; display: block; position: absolute; top: 0; left: 0; bottom: 0; right: 0; background: rgba(18, 16, 16, 0.1); opacity: 0; z-index: 2; pointer-events: none; animation: flicker 0.15s infinite; border-radius: 18px; }' +
    '        @keyframes flicker { 0% { opacity: 0.1; } 50% { opacity: 0.2; } 100% { opacity: 0.1; } }' +
    '      </style>' +
    '      <div class="crt-screen" style="position:relative; pointer-events: auto; background:rgba(30,30,30,0.8); backdrop-filter:blur(10px); border-radius:24px; border:2px solid #555; padding:8px; box-shadow: 0 0 20px rgba(0,0,0,0.8); width:fit-content;">' +
    '        <div id="' + LJSName + '_time" style="position:absolute; top:12px; left:18px; color:#00ffcc; font-size:10px; z-index:10; opacity:0.8; letter-spacing:1px;">00:00</div>' +
    '        <div id="' + LJSName + '_score_wrap" style="position:absolute; top:12px; right:18px; color:#00ffcc; font-size:10px; z-index:10; opacity:0.8; letter-spacing:1px;">SCORE:0</div>' +
    '        <canvas id="' + LJSName + '_canvas" width="280" height="150" style="display:block; background:#050505; border-radius:18px;"></canvas>' +
    '        <div id="' + LJSName + '_overlay" style="position:absolute; top:0; left:0; width:100%; height:100%; display:flex; align-items:center; '+'justify-content:center; background:rgba(0,0,0,0.85); border-radius:18px; z-index:20; color:#00ffcc; text-align:center; font-size:12px; letter-spacing:1px;">' +
    '           <div id="' + LJSName + '_overlay_content">НАЖМИ НА СТИК<br>ЧТОБЫ НАЧАТЬ</div>' +
    '        </div>' +
    '      </div>' +
    '      <div id="' + LJSName + '_ctrl" style="pointer-events: auto; margin-top:15px; width:220px; height:48px; background:rgba(255,255,255,0.1); border-radius:24px; position:relative; border:1px solid rgba(255,255,255,0.2); touch-action:none;">' +
    '        <div id="' + LJSName + '_stick" style="position:absolute; left:50%; top:50%; transform:translate(-50%,-50%); width:44px; height:44px; background:linear-gradient(135deg,#00ffcc,#00aba9); border-radius:50%; box-shadow:0 0 15px rgba(0,255,204,0.5); pointer-events:none;"></div>' +
    '      </div>' +
    '    </div>`;' +

    '  targetPanel.insertAdjacentHTML("afterbegin", gameHTML);' +

    '  const canvas = document.getElementById("' + LJSName + '_canvas");' +
    '  const ctx = canvas.getContext("2d");' +
    '  const ctrl = document.getElementById("' + LJSName + '_ctrl");' +
    '  const stick = document.getElementById("' + LJSName + '_stick");' +
    '  const scoreWrap = document.getElementById("' + LJSName + '_score_wrap");' +
    '  const timeEl = document.getElementById("' + LJSName + '_time");' +
    '  const overlay = document.getElementById("' + LJSName + '_overlay");' +
    '  const overlayContent = document.getElementById("' + LJSName + '_overlay_content");' +

    '  let score = 0; let x = canvas.width/2; let y = canvas.height-30; ' +
    '  let dx = 1.8; let dy = -1.8; ' +
    '  let paddleW = 70; let paddleX = (canvas.width - paddleW)/2;' +
    '  let bricks = []; const rows = 4; const cols = 8; ' +
    '  let startTime = 0; let timerInterval = null;' +
    '  ' + LJSName + '.gameActive = false;' +
    '  ' + LJSName + '.gameRunning = false;' +

    '  function formatTime(seconds) {' +
    '    const m = Math.floor(seconds / 60).toString().padStart(2, "0");' +
    '    const s = (seconds % 60).toString().padStart(2, "0");' +
    '    return m + ":" + s;' +
    '  }' +

    '  function updateGameTimer() {' +
    '    if (' + LJSName + '.gameActive) {' +
    '      const elapsed = Math.floor((Date.now() - startTime) / 1000);' +
    '      timeEl.innerText = formatTime(elapsed);' +
    '    }' +
    '  }' +

    '  function initBricks() {' +
    '    for(let c=0; c<cols; c++) { bricks[c]=[]; for(let r=0; r<rows; r++) bricks[c][r]={x:0,y:0,status:1}; }' +
    '  }' +
    '  initBricks();' +

    '  function draw() {' +
    '    if (!' + LJSName + '.gameActive) {' +
    '       ' + LJSName + '.gameRunning = false;' +
    '       if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }' +
    '       return;' +
    '    }' +
    '    ctx.fillStyle = "rgba(5, 5, 5, 0.3)"; ctx.fillRect(0,0,canvas.width,canvas.height);' +

    '    for(let c=0; c<cols; c++) for(let r=0; r<rows; r++) {' +
    '      if(bricks[c][r].status) {' +
    '        let brickW = 30; let brickH = 10; let gap = 4;' +
    '        let bx = c*(brickW+gap)+5; let by = r*(brickH+gap)+35; bricks[c][r].x=bx; bricks[c][r].y=by;' +
    '        ctx.fillStyle="rgba(0, 255, 204, 0.4)"; ' +
    '        if (ctx.roundRect) { ctx.beginPath(); ctx.roundRect(bx,by,brickW,brickH,2); ctx.fill(); } else ctx.fillRect(bx,by,brickW,brickH);' +
    '      }' +
    '    }' +

    '    ctx.beginPath(); ctx.arc(x,y,4,0,Math.PI*2); ctx.fillStyle="#fff"; ctx.fill(); ctx.closePath();' +
    '    ctx.fillStyle="#00ffcc"; ' +
    '    if (ctx.roundRect) { ctx.beginPath(); ctx.roundRect(paddleX, canvas.height-12, paddleW, 6, 3); ctx.fill(); } else ctx.fillRect(paddleX, canvas.height-12, paddleW, 6);' +

    '    for(let c=0; c<cols; c++) for(let r=0; r<rows; r++) {' +
    '      let b = bricks[c][r]; if(b.status && x>b.x && x<b.x+30 && y>b.y && y<b.y+10) {' +
    '        dy=-dy; b.status=0; score+=10; scoreWrap.innerText="SCORE:" + score;' +
    '      }' +
    '    }' +
    '    if(bricks.every(c => c.every(b => !b.status))) initBricks();' +

    '    if(x+dx > canvas.width-4 || x+dx < 4) dx = -dx;' +
    '    if(y+dy < 4) dy = -dy;' +
    '    else if(y+dy > canvas.height-12) {' +
    '      if(x > paddleX && x < paddleX+paddleW) { dy = -Math.abs(dy); dx = (x - (paddleX + paddleW/2)) * 0.12; }' +
    '      else {' +
    '             const totalTime = timeEl.innerText;' +
    '             const finalScore = score;' +
    '             x=canvas.width/2; y=canvas.height-30; score=0; scoreWrap.innerText="SCORE:0"; initBricks(); ' +
    '             ' + LJSName + '.gameActive = false; ' + LJSName + '.gameRunning = false;' +
    '             overlayContent.innerHTML = `ИГРА ОКОНЧЕНА<br><br>ВРЕМЯ: ${totalTime}<br>ОЧКИ: ${finalScore}<br><br>ТАПНИ СТИК ДЛЯ РЕСТАРТА`;' +
    '             overlay.style.display="flex";' +
    '      }' +
    '    }' +
    '    x+=dx; y+=dy; requestAnimationFrame(draw);' +
    '  }' +

    '  function move(e) {' +
    '    const rect = ctrl.getBoundingClientRect();' +
    '    const cx = e.clientX || (e.touches && e.touches[0].clientX);' +
    '    if(!cx) return;' +
    '    let p = cx - rect.left; if(p<22) p=22; if(p>rect.width-22) p=rect.width-22;' +
    '    stick.style.left = p + "px";' +
    '    paddleX = ((p-22)/(rect.width-44))*(canvas.width-paddleW);' +
    '    ' +
    '    if (!' + LJSName + '.gameActive && !' + LJSName + '.gameRunning) {' +
    '       ' + LJSName + '.gameActive = true;' +
    '       ' + LJSName + '.gameRunning = true;' +
    '       startTime = Date.now();' +
    '       timeEl.innerText = "00:00";' +
    '       if (timerInterval) clearInterval(timerInterval);' +
    '       timerInterval = setInterval(updateGameTimer, 1000);' +
    '       overlay.style.display="none";' +
    '       draw();' +
    '    }' +
    '  }' +

    '  ctrl.addEventListener("pointerdown", (e) => { ctrl.setPointerCapture(e.pointerId); move(e); });' +
    '  ctrl.addEventListener("pointermove", (e) => { if(e.buttons>0 || e.pointerType==="touch") move(e); });' +
    '})();'
  );
end;

procedure ShowServicePanel(APanel: TUnimPanel; const ADataJSON, AComboBoxJSON,
  ABgColor, AFontName, AFontColor, ACaption, ACaptionColor: string; AActiveTabIndex: Integer = 0);
var
  LHTML, LJS, LCID, LCap: string;
  LCColor: string;
  Tab0Style, Tab1Style: string;
begin
  LCID := APanel.JSName + '_svc';
  LCap := ACaption;
  LCap := StringReplace(LCap, '&', '&amp;', [rfReplaceAll]);
  LCap := StringReplace(LCap, '<', '&lt;', [rfReplaceAll]);
  LCap := StringReplace(LCap, '>', '&gt;', [rfReplaceAll]);
  LCap := StringReplace(LCap, '"', '&quot;', [rfReplaceAll]);

  if Trim(LCap) = '' then LCap := '&nbsp;';
  LCColor := IfThen(Trim(ACaptionColor) = '', '#ffffff', ACaptionColor);

  // Определяем начальные стили для вкладок в зависимости от параметра
  if AActiveTabIndex = 0 then
  begin
    Tab0Style := 'background:rgba(255,255,255,0.1); opacity:1;';
    Tab1Style := 'background:transparent; opacity:0.5;';
  end
  else
  begin
    Tab0Style := 'background:transparent; opacity:0.5;';
    Tab1Style := 'background:rgba(255,255,255,0.1); opacity:1;';
  end;

  LHTML :=
    '<div id="' + LCID + '_msk" style="position:fixed; top:0; left:0; width:100vw; height:100vh; ' +
    '  background:rgba(0,0,0,0.7); backdrop-filter:blur(10px); z-index:999999; display:flex; justify-content:center; align-items:center; font-family:' + AFontName + ';">' +

    '  <div style="position:relative; width:92%; max-width:500px; height:85%; background:' + ABgColor + '; ' +
    '    border-radius:32px; display:flex; flex-direction:column; overflow:hidden; box-shadow:0 30px 60px rgba(0,0,0,0.5); border:1px solid rgba(255,255,255,0.1);">' +

    // Шапка
    '    <div style="position:relative; flex-shrink:0; min-height:52px; box-sizing:border-box; border-bottom:1px solid rgba(255,255,255,0.08); padding:12px 56px 12px 16px;">' +
    '      <div style="text-align:center; padding:8px 0; font-family:' + AFontName + '; font-size:28px; font-weight:600; line-height:1.3; color:' + LCColor + ';">' + LCap + '</div>' +
    '      <div onclick="ajaxRequest(' + APanel.JSName + ', ''srvPanelClosed'', []); document.getElementById(''' + LCID + '_msk'').remove();" ' +
    '        style="position:absolute; top:12px; right:12px; width:40px; height:40px; background:#ef4444; color:#fff; ' +
    '        border-radius:50%; display:flex; align-items:center; justify-content:center; cursor:pointer; font-size:20px; font-weight:bold; z-index:100;">✕</div>' +
    '    </div>' +

    // Вкладки с применением начальных стилей
    '    <div style="display:flex; background:rgba(0,0,0,0.1); padding:8px; gap:8px; flex-shrink:0;">' +
    '      <div id="' + LCID + '_tab0" onclick="window._switchTab(0)" style="flex:1; text-align:center; padding:12px; border-radius:16px; cursor:pointer; font-weight:600; transition:0.3s; color:#fff; ' + Tab0Style + '">Сервис</div>' +
    '      <div id="' + LCID + '_tab1" onclick="window._switchTab(1)" style="flex:1; text-align:center; padding:12px; border-radius:16px; cursor:pointer; font-weight:600; transition:0.3s; color:#fff; ' + Tab1Style + '">Ремонт</div>' +
    '    </div>' +

    // Таблица данных
    '    <div style="flex:1; overflow-y:auto; padding:10px 20px;">' +
    '      <table style="width:100%; border-collapse:separate; border-spacing:0 10px; color:' + AFontColor + ';">' +
    '        <tbody id="' + LCID + '_tb"></tbody>' +
    '      </table>' +
    '    </div>' +

    // Выпадающий список
    '    <div id="' + LCID + '_drop" style="display:none; position:absolute; bottom:110px; left:25px; right:25px; ' +
    '      max-height:350px; background:white; border-radius:18px; overflow-y:auto; z-index:3000; ' +
    '      box-shadow:0 -10px 40px rgba(0,0,0,0.4); border:1px solid #ccc;"></div>' +

    // Оверлей добавления (счетчик)
    '    <div id="' + LCID + '_fcd" style="display:none; position:absolute; top:0; left:0; width:100%; height:100%; ' +
    '      background:rgba(0,0,0,0.95); color:#fff; z-index:4000; flex-direction:column; justify-content:center; align-items:center; text-align:center;">' +
    '      <div id="' + LCID + '_itm" style="font-size:28px; font-weight:bold; color:#fbbf24; margin-bottom:20px;">---</div>' +
    '      <div id="' + LCID + '_num" style="font-size:140px; font-weight:900;">5</div>' +
    '      <button onclick="window._cancelSvc()" style="margin-top:40px; width:220px; height:65px; background:#ef4444; color:white; border:none; border-radius:20px; font-weight:bold;">ОТМЕНА</button>' +
    '    </div>' +

    // Нижняя панель
    '    <div style="padding:25px; background:rgba(0,0,0,0.2); display:flex; gap:12px; border-top:1px solid rgba(255,255,255,0.05);">' +
    '      <div id="' + LCID + '_cb" style="flex:1; height:55px; border-radius:18px; background:rgba(255,255,255,0.9); ' +
    '        padding:0 15px; font-size:16px; font-weight:600; color:#000; display:flex; align-items:center; cursor:pointer;">Выберите...</div>' +
    '      <div id="' + LCID + '_add" style="width:65px; height:55px; background:#10b981; color:#fff; border-radius:18px; ' +
    '        display:flex; align-items:center; justify-content:center; font-size:32px; cursor:pointer;">+</div>' +
    '    </div>' +
    '  </div>' +
    '</div>';

  LJS := Format(
    'var old=document.getElementById("%0:s_msk"); if(old)old.remove();' +
    'document.body.insertAdjacentHTML("beforeend", `%1:s`);' +
    'var d=%2:s, opts=%3:s, b=document.getElementById("%0:s_tb"), cb=document.getElementById("%0:s_cb"), drop=document.getElementById("%0:s_drop");' +
    'var selVal="", selTxt="Выберите...";' +

    // Инициализация активного таба из параметра Delphi
    'window._activeTab = %7:d;' +

    'window._switchTab = function(idx) {' +
    '  if(window._activeTab === idx) return;' +
    '  window._activeTab = idx;' +
    '  [0,1].forEach(function(i){ ' +
    '    var t = document.getElementById("%0:s_tab"+i);' +
    '    t.style.background = (i===idx) ? "rgba(255,255,255,0.1)" : "transparent";' +
    '    t.style.opacity = (i===idx) ? "1" : "0.5";' +
    '  });' +
    '  ajaxRequest(%6:s, "tabChanged", ["index="+idx]);' +
    '};' +

    // Dropdown настройки
    'var bgCol = %5:s; drop.style.background = "color-mix(in srgb, " + bgCol + ", black 30%%)";' +
    'opts.forEach(function(o){ ' +
    '  var k=Object.keys(o), id=o[k[0]], txt=o[k[1]||k[0]];' +
    '  var row=document.createElement("div"); row.style.padding="18px 15px"; row.style.borderBottom="1px solid rgba(255,255,255,0.1)";' +
    '  row.style.color="#ffffff"; row.innerText=txt; row.onclick=function(e){ ' +
    '    e.stopPropagation(); selVal=id; selTxt=txt; cb.innerText=txt; drop.style.display="none"; ' +
    '  }; drop.appendChild(row);' +
    '});' +

    'cb.onclick=function(e){ e.stopPropagation(); drop.style.display=(drop.style.display==="none"?"block":"none"); };' +
    'document.addEventListener("click", function(){ if(drop) drop.style.display="none"; }, {once:false});' +

    // Отрисовка таблицы
    'var draw=function(da){ b.innerHTML=""; da.forEach(function(r){ ' +
    '  var tr=b.insertRow(); tr.style.background="rgba(255,255,255,0.03)"; ' +
    '  var ks=Object.keys(r); ks.forEach(function(k,i){ ' +
    '    var td=tr.insertCell(); td.style.padding="15px 12px"; td.innerText=r[k]; ' +
    '    if(i===0) td.style.borderRadius="12px 0 0 12px"; if(i===ks.length-1) td.style.borderRadius="0 12px 12px 0";' +
    '  }); }); }; draw(d);' +

    // Кнопка "+" и звук
    'var timer=null; document.getElementById("%0:s_add").onclick=function(){ ' +
    '  if(!selVal) return; ' +
    '  var v=selTxt, id=selVal, cd=document.getElementById("%0:s_fcd"), nm=document.getElementById("%0:s_num"), itm=document.getElementById("%0:s_itm"), count=5;' +
    '  var snd = new Audio("files/src-media/warning.mp3"); snd.loop = true; snd.play(); ' +
    '  itm.innerText=v; cd.style.display="flex"; nm.innerText=count;' +
    '  window._cancelSvc=function(){ clearInterval(timer); if(snd){snd.pause(); snd.currentTime=0;} cd.style.display="none"; }; ' +
    '  timer=setInterval(function(){ count--; nm.innerText=count; ' +
    '    if(count<=0){ clearInterval(timer); snd.pause(); cd.style.display="none"; ' +
    '      var ds=new Date().toLocaleString("ru-RU").replace(",",""), ks=Object.keys(d[0]||{"p":"","v":"","d":""}), n={}; ' +
    '      n[ks[0]]=(d[0]?d[0][ks[0]]:""); n[ks[1]]=v; n[ks[2]]=ds; d.unshift(n); draw(d); ' +
    '      ajaxRequest(%6:s, "itemAdded", ["id="+id, "val="+v, "tab="+window._activeTab]); ' +
    '    } }, 1000); ' +
    '};',

    [LCID, LHTML,
     IfThen(ADataJSON = '', '[]', ADataJSON),
     IfThen(AComboBoxJSON = '', '[]', AComboBoxJSON),
     AFontName,
     QuotedStr(ABgColor),
     APanel.JSName,
     AActiveTabIndex // %7:d
    ]);

  UniSession.AddJS(LJS);
end;

procedure ShowCustomScanner(
  APanel: TUnimPanel;
  const ATitle, ABgColor, AFontName, AFontColor, AThemeColor: string;
  AFontSize: Integer;
  const AMode: string = '';
  AScale: Double = 1.0;
  ARollInfoJson: string = '';
  ACurrentEquipId: string = '';
  ACurrentRollId: string = '';
  AScanAreaScale: Double = 0.50);
var
  LHTML, LJS, LCID, LSScanAreaScale, LSvgUser, LSvgEquipBig, LSvgExit, LSvgScan, LSvgRollBig, LSettingsPanel: string;
  LIsLogin: Boolean;
  LScanAreaScale: Double;
  LUserHeader, LScannerFlex, LButtonsHTML, LProcessPanel: string;
begin
  LCID := APanel.JSName;
  LScanAreaScale := AScanAreaScale;
  if LScanAreaScale <= 0 then
    LScanAreaScale := AScale;
  if LScanAreaScale < 0.2 then
    LScanAreaScale := 0.2
  else if LScanAreaScale > 0.95 then
    LScanAreaScale := 0.95;
  LSScanAreaScale := FloatToStr(LScanAreaScale).Replace(',', '.');
  LIsLogin := AMode = 'login';

  // Сканер будет занимать столько места, сколько нужно, а панель под ним заберет остаток
  LScannerFlex := IfThen(LIsLogin, '1', '0 0 auto');

  // Базовые SVG
  LSvgUser := '<svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>';
  LSvgExit := '<svg viewBox="0 0 24 24" width="17" height="17" stroke="currentColor" stroke-width="2.5" fill="none"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>';
  LSvgScan := '<svg viewBox="0 0 24 24" width="40" height="40" stroke="white" stroke-width="2" fill="none"><path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 12h10"/></svg>';

  // Увеличенные на 50% SVG для панели процессов (было 34, стало 51)
  LSvgEquipBig := '<svg viewBox="0 0 24 24" width="51" height="51" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M9 9h6v6H9zM9 1v3M15 1v3M9 20v3M15 20v3M20 9h3M20 15h3M1 9h3M1 15h3"/></svg>';
  LSvgRollBig := '<svg viewBox="0 0 24 24" width="51" height="51" fill="none" stroke="currentColor" stroke-width="1.5"><ellipse cx="12" cy="6" rx="8" ry="3"></ellipse><path d="M4 6v12c0 1.66 3.58 3 8 3s8-1.34 8-3V6"></path></svg>';

  // 1. Блок юзера над сканером
  LUserHeader := '';

  LButtonsHTML :=
    '<div id="' + LCID + '_btn_scan" style="width:90px; height:90px; background:rgba(255,255,255,0.1); border:1px solid rgba(255,255,255,0.4); ' +
    'border-radius:50%; display:flex; align-items:center; justify-content:center; cursor:pointer; box-shadow:0 0 40px rgba(0,0,0,0.5);">' + LSvgScan + '</div>';

  LSettingsPanel :=
    '<div id="' + LCID + '_scan_settings" style="display:none; position:fixed; inset:0; z-index:10000; ' +
    'background:rgba(0,0,0,0.88); flex-direction:column; font-family:' + AFontName + '; color:#fff; overflow:hidden;">' +
    '  <style>' +
    '    #' + LCID + '_scan_settings .ss-action-btn{' +
    '      transition:transform .12s ease,opacity .12s ease,background .15s ease,box-shadow .15s ease;' +
    '      -webkit-tap-highlight-color:transparent; touch-action:manipulation; user-select:none;}' +
    '    #' + LCID + '_scan_settings .ss-action-btn:active,' +
    '    #' + LCID + '_scan_settings .ss-action-btn.ss-btn-pressed{transform:scale(0.96);opacity:.82;}' +
    '    #' + LCID + '_scan_settings .ss-action-btn.ss-btn-busy{opacity:.5;pointer-events:none;}' +
    '    #' + LCID + '_scan_settings .ss-action-btn.ss-btn-ok{box-shadow:0 0 0 2px #22c55e;opacity:1;}' +
    '    #' + LCID + '_scan_settings .ss-btn-secondary{background:transparent;border:1px solid rgba(255,255,255,0.2);color:#fff;}' +
    '    #' + LCID + '_scan_settings .ss-btn-muted{background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.25);color:#fff;}' +
    '    #' + LCID + '_scan_settings .ss-btn-global{background:rgba(16,185,129,0.18);border:1px solid rgba(16,185,129,0.45);color:#ecfdf5;}' +
    '    #' + LCID + '_scan_settings .ss-btn-primary{background:#3b82f6;border:none;color:#fff;}' +
    '  </style>' +

    // шапка
    '  <div style="display:flex; align-items:center; justify-content:space-between; padding:16px 20px; ' +
    'border-bottom:1px solid rgba(255,255,255,0.12); flex-shrink:0;">' +
    '    <div style="font-size:18px; font-weight:700;">Настройки сканера</div>' +
    '    <button type="button" id="' + LCID + '_ss_close" ' +
    'style="width:36px; height:36px; border:none; border-radius:50%; background:rgba(255,255,255,0.12); color:#fff; font-size:22px; cursor:pointer;">&times;</button>' +
    '  </div>' +

    // тело
    '  <div style="flex:1; overflow-y:auto; padding:16px 20px 24px; -webkit-overflow-scrolling:touch;">' +
    '    <div style="font-size:12px; color:#94a3b8; margin-bottom:16px; line-height:1.5;">' +
    'Если сканер не работает на iPhone — попробуйте сменить камеру, FPS, соотношение сторон или отключить qrbox (полный кадр).</div>' +
    '    <div style="display:flex; flex-direction:column; gap:14px;">' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Камера (facingMode)' +
    '        <select id="' + LCID + '_ss_facing" style="padding:10px 12px; border-radius:10px; border:1px solid rgba(255,255,255,0.2); background:#1e293b; color:#fff; font-size:14px;">' +
    '          <option value="environment">Задняя (environment)</option>' +
    '          <option value="user">Передняя (user)</option>' +
    '          <option value="exact">Конкретная камера (ID)</option>' +
    '        </select></label>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">ID камеры' +
    '        <select id="' + LCID + '_ss_camera" style="padding:10px 12px; border-radius:10px; border:1px solid rgba(255,255,255,0.2); background:#1e293b; color:#fff; font-size:14px;">' +
    '          <option value="">— загрузка —</option></select></label>' +

    '    <button type="button" id="' + LCID + '_ss_refresh_cam" class="ss-action-btn ss-btn-muted" ' +
    'style="padding:10px; border-radius:10px; font-size:13px; cursor:pointer; width:100%;">' +
    'Обновить список камер</button>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">FPS сканирования: <span id="' + LCID + '_ss_fps_val">10</span>' +
    '        <input type="range" id="' + LCID + '_ss_fps" min="1" max="60" value="10" style="width:100%;"></label>' +
    '      <div style="font-size:11px; color:#64748b; margin-top:-8px;">1–30 обычно достаточно; на iPhone можно попробовать 40–60</div>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Область сканирования (%%): <span id="' + LCID + '_ss_qrbox_val">50</span>' +
    '        <input type="range" id="' + LCID + '_ss_qrbox" min="20" max="95" value="50" style="width:100%;"></label>' +

    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;">' +
    '        <input type="checkbox" id="' + LCID + '_ss_fullframe"> Сканировать весь кадр (без qrbox)</label>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Соотношение сторон видео' +
    '        <select id="' + LCID + '_ss_aspect" style="padding:10px 12px; border-radius:10px; border:1px solid rgba(255,255,255,0.2); background:#1e293b; color:#fff; font-size:14px;">' +
    '          <option value="0">Авто (не задавать)</option>' +
    '          <option value="1">1:1</option>' +
    '          <option value="1.333">4:3</option>' +
    '          <option value="1.777">16:9</option>' +
    '        </select></label>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Антидребезг (мс): <span id="' + LCID + '_ss_debounce_val">2500</span>' +
    '        <input type="range" id="' + LCID + '_ss_debounce" min="500" max="5000" step="100" value="2500" style="width:100%;"></label>' +

    '      <div style="font-size:13px; font-weight:600; margin-top:4px;">Изображение камеры</div>' +
    '      <div style="font-size:11px; color:#64748b; line-height:1.4;">Zoom — оптический (если камера поддерживает). Яркость и контраст — через CSS и аппаратно.</div>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Zoom: <span id="' + LCID + '_ss_zoom_val">1</span>' +
    '        <input type="range" id="' + LCID + '_ss_zoom" min="1" max="10" step="0.1" value="1" style="width:100%;"></label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;">' +
    '        <input type="checkbox" id="' + LCID + '_ss_disable_zoom"> Отключить zoom / автозум камеры</label>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Яркость (%%): <span id="' + LCID + '_ss_brightness_val">100</span>' +
    '        <input type="range" id="' + LCID + '_ss_brightness" min="50" max="200" step="5" value="100" style="width:100%;"></label>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Контраст (%%): <span id="' + LCID + '_ss_contrast_val">100</span>' +
    '        <input type="range" id="' + LCID + '_ss_contrast" min="50" max="200" step="5" value="100" style="width:100%;"></label>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Препроцессинг превью' +
    '        <select id="' + LCID + '_ss_preprocess" style="padding:10px 12px; border-radius:10px; border:1px solid rgba(255,255,255,0.2); background:#1e293b; color:#fff; font-size:14px;">' +
    '          <option value="off">Выкл (обычное видео)</option>' +
    '          <option value="contrast">Высокий контраст (CSS)</option>' +
    '          <option value="bw">Ч/б усиленный (CSS)</option>' +
    '          <option value="binary">Ч/б бинаризация (canvas)</option>' +
    '        </select></label>' +
    '      <div style="font-size:11px; color:#64748b; margin-top:-8px;">Превью для наведения на код. По умолчанию сканер читает исходное видео.</div>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;">' +
    '        <input type="checkbox" id="' + LCID + '_ss_decode_pre"> Сканировать обработанный кадр (canvas)</label>' +
    '      <div style="font-size:11px; color:#64748b; margin-top:-8px;">Медленнее; включайте при препроцессинге ≠ Выкл. На iPhone попробуйте бинаризацию.</div>' +

    '      <label style="display:flex; flex-direction:column; gap:6px; font-size:13px;">Порог бинаризации: <span id="' + LCID + '_ss_pre_th_val">128</span>' +
    '        <input type="range" id="' + LCID + '_ss_pre_th" min="60" max="200" step="1" value="128" style="width:100%;"></label>' +

    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;">' +
    '        <input type="checkbox" id="' + LCID + '_ss_disable_flip"> disableFlip (не сканировать зеркально)</label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;">' +
    '        <input type="checkbox" id="' + LCID + '_ss_barcode_detector"> useBarCodeDetectorIfSupported (эксп.)</label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;">' +
    '        <input type="checkbox" id="' + LCID + '_ss_verbose"> Подробный лог в консоль</label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;">' +
    '        <input type="checkbox" id="' + LCID + '_ss_autostart"> Автозапуск камеры при открытии</label>' +

    '      <div style="font-size:13px; font-weight:600; margin-top:4px;">Форматы кодов</div>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;"><input type="checkbox" id="' + LCID + '_ss_fmt_qr" checked> QR Code</label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;"><input type="checkbox" id="' + LCID + '_ss_fmt_c128"> CODE_128</label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;"><input type="checkbox" id="' + LCID + '_ss_fmt_ean13"> EAN_13</label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;"><input type="checkbox" id="' + LCID + '_ss_fmt_c39"> CODE_39</label>' +
    '      <label style="display:flex; align-items:center; gap:10px; font-size:13px;"><input type="checkbox" id="' + LCID + '_ss_fmt_datamatrix"> DATA_MATRIX</label>' +

    '      <div style="display:flex; gap:10px;">' +
    '        <label style="flex:1; display:flex; flex-direction:column; gap:6px; font-size:13px;">Ширина видео (0=авто)' +
    '          <input type="number" id="' + LCID + '_ss_vw" min="0" max="4096" value="0" ' +
    'style="padding:10px; border-radius:10px; border:1px solid rgba(255,255,255,0.2); background:#1e293b; color:#fff;"></label>' +
    '        <label style="flex:1; display:flex; flex-direction:column; gap:6px; font-size:13px;">Высота видео (0=авто)' +
    '          <input type="number" id="' + LCID + '_ss_vh" min="0" max="4096" value="0" ' +
    'style="padding:10px; border-radius:10px; border:1px solid rgba(255,255,255,0.2); background:#1e293b; color:#fff;"></label>' +
    '      </div>' +

    '      <div id="' + LCID + '_ss_status" style="font-size:12px; color:#fbbf24; min-height:18px; word-break:break-word;"></div>' +
    '    </div>' +
    '  </div>' +

    // подвал
    '  <div style="display:flex; flex-direction:column; gap:10px; padding:16px 20px calc(16px + env(safe-area-inset-bottom)); ' +
    'border-top:1px solid rgba(255,255,255,0.12); flex-shrink:0;">' +
    '    <div style="display:flex; gap:10px;">' +
    '      <button type="button" id="' + LCID + '_ss_reset" class="ss-action-btn ss-btn-secondary" ' +
    'style="flex:1; padding:14px; border-radius:14px; font-weight:600; cursor:pointer;">Сброс</button>' +
    '      <button type="button" id="' + LCID + '_ss_save_profile" class="ss-action-btn ss-btn-muted" ' +
    'style="flex:1; padding:14px; border-radius:14px; font-weight:600; cursor:pointer;">Сохранить</button>' +
    '    </div>' +
    '    <button type="button" id="' + LCID + '_ss_apply_global" class="ss-action-btn ss-btn-global" ' +
    'style="width:100%; padding:14px; border-radius:14px; font-weight:700; cursor:pointer;">Применить глобальные настройки</button>' +
    '    <button type="button" id="' + LCID + '_ss_apply" class="ss-action-btn ss-btn-primary" ' +
    'style="width:100%; padding:14px; border-radius:14px; font-weight:700; cursor:pointer;">Применить</button>' +
    '  </div>' +
    '</div>';

  // 2. Панель процесса (под сканнером, увеличенные шрифты и иконки)
  LProcessPanel :=
    '<div id="' + LCID + '_process_panel" style="display:none; flex:1; flex-direction:column; padding:15px 20px 30px; box-sizing:border-box; overflow-y:auto; position:relative; gap:15px;">' +
    '  ' +
//    '  <div style="display:flex; justify-content:center; align-items:center; background:rgba(255,255,255,0.05); padding:20px 30px; border-radius:24px; border:1px solid rgba(255,255,255,0.1); gap:40px; box-shadow: 0 10px 30px rgba(0,0,0,0.2);">' +
//    '    <div id="' + LCID + '_node_eq" style="color:#fff; opacity:0.3; transition:all 0.5s; display:flex; flex-direction:column; align-items:center; gap:12px;">' +
//           LSvgEquipBig + '<span style="font-size:14px; font-weight:bold;">' + ACurrentEquipId + '</span></div>' +

      '  <div style="display:flex; justify-content:center; align-items:center; background:rgba(255,255,255,0.05); padding:20px 30px; border-radius:24px; border:1px solid rgba(255,255,255,0.1); gap:40px; box-shadow: 0 10px 30px rgba(0,0,0,0.2);">' +
      '    <div id="' + LCID + '_node_eq" onclick="ajaxRequest(window[''' + LCID + '''], ''nodeEqClick'', [''equipId=' + ACurrentEquipId + '''])" style="color:#fff; opacity:0.3; transition:all 0.5s; display:flex; flex-direction:column; align-items:center; gap:12px; cursor:pointer;">' +
             LSvgEquipBig + '<span style="font-size:14px; font-weight:bold;">' + ACurrentEquipId + '</span></div>' +


    '    <div style="width:2px; height:50px; background:rgba(255,255,255,0.1);"></div>' + // Разделитель внутри группы
    '    <div id="' + LCID + '_node_roll" onclick="ajaxRequest(window[''' + LCID + '''], ''nodeRollClick'', [])" style="color:#fff; opacity:0.3; transition:all 0.5s; display:flex; flex-direction:column; align-items:center; gap:12px;">' +
           LSvgRollBig + '<span style="font-size:14px; font-weight:bold;">' + ACurrentRollId + '</span></div>' +
    '  </div>' +
    '  ' +
    '  <div style="display:flex; justify-content:center; margin:-5px 0;">' +
    '    <div id="' + LCID + '_link_line" style="width:4px; height:0px; opacity:1 !important; background:#DEE64C!important; border-radius:2px; transition:height 0.8s ease-in-out;"></div>' +
    '  </div>' +
    // кнопки Начать\Закончить
    ' <div id="' + LCID + '_block_end" style="opacity:0; transform:translateY(-20px); transition:all 0.8s; background:rgba(255,255,255,0.05); padding:25px; border-radius:24px; text-align:center;">' +
    '  <div id="' + LCID + '_block_end_title" style="font-size:24px; font-weight:bold; margin-bottom:18px;">Статус рулона</div>' +
    '  <div style="display:flex; justify-content:center; align-items:center;">' +

    '   <button id="' + LCID + '_btn_action_start" onclick="ajaxRequest(window[''' + LCID + '''], ''actionStart'', [])" ' +
    '     style="flex:0; max-width:0px; opacity:0; padding:20px 0; margin:0; overflow:hidden; '+'white-space:nowrap; box-sizing:border-box; font-family:' + AFontName + '; border-radius:16px; border:none; background:#3b82f6; color:#fff; font-weight:bold; font-size:21px; pointer-events:none; transition:all 0.5s ease-in-out;">НАЧАТЬ</button>' +
    '   <button id="' + LCID + '_btn_action_end" ' +
    '     style="flex:0; max-width:0px; opacity:0; padding:20px 0; margin:0; overflow:hidden; '+'white-space:nowrap; box-sizing:border-box; border-radius:16px; border:none; background:#ef4444; color:#fff; font-weight:bold; font-size:21px; position:relative; pointer-events:none; transition:all 0.5s ease-in-out;">' +
    '    <div id="' + LCID + '_btn_end_fill" style="position:absolute; top:0; left:0; height:100%; width:0%; background:rgba(0,0,0,0.3); pointer-events:none;"></div>' +
    '    <span style="position:relative; font-family:' + AFontName + '; z-index:2;">ЗАКОНЧИТЬ</span>' +
    '   </button>' +
    '  </div>' +
    ' </div>' +
    '  ' +
    ' <style>' +
    '  .bottom-sheet {' +
    '    position: fixed;' +
    '    left: 0; right: 0; bottom: 0;' +
    '    transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1);' + // Плавный инерционный переход
    '    transform: translateY(calc(100% - 44px));' +
    '    z-index: 9999;' +
    '    display: flex; flex-direction: column;' +
    '  }' +
    '  .bottom-sheet.open {' +
    '    transform: translateY(0);' +
    '  }' +
    '  .sheet-header {' +
    '    height: 44px; background: rgba(28, 28, 30, 0.8);' +
    '    backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);' +
    '    display: flex; justify-content: center; align-items: center;' +
    '    cursor: pointer; border-radius: 24px 24px 0 0;' +
    '    border-top: 1px solid rgba(255,255,255,0.1);' +
    '  }' +
    '  .sheet-handle {' +
    '    width: 36px; height: 5px; background: #ffffff;' +
    '    border-radius: 3px;' +
    '  }' +
    '  .sheet-content {' +
    '    background: rgba(28, 28, 30, 0.94); backdrop-filter: blur(25px);' +
    '    padding: 20px; padding-bottom: 30px;' +
    '    border-top: 1px solid rgba(255,255,255,0.05);' +
    '    box-shadow: 0 -10px 40px rgba(0,0,0,0.4);' +
    '  }' +
    '  .tab-group {' +
    '    display: flex; gap: 10px; background: rgba(255,255,255,0.05);' +
    '    padding: 4px; border-radius: 12px; margin-bottom: 20px;' +
    '  }' +
    '  .tab-btn {' +
    '    flex: 1; text-align: center; padding: 12px; border-radius: 10px;' +
    '    font-size: 15px; font-weight: 600; cursor: pointer; color: #fff;' +
    '    transition: all 0.2s; border: none;' +
    '  }' +
    '  .tab-btn:active { transform: scale(0.96); background: rgba(255,255,255,0.1); }' +
    '  .tab-btn.active { background: #007AFF; box-shadow: 0 4px 12px rgba(0,122,255,0.3); }' +
    ' </style>' +

    // HTML блок
    '' +
    '<div id="mySidePanel" style="position:fixed; bottom:0; left:0; width:100%; height:52vh; ' +
    'transform:translateY(100%); background:rgba(28,28,30,0.97); border-radius:28px 28px 0 0; ' +
    'z-index:9999; transition:all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1); ' +
    'display:flex; flex-direction:column; overflow:hidden; ' +
    'box-shadow:0 -10px 50px rgba(0,0,0,0.5); border:1px solid rgba(255,255,255,0.08);">' +
      '<div style="flex:1; display:flex; flex-direction:column; padding:14px 16px 18px; ' +
      'overflow:hidden; min-height:0;">' +
        '<div id="' + LCID + '_table_container" style="flex:1; overflow-y:auto; min-height:0; ' +
        'font-size:12px; color:rgba(255,255,255,0.9); line-height:1.5; margin-bottom:12px;">' +
        '</div>' +
        '<button onclick="document.getElementById(''mySidePanel'').style.transform=''translateY(100%)''; ' +
        'try{var s=window[''' + LCID + ''']; if(s)ajaxRequest(s,''sheetClosed'',[]);}catch(e){}" ' +
        'style="width:100%; padding:16px; border-radius:16px; border:none; flex-shrink:0; ' +
        'background:rgba(255,255,255,0.1); color:#fff; font-weight:bold; font-size:16px; cursor:pointer;">' +
          'ЗАКРЫТЬ' +
        '</button>' +
      '</div>' +
    '</div>' +

    '  </div>' +
    '</div>';

  LHTML :=
  // Мы вешаем position:absolute и top/bottom:0, чтобы игнорировать косяки родительских div-ов uniGUI
  '<div id="' + LCID + '_wrap" style="position:absolute; top:0; left:0; right:0; bottom:0; background:' + ABgColor + '; display:flex; flex-direction:column; font-family:' + AFontName + '; overflow:hidden; color:' + AFontColor + ';">' +
  '  <style>' +
  '    #' + LCID + '_wrap * { box-sizing: border-box; } ' +
  '    #' + LCID + '_view_host { position:absolute; top:0; left:0; right:0; bottom:0; border-radius:26px; overflow:hidden; z-index:1; } ' +
  '    #' + LCID + '_view { width:100%%; height:100%%; } ' +
  '    #' + LCID + '_view video { display:block; } ' +
  '    #' + LCID + '_view video.bs_cam_preview { width:100%%; height:100%%; object-fit:contain; } ' +
  '    #' + LCID + '_view canvas { position:absolute; top:0; left:0; width:100%%; height:100%%; object-fit:cover; z-index:3; pointer-events:none; } ' +
  '    #' + LCID + '_view div[style*="border-style: solid"] { display:none !important; } ' +
  '    #' + LCID + '_scan_area { position:absolute; left:50%; top:50%; width:calc(100% * ' + LSScanAreaScale + '); height:calc(100% * ' + LSScanAreaScale + '); transform:translate(-50%,-50%); border-radius:26px; border:2px solid rgba(255,255,255,0.95); box-shadow:0 0 0 9999px rgba(0,0,0,0.48), 0 0 20px rgba(255,255,255,0.25); overflow:hidden; z-index:8; pointer-events:none; } ' +
  '    #' + LCID + '_scan_area::before { content:""; position:absolute; left:10%; right:10%; top:0; height:3px; background:linear-gradient(90deg, transparent, rgba(239,68,68,0.98), transparent); box-shadow:0 0 18px rgba(239,68,68,0.9); animation:' + LCID + '_scan_line 1.7s ease-in-out infinite; } ' +
  '    #' + LCID + '_scan_area::after { content:""; position:absolute; inset:0; border-radius:24px; border:1px solid rgba(255,255,255,0.28); } ' +
  '    #' + LCID + '_scan_area.scanner-paused::before { animation:none; opacity:0; } ' +
  '    @keyframes ' + LCID + '_scan_line { 0% { top:0; opacity:0.1; } 12% { opacity:1; } 50% { opacity:1; } 100% { top:calc(100% - 4px); opacity:0.1; } } ' +
  '    /* Секция сканера - забирает всё свободное место */' +                        // Изменение оступа если режим логина //
  '    .scanner-main-sec { flex: 1; display: flex; flex-direction: column; padding-top: ' + IfThen(LIsLogin, '45', '5') + '%; justify-content: center; align-items: center; min-height: 0; }' +
  '    /* Секция процесса - прижата к низу, высота по контенту */' +
  '    .process-bottom-sec { flex: 0 0 auto; width: 100%; padding-bottom: env(safe-area-inset-bottom); }' +
  '  </style>' +

  '  <div id="' + LCID + '_confetti_box" style="position:absolute; top:0; left:0; width:100%; height:100%; pointer-events:none; z-index:1000;"></div>' +

  '  <div class="scanner-main-sec">' +
       LUserHeader +
//  '    <div style="text-align:center; font-size:' + IntToStr(AFontSize) + 'px; font-weight:800; margin-bottom:10px; opacity:0.9;">' + ATitle + '</div>' +
//  '    <div id="' + LCID + '_box" style="background:#000; border-radius:32px; padding:6px; border:1px solid rgba(255,255,255,0.1); width:90%; max-width:320px; position:relative; box-shadow:0 15px 40px rgba(0,0,0,0.5); aspect-ratio:1/1; overflow:hidden;">' +
//  '      <div id="' + LCID + '_view" style="width:100%; height:100%; border-radius:26px; overflow:hidden;"></div>' +
//  '      <div id="' + LCID + '_scan_area"></div>' +
//  '      <div id="' + LCID + '_cam_stub" onclick="ajaxRequest(' + APanel.JSName + ', ''camStubClick'', [])" style="position:absolute; top:0; left:0; width:100%; height:100%; background:#1e293b; border-radius:26px; display:none; align-items:center; justify-content:center; z-index:9;">' + // Keep camera stub above scan area.
//  '        <div style="color:#94a3b8; font-family:fop; font-size:48px;">&#xf029</div>' +
//  '      </div>' +
//  '      <div id="' + LCID + '_overlay" style="position:absolute; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.4); border-radius:26px; display:flex; align-items:center; justify-content:center; z-index:10; opacity:0; pointer-events:none;">' +
//         LButtonsHTML +
//  '      </div>' +
//  '    </div>' +
//  '  </div>' +

    '    <div style="text-align:center; font-size:' + IntToStr(AFontSize) + 'px; font-weight:800; margin-bottom:10px; opacity:0.9;">' + ATitle + '</div>' +
    '    <div id="' + LCID + '_box" style="background:#000; border-radius:32px; padding:6px; border:1px solid rgba(255,255,255,0.1); width:90%; max-width:320px; position:relative; box-shadow:0 15px 40px rgba(0,0,0,0.5); aspect-ratio:1/1; overflow:hidden;">' +
    '      <div id="' + LCID + '_view_host" style="position:absolute; top:0; left:0; right:0; bottom:0; border-radius:26px; overflow:hidden; z-index:1;" ' +
    '           onmousedown="this.lp=setTimeout(function(){ajaxRequest(' + APanel.JSName + ',''_camLongPress'',[''id=' + LCID + '''])}, 500);" ' +
    '           onmouseup="clearTimeout(this.lp);" onmouseleave="clearTimeout(this.lp);" ' +
    '           ontouchstart="this.lp=setTimeout(function(){ajaxRequest(' + APanel.JSName + ',''_camLongPress'',[''id=' + LCID + '''])}, 500);" ' +
    '           ontouchend="clearTimeout(this.lp);">' +
    '        <div id="' + LCID + '_view" style="width:100%; height:100%; border-radius:26px; overflow:hidden;"></div>' +
    '      </div>' +
    '      <div id="' + LCID + '_decode_sink" style="position:absolute;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none;left:-9999px;top:0;"></div>' +
    '      <div id="' + LCID + '_scan_area"></div>' +
    '      <div id="' + LCID + '_cam_stub" style="position:absolute; top:0; left:0; width:100%; height:100%; background:#1e293b; border-radius:26px; display:none; align-items:center; justify-content:center; z-index:9; cursor:pointer; -webkit-user-select:none; user-select:none;">' +
    '        <div style="color:#94a3b8; font-family:fop; font-size:48px;">&#xf029</div>' +
    '      </div>' +
    '      <div id="' + LCID + '_overlay" style="position:absolute; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.4); border-radius:26px; display:flex; align-items:center; justify-content:center; z-index:10; opacity:0; pointer-events:none;">' +
           LButtonsHTML +
    '      </div>' +
    '    </div>' +
    '  </div>' +


   // БЛОК ПАНЕЛИ ПРОЦЕССА (ПОД СКАННЕРОМ)
  '  <div class="process-bottom-sec">' +
       LProcessPanel +
  '  </div>' +

  '  <audio id="' + LCID + '_beep" src="/files/src-media/scan_beep.mp3" preload="auto"></audio>' +
  LSettingsPanel +
  '</div>';


    if not LIsLogin then

    //    Обычная кнопка выхода без приколов
    //    LHTML := LHTML +
    //      '<div id="' + LCID + '_exit" onclick="ajaxRequest(window[''' + LCID + '''], ''exitScanner'', []);" ' +
    //      'style="position:absolute; top:10px; left:93%; transform:translateX(-50%); width:40px; height:40px; background:#ef4444; border-radius:50%; ' +
    //      'display:flex; align-items:center; justify-content:center; color:white; box-shadow:0 8px 20px rgba(239,68,68,0.7); z-index:999;">' + LSvgExit + '</div>';
    //

    // Кнопка Выход с приколами
    LHTML := LHTML +
      '<style>' +
      '  @keyframes spin { 100% { transform: translate(-50%, -50%) rotate(360deg); } }' +
      '</style>' +
      '<div id="' + LCID + '_exit" onclick="ajaxRequest(window[''' + LCID + '''], ''exitScanner'', []);" ' +
      'style="position:absolute; top:5px; left:95.5%; transform:translateX(-50%); width:27px; height:27px; ' +
      'background:#ef4444; border-radius:50%; display:flex; align-items:center; justify-content:center; ' +
      'color:white; box-shadow:0 0 15px rgba(0,0,0,0.7); z-index:999; overflow:hidden;">' +
        // Этот div внутри создаст крутящуюся линию
        '<div style="position:absolute; width:150%; height:150%; top:50%; left:50%; ' +
        'background:conic-gradient(from 0deg, transparent 70%, #ffffff 100%); ' +
        'transform:translate(-50%, -50%); animation: spin 10s linear infinite;"></div>' +
        // Это подложка, чтобы оставить только кантик
        '<div style="position:absolute; inset:2px; background:#ef4444; border-radius:50%; z-index:1;"></div>' +
        // Сама иконка
        '<div style="position:relative; z-index:2; display:flex;">' + LSvgExit + '</div>' +
      '</div>';

  APanel.JSInterface.JSCall('update', [LHTML]);

  // Основной JS блок
  LJS := Format(
    'var runScanner=function(){ var p=window["%0:s"]; if(!p)return; ' +
    'if(typeof Html5Qrcode==="undefined"){ var s=document.createElement("script"); s.src="/files/src-js/html5-qrcode.min.js"; s.onload=runScanner; document.head.appendChild(s); return; } ' +
    'if(p._scanner){try{p._scanner.stop();}catch(e){}} p._scanner=null; p._scannerCfg=null; ' +
    'p._lastCode=""; p._lastTime=0; p._camActive=true; ' +
    'p._nodes = { eq: false, roll: false }; ' +

    // --- ФУНКЦИЯ: Старт/Стоп камеры ---
    'p.toggleCam=function(state){ ' +
    '  if(state){ ' +
    '    try{if(window.__bsOrientationLock&&window.__bsOrientationLock.isLandscape()){window.__bsOrientationLock.update();return;}}catch(e){} ' +
    '    try{if(window.__bsOrientationLock)window.__bsOrientationLock.tryLock();}catch(e){} ' +
    '  } ' +
    '  p._camActive=state; ' +
    '  var stub=document.getElementById("%0:s_cam_stub"); ' +
    '  var scanArea=document.getElementById("%0:s_scan_area"); ' +
    '  if(scanArea){ scanArea.classList.toggle("scanner-paused", !state); } ' +
    '  if(state){ ' +
    '    stub.style.display="none"; ' +
    '    try{ p._startScan("%2:s"); }catch(e){} ' +
    '  } else { ' +
    '    stub.style.display="flex"; ' +
    '    p._stopScanPipeline(); ' +
    '  }' +
    '}; ' +

    // --- ФУНКЦИЯ: Установка текста для произвольного элемента
    'p.setElementText=function(id, text){ ' +
    '  var el = document.getElementById("' + LCID + '_" + id); ' +
    '  if(!el) { console.error("Element not found: " + id); return; } ' + // Лог в консоль для отладки

       // Если в элементе есть span (ваша кнопка со слоем), меняем текст в span
    '  var target = el.querySelector("span"); ' +
    '  if (target) { ' +
    '    target.textContent = text; ' +
    '  } else { ' +
         // Если это заголовок или простой div, меняем текст напрямую
    '    el.textContent = text; ' +
    '  } ' +
    '}; ' +

     // 2. Управление текстом (НОВОЕ)
    'p.setNodeText=function(node, text){ ' +
    '  var el=document.getElementById("%0:s_node_"+node); ' +
    '  if(el){ var s=el.querySelector("span"); if(s) s.innerText=text; } ' +
    '}; ' +


    'p.setElementSvg = function(id, svgCode) { ' +
    '  var el = document.getElementById("' + LCID + '_" + id); ' +
    '  if(!el) { console.error("Element not found for SVG: " + id); return; } ' +

     // Находим текущий SVG (или создаем временный контейнер, если его нет)
    '  var oldSvg = el.querySelector("svg"); ' +

    '  if (oldSvg) { ' +
       // 1. Устанавливаем стиль перехода и гасим прозрачность
    '    oldSvg.style.transition = "opacity 0.2s ease-in-out"; ' +
    '    oldSvg.style.opacity = "0"; ' +

       // 2. Ждем окончания анимации (200мс), затем меняем код
    '    setTimeout(function() { ' +
    '      oldSvg.outerHTML = svgCode; ' +
         // Находим новый вставленный SVG и плавно проявляем его
    '      var newSvg = el.querySelector("svg"); ' +
    '      if (newSvg) { ' +
    '        newSvg.style.opacity = "0"; ' +
    '        newSvg.style.transition = "opacity 0.2s ease-in-out"; ' +
           // Force reflow для срабатывания анимации
    '        newSvg.getBoundingClientRect(); ' +
    '        newSvg.style.opacity = "1"; ' +
    '      } ' +
    '    }, 200); ' +

    '  } else { ' +
       // Если SVG не было, просто вставляем с анимацией появления
    '    el.insertAdjacentHTML("afterbegin", svgCode); ' +
    '    var freshSvg = el.querySelector("svg"); ' +
    '    freshSvg.style.opacity = "0"; ' +
    '    freshSvg.style.transition = "opacity 0.2s ease-in-out"; ' +
    '    setTimeout(function() { freshSvg.style.opacity = "1"; }, 10); ' +
    '  } ' +
    '}; ' +

    // --- ФУНКЦИЯ: Показать/скрыть панель процесса под сканером ---
    //              Если логин, то скрываем панель процесса
    'p.showProcessPanel=function(show){ ' +
    '  document.getElementById("%0:s_process_panel").style.display = show ? "flex" : "none"; ' +
    '}; p.showProcessPanel('+ IfThen(LIsLogin, 'false', 'true') +'); ' +

    // --- ФУНКЦИЯ: Активация иконок (Оборудование/Рулон) ---
    'p.setNodeActive=function(node, isActive){ ' +
    '  p._nodes[node] = isActive; ' +
    '  var el = document.getElementById("%0:s_node_" + node); ' +
    '  if(el){ ' +
    '    el.style.opacity = isActive ? "1" : "0.3"; ' +
    '    el.style.color = isActive ? "#DEE64C" : "#fff"; ' +
    '    el.style.transform = isActive ? "scale(1.1)" : "scale(1)"; ' +
    '  } ' +
    '  var line = document.getElementById("'+ LCID +'_link_line"); ' +
    '  line.style.opacity = "1"; ' +
    '  var block = document.getElementById("%0:s_block_end"); ' +
    '  if(p._nodes.eq || p._nodes.roll){ ' +
    '    line.style.height = "40px"; ' +
    '    block.style.opacity = "1"; block.style.transform = "translateY(0)"; ' +
    '  } else { ' +
    '    line.style.height = "0px"; ' +
    '    block.style.opacity = "0"; block.style.transform = "translateY(-20px)"; ' +
    '  } ' +
    '}; ' +

    // --- ФУНКЦИЯ: Управление кнопками "Начать"/"Закончить" ---

      'p.setButtonsState=function(canStart, canEnd){ ' +
      '  var bs = document.getElementById("' + LCID + '_btn_action_start"); ' +
      '  var be = document.getElementById("' + LCID + '_btn_action_end"); ' +
      '  var blk = document.getElementById("' + LCID + '_block_end"); ' + // Ищем общую панель

         // Если кнопок нет — выходим молча, без ошибок в консоль
      '  if(!bs || !be) return; ' +

      '  var apply = function(el, show, hasMargin) { ' +
      '    if(show) { ' +
      '      el.style.flex = "1"; ' +
      '      el.style.maxWidth = "500px"; ' +
      '      el.style.opacity = "1"; ' +
      '      el.style.padding = "20px"; ' +
      '      el.style.pointerEvents = "auto"; ' +
      '      el.style.margin = hasMargin ? "0 10px" : "0"; ' +
      '    } else { ' +
      '      el.style.flex = "0"; ' +
      '      el.style.maxWidth = "0px"; ' +
      '      el.style.opacity = "0"; ' +
      '      el.style.padding = "20px 0"; ' +
      '      el.style.pointerEvents = "none"; ' +
      '      el.style.margin = "0"; ' +
      '    } ' +
      '  }; ' +

         // Применяем стили к кнопкам
      '  apply(bs, canStart, (canStart && canEnd)); ' +
      '  apply(be, canEnd, (canStart && canEnd)); ' +

         // ЛОГИКА СКРЫТИЯ ВСЕЙ ПАНЕЛИ (только если она найдена)
      '  if(blk) { ' +
      '    if(!canStart && !canEnd) { ' +
      '      blk.style.opacity = "0"; ' +
      '      blk.style.transform = "translateY(-20px)"; ' +
      '      blk.style.pointerEvents = "none"; ' +
      '    } else { ' +
      '      blk.style.opacity = "1"; ' +
      '      blk.style.transform = "translateY(0px)"; ' +
      '      blk.style.pointerEvents = "auto"; ' +
      '    } ' +
      '  } ' +
      '}; '  +

    // --- ЛОГИКА ДОЛГОГО НАЖАТИЯ "Закончить" ---
    'var btnEnd = document.getElementById("%0:s_btn_action_end"); ' +
    'var fillEnd = document.getElementById("%0:s_btn_end_fill"); ' +
    'var pressTimer; var isLong=false; ' +
    'var pressStart = function(e){ ' +
    '  if(btnEnd.style.pointerEvents==="none") return; ' +
    '  isLong=false; fillEnd.style.transition="width 2s linear"; fillEnd.style.width="100%%"; ' +
    '  pressTimer=setTimeout(function(){ ' +
    '    isLong=true; fillEnd.style.width="0%%"; ajaxRequest(p, "actionEndForce", []); ' +
    '  }, 2000); ' +
    '}; ' +

    'var pressEnd = function(e){ ' +
    '  clearTimeout(pressTimer); fillEnd.style.transition="none"; fillEnd.style.width="0%%"; ' +
    // Отправление ивента по нажатию на кнопку "закрыть"
    '  if(!isLong && e.type==="mouseup"){ ajaxRequest(p, "actionEndNormal", []); } ' +
    '}; ' +
    'btnEnd.addEventListener("mousedown", pressStart); btnEnd.addEventListener("touchstart", pressStart); ' +
    'btnEnd.addEventListener("mouseup", pressEnd); btnEnd.addEventListener("mouseleave", pressEnd); btnEnd.addEventListener("touchend", pressEnd); ' +

    // --- ФУНКЦИЯ: Отрисовка инфо-панели (карточки + таблицы) ---
    'p.renderTable=function(jsonStr){ ' +
    '  var cont=document.getElementById("%0:s_table_container"); ' +
    '  var esc=function(s){return String(s||"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/"/g,"&quot;");}; ' +
    '  var mkBadge=function(t,b,f,s){s=s||30;var z=t.length>2?7:(t.length>1?9:11);' +
    '    return ''<span style="display:inline-flex;align-items:center;justify-content:center;width:''+s+''px;height:''+s+''px;''+' +
    '    ''border-radius:50%%;background:''+b+'';color:''+(f||"#fff")+'';font-size:''+z+''px;font-weight:700;line-height:1;">''+esc(t)+''</span>'';}; ' +
    '  var mkCard=function(badge,title,sub,meta){var h=' +
    '    ''<div style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.1);border-radius:12px;padding:8px 10px;margin-bottom:10px;">''+' +
    '    ''<table style="width:100%%;border-collapse:collapse;"><tr>''+' +
    '    ''<td style="width:1px;vertical-align:top;padding-right:8px;">''+badge+''</td>''+' +
    '    ''<td style="vertical-align:top;"><div style="font-size:13px;font-weight:700;color:#fff;line-height:1.25;">''+title+''</div>''; ' +
    '    if(sub)h+=''<div style="font-size:10px;color:#989FC0;margin-top:1px;">''+sub+''</div>''; ' +
    '    if(meta)h+=''<div style="font-size:10px;color:#94a3b8;margin-top:5px;line-height:1.45;">''+meta+''</div>''; ' +
    '    return h+''</td></tr></table></div>'';}; ' +
    '  var rowBadge=function(n,st){var s=(st||"").toLowerCase(),bg="rgba(100,116,139,0.25)",fg="#94a3b8";' +
    '    if(s.indexOf("начат")>=0||s.indexOf("старт")>=0){bg="rgba(239,68,68,0.28)";fg="#ef4444";}' +
    '    else if(s.indexOf("оконч")>=0||s.indexOf("заверш")>=0){bg="rgba(16,185,129,0.28)";fg="#10b981";}' +
    '    return mkBadge(String(n),bg,fg,22);}; ' +
    '  var mkListTable=function(cap,heads,rows){var h="",i,r,c,al; ' +
    '    if(cap)h+=''<div style="font-size:10px;font-weight:700;color:#94a3b8;margin:0 0 4px 2px;">''+cap+''</div>''; ' +
    '    h+=''<table style="width:100%%;border-collapse:collapse;font-size:11px;"><thead><tr style="color:#64748b;font-size:9px;text-transform:uppercase;">''; ' +
    '    for(c=0;c<heads.length;c++){al=heads[c]==="Кол"?"right":"left";' +
    '      h+=''<th style="padding:2px 4px;text-align:''+al+'';">''+heads[c]+''</th>'';} ' +
    '    h+=''</tr></thead><tbody>''; ' +
    '    for(i=0;i<rows.length;i++){r=rows[i];h+=''<tr style="border-top:1px solid rgba(255,255,255,0.07);">''; ' +
    '      for(c=0;c<r.length;c++){al=heads[c]==="Кол"?"right":"left";' +
    '        h+=''<td style="padding:5px 4px;vertical-align:top;text-align:''+al+'';">''+r[c]+''</td>'';} ' +
    '      h+=''</tr>'';} return h+''</tbody></table>'';}; ' +
    '  var metaJoin=function(row,keys){var p=[],k;for(k=0;k<keys.length;k++)' +
    '    if(row[keys[k]]!==undefined&&row[keys[k]]!=="")p.push(keys[k]+": <b>"+esc(row[keys[k]])+"</b>");' +
    '    return p.join(" · ");}; ' +
    '  try { ' +
    '    var parsed=JSON.parse(jsonStr), html="", data, row, pr, parts, meta, i, rows, r; ' +
    '    if(parsed&&parsed.isAssembly){ ' +
    '      pr=parsed.parent||{}; parts=parsed.parts||[]; ' +
    '      meta=metaJoin(pr,["Кол-во","Кол-во блоков","Название заказа","Дата создания"]); ' +
    '      html=mkCard(mkBadge("SBR","#007AFF","#fff",32),esc(pr["Имя"]||"—"),esc(pr["Артикул"]||""),meta); ' +
    '      if(parts.length){rows=[];for(i=0;i<parts.length;i++){row=parts[i];rows.push([' +
    '        mkBadge(String(i+1),"rgba(0,122,255,0.22)","#007AFF",22),' +
    '        ''<div style="font-weight:600;color:#fff;line-height:1.2;">''+esc(row["Имя"]||row["Артикул"]||"—")+''</div>''+' +
    '        ''<div style="font-size:9px;color:#94a3b8;">''+esc(row["Артикул"]||"")+''</div>'',' +
    '        ''<span style="color:#DEE64C;font-weight:700;">''+esc(row["Кол-во"]||"")+''</span>'']);} ' +
    '        html+=mkListTable("Состав ("+parts.length+")",["","Наименование","Кол"],rows);} ' +
    '      cont.innerHTML=html; return; ' +
    '    } ' +
    '    data=Array.isArray(parsed)?parsed:[]; ' +
    '    if(!data.length){cont.innerHTML="Нет данных";return;} ' +
    '    row=data[0]; ' +
    '    if(row["Диапазон"]!==undefined){ ' +
    '      html=mkCard(mkBadge("Б","#DEE64C","#1a1a1a",30),"Блок "+esc(row["Диапазон"]||"—"),' +
    '        "Рулон: "+esc(row["Рулон"]||""),metaJoin(row,["Заказ"])); ' +
    '      if(data.length>1){rows=[];for(i=1;i<data.length;i++){r=data[i];rows.push([esc(r["Диапазон"]||""),esc(r["Рулон"]||""),esc(r["Заказ"]||"")]);} ' +
    '        html+=mkListTable("Ещё диапазоны",["Диапазон","Рулон","Заказ"],rows);} ' +
    '      cont.innerHTML=html; return; ' +
    '    } ' +
    '    if(row["Статус"]!==undefined){ ' +
    '      html=mkCard(mkBadge("Ж","#64748b","#fff",30),"Журнал операций",' +
    '        esc(row["Оборудование"]||""),"Последние "+data.length+" записей"); ' +
    '      rows=[];for(i=0;i<data.length;i++){r=data[i];rows.push([' +
    '        rowBadge(i+1,r["Статус"]),' +
    '        ''<span style="font-weight:600;color:#fff;">''+esc(r["Статус"]||"")+''</span>'',' +
    '        esc(r["Оператор"]||""),esc(r["Дата"]||"")]);} ' +
    '      html+=mkListTable("",["","Статус","Оператор","Дата"],rows); ' +
    '      cont.innerHTML=html; return; ' +
    '    } ' +
    '    if(row["Имя"]!==undefined||row["Артикул"]!==undefined){ ' +
    '      meta=metaJoin(row,["Кол-во","Кол-во блоков","Название заказа","Дата создания","Код"]); ' +
    '      cont.innerHTML=mkCard(mkBadge("Р","#5856D6","#fff",30),esc(row["Имя"]||row["Артикул"]||"—"),esc(row["Артикул"]||""),meta); return; ' +
    '    } ' +
    '    if(data.length===1){ ' +
    '      meta="";for(i=0;i<Object.keys(row).length;i++){var k=Object.keys(row)[i];' +
    '        if(i)meta+=" · ";meta+="<b>"+esc(k)+"</b>: "+esc(row[k]);} ' +
    '      cont.innerHTML=mkCard(mkBadge("i","#64748b","#fff",30),"Информация","",meta); return; ' +
    '    } ' +
    '    rows=[];for(i=0;i<data.length;i++){r=data[i];rows.push(Object.keys(r).map(function(k){return esc(r[k]);}));} ' +
    '    html+=mkListTable("Записи ("+data.length+")",Object.keys(row),rows); ' +
    '    cont.innerHTML=html; ' +
    '  } catch(e){ cont.innerHTML="'+IfThen(ARollInfoJson.Length < 5, 'Нет данных' , 'Не выбрано оборудование')+'"; } ' +
    '}; ' +

    // --- ФУНКЦИЯ: Конфетти ---
    //
    //     Бумажное конфетти(наскоментить и закоментить салют)
    //
    //    'p.fireConfetti=function(){ ' +
    //    '  var box = document.getElementById("%0:s_confetti_box"); box.innerHTML=""; ' +
    //    '  var colors=["#ef4444","#3b82f6","#10b981","#f59e0b","#8b5cf6"]; ' +
    //    '  for(var i=0; i<60; i++){ ' +
    //    '    var c = document.createElement("div"); ' +
    //    '    c.style.position="absolute"; c.style.width="12px"; c.style.height="12px"; ' +
    //    '    c.style.backgroundColor=colors[Math.floor(Math.random()*colors.length)]; ' +
    //    '    c.style.left=Math.random()*100+"%%"; c.style.top="-20px"; ' +
    //    '    c.style.opacity=Math.random()+0.5; ' +
    //    '    c.style.transition="transform "+(Math.random()*2+1)+"s ease-in, top "+(Math.random()*2+1)+"s ease-in"; ' +
    //    '    box.appendChild(c); ' +
    //    '    (function(el){ setTimeout(function(){ el.style.top="120%%"; el.style.transform="rotate("+(Math.random()*360)+"deg)"; }, 50); })(c); ' +
    //    '  } ' +
    //    '}; ' +
    //

    //    ---- Салют(начало) ----
    'p.fireConfetti = function() { ' +
    '  var box = document.getElementById("%0:s_confetti_box"); ' +
    '  box.innerHTML = ""; ' +
    '  var canvas = document.createElement("canvas"); ' +
    '  canvas.style.position = "absolute"; canvas.style.left="0"; canvas.style.top="0"; ' +
    '  canvas.width = box.offsetWidth; canvas.height = box.offsetHeight; ' +
    '  box.appendChild(canvas); ' +
    '  var ctx = canvas.getContext("2d"); ' +
    '  var particles = []; ' +
    '  var colors = ["#ff0000", "#ffd700", "#00ff00", "#00ffff", "#ff00ff", "#ffffff"]; ' +

    // Создаем взрыв в центре или случайных местах
    '  function createFirework(x, y) { ' +
    '    var count = 80; ' +
    '    var color = colors[Math.floor(Math.random() * colors.length)]; ' +
    '    for (var i = 0; i < count; i++) { ' +
    '      var angle = Math.random() * Math.PI * 2; ' +
    '      var speed = Math.random() * 6 + 2; ' +
    '      particles.push({ ' +
    '        x: x, y: y, ' +
    '        vx: Math.cos(angle) * speed, ' +
    '        vy: Math.sin(angle) * speed, ' +
    '        radius: Math.random() * 3 + 1, ' +
    '        color: color, ' +
    '        opacity: 1, ' +
    '        gravity: 0.12 ' +
    '      }); ' +
    '    } ' +
    '  } ' +

    '  function animate() { ' +
    '    ctx.clearRect(0, 0, canvas.width, canvas.height); ' +
    '    for (var i = 0; i < particles.length; i++) { ' +
    '      var p = particles[i]; ' +
    '      p.vx *= 0.98; p.vy *= 0.98; ' + // Сопротивление воздуха
    '      p.vy += p.gravity; ' +          // Гравитация
    '      p.x += p.vx; p.y += p.vy; ' +
    '      p.opacity -= 0.015; ' +         // Затухание
    '      if (p.opacity > 0) { ' +
    '        ctx.beginPath(); ' +
    '        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2); ' +
    '        ctx.fillStyle = p.color; ' +
    '        ctx.globalAlpha = p.opacity; ' +
    '        ctx.shadowBlur = 10; ctx.shadowColor = p.color; ' + // Эффект свечения (искры)
    '        ctx.fill(); ' +
    '      } else { particles.splice(i, 1); i--; } ' +
    '    } ' +
    '    if (particles.length > 0) requestAnimationFrame(animate); ' +
    '    else { box.innerHTML = ""; } ' +
    '  } ' +

  // Запускаем 3 салюта в разных точках
  '   ' +
  '  createFirework(canvas.width * 0.5, canvas.height * 0.4); ' +
  '  setTimeout(function(){ createFirework(canvas.width * 0.3, canvas.height * 0.5); }, 300); ' +
  '  setTimeout(function(){ createFirework(canvas.width * 0.7, canvas.height * 0.5); }, 600); ' +
  '  animate(); ' +
  '}; ' +
   // --- Салют(конец) ----


    // --- СКАНЕР: настройки (LocalStorage) ---
    'var SCAN_SETTINGS_KEY="badsticker_scanner_settings"; ' +

    // defaults / load / save
    'p._defaultScanSettings=function(){ ' +
    '  return { facingMode:"environment", cameraId:"", fps:10, qrboxScale:%1:s, fullFrame:false, ' +
    '    aspectMode:"1", disableFlip:false, useBarCodeDetector:false, debounceMs:2500, autoStartCamera:false, ' +
    '    verbose:false, videoWidth:0, videoHeight:0, zoom:1, disableZoom:false, brightnessPct:100, contrastPct:100, ' +
    '    preprocessMode:"off", preprocessThreshold:128, decodePreprocessed:false, ' +
    '    formats:{qr:true,c128:false,ean13:false,c39:false,dm:false} }; ' +
    '}; ' +
    'p._loadScanSettings=function(){ ' +
    '  var d=p._defaultScanSettings(); ' +
    '  try{ ' +
    '    var s=localStorage.getItem(SCAN_SETTINGS_KEY); ' +
    '    if(s){ var o=JSON.parse(s); for(var k in o){ if(o.hasOwnProperty(k)) d[k]=o[k]; } ' +
    '      if(o.formats) d.formats=Object.assign(d.formats,o.formats); ' +
    '    } ' +
    '  }catch(e){} return d; ' +
    '}; ' +
    'p._saveScanSettings=function(s){ try{ localStorage.setItem(SCAN_SETTINGS_KEY, JSON.stringify(s)); }catch(e){} }; ' +
    'p._scanSettings=p._loadScanSettings(); ' +
    'p._CAMERA_SETTING_KEYS=["facingMode","cameraId","videoWidth","videoHeight","aspectMode"]; ' +
    'p._extractProfileSettings=function(s){ ' +
    '  var out={}, i, k, cam=p._CAMERA_SETTING_KEYS; ' +
    '  s=s||{}; ' +
    '  for(i=0;i<cam.length;i++){ /* skip camera keys */ } ' +
    '  for(k in s){ if(!s.hasOwnProperty(k)) continue; if(cam.indexOf(k)>=0) continue; ' +
    '    if(k==="formats") out.formats=Object.assign({}, s.formats||{}); else out[k]=s[k]; } ' +
    '  return out; ' +
    '}; ' +
    'p._mergeProfileSettings=function(profile){ ' +
    '  var cur=p._scanSettings||p._loadScanSettings(), merged=Object.assign({}, cur, profile||{}), i, cam=p._CAMERA_SETTING_KEYS; ' +
    '  if(profile&&profile.formats) merged.formats=Object.assign({}, cur.formats||{}, profile.formats); ' +
    '  for(i=0;i<cam.length;i++) merged[cam[i]]=cur[cam[i]]; ' +
    '  return merged; ' +
    '}; ' +
    'p.applyScannerProfile=function(jsonOrObj, restart){ ' +
    '  var profile=typeof jsonOrObj==="string"?JSON.parse(jsonOrObj):jsonOrObj; ' +
    '  p._scanSettings=p._mergeProfileSettings(profile||{}); ' +
    '  p._saveScanSettings(p._scanSettings); ' +
    '  p._fillSettingsForm(); ' +
    '  p._applyScanSettings(!!restart); ' +
    '}; ' +
    'p._flushPendingProfileApply=function(){ ' +
    '  if(!p._pendingProfileApply && window.__bsScanProfilePending){ ' +
    '    p._pendingProfileApply=window.__bsScanProfilePending; ' +
    '    delete window.__bsScanProfilePending; ' +
    '  } ' +
    '  if(!p._pendingProfileApply) return; ' +
    '  var pa=p._pendingProfileApply; p._pendingProfileApply=null; ' +
    '  p.applyScannerProfile(pa.cfg, pa.restart); ' +
    '}; ' +
    'p._saveProfileToServer=function(){ ' +
    '  p._ssBtnFeedback("save_profile","press"); ' +
    '  p._ssBtnFeedback("save_profile","busy"); ' +
    '  p._readSettingsForm(); ' +
    '  var profile=p._extractProfileSettings(p._scanSettings); ' +
    '  ajaxRequest(p,"saveScannerProfile",["config="+encodeURIComponent(JSON.stringify(profile))]); ' +
    '}; ' +
    'p._applyGlobalProfileFromServer=function(){ ' +
    '  p._ssBtnFeedback("apply_global","press"); ' +
    '  p._ssBtnFeedback("apply_global","busy"); ' +
    '  ajaxRequest(p,"applyGlobalScannerProfile",[]); ' +
    '}; ' +

    // визуальная рамка сканирования
    'p._updateScanAreaVisual=function(){ ' +
    '  var el=document.getElementById("%0:s_scan_area"); if(!el) return; ' +
    '  var sc=p._scanSettings.fullFrame ? 0.95 : p._scanSettings.qrboxScale; ' +
    '  el.style.width=el.style.height="calc(100%% * "+sc+")"; ' +
    '}; ' +

    // html5-qrcode: форматы и инстанс
    'p._getFormatsList=function(){ ' +
    '  var f=[], m=p._scanSettings.formats||{}; ' +
    '  if(typeof Html5QrcodeSupportedFormats!=="undefined"){ ' +
    '    if(m.qr!==false) f.push(Html5QrcodeSupportedFormats.QR_CODE); ' +
    '    if(m.c128) f.push(Html5QrcodeSupportedFormats.CODE_128); ' +
    '    if(m.ean13) f.push(Html5QrcodeSupportedFormats.EAN_13); ' +
    '    if(m.c39) f.push(Html5QrcodeSupportedFormats.CODE_39); ' +
    '    if(m.dm) f.push(Html5QrcodeSupportedFormats.DATA_MATRIX); ' +
    '    if(!f.length) f.push(Html5QrcodeSupportedFormats.QR_CODE); ' +
    '  } return f; ' +
    '}; ' +
    'p._usesPreprocessDecode=function(){ ' +
    '  var s=p._scanSettings; ' +
    '  return !!s.decodePreprocessed && (s.preprocessMode||"off")!=="off"; ' +
    '}; ' +
    'p._ensureDecodeSink=function(){ ' +
    '  var id="%0:s_decode_sink", el=document.getElementById(id); ' +
    '  if(!el){ ' +
    '    var box=document.getElementById("%0:s_box"); ' +
    '    el=document.createElement("div"); el.id=id; ' +
    '    el.style.cssText="position:fixed;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none;left:-9999px;top:0;z-index:-1;"; ' +
    '    if(box) box.appendChild(el); else document.body.appendChild(el); ' +
    '  } return id; ' +
    '}; ' +
    'p._ensureScanner=function(){ ' +
    '  var ctor={}, fmts=p._getFormatsList(); ' +
    '  if(fmts.length) ctor.formatsToSupport=fmts; ' +
    '  if(p._scanSettings.verbose) ctor.verbose=true; ' +
    '  if(p._scanSettings.useBarCodeDetector) ctor.experimentalFeatures={useBarCodeDetectorIfSupported:true}; ' +
    '  var elId=p._usesPreprocessDecode()?p._ensureDecodeSink():"%0:s_view"; ' +
    '  var needRecreate=!p._scanner; ' +
    '  if(p._scanner && p._scannerElId!==elId) needRecreate=true; ' +
    '  if(p._scanner && p._scannerCfg) needRecreate=needRecreate||JSON.stringify(p._scannerCfg)!==JSON.stringify(ctor); ' +
    '  if(needRecreate){ ' +
    '    if(p._scanner){ try{p._scanner.stop();}catch(e){} try{p._scanner.clear();}catch(e){} } ' +
    '    p._scanner=new Html5Qrcode(elId, ctor); p._scannerCfg=ctor; p._scannerElId=elId; ' +
    '  } ' +
    '}; ' +

    // конфиг камеры и сканирования
    'p._getCameraConfig=function(){ ' +
    '  var s=p._scanSettings; ' +
    '  if(s.facingMode==="exact" && s.cameraId) return s.cameraId; ' +
    '  if(s.facingMode==="exact") return {facingMode:"environment"}; ' +
    '  return {facingMode:s.facingMode||"environment"}; ' +
    '}; ' +
    'p._buildScanConfig=function(){ ' +
    '  var s=p._scanSettings, cfg={fps:Math.min(60,Math.max(1,parseInt(s.fps,10)||10)), disableFlip:!!s.disableFlip}; ' +
    '  if(s.aspectMode && s.aspectMode!=="0") cfg.aspectRatio=parseFloat(s.aspectMode)||1; ' +
    '  if(!s.fullFrame){ ' +
    '    cfg.qrbox=function(vw,vh){ ' +
    '      var sc=parseFloat(s.qrboxScale)||%1:s; ' +
    '      var edge=Math.floor(Math.min(vw,vh)*sc); ' +
    '      return {width:edge,height:edge}; ' +
    '    }; ' +
    '  } ' +
    '  if(s.videoWidth>0 || s.videoHeight>0){ ' +
    '    cfg.videoConstraints={}; ' +
    '    if(s.videoWidth>0) cfg.videoConstraints.width=s.videoWidth; ' +
    '    if(s.videoHeight>0) cfg.videoConstraints.height=s.videoHeight; ' +
    '    if(s.facingMode && s.facingMode!=="exact") cfg.videoConstraints.facingMode=s.facingMode; ' +
    '  } ' +
    '  return cfg; ' +
    '}; ' +

    // video track: zoom / brightness / contrast
    'p._getVideoEl=function(){ ' +
    '  var view=document.getElementById("%0:s_view"); ' +
    '  return view ? view.querySelector("video") : null; ' +
    '}; ' +
    'p._getVideoTrack=function(){ ' +
    '  var v=p._getVideoEl(); ' +
    '  if(!v || !v.srcObject) return null; ' +
    '  var tr=v.srcObject.getVideoTracks(); ' +
    '  return tr.length ? tr[0] : null; ' +
    '}; ' +
    'p._clamp=function(val, cap){ ' +
    '  if(!cap || cap.min===undefined) return val; ' +
    '  var max=(cap.max!==undefined)?cap.max:val; ' +
    '  return Math.max(cap.min, Math.min(max, val)); ' +
    '}; ' +
    'p._pctToCap=function(pct, cap){ ' +
    '  if(!cap || cap.min===undefined || cap.max===undefined) return null; ' +
    '  var t=(parseFloat(pct)-50)/150; ' +
    '  return cap.min + t*(cap.max-cap.min); ' +
    '}; ' +
    'p._syncTrackSliders=function(){ ' +
    '  var s=p._scanSettings, track=p._getVideoTrack(); ' +
    '  var zEl=document.getElementById("%0:s_ss_zoom"); ' +
    '  var zLbl=document.getElementById("%0:s_ss_zoom_val"); ' +
    '  if(!zEl) return; ' +
    '  var zMin=1, zMax=10, zStep=0.1; ' +
    '  if(track && track.getCapabilities){ ' +
    '    var caps=track.getCapabilities(); ' +
    '    if(caps.zoom){ zMin=caps.zoom.min; zMax=caps.zoom.max; zStep=caps.zoom.step||0.1; } ' +
    '  } ' +
    '  zEl.min=zMin; zEl.max=zMax; zEl.step=zStep; ' +
    '  var zVal=p._clamp(parseFloat(s.zoom)||zMin, {min:zMin,max:zMax}); ' +
    '  zEl.value=zVal; if(zLbl) zLbl.textContent=parseFloat(zVal).toFixed(1); ' +
    '  p._updateZoomUi(); ' +
    '}; ' +
    'p._updateZoomUi=function(){ ' +
    '  var off=!!p._scanSettings.disableZoom; ' +
    '  var zEl=document.getElementById("%0:s_ss_zoom"); ' +
    '  if(zEl){ zEl.disabled=off; zEl.style.opacity=off?"0.35":"1"; } ' +
    '}; ' +

    // препроцессинг превью (CSS + canvas бинаризация)
    'p._buildFilterCss=function(){ ' +
    '  var s=p._scanSettings, mode=s.preprocessMode||"off"; ' +
    '  var br=(parseFloat(s.brightnessPct)||100)/100; ' +
    '  var ct=(parseFloat(s.contrastPct)||100)/100; ' +
    '  var parts=[]; ' +
    '  if(mode==="contrast") parts.push("grayscale(1)","contrast(2.4)","brightness(1.08)"); ' +
    '  else if(mode==="bw") parts.push("grayscale(1)","contrast(4.5)","brightness(1.12)"); ' +
    '  parts.push("brightness("+br+")","contrast("+ct+")"); ' +
    '  return parts.join(" "); ' +
    '}; ' +
    'p._drawPreprocessToCanvas=function(ctx,dw,dh,v){ ' +
    '  var s=p._scanSettings, mode=s.preprocessMode||"off"; ' +
    '  ctx.save(); ' +
    '  ctx.filter=(mode!=="binary")?p._buildFilterCss():"none"; ' +
    '  ctx.drawImage(v,0,0,dw,dh); ' +
    '  ctx.filter="none"; ' +
    '  if(mode==="binary"){ ' +
    '    var img=ctx.getImageData(0,0,dw,dh), d=img.data, th=parseInt(s.preprocessThreshold,10)||128; ' +
    '    for(var i=0;i<d.length;i+=4){ ' +
    '      var g=0.299*d[i]+0.587*d[i+1]+0.114*d[i+2]; ' +
    '      var bin=g>=th?255:0; d[i]=d[i+1]=d[i+2]=bin; ' +
    '    } ' +
    '    ctx.putImageData(img,0,0); ' +
    '  } ' +
    '  ctx.restore(); ' +
    '}; ' +
    'p._shouldUseCanvasPreview=function(){ ' +
    '  return (p._scanSettings.preprocessMode||"off")==="binary"; ' +
    '}; ' +
    'p._stopPreprocessCanvas=function(){ ' +
    '  if(p._preprocessRaf){ cancelAnimationFrame(p._preprocessRaf); p._preprocessRaf=0; } ' +
    '  var c=document.getElementById("%0:s_preprocess_cv"); if(c) c.remove(); ' +
    '  var v=p._getVideoEl(); if(v){ v.style.opacity="1"; } ' +
    '}; ' +
    'p._preprocessCanvasLoop=function(){ ' +
    '  if(!p._camActive || !p._shouldUseCanvasPreview()){ p._stopPreprocessCanvas(); return; } ' +
    '  var v=p._getVideoEl(), c=document.getElementById("%0:s_preprocess_cv"); ' +
    '  if(!v || !c){ p._preprocessRaf=0; return; } ' +
    '  var ctx=c.getContext("2d"); ' +
    '  var vw=v.videoWidth||0, vh=v.videoHeight||0; ' +
    '  if(vw>0 && vh>0){ ' +
    '    var dw=Math.min(vw,640), dh=Math.round(vh*(dw/vw)); ' +
    '    if(c.width!==dw){ c.width=dw; c.height=dh; } ' +
    '    p._drawPreprocessToCanvas(ctx,dw,dh,v); ' +
    '    if(p._shouldUseCanvasPreview()) v.style.opacity="0"; ' +
    '  } ' +
    '  p._preprocessRaf=requestAnimationFrame(p._preprocessCanvasLoop); ' +
    '}; ' +
    'p._startPreprocessCanvas=function(){ ' +
    '  p._stopPreprocessCanvas(); ' +
    '  var view=document.getElementById("%0:s_view"), v=p._getVideoEl(); ' +
    '  if(!view || !v) return; ' +
    '  var c=document.createElement("canvas"); ' +
    '  c.id="%0:s_preprocess_cv"; ' +
    '  c.style.cssText="position:absolute;top:0;left:0;width:100%%;height:100%%;object-fit:cover;z-index:3;pointer-events:none;"; ' +
    '  view.appendChild(c); ' +
    '  v.style.filter=""; v.style.transform=""; v.style.opacity="1"; ' +
    '  p._preprocessCanvasLoop(); ' +
    '}; ' +
    'p._applyPreprocess=function(){ ' +
    '  var v=p._getVideoEl(); if(!v) return; ' +
    '  if(p._shouldUseCanvasPreview()){ p._startPreprocessCanvas(); return; } ' +
    '  p._stopPreprocessCanvas(); ' +
    '  p._applyVideoFilters(); ' +
    '}; ' +

    'p._applyVideoFilters=function(){ ' +
    '  var v=p._getVideoEl(); if(!v) return; ' +
    '  if(p._shouldUseCanvasPreview()) return; ' +
    '  if(p._usesPreprocessDecode()){ ' +
    '    var s=p._scanSettings; ' +
    '    v.style.filter=p._buildFilterCss(); ' +
    '    v.style.transform=""; v.style.transformOrigin=""; ' +
    '    if(!s.disableZoom && !p._trackZoomOk && (parseFloat(s.zoom)||1)>1){ ' +
    '      v.style.transformOrigin="center center"; ' +
    '      v.style.transform="scale("+parseFloat(s.zoom)+")"; ' +
    '    } ' +
    '    return; ' +
    '  } ' +
    '  var s=p._scanSettings, mode=s.preprocessMode||"off"; ' +
    '  if(mode!=="off"){ ' +
    '    v.style.filter=p._buildFilterCss(); ' +
    '  } else { v.style.filter=""; } ' +
    '  v.style.transform=""; v.style.transformOrigin=""; ' +
    '  if(s.disableZoom) return; ' +
    '  if(!p._trackZoomOk && (parseFloat(s.zoom)||1)>1){ ' +
    '    v.style.transformOrigin="center center"; ' +
    '    v.style.transform="scale("+parseFloat(s.zoom)+")"; ' +
    '  } ' +
    '}; ' +
    'p._applyTrackSettings=function(){ ' +
    '  var s=p._scanSettings, track=p._getVideoTrack(); ' +
    '  p._trackZoomOk=false; ' +
    '  p._applyPreprocess(); ' +
    '  if(!track || !track.applyConstraints) return Promise.resolve(); ' +
    '  var caps=track.getCapabilities ? track.getCapabilities() : {}; ' +
    '  var adv={}, flat={}; ' +
    '  if(!s.disableZoom && caps.zoom && s.zoom){ flat.zoom=p._clamp(parseFloat(s.zoom), caps.zoom); } ' +
    '  if(caps.brightness && s.brightnessPct){ ' +
    '    var b=p._pctToCap(s.brightnessPct, caps.brightness); if(b!==null) adv.brightness=b; ' +
    '  } ' +
    '  if(caps.contrast && s.contrastPct){ ' +
    '    var c=p._pctToCap(s.contrastPct, caps.contrast); if(c!==null) adv.contrast=c; ' +
    '  } ' +
    '  var pFlat=Object.keys(flat).length ? track.applyConstraints(flat) : Promise.resolve(); ' +
    '  return pFlat.then(function(){ p._trackZoomOk=!!flat.zoom; p._applyPreprocess(); ' +
    '    if(!Object.keys(adv).length) return; ' +
    '    return track.applyConstraints({advanced:[adv]}); ' +
    '  }).catch(function(err){ ' +
    '    if(p._scanSettings.verbose) console.warn("track constraints", err); ' +
    '    p._applyPreprocess(); ' +
    '  }); ' +
    '}; ' +

    // canvas decode pipeline (direct canvas decode, no scanFile DOM)
    'p._stopPreprocessScanTimer=function(){ ' +
    '  if(p._preprocessScanTimer){ clearInterval(p._preprocessScanTimer); p._preprocessScanTimer=0; } ' +
    '  p._scanBusy=false; ' +
    '}; ' +
    'p._stopCameraStream=function(){ ' +
    '  if(p._cameraStream){ p._cameraStream.getTracks().forEach(function(t){ t.stop(); }); p._cameraStream=null; } ' +
    '}; ' +
    'p._stopScanPipeline=function(){ ' +
    '  p._stopPreprocessScanTimer(); ' +
    '  p._stopCameraStream(); ' +
    '  p._stopPreprocessCanvas(); ' +
    '  if(p._scanner){ try{p._scanner.stop();}catch(e){} } ' +
    '}; ' +
    'p._openCameraStream=function(){ ' +
    '  p._stopCameraStream(); ' +
    '  var cam=p._getCameraConfig(), s=p._scanSettings, vc={}; ' +
    '  if(typeof cam==="string") vc.deviceId={exact:cam}; ' +
    '  else for(var k in cam){ if(cam.hasOwnProperty(k)) vc[k]=cam[k]; } ' +
    '  if(s.videoWidth>0) vc.width=s.videoWidth; ' +
    '  if(s.videoHeight>0) vc.height=s.videoHeight; ' +
    '  if(s.aspectMode && s.aspectMode!=="0") vc.aspectRatio=parseFloat(s.aspectMode)||1; ' +
    '  return navigator.mediaDevices.getUserMedia({video:vc,audio:false}).then(function(stream){ ' +
    '    var view=document.getElementById("%0:s_view"); if(!view) throw new Error("view missing"); ' +
    '    view.innerHTML=""; ' +
    '    var v=document.createElement("video"); ' +
    '    v.className="bs_cam_preview"; ' +
    '    v.setAttribute("playsinline","true"); v.setAttribute("webkit-playsinline","true"); ' +
    '    v.muted=true; v.autoplay=true; v.srcObject=stream; ' +
    '    v.style.width="100%%"; v.style.height="100%%"; v.style.objectFit="contain"; ' +
    '    view.appendChild(v); p._cameraStream=stream; ' +
    '    return new Promise(function(resolve, reject){ ' +
    '      function go(){ v.play().then(function(){ resolve(); }).catch(reject); } ' +
    '      if(v.readyState>=1 && v.videoWidth>0) go(); ' +
    '      else v.addEventListener("loadedmetadata", go, {once:true}); ' +
    '    }); ' +
    '  }); ' +
    '}; ' +
    'p._onScanDecoded=function(t,m){ ' +
    '  var deb=p._scanSettings.debounceMs||2500, now=Date.now(); ' +
    '  if(t===p._lastCode && (now-p._lastTime<deb)) return; ' +
    '  p._lastCode=t; p._lastTime=now; ' +
    '  try{ document.getElementById("%0:s_beep").play(); }catch(e){} ' +
    '  ajaxRequest(p,"scanSuccess",["code="+t,"mode=%2:s","submode="+m]); ' +
    '}; ' +
    'p._decodeCanvasFrame=function(canvas){ ' +
    '  var dec=p._scanner&&p._scanner.qrcode; ' +
    '  var pick=function(r){ return r&&(r.text||r.decodedText); }; ' +
    '  var tryDirect=function(){ ' +
    '    if(dec&&dec.decodeRobustlyAsync) return dec.decodeRobustlyAsync(canvas).then(pick); ' +
    '    if(dec&&dec.decodeAsync) return dec.decodeAsync(canvas).then(pick); ' +
    '    return Promise.reject(new Error("decoder unavailable")); ' +
    '  }; ' +
    '  return tryDirect().catch(function(err){ ' +
    '    if(!p._scanner||!p._scanner.scanFileV2) return Promise.reject(err); ' +
    '    return new Promise(function(resolve,reject){ ' +
    '      canvas.toBlob(function(blob){ ' +
    '        if(!blob) return reject(err); ' +
    '        var f=new File([blob],"frame.png",{type:blob.type||"image/png"}); ' +
    '        p._scanner.scanFileV2(f,true).then(function(r){ resolve(r.decodedText||r.text); }).catch(reject); ' +
    '      },"image/png"); ' +
    '    }); ' +
    '  }); ' +
    '}; ' +
    'p._preprocessScanTick=function(){ ' +
    '  if(!p._camActive || !p._usesPreprocessDecode() || p._scanBusy) return; ' +
    '  var v=p._getVideoEl(); if(!v || !v.videoWidth) return; ' +
    '  var vw=v.videoWidth, vh=v.videoHeight, dw=Math.min(vw,640), dh=Math.round(vh*(dw/vw)); ' +
    '  if(!p._scanCanvas) p._scanCanvas=document.createElement("canvas"); ' +
    '  var c=p._scanCanvas, ctx=c.getContext("2d"); c.width=dw; c.height=dh; ' +
    '  p._drawPreprocessToCanvas(ctx,dw,dh,v); ' +
    '  var src=c, sc=p._scanSettings; ' +
    '  if(!sc.fullFrame){ ' +
    '    var edge=Math.floor(Math.min(dw,dh)*(parseFloat(sc.qrboxScale)||%1:s)); ' +
    '    if(edge>0 && edge<Math.min(dw,dh)){ ' +
    '      if(!p._scanCropCanvas) p._scanCropCanvas=document.createElement("canvas"); ' +
    '      p._scanCropCanvas.width=edge; p._scanCropCanvas.height=edge; ' +
    '      var cx=Math.floor((dw-edge)/2), cy=Math.floor((dh-edge)/2); ' +
    '      p._scanCropCanvas.getContext("2d").drawImage(c,cx,cy,edge,edge,0,0,edge,edge); ' +
    '      src=p._scanCropCanvas; ' +
    '    } ' +
    '  } ' +
    '  p._scanBusy=true; ' +
    '  p._decodeCanvasFrame(src).then(function(t){ ' +
    '    p._scanBusy=false; ' +
    '    if(!p._camActive) return; ' +
    '    if(t) p._onScanDecoded(t,p._scanMode||"scan"); ' +
    '  }).catch(function(err){ ' +
    '    p._scanBusy=false; ' +
    '    if(p._scanSettings.verbose) console.warn("preprocess scan", err); ' +
    '  }); ' +
    '}; ' +
    'p._startPreprocessDecodeScan=function(m){ ' +
    '  p._scanMode=m; p._stopPreprocessScanTimer(); ' +
    '  var run=function(){ ' +
    '    return p._openCameraStream().then(function(){ return p._applyTrackSettings(); }).then(function(){ ' +
    '      p._applyPreprocess(); ' +
    '      var fps=Math.min(60,Math.max(1,parseInt(p._scanSettings.fps,10)||10)); ' +
    '      p._preprocessScanTimer=setInterval(function(){ p._preprocessScanTick(); }, Math.max(50,Math.floor(1000/fps))); ' +
    '    }); ' +
    '  }; ' +
    '  if(p._scanner){ return p._scanner.stop().catch(function(){}).then(run); } ' +
    '  return run(); ' +
    '}; ' +
    'p._startNativeScan=function(m){ ' +
    '  p._scanMode=m; p._stopPreprocessScanTimer(); p._stopCameraStream(); p._stopPreprocessCanvas(); ' +
    '  p._ensureScanner(); ' +
    '  var cfg=p._buildScanConfig(), cam=p._getCameraConfig(); ' +
    '  var stopP=(p._scanner&&p._scanner.isScanning&&p._scanner.isScanning()) ' +
    '    ? p._scanner.stop().catch(function(){}) : Promise.resolve(); ' +
    '  return stopP.then(function(){ ' +
    '    return p._scanner.start(cam, cfg, ' +
    '      function(t){ p._onScanDecoded(t,m); }, ' +
    '      function(err){ if(p._scanSettings.verbose) console.warn("scan err", err); } ' +
    '    ); ' +
    '  }).then(function(){ return p._applyTrackSettings(); }); ' +
    '}; ' +

    'p._setScanStatus=function(msg){ ' +
    '  var el=document.getElementById("%0:s_ss_status"); if(el) el.textContent=msg||""; ' +
    '}; ' +
    'p._ssBtnFeedback=function(id,state){ ' +
    '  var el=document.getElementById("%0:s_ss_"+id); if(!el) return; ' +
    '  el.classList.remove("ss-btn-pressed","ss-btn-busy","ss-btn-ok"); ' +
    '  if(state==="press"){ el.classList.add("ss-btn-pressed"); setTimeout(function(){ el.classList.remove("ss-btn-pressed"); },180); } ' +
    '  else if(state==="busy") el.classList.add("ss-btn-busy"); ' +
    '  else if(state==="ok"){ el.classList.add("ss-btn-ok"); setTimeout(function(){ el.classList.remove("ss-btn-ok"); },1400); } ' +
    '  else if(state==="idle"){} ' +
    '}; ' +

    // UI панели настроек
    'p._refreshCameraList=function(){ ' +
    '  var sel=document.getElementById("%0:s_ss_camera"); if(!sel) return; ' +
    '  sel.innerHTML=''<option value="">— выберите —</option>''; ' +
    '  if(typeof Html5Qrcode==="undefined") return; ' +
    '  Html5Qrcode.getCameras().then(function(cams){ ' +
    '    cams.forEach(function(c){ ' +
    '      var o=document.createElement("option"); o.value=c.id; o.textContent=(c.label||c.id); ' +
    '      if(p._scanSettings.cameraId===c.id) o.selected=true; sel.appendChild(o); ' +
    '    }); ' +
    '  }).catch(function(err){ p._setScanStatus("Камеры: "+(err&&err.message?err.message:err)); }); ' +
    '}; ' +
    'p._fillSettingsForm=function(){ ' +
    '  var s=p._scanSettings; ' +
    '  var setVal=function(id,v){ var el=document.getElementById("%0:s_ss_"+id); if(el) el.value=v; }; ' +
    '  var setChk=function(id,v){ var el=document.getElementById("%0:s_ss_"+id); if(el) el.checked=!!v; }; ' +
    '  setVal("facing", s.facingMode||"environment"); ' +
    '  setVal("fps", s.fps||10); ' +
    '  setVal("qrbox", Math.round((s.qrboxScale||%1:s)*100)); ' +
    '  setVal("aspect", s.aspectMode||"1"); ' +
    '  setVal("debounce", s.debounceMs||2500); ' +
    '  setVal("vw", s.videoWidth||0); setVal("vh", s.videoHeight||0); ' +
    '  setVal("brightness", s.brightnessPct||100); ' +
    '  setVal("contrast", s.contrastPct||100); ' +
    '  setVal("zoom", s.zoom||1); ' +
    '  setVal("preprocess", s.preprocessMode||"off"); ' +
    '  setVal("pre_th", s.preprocessThreshold||128); ' +
    '  setChk("decode_pre", s.decodePreprocessed); ' +
    '  setChk("fullframe", s.fullFrame); setChk("disable_flip", s.disableFlip); ' +
    '  setChk("disable_zoom", s.disableZoom); ' +
    '  setChk("barcode_detector", s.useBarCodeDetector); setChk("verbose", s.verbose); ' +
    '  setChk("autostart", s.autoStartCamera); ' +
    '  var fm=s.formats||{}; ' +
    '  setChk("fmt_qr", fm.qr!==false); setChk("fmt_c128", !!fm.c128); setChk("fmt_ean13", !!fm.ean13); ' +
    '  setChk("fmt_c39", !!fm.c39); setChk("fmt_datamatrix", !!fm.dm); ' +
    '  document.getElementById("%0:s_ss_fps_val").textContent=s.fps||10; ' +
    '  document.getElementById("%0:s_ss_qrbox_val").textContent=Math.round((s.qrboxScale||%1:s)*100); ' +
    '  document.getElementById("%0:s_ss_debounce_val").textContent=s.debounceMs||2500; ' +
    '  document.getElementById("%0:s_ss_brightness_val").textContent=s.brightnessPct||100; ' +
    '  document.getElementById("%0:s_ss_contrast_val").textContent=s.contrastPct||100; ' +
    '  document.getElementById("%0:s_ss_pre_th_val").textContent=s.preprocessThreshold||128; ' +
    '  p._syncTrackSliders(); ' +
    '  p._refreshCameraList(); ' +
    '}; ' +
    'p._readSettingsForm=function(){ ' +
    '  var g=function(id){ return document.getElementById("%0:s_ss_"+id); }; ' +
    '  var s=p._scanSettings; ' +
    '  s.facingMode=g("facing").value; s.cameraId=g("camera").value; ' +
    '  s.fps=Math.min(60,Math.max(1,parseInt(g("fps").value,10)||10)); ' +
    '  s.qrboxScale=(parseInt(g("qrbox").value,10)||50)/100; ' +
    '  s.fullFrame=g("fullframe").checked; s.aspectMode=g("aspect").value; ' +
    '  s.debounceMs=parseInt(g("debounce").value,10)||2500; ' +
    '  s.disableFlip=g("disable_flip").checked; s.disableZoom=g("disable_zoom").checked; ' +
    '  s.useBarCodeDetector=g("barcode_detector").checked; ' +
    '  s.verbose=g("verbose").checked; s.autoStartCamera=g("autostart").checked; ' +
    '  s.videoWidth=parseInt(g("vw").value,10)||0; s.videoHeight=parseInt(g("vh").value,10)||0; ' +
    '  s.zoom=parseFloat(g("zoom").value)||1; ' +
    '  s.brightnessPct=parseInt(g("brightness").value,10)||100; ' +
    '  s.contrastPct=parseInt(g("contrast").value,10)||100; ' +
    '  s.preprocessMode=g("preprocess").value||"off"; ' +
    '  s.preprocessThreshold=parseInt(g("pre_th").value,10)||128; ' +
    '  s.decodePreprocessed=g("decode_pre").checked && s.preprocessMode!=="off"; ' +
    '  s.formats={qr:g("fmt_qr").checked,c128:g("fmt_c128").checked,ean13:g("fmt_ean13").checked, ' +
    '    c39:g("fmt_c39").checked,dm:g("fmt_datamatrix").checked}; ' +
    '  p._saveScanSettings(s); return s; ' +
    '}; ' +
    'p._openScanSettings=function(e){ ' +
    '  if(e){ e.stopPropagation(); e.preventDefault(); } ' +
    '  p._fillSettingsForm(); ' +
    '  var pan=document.getElementById("%0:s_scan_settings"); if(pan) pan.style.display="flex"; ' +
    '}; ' +
    'p._closeScanSettings=function(){ ' +
    '  var pan=document.getElementById("%0:s_scan_settings"); if(pan) pan.style.display="none"; ' +
    '}; ' +
    'p._applyScanSettings=function(restart){ ' +
    '  p._ssBtnFeedback("apply","press"); ' +
    '  p._readSettingsForm(); p._updateScanAreaVisual(); p._ensureScanner(); ' +
    '  if(restart && p._camActive){ ' +
    '    p._ssBtnFeedback("apply","busy"); ' +
    '    try{ ' +
    '      p._scanner.stop().then(function(){ p._startScan(p._scanMode||"scan"); p._ssBtnFeedback("apply","ok"); }) ' +
    '        .catch(function(){ p._startScan(p._scanMode||"scan"); p._ssBtnFeedback("apply","ok"); }); ' +
    '    }catch(e){ p._startScan(p._scanMode||"scan"); p._ssBtnFeedback("apply","ok"); } ' +
    '  } else if(p._camActive){ ' +
    '    p._applyTrackSettings(); ' +
    '    p._ssBtnFeedback("apply","ok"); ' +
    '  } else p._ssBtnFeedback("apply","ok"); ' +
    '  p._setScanStatus("Настройки сохранены"); ' +
    '  setTimeout(function(){ p._setScanStatus(""); }, 2000); ' +
    '  p._closeScanSettings(); ' +
    '}; ' +
    'p._bindScanSettingsUI=function(){ ' +
    // короткий тап — camStubClick, удержание 11 сек — настройки
    '  var stub=document.getElementById("%0:s_cam_stub"); ' +
    '  if(stub){ ' +
    '    var stubTimer, stubLong=false, stubActive=false; ' +
    '    var stubPressStart=function(){ ' +
    '      if(stubActive) return; stubActive=true; stubLong=false; ' +
    '      stubTimer=setTimeout(function(){ stubLong=true; stubActive=false; p._openScanSettings(); }, 3000); ' +
    '    }; ' +
    '    var stubPressCancel=function(){ clearTimeout(stubTimer); stubActive=false; stubLong=false; }; ' +
    '    var stubPressEnd=function(){ ' +
    '      clearTimeout(stubTimer); ' +
    '      if(stubActive && !stubLong) ajaxRequest(p, "camStubClick", []); ' +
    '      stubActive=false; stubLong=false; ' +
    '    }; ' +
    '    stub.addEventListener("mousedown", stubPressStart); ' +
    '    stub.addEventListener("mouseup", stubPressEnd); ' +
    '    stub.addEventListener("mouseleave", stubPressCancel); ' +
    '    stub.addEventListener("touchstart", stubPressStart, {passive:true}); ' +
    '    stub.addEventListener("touchend", stubPressEnd); ' +
    '    stub.addEventListener("touchcancel", stubPressCancel); ' +
    '  } ' +
    '  ["fps","qrbox","debounce","brightness","contrast","zoom","pre_th"].forEach(function(id){ ' +
    '    var el=document.getElementById("%0:s_ss_"+id); if(!el) return; ' +
    '    el.oninput=function(){ ' +
    '      var lbl=document.getElementById("%0:s_ss_"+id+"_val"); if(!lbl) return; ' +
    '      lbl.textContent=(id==="zoom") ? parseFloat(el.value).toFixed(1) : el.value; ' +
    '      if(p._camActive && (id==="brightness" || id==="contrast" || id==="pre_th" || (id==="zoom" && !p._scanSettings.disableZoom))){ ' +
    '        if(id==="zoom") p._scanSettings.zoom=parseFloat(el.value); ' +
    '        else if(id==="brightness") p._scanSettings.brightnessPct=parseInt(el.value,10); ' +
    '        else if(id==="contrast") p._scanSettings.contrastPct=parseInt(el.value,10); ' +
    '        else if(id==="pre_th") p._scanSettings.preprocessThreshold=parseInt(el.value,10); ' +
    '        p._applyPreprocess(); ' +
    '      } ' +
    '    }; ' +
    '  }); ' +
    '  var preSel=document.getElementById("%0:s_ss_preprocess"); ' +
    '  if(preSel) preSel.onchange=function(){ ' +
    '    p._scanSettings.preprocessMode=preSel.value; ' +
    '    if(p._scanSettings.preprocessMode==="off") p._scanSettings.decodePreprocessed=false; ' +
    '    if(p._camActive) p._applyPreprocess(); ' +
    '  }; ' +
    '  var decPre=document.getElementById("%0:s_ss_decode_pre"); ' +
    '  if(decPre) decPre.onchange=function(){ ' +
    '    p._scanSettings.decodePreprocessed=decPre.checked && (p._scanSettings.preprocessMode||"off")!=="off"; ' +
    '    if(p._camActive){ ' +
    '      try{ p._scanner.stop().then(function(){ p._startScan(p._scanMode||"scan"); }).catch(function(){ p._startScan(p._scanMode||"scan"); }); } ' +
    '      catch(e){ p._startScan(p._scanMode||"scan"); } ' +
    '    } ' +
    '  }; ' +
    '  var closeBtn=document.getElementById("%0:s_ss_close"); ' +
    '  if(closeBtn) closeBtn.onclick=function(){ p._closeScanSettings(); }; ' +
    '  var applyBtn=document.getElementById("%0:s_ss_apply"); ' +
    '  if(applyBtn) applyBtn.onclick=function(){ p._applyScanSettings(true); }; ' +
    '  var applyGlobalBtn=document.getElementById("%0:s_ss_apply_global"); ' +
    '  if(applyGlobalBtn) applyGlobalBtn.onclick=function(){ p._applyGlobalProfileFromServer(); }; ' +
    '  var saveProfBtn=document.getElementById("%0:s_ss_save_profile"); ' +
    '  if(saveProfBtn) saveProfBtn.onclick=function(){ p._saveProfileToServer(); }; ' +
    '  var resetBtn=document.getElementById("%0:s_ss_reset"); ' +
    '  if(resetBtn) resetBtn.onclick=function(){ ' +
    '    p._ssBtnFeedback("reset","press"); ' +
    '    p._scanSettings=p._defaultScanSettings(); p._saveScanSettings(p._scanSettings); ' +
    '    p._fillSettingsForm(); p._setScanStatus("Сброшено к умолчанию"); ' +
    '    p._ssBtnFeedback("reset","ok"); ' +
    '  }; ' +
    '  var refBtn=document.getElementById("%0:s_ss_refresh_cam"); ' +
    '  if(refBtn) refBtn.onclick=function(){ p._ssBtnFeedback("refresh_cam","press"); p._refreshCameraList(); p._ssBtnFeedback("refresh_cam","ok"); }; ' +
    '  var dzChk=document.getElementById("%0:s_ss_disable_zoom"); ' +
    '  if(dzChk) dzChk.onchange=function(){ ' +
    '    p._scanSettings.disableZoom=dzChk.checked; p._updateZoomUi(); ' +
    '    if(p._camActive) p._applyPreprocess(); ' +
    '  }; ' +
    '}; ' +

    // --- СКАНЕР: запуск ---
    'p._startScan=function(m){ ' +
    '  if(!p._camActive) return Promise.resolve(); ' +
    '  p._scanMode=m; p._ensureScanner(); ' +
    '  var startFn=p._usesPreprocessDecode()?p._startPreprocessDecodeScan:p._startNativeScan; ' +
    '  return startFn.call(p,m).catch(function(err){ ' +
    '    p._setScanStatus("Ошибка камеры: "+(err&&err.message?err.message:err)); ' +
    '    if(p._scanSettings.verbose) console.error(err); ' +
    '  }); ' +
    '}; ' +
    'p._refreshCameraList(); ' +
    'p._updateScanAreaVisual(); ' +
    'p._bindScanSettingsUI(); ' +
    'p._startScan("scan"); ' +
    'p.toggleCam(!!p._scanSettings.autoStartCamera); ' +
    'p._flushPendingProfileApply(); ' +
    '}; runScanner();',
    [LCID, LSScanAreaScale, AMode]);

  UniSession.AddJS(LJS);
end;

const
  SCANNER_PROFILE_FILE = 'scanner_profile.json';

function ScannerProfileFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + SCANNER_PROFILE_FILE;
end;

procedure SaveScannerProfileConfig(const AJsonConfig: string);
var
  J: TJSONValue;
begin
  J := TJSONObject.ParseJSONValue(AJsonConfig);
  if J = nil then
    raise Exception.Create('Invalid scanner profile JSON');
  try
    TFile.WriteAllText(ScannerProfileFilePath, J.ToJSON, TEncoding.UTF8);
  finally
    J.Free;
  end;
end;

function LoadScannerProfileFromFile: string;
begin
  if TFile.Exists(ScannerProfileFilePath) then
    Result := TFile.ReadAllText(ScannerProfileFilePath, TEncoding.UTF8)
  else
    Result := '';
end;

procedure ApplyScannerProfileConfig(APanel: TUnimPanel; const AJsonConfig: string;
  ARestartCamera: Boolean);
var
  J: TJSONValue;
  LJson, LRestart, LPanel: string;
begin
  if not Assigned(APanel) then
    Exit;
  J := TJSONObject.ParseJSONValue(AJsonConfig);
  if J = nil then
    raise Exception.Create('Invalid scanner profile JSON');
  try
    LJson := J.ToJSON;
  finally
    J.Free;
  end;
  LPanel := APanel.JSName;
  LRestart := IfThen(ARestartCamera, 'true', 'false');
  UniSession.AddJS(
    '(function(){try{' +
    'window.__bsScanProfile=' + LJson + ';' +
    'var cfg=window.__bsScanProfile;delete window.__bsScanProfile;' +
    'var p=window["' + LPanel + '"];' +
    'if(p&&typeof p.applyScannerProfile==="function"){p.applyScannerProfile(cfg,' + LRestart + ');return;}' +
    'window.__bsScanProfilePending={cfg:cfg,restart:' + LRestart + '};' +
    '}catch(e){console.error("applyScannerProfile",e);}})();'
  );
end;

procedure SetSidePanelState(AOpen: Boolean);
begin
  if AOpen then
  begin
    // Выезжает снизу (0 - конечная точка)
    UniSession.AddJS(
      'var s=document.getElementById(''mySidePanel''); ' +
      'if(s){ s.style.transform=''translateY(0)''; s.style.pointerEvents=''auto''; }'
    );
  end
  else
  begin
    // Уезжает вниз (100% - полностью скрыта)
    UniSession.AddJS(
      'var s=document.getElementById(''mySidePanel''); ' +
      'if(s){ s.style.transform=''translateY(100%)''; s.style.pointerEvents=''none''; }'
    );
  end;
end;

end.
