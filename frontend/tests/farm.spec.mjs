import {test,expect,chromium} from '@playwright/test';
import {join} from 'node:path';
import {tmpdir} from 'node:os';

function wavSample(){const wav=Buffer.alloc(44+16000),text=(offset,value)=>wav.write(value,offset,'ascii');text(0,'RIFF');wav.writeUInt32LE(wav.length-8,4);text(8,'WAVE');text(12,'fmt ');wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(16000,24);wav.writeUInt32LE(32000,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);text(36,'data');wav.writeUInt32LE(16000,40);for(let i=0;i<8000;i++)wav.writeInt16LE(Math.round(Math.sin(i/16000*Math.PI*2*330)*10000),44+i*2);return wav;}

async function setup(page,{count=1,coins=0,guest=false,voicesReady=false}={}){
  const catalog=[['sheep','Schaf','Schafe',1,8,40],['chicken','Huhn','Hühner',2,9,110],['duck','Ente','Enten',4,10,280],['pig','Schwein','Schweine',8,11,700],['cow','Kuh','Kühe',16,12,1800],['alpaca','Alpaka','Alpakas',32,13,4500]].map(([id,name,plural,income,interval,price],art)=>({id,name,plural,income,interval,price,art,owned:art===0?count:0}));
  const state={coins,earned:coins,running:false,capacity:100,catalog,voices:[],animals:Array.from({length:count},(_,i)=>({id:(i+1).toString(16).padStart(32,'0'),species:catalog[i%6].id,name:`${catalog[i%6].name} ${i+1}`,voice_id:null}))};
  const uploads=[],buys=[],updates=[];let started=0,called=false;const blobs=new Map();
  if(voicesReady){state.voices=[{id:'voice-1',name:'Alle meine Tiere',duration:.5}];state.animals.forEach(animal=>animal.voice_id='voice-1');blobs.set('voice-1',wavSample());}
  await page.route('**/api/**',async route=>{
    const req=route.request(),url=new URL(req.url()),path=url.pathname;let json=[];
    if(path.endsWith('/auth/me'))json={user:guest?null:{username:'Kyoko',role:'member',chickens:100,chickens_earned:100}};
    else if(path==='/api/farm')json=state;
    else if(path.endsWith('/farm/start')){state.running=true;started=Date.now();called=false;json=state;}
    else if(path.endsWith('/farm/pause')){state.running=false;json=state;}
    else if(path.endsWith('/farm/tick')){let events=[];if(state.running&&!called&&Date.now()-started>=(voicesReady?1000:8000)){called=true;events=(voicesReady?state.animals:[state.animals[0]]).map((animal,index)=>({id:`call-${index}`,animal_id:animal.id,voice_id:animal.voice_id,amount:state.catalog.find(item=>item.id===animal.species).income}));state.coins+=events.reduce((sum,event)=>sum+event.amount,0);}json={...state,events};}
    else if(path.endsWith('/farm/voices')&&req.method()==='POST'){
      uploads.push({params:Object.fromEntries(url.searchParams),bytes:req.postDataBuffer()});const id=`voice-${uploads.length}`;blobs.set(id,req.postDataBuffer());state.voices.push({id,name:url.searchParams.get('name'),duration:1});state.animals.find(a=>a.id===url.searchParams.get('animal_id')).voice_id=id;json={...state,saved_voice_id:id};
    }else if(path.includes('/farm/voices/')&&req.method()==='GET'){return route.fulfill({contentType:'audio/wav',body:blobs.get(path.split('/').pop())||Buffer.alloc(44)});}
    else if(path.endsWith('/farm/buy')){const body=req.postDataJSON();buys.push(body);const kind=state.catalog.find(e=>e.id===body.species);state.coins-=kind.price;kind.owned++;kind.price=Math.ceil(kind.price*1.16);const id=(state.animals.length+1).toString(16).padStart(32,'0');state.animals.push({id,species:kind.id,name:`${kind.name} ${kind.owned}`,voice_id:body.voice_id});json={...state,bought_id:id};}
    else if(path.includes('/farm/animals/')){const body=req.postDataJSON();updates.push(body);Object.assign(state.animals.find(a=>a.id===path.split('/').pop()),body);json=state;}
    else if(path.endsWith('/dashboard'))json={stats:{},leaderboard:[],active_members:[],news:[],events:[]};
    return route.fulfill({json});
  });
  await page.goto('http://127.0.0.1:4186/#games/quatschfarm');
  await expect(page.locator('.farmGame')).toBeVisible();
  await expect.poll(()=>page.locator('.farmPasture canvas').evaluate(c=>Boolean(c.__farmScene?.sprites.complete&&c.__farmScene.sprites.naturalWidth))).toBe(true);
  return {state,uploads,buys,updates};
}

