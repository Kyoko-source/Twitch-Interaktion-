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

test('countdown audio accelerates with time and mistakes; real MP3s switch, pause, mute and stop at explosion',async({browser,request})=>{
  test.setTimeout(90000);
  const game=await createLobby(browser,request,{mission:'contact'}),{host,id,errors}=game;
  // An existing project MP3 is a disposable playback fixture, never a shipped song.
  await host.route('**/music/nullsignal/*.mp3',route=>route.fulfill({path:join(process.cwd(),'../assets/chicken_theme.mp3'),contentType:'audio/mpeg'}));
  await host.addInitScript(()=>{
    window.countdownProbe={beeps:[],sources:[],music:[]};
    const Context=window.AudioContext||window.webkitAudioContext,create=Context.prototype.createBufferSource,play=HTMLMediaElement.prototype.play;
    Context.prototype.createBufferSource=function(...args){const source=create.apply(this,args),start=source.start.bind(source);source.start=(...args)=>{const duration=source.buffer?.duration||0;window.countdownProbe.sources.push(duration);if(Math.abs(duration-.06)<.0001)window.countdownProbe.beeps.push(performance.now());return start(...args);};return source;};
    HTMLMediaElement.prototype.play=function(...args){if(this.src.includes('/music/nullsignal/')&&!window.countdownProbe.music.includes(this))window.countdownProbe.music.push(this);return play.apply(this,args);};
  });
  await host.reload();await expect(host.getByLabel('Einladungslink')).toBeVisible();await host.getByRole('button',{name:'Ton einschalten',exact:true}).click();
  const playing=()=>host.evaluate(()=>window.countdownProbe.music.filter(track=>!track.paused&&!track.ended).map(track=>({src:track.src,time:track.currentTime,loop:track.loop,volume:track.volume})));
  await expect.poll(async()=>(await playing())[0]?.src).toContain('menu.mp3');await expect.poll(async()=>(await playing())[0]?.time||0).toBeGreaterThan(.05);expect((await playing())[0].loop).toBe(true);
  await host.getByLabel('Audio-Einstellungen',{exact:true}).click();const musicRange=host.getByLabel('Musiklautstärke',{exact:true});await musicRange.press('Home');for(let i=0;i<8;i++)await musicRange.press('ArrowRight');await expect.poll(async()=>(await playing())[0]?.volume).toBe(.4);await host.screenshot({path:join(tmpdir(),'nullsignal-audio-desktop.png')});await host.getByLabel('Audio-Einstellungen',{exact:true}).click();
  await joinGuest(game,'Audio expert');await start(game);await expect.poll(async()=>(await playing())[0]?.src).toContain('ingame.mp3');expect((await playing()).length).toBe(1);
  const base=await backend(request,`/rooms/${id}/host`);let version=base.version+100,fixture={...base};
  await host.route('**/api/nullsignal/rooms/*/host',route=>route.fulfill({json:{...fixture,version:version++,server_time:Date.now()/1000,...(fixture.status==='running'?{deadline:Date.now()/1000+fixture.remaining}:{deadline:null})}}));
  async function tempo(remaining,strikes,wait){
    fixture={...base,status:'running',remaining,strikes,event:null};
    await expect(host.getByLabel('Verbleibende Zeit')).toHaveText(`${String(Math.floor(remaining/60)).padStart(2,'0')}:${String(remaining%60).padStart(2,'0')}`);
    const begin=await host.evaluate(()=>window.countdownProbe.beeps.length);await host.waitForTimeout(wait);
    const beats=await host.evaluate(begin=>window.countdownProbe.beeps.slice(begin),begin),gaps=beats.slice(1).map((beat,i)=>beat-beats[i]).sort((a,b)=>a-b);expect(gaps.length).toBeGreaterThan(0);return gaps[Math.floor(gaps.length/2)];
  }
  const normal=await tempo(300,0,2400),minute=await tempo(60,0,1800),halfMinute=await tempo(30,0,1400),critical=await tempo(5,0,1000),firstMistake=await tempo(300,1,2100),secondMistake=await tempo(300,2,1700);
  expect(normal).toBeGreaterThan(850);expect(minute).toBeLessThan(normal*.75);expect(halfMinute).toBeLessThan(minute*.85);expect(critical).toBeLessThan(halfMinute*.65);expect(firstMistake).toBeLessThan(normal*.85);expect(secondMistake).toBeLessThan(firstMistake*.85);
  fixture={...fixture,status:'paused',remaining:200};await expect(host.locator('.nsGame')).toHaveAttribute('data-status','paused');expect(await playing()).toEqual([]);let count=await host.evaluate(()=>window.countdownProbe.beeps.length);await host.waitForTimeout(350);expect(await host.evaluate(()=>window.countdownProbe.beeps.length)).toBe(count);
  fixture={...fixture,status:'running',remaining:5,strikes:0};await expect.poll(async()=>(await playing())[0]?.src).toContain('ingame.mp3');await host.getByRole('button',{name:'Spiel stummschalten',exact:true}).click();await expect(host.getByRole('button',{name:'Spielton einschalten',exact:true})).toBeVisible();expect(await playing()).toEqual([]);count=await host.evaluate(()=>window.countdownProbe.beeps.length);await host.waitForTimeout(350);expect(await host.evaluate(()=>window.countdownProbe.beeps.length)).toBe(count);
  await host.getByRole('button',{name:'Spielton einschalten',exact:true}).click();await expect.poll(async()=>(await playing()).length).toBe(1);
  const effects=await host.evaluate(()=>window.countdownProbe.sources.filter(duration=>Math.abs(duration-.06)>.0001).length);
  fixture={...fixture,status:'exploded',remaining:0,strikes:3,event:{id:'audio-explosion-proof',kind:'exploded',message:'Die Zeit ist abgelaufen.'},result:{remaining:0,score:0}};
  await expect(host.getByRole('region',{name:'Missionsergebnis'})).toBeVisible();expect(await playing()).toEqual([]);await expect.poll(()=>host.evaluate(()=>window.countdownProbe.sources.filter(duration=>Math.abs(duration-.06)>.0001).length)).toBeGreaterThan(effects);count=await host.evaluate(()=>window.countdownProbe.beeps.length);await host.waitForTimeout(350);expect(await host.evaluate(()=>window.countdownProbe.beeps.length)).toBe(count);
  console.log('Measured countdown intervals (ms)',{normal,minute,halfMinute,critical,firstMistake,secondMistake});expect(errors).toEqual([]);
});

