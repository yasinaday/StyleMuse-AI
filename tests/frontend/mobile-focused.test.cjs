const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const http=require('node:http');const path=require('node:path');
const {chromium}=require('playwright');
async function mobile(width,run){
 const server=http.createServer((q,s)=>{s.setHeader('Content-Type','text/html');s.end(fs.readFileSync(path.join(__dirname,'../../index.html')))});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
 try {browser=await chromium.launch({headless:true,executablePath:process.env.CHROMIUM_PATH||'/root/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome',args:['--no-sandbox']});
 const page=await browser.newPage({viewport:{width,height:812},isMobile:true,hasTouch:true});
 const origin=`http://127.0.0.1:${server.address().port}`;
 await page.route('**/*',r=>r.request().url().startsWith(origin)?r.continue():r.abort());await page.goto(origin);
 await page.evaluate(()=>{const c=document.createElement('canvas');c.width=80;c.height=240;const ctx=c.getContext('2d');ctx.fillStyle='red';ctx.fillRect(0,0,80,240);window.fixture=c.toDataURL();multiSource=fixture;aiParts=[{id:'one',image:fixture,originalPreview:fixture,category:'Çanta',selected:true,generated:true,review:'pending'}];showAiParts()});
 await run(page);
 } finally {if(browser)await browser.close();await new Promise(r=>server.close(r))}
}
for(const width of [320,360,390,412])test(`compact focused uncropped comparison at ${width}px`,()=>mobile(width,async page=>{
 assert.equal(await page.locator('.ai-model').isVisible(),false,'single product must not repeat full outfit');
 const imgs=page.locator('.ai-generated img');assert.equal(await imgs.count(),2);
 for(const img of await imgs.all()){assert.equal(await img.evaluate(el=>getComputedStyle(el).objectFit),'contain');assert.equal(await img.evaluate(el=>el.naturalHeight),240);assert.ok((await img.boundingBox()).height<=200,'compact comparison');}
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 assert.equal(await page.locator('.ai-review-panel').evaluate(el=>el.scrollWidth<=el.clientWidth),true);
 if(process.env.STYLEMUSE_UI_EVIDENCE)await page.locator('.ai-review-panel').screenshot({path:path.join(process.env.STYLEMUSE_UI_EVIDENCE,'comparison-'+width+'.png')});
}));
test('multiple mobile candidates show one product and navigation preserves state',()=>mobile(360,async page=>{
 await page.evaluate(()=>{aiParts=[0,1,2].map((n)=>({id:'candidate-'+n,image:fixture,originalPreview:fixture,category:'Çanta',selected:n!==1,generated:true,review:n===1?'rejected':'pending'}));showAiParts()});
 const before=await page.evaluate(()=>JSON.stringify(aiParts));
 assert.equal(await page.locator('.ai-piece').count(),3,'keep all candidates in DOM');
 assert.equal(await page.locator('.ai-piece:visible').count(),1,'only active product visible');
 assert.equal(await page.locator('.ai-model').isVisible(),false);
 assert.equal(await page.getByRole('button',{name:'Önceki ürün',exact:true}).isDisabled(),true);
 for(const index of [1,2]){
  await page.getByRole('button',{name:'Sonraki ürün',exact:true}).click();
  assert.equal(await page.locator('.ai-piece:visible').count(),1);
  assert.equal(await page.locator('.ai-piece').nth(index).isVisible(),true);
 }
 assert.equal(await page.getByRole('button',{name:'Sonraki ürün',exact:true}).isDisabled(),true);
 await page.getByRole('button',{name:'Önceki ürün',exact:true}).click();
 assert.equal(await page.locator('.ai-piece').nth(1).isVisible(),true);
 await page.evaluate(()=>showAiParts());
 assert.equal(await page.locator('.ai-piece').nth(1).isVisible(),true,'rerender keeps active candidate');
 assert.equal(await page.evaluate(()=>JSON.stringify(aiParts)),before);
 for(const img of await page.locator('.ai-piece:visible img').all())assert.equal(await img.evaluate(el=>getComputedStyle(el).objectFit),'contain');
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 assert.equal(await page.locator('.ai-review-panel').evaluate(el=>el.scrollWidth<=el.clientWidth),true);
 await page.evaluate(()=>{aiParts.forEach(p=>p.generated=false);showAiParts()});
 assert.equal(await page.locator('.ai-model').isVisible(),true,'ungenerated detection retains original outfit');
 assert.equal(await page.locator('#ai-original').getAttribute('src'),await page.evaluate(()=>fixture));
 await page.setViewportSize({width:900,height:812});
 await page.evaluate(()=>{aiParts.forEach(p=>p.generated=true);showAiParts()});
 assert.equal(await page.locator('.ai-piece:visible').count(),3,'desktop keeps all products visible');
}));
module.exports={mobile};