test('microphone: real MediaRecorder → PCM preview → private save → sheep call pays one coin → buy and persist voice assignment',async()=>{
  const browser=await chromium.launch({channel:'msedge',headless:true,args:['--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream']});
  const context=await browser.newContext({viewport:{width:1536,height:1024},permissions:['microphone']});const page=await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  try{
    await page.addInitScript(()=>{const get=navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);navigator.mediaDevices.getUserMedia=async options=>{window.testMic=await get(options);return window.testMic;};});
    const {state,uploads,buys,updates}=await setup(page);
    await expect(page.getByRole('button',{name:'Farm starten',exact:true})).toBeDisabled();
    await page.locator('.farmGame').screenshot({path:join(tmpdir(),'aviary-farm-desktop.png')});
    await page.getByRole('button',{name:'Sound aufnehmen',exact:true}).click();
    await expect(page.getByRole('button',{name:'Aufnahme stoppen',exact:true})).toBeVisible();
    await page.waitForTimeout(1400);
    await page.getByRole('button',{name:'Aufnahme stoppen',exact:true}).click();
    await expect(page.getByRole('button',{name:'Stimme speichern',exact:true})).toBeEnabled();
    expect(await page.evaluate(()=>window.testMic.getTracks().every(track=>track.readyState==='ended'))).toBe(true);
    await page.getByLabel('Name der Aufnahme').fill('Mein Quatsch');
    await page.getByRole('button',{name:'Anhören',exact:true}).click();
    await page.getByRole('button',{name:'Stimme speichern',exact:true}).click();
    await expect(page.getByRole('button',{name:'Farm starten',exact:true})).toBeEnabled();
    expect(uploads).toHaveLength(1);expect(uploads[0].bytes.toString('ascii',0,4)).toBe('RIFF');expect(uploads[0].bytes.length).toBeGreaterThan(3244);expect(uploads[0].bytes.length).toBeLessThanOrEqual(128044);
    await page.getByRole('button',{name:'Farm starten',exact:true}).click();
    await expect(page.getByTestId('farm-coins')).toHaveText('1',{timeout:11000});
    await page.getByRole('button',{name:'Farm stummschalten'}).click();
    await expect(page.getByRole('button',{name:'Farm-Sound einschalten'})).toHaveAttribute('aria-pressed','false');
    await page.getByRole('button',{name:'Farm pausieren',exact:true}).click();
    state.coins=40;await page.reload();
    await page.getByRole('button',{name:'Schaf für 40 Farm-Coins kaufen',exact:true}).evaluate(b=>{b.click();b.click();});
    await expect(page.locator('.farmHerdRow')).toHaveCount(2);expect(buys).toHaveLength(1);expect(buys[0].voice_id).toBe('voice-1');
    await page.getByLabel('Tiername',{exact:true}).fill('Sir Wollbert');
    await page.getByRole('button',{name:'Tier speichern',exact:true}).click();
    await expect(page.locator('.farmSelectedAnimal')).toContainText('Sir Wollbert');expect(updates).toHaveLength(1);
    await page.reload();await expect(page.locator('.farmHerdList')).toContainText('Sir Wollbert');expect(errors).toEqual([]);
  }finally{await browser.close();}
});