test('mobile audio settings remain usable and absent optional songs leave countdown effects working',async({browser,request})=>{
  const game=await createLobby(browser,request,{mobile:true,mission:'contact'}),{host,errors}=game;
  await host.route('**/music/nullsignal/*.mp3',route=>route.fulfill({status:204}));await host.reload();await expect(host.getByLabel('Einladungslink')).toBeVisible();await host.getByLabel('Audio-Einstellungen',{exact:true}).click();
  await expect(host.getByLabel('Musiklautstärke',{exact:true})).toBeVisible();await host.getByLabel('Musik einschalten',{exact:true}).uncheck();await expect(host.getByLabel('Musik einschalten',{exact:true})).not.toBeChecked();await host.getByLabel('Musik einschalten',{exact:true}).check();await host.getByLabel('Spiellautstärke',{exact:true}).press('ArrowLeft');
  const rect=await host.locator('.nsAudioSettings>div').boundingBox();expect(rect.x).toBeGreaterThanOrEqual(0);expect(rect.x+rect.width).toBeLessThanOrEqual(390);await host.screenshot({path:join(tmpdir(),'nullsignal-audio-mobile.png')});await host.getByLabel('Audio-Einstellungen',{exact:true}).click();
  await joinGuest(game,'Silent music');await start(game);await expect.poll(()=>host.evaluate(()=>window.nullsignalAudioProof.sources)).toBeGreaterThan(0);expect(errors).toEqual([]);
});

