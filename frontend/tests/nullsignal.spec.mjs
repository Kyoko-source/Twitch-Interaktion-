import {test,expect} from '@playwright/test';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {GLYPHS} from '../src/nullsignal/glyphs.js';

// These tests use real disposable SQLite + FastAPI, not simulated puzzle state.
// The isolated QA server has a fixed test identity and must be loopback-only.
const API=process.env.NULLSIGNAL_TEST_API;
test.use({launchOptions:{args:['--enable-unsafe-swiftshader']}});
test.skip(!API,'Set NULLSIGNAL_TEST_API to the isolated loopback QA backend.');
if(API&&!['127.0.0.1','localhost'].includes(new URL(API).hostname))throw new Error('Nullsignal QA must use a loopback-only backend.');
const AUTH={Authorization:'Bearer nullsignal-qa-host'};
const rooms=new Set(),contexts=[];

async function backend(request,path,{method='GET',data,headers=AUTH}={}){
  const response=await request.fetch(`${API}/api/nullsignal${path}`,{method,headers,...(data?{data}:{})});
  if(!response.ok())throw new Error(`${method} ${path}: ${response.status()} ${await response.text()}`);
  return response.json();
}
async function attach(page,host){
  if(host)await page.addInitScript(()=>{
    localStorage.setItem('aviary_token','nullsignal-qa-host');window.nullsignalAudioProof={sources:0,oscillators:0};
    const Ctx=window.AudioContext||window.webkitAudioContext,create=Ctx.prototype.createBufferSource,oscillator=Ctx.prototype.createOscillator;
    Ctx.prototype.createBufferSource=function(...args){const source=create.apply(this,args),start=source.start.bind(source);source.start=(...args)=>{if(source.buffer)window.nullsignalAudioProof.sources++;return start(...args);};return source;};
    Ctx.prototype.createOscillator=function(...args){window.nullsignalAudioProof.oscillators++;return oscillator.apply(this,args);};
  });
  await page.route('**/api/**',async route=>{
    const uri=new URL(route.request().url());
    if(uri.pathname.startsWith('/api/nullsignal/'))return route.fulfill({response:await route.fetch({url:API+uri.pathname+uri.search})});
    return route.fulfill({json:uri.pathname==='/api/auth/me'?{user:host?{username:'NullsignalQA',role:'member',chickens:0}:null}:uri.pathname==='/api/dashboard'?{stats:{},leaderboard:[],active_members:[],news:[],events:[]}:[]});
  });
}
async function createLobby(browser,request,{mission='blackout',mobile=false}={}){
  // Close only this isolated test identity's earlier disposable rooms.
  for(let i=0;i<4;i++){const prior=await backend(request,'/rooms/active');if(!prior)break;await backend(request,`/rooms/${prior.room_id}/control`,{method:'POST',data:{command:'close'}});}
  const viewport=mobile?{width:390,height:844}:{width:1536,height:1024};
  const hc=await browser.newContext({baseURL:'http://127.0.0.1:4186',viewport,...(mobile?{isMobile:true,hasTouch:true}:{})}),gc=await browser.newContext({baseURL:'http://127.0.0.1:4186',viewport,...(mobile?{isMobile:true,hasTouch:true}:{})});contexts.push(hc,gc);
  const host=await hc.newPage(),guest=await gc.newPage(),errors=[];
  host.on('pageerror',error=>errors.push(error.message));guest.on('pageerror',error=>errors.push(error.message));await attach(host,true);await attach(guest,false);
  await host.goto('/#games/nullsignal');await expect(host.getByRole('button',{name:'Lobby erstellen',exact:true})).toBeEnabled();
  const title={contact:'Erstkontakt',incident:'Störfall',blackout:'Blackout'}[mission];await host.getByRole('button',{name:new RegExp(`^${title}.*Module`)}).click();
  await host.getByRole('button',{name:'Lobby erstellen',exact:true}).click();await expect(host.getByLabel('Einladungslink')).toBeVisible();
  const invite=await host.getByLabel('Einladungslink').inputValue(),id=invite.split('/').at(-2);rooms.add(id);
  return {host,guest,hc,gc,invite,id,errors};
}
async function joinGuest(game,name='Alex'){
  await game.guest.goto(game.invite);await game.guest.getByLabel('Dein Name',{exact:true}).fill(name);await game.guest.getByRole('button',{name:'Als Experte beitreten',exact:true}).click();
  await expect(game.guest.getByRole('article',{name:'Entschärfungshandbuch'})).toBeVisible();
  return game.guest.evaluate(id=>sessionStorage.getItem(`nullsignal-guest:${id}`),game.id);
}
async function start(game){
  await game.guest.getByRole('button',{name:'Ich bin bereit',exact:true}).click();await expect(game.host.getByRole('button',{name:'Mission starten',exact:true})).toBeEnabled();await game.host.getByRole('button',{name:'Mission starten',exact:true}).click();await expect(game.host.locator('.nsGame')).toHaveAttribute('data-status','running');await expect(game.host.locator('.nsViewport')).toHaveAttribute('data-loaded','true',{timeout:20000});
}
async function uiAction(host,locator){
  await expect(host.locator('.nsGame')).toHaveAttribute('data-busy','false');
  await Promise.all([host.waitForResponse(response=>response.url().endsWith('/action')&&response.request().method()==='POST'),locator.click()]);
  await expect(host.locator('.nsGame')).toHaveAttribute('data-busy','false');
}
async function physical(host,module,operation,value,touch=false){
  await host.getByRole('navigation',{name:'Bombenmodule'}).getByRole('button',{name:new RegExp(module.name)}).click();
  const canvas=host.locator('.nsViewport canvas');await canvas.scrollIntoViewIfNeeded();await host.waitForTimeout(550);
  const target=await canvas.evaluate((c,args)=>c.__nullsignalScene.targets().find(target=>target.id===args.module&&target.operation===args.operation&&JSON.stringify(target.value)===JSON.stringify(args.value)&&target.inView),{module:module.id,operation,value});
  expect(target).toBeTruthy();
  await Promise.all([host.waitForResponse(response=>response.url().endsWith('/action')&&response.request().method()==='POST',{timeout:8000}),touch?canvas.tap({position:{x:target.x,y:target.y}}):canvas.click({position:{x:target.x,y:target.y}})]);
  await expect(host.locator('.nsGame')).toHaveAttribute('data-busy','false');
}
function solution(module,rules,facts){
  const data=module.data;
  switch(module.kind){
    case 'wires':{const colors=data.wires,p=rules.priority,s=rules.secondary;const index=colors.length>=5&&colors.filter(c=>c===p).length>=2?colors.lastIndexOf(p):Number(facts.serial.at(-1))%2&&colors.includes(s)?colors.indexOf(s):!colors.includes('red')?1:colors.length-1;return [['cut',index]];}
    case 'glyphs':{const column=rules.columns.find(column=>data.keys.every(key=>column.includes(key)));return column.filter(key=>data.keys.includes(key)).map(key=>['press',data.keys.indexOf(key)]);}
    case 'frequency':return [['tune',data.channels.indexOf(rules.channels.find(row=>row.pattern===data.pattern).frequency)],['submit',null]];
    case 'sequence':{const positions=[];data.displays.forEach((display,stage)=>{const rule=rules.stages[stage][display-1];positions.push(rule.rule==='position'?rule.value-1:rule.rule==='label'?data.keys.indexOf(rule.value):positions[rule.value-1]);});return positions.map(position=>['press',position]);}
    case 'relays':{const values=rules.rows.find(row=>row.pattern===data.pattern)[`v${facts.voltage}`];return values.flatMap((value,i)=>value!==data.switches[i]?[['toggle',i]]:[]).concat([['submit',null]]);}
    case 'sliders':{const values=rules.rows.find(row=>row.mark===data.mark).values;return values.map((value,i)=>['slide',[i,data.polarity==='+'?value:4-value]]).concat([['submit',null]]);}
    case 'pipes':{const route=rules[facts.coolant==='KALT'?'north':'south'].map(cell=>[cell.charCodeAt(0)-65,Number(cell[1])-1]),actions=[];
      route.forEach(([x,y],i)=>{const neighbours=[i?route[i-1]:[-1,y],i===route.length-1?[3,y]:route[i+1]],mask=neighbours.reduce((mask,[nx,ny])=>mask|({'-1,0':8,'1,0':2,'0,-1':1,'0,1':4}[`${nx-x},${ny-y}`]),0),index=y*3+x;
        for(let extra=0;extra<4;extra++){const n=(data.rotations[index]+extra)%4,base=data.tiles[index],rotated=((base<<n)|(base>>(4-n)))&15;if(rotated===mask){for(let step=0;step<extra;step++)actions.push(['rotate',index]);break;}}
      });return actions.concat([['submit',null]]);}
    case 'vectors':{const [a,b,c]=data.numbers,[w,x,y,z]=rules.weights,s=Number(facts.serial.at(-1));return [w*a+b,x*b+c,y*c+a,z*s+b].map(value=>['digit',value%10]).concat([['submit',null]]);}
    default:throw new Error(module.kind);
  }
}

