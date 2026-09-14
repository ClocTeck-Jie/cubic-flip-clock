-- Independent client of the firmware weather service. No Weather app code or state.
local W={}
local function trim(v)return tostring(v or ''):match('^%s*(.-)%s*$')end
local function enc(v)return tostring(v):gsub('([^%w%-_%.~])',function(c)return string.format('%%%02X',c:byte())end)end
function W.new(dir,L,notify)
 local s={generation=0,stopped=false,busy=false,city='',text='',error='',requests=0}
 local function decode(raw)
  if type(raw)~='string' then return nil end
  if raw:byte(1)==31 and raw:byte(2)==139 then local ok,v=pcall(zlib.gunzip,raw);if not ok then return nil end;raw=v end
  local ok,v=pcall(sjson.decode,raw);return ok and type(v)=='table' and v or nil
 end
 function s:configure(lang,address)
  self.generation=self.generation+1;self.busy=false;self.lang=lang;self.address=trim(address)
  self.city=self.address~='' and self.address or L.words[lang].city
  self.temp=nil;self.text='';self.error='';self.id=nil;self.updated=nil
  self.cacheKey=lang..'|'..self.address
  if self.address=='' then self.id=lang=='zh-CN' and '101020100' or '1E98E' end
  local cache=decode(file.getcontents(dir..'weather-cache.json'))
  if cache and cache.key==self.cacheKey and type(cache.id)=='string' and cache.id~='' then self.id=cache.id;self.city=cache.city or self.city end
  notify()
 end
 function s:refresh()
  if self.stopped or self.busy then return end
  self.busy=true;self.started=tmr.now();local generation=self.generation
  local function active()return not self.stopped and generation==self.generation end
  local function finish(err)
   if not active() then return end
   self.busy=false;self.error=err or '';notify()
  end
  local function get(path,done)
   if not http or not http.cubicserver or not http.cubicserver.get then finish('Weather service unavailable');return end
   self.requests=self.requests+1
   local ok,err=pcall(http.cubicserver.get,path,'Accept-Encoding: gzip\r\n',function(code,body)
    if not active() then return end
    local d=decode(body)
    if tonumber(code)~=200 or not d or tostring(d.code)~='200' then finish('Weather HTTP '..tostring(code)..' / API '..tostring(d and d.code or 'JSON'));return end
    done(d)
   end)
   if not ok then finish(tostring(err)) end
  end
  local lang=self.lang=='zh-CN' and 'zh' or self.lang
  local function now()
   get('/v1/weather/now?location='..enc(self.id)..'&unit=m&lang='..lang,function(d)
    local n=d.now
    if type(n)~='table' or not tonumber(n.temp) then finish('Weather temperature missing');return end
    self.temp=tonumber(n.temp);self.text=tostring(n.text or '');self.updated=tostring(d.updateTime or n.obsTime or '');finish()
   end)
  end
  if self.id then now() else
   get('/v1/weather/cities?location='..enc(self.address)..'&number=1&lang='..lang,function(d)
    local list=d.locations or d.location;local city=type(list)=='table' and list[1]
    if type(city)~='table' or trim(city.id)=='' then finish('City not found');return end
    self.id=tostring(city.id);self.city=trim(city.name)~='' and city.name or self.city
    pcall(function()file.putcontents(dir..'weather-cache.json',sjson.encode({key=self.cacheKey,id=self.id,city=self.city}))end)
    notify();now()
   end)
  end
 end
 function s:poll()
  if self.busy and (tmr.now()-self.started)%4294967296>30000000 then self.generation=self.generation+1;self.busy=false;self.error='Weather request timed out';notify() end
 end
 function s:stop()self.stopped=true;self.generation=self.generation+1 end
 return s
end
return W