test('guest welcome never loads Three.js; invalid invitation and denied 3D texture have usable recovery',async({browser,request})=>{
  const game=await createLobby(browser,request,{mission:'contact'});await game.host.route('**/assets/nullsignal/steel.png',route=>route.abort());await game.host.reload();await expect(game.host.getByRole('button',{name:'3D erneut laden',exact:true})).toBeVisible();await game.host.unroute('**/assets/nullsignal/steel.png');await game.host.getByRole('button',{name:'3D erneut laden',exact:true}).click();await expect(game.host.locator('.nsViewport')).toHaveAttribute('data-loaded','true',{timeout:20000});
  const assets=[];game.guest.on('request',request=>{if(request.url().includes('/assets/'))assets.push(request.url());});await game.guest.goto('/#nullsignal/join/broken/link');await expect(game.guest.getByRole('alert')).toContainText('unvollständig');await expect(game.guest.getByRole('button',{name:'Als Experte beitreten',exact:true})).toBeDisabled();expect(assets.some(url=>/DeviceScene|OutputPass|workshop\.png|steel\.png/.test(url))).toBe(false);
  await game.host.getByRole('link',{name:'Zurück zu den Minispielen',exact:true}).click();await expect(game.host.getByRole('button',{name:'Loslaufen',exact:true})).toBeVisible();expect(await game.host.locator('.communityApp').evaluate(app=>app.inert)).toBe(false);expect(game.errors).toEqual([]);
});

