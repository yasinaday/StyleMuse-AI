const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('playwright');
const html=fs.readFileSync(path.join(__dirname,'../../index.html'),'utf8');
const image='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';
test('restored legacy string IDs support zoom, edit, selection and removal after reload',async()=>{
 const browser=await chromium.launch({headless:true});
 try{
  const context=await browser.newContext({serviceWorkers:'block'});
  await context.route('**/*',r=>r.request().url()==='https://offline.invalid/'?r.fulfill({contentType:'text/html',body:html}):r.abort());
  const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto('https://offline.invalid/');await page.waitForFunction(()=>wardrobeReady);
  const backup={version:2,items:[{id:'legacy_42',image,category:'Çanta'},{id:'legacy-43',image,category:'Üst giyim'}],looks:[],preferences:{'sm-name':'Legacy'}};
  await Promise.all([page.waitForEvent('load'),page.evaluate(data=>{confirmStyleAction=async()=>true;void restoreData({files:[new File([JSON.stringify(data)],'legacy.json')],value:'legacy'});},backup)]);
  await page.waitForFunction(()=>wardrobeReady&&getItems().length===2);
  await page.evaluate(()=>tab('closet'));
  await page.locator('#items img').first().click();
  assert.equal(await page.locator('#zoom-overlay').evaluate(el=>el.classList.contains('active')),true);
  assert.equal(await page.locator('#zoom-image').getAttribute('src'),image);
  await page.evaluate(()=>closeZoom());
  await page.locator('#items .item-meta button').first().click();
  // Assert immediately on handler errors so RED identifies the compatibility bug.
  assert.deepEqual(errors,[]);
  await page.waitForFunction(()=>document.getElementById('crop-modal').classList.contains('active'));
  assert.equal(await page.evaluate(()=>cropEditId),'legacy_42');
  await page.evaluate(()=>{closeCrop();tab('tryon');renderTry()});
  await page.locator('#try-choices button').first().click();
  assert.deepEqual(await page.evaluate(()=>chosenTry),['legacy_42']);
  assert.equal(await page.locator('#mannequin-selected img').count(),1);
  await page.locator('#try-choices button').first().click();
  assert.deepEqual(await page.evaluate(()=>chosenTry),[]);
  await page.evaluate(()=>{tab('closet');confirmStyleAction=async()=>true});
  await page.locator('#items .item-meta button').nth(1).click();
  await page.waitForFunction(()=>getItems().length===1);
  assert.equal(await page.evaluate(()=>getItems()[0].id),'legacy-43');
  await page.reload();await page.waitForFunction(()=>wardrobeReady);
  assert.deepEqual(await page.evaluate(()=>getItems().map(x=>x.id)),['legacy-43']);
  assert.deepEqual(errors,[]);
 }finally{await browser.close()}
});
