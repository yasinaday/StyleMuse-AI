const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const http=require('node:http');const path=require('node:path');
const {chromium}=require('playwright');
const fixtures=process.env.STYLEMUSE_FIXTURE_ROOT||'/opt/stylemuse-ai';
const source='data:image/png;base64,'+fs.readFileSync(fixtures+'/approved-four-test/bordo-canta.png').toString('base64');
const generated='data:image/png;base64,'+fs.readFileSync(fixtures+'/final-four-products/products/bordo-canta.png').toString('base64');
test('375px review has large labelled SAM3/fal images, reject and immediate duplicate-safe save',async()=>{
 const server=http.createServer((q,s)=>{s.setHeader('Content-Type','text/html');s.end(fs.readFileSync(path.join(__dirname,'../../index.html')))});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
 try{
  browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/root/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--no-sandbox']});
  const page=await browser.newPage({viewport:{width:375,height:812},isMobile:true,hasTouch:true});
  const origin=`http://127.0.0.1:${server.address().port}`;
  await page.route('**/*',r=>r.request().url().startsWith(origin)?r.continue():r.abort());await page.goto(origin);
  await page.evaluate(({source,generated})=>{
   multiSource=source;updateAiBudget({lifetime_budget_usd:.5,reserved_usd:.5});
   aiParts=[{id:'bag',image:generated,originalPreview:source,category:'Çanta',selected:true,generated:true,review:'pending'}];showAiParts();
  },{source,generated});
  const images=page.locator('.ai-generated img');
  for(let i=0;i<2;i++){const box=await images.nth(i).boundingBox();assert.ok(box.width>=250&&box.height>=220,JSON.stringify(box))}
  assert.match(await page.locator('.ai-generated').innerText(),/SAM 3/);assert.match(await page.locator('.ai-generated').innerText(),/fal.ai/);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  const evidence=fs.mkdtempSync(path.join(__dirname,'evidence/large-budget-review-'));
  await page.locator('.ai-generated').screenshot({path:path.join(evidence,'comparison-375.png')});
  await page.getByRole('button',{name:'Reddet',exact:true}).scrollIntoViewIfNeeded();
  const reviewScroll=await page.locator('.ai-review-panel').evaluate(el=>el.scrollTop);
  await page.getByRole('button',{name:'Reddet',exact:true}).click();
  assert.equal(await page.locator('.ai-review-panel').evaluate(el=>el.scrollTop),reviewScroll);
  await page.screenshot({path:path.join(evidence,'review-actions-375.png')});
  console.log('Mobile review evidence:',evidence);
  assert.equal(await page.evaluate(()=>localStorage.getItem('sm-items')),null);
  await page.getByRole('button',{name:'Kabul et ve kaydet',exact:true}).click();
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('sm-items')).length),1);
  assert.equal(await page.getByRole('button',{name:'✓ Dolaba kaydedildi',exact:true}).isDisabled(),true);
  assert.equal(await page.getByRole('button',{name:'Reddet',exact:true}).isDisabled(),true);
  await page.evaluate(()=>reviewAiPart(0,'accepted'));
  assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('sm-items')).length),1);
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r))}
});