for(const quality of [undefined,'low','missing'])test('quality warning: '+quality,()=>mobile(360,async page=>{
 await page.evaluate(quality=>{aiParts[0].mask_quality=quality;aiParts[0].quality_warnings=['Mask edge uncertain'];aiParts[0].category_verified=false;showAiParts()},quality);
 assert.match(await page.locator('.ai-piece').innerText(),/Maske.*(doğrulanmadı|düşük|eksik)/);
 assert.match(await page.locator('.ai-piece').innerText(),/Mask edge uncertain/);
 assert.match(await page.locator('.ai-piece').innerText(),/Kategori doğrulanmadı/);
 assert.doesNotMatch(await page.locator('.ai-piece').evaluate(el=>getComputedStyle(el,'::after').content),/✓/);
}));

for(const width of [320,360,390,412])test('reject accept save and confirmed deletion '+width,()=>mobile(width,async page=>{
 await page.evaluate(()=>{localStorage.setItem('sm-items',JSON.stringify([{id:7,image:fixture,category:'Çanta',custom:'preserve'}]));localStorage.setItem('sm-name','kept');localStorage.setItem('sm-ai-results','opaque retained');render()});
 await page.getByRole('button',{name:'Reddet',exact:true}).click();
 assert.equal(await page.evaluate(()=>aiParts[0].review),'rejected');
 assert.equal(await page.evaluate(()=>getItems().length),1);
 await page.getByRole('button',{name:'Kabul et ve kaydet',exact:true}).click();
 assert.equal(await page.evaluate(()=>aiParts[0].review),'accepted');
 assert.equal(await page.evaluate(()=>getItems().length),2);
 assert.equal(await page.getByRole('button',{name:'✓ Dolaba kaydedildi',exact:true}).isDisabled(),true);
 assert.equal(await page.getByRole('button',{name:'Reddet',exact:true}).isDisabled(),true);
 await page.evaluate(()=>{showAiParts();reviewAiPart(0,'accepted')});
 assert.equal(await page.evaluate(()=>getItems().length),2);
 await page.locator('#ai-review').getByRole('button',{name:'Kapat',exact:true}).click();
 await page.locator('.nav button[data-tab="closet"]').click();
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 page.once('dialog',d=>d.dismiss());await page.getByRole('button',{name:'Sil',exact:true}).last().click();
 assert.equal(await page.evaluate(()=>getItems().length),2);
 page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'Sil',exact:true}).last().click();
 assert.deepEqual(await page.evaluate(()=>getItems().map(x=>[x.id,x.custom])),[[7,'preserve']]);
 assert.deepEqual(await page.evaluate(()=>[localStorage.getItem('sm-name'),localStorage.getItem('sm-ai-results')]),['kept','opaque retained']);
}));
test('saved combinations resist duplicate save and require deletion confirmation',()=>mobile(360,async page=>{
 await page.evaluate(()=>{closeAiReview();localStorage.setItem('sm-items',JSON.stringify([{id:1,image:fixture,category:'Elbise'}]));tab('outfits')});
 await page.getByRole('button',{name:'Bana fikir ver ✦',exact:true}).click();
 await page.getByRole('button',{name:'♡ Kaydet',exact:true}).click();
 assert.equal(await page.locator('#suggestion .actions button').first().isDisabled(),true);
 await page.evaluate(()=>saveCombo());assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('sm-combos')).length),1);
 page.once('dialog',d=>d.dismiss());await page.getByRole('button',{name:'Kaldır',exact:true}).click();
 assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('sm-combos')).length),1);
 page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'Kaldır',exact:true}).click();
 assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('sm-combos')).length),0);
}));

for(const [status,expected] of [['missing',/Maske eksik/],['review_required',/Maske kalitesi düşük — elle kontrol et/],['unverified',/Maske kalitesi doğrulanmadı/]])test('backend quality object: '+status,()=>mobile(360,async page=>{
 await page.evaluate(status=>{aiParts[0].mask_quality={status,source:'detector_mask'};aiParts[0].quality_warnings=['semantic_category_unverified','mask_completeness_unverified','mask_quality_unavailable','small_mask','image_boundary_contact'];showAiParts()},status);
 const text=await page.locator('.ai-piece').innerText();assert.match(text,expected);
 for(const translation of ['Kategori doğrulanmadı','Maske bütünlüğü doğrulanmadı','Maske kalitesi bilgisi mevcut değil','Maske çok küçük','Maske görselin sınırına temas ediyor'])assert.ok(text.includes(translation),translation);
 assert.doesNotMatch(text,/semantic_category_unverified|mask_completeness_unverified|mask_quality_unavailable|small_mask|image_boundary_contact/);
}));

test('detection retains conservative provider quality metadata',()=>mobile(360,async page=>{
 await page.evaluate(()=>{closeAiReview();window.confirm=()=>true;aiPost=async path=>path==='/api/detect'?{job_id:'mock',items:[{id:'mask',preview:fixture,category:'bag',mask_quality:'low',quality_warnings:['Mock mask warning'],category_verified:false}]}:{status:'ok',enabled:true,authenticated:true,remaining_usd:.45};});
 await page.evaluate(()=>analyzeClothes());
 assert.match(await page.locator('.ai-piece').innerText(),/Maske kalitesi düşük/);
 assert.match(await page.locator('.ai-piece').innerText(),/Mock mask warning/);
}));
