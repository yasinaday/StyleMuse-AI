const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {chromium}=require('playwright');
const html=fs.readFileSync(require('node:path').join(__dirname,'../../index.html'),'utf8');
const png='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';
async function offline(fn){const browser=await chromium.launch({headless:true,args:['--disable-background-networking','--disable-component-update','--no-first-run','--host-resolver-rules=MAP * ~NOTFOUND']});try{const context=await browser.newContext({serviceWorkers:'block'});await context.route('**/*',r=>r.request().url()==='https://offline.invalid/'?r.fulfill({contentType:'text/html',body:html}):r.abort());const page=await context.newPage();await page.goto('https://offline.invalid/');await page.waitForFunction(()=>typeof parseStyleMuseBackup==='function'&&wardrobeReady);await fn(page);}finally{await browser.close()}}
async function setupPaid(page,action='detect'){
 await page.evaluate(({png,action})=>{
 window.requests=[];window.quoteNumber=0;canUseStyleTokens=async()=>true;
 aiPost=async(path,payload)=>{requests.push({path,payload});if(path==='/api/health')return {authenticated:true,status:'ok',enabled:true};if(path==='/api/quote')return {action:payload.action,quote_id:'quote-'+(++quoteNumber),estimated_cost_usd:payload.action==='generate'?.246:.073,expires_in_seconds:90};if(path==='/api/detect')return {job_id:'job',items:[]};if(path==='/api/generate')return {items:payload.item_ids.map(id=>({id,image:png}))};throw Error('Unexpected offline endpoint '+path)};
 multiSource=png;
 if(action==='generate'){aiJobId='job';aiReviewPhase='detail';aiParts=['one','two'].map(id=>({id,image:png,category:'Üst giyim',selected:true,generated:false,mask_quality:'verified',category_verified:true,quality_warnings:[]}));}
 window.pendingPaid=action==='generate'?generateAiParts():analyzeClothes();
 },{png,action});
 await page.waitForFunction(()=>document.getElementById('style-confirm').open);
}
for(const approved of [false,true])test('analysis displays quote and tokens together before '+(approved?'exact submission':'cancellation'),()=>offline(async page=>{
 await setupPaid(page);const message=await page.locator('#style-confirm-message').textContent();assert.match(message,/1 Stil Jetonu/);assert.match(message,/0\.073.*USD/);assert.match(message,/ek.*(ücret|ödeme).*değil/i);
 assert.equal(await page.evaluate(()=>requests.filter(r=>r.path==='/api/detect').length),0);
 await page.locator(approved?'#style-confirm-approve':'#style-confirm-cancel').click();await page.evaluate(()=>pendingPaid);
 const requests=await page.evaluate(()=>window.requests);const paid=requests.filter(r=>r.path==='/api/detect');assert.equal(paid.length,approved?1:0);if(approved){const quote=requests.find(r=>r.path==='/api/quote');assert.deepEqual(paid[0].payload,{...quote.payload.inputs,confirmed:true,quote_id:'quote-1',max_total_usd:.073});}
}));
for(const approved of [false,true])test('multi-item generation uses one server TOTAL and exact selected inputs; approval '+approved,()=>offline(async page=>{
 await setupPaid(page,'generate');const message=await page.locator('#style-confirm-message').textContent();assert.equal(await page.evaluate(()=>requests.filter(r=>r.path==='/api/quote').length),1);assert.match(message,/2 Stil Jetonu/);assert.match(message,/0\.246 USD/);assert.doesNotMatch(message,/0\.492/);assert.equal(await page.evaluate(()=>requests.filter(r=>r.path==='/api/generate').length),0);
 await page.locator(approved?'#style-confirm-approve':'#style-confirm-cancel').click();await page.evaluate(()=>pendingPaid);const requests=await page.evaluate(()=>window.requests);const paid=requests.filter(r=>r.path==='/api/generate');assert.equal(paid.length,approved?1:0);if(approved)assert.deepEqual(paid[0].payload,{job_id:'job',item_ids:['one','two'],quote_id:'quote-1',max_total_usd:.246,confirmed:true});
}));
for(const approveRenewal of [false,true])test('90-second expiry requires fresh quote and NEW explicit approval; renewed approval '+approveRenewal,()=>offline(async page=>{
 await page.evaluate(()=>{const now=performance.now.bind(performance);window.timeOffset=0;performance.now=()=>now()+timeOffset});
 await setupPaid(page);await page.evaluate(()=>{timeOffset=90001});await page.locator('#style-confirm-approve').click();
 await page.waitForTimeout(100);assert.equal(await page.evaluate(()=>requests.filter(r=>r.path==='/api/detect').length),0,'expired displayed quote must never submit');
 await page.waitForFunction(()=>quoteNumber===2&&document.getElementById('style-confirm').open,{},{timeout:2000});
 assert.equal(await page.evaluate(()=>requests.filter(r=>r.path==='/api/detect').length),0);
 await page.locator(approveRenewal?'#style-confirm-approve':'#style-confirm-cancel').click();await page.evaluate(()=>pendingPaid);
 const paid=await page.evaluate(()=>requests.filter(r=>r.path==='/api/detect'));assert.equal(paid.length,approveRenewal?1:0);if(approveRenewal)assert.equal(paid[0].payload.quote_id,'quote-2');
}));
test('wall-clock expiry during device sleep renews amount and requires approval again',()=>offline(async page=>{
 await page.evaluate(()=>{const now=Date.now;window.wallOffset=0;Date.now=()=>now()+wallOffset});await setupPaid(page);
 await page.evaluate(()=>{wallOffset=90001;const post=aiPost;aiPost=async(path,payload)=>{const result=await post(path,payload);return path==='/api/quote'?{...result,estimated_cost_usd:.129}:result}});
 await page.locator('#style-confirm-approve').click();await page.waitForTimeout(100);
 assert.equal(await page.evaluate(()=>requests.filter(r=>r.path==='/api/detect').length),0,'suspended monotonic clock must not extend server lease');
 await page.waitForFunction(()=>quoteNumber===2&&document.getElementById('style-confirm').open);
 assert.match(await page.locator('#style-confirm-message').textContent(),/0\.129 USD/);await page.locator('#style-confirm-approve').click();await page.evaluate(()=>pendingPaid);
 const paid=await page.evaluate(()=>requests.filter(r=>r.path==='/api/detect'));assert.equal(paid.length,1);assert.equal(paid[0].payload.quote_id,'quote-2');assert.equal(paid[0].payload.max_total_usd,.129);
}));
async function setupTryon(page){
 await page.evaluate(()=>{
 const canvas=document.createElement('canvas');canvas.width=canvas.height=16;const image=canvas.toDataURL('image/png');
 wardrobeCache=[{id:1,image,category:'Üst giyim'},{id:2,image,category:'Alt giyim'}];chosenTry=[1,2];mannequinPhotoData=image;styleMuseAccount={balance:10};canUseStyleTokens=async()=>true;window.requests=[];window.quoteNumber=0;
 tryonImageData=async()=>image;
 aiPost=async(path,payload)=>{requests.push({path,payload});if(path==='/api/health')return {authenticated:true,status:'ok',enabled:true};if(path==='/api/quote')return {action:'tryon',quote_id:'try-'+(++quoteNumber),estimated_cost_usd:.04*quoteNumber,expires_in_seconds:90};if(path==='/api/tryon')return {job_id:'job-'+quoteNumber};if(path==='/api/tryon/status')return {state:'done',image:'https://fal.media/result-'+quoteNumber+'.png'};throw Error(path)};
 window.pendingPaid=requestVirtualTryOn();
 });await page.waitForFunction(()=>document.getElementById('style-confirm').open);
}
for(const cancelAt of [1,2,0])test('sequential tryon independently quotes each step; cancel at '+cancelAt,()=>offline(async page=>{
 await setupTryon(page);assert.equal(await page.evaluate(()=>quoteNumber),1,'a step quote must precede its approval dialog');
 for(let step=1;step<=2;step++){
  await page.waitForFunction(step=>quoteNumber===step&&document.getElementById('style-confirm').open,step,{timeout:2000});
  assert.equal(await page.evaluate(()=>requests.filter(r=>r.path==='/api/tryon').length),step-1);
  const message=await page.locator('#style-confirm-message').textContent();assert.match(message,/1 Stil Jetonu/);assert.ok(message.includes(String(.04*step)+' USD'));
  await page.locator(cancelAt===step?'#style-confirm-cancel':'#style-confirm-approve').click();if(cancelAt===step)break;
 }
 await page.evaluate(()=>pendingPaid);const requests=await page.evaluate(()=>window.requests);const paid=requests.filter(r=>r.path==='/api/tryon');assert.equal(paid.length,cancelAt?cancelAt-1:2);
 for(let i=0;i<paid.length;i++){const quote=requests.filter(r=>r.path==='/api/quote')[i];assert.deepEqual(paid[i].payload,{...quote.payload.inputs,quote_id:'try-'+(i+1),max_total_usd:.04*(i+1),confirmed:true})}
}));
for(const action of ['generate','tryon'])test(action+' also renews expired quote and cancellation blocks paid submit',()=>offline(async page=>{
 await page.evaluate(()=>{const now=performance.now.bind(performance);window.timeOffset=0;performance.now=()=>now()+timeOffset});
 if(action==='tryon')await setupTryon(page);else await setupPaid(page,action);
 await page.evaluate(()=>{timeOffset=90000});await page.locator('#style-confirm-approve').click();await page.waitForFunction(()=>quoteNumber===2&&document.getElementById('style-confirm').open);
 const before=await page.evaluate(()=>window.requests);assert.equal(before.filter(r=>r.path==='/api/'+action).length,0);const quotes=before.filter(r=>r.path==='/api/quote');assert.deepEqual(quotes[0].payload.inputs,quotes[1].payload.inputs);
 await page.locator('#style-confirm-cancel').click();await page.evaluate(()=>pendingPaid);assert.equal(await page.evaluate(action=>requests.filter(r=>r.path==='/api/'+action).length,action),0);
}));
test('invalid quotes never reach approval; zero-cost cached generation remains valid',()=>offline(async page=>{
 const results=await page.evaluate(async()=>{
 const base={action:'tryon',quote_id:'q',estimated_cost_usd:.04,expires_in_seconds:90};let approvals=0;confirmStyleTokens=async()=>{approvals++;return true};const results=[];
 for(const mutation of [{action:'detect'},{quote_id:''},{quote_id:7},{estimated_cost_usd:'0.04'},{estimated_cost_usd:-1},{estimated_cost_usd:NaN},{estimated_cost_usd:Infinity},{estimated_cost_usd:0},{expires_in_seconds:undefined},{expires_in_seconds:0},{expires_in_seconds:91},{expires_in_seconds:'90'}]){
 aiPost=async()=>({...base,...mutation});let rejected=false;try{await approvePaidQuote('tryon',{},1,'Step')}catch{rejected=true}results.push({rejected,approvals});
 }
 aiPost=async()=>({...base,action:'generate',estimated_cost_usd:0});const cached=await approvePaidQuote('generate',{},2,'Cached');return {results,cached,approvals};
 });
 for(const result of results.results)assert.deepEqual(result,{rejected:true,approvals:0});assert.equal(results.cached.estimated_cost_usd,0);assert.equal(results.approvals,1);
}));
test('offline routed HTTP exercises real session/aiPost transport and exact approved payload',()=>offline(async page=>{
 const calls=[];await page.route('**/api/**',async route=>{
  const request=route.request(),path=new URL(request.url()).pathname;
  const headers={'access-control-allow-origin':'https://offline.invalid','access-control-allow-credentials':'true','access-control-allow-headers':'content-type'};
  if(request.method()==='OPTIONS')return route.fulfill({status:204,headers});
  const payload=request.postDataJSON();calls.push({path,payload});let body;
  if(path==='/api/session')body={authenticated:true};else if(path==='/api/health')body={authenticated:true,status:'ok',enabled:true};else if(path==='/api/quote')body={action:'detect',quote_id:'http-quote',estimated_cost_usd:.081,expires_in_seconds:90};else if(path==='/api/detect')body={job_id:'http-job',items:[]};else throw Error('Unexpected fixture endpoint '+path);
  await route.fulfill({headers,contentType:'application/json',body:JSON.stringify(body)});
 });
 await page.evaluate(png=>{canUseStyleTokens=async()=>true;refreshStyleMuseAccount=async()=>({});aiSessionPromise=null;multiSource=png;window.pendingPaid=analyzeClothes()},png);
 await page.waitForFunction(()=>document.getElementById('style-confirm').open);assert.match(await page.locator('#style-confirm-message').textContent(),/0\.081 USD/);assert.equal(calls.filter(x=>x.path==='/api/detect').length,0);
 await page.locator('#style-confirm-approve').click();await page.evaluate(()=>pendingPaid);
 assert.equal(calls.filter(x=>x.path==='/api/session').length,1);const quote=calls.find(x=>x.path==='/api/quote');const paid=calls.filter(x=>x.path==='/api/detect');assert.equal(paid.length,1);assert.deepEqual(paid[0].payload,{...quote.payload.inputs,quote_id:'http-quote',max_total_usd:.081,confirmed:true});
}));
for(const format of ['png','jpeg'])test('restored '+format+' profile survives startup reload',()=>offline(async page=>{
 const image=await page.evaluate(({png,format})=>{if(format==='png')return png;const c=document.createElement('canvas');c.width=c.height=1;return c.toDataURL('image/jpeg')},{png,format});
 await Promise.all([page.waitForEvent('load'),page.evaluate(image=>{confirmStyleAction=async()=>true;void restoreData({files:[new File([JSON.stringify({version:2,items:[],looks:[],preferences:{'sm-profile-photo':image}})],'backup.json')],value:'backup'})},image)]);
 await page.waitForFunction(()=>wardrobeReady);assert.equal(await page.locator('#profile-avatar').getAttribute('src'),image);
 await page.reload();await page.waitForFunction(()=>wardrobeReady);assert.equal(await page.locator('#profile-avatar').getAttribute('src'),image);
}));
