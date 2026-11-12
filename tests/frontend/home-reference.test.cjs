// Offline real-browser home acceptance checks. Never contacts AI providers.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {chromium}=require('playwright');
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const evidence=process.env.STYLEMUSE_HOME_EVIDENCE||path.join(root,'evidence/home-reference');
test('reference home: mobile layout, illustrations, routes and header controls',async()=>{
 fs.mkdirSync(evidence,{recursive:true});
 const server=http.createServer((req,res)=>{const relative=decodeURIComponent(new URL(req.url,'http://localhost').pathname);const file=path.resolve(root,'.'+(relative==='/'?'/index.html':relative));if(!file.startsWith(root+path.sep)){res.writeHead(403).end();return}try{res.setHeader('Content-Type',file.endsWith('.webp')?'image/webp':'text/html; charset=utf-8');res.end(fs.readFileSync(file))}catch{res.writeHead(404).end()}});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;const reports=[];
 try{browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})});
 for(const width of [360,390,430]){
  const page=await browser.newPage({viewport:{width,height:700},deviceScaleFactor:1,isMobile:true,hasTouch:true});const errors=[],paid=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('https://**/*',r=>{if(/\/api\/(detect|generate|tryon|quote)/.test(r.request().url()))paid.push(r.request().url());return r.abort()});
  await page.goto(`http://127.0.0.1:${server.address().port}`);await page.locator('.home-card img').last().waitFor();
  await page.waitForFunction(()=>[...document.querySelectorAll('#discover img')].every(x=>x.complete&&x.naturalWidth>0));
  const layout=await page.evaluate(()=>({width:innerWidth,scrollWidth:document.documentElement.scrollWidth,navTop:document.querySelector('.nav').getBoundingClientRect().top,cards:[...document.querySelectorAll('.home-card')].map(x=>({bottom:x.getBoundingClientRect().bottom,clipped:[...x.querySelectorAll('strong,span')].some(e=>e.scrollWidth>e.clientWidth+1||e.scrollHeight>e.clientHeight+1)}))}));
  assert.equal(layout.scrollWidth,width);assert.equal(layout.cards.length,4);assert.ok(layout.cards.every(x=>!x.clipped&&x.bottom<layout.navTop));
  await page.screenshot({path:path.join(evidence,`mobile-${width}.png`),fullPage:true});
  const chooser=page.waitForEvent('filechooser');await page.locator('.home-card-separate img').click();await chooser;assert.ok(await page.locator('#closet').isVisible());assert.ok(!await page.locator('#zoom-overlay').isVisible());await page.locator('[data-tab=discover]').click();
  for(const [selector,id] of [['tryon','tryon'],['outfits','outfits'],['wardrobe','closet']]){await page.locator(`.home-card-${selector} img`).click();assert.ok(await page.locator('#'+id).isVisible());assert.ok(!await page.locator('#zoom-overlay').isVisible());await page.locator('[data-tab=discover]').click()}
  for(const id of ['closet','outfits','tryon','profile','discover']){await page.locator(`[data-tab=${id}]`).click();assert.ok(await page.locator('#'+id).isVisible())}
  await page.getByRole('button',{name:'Menüyü aç',exact:true}).click();assert.ok(await page.locator('#home-menu').isVisible());
  await page.locator('#home-menu').getByRole('button',{name:'Giysiler',exact:true}).click();assert.ok(await page.locator('#closet').isVisible());await page.locator('[data-tab=discover]').click();
  assert.equal(await page.locator('[aria-controls=home-menu]').getAttribute('aria-expanded'),'false');
  await page.getByRole('button',{name:'PRO bilgileri',exact:true}).click();assert.ok(await page.locator('#home-pro').isVisible());await page.getByRole('button',{name:'Profil ve AI ayarları'}).click();assert.ok(await page.locator('#profile').isVisible());await page.locator('[data-tab=discover]').click();
  await page.locator('#site-brand-header').getByRole('button',{name:'Profil',exact:true}).click();assert.ok(await page.locator('#profile').isVisible());await page.locator('[data-tab=discover]').click();
  assert.deepEqual(errors,[]);assert.deepEqual(paid,[]);reports.push({width,layout,pageErrors:errors,paidRequests:paid});await page.close();
 }
 fs.writeFileSync(path.join(evidence,'results.json'),JSON.stringify(reports,null,2));
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r))}
});
