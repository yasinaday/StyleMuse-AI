const {test}=require('node:test');
const assert=require('node:assert/strict');
const {app}=require('./offline-harness.cjs');
test('offline harness executes app script without consuming later external script markup',()=>{
 const a=app();assert.equal(a.run('typeof parseStyleMuseBackup'),'function');
});
