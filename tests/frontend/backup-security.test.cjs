const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {chromium}=require('playwright');
const html=fs.readFileSync(require('node:path').join(__dirname,'../../index.html'),'utf8');
const image='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';
async function offline(fn){
 const browser=await chromium.launch({headless:true});
 try{const context=await browser.newContext({serviceWorkers:'block'});
 await context.route('**/*',route=>route.request().url()==='https://offline.invalid/'?route.fulfill({contentType:'text/html',body:html}):route.abort());
 const page=await context.newPage();await page.goto('https://offline.invalid/');await page.waitForFunction(()=>typeof parseStyleMuseBackup==='function'&&wardrobeReady);await fn(page);
 }finally{await browser.close()}
}
test('backup wardrobe images never enter HTML strings across closet, suggestions and try-on',async()=>offline(async page=>{
 const result=await page.evaluate(({image})=>{
 wardrobeCache=parseStyleMuseBackup({version:2,items:[{id:1,image,category:'Üst giyim'},{id:2,image,category:'Alt giyim'}],looks:[],preferences:{}}).items;
 const descriptor=Object.getOwnPropertyDescriptor(Element.prototype,'innerHTML');const unsafe=[];
 Object.defineProperty(Element.prototype,'innerHTML',{...descriptor,set(value){if(String(value).includes(image))unsafe.push(this.id);descriptor.set.call(this,value)}});
 render();renderHomeRecent();suggest();chosenTry=[1,2];renderTry();
 return {unsafe,closet:document.querySelectorAll('#items img').length,choices:document.querySelectorAll('#try-choices img').length};
 },{image});assert.deepEqual(result.unsafe,[]);assert.equal(result.closet,2);assert.equal(result.choices,2);
}));
test('invalid restore preserves IndexedDB wardrobe, saved looks, preferences and visible closet',async()=>offline(async page=>{
 const result=await page.evaluate(async({image})=>{
 const items=[{id:7,image,category:'Çanta'}],looks=[{images:[image],aiImage:image}];
 await persistWardrobe(items);await persistSavedLooks(looks);localStorage.setItem('sm-name','Before');render();tab('closet');
 const read=async()=>{const db=await wardrobeDb();try{return await Promise.all(['items','saved-looks'].map(key=>new Promise((resolve,reject)=>{const q=db.transaction('wardrobe').objectStore('wardrobe').get(key);q.onsuccess=()=>resolve(q.result);q.onerror=()=>reject(q.error)})))}finally{db.close()}};
 const before=JSON.stringify(await read());let confirmations=0;confirmStyleAction=async()=>{confirmations++;return true};
 for(const bad of [
 {items:[{id:1,image:'data:image/svg+xml;base64,YQ==',category:'Çanta'}]},
 {items:[{id:1,image,category:'Çanta'},{id:'1',image,category:'Çanta'}]},
 {looks:[{images:[image],aiImage:'https://evil.invalid/x'}]},
 {preferences:{'sm-profile-photo':'javascript:alert(1)'}},
 ]){const data={version:2,items:[],looks:[],preferences:{'sm-name':'After'},...bad};await restoreData({files:[new File([JSON.stringify(data)],'bad.json')],value:'bad'});if(JSON.stringify(await read())!==before)throw Error('wardrobe mutated');}
 return {confirmations,name:localStorage.getItem('sm-name'),count:document.querySelectorAll('#items img').length,cache:getItems()[0].id,status:document.getElementById('backup-status').textContent};
 },{image});assert.deepEqual(result,{confirmations:0,name:'Before',count:1,cache:7,status:'Geri yüklenemedi.'});
}));
for(const version of [1,2])test('valid legacy backup version '+version+' restores and opens wardrobe after reload',async()=>offline(async page=>{
 const data=version===1?{version:1,'sm-items':JSON.stringify([image]),'sm-combos':JSON.stringify([{images:[image],aiImage:image}]),'sm-name':'Legacy'}:{version:2,items:[{id:42,image,category:'Çanta'}],looks:[{images:[image],aiImage:image}],preferences:{'sm-name':'Legacy'}};
 await Promise.all([page.waitForEvent('load'),page.evaluate(data=>{confirmStyleAction=async()=>true;void restoreData({files:[new File([JSON.stringify(data)],'backup.json')],value:'backup'});},data)]);
 await page.waitForFunction(()=>wardrobeReady&&getItems().length===1&&savedLooksCache.length===1);
 const result=await page.evaluate(()=>{tab('closet');renderSaved();return {count:document.querySelectorAll('#items img').length,src:document.querySelector('#items img').src,look:document.querySelector('#savedOutfits img').src,name:localStorage.getItem('sm-name')};});
 assert.equal(result.count,1);assert.equal(result.src,image);assert.equal(result.look,image);assert.equal(result.name,'Legacy');
}));
test('restored allowlisted result cannot create executable attributes in real DOM',async()=>offline(async page=>{
 const result=await page.evaluate(({image})=>{
 const payload='https://fal.media/x" onerror="globalThis.BACKUP_XSS=1';
 savedLooksCache=parseStyleMuseBackup({version:2,items:[],looks:[{images:[image],aiImage:payload}],preferences:{}}).looks;
 renderSaved();const img=document.querySelector('#savedOutfits img');img.dispatchEvent(new Event('error'));
 return {handler:img.getAttribute('onerror'),ran:globalThis.BACKUP_XSS||0,src:img.src};
 },{image});assert.equal(result.handler,null);assert.equal(result.ran,0);assert.match(result.src,/^https:\/\/fal.media\//);
}));
