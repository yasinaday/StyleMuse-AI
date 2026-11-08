const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const http=require('node:http');
const {chromium}=require('playwright');
const html=fs.readFileSync(require('node:path').join(__dirname,'../../index.html'),'utf8');
const image='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
test('mobile real DOM: confirmations, selected-only generation, explicit save, session-only credential',async()=>{
 const server=http.createServer((req,res)=>{res.setHeader('Content-Type','text/html');res.end(html)});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 let browser;
 try{
 browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/root/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width:375,height:812},isMobile:true,hasTouch:true});
 const errors=[],requests=[],dialogs=[];let accept=false;
 page.on('pageerror',e=>errors.push(e.message));
 page.on('dialog',async d=>{dialogs.push(d.message());await (accept?d.accept():d.dismiss())});
 const origin=`http://127.0.0.1:${server.address().port}`;
 await page.route('**/*',async route=>{
 const url=route.request().url();
 if(url.startsWith(origin))return route.continue();
 if(url.startsWith('https://fixture.invalid/api/')){
 const payload=route.request().postDataJSON();requests.push({url,payload});
 const body=url.endsWith('/detect')?{job_id:'job',items:[{id:'top',category:'Üst giyim',preview:image},{id:'bag',category:'Çanta',preview:image}]}:{items:[{id:'bag',image}]};
 return route.fulfill({json:body});
 }
 return route.abort();
 });
 await page.goto(origin);
 await page.evaluate(()=>tab('profile'));
 await page.locator('#sm-api-setting').fill('https://fixture.invalid');
 await page.locator('#sm-access-setting').fill('fixture-session-token');
 await page.getByRole('button',{name:'Bağlantıyı kaydet',exact:true}).click();
 assert.equal(await page.locator('#sm-access-setting').inputValue(),'');
 assert.equal(await page.evaluate(()=>JSON.stringify(localStorage).includes('fixture-session-token')),false);
 assert.equal(html.includes('fixture-session-token'),false);
 assert.doesNotMatch(html,/(?:FAL_KEY|FAL_API_KEY)\s*[:=]\s*['"][^'"]+['"]/);
 await page.evaluate(()=>tab('closet'));
 await page.locator('#smart-photo').setInputFiles({name:'outfit.png',mimeType:'image/png',buffer:Buffer.from(image.split(',')[1],'base64')});
 await page.waitForFunction(()=>document.querySelector('#ai-status')?.textContent.includes('iptal'));
 assert.equal(requests.length,0);assert.match(dialogs[0],/0,05 USD/);
 accept=true;
 await page.locator('#smart-photo').setInputFiles({name:'outfit.png',mimeType:'image/png',buffer:Buffer.from(image.split(',')[1],'base64')});
 await page.waitForFunction(()=>typeof aiBusy!=='undefined'&&!aiBusy&&aiParts.length===2);
 const boxes=page.locator('#ai-cards input[type=checkbox]');
 assert.equal(await boxes.nth(1).isEnabled(),true,'detection completion must re-enable selection');
 assert.equal(await boxes.nth(0).isChecked(),false);
 await boxes.nth(1).check();
 accept=false;await page.locator('#ai-generate').click();assert.equal(requests.length,1);
 accept=true;await page.locator('#ai-generate').click();
 await page.waitForFunction(()=>!aiBusy&&aiParts[1].generated);
 assert.deepEqual(requests[1].payload.item_ids,['bag']);assert.equal(requests[1].payload.confirmed,true);assert.equal(requests[1].payload.max_total_usd,.1);
 assert.equal(requests[0].payload.confirmed,true);assert.equal(requests[0].payload.max_total_usd,.05);
 assert.match(dialogs.at(-1),/toplam 0.10 USD/);
 assert.equal(await page.evaluate(()=>localStorage.getItem('sm-items')),null);
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 const panel=await page.locator('.ai-review-panel').boundingBox();assert.ok(panel.x>=0&&panel.x+panel.width<=375);
 await page.screenshot({path:require('node:path').join(__dirname,'evidence/mobile-review.png')});
 await page.getByRole('button',{name:'✓ Seçilen üretilmiş ürünleri kaydet',exact:true}).click();
 assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('sm-items')).length),1);
 assert.deepEqual(errors,[]);
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r))}
});