test('mobile 100 animals: generated sprites render, full shop, individual herd selection and no overflow',async({browser})=>{
  const context=await browser.newContext({viewport:{width:390,height:844},hasTouch:true,isMobile:true});const page=await context.newPage();
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await setup(page,{count:100,coins:5000});
  await expect(page.locator('.farmHerdRow')).toHaveCount(100);
  await expect.poll(()=>page.locator('.farmPasture canvas').evaluate(c=>c.__farmScene.positions.length)).toBe(100);
  expect(await page.locator('.farmPasture canvas').evaluate(c=>new Set(c.__farmScene.positions.map(p=>`${Math.floor(p.x/60)},${Math.floor(p.y/50)}`)).size)).toBeGreaterThan(30);
  await expect(page.locator('.farmShopRail article')).toHaveCount(6);
  await expect(page.getByRole('button',{name:'Schaf für 40 Farm-Coins kaufen',exact:true})).toBeDisabled();
  await page.getByLabel('Tier suchen').fill('Alpaka 96');
  await page.locator('.farmHerdRow').tap();await expect(page.locator('.farmSelectedAnimal')).toContainText('Alpaka 96');
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.evaluate(()=>scrollTo(0,0));await page.screenshot({path:join(tmpdir(),'aviary-farm-mobile.png'),fullPage:true});
  await page.getByRole('button',{name:'Pepple Survivor',exact:true}).tap();
  await expect(page.getByRole('button',{name:'Spiel starten',exact:true})).toBeEnabled();
  expect(errors).toEqual([]);await context.close();
});

test('microphone permission denial has upload fallback; failed art has working retry; guest cannot mutate a farm',async({page})=>{
  await page.route('**/assets/farm/meadow.png',route=>route.abort());await setup(page,{guest:true});
  await expect(page.getByRole('button',{name:'Weide erneut laden',exact:true})).toBeVisible();
  await page.unroute('**/assets/farm/meadow.png');await page.getByRole('button',{name:'Weide erneut laden',exact:true}).click();
  await expect(page.locator('.farmSceneStatus')).toHaveCount(0);
  await expect(page.getByRole('button',{name:'Sound aufnehmen',exact:true})).toBeDisabled();
  await page.unroute('**/api/**');
  await page.addInitScript(()=>{navigator.mediaDevices.getUserMedia=()=>Promise.reject(new DOMException('Denied','NotAllowedError'));});
  await page.goto('about:blank');
  await setup(page);await page.getByRole('button',{name:'Sound aufnehmen',exact:true}).click();
  await expect(page.getByRole('alert')).toContainText('Mikrofonfreigabe fehlt');
  await expect(page.getByRole('button',{name:'Audiodatei wählen (erste 4 Sekunden)',exact:true})).toBeEnabled();
  const wav=wavSample();
  await page.locator('.farmRecorder input[type=file]').setInputFiles({name:'my-voice.wav',mimeType:'audio/wav',buffer:wav});
  await expect(page.getByRole('button',{name:'Stimme speichern',exact:true})).toBeEnabled();
  await page.getByRole('button',{name:'Stimme speichern',exact:true}).click();
  await expect(page.getByRole('button',{name:'Farm starten',exact:true})).toBeEnabled();
});

test('chaos mode plays all 100 recorded calls through real decoded audio buffers',async({page})=>{
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(()=>{window.farmStarted=0;const context=window.AudioContext||window.webkitAudioContext,create=context.prototype.createBufferSource;context.prototype.createBufferSource=function(...args){const source=create.apply(this,args),start=source.start.bind(source);source.start=(...args)=>{if(source.buffer)window.farmStarted++;return start(...args);};return source;};});
  await setup(page,{count:100,voicesReady:true});
  await page.getByLabel('Sounddichte').selectOption('chaos');
  await page.getByRole('button',{name:'Farm starten',exact:true}).click();
  await expect.poll(()=>page.evaluate(()=>window.farmStarted)).toBe(100);
  await page.getByRole('button',{name:'Farm pausieren',exact:true}).click();expect(errors).toEqual([]);
});

