// Real Chromium cookie engine + HTTPS ASGI fixture. All external URLs intercepted.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const path=require('node:path');
const {spawn,execFileSync}=require('node:child_process');
const {chromium}=require('playwright');
const ROOT=path.resolve(__dirname,'../..');
const API='https://localhost:19443', PAGES='https://yasinaday.github.io:19443/stylemuse-ai/';
const html=fs.readFileSync(path.join(ROOT,'index.html'),'utf8').replace("const STYLEMUSE_API='https://stylemuse-api.129.121.148.187.sslip.io'",`const STYLEMUSE_API='${API}'`);

test('real cross-site CHIPS: owner succeeds; forwarded launch, authorize and provider URLs fail', {timeout:180000}, async()=>{
 const dir=fs.mkdtempSync(path.join(ROOT,'evidence/oauth-browser-binding/browser-run-'));
 execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',dir+'/key.pem','-out',dir+'/cert.pem','-days','1','-subj','/CN=localhost'],{stdio:'ignore'});
 const output=fs.openSync(dir+'/fixture.log','wx');
 const server=spawn('/opt/stylemuse-ai/integration-venv/bin/python',['-m','uvicorn','oauth_browser_fixture:app','--host','127.0.0.1','--port','19443','--ssl-keyfile',dir+'/key.pem','--ssl-certfile',dir+'/cert.pem','--no-access-log'],{cwd:ROOT+'/server',env:{...process.env,OAUTH_FIXTURE_DIR:dir},stdio:['ignore',output,output]});
 let browser;
 try {
  browser=await chromium.launch({headless:true,executablePath:chromium.executablePath(),args:['--no-sandbox','--no-proxy-server','--host-resolver-rules=MAP yasinaday.github.io 127.0.0.1, MAP github.com 127.0.0.1','--disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessChecks']});
  let ready=false;
  for(let i=0;i<60;i++){try{execFileSync('curl',['-skf',API+'/api/health'],{stdio:'ignore'});ready=true;break}catch{}await new Promise(r=>setTimeout(r,100));}
  assert.ok(ready,'HTTPS fixture ready');
  const contexts=await Promise.all([browser.newContext({ignoreHTTPSErrors:true}),browser.newContext({ignoreHTTPSErrors:true})]);
  const seen=[];
  for(const context of contexts){await context.route('**/*',async route=>{
   const url=route.request().url();
   if([API,'https://yasinaday.github.io:19443','https://github.com:19443'].includes(new URL(url).origin))return route.continue();
   return route.abort();
  });context.on('request',r=>seen.push(new URL(r.url()).pathname));}
  const attacker=await contexts[0].newPage(), victim=await contexts[1].newPage();
  for(const page of [attacker,victim]){page.on('pageerror',e=>console.log('PAGE_ERROR',e.message));page.on('requestfailed',r=>console.log('REQUEST_FAILED',new URL(r.url()).pathname,r.failure()?.errorText));}
  const post=(page,endpoint,body={})=>page.evaluate(async({api,endpoint,body})=>{
   const response=await fetch(api+endpoint,{method:'POST',credentials:'include',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
   return {status:response.status,body:await response.json()};
  },{api:API,endpoint,body});
  const start=async page=>{await page.goto(PAGES);assert.equal((await post(page,'/api/session')).status,200);return (await post(page,'/api/auth/github/start')).body.launch_url;};
  // Forwarding the LAUNCH URL cannot bind the attacker's CHIPS session to victim.
  const forwardedLaunch=await start(attacker);
  const rejectedHandoff=victim.waitForResponse(r=>r.url()===API+'/api/auth/github/handoff');
  await victim.goto(forwardedLaunch);
  console.log('FORWARDED_LAUNCH_PAGE',await victim.evaluate(()=>({origin:location.origin,hasFragment:!!location.hash,status:document.getElementById('github-status')?.textContent})));
  assert.equal((await rejectedHandoff).status(),403);
  assert.equal((await post(attacker,'/api/session')).body.authenticated,false);
  assert.equal((await post(victim,'/api/session')).body.authenticated,false);
  // Capture the authorize URL BEFORE the initiating browser advances it.
  let releaseAuthorize, capturedAuthorize;
  const gate=new Promise(resolve=>releaseAuthorize=resolve);
  const captured=new Promise(resolve=>capturedAuthorize=resolve);
  await contexts[0].route(API+'/api/auth/github/authorize?*',async route=>{
   capturedAuthorize(route.request().url());await gate;await route.continue();
  },{times:1});
  await attacker.goto(PAGES);await attacker.evaluate(()=>loginGithub());
  const authorizeUrl=await captured;
  assert.equal((await victim.goto(authorizeUrl)).status(),403);
  releaseAuthorize();
  await attacker.waitForURL('https://github.com:19443/login/oauth/authorize?*');
  const provider=attacker.url(), state=new URL(provider).searchParams.get('state');
  const cookies=await contexts[0].cookies();
  const chips=cookies.find(c=>c.name==='__Host-stylemuse_session');
  const proof=cookies.find(c=>c.name==='__Host-stylemuse_oauth_browser');
  assert.ok(chips.partitionKey,'real CHIPS partition key exists');
  assert.equal(chips.httpOnly,true);assert.equal(chips.secure,true);
  assert.equal(proof.partitionKey,undefined);assert.equal(proof.sameSite,'Lax');assert.equal(proof.httpOnly,true);
  // Forward the real fixture provider URL and approve in the other browser.
  await victim.goto(provider);
  const rejectedCallback=victim.waitForResponse(r=>r.url().startsWith(API+'/api/auth/github/callback?'));
  await victim.locator('#consent').click();
  assert.equal((await rejectedCallback).status(),403);
  await victim.goto(PAGES);
  assert.equal((await post(victim,'/api/session')).body.authenticated,false);
  // The unrelated browser cannot invalidate the legitimate pending attempt.
  const callbackUrl=await attacker.locator('#consent').getAttribute('href');
  await attacker.locator('#consent').click();
  await attacker.waitForURL(PAGES);
  assert.equal((await post(attacker,'/api/session')).body.authenticated,true);
  const replay=await attacker.goto(callbackUrl);assert.equal(replay.status(),403);
  assert.ok(!seen.includes('/api/detect')&&!seen.includes('/api/generate'));
  console.log('PASS: two isolated contexts, actual cross-site CHIPS + top-level Lax cookie, forwarded launch and provider callback rejected, owner success, replay rejected, no AI calls');
  console.log('Browser evidence: '+dir);
 }finally{if(browser)await browser.close();server.kill('SIGTERM');await new Promise(r=>server.once('exit',r));fs.closeSync(output);}
});
