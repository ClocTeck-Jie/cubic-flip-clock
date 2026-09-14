const fs=require('fs'),assert=require('assert'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const interop=require('fengari-interop');
const root='package';const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);lauxlib.luaL_requiref(L,to_luastring('js'),interop.luaopen_js,1);lua.lua_pop(L,1);
globalThis.source=n=>fs.readFileSync(path.join(root,n),'utf8');
function run(s){if(lauxlib.luaL_dostring(L,to_luastring(s)))throw Error(to_jsstring(lua.lua_tostring(L,-1)))}
for(const n of fs.readdirSync(root).filter(n=>n.endsWith('.lua'))){let b=fs.readFileSync(path.join(root,n));if(lauxlib.luaL_loadbuffer(L,b,b.length,to_luastring(n)))throw Error(to_jsstring(lua.lua_tostring(L,-1)));lua.lua_pop(L,1)}
run(`local js=require('js');function module(n)return assert(load(js.global:source(n)))()end
local L=module('locale.lua');assert(L.normalize('de-DE')=='de');assert(L.normalize('ja_JP')=='ja')
local t={year=2026,mon=9,day=11};assert(L.date('de',t,6)=='11.09.2026  Freitag');assert(L.date('ja',t,6)=='2026年9月11日  金曜日')
local files={};local docs={};local seq=0
file={getcontents=function(p)return files[p]end,putcontents=function(p,v)files[p]=v end}
sjson={encode=function(d)seq=seq+1;docs[tostring(seq)]=d;return tostring(seq)end,decode=function(v)return assert(docs[v])end}
tmr={now=function()return 1000 end};local requests={};http={cubicserver={get=function(p,h,cb)requests[#requests+1]={p=p,cb=cb}end}}
local W=module('weather.lua');local w=W.new('/',L,function()end)
w:configure('en','');assert(w.id=='1E98E' and w.city=='New York');w:refresh();assert(#requests==1 and requests[1].p:find('/now?',1,true))
requests[1].cb(200,sjson.encode({code='200',now={temp='21',text='Sunny'}}));assert(w.temp==21 and w.text=='Sunny' and not w.busy)
w:configure('zh-CN','');assert(w.id=='101020100')
w:configure('de','Berlin');w:refresh();local old=requests[#requests];assert(old.p:find('/cities?',1,true))
w:configure('ja','Tokyo');w:refresh();old.cb(200,sjson.encode({code='200',location={{id='old',name='Berlin'}}}));assert(w.id==nil,'stale callback changed city')
requests[#requests].cb(200,sjson.encode({code='200',location={{id='tokyo',name='東京'}}}));assert(w.id=='tokyo');assert(requests[#requests].p:find('location=tokyo',1,true))
requests[#requests].cb(200,sjson.encode({code='200',now={temp='17',text='晴れ'}}));assert(w.temp==17 and w.city=='東京')
local reopened=W.new('/',L,function()end);reopened:configure('ja','Tokyo');assert(reopened.id=='tokyo','city cache not restored')
reopened:refresh();requests[#requests].cb(500,'broken');assert(not reopened.busy and reopened.error~='');reopened:refresh();assert(reopened.busy,'cannot retry')
local P=module('preferences.lua');assert(P.save(file,sjson,'prefs',false,false,'ice','rebound',{language='de',address=''}));local p=P.load(file,sjson,'prefs');assert(p.language=='de' and p.address=='' and p.theme=='ice' and not p.seconds)
assert(P.save(file,sjson,'prefs',false,true,'dark','original',{language='auto'}));assert(P.load(file,sjson,'prefs').address==nil)
key={LEFT=1,RIGHT=2,UP=3,DOWN=4,HOME=5,START=10,SHORT=11,LONG_START=12,LONG_REPEAT=13,LONG_END=14}
local moves,confirms,items,backs,exits=0,0,0,0,0
local input=module('input.lua').new({move=function(d)moves=moves+d end,item=function(d)items=items+d end,confirm=function()confirms=confirms+1 end,back=function()backs=backs+1 end,exit=function()exits=exits+1 end})
for _,evt in ipairs({key.START,key.SHORT,key.LONG_START,key.LONG_REPEAT,key.LONG_END})do input:handle(key.UP,evt);input:handle(key.DOWN,evt)end
assert(moves==0 and confirms==0 and items==0 and backs==0 and exits==0,'forward/back must do nothing')
input:handle(key.LEFT,key.START);input:handle(key.LEFT,key.SHORT);input:handle(key.LEFT,key.LONG_START);for i=1,6 do input:handle(key.LEFT,key.LONG_REPEAT)end;assert(moves==1,'original left hold once')
input:handle(key.RIGHT,key.START);input:handle(key.RIGHT,key.SHORT);input:handle(key.RIGHT,key.LONG_START);for i=1,6 do input:handle(key.RIGHT,key.LONG_REPEAT)end;assert(items==1 and confirms==1 and moves==1,'original right short/hold mapping')
input:handle(key.HOME,key.SHORT);assert(exits==1)
input:pad({buttons=16});input:pad({buttons=16});assert(confirms==2);input:pad({buttons=0});input:pad({buttons=16});assert(confirms==3)
input:pad({buttons=4});assert(moves==0);input:pad({buttons=8});assert(moves==1)

`);
console.log('PASS Lua syntax, localization, weather lookup/cache/defaults/retry/stale callbacks, preference restoration, original gyro mapping, no forward/back actions, Launcher controller edges');