test('silent default input can be replaced with a quiet microphone: live test, normalized recording and private save',async({page})=>{
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(()=>{
    window.micRequests=[];window.micTracks=[];
    navigator.mediaDevices.enumerateDevices=async()=>[
      {kind:'audioinput',deviceId:'silent-input',label:'Stummer Monitor'},
      {kind:'audioinput',deviceId:'quiet-headset',label:'Mein leises Headset'},
    ];
    navigator.mediaDevices.getUserMedia=async options=>{
      window.micRequests.push(options);
      const context=new AudioContext(),tone=context.createOscillator(),gain=context.createGain(),destination=context.createMediaStreamDestination();
      tone.frequency.value=330;gain.gain.value=options.audio.deviceId?.exact==='quiet-headset'?.002:0;
      tone.connect(gain).connect(destination);tone.start();await context.resume();
      const track=destination.stream.getAudioTracks()[0],stop=track.stop.bind(track);
      track.stop=()=>{stop();tone.stop();context.close();};window.micTracks.push(track);
      return destination.stream;
    };
  });
  const {uploads}=await setup(page);
  await page.getByRole('button',{name:'Sound aufnehmen',exact:true}).click();
  await expect(page.getByRole('status')).toContainText('Noch kein Ton');
  await page.getByRole('button',{name:'Aufnahme stoppen',exact:true}).click();
  await expect(page.getByRole('alert')).toContainText('Von diesem Mikrofon kommt kein Ton an');
  await expect(page.getByRole('button',{name:'Stimme speichern',exact:true})).toBeDisabled();expect(uploads).toHaveLength(0);
  await page.getByLabel('Mikrofon auswählen').selectOption('quiet-headset');
  await page.getByRole('button',{name:'Mikrofon testen',exact:true}).click();
  await expect(page.getByRole('status')).toHaveText('Ton kommt an.');
  await expect(page.getByRole('button',{name:'Sound aufnehmen',exact:true})).toBeDisabled();
  expect(uploads).toHaveLength(0);
  await page.locator('.farmStudio').screenshot({path:join(tmpdir(),'aviary-farm-microphone-test.png')});
  await page.getByRole('button',{name:'Mikrofontest stoppen',exact:true}).click();
  expect(await page.evaluate(()=>window.micTracks.every(track=>track.readyState==='ended'))).toBe(true);
  await page.getByRole('button',{name:'Sound aufnehmen',exact:true}).click();
  await expect(page.getByRole('status')).toHaveText('Ton kommt an.');
  await page.waitForTimeout(900);await page.getByRole('button',{name:'Aufnahme stoppen',exact:true}).click();
  await expect(page.getByRole('button',{name:'Anhören',exact:true})).toBeEnabled();
  await page.getByRole('button',{name:'Anhören',exact:true}).click();
  await page.getByRole('button',{name:'Stimme speichern',exact:true}).click();
  expect(uploads).toHaveLength(1);
  const wav=uploads[0].bytes;let peak=0;for(let i=44;i<wav.length;i+=2)peak=Math.max(peak,Math.abs(wav.readInt16LE(i)/32768));
  expect(peak).toBeGreaterThan(.15);expect(peak).toBeLessThan(.99);
  expect(await page.evaluate(()=>window.micRequests.every(request=>request.audio.echoCancellation===false&&request.audio.noiseSuppression===false&&request.audio.autoGainControl===false))).toBe(true);
  expect(await page.evaluate(()=>window.micRequests.at(-1).audio.deviceId)).toEqual({exact:'quiet-headset'});
  expect(await page.evaluate(()=>window.micTracks.every(track=>track.readyState==='ended'))).toBe(true);
  expect(errors).toEqual([]);
});

test('microphone test releases input on navigation and explains unavailable devices',async({page})=>{
  await page.addInitScript(()=>{
    navigator.mediaDevices.getUserMedia=async()=>{throw new DOMException('Unavailable','NotReadableError');};
  });
  await setup(page);
  await page.getByRole('button',{name:'Mikrofon testen',exact:true}).click();
  await expect(page.getByRole('alert')).toContainText('andere App es exklusiv verwendet');
  await expect(page.getByRole('button',{name:'Sound aufnehmen',exact:true})).toBeEnabled();
  await page.evaluate(()=>{
    navigator.mediaDevices.getUserMedia=async()=>{
      const context=new AudioContext(),destination=context.createMediaStreamDestination();window.testInput=destination.stream;
      const track=window.testInput.getAudioTracks()[0],stop=track.stop.bind(track);track.stop=()=>{stop();context.close();};return window.testInput;
    };
  });
  await page.getByRole('button',{name:'Mikrofon testen',exact:true}).click();
  await expect(page.getByRole('button',{name:'Mikrofontest stoppen',exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Pepple Survivor',exact:true}).click();
  await expect.poll(()=>page.evaluate(()=>window.testInput.getTracks().every(track=>track.readyState==='ended'))).toBe(true);
});