test('pressure builds as time runs out; C consumes a real persistent pill, clears blur and survives pause/reload',async({browser,request})=>{
  test.setTimeout(60000);
  const game=await createLobby(browser,request),{host,guest,id,errors}=game;await joinGuest(game,'Calm expert');await start(game);
  let visualRemaining=300;
  // Compress only the visible countdown; pill consumption, duration and inventory
  // still use the real isolated backend and its actual active-play clock.
  await host.route('**/api/nullsignal/rooms/*/host',async route=>{const response=await route.fetch({url:API+new URL(route.request().url()).pathname}),state=await response.json();if(state.status==='running'){state.remaining=visualRemaining;state.deadline=state.server_time+visualRemaining;}return route.fulfill({json:state});});
  const blur=()=>host.locator('.nsViewport canvas').evaluate(canvas=>Number.parseFloat(getComputedStyle(canvas).filter.match(/blur\(([^p]+)/)?.[1]||'0'));
  await expect(host.getByLabel('Verbleibende Zeit')).toHaveText('05:00');const initial=Number(await host.locator('.nsPressureEdges').getAttribute('data-intensity'));expect(await blur()).toBe(0);
  visualRemaining=60;await expect(host.getByLabel('Verbleibende Zeit')).toHaveText('01:00');await expect.poll(blur).toBeGreaterThan(.8);
  const minute=Number(await host.locator('.nsPressureEdges').getAttribute('data-intensity'));expect(minute).toBeGreaterThan(initial);
  visualRemaining=10;await expect(host.getByLabel('Verbleibende Zeit')).toHaveText('00:10');await expect.poll(blur).toBeGreaterThan(2);const critical=Number(await host.locator('.nsPressureEdges').getAttribute('data-intensity'));expect(critical).toBeGreaterThan(minute);
  expect(await host.locator('.nsPressureEdges').evaluate(element=>getComputedStyle(element).pointerEvents)).toBe('none');expect(await guest.locator('.nsPressureEdges').count()).toBe(0);await host.screenshot({path:join(tmpdir(),'nullsignal-pressure-desktop.png')});
  await host.getByLabel('Audio-Einstellungen',{exact:true}).click();await host.getByLabel('Musiklautstärke',{exact:true}).press('c');expect((await backend(request,`/rooms/${id}/host`)).calm.pills_remaining).toBe(2);await host.getByLabel('Audio-Einstellungen',{exact:true}).click();await host.locator('.nsBrand h1').focus();
  await Promise.all([host.waitForResponse(response=>response.url().endsWith('/calm')),host.keyboard.press('c')]);await expect(host.getByRole('button',{name:'Beruhigungspille nehmen',exact:true})).toContainText('1/2');await expect.poll(blur).toBe(0);await expect(host.locator('#ns-calm-status')).toContainText('Klare Sicht');await expect.poll(async()=>Number(await host.locator('.nsPressureEdges').getAttribute('data-intensity'))).toBeGreaterThan(.9);await host.screenshot({path:join(tmpdir(),'nullsignal-calm-desktop.png')});
  await host.keyboard.press('c');expect((await backend(request,`/rooms/${id}/host`)).calm.pills_remaining).toBe(1);
  await host.getByRole('button',{name:'Mission pausieren',exact:true}).click();await expect(host.getByRole('heading',{name:'Mission pausiert.',exact:true})).toBeVisible();await expect(host.locator('.nsPressureEdges')).toHaveAttribute('data-intensity','0.000');const paused=(await backend(request,`/rooms/${id}/host`)).calm.seconds_remaining;await host.waitForTimeout(1100);expect((await backend(request,`/rooms/${id}/host`)).calm.seconds_remaining).toBe(paused);
  await host.getByRole('button',{name:'Fortsetzen',exact:true}).click();await host.reload();await expect(host.getByRole('button',{name:'Beruhigungspille nehmen',exact:true})).toContainText('1/2');await expect.poll(blur).toBe(0);
  await host.getByRole('button',{name:'Mission pausieren',exact:true}).click();await host.getByRole('button',{name:'Neue Runde vorbereiten',exact:true}).click();await expect(host.locator('.nsGame')).toHaveAttribute('data-status','lobby');expect((await backend(request,`/rooms/${id}/host`)).calm.pills_remaining).toBe(2);expect(errors).toEqual([]);
});

test('mobile pill button restores focus, pressure never blocks touch, and reduced motion disables pulsing',async({browser,request})=>{
  const game=await createLobby(browser,request,{mobile:true}),{host,id,errors}=game;await host.emulateMedia({reducedMotion:'reduce'});await joinGuest(game,'Touch expert');await start(game);
  await host.route('**/api/nullsignal/rooms/*/host',async route=>{const response=await route.fetch({url:API+new URL(route.request().url()).pathname}),state=await response.json();if(state.status==='running'){state.remaining=10;state.deadline=state.server_time+10;}return route.fulfill({json:state});});
  await expect(host.getByLabel('Verbleibende Zeit')).toHaveText('00:10');expect(await host.locator('.nsPressureEdges').evaluate(element=>getComputedStyle(element).animationName)).toBe('none');const button=host.getByRole('button',{name:'Beruhigungspille nehmen',exact:true});await expect(button).toBeVisible();await host.screenshot({path:join(tmpdir(),'nullsignal-pressure-mobile.png')});await button.tap();await expect(button).toContainText('1/2');await expect(host.locator('#ns-calm-status')).toContainText('Klare Sicht');expect((await backend(request,`/rooms/${id}/host`)).calm.pills_remaining).toBe(1);expect(await host.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await expect.poll(async()=>Number(await host.locator('.nsPressureEdges').getAttribute('data-intensity'))).toBeGreaterThan(.9);await host.screenshot({path:join(tmpdir(),'nullsignal-calm-mobile.png')});expect(errors).toEqual([]);
});

test('drag rotates only the case in lobby and mission; table and camera stay fixed and rear modules still focus',async({browser,request})=>{
  const game=await createLobby(browser,request),{host,id,errors}=game,canvas=host.locator('.nsViewport canvas');
  await expect(host.locator('.nsViewport')).toHaveAttribute('data-loaded','true',{timeout:20000});
  const transforms=()=>canvas.evaluate(canvas=>canvas.__nullsignalScene.transforms());
  async function drag(){const rect=await canvas.boundingBox();await host.mouse.move(rect.x+rect.width*.45,rect.y+rect.height*.5);await host.mouse.down();await host.mouse.move(rect.x+rect.width*.45+160,rect.y+rect.height*.5+45,{steps:14});await host.mouse.up();await host.waitForTimeout(150);}
  const beforeLobby=await transforms();await drag();const afterLobby=await transforms();expect(afterLobby.deviceRotation).not.toEqual(beforeLobby.deviceRotation);expect(afterLobby.tableCorners).toEqual(beforeLobby.tableCorners);expect(afterLobby.cameraRotation).toEqual(beforeLobby.cameraRotation);expect(afterLobby.camera).toEqual(beforeLobby.camera);await host.screenshot({path:join(tmpdir(),'nullsignal-fixed-table-menu.png')});
  await joinGuest(game,'Steady table');await start(game);const beforeGame=await transforms();await drag();const afterGame=await transforms();expect(afterGame.deviceRotation).not.toEqual(beforeGame.deviceRotation);expect(afterGame.tableCorners).toEqual(beforeGame.tableCorners);expect(afterGame.cameraRotation).toEqual(beforeGame.cameraRotation);expect((await backend(request,`/rooms/${id}/host`)).strikes).toBe(0);await host.screenshot({path:join(tmpdir(),'nullsignal-fixed-table-game.png')});
  await host.getByRole('button',{name:'Rückseite',exact:true}).click();await host.waitForTimeout(550);const back=await transforms();expect(back.deviceRotation).not.toEqual(afterGame.deviceRotation);expect(back.cameraRotation.map(value=>Number(value.toFixed(8)))).toEqual(beforeGame.cameraRotation.map(value=>Number(value.toFixed(8))));
  await host.getByRole('navigation',{name:'Bombenmodule'}).getByRole('button',{name:/Kreislauf/}).click();await host.waitForTimeout(550);expect((await canvas.evaluate(canvas=>canvas.__nullsignalScene.targets())).some(target=>target.id==='pipes'&&target.inView)).toBe(true);const focused=await transforms();expect(focused.cameraRotation.map(value=>Number(value.toFixed(8)))).toEqual(beforeGame.cameraRotation.map(value=>Number(value.toFixed(8))));await host.screenshot({path:join(tmpdir(),'nullsignal-fixed-table-back-focus.png')});expect(errors).toEqual([]);
});

test('touch drag turns only the bomb and two-finger zoom does not tilt the workbench',async({browser,request})=>{
  const game=await createLobby(browser,request,{mobile:true}),{host,hc,errors}=game;await joinGuest(game,'Touch rotation');await start(game);const canvas=host.locator('.nsViewport canvas'),rect=await canvas.boundingBox(),session=await hc.newCDPSession(host);
  const state=()=>canvas.evaluate(canvas=>canvas.__nullsignalScene.transforms()),before=await state(),x=rect.x+rect.width*.4,y=rect.y+rect.height*.5;
  await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y,id:1}]});for(let step=1;step<=12;step++)await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x+step*8,y:y+step*2,id:1}]});await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await host.waitForTimeout(150);
  const rotated=await state();expect(rotated.deviceRotation).not.toEqual(before.deviceRotation);expect(rotated.tableCorners).toEqual(before.tableCorners);expect(rotated.cameraRotation).toEqual(before.cameraRotation);
  const cx=rect.x+rect.width*.5;await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:cx-30,y,id:2},{x:cx+30,y,id:3}]});for(let step=1;step<=8;step++)await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:cx-30-step*5,y,id:2},{x:cx+30+step*5,y,id:3}]});await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await host.waitForTimeout(150);
  const zoomed=await state();expect(zoomed.camera).not.toEqual(rotated.camera);expect(zoomed.deviceRotation).toEqual(rotated.deviceRotation);expect(zoomed.cameraRotation.map(value=>Number(value.toFixed(8)))).toEqual(before.cameraRotation.map(value=>Number(value.toFixed(8))));await host.screenshot({path:join(tmpdir(),'nullsignal-fixed-table-mobile.png')});await session.detach();expect(errors).toEqual([]);
});

