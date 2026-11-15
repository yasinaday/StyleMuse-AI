const {test}=require('node:test');
const assert=require('node:assert/strict');
const {app}=require('./offline-harness.cjs');
test('VM harness supplies form collection, removal and monotonic clock used by current app',()=>{
 const a=app();
 assert.ok(Array.isArray(a.get('style-profile-form').elements));
 assert.equal(typeof a.get('ai-budget').remove,'function');
 assert.equal(typeof a.ctx.performance.now,'function');
 assert.ok(Number.isFinite(a.ctx.performance.now()));
 assert.equal(typeof a.ctx.AbortSignal.timeout,'function');
 assert.equal(a.ctx.document.documentElement.lang,'tr');
});
