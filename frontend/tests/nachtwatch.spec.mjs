import {test,expect} from '@playwright/test';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
const URL=process.env.NACHTWACHE_QA_URL;
test.skip(!URL,'Set NACHTWACHE_QA_URL to the isolated local Godot QA export.');
if(URL&&!['127.0.0.1','localhost'].includes(new globalThis.URL(URL).hostname))throw new Error('Godot QA must be local.');
test.use({viewport:{width:1536,height:1024},launchOptions:{args:['--enable-unsafe-swiftshader']}});
const state=page=>page.evaluate(()=>{window.nachtwacheQA?.(JSON.stringify({op:'state'}));return window.nachtwacheStatus;});
const qa=(page,command)=>page.evaluate(command=>window.nachtwacheQA(JSON.stringify(command)),command);
async function clickControl(page,text){const control=(await state(page)).controls.find(c=>c.text===text);expect(control).toBeTruthy();const [x,y,w,h]=control.rect;await page.mouse.click(x+w/2,y+h/2);}
async function load(page){await page.goto(URL);await expect(page).toHaveTitle('NACHTWACHE - Kinderparadies');await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu'&&typeof window.nachtwacheQA==='function',{timeout:45000});const exported=await state(page);expect(exported.renderer).toBe('gl_compatibility');expect(exported.native_assets).toBe(false);}
async function begin(page){await load(page);await clickControl(page,'Neue Nachtschicht');await expect.poll(async()=>(await state(page)).phase).toBe('play');}
async function walk(page,key,predicate){await page.keyboard.down(key);try{await expect.poll(async()=>predicate(await state(page)),{timeout:18000,intervals:[70]}).toBe(true);}catch(error){error.message+='\nPatrol state: '+JSON.stringify(await state(page));throw error;}finally{await page.keyboard.up(key);await page.waitForTimeout(180);}}
const errors=[];
test.beforeEach(async({page})=>{errors.length=0;page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});});
test.afterEach(()=>expect(errors).toEqual([]));

test('actual WASD patrol visits all areas, collides with floor, operates flashlight, pauses and chooses the real green door',async({page})=>{
 test.setTimeout(180000);await load(page);await page.screenshot({path:join(tmpdir(),'nachtwache-menu-desktop.png')});await page.mouse.click(250,490);await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await page.keyboard.press('f');await expect.poll(async()=>(await state(page)).torch).toBe(false);await page.keyboard.press('f');
 await walk(page,'w',s=>s.position[2]<4.5);await expect.poll(async()=>(await state(page)).visited).toContain('Empfang');
 await walk(page,'s',s=>s.position[2]>10.3);await walk(page,'d',s=>s.position[0]>8.8);await walk(page,'s',s=>s.position[2]>12.0);await expect.poll(async()=>(await state(page)).visited).toContain('Bällebad');
 await walk(page,'a',s=>s.position[0]<6.05);await walk(page,'w',s=>s.position[2]<-4.9);await walk(page,'d',s=>s.position[0]>11.1);await walk(page,'w',s=>s.position[2]<-6.1);await expect.poll(async()=>(await state(page)).visited).toContain('Partyraum');
 await page.screenshot({path:join(tmpdir(),'nachtwache-partyroom-desktop.png')});await walk(page,'s',s=>s.position[2]>-4.9);await walk(page,'a',s=>s.position[0]<6.05);await walk(page,'w',s=>s.position[2]<-7.2);await walk(page,'a',s=>s.position[0]<-7.1);await expect.poll(async()=>(await state(page)).visited.length).toBe(4);
 await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).phase).toBe('help');await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await walk(page,'d',s=>s.position[0]>-4.4);await walk(page,'w',s=>s.position[2]<-9.9);console.log('Door approach',await state(page));await page.screenshot({path:join(tmpdir(),'nachtwache-door-approach.png')});await expect.poll(async()=>(await state(page)).target).toBe('green');await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).streak).toBe(1);await expect.poll(async()=>(await state(page)).phase).toBe('result');
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await page.mouse.click(250,550);await expect.poll(async()=>(await state(page)).phase).toBe('play');await expect.poll(async()=>(await state(page)).streak).toBe(1);expect((await state(page)).position[1]).toBeGreaterThan(-.2);
});