test('power failure lights actual 3D surfaces; hallucination and single scare yield to real pills and pause',async({browser,request})=>{
  test.setTimeout(90000);
  const game=await createLobby(browser,request,{mission:'contact'}),{host,guest,id,errors}=game;
  host.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  await host.addInitScript(()=>{
    window.fearSamples=[];const C=window.AudioContext||window.webkitAudioContext,create=C.prototype.createBufferSource;
    C.prototype.createBufferSource=function(...args){const source=create.apply(this,args),start=source.start.bind(source);source.start=(...args)=>{window.fearSamples.push({rate:source.playbackRate.value,duration:source.buffer?.duration});return start(...args);};return source;};
  });
  await host.reload();await expect(host.getByLabel('Einladungslink')).toBeVisible();
  const token=await joinGuest(game,'Power expert');await start(game);const canvas=host.locator('.nsViewport canvas'),layer=host.locator('.nsAtmosphere');
  let phase='normal';
  await host.route('**/api/nullsignal/rooms/*/host',async route=>{
    const response=await route.fetch({url:API+new URL(route.request().url()).pathname}),state=await response.json();
    if(state.status==='running'){
      state.remaining=phase==='normal'?170:phase==='outage'?100:45;state.deadline=state.server_time+state.remaining;
      state.atmosphere={...state.atmosphere,played:phase==='outage'?43:phase==='normal'?10:74,untreated:100,outage_start:40,scare_id:phase==='scare'?state.round_id:null,scare_remaining:phase==='scare'?1.2:0};
    }
    return route.fulfill({json:state});
  });
  phase='outage';await expect(layer).toHaveAttribute('data-blackout','true');await expect(host.locator('.nsViewport')).toHaveAttribute('data-blackout','true');
  const lighting=()=>canvas.evaluate(c=>c.__nullsignalScene.lighting());
  expect((await lighting()).flashlight).toBe(65);expect((await lighting()).background).toBeLessThan(.05);
  const before=(await lighting()).aim,rect=await canvas.boundingBox();await host.mouse.move(rect.x+rect.width*.7,rect.y+rect.height*.65);await expect.poll(async()=>JSON.stringify((await lighting()).aim)).not.toBe(JSON.stringify(before));
  await host.screenshot({path:join(tmpdir(),'nullsignal-outage-desktop.png')});
  await host.keyboard.press('f');await expect(host.getByRole('button',{name:'Taschenlampe',exact:true})).toHaveAttribute('aria-pressed','false');await expect.poll(async()=>(await lighting()).flashlight).toBe(0);
  await host.getByRole('button',{name:'Taschenlampe',exact:true}).click();await expect.poll(async()=>(await lighting()).flashlight).toBe(65);
  // A genuine raycast press still reaches the server during the outage.
  const base=await backend(request,`/rooms/${id}/host`),manual=await backend(request,`/rooms/${id}/expert`,{headers:{'X-Nullsignal-Token':token}}),glyph=base.bomb.modules.find(m=>m.kind==='glyphs'),step=solution(glyph,manual.manual.find(m=>m.id===glyph.id).manual,base.bomb)[0];
  await physical(host,glyph,...step);expect((await backend(request,`/rooms/${id}/host`)).strikes).toBe(0);
  phase='hallucination';await expect(layer).toHaveAttribute('data-blackout','false');await expect.poll(async()=>Number(await layer.getAttribute('data-hallucination'))).toBeGreaterThan(.9);await expect(host.locator('.nsPhantom')).toBeVisible();await host.waitForTimeout(700);await host.screenshot({path:join(tmpdir(),'nullsignal-hallucination-desktop.png')});
  phase='scare';await expect(layer).toHaveAttribute('data-scare','true');await expect(host.locator('.nsJumpscare')).toBeVisible();await expect.poll(()=>host.locator('.nsJumpscare img').evaluate(image=>image.complete&&image.naturalWidth>0)).toBe(true);await host.screenshot({path:join(tmpdir(),'nullsignal-jumpscare-desktop.png')});
  await expect.poll(()=>host.evaluate(()=>window.fearSamples.filter(s=>Math.abs(s.rate-.65)<.01).length)).toBe(1);await host.waitForTimeout(1700);expect(await host.evaluate(()=>window.fearSamples.filter(s=>Math.abs(s.rate-.65)<.01).length)).toBe(1);
  await host.getByRole('button',{name:'Beruhigungspille nehmen',exact:true}).click();await expect(layer).toHaveAttribute('data-scare','false');await expect(layer).toHaveAttribute('data-hallucination','0.000');expect((await backend(request,`/rooms/${id}/host`)).calm.pills_remaining).toBe(1);
  expect(await guest.locator('.nsAtmosphere').count()).toBe(0);expect(await host.locator('.nsAtmosphere').evaluate(e=>getComputedStyle(e).pointerEvents)).toBe('none');
  await host.getByRole('button',{name:'Mission pausieren',exact:true}).click();await expect(layer).toHaveAttribute('data-blackout','false');await expect(layer).toHaveAttribute('data-scare','false');expect((await lighting()).flashlight).toBe(0);
  expect(errors).toEqual([]);
});