test.afterEach(async({request})=>{for(const id of rooms)await backend(request,`/rooms/${id}/control`,{method:'POST',data:{command:'close'}}).catch(()=>{});rooms.clear();for(const context of contexts){for(const page of context.pages())await page.unrouteAll({behavior:'ignoreErrors'});await context.close();}contexts.length=0;});

test('two real browsers: private manual, genuine 3D cable cut, all eight modules, result, reward and rematch',async({browser,request})=>{
  test.setTimeout(180000);
  const game=await createLobby(browser,request),token=await joinGuest(game),{host,guest,id,errors}=game;
  const initial=await backend(request,`/rooms/${id}/host`),manual=await backend(request,`/rooms/${id}/expert`,{headers:{'X-Nullsignal-Token':token}});
  expect(manual.bomb).toBeUndefined();expect(initial.manual).toBeUndefined();expect(JSON.stringify(initial)).not.toContain('"answer"');expect(JSON.stringify(manual)).not.toContain(initial.bomb.serial);
  expect(await guest.locator('.nsViewport canvas').count()).toBe(0);expect(await guest.evaluate(()=>localStorage.getItem('aviary_token'))).toBeNull();
  await guest.getByRole('navigation',{name:'Handbuchinhalt'}).getByRole('button',{name:/Kabelmatrix/}).click();
  await expect(host.getByRole('button',{name:'Mission starten',exact:true})).toBeDisabled();
  await guest.getByRole('button',{name:'Ich bin bereit',exact:true}).click();await expect(host.getByRole('button',{name:'Mission starten',exact:true})).toBeEnabled();await host.screenshot({path:join(tmpdir(),'nullsignal-lobby-desktop.png')});
  await host.getByRole('button',{name:'Mission starten',exact:true}).click();await expect(host.locator('.nsViewport')).toHaveAttribute('data-loaded','true',{timeout:20000});await expect(host.locator('.nsGame')).toHaveAttribute('data-status','running');
  await host.waitForTimeout(500);await host.screenshot({path:join(tmpdir(),'nullsignal-host-desktop.png')});await guest.screenshot({path:join(tmpdir(),'nullsignal-manual-desktop.png')});
  const began=Date.now();
  for(const module of initial.bomb.modules){
    const rules=manual.manual.find(m=>m.id===module.id).manual,steps=solution(module,rules,initial.bomb);
    let physicalUsed=false;
    if(module.kind==='wires'){
      await host.getByRole('navigation',{name:'Bombenmodule'}).getByRole('button',{name:/Kabelmatrix/}).click();await host.waitForTimeout(550);
      const canvas=host.locator('.nsViewport canvas'),target=await canvas.evaluate((c,value)=>c.__nullsignalScene.targets().find(t=>t.id==='wires'&&t.operation==='cut'&&t.value===value),steps[0][1]);
      expect(target?.inView).toBe(true);await Promise.all([host.waitForResponse(r=>r.url().endsWith('/action'),{timeout:8000}),canvas.click({position:{x:target.x,y:target.y}})]);await expect(host.locator('.nsGame')).toHaveAttribute('data-busy','false');
    }else{
      await host.getByRole('navigation',{name:'Bombenmodule'}).getByRole('button',{name:new RegExp(module.name)}).click();
      for(const [operation,value] of steps){
        if(module.kind==='frequency'&&operation==='tune'){
          if(value>0){await physical(host,module,'step',1);physicalUsed=true;}
          for(let i=1;i<value;i++)await uiAction(host,host.getByRole('button',{name:'Frequenz erhöhen',exact:true}));
        }
        else if(!physicalUsed){await physical(host,module,operation,value);physicalUsed=true;}
        else if(module.kind==='glyphs')await uiAction(host,host.getByRole('button',{name:`Symbol ${GLYPHS[module.data.keys[value]].name} drücken`,exact:true}));
        else if(module.kind==='sequence')await uiAction(host,host.getByRole('button',{name:`Taste ${module.data.keys[value]}, Position ${value+1}`,exact:true}));
        else if(module.kind==='relays'&&operation==='toggle')await uiAction(host,host.locator('.nsRelayKeys button').nth(value));
        else if(module.kind==='sliders'&&operation==='slide')await uiAction(host,host.getByRole('button',{name:`Regler ${'ABC'[value[0]]} auf ${value[1]}`,exact:true}));
        else if(module.kind==='pipes'&&operation==='rotate')await uiAction(host,host.getByRole('button',{name:`Rohr ${'ABC'[value%3]}${Math.floor(value/3)+1} drehen`,exact:true}));
        else if(module.kind==='vectors'&&operation==='digit')await uiAction(host,host.getByRole('button',{name:`Ziffer ${value}`,exact:true}));
        else if(operation==='submit'){
          if(module.kind==='vectors'&&Date.now()-began<16000)await host.waitForTimeout(16000-(Date.now()-began));
          await uiAction(host,host.getByRole('button',{name:module.kind==='frequency'?'Senden':module.kind==='vectors'?'OK':'Prüfen',exact:true}));
        }
      }
    }
    await expect.poll(async()=>{const state=await backend(request,`/rooms/${id}/host`);return state.bomb.modules.find(m=>m.id===module.id).solved;}).toBe(true);
  }
  await expect(host.getByRole('region',{name:'Missionsergebnis'})).toBeVisible();await expect(host.locator('.nsGame')).toHaveAttribute('data-status','defused');
  const result=await backend(request,`/rooms/${id}/host`);expect(result.strikes).toBe(0);expect(result.solved).toBe(8);expect(result.chickens_awarded).toBe(18);
  expect(await host.evaluate(()=>window.nullsignalAudioProof.sources)).toBeGreaterThan(5);expect(await host.evaluate(()=>window.nullsignalAudioProof.oscillators)).toBe(0);
  await expect(guest.locator('.nsExpertStatus')).toContainText('Gemeinsam entschärft');await host.screenshot({path:join(tmpdir(),'nullsignal-result-desktop.png')});
  await host.getByRole('button',{name:'Neue Runde',exact:true}).click();await expect(host.locator('.nsGame')).toHaveAttribute('data-status','lobby');await expect(guest.getByRole('button',{name:'Ich bin bereit',exact:true})).toBeVisible();
  expect((await backend(request,`/rooms/${id}/host`)).round_id).not.toBe(result.round_id);expect(errors).toEqual([]);
});