test('visible anomaly, real door raycasts, wrong decision reset and thirteen consecutive correct doors reach the ending',async({page})=>{
 test.setTimeout(120000);await begin(page);
 await qa(page,{op:'warp',x:-4.3,z:-10.1});await expect.poll(async()=>(await state(page)).target).toBe('green');await page.keyboard.press('e');expect((await state(page)).streak).toBe(0);expect((await state(page)).phase).toBe('play');
 await qa(page,{op:'anomaly',id:'balls_float'});await qa(page,{op:'warp',x:3.0,z:8.5,yaw:0});await page.mouse.click(768,512);await page.waitForTimeout(500);await page.screenshot({path:join(tmpdir(),'nachtwache-anomaly-desktop.png')});
 await qa(page,{op:'inspect'});await qa(page,{op:'warp',x:-4.3,z:-10.1});await expect.poll(async()=>(await state(page)).target).toBe('green');await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('result');expect((await state(page)).streak).toBe(0);
 for(let i=0;i<13;i++){
  await expect.poll(async()=>(await state(page)).phase).toBe('result');await page.waitForTimeout(350);await qa(page,{op:'next'});await expect.poll(async()=>(await state(page)).phase).toBe('play');await page.waitForTimeout(350);await page.mouse.click(768,512);const red=(await state(page)).anomaly!=='none';await qa(page,{op:'inspect'});await qa(page,{op:'warp',x:red?-2.15:-4.3,z:-10.1});await expect.poll(async()=>(await state(page)).target).toBe(red?'red':'green');await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).streak).toBe(i+1);
 }
 await expect.poll(async()=>(await state(page)).phase).toBe('won');await page.waitForTimeout(600);await page.screenshot({path:join(tmpdir(),'nachtwache-ending-desktop.png')});
});

test('pause freezes movement and real settings controls persist volume after reload',async({page})=>{
 await begin(page);await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 const position=(await state(page)).position;await page.keyboard.down('w');await page.waitForTimeout(400);await page.keyboard.up('w');expect((await state(page)).position).toEqual(position);
 await qa(page,{op:'menu'});await page.waitForTimeout(100);await clickControl(page,'Einstellungen');await expect.poll(async()=>(await state(page)).phase).toBe('settings');await page.waitForTimeout(100);
 await clickControl(page,'Lautstärke');await page.keyboard.press('Home');await expect.poll(async()=>(await state(page)).volume).toBe(0);await page.screenshot({path:join(tmpdir(),'nachtwache-settings-desktop.png')});await clickControl(page,'Zurück');await expect.poll(async()=>(await state(page)).phase).toBe('menu');await page.waitForTimeout(400);await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await expect.poll(async()=>(await state(page)).volume).toBe(0);
});

test('space jumps and lands; G physically lifts a toy, mouse throws it, pause freezes props and next world releases references',async({page})=>{
 test.setTimeout(90000);await begin(page);await page.waitForTimeout(250);
 await page.keyboard.press('Space');await expect.poll(async()=>(await state(page)).position[1],{intervals:[70]}).toBeGreaterThan(.5);
 await expect.poll(async()=>(await state(page)).grounded,{timeout:5000}).toBe(true);
 let toy=(await state(page)).props.find(p=>p.name==='Stoffhase');expect(toy).toBeTruthy();
 await qa(page,{op:'warp',x:toy.position[0],z:toy.position[2]+1.8,pitch:-Math.atan2(1.62-toy.position[1],1.8)});
 await page.waitForTimeout(200);await page.keyboard.press('g');await expect.poll(async()=>(await state(page)).held).toBe('Stoffhase');
 await expect.poll(async()=>(await state(page)).props.find(p=>p.name==='Stoffhase').position[1]).toBeGreaterThan(.5);
 await page.screenshot({path:join(tmpdir(),'nachtwache-v11-physics.png')});
 toy=(await state(page)).props.find(p=>p.name==='Stoffhase');await page.mouse.click(768,512);await expect.poll(async()=>(await state(page)).held).toBe('');
 await expect.poll(async()=>Math.hypot(...(await state(page)).props.find(p=>p.name==='Stoffhase').position.map((v,i)=>v-toy.position[i]))).toBeGreaterThan(.6);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const frozen=(await state(page)).props.map(p=>p.position);await page.waitForTimeout(350);expect((await state(page)).props.map(p=>p.position)).toEqual(frozen);expect((await state(page)).props.every(p=>p.frozen)).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).props.every(p=>!p.frozen)).toBe(true);
 await qa(page,{op:'new'});expect((await state(page)).held).toBe('');expect((await state(page)).anomaly).toBe('none');
});

