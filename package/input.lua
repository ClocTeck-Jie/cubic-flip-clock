-- Gyro mapping follows baby-watch cubic-flip-clock 1.1.0.
-- Controller masks, polling and edge handling follow Launcher v1.30.
local Input={}
function Input.new(actions)
 local s={buttons=0,stopped=false,events=0,last="",timers={}}
 local function dispatch(name,...) if s.stopped then return end;s.events=s.events+1;s.last=name;return actions[name](...) end
 function s:handle(code,evt)
  -- Original baby-watch gyro mapping: no START/repeat or forward/back actions.
  if code==key.LEFT and evt==key.LONG_START then dispatch("move",1)
  elseif code==key.RIGHT and evt==key.LONG_START then dispatch("confirm")
  elseif code==key.RIGHT and evt==key.SHORT then dispatch("item",1)
  elseif code==key.HOME and evt==key.SHORT then dispatch("exit") end
 end
 function s:pad(pad)
  local buttons=type(pad)=="table" and tonumber(pad.buttons) or 0
  if type(pad)=="table" and pad.connected==false then buttons=0 end
  buttons=buttons or 0;local pressed=buttons&(~self.buttons);self.buttons=buttons
  -- Launcher uses the same source, masks, 40ms polling and edge-only dispatch.
  if (pressed&4)~=0 then dispatch("move",-1)
  elseif (pressed&8)~=0 then dispatch("move",1)
  elseif (pressed&1)~=0 then dispatch("item",-1)
  elseif (pressed&2)~=0 then dispatch("item",1)
  elseif (pressed&(16|8192))~=0 then dispatch("confirm")
  elseif (pressed&(32|4096))~=0 then dispatch("back")
  elseif (pressed&32768)~=0 then dispatch("exit") end
 end
 function s:start()
  for _,code in ipairs({key.LEFT,key.RIGHT,key.UP,key.DOWN,key.HOME}) do key.on(code,function(evt)self:handle(code,evt)end) end
  if controller and controller.state then local t=tmr.create();self.timers[#self.timers+1]=t;t:alarm(40,tmr.ALARM_AUTO,function()
   local ok,pad=pcall(controller.state,"ble-main");self:pad(ok and pad or nil)
  end) end
 end
 function s:stop() self.stopped=true;key.off();for _,t in ipairs(self.timers) do pcall(function()t:unregister()end) end end
 return s
end
return Input
