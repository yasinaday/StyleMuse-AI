const {test}=require('node:test');
const assert=require('node:assert/strict');
const {app}=require('./offline-harness.cjs');
test('manual balance risk and server date are visible before single-use analysis consent; cancel never submits',async()=>{
 const a=app();a.run("aiSessionPromise=Promise.resolve();multiSource='data:image/png;base64,YQ=='");
 a.ctx.confirm=message=>{a.confirms.push(message);return false};
 a.ctx.fetch=async(url,opts)=>{const path=new URL(url).pathname;a.calls.push({url:String(url)});return {ok:true,json:async()=>path.endsWith('/quote')?{quote_id:'fixture',action:'detect',estimated_cost_usd:.05,expires_in_seconds:90,provider_credit:{source:'manual_non_realtime',available_usd:.92,recorded_at:1794301200,expires_at:1794387600,overspend_risk:true}}:{status:'ok',enabled:true,authenticated:true}}};
 await a.ctx.analyzeClothes();assert.equal(a.confirms.length,1);const message=a.confirms[0];assert.match(message,/0.920000/);assert.match(message,/2026/);assert.match(message,/manuel/i);assert.match(message,/anlık değil/i);assert.match(message,/aşım riski/i);assert.equal(a.calls.filter(c=>c.url.endsWith('/detect')).length,0);
});
test('health cost display never presents historical lifetime ceiling as current spending limit',async()=>{
 const a=app();a.ctx.fetch=async()=>({ok:true,json:async()=>({status:'ok',enabled:true,authenticated:true,lifetime_budget_usd:.5,remaining_usd:0,spent_usd:.1,pending_usd:.2,app_spending_ceiling_usd:null,historical_budget_metadata:true})});
 await a.ctx.checkAiHealth();assert.doesNotMatch(a.get('ai-connection-state').textContent,/lifetime_budget_usd|remaining_usd/);assert.match(a.get('ai-connection-state').textContent,/0.10/);
});
