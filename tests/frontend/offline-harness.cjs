// Offline DOM/transport harness; all balances and provider results are fixtures.
const vm=require('node:vm'),fs=require('node:fs');
const html=fs.readFileSync(require('node:path').join(__dirname,'../../index.html'),'utf8');
function quoteFixture(action='detect'){return {quote_id:'offline-'+action,action,estimated_cost_usd:action==='detect'?.05:.1,expires_in_seconds:90}}
function app(){
 const els=new Map();const store=()=>{const m=new Map();return {getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,String(v)),removeItem:k=>m.delete(k)}};
 const element=()=>({value:'',textContent:'',innerHTML:'',style:{},dataset:{},disabled:false,classList:{add(){},remove(){},toggle(){}},addEventListener(){},appendChild(){},append(){},replaceChildren(){},querySelectorAll(){return []},querySelector(){return element()},setAttribute(){},focus(){},contains(){return true},getBoundingClientRect(){return {width:300,height:300}}});
 const get=id=>{if(!els.has(id))els.set(id,element());return els.get(id)};
 const calls=[],alerts=[],confirms=[];const ctx={console,URL,URLSearchParams,window:{addEventListener(){},location:{hash:'',pathname:'/',search:'',assign(){}}},history:{replaceState(){}},Blob,AbortController,setTimeout:(...args)=>{const t=setTimeout(...args);t.unref();return t},clearTimeout,crypto:require('node:crypto').webcrypto,localStorage:store(),sessionStorage:store(),document:{getElementById:get,createElement:element,querySelectorAll:()=>[],querySelector:element,body:element(),addEventListener(){}},scrollTo(){},alert:x=>alerts.push(x),confirm:x=>{confirms.push(x);return false},fetch:async(url,opts)=>{calls.push({url:String(url),...opts});return {ok:true,json:async()=>String(url).endsWith('/quote')?quoteFixture(JSON.parse(opts.body).action):({status:'ok',enabled:true,authenticated:true,login:'yasinaday'})}}};
 vm.createContext(ctx);vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1],ctx);
 return {ctx,get,calls,alerts,confirms,run:s=>vm.runInContext(s,ctx)};
}
module.exports={app,html,quoteFixture};
