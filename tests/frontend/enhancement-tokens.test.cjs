// Offline fixtures only. All account/quote/provider transport is replaced.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {app}=require('./offline-harness.cjs');
for(const scenario of [
 {name:'one item quotes and approves 2 tokens',n:1,tokens:2,balance:9,approve:true,requests:1},
 {name:'two items quote and approve 4 tokens',n:2,tokens:4,balance:9,approve:true,requests:1},
 {name:'cancel sends no generation request',n:1,tokens:2,balance:9,approve:false,requests:0},
 {name:'insufficient balance sends no generation request',n:2,tokens:4,balance:3,approve:true,requests:0},
 {name:'cached zero-token quote works at zero balance',n:2,tokens:0,balance:0,approve:true,requests:1}
])test(scenario.name,async()=>{
 const a=app(),c=scenario,dialogs=[],requests=[];
 a.ctx.performance=require('node:perf_hooks').performance;
 a.ctx.showStyleDialog=async message=>{dialogs.push(message);return c.approve};
 a.ctx.refreshStyleMuseAccount=async()=>({balance:c.balance});
 a.ctx.openHomePro=()=>{};a.get('ai-budget').remove=()=>{};a.ctx.updateGithubStatus=()=>{};
 // Test actual generation, quote and balance control; rendering covered by browser acceptance.
 a.ctx.showAiParts=()=>{};
 a.run(`aiSessionPromise=Promise.resolve();aiJobId='fixture-job';aiReviewPhase='detail';aiParts=${JSON.stringify(Array.from({length:c.n},(_,i)=>({id:'fixture-'+i,image:'data:image/png;base64,YQ==',category:'Üst',selected:true,generated:false,category_verified:true,mask_quality:'verified'})))}`);
 a.ctx.fetch=async(url,opts)=>{
  const path=new URL(url).pathname,payload=JSON.parse(opts.body);requests.push({path,payload});
  let result;
  if(path==='/api/quote')result={quote_id:'offline-quote',action:'generate',style_tokens:c.tokens,estimated_cost_usd:c.tokens?.123:0,expires_in_seconds:90};
  else if(path==='/api/generate')result={items:Array.from({length:c.n},(_,i)=>({id:'fixture-'+i,image:'data:image/png;base64,YQ=='}))};
  else if(path==='/api/health')result={status:'ok'};
  else throw Error('Unexpected offline request '+path);
  return {ok:true,status:200,json:async()=>result};
 };
 await a.ctx.generateAiParts();
 assert.equal(requests.filter(x=>x.path==='/api/quote').length,1);
 const generated=requests.filter(x=>x.path==='/api/generate');assert.equal(generated.length,c.requests);
 if(c.balance<c.tokens)assert.equal(dialogs.length,0);
 else {assert.equal(dialogs.length,1);assert.ok(dialogs[0].includes(c.tokens+' Stil Jetonu'));assert.match(dialogs[0],/ek ücret veya ödeme değildir/);}
 if(c.requests)assert.deepEqual(generated[0].payload,{job_id:'fixture-job',item_ids:Array.from({length:c.n},(_,i)=>'fixture-'+i),quote_id:'offline-quote',approved_style_tokens:c.tokens,confirmed:true,max_total_usd:c.tokens?.123:0});
});
