const fs=require('fs'),vm=require('vm'),assert=require('assert');
const {parseHTML}=require('linkedom');
const html=fs.readFileSync('package/index.html','utf8');
const {window}=parseHTML(html);const {document}=window;
// linkedom only implements the select getter; use native-like mutable values for this DOM test.
for(const e of document.querySelectorAll('select'))Object.defineProperty(e,'value',{writable:true,value:e.querySelector('option').value});
let posted,interval;const snapshot={ok:true,version:'1.2.0',theme:'ice',motion:'original',seconds:true,language:'auto',resolved_language:'de',follow_system_address:true,system_address:'Berlin',weather:{city:'Berlin',temp:21,text:'Sonnig'}};
const context=vm.createContext({document,console,setInterval:f=>interval=f,fetch:async(url,opts)=>{if(opts?.method==='POST'){posted=JSON.parse(opts.body);Object.assign(snapshot,posted);}return {ok:true,json:async()=>snapshot}}});
vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1],context);
(async()=>{await new Promise(setImmediate);assert.equal(document.documentElement.lang,'de');assert.equal(document.querySelectorAll('.swatch').length,7);assert(document.getElementById('weather').textContent.includes('21°C'));assert.equal(document.querySelector('.back').getAttribute('href'),'/main');
for(const language of ['en','de','ja','zh-CN']){snapshot.resolved_language=language;await interval();assert.equal(document.documentElement.lang,language);assert(document.querySelector('h1').textContent);}
assert.equal(document.getElementById('language'),null);assert.equal(document.getElementById('address'),null);assert.equal(document.getElementById('follow'),null);
await document.getElementById('settings').onsubmit({preventDefault(){}});assert.equal(posted.address,undefined);assert.equal(posted.language,undefined);assert.equal(posted.follow_system_address,undefined);assert.equal(posted.theme,'ice');console.log('PASS Web UI: follows four device languages, seven themes, no city/language controls or overrides, appearance submit, console link');})();