test('mobile outage toggle works; reduced motion avoids scare zoom and horror preference persists',async({browser,request})=>{
  const game=await createLobby(browser,request,{mobile:true,mission:'contact'}),{host,errors}=game;await joinGuest(game,'Torch expert');await start(game);
  host.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  let scare=false;
  await host.route('**/api/nullsignal/rooms/*/host',async route=>{
    const response=await route.fetch({url:API+new URL(route.request().url()).pathname}),state=await response.json();
    if(state.status==='running'){state.remaining=45;state.deadline=state.server_time+45;state.atmosphere={...state.atmosphere,played:43,untreated:100,outage_start:40,scare_id:scare?state.round_id:null,scare_remaining:scare?1.2:0};}
    return route.fulfill({json:state});
  });
  await expect(host.locator('.nsAtmosphere')).toHaveAttribute('data-blackout','true');const torch=host.getByRole('button',{name:'Taschenlampe',exact:true});await torch.tap();await expect(torch).toHaveAttribute('aria-pressed','false');await torch.tap();await expect(torch).toHaveAttribute('aria-pressed','true');
  const canvas=host.locator('.nsViewport canvas'),rect=await canvas.boundingBox(),session=await game.hc.newCDPSession(host),before=await canvas.evaluate(c=>({rotation:c.__nullsignalScene.transforms().deviceRotation,aim:c.__nullsignalScene.lighting().aim}));
  await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:rect.x+rect.width*.45,y:rect.y+rect.height*.65,id:1}]});
  for(let step=1;step<=10;step++){await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:rect.x+rect.width*(.45+.25*step/10),y:rect.y+rect.height*(.65+.15*step/10),id:1}]});await host.waitForTimeout(20);}
  await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await host.waitForTimeout(100);
  expect(await canvas.evaluate(c=>c.__nullsignalScene.transforms().deviceRotation)).toEqual(before.rotation);expect(await canvas.evaluate(c=>c.__nullsignalScene.lighting().aim)).not.toEqual(before.aim);
  await host.screenshot({path:join(tmpdir(),'nullsignal-outage-mobile.png')});scare=true;await expect(host.locator('.nsJumpscare img')).toBeVisible();await expect.poll(()=>host.locator('.nsJumpscare img').evaluate(image=>image.complete&&image.naturalWidth===1024)).toBe(true);await host.screenshot({path:join(tmpdir(),'nullsignal-jumpscare-mobile.png')});await host.emulateMedia({reducedMotion:'reduce'});expect(await host.locator('.nsJumpscare img').evaluate(e=>getComputedStyle(e).display)).toBe('none');expect(await host.locator('.nsJumpscare').evaluate(e=>getComputedStyle(e).animationName)).toBe('none');
  await host.getByLabel('Audio-Einstellungen',{exact:true}).tap();
  await expect(host.locator('.nsAudioSettings')).toHaveAttribute('open','');await host.getByLabel('Schreckeffekte einschalten',{exact:true}).uncheck();await expect(host.locator('.nsAtmosphere')).toHaveAttribute('data-scare','false');await expect(host.locator('.nsAtmosphere')).toHaveAttribute('data-hallucination','0.000');
  await host.reload();await expect(host.locator('.nsGame')).toHaveAttribute('data-status','running');await host.getByLabel('Audio-Einstellungen',{exact:true}).tap();await expect(host.getByLabel('Schreckeffekte einschalten',{exact:true})).not.toBeChecked();expect(await host.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);expect(errors).toEqual([]);await session.detach();
});