test('website offers a real Windows ZIP and opens the release game without any QA commands',async({page,request})=>{
 await page.route('**/api/**',route=>route.fulfill({json:route.request().url().includes('/auth/me')?{user:null}:[]}));
 await page.goto('http://127.0.0.1:4186/#games/nachtwache');await expect(page.getByRole('heading',{name:'NACHTWACHE',exact:true})).toBeVisible();
 const link=page.getByRole('link',{name:'Für Windows herunterladen',exact:true});await expect(link).toHaveAttribute('href','/downloads/nachtwache-windows-v1.3.0.zip');
 const zip=await request.get('http://127.0.0.1:4186/downloads/nachtwache-windows-v1.3.0.zip',{headers:{Range:'bytes=0-3'}});expect(zip.status()).toBe(206);expect([...(await zip.body())]).toEqual([80,75,3,4]);
 await page.locator('.nightLaunchArt img').evaluate(img=>img.decode());await page.locator('.nightLaunch').screenshot({path:join(tmpdir(),'nachtwache-launcher-desktop.png')});await page.getByRole('button',{name:'Im Web spielen',exact:true}).click();
 await expect(page.getByRole('region',{name:'NACHTWACHE spielen'})).toBeVisible();const iframe=page.frameLocator('iframe[title="NACHTWACHE – eigenständiges 3D-Spiel"]');await expect(iframe.locator('canvas')).toBeVisible();
 const frame=page.frames().find(f=>f.url().includes('/standalone/kinderparadies/'));await frame.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu',{timeout:45000});expect(await frame.evaluate(()=>typeof window.nachtwacheQA)).toBe('undefined');expect(await frame.evaluate(()=>'anomaly' in window.nachtwacheStatus)).toBe(false);
 await page.getByRole('button',{name:'Zurück zur Webseite',exact:true}).click();await expect(page.locator('.nightGameWindow')).toHaveCount(0);expect(await page.locator('.communityApp').evaluate(e=>e.inert)).toBe(false);
});

test('bunny scare requires facing proximity, pauses exactly and completes once; other moving anomalies remain visible',async({page})=>{
 test.setTimeout(90000);await begin(page);
 await qa(page,{op:'warp',x:-5.9,z:4.85,yaw:-Math.PI/2,pitch:-.08});await page.waitForTimeout(1500);
 expect((await state(page)).encounter.triggered).toBe(false);
 await qa(page,{op:'anomaly',id:'bunny_lunge'});await page.waitForTimeout(1200);
 await qa(page,{op:'warp',x:-5.9,z:4.85,yaw:Math.PI/2,pitch:-.08});await page.waitForTimeout(250);
 expect((await state(page)).encounter.triggered).toBe(false);
 await qa(page,{op:'warp',x:-6.3,z:4.85,yaw:-Math.PI/2,pitch:-.08});await page.mouse.click(768,512);
 await page.keyboard.down('w');try{await expect.poll(async()=>(await state(page)).encounter.triggered,{intervals:[30]}).toBe(true);}finally{await page.keyboard.up('w');}
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 const paused=(await state(page)).encounter;await page.waitForTimeout(400);expect((await state(page)).encounter.time).toBe(paused.time);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await expect.poll(async()=>(await state(page)).encounter.finished).toBe(true);
 const ended=(await state(page)).encounter.time;await page.waitForTimeout(500);expect((await state(page)).encounter.time).toBe(ended);
 await qa(page,{op:'anomaly',id:'croc_snap'});await page.waitForTimeout(1100);
 await qa(page,{op:'warp',x:6.8,z:11.3,yaw:-Math.PI/2,pitch:0});await expect.poll(async()=>(await state(page)).encounter.triggered).toBe(true);
 await expect.poll(async()=>(await state(page)).encounter.finished).toBe(true);
 await qa(page,{op:'anomaly',id:'party_burst'});await page.waitForTimeout(1100);
 await qa(page,{op:'warp',x:8.5,z:-4.9,yaw:0,pitch:0});await expect.poll(async()=>(await state(page)).encounter.triggered).toBe(true);
 await expect.poll(async()=>(await state(page)).encounter.finished).toBe(true);
 await qa(page,{op:'new'});expect((await state(page)).encounter.triggered).toBe(false);
});

test('mobile launcher explains keyboard requirement, keeps Windows download and never overflows',async({browser})=>{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});try{const page=await context.newPage();await page.route('**/api/**',route=>route.fulfill({json:route.request().url().includes('/auth/me')?{user:null}:[]}));await page.goto('http://127.0.0.1:4186/#games/nachtwache');await expect(page.getByRole('heading',{name:'NACHTWACHE',exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'Im Web spielen',exact:true})).toBeDisabled();await expect(page.getByRole('link',{name:'Für Windows herunterladen',exact:true})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.locator('.nightLaunch').screenshot({path:join(tmpdir(),'nachtwache-launcher-mobile.png')});}finally{await context.close();}
});
