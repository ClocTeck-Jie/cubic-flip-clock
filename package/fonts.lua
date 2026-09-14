-- The complete font stays on SD. Only the current label's glyphs reach lv_font_load.
-- The native font allocator owns the compact buffer; Lua never loads the full bitmap.
local F={}
local function align(s)return s..string.rep('\0',(-#s)%4)end
local function codepoints(text,set)
 local i=1
 while i<=#text do
  local a,b,c,d=text:byte(i,i+3);local cp,n=a,1
  if a>=240 and d then cp=(a-240)*262144+(b-128)*4096+(c-128)*64+d-128;n=4
  elseif a>=224 and c then cp=(a-224)*4096+(b-128)*64+c-128;n=3
  elseif a>=192 and b then cp=(a-192)*64+b-128;n=2 end
  if cp>=0 and cp<=65535 then set[cp]=true end;i=i+n
 end
end
function F.new(dir)
 local self={slots={},bytes=0}
 local function build(size,codes,path)
  local src=assert(file.open(dir..'chinese'..size..'.bin','r'))
  local idx=assert(file.open(dir..'glyph'..size..'.idx','r'))
  local ok,result=pcall(function()
   local head=assert(src:read(48));local headsize=string.unpack('<I4',head)
   if headsize>48 then head=head..assert(src:read(headsize-48))end
   head=head:sub(1,12)..string.pack('<I2',3)..head:sub(15,34)..string.char(1,0)..head:sub(37)
   local glyphs,used,offsets={}, {}, {8};local length=8
   for _,cp in ipairs(codes)do
    idx:seek('set',cp*8);local rec=idx:read(8)
    if rec and #rec==8 then
     local off,len=string.unpack('<I4I4',rec)
     if len>0 and len<2048 then
      src:seek('set',off);local data=assert(src:read(len));assert(#data==len,'Incomplete glyph')
      used[#used+1]=cp;offsets[#offsets+1]=length;glyphs[#glyphs+1]=data;length=length+len
     end
    end
   end
   assert(#used>0 and #used<255,'Invalid glyph count')
   local deltas={};for _,cp in ipairs(used)do deltas[#deltas+1]=string.pack('<I2',cp-used[1])end
   local body=align(table.concat(deltas));local cmap=string.pack('<I4c4I4I4I4I2I2I2I1I1',28+#body,'cmap',1,28,used[1],used[#used]-used[1]+1,1,#used,3,0)..body
   local loc={};for _,off in ipairs(offsets)do loc[#loc+1]=string.pack('<I4',off)end
   local loca=string.pack('<I4c4I4',12+#offsets*4,'loca',#offsets)..table.concat(loc)
   local glyf=align(string.pack('<I4c4',length+(-length)%4,'glyf')..table.concat(glyphs))
   local raw=head..cmap..loca..glyf;assert(#raw<32768,'Font subset too large')
   file.putcontents(path,raw)
   return #raw
  end)
  src:close();idx:close();if not ok then error(result)end;return result
 end
 function self:set(slot,obj,size,text)
  text=tostring(text or '')
  -- Keep only digits reusable across time/temperature updates; all other glyphs
  -- come from the text actually displayed, not an entire language or ASCII set.
  local set={};for cp=48,57 do set[cp]=true end
  codepoints(text,set)
  local codes={};for cp in pairs(set)do codes[#codes+1]=cp end;table.sort(codes)
  local key=tostring(size)..':'..table.concat(codes,',');local old=self.slots[slot]
  if not old or old.key~=key then
   local path=dir..'.font-'..slot..'.bin';local bytes=build(size,codes,path)
   local font=assert(lv_font_load(path),'Font subset load failed')
   lv_obj_set_style_text_font(obj,font,LV_PART_MAIN|LV_STATE_DEFAULT)
   self.slots[slot]={key=key,font=font,bytes=bytes};self.bytes=self.bytes+bytes-(old and old.bytes or 0)
   if old then lv_font_free(old.font)end
  end
  lv_label_set_text(obj,text)
 end
 function self:stop()for _,s in pairs(self.slots)do pcall(lv_font_free,s.font)end;self.slots={};self.bytes=0 end
 return self
end
return F