test('lost join response reconnects without an account; occupied invite cannot replace guest; host reload recovers lobby',async({browser,request})=>{
  const game=await createLobby(browser,request,{mission:'contact'}),{host,guest,invite,id,errors}=game;
  let lost=false;
  await guest.route('**/api/nullsignal/rooms/*/join',async route=>{if(!lost){lost=true;const uri=new URL(route.request().url());await route.fetch({url:API+uri.pathname});return route.abort('failed');}return route.fallback();});
  await guest.goto(invite);await guest.getByLabel('Dein Name',{exact:true}).fill('Recoverable guest');await guest.getByRole('button',{name:'Als Experte beitreten',exact:true}).click();await expect(guest.getByRole('alert')).toBeVisible();
  await guest.reload();await expect(guest.getByRole('article',{name:'Entschärfungshandbuch'})).toBeVisible();
  await host.reload();await expect(host.getByLabel('Einladungslink')).toHaveValue(invite);
  const otherContext=await browser.newContext();contexts.push(otherContext);const other=await otherContext.newPage();await attach(other,false);await other.goto(invite);await other.getByLabel('Dein Name',{exact:true}).fill('Another guest');await other.getByRole('button',{name:'Als Experte beitreten',exact:true}).click();await expect(other.getByRole('alert')).toContainText('bereits belegt');
  await host.getByRole('button',{name:'Einladung erneuern / Gast entfernen',exact:true}).click();await expect(host.getByLabel('Einladungslink')).not.toHaveValue(invite);await expect(guest.getByRole('alert')).toContainText('keinen Zugang');await expect(guest.getByRole('article',{name:'Entschärfungshandbuch'})).toHaveCount(0);
  expect((await backend(request,`/rooms/${id}/host`)).expert_name).toBe('');expect(errors).toEqual([]);
});

