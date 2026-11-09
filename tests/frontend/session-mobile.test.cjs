const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const http=require('node:http');const path=require('node:path');
const {chromium}=require('playwright');
const html=fs.readFileSync(path.join(__dirname,'../../index.html'),'utf8');
test('mobile file picker previews locally; cookie session precedes health; disabled never detects',async()=>{
 const server=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html');res.end(html)});await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
 try{browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/root/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:375,height:812},isMobile:true,hasTouch:true});const calls=[],errors=[];page.on('pageerror',e=>errors.push(e.message));
 const origin=`http://127.0.0.1:${server.address().port}`;
 await page.route('**/*',async route=>{const req=route.request();if(req.url().startsWith(origin))return route.continue();if(req.url().includes('/api/')){calls.push({url:req.url(),headers:req.headers(),method:req.method()});return route.fulfill({json:req.url().endsWith('/session')?{status:'ok'}:{status:'ok',enabled:false,reserved_usd:.05}})}return route.abort()});
 await page.goto(origin);
 assert.equal(await page.locator('#sm-access-setting').count(),0,'no access-key field');
 await page.evaluate(()=>tab('closet'));
 const chooser=page.waitForEvent('filechooser');await page.locator('label[for="smart-photo"]').click();await (await chooser).setFiles({name:'phone.png',mimeType:'image/png',buffer:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64')});
 await page.waitForFunction(()=>document.querySelector('#ai-upload-preview')?.naturalWidth>0);
 assert.equal(calls.length,0,'selection must not call AI or session');
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 await page.screenshot({path:path.join(__dirname,`evidence/budget-session-mobile-preview-${Date.now()}.png`)});
 await page.locator('#ai-analyze').click();await page.waitForFunction(()=>document.querySelector('#ai-status').textContent.includes('Yetkisiz'));
 assert.deepEqual(calls.map(x=>new URL(x.url).pathname),['/api/session','/api/health']);assert.ok(calls.every(x=>!x.headers.authorization));
 assert.deepEqual(await page.evaluate(()=>performance.getEntriesByType('resource').filter(x=>x.name.includes('/api/')).map(x=>x.name.split('/').pop())),['session','health']);
 await page.getByRole('button',{name:'Elle kırp',exact:true}).click();
 await page.waitForFunction(()=>document.querySelector('#crop-modal').classList.contains('active'));
 assert.equal(await page.evaluate(()=>localStorage.getItem('sm-items')),null);
 assert.equal(await page.evaluate(()=>document.querySelector('#crop-canvas').getContext('2d').getImageData(300,300,1,1).data[3]),255);
 await page.getByRole('button',{name:'Parçayı kaydet ve devam et',exact:true}).click();
 assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('sm-items')).length),1);
 assert.equal(calls.length,2,'manual fallback must not send network requests');
 // The ordinary phone photo picker also decodes into the crop preview without AI.
 await page.locator('#photo').setInputFiles({name:'manual.png',mimeType:'image/png',buffer:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64')});
 await page.waitForFunction(()=>document.querySelector('#crop-modal').classList.contains('active'));
 assert.equal(calls.length,2);await page.getByRole('button',{name:'Vazgeç',exact:true}).last().click();
 assert.deepEqual(errors,[]);
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r))}
});
