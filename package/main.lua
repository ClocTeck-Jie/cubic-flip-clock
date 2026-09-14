-- 正式翻页钟：数字图集按卡片流式读取；左右倾斜使用已验证的 LONG_START。
local DIR, NAME = "/sd/apps/flip-clock/", "CUBIC_FLIP_CLOCK"
local prior = rawget(_G, NAME)
if prior and prior.stop then pcall(prior.stop, "reload") end
local A = {running=true, light=false, seconds=true, cards={}, timers={}, fonts={}, tick=0, flips=0}
local diagnostics=file.exists(DIR.."diagnostics.flag")
_G[NAME] = A
local S = LV_PART_MAIN | LV_STATE_DEFAULT
local status = {version="1.2.0", state="starting", cleanup_errors={}, started=tmr.now()}
local function nowms() return tmr.now()/1000 end
local function report()
  if not diagnostics then return end
  status.theme=A.theme;status.motion=A.motion;status.light=A.light; status.seconds=A.seconds; status.flips=A.flips; status.ticks=A.tick
  status.usage=sys.usage()
  file.putcontents(DIR.."status.json",sjson.encode(status))
end
local function safe(name, fn)
  local ok,e=pcall(fn)
  if not ok then status.cleanup_errors[#status.cleanup_errors+1]=name..":"..tostring(e) end
end
function A.stop(reason)
  if not A.running then return end
  A.running=false
  if A.web then safe("web",function()A.web:stop()end)end
  if A.input then safe("input",function()A.input:stop()end)end
  if A.weather then A.weather:stop()end
  if app.set_home_exit then pcall(app.set_home_exit,true)end
  safe("left",function() key.off(key.LEFT) end)
  safe("right",function() key.off(key.RIGHT) end)
  for _,t in ipairs(A.timers) do safe("timer",function() t:stop(); t:unregister() end) end
  A.timers={}
  if A.panel then safe("panel",function() lv_obj_del(A.panel) end); A.panel=nil end
  for _,f in ipairs(A.fonts) do safe("font",function() lv_font_free(f) end) end
  if A.fontManager then safe("fonts",function()A.fontManager:stop()end)end
  A.fonts={}; A.cards={}
  status.state="stopped"; status.reason=tostring(reason or "stop")
  pcall(report)
  if rawget(_G,NAME)==A then _G[NAME]=nil end
end
A.shutdown=A.stop
local function reset(o)
  lv_obj_remove_style_all(o)
  lv_obj_clear_flag(o,LV_OBJ_FLAG_SCROLLABLE)
end
local function box(parent,x,y,w,h,color,radius)
  local o=lv_obj_create(parent); reset(o)
  lv_obj_set_pos(o,x,y); lv_obj_set_size(o,w,h)
  lv_obj_set_style_bg_color(o,color,S); lv_obj_set_style_bg_opa(o,255,S)
  lv_obj_set_style_radius(o,radius or 0,S)
  return o
end
local function label(text,x,y,w,font,align)
  local o=lv_label_create(A.panel); reset(o)
  lv_label_set_text(o,text); lv_obj_set_pos(o,x,y); lv_obj_set_width(o,w)
  lv_obj_set_style_text_color(o,0xffffff,S)
  lv_obj_set_style_text_font(o,font,S)
  lv_obj_set_style_text_align(o,align or LV_TEXT_ALIGN_LEFT,S)
  return o
end
local function timeparts()
  -- 只读取系统时钟，不修改其他应用共享的时区和 NTP 配置。
  local t=time.getlocal()
  if type(t)~="table" or not t.year or t.year<2024 then return nil end
  return t
end
local calendar,lunarData,preferences,skins,motion,renderer,cachePolicy,L
local function weatherLabels()
 if not A.title or not A.weather then return end
 local w=A.weather
 A.fontManager:set("city",A.title,12,w.city.."  "..(w.temp and tostring(w.temp).."°C" or "--°C"))
 if A.language~="zh-CN" then status.lunar=w.text~="" and w.text or L.words[A.language].waiting;A.fontManager:set("bottom",A.lunar,12,status.lunar) end
end
local function skin() return skins[A.skinIndex] end
local function weekday(y,m,d)
  local offsets={0,3,2,5,0,3,5,1,4,6,2,4}
  if m<3 then y=y-1 end
  return (y+math.floor(y/4)-math.floor(y/100)+math.floor(y/400)+offsets[m]+d)%7+1
end
local function readcard(n,w,h)
  local slot=n*(#A.assetIndex/60)+1
  local offset,length=string.unpack("<I4I4",A.assetIndex,slot)
  local f=assert(file.open(DIR..A.assetStem..".dat","r"),"Cannot open digit asset")
  local ok,data=pcall(function() f:seek("set",offset);return f:read(length) end)
  f:close();if not ok then error(data) end
  local decoded,err=zlib.inflate(data)
  assert(type(decoded)=="string" and #decoded==w*h*2,err or "Incomplete digit asset")
  return decoded
end
local function blit(c,pixels,x,y,w,h)
  lv_canvas_blit_rgb565(c.canvas,x or 0,y or 0,w or c.w,h or c.h,pixels)
end
local function frame(c,stamp)
  if not c.started then return end
  local elapsed=(stamp-c.started)%4294967.296
  local duration=A.motion=="rebound" and 760 or 320
  if elapsed>=duration then
    if diagnostics and A.motion=="rebound" then
      status.rebound_completed=(status.rebound_completed or 0)+1
      if (c.reboundFrames or 0)==0 then status.rebound_missed=(status.rebound_missed or 0)+1 end
    end
    blit(c,c.pixels);c.old=nil;c.started=nil;renderer.reset(c);return
  end
  if diagnostics and A.motion=="rebound" and elapsed>=320 then
    c.reboundFrames=(c.reboundFrames or 0)+1
  end
  renderer.draw(c,elapsed,A.motion,motion,skin().bottom)
end
local function rebuild()
  A.cards={}
  A.assetStem="skins/"..(A.seconds and "small" or "large").."-"..A.theme
  A.assetIndex=assert(file.getcontents(DIR..A.assetStem..".idx"))
  if A.cardRoot then lv_obj_del(A.cardRoot) end
  A.cardRoot=lv_obj_create(A.panel); reset(A.cardRoot)
  lv_obj_set_size(A.cardRoot,320,130); lv_obj_set_pos(A.cardRoot,0,58)
  lv_obj_set_style_bg_opa(A.cardRoot,0,S)
  local count=A.seconds and 3 or 2
  local w,h,gap=A.seconds and 94 or 140,A.seconds and 100 or 116,A.seconds and 6 or 10
  local x=math.floor((320-count*w-(count-1)*gap)/2)
  for i=1,count do
    local panel=box(A.cardRoot,x+(i-1)*(w+gap),0,w,h,skin().top,7)
    lv_obj_set_style_clip_corner(panel,true,S)
    local canvas=lv_canvas_create(panel,w,h)
    lv_obj_set_pos(canvas,0,0)
    local c={canvas=canvas,w=w,h=h,value=-1}
    A.cards[i]=c
    box(panel,0,h/2,w,1,skin().seam,0)
    box(panel,0,h/2-3,3,6,skin().hinge,1)
    box(panel,w-3,h/2-3,3,6,skin().hinge,1)
  end
  if A.seconds then lv_obj_clear_flag(A.iconSecond,LV_OBJ_FLAG_HIDDEN)
  else lv_obj_add_flag(A.iconSecond,LV_OBJ_FLAG_HIDDEN) end
  A.dateKey=nil
end
local function update(animate)
  local t=timeparts();A.time=t
  if not t then A.fontManager:set("date",A.date,16,L.words[A.language].sync);lv_label_set_text(A.lunar,"");return end
  local values={t.hour,t.min,t.sec}
  local stamp=nowms()
  for i,c in ipairs(A.cards) do
    if c.value~=values[i] then
      local data
      if c.nextValue==values[i] then data=c.nextPixels;c.nextPixels=nil;c.nextValue=nil
      else
        c.nextPixels=nil;c.nextValue=nil
        data=readcard(values[i],c.w,c.h)
      end
      local old=c.pixels
      if diagnostics and c.started and A.motion=="rebound" then
        status.rebound_interrupted=(status.rebound_interrupted or 0)+1
      end
      c.pixels=data;c.value=values[i]
      c.reboundFrames=0;renderer.reset(c)
      if animate and old then c.old=old;c.started=stamp;A.flips=A.flips+1
        if diagnostics and A.motion=="rebound" then status.rebound_started=(status.rebound_started or 0)+1 end
      else c.old=nil;c.started=nil;blit(c,data) end
    end
    frame(c,stamp)
  end
  local dateKey=t.year*10000+t.mon*100+t.day
  if A.dateKey~=dateKey then
    A.dateKey=dateKey
    status.date=L.date(A.language,t,weekday(t.year,t.mon,t.day))
    if A.language=="zh-CN" then
      if not calendar then calendar=assert(load(assert(file.getcontents(DIR.."calendar.lua"))))() end
      if not lunarData then lunarData=assert(load(assert(file.getcontents(DIR.."lunar_data.lua"))))() end
      status.lunar=calendar.text(lunarData,t.year,t.mon,t.day)
    else
      calendar=nil;lunarData=nil
      status.lunar=A.weather and A.weather.text~="" and A.weather.text or L.words[A.language].waiting
    end
    A.fontManager:set("date",A.date,16,status.date)
    A.fontManager:set("bottom",A.lunar,A.language=="zh-CN" and 13 or 12,status.lunar)
  end
  status.clock=string.format("%02d:%02d:%02d",t.hour,t.min,t.sec)
end
local function prefetch()
  cachePolicy.step(A.cards,A.time,readcard)
end
local function capture()
  -- 截图是验证证据，失败时只记录，不中断时钟。
  local handle
  local ok,e=pcall(function()
    handle=lv_snapshot_take(A.panel,LV_IMG_CF_TRUE_COLOR_ALPHA or 5)
    assert(handle,"snapshot unavailable")
    local result,err=lv_snapshot_save_to_png(handle,DIR.."preview.png")
    return tostring(result)..":"..tostring(err)
  end)
  if handle then pcall(lv_snapshot_free,handle) end
  status.capture=tostring(e)
end
local function start()
  -- 只加载仓库随包提供的纯 Lua 日期模块，农历数据每日查询一次。
  preferences=assert(load(assert(file.getcontents(DIR.."preferences.lua")),"@preferences.lua"))()
  skins=assert(load(assert(file.getcontents(DIR.."skins.lua"))))()
  motion=assert(load(assert(file.getcontents(DIR.."motion.lua"))))()
  renderer=assert(load(assert(file.getcontents(DIR.."renderer.lua"))))()
  cachePolicy=assert(load(assert(file.getcontents(DIR.."prefetch.lua"))))()
  L=assert(load(assert(file.getcontents(DIR.."locale.lua"))))()
  local sysraw=file.getcontents('/sd/apps/settings.json')
  local ok,system=pcall(sjson.decode,sysraw or '{}');if not ok or type(system)~='table' then system={} end
  A.systemLanguage=L.normalize(system.language or system.locale or system.lang)
  A.systemAddress=tostring(system.weather_address or system.weatherAddress or '')
  local saved=preferences.load(file,sjson,DIR.."settings.json")
  A.languageChoice="auto";A.addressChoice=nil
  A.language=A.systemLanguage
  A.address=A.systemAddress
  A.light=saved.light;A.seconds=saved.seconds;A.theme=saved.theme;A.motion=saved.motion
  A.skinIndex=1;for i,v in ipairs(skins) do if v.id==A.theme then A.skinIndex=i end end
  local root=lv_scr_act()
  -- 应用面板仍然透明；底层帧缓冲以黑色清屏，避免透明根节点留下旧像素。
  lv_obj_set_style_bg_color(root,0x000000,S)
  lv_obj_set_style_bg_opa(root,255,S)
  A.panel=lv_obj_create(root);reset(A.panel)
  lv_obj_set_size(A.panel,320,240);lv_obj_set_style_bg_opa(A.panel,0,S)
  A.fontManager=assert(load(assert(file.getcontents(DIR..'fonts.lua'))))().new(DIR)
  local font,datefont,lunarfont=LV_FONT_MONTSERRAT_12,LV_FONT_MONTSERRAT_16,LV_FONT_MONTSERRAT_12
  box(A.panel,14,26,4,4,0xffffff,2)
  A.title=label("",23,21,250,font)
  lv_label_set_long_mode(A.title,LV_LABEL_LONG_CLIP)
  -- 图标用几何图形绘制，不依赖字体是否包含时钟符号。
  A.icon=box(A.panel,287,21,16,16,0,8)
  lv_obj_set_style_bg_opa(A.icon,0,S)
  lv_obj_set_style_border_width(A.icon,1,S)
  lv_obj_set_style_border_color(A.icon,0xffffff,S)
  box(A.panel,294,24,1,6,0xffffff)
  box(A.panel,294,29,4,1,0xffffff)
  A.iconSecond=box(A.panel,298,32,2,2,0xffffff,1)
  A.date=label("",0,183,320,datefont,LV_TEXT_ALIGN_CENTER)
  A.lunar=label("",0,211,320,lunarfont,LV_TEXT_ALIGN_CENTER)
  rebuild();update(false)
  function A.snapshot()
    local w=A.weather or {}
    return {ok=true,version='1.2.0',theme=A.theme,motion=A.motion,seconds=A.seconds,language=A.languageChoice,resolved_language=A.language,address=A.addressChoice or '',follow_system_address=A.addressChoice==nil,system_address=A.systemAddress,
      weather={city=w.city,temp=w.temp,text=w.text,error=w.error,busy=w.busy,id=w.id,updated=w.updated,requests=w.requests},clock=status.clock,date=status.date,bottom=status.lunar,font_bytes=A.fontManager.bytes,runtime_error=status.error,input_profile='original-gyro/launcher-v1.30-pad'}
  end
  function A.configure(p)
    local theme=p.theme or A.theme;local found
    for i,v in ipairs(skins)do if v.id==theme then found=i end end
    local mode=p.motion or A.motion;local language="auto"
    local seconds=A.seconds;if p.seconds~=nil then seconds=p.seconds end
    local address=nil
    if not found or (mode~='original' and mode~='rebound') or type(seconds)~='boolean' then return false,'Invalid style' end
    local ok,err=preferences.save(file,sjson,DIR..'settings.json',theme=='light',seconds,theme,mode,{language=language,address=address})
    if not ok then return false,err end
    local changed=A.theme~=theme or A.seconds~=seconds
    A.theme=theme;A.light=theme=='light';A.skinIndex=found;A.seconds=seconds;A.motion=mode
    local oldlang,oldaddress=A.language,A.address
    A.languageChoice=language;A.addressChoice=address
    A.language=A.systemLanguage
    A.address=A.systemAddress
    A.dateKey=nil
    if changed then A.rebuildPending=true end
    A.renderPending=true
    if oldlang~=A.language or oldaddress~=A.address then A.weather:configure(A.language,A.address);A.weather:refresh()end
    A.weatherDirty=true;report();return true
  end
  local Weather=assert(load(assert(file.getcontents(DIR..'weather.lua'))))()
  A.weather=Weather.new(DIR,L,function()if A.running then A.weatherDirty=true end end);A.weather:configure(A.language,A.address)
  local Input=assert(load(assert(file.getcontents(DIR..'input.lua'))))()
  local function change(p)local ok,e=A.configure(p);if not ok then status.settings_error=e end end
  A.input=Input.new({
    move=function(d)change({theme=skins[(A.skinIndex-1+d)%#skins+1].id})end,
    item=function(d)if d<0 then change({seconds=not A.seconds})else change({motion=A.motion=='original' and 'rebound' or 'original'})end end,
    confirm=function()change({seconds=not A.seconds})end,
    back=function()app.exit()end,exit=function()app.exit()end})
  if app.set_home_exit then app.set_home_exit(false)end
  A.input:start()
  A.web=assert(load(assert(file.getcontents(DIR..'web.lua'))))().new(DIR,A);A.web:start()
  local wt=tmr.create();A.timers[#A.timers+1]=wt
  wt:alarm(60000,tmr.ALARM_AUTO,function()
    if not A.running then return end
    local raw=file.getcontents('/sd/apps/settings.json');local ok,d=pcall(sjson.decode,raw or '{}')
    if ok and type(d)=='table' then
      local lang=L.normalize(d.language or d.locale or d.lang);local address=tostring(d.weather_address or d.weatherAddress or '')
      if lang~=A.language or address~=A.address then
        A.systemLanguage=lang;A.systemAddress=address;A.language=lang;A.address=address;A.dateKey=nil;A.renderPending=true
        A.weather:configure(lang,address)
      end
    end
    A.weather:refresh()
  end)
  A.weather:refresh()
  -- 文档通过 IPC 通知应用停止，不向即将销毁的应用承诺 exit 回调。
  -- 保留显式 stop 与退出标志轮询；不拦截系统原有返回手势。
  local timer=tmr.create();A.timers[#A.timers+1]=timer
  timer:alarm(40,tmr.ALARM_AUTO,function()
    if not A.running then return end
    local ok,e=pcall(function()
      if app.exiting() then A.stop("app.exiting");return end
      local began=nowms()
      A.tick=A.tick+1
      -- All canvas/font mutations happen in this one UI timer, never in HTTP callbacks.
      if A.rebuildPending then A.rebuildPending=nil;rebuild()end
      if A.renderPending then A.renderPending=nil;update(false)else update(true)end
      if A.weatherDirty then A.weatherDirty=nil;weatherLabels()end
      A.weather:poll()
      local cost=(nowms()-began)%4294967.296
      status.max_update_ms=math.max(status.max_update_ms or 0,cost)
      status.total_update_ms=(status.total_update_ms or 0)+cost
      status.average_update_ms=status.total_update_ms/A.tick
      prefetch()
      if diagnostics and A.tick==100 then report() end
      if A.tick%250==0 then report() end
    end)
    if not ok then status.error=tostring(e);A.stop("timer-error") end
  end)
  status.state="running";report()
end
local ok,e=pcall(start)
if not ok then status.error=tostring(e);A.stop("startup-error") end
return A
