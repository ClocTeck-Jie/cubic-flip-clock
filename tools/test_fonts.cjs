const fs=require('fs'),assert=require('assert');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');const interop=require('fengari-interop');
const root='package/';let fonts=0,freed=0,maxRead=0;const generated={};
function glyphs(b){let t={},p=0;while(p<b.length){let n=b.readUInt32LE(p);assert(n>=8&&p+n<=b.length);t[b.toString('ascii',p+4,p+8)]=b.subarray(p,p+n);p+=n}let map={};const c=t.cmap,loc=t.loca;for(let j=0;j<c.readUInt32LE(8);j++){let a=12+j*16,off=c.readUInt32LE(a),start=c.readUInt32LE(a+4),len=c.readUInt16LE(a+8),gid=c.readUInt16LE(a+10),count=c.readUInt16LE(a+12),type=c[a+14];for(let i=0;i<(type===0||type===2?len:count);i++){let cp=start+(type===1||type===3?c.readUInt16LE(off+2*i):i);let id=gid+(type===2||type===3?i:type===0?c[off+i]:c.readUInt16LE(off+count*2+i*2));let stride=t.head[34]?4:2;let read=p=>stride===4?loc.readUInt32LE(p):loc.readUInt16LE(p);let x=read(12+id*stride),y=id+1<loc.readUInt32LE(8)?read(12+(id+1)*stride):t.glyf.length;map[cp]=t.glyf.subarray(x,y)}}return map}
const sources={};for(const size of [12,13,16])sources[size]=glyphs(fs.readFileSync(root+`chinese${size}.bin`));
globalThis.read=(p,o,n)=>{maxRead=Math.max(maxRead,n);const b=fs.readFileSync(root+p);return b.subarray(o,o+n).toString('hex')};
globalThis.write=(p,hex)=>{generated[p]=Buffer.from(hex,'hex')};
globalThis.validate=(p)=>{const b=generated[p];assert(b.length<16000);const size=b.readUInt16LE(14);const gs=glyphs(b);for(const [cp,g] of Object.entries(gs)){const src=sources[size][cp];assert(src);assert(g.equals(src)||g.subarray(0,src.length).equals(src));}fonts++;};
globalThis.free=()=>freed++;
globalThis.moduleSource=()=>fs.readFileSync(root+'fonts.lua','utf8');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);lauxlib.luaL_requiref(L,to_luastring('js'),interop.luaopen_js,1);lua.lua_pop(L,1);
const code=`local js=require('js');local function bytes(h)return h:gsub('..',function(x)return string.char(tonumber(x,16))end)end
file={open=function(path)local s={pos=0};function s:seek(_,p)self.pos=p end;function s:read(n)local b=bytes(js.global:read(path,self.pos,n));self.pos=self.pos+#b;return b end;function s:close()end;return s end,putcontents=function(p,v)js.global:write(p,(v:gsub('.',function(c)return string.format('%02x',c:byte())end)))end}
lv_font_load=function(p)js.global:validate(p);return p end;lv_font_free=function()js.global:free()end
LV_PART_MAIN=0;LV_STATE_DEFAULT=0;lv_obj_set_style_text_font=function()end;lv_label_set_text=function()end
local F=assert(load(js.global:moduleSource()))().new('')
F:set('city',1,12,'镇海 24°C');F:set('city',1,12,'镇海 23°C');F:set('city',1,12,'New York 23°C')
F:set('date',2,16,'2026年9月11日 星期五');F:set('bottom',3,13,'晴れ');F:set('bottom',3,12,'晴れ');F:set('bottom',3,12,'快晴');F:stop()
`;
if(lauxlib.luaL_dostring(L,to_luastring(code)))throw Error(to_jsstring(lua.lua_tostring(L,-1)));
assert.equal(fonts,6);assert.equal(freed,6);assert(maxRead<2048);console.log('PASS on-demand fonts: exact glyph bytes, no full-file reads, digit changes reuse font, replacement and stop release all handles; maximum read',maxRead);
