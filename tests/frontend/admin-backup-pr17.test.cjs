const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('playwright');
const html=fs.readFileSync(path.join(__dirname,'../../index.html'),'utf8');
const image='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';
async function offline(fn){const browser=await chromium.launch({headless:true});try{const context=await browser.newContext({serviceWorkers:'block'});await context.route('**/*',r=>r.request().url()==='https://offline.invalid/'?r.fulfill({contentType:'text/html',body:html}):r.abort());const page=await context.newPage();await page.goto('https://offline.invalid/');await page.waitForFunction(()=>wardrobeReady);await fn(page);}finally{await browser.close();}}
test('normal and signed-out accounts cannot invoke hidden admin tools',()=>offline(async page=>{
 const result=await page.evaluate(async()=>{let calls=[];aiPost=async p=>{calls.push(p);return {request_id:'x'}};for(const user of [null,{admin:false},{admin:'true'}]){renderStyleMuseAccount({user});document.getElementById('profile-management').hidden=false;await refreshFalCredit();await refreshReplicateCredit();document.getElementById('sm-replicate-credit').value='1';await saveProviderBalance();document.getElementById('token-load-amount').value='1';document.getElementById('token-load-form').dispatchEvent(new Event('submit',{cancelable:true}));let read=false;await importWardrobePackage({target:{files:[{text:async()=>{read=true;return '{}'}}],value:'x'}});if(read)calls.push('package-read');}return calls;});assert.deepEqual(result,[]);
}));
for(const version of [1,2])test('V'+version+' restore then real downloaded V2 export preserves data and excludes credentials',()=>offline(async page=>{
 const data=version===1?{version:1,'sm-items':JSON.stringify([image]),'sm-combos':JSON.stringify([{images:[image],aiImage:image}]),'sm-name':'Offline'}:{version:2,items:[{id:'item-1',image,category:'Çanta'}],looks:[{images:[image],aiImage:image}],preferences:{'sm-name':'Offline'}};
 await Promise.all([page.waitForEvent('load'),page.evaluate(data=>{confirmStyleAction=async()=>true;void restoreData({files:[new File([JSON.stringify(data)],'backup.json')],value:'backup'});},data)]);
 await page.waitForFunction(()=>wardrobeReady&&savedLooksCache.length===1);
 await page.evaluate(()=>{localStorage.setItem('secret-token','never-export');localStorage.setItem('sm-session','never-export');});
 const downloaded=page.waitForEvent('download');await page.evaluate(()=>exportData());const download=await downloaded;const exported=JSON.parse(fs.readFileSync(await download.path(),'utf8'));assert.equal(exported.version,2);assert.equal(exported.items[0].image,image);assert.equal(exported.looks[0].aiImage,image);assert.equal(exported.preferences['sm-name'],'Offline');assert.doesNotMatch(JSON.stringify(exported),/never-export/);
}));