test('connection loss pauses real server clock and reconnect can resume the same round',async({browser,request})=>{
  test.setTimeout(65000);const game=await createLobby(browser,request,{mission:'contact'});await joinGuest(game);await start(game);
  await game.guest.route('**/api/nullsignal/rooms/*/expert',route=>route.abort('failed'));
  await expect(game.host.getByRole('heading',{name:'Mission pausiert.',exact:true})).toBeVisible({timeout:22000});
  const paused=await backend(request,`/rooms/${game.id}/host`);await game.host.waitForTimeout(1400);expect((await backend(request,`/rooms/${game.id}/host`)).remaining).toBe(paused.remaining);
  await game.guest.unroute('**/api/nullsignal/rooms/*/expert');await expect(game.host.getByRole('button',{name:'Fortsetzen',exact:true})).toBeEnabled();await game.host.getByRole('button',{name:'Fortsetzen',exact:true}).click();await expect(game.host.locator('.nsGame')).toHaveAttribute('data-status','running');expect((await backend(request,`/rooms/${game.id}/host`)).round_id).toBe(paused.round_id);expect(game.errors).toEqual([]);
});

test('mobile: full 3D host, eight readable manual chapters, touch controls and no overflow',async({browser,request})=>{
  const game=await createLobby(browser,request,{mobile:true}),token=await joinGuest(game,'Mobile expert');await start(game);
  const {host,guest,id}=game;await expect(guest.getByLabel('Handbuchkapitel')).toBeVisible();await guest.getByLabel('Handbuchkapitel').selectOption('vectors');await expect(guest.getByRole('article',{name:'Entschärfungshandbuch'})).toContainText('Berechne einen vierstelligen Code');
  expect(await host.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);expect(await guest.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);expect(await host.locator('.nsGame').evaluate(element=>element.getBoundingClientRect().width)).toBe(390);
  expect(await host.locator('.nsPlay').evaluate(element=>element.scrollTop)).toBe(0);
  await host.screenshot({path:join(tmpdir(),'nullsignal-host-mobile.png')});await guest.screenshot({path:join(tmpdir(),'nullsignal-manual-mobile.png')});
  const state=await backend(request,`/rooms/${id}/host`),manual=await backend(request,`/rooms/${id}/expert`,{headers:{'X-Nullsignal-Token':token}}),steps=solution(state.bomb.modules[0],manual.manual[0].manual,state.bomb);
  await host.getByRole('navigation',{name:'Bombenmodule'}).getByRole('button',{name:/Kabelmatrix/}).tap();const canvas=host.locator('.nsViewport canvas');await canvas.scrollIntoViewIfNeeded();await host.waitForTimeout(600);
  const target=await canvas.evaluate((c,value)=>c.__nullsignalScene.targets().find(t=>t.id==='wires'&&t.operation==='cut'&&t.value===value&&t.inView),steps[0][1]);expect(target).toBeTruthy();await Promise.all([host.waitForResponse(r=>r.url().endsWith('/action')),canvas.tap({position:{x:target.x,y:target.y}})]);
  await expect.poll(async()=>(await backend(request,`/rooms/${id}/host`)).solved).toBe(1);expect(game.errors).toEqual([]);
});

