const {test}=require('node:test');
const assert=require('node:assert/strict');
const {app}=require('./offline-harness.cjs');

test('health never describes blocked Replicate analysis as usable and never calls provider',async()=>{
 const a=app();await a.ctx.checkAiHealth();
 assert.match(a.get('ai-connection-state').textContent,/Replicate.*kredi.*doğrulanam/i);
 assert.match(a.get('ai-connection-state').textContent,/analiz.*engelli/i);
 assert.equal(a.calls.some(c=>/\/(detect|generate|quote)$/.test(c.url)),false);
});

test('provider credit unknown clearly blocks Replicate analysis without confirmation or inference and keeps owner session',async()=>{
 const a=app();a.run("aiSessionPromise=Promise.resolve();multiSource='data:image/png;base64,YQ=='");
 a.ctx.fetch=async(url,opts)=>{a.calls.push({url:String(url)});const quote=String(url).endsWith('/quote');return {ok:!quote,status:quote?402:200,json:async()=>quote?{error:'provider_credit_unavailable'}:{status:'ok',enabled:true,authenticated:true}}};
 await a.ctx.analyzeClothes();assert.equal(a.confirms.length,0);assert.equal(a.calls.filter(c=>c.url.endsWith('/detect')).length,0);
 assert.match(a.get('ai-status').textContent,/Replicate.*kredi.*doğrulanam/i);assert.notEqual(a.run('aiSessionPromise'),null);
 a.ctx.updateAiBudget({lifetime_budget_usd:1,reserved_usd:2,spent_usd:.64,pending_usd:.1});
 assert.doesNotMatch(a.get('ai-budget').textContent,/Kalan:|Toplam sınır:/);assert.match(a.get('ai-budget').textContent,/uygulama.*tavan.*yok/i);
});

test('generation quotes exact selected inputs before per-operation confirmation and cancellation never submits',async()=>{
 for(const approved of [false,true]){
  const a=app();let inputs;
  a.run("aiSessionPromise=Promise.resolve();aiJobId='fixture-job';multiSource='data:image/png;base64,YQ==';aiParts=[{id:'item',image:multiSource,category:'Çanta',selected:true,generated:false}]");
  a.ctx.confirm=message=>{a.confirms.push(message);assert.match(message,/0.123/);assert.ok(inputs);return approved};
  a.ctx.fetch=async(url,opts)=>{const path=new URL(url).pathname,payload=JSON.parse(opts.body);a.calls.push({url:String(url),payload});return {ok:true,json:async()=>{
   if(path.endsWith('/quote')){assert.equal(payload.action,'generate');inputs=payload.inputs;return {quote_id:'generate-quote',action:'generate',estimated_cost_usd:.123,expires_in_seconds:90}}
   if(path.endsWith('/generate')){assert.deepEqual(payload,{...inputs,quote_id:'generate-quote',max_total_usd:.123,confirmed:true});return {items:[{id:'item',image:'data:image/png;base64,YQ=='}]}}
   return {status:'ok',enabled:true,authenticated:true}
  }}};
  await a.ctx.generateAiParts();assert.equal(a.confirms.length,1);
  assert.equal(a.calls.filter(c=>c.url.endsWith('/generate')).length,approved?1:0);
 }
});

test('analysis obtains bound quote, shows server cost, confirms then submits exact quoted inputs despite historic cap',async()=>{
 const a=app();let quoteInputs;
 a.ctx.confirm=message=>{a.confirms.push(message);assert.match(message,/0.073/);assert.equal(a.calls.filter(c=>c.url.endsWith('/detect')).length,0);return true};
 a.ctx.fetch=async(url,opts)=>{const path=new URL(url).pathname,payload=JSON.parse(opts.body);a.calls.push({url:String(url),payload});return {ok:true,json:async()=>{
  if(path.endsWith('/quote')){assert.equal(payload.action,'detect');quoteInputs=payload.inputs;return {quote_id:'fixture-quote',action:'detect',estimated_cost_usd:.073,expires_in_seconds:90}}
  if(path.endsWith('/detect')){assert.deepEqual(payload,{...quoteInputs,quote_id:'fixture-quote',max_total_usd:.073,confirmed:true});return {job_id:'job',items:[{id:'item',preview:'data:image/png;base64,YQ==',category:'bag'}]}}
  return {status:'ok',enabled:true,authenticated:true,remaining_usd:0,lifetime_budget_usd:1}
 }}};
 a.run("multiSource='data:image/png;base64,YQ=='");await a.ctx.analyzeClothes();
 assert.equal(a.confirms.length,1);assert.equal(a.calls.filter(c=>c.url.endsWith('/detect')).length,1);
 assert.equal(a.run('aiParts[0].selected'),true);
});