test('guest welcome never loads Three.js; invalid invitation and denied 3D texture have usable recovery',async({browser,request})=>{
  const game=await createLobby(browser,request,{mission:'contact'});await game.host.route('**/assets/nullsignal/steel.png',route=>route.abort());await game.host.reload();await expect(game.host.getByRole('button',{name:'3D erneut laden',exact:true})).toBeVisible();await game.host.unroute('**/assets/nullsignal/steel.png');await game.host.getByRole('button',{name:'3D erneut laden',exact:true}).click();await expect(game.host.locator('.nsViewport')).toHaveAttribute('data-loaded','true',{timeout:20000});
  const assets=[];game.guest.on('request',request=>{if(request.url().includes('/assets/'))assets.push(request.url());});await game.guest.goto('/#nullsignal/join/broken/link');await expect(game.guest.getByRole('alert')).toContainText('unvollständig');await expect(game.guest.getByRole('button',{name:'Als Experte beitreten',exact:true})).toBeDisabled();expect(assets.some(url=>/DeviceScene|OutputPass|workshop\.png|steel\.png/.test(url))).toBe(false);
  await game.host.getByRole('link',{name:'Zurück zu den Minispielen',exact:true}).click();await expect(game.host.getByRole('button',{name:'Loslaufen',exact:true})).toBeVisible();expect(await game.host.locator('.communityApp').evaluate(app=>app.inert)).toBe(false);expect(game.errors).toEqual([]);
});
