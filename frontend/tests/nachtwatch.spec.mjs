import {test,expect} from '@playwright/test';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
const URL=process.env.NACHTWACHE_QA_URL;
test.skip(!URL,'Set NACHTWACHE_QA_URL to the isolated local Godot QA export.');
if(URL&&!['127.0.0.1','localhost'].includes(new globalThis.URL(URL).hostname))throw new Error('Godot QA must be local.');
test.use({viewport:{width:1920,height:1080},launchOptions:{args:['--enable-unsafe-swiftshader']}});
const state=page=>page.evaluate(()=>{window.nachtwacheQA?.(JSON.stringify({op:'state'}));return window.nachtwacheStatus;});
async function skipIntro(page){await expect.poll(async()=>(await state(page)).phase).toBe('intro');await page.mouse.move(768,512);await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).phase,{timeout:8000,intervals:[70]}).toBe('play');}finally{await page.keyboard.up('Space');}}
async function qa(page,command){await page.evaluate(command=>window.nachtwacheQA(JSON.stringify(command)),command);if(command.op==='new')await skipIntro(page);}
async function clickControl(page,text){const control=(await state(page)).controls.find(c=>c.text===text);expect(control).toBeTruthy();const [x,y,w,h]=control.rect;await page.mouse.move(x+w/2,y+h/2);await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.mouse.click(x+w/2,y+h/2);await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));}
async function load(page){await page.goto(URL);await expect(page).toHaveTitle('After Play');await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu'&&typeof window.nachtwacheQA==='function',{timeout:45000});const exported=await state(page);expect(exported.renderer).toBe('gl_compatibility');expect(exported.native_assets).toBe(false);expect(exported.shared_croc).toBe(true);expect(exported.presentation.logical_size).toEqual([1920,1080]);}
async function begin(page){await load(page);await clickControl(page,'Neue Nachtschicht');await skipIntro(page);await expect.poll(async()=>(await state(page)).phase).toBe('play');}
async function doorTrip(page,red,{wrong=false}={}){
 await qa(page,{op:'warp',x:red?-2.15:-4.3,z:-10.5,yaw:0,pitch:0});
 await expect.poll(async()=>(await state(page)).target).toBe(red?'red':'green');
 await page.keyboard.press('e');await walk(page,'w',s=>s.phase!=='play');
 if(!wrong)await expect.poll(async()=>(await state(page)).phase,{timeout:15000}).toBe('play');
}
async function walk(page,key,predicate){await page.keyboard.down(key);try{await expect.poll(async()=>predicate(await state(page)),{timeout:18000,intervals:[70]}).toBe(true);}catch(error){error.message+='\nPatrol state: '+JSON.stringify(await state(page));throw error;}finally{await page.keyboard.up(key);await page.waitForTimeout(180);}}
const errors=[];

test('round 5 cinema newspaper can be collected with E from the aisle and stays in the saved inventory',async({page})=>{
 test.setTimeout(150000);await begin(page);
 for(let i=0;i<4;i++){
  await qa(page,{op:'choose',red:(await state(page)).anomaly!=='none'});await expect.poll(async()=>(await state(page)).phase,{timeout:15000}).toBe('play');
 }
 expect((await state(page)).streak).toBe(4);expect((await state(page)).anomaly).toBe('none');expect((await state(page)).archive.spawned.some(p=>p.id==='missing')).toBe(true);
 await qa(page,{op:'warp',x:1.2,y:.03,z:-31.90,yaw:Math.PI/2,pitch:-.85});await expect.poll(async()=>(await state(page)).target).toBe('paper:missing');
 await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-cinema-newspaper.png')});await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).archive.collected.includes('missing')).toBe(true);
 expect((await state(page)).archive.spawned.some(p=>p.id==='missing')).toBe(false);await page.keyboard.press('Tab');expect((await state(page)).archive_reader).toBe('missing');await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-newspaper-reader.png')});await page.keyboard.press('Escape');
 await page.keyboard.press('Escape');await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).streak).toBe(4);expect((await state(page)).archive.collected).toContain('missing');expect((await state(page)).archive.spawned.some(p=>p.id==='missing')).toBe(false);
});

test('reception memories and live CCTV remain voluntary; physical pit balls react and pause',async({page})=>{
 test.setTimeout(150000);await begin(page);
 await qa(page,{op:'warp',x:-7.4,y:.02,z:5.45,yaw:Math.PI/2,pitch:-.24});
 await expect.poll(async()=>(await state(page)).target).toBe('reception_cctv');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('surveillance');
 expect((await state(page)).watch.world_shared).toBe(true);expect((await state(page)).watch.count).toBe(7);
 const position=(await state(page)).position;await page.keyboard.down('w');await page.waitForTimeout(250);await page.keyboard.up('w');expect((await state(page)).position).toEqual(position);
 for(let i=0;i<7;i++){
  await clickControl(page,`Kamera 0${i+1}`);await expect.poll(async()=>(await state(page)).watch.feed).toBe(i);
 }
 await page.screenshot({path:join(tmpdir(),'after-play-v2120-web-cctv.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).watch.opened).toBe(false);expect((await state(page)).watch.updates).toBe(0);
 await qa(page,{op:'warp',x:1.2,y:.02,z:14.7,yaw:Math.PI,pitch:.43});await expect.poll(async()=>(await state(page)).target).toBe('memory_wall');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('help');expect((await state(page)).instructions.join(' ')).toContain('Die Geburtstage von damals');await page.screenshot({path:join(tmpdir(),'after-play-v2120-web-photos.png')});await clickControl(page,'Zurück zum Rundgang');
 await qa(page,{op:'warp',x:1.1,y:.03,z:7.8,yaw:0,pitch:-.55});await page.keyboard.down('w');
 await expect.poll(async()=>(await state(page)).ball_pit.kicks,{timeout:12000}).toBeGreaterThan(0);await page.keyboard.up('w');
 expect((await state(page)).ball_pit.count).toBe(360);await page.screenshot({path:join(tmpdir(),'after-play-v2120-web-ball-physics.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');expect((await state(page)).ball_pit.running).toBe(false);
 await clickControl(page,'Rundgang fortsetzen');await expect.poll(async()=>(await state(page)).ball_pit.running).toBe(true);
 for(const encounter of [{id:'wc_stall_watcher',x:23.5,z:7,yaw:Math.PI,pitch:0},{id:'wc_ceiling_guest',x:22.4,z:7.1,yaw:-Math.PI/2,pitch:-.12},{id:'snackbar_visitor',x:17.2,z:11.9,yaw:Math.PI,pitch:0}]){
  await qa(page,{op:'anomaly',id:encounter.id});await qa(page,{op:'warp',...encounter,y:.03});
  await expect.poll(async()=>(await state(page)).terrors.triggered,{timeout:12000}).toBe(true);
 }
 await qa(page,{op:'anomaly',id:'balls_missing'});expect((await state(page)).ball_pit.running).toBe(false);
 await qa(page,{op:'anomaly',id:'balls_float'});await expect.poll(async()=>(await state(page)).ball_pit.floating).toBe(120);
});
test.beforeEach(async({page})=>{errors.length=0;page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});});
test.afterEach(()=>expect(errors).toEqual([]));

test('v2.4 recorded footsteps follow six actual floors; the furred mascot renders and the phone display follows the call',async({page})=>{
 test.setTimeout(120000);await load(page);await clickControl(page,'Neue Nachtschicht');
 await expect.poll(async()=>(await state(page)).polish.phone_state).toBe('Eingehender Anruf');await page.waitForTimeout(1500);await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).polish.phone_state).toBe('Verbunden');await page.screenshot({path:join(tmpdir(),'after-play-v240-web-phone.png')});await skipIntro(page);
 const samples=[{floor:'concrete',x:-6,z:8,y:0,yaw:0},{floor:'carpet',x:-5,z:-29.65,y:0,yaw:-Math.PI/2},{floor:'metal',x:-12.1,z:-4.5,y:0,yaw:Math.PI/2},{floor:'rubber',x:-.65,z:-5.04,y:.39,yaw:Math.PI},{floor:'plastic',x:-2.63,z:15.8,y:.31,yaw:-Math.PI/2},{floor:'wood',x:7.5,z:3.6,y:2.44,yaw:-Math.PI/2}];
 for(const sample of samples){
  await qa(page,{op:'warp',...sample});if(sample.floor==='plastic')await page.keyboard.down('c');
  await expect.poll(async()=>(await state(page)).polish.floor).toBe(sample.floor);const before=(await state(page)).polish.steps;
  await walk(page,'w',s=>s.polish.steps>before);expect((await state(page)).polish.last_surface).toBe(sample.floor);
  expect((await state(page)).polish.step_track).toContain(sample.floor==='plastic'?'/ambience/crawl-contact.wav':`/surfaces/footstep_${sample.floor}_`);
  await page.keyboard.up('c');
 }
 await qa(page,{op:'warp',x:13.2,z:-6.8,yaw:-2.5,pitch:.18});await page.waitForTimeout(700);expect((await state(page)).polish.mascot).toBe(true);expect((await state(page)).polish.fur).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v240-web-mascot.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');expect((await state(page)).polish.step_playing).toBe(false);
});

test('v2.6.0 sewn party mascot is on the right, has a solid approach and leaves the withdrawal route clear',async({page})=>{
 test.setTimeout(90000);await begin(page);
 const current=await state(page);expect(current.polish.party_mascot).toBe(true);for(const [i,value] of [17.9,.016,.38].entries())expect(current.polish.party_position[i]).toBeCloseTo(value,4);expect(current.fog.density).toBeCloseTo(.08);
 await qa(page,{op:'warp',x:17.9,z:-3.0,yaw:Math.PI,pitch:.18});await walk(page,'w',s=>s.position[2]>-1.7);
 await page.keyboard.down('w');await page.waitForTimeout(550);await page.keyboard.up('w');const blocked=(await state(page)).position;expect(blocked[2]).toBeLessThan(-.95);expect(blocked[2]).toBeGreaterThan(-1.8);expect(blocked[1]).toBeGreaterThan(-.1);
 await walk(page,'s',s=>s.position[2]<-2.6);await page.screenshot({path:join(tmpdir(),'after-play-v251-web-party-mascot.png')});
 await qa(page,{op:'audit'});const audit=(await state(page)).layout;expect(audit.door_obstructions).toEqual([]);expect(audit.art_overlaps).toEqual([]);expect(audit.furniture_wall_intrusions).toEqual([]);
});

test('v2.7 stage ramp and backstage are walkable both ways; E reads maintenance history and TAB opens the duty badge',async({page})=>{
 test.setTimeout(150000);await begin(page);expect((await state(page)).backstage.costumes).toBe(7);
 expect((await state(page)).hud_labels.some(t=>t.includes('Empfang')||t.includes('WASD'))).toBe(false);expect((await state(page)).hud_labels).toContain('RUNDGANG 01 / 13');
 await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).notebook.visible).toBe(true);expect((await state(page)).notebook.round).toBe(1);await page.screenshot({path:join(tmpdir(),'after-play-v270-web-notebook.png')});await page.keyboard.press('Escape');
 await qa(page,{op:'warp',x:17.3,z:-8.2,yaw:0});await walk(page,'w',s=>s.position[2]<-14.0);
 expect((await state(page)).polish.floor).toBe('wood');await page.screenshot({path:join(tmpdir(),'after-play-v270-web-costumes.png')});
 await page.keyboard.press('Escape');await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).position[2]).toBeLessThan(-13.9);
 await walk(page,'s',s=>s.position[2]>-8.7);expect((await state(page)).position[1]).toBeGreaterThan(-.1);
 for(const doc of [{id:'plan',x:-14.1,y:1.94,text:'Bestandsplan'},{id:'repairs',x:-12.55,y:1.82,text:'Wartungsbuch'}]){
  await qa(page,{op:'warp',x:doc.x,z:-5.17,yaw:0,pitch:Math.atan2(doc.y-1.62,1.65)});await expect.poll(async()=>(await state(page)).target).toBe('story:'+doc.id);
  await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('help');expect((await state(page)).instructions.join(' ')).toContain(doc.text);
  const before=(await state(page)).position;await page.keyboard.down('w');await page.waitForTimeout(250);await page.keyboard.up('w');expect((await state(page)).position).toEqual(before);await clickControl(page,'Zurück zum Rundgang');
 }
 await page.keyboard.press('Tab');await clickControl(page,'Meine Kontrollliste');expect((await state(page)).notebook.visited).toEqual((await state(page)).visited);await clickControl(page,'Meine Ausrüstung');await expect.poll(async()=>(await state(page)).phase).toBe('help');expect((await state(page)).instructions.join(' ')).toContain('Dienstausweis 013');
 await page.screenshot({path:join(tmpdir(),'after-play-v270-web-equipment.png')});await clickControl(page,'Zurück zu den Fundstücken');await expect.poll(async()=>(await state(page)).phase).toBe('inventory');await page.keyboard.press('Escape');
 await qa(page,{op:'audit'});expect((await state(page)).layout.door_obstructions).toEqual([]);expect((await state(page)).layout.art_overlaps).toEqual([]);
});

test('v2.7 false exit changes once, pauses and preserves the decayed corridor and return path after reload',async({page})=>{
 test.setTimeout(150000);await begin(page);await qa(page,{op:'choose',red:false});await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await qa(page,{op:'anomaly',id:'false_exit'});await qa(page,{op:'warp',x:-8.8,z:9.4,yaw:Math.PI/2,pitch:-.20});await expect.poll(async()=>(await state(page)).target).toBe('delivery_exit');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).backstage.exit_started).toBe(true);expect((await state(page)).backstage.clean_corridor).toBe(true);
 await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).phase).toBe('inventory');const paused=(await state(page)).backstage.exit_clock;await page.waitForTimeout(500);expect((await state(page)).backstage.exit_clock).toBe(paused);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).backstage.exit_finished,{timeout:12000}).toBe(true);expect((await state(page)).backstage.clean_corridor).toBe(false);
 await expect.poll(async()=>(await state(page)).backstage.exit_angle).toBe(0);await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).backstage.exit_angle).toBeGreaterThan(1.45);
 await walk(page,'w',s=>s.position[0]<-12.3);await page.screenshot({path:join(tmpdir(),'after-play-v270-web-exit.png')});
 await page.keyboard.press('Escape');await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).backstage.exit_finished).toBe(true);expect((await state(page)).backstage.exit_open).toBe(true);expect((await state(page)).position[0]).toBeLessThan(-12.2);await walk(page,'s',s=>s.position[0]>-9.8);
});

test('v2.7 hanging costume and seated guest react in 3D; the costume remains changed when the shift resumes',async({page})=>{
 test.setTimeout(120000);await begin(page);await qa(page,{op:'choose',red:false});await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await qa(page,{op:'anomaly',id:'costume_wakes'});await qa(page,{op:'warp',x:16.15,y:.2,z:-15.1,yaw:0,pitch:.15});await expect.poll(async()=>(await state(page)).backstage.costume_triggered).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const frozen=(await state(page)).backstage.costume_attack;await page.waitForTimeout(400);expect((await state(page)).backstage.costume_attack).toBe(frozen);
 expect((await state(page)).backstage.costume_paused).toBe(true);await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).backstage.costume_triggered).toBe(true);expect((await state(page)).backstage.costume_audio).toBe(false);
 await qa(page,{op:'anomaly',id:'throne_guest'});await qa(page,{op:'warp',x:13.4,y:.2,z:-8.6,yaw:0,pitch:.10});await expect.poll(async()=>(await state(page)).terrors.triggered).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v270-web-throne-guest.png')});
});

test('v2.5 cinematic menu and eleven narration images follow the actual tape, pause and restore the archive',async({page})=>{
 test.setTimeout(150000);await load(page);
 const menuControls=(await state(page)).controls.filter(c=>['Neue Nachtschicht','Schicht fortsetzen','Einstellungen','Dienstanweisung','Mitwirkende','Zur Webseite'].includes(c.text));expect(menuControls).toHaveLength(6);
 for(let i=1;i<menuControls.length;i++)expect(menuControls[i].rect[1]).toBeGreaterThanOrEqual(menuControls[i-1].rect[1]+menuControls[i-1].rect[3]);
 await page.screenshot({path:join(tmpdir(),'after-play-v250-web-main-menu.png')});await clickControl(page,'Einstellungen');await expect.poll(async()=>(await state(page)).phase).toBe('settings');await clickControl(page,'Audio');await expect.poll(async()=>(await state(page)).settings_tab).toBe('Audio');expect((await state(page)).controls.some(c=>c.text==='Menümusik')).toBe(true);await clickControl(page,'Zurück');await expect.poll(async()=>(await state(page)).phase).toBe('menu');await clickControl(page,'Neue Nachtschicht');await skipIntro(page);
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2,pitch:-.22});await expect.poll(async()=>(await state(page)).target).toBe('archive_door');await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('code');await page.mouse.click(275,220);await page.keyboard.type('0712',{delay:35});await expect.poll(async()=>(await state(page)).archive_input).toBe('0712');await page.keyboard.press('Enter');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await qa(page,{op:'warp',x:-11.3,z:-9.9,yaw:1.983,pitch:-1.049});await expect.poll(async()=>(await state(page)).target).toBe('archive_recording');await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).memories.visible).toBe(true);
 const cues=[['01-recorder.png',2],['02-birthday.png',24.2],['03-showkitchen.png',52.6],['04-the-soup.png',89.4],['05-emergency-call.png',107.1],['06-locked-exit.png',135.3],['07-the-archive.png',162.6],['08-the-return.png',193.3],['09-the-pot.png',208.4],['10-abandoned.png',224.9],['11-warning.png',257.9]];
 for(let i=0;i<cues.length;i++){
  await qa(page,{op:'recording_seek',time:cues[i][1]});await expect.poll(async()=>(await state(page)).memories.shot).toBe(i);expect((await state(page)).memories.image).toBe(cues[i][0]);
  if([0,2,6,10].includes(i))await page.screenshot({path:join(tmpdir(),`after-play-v250-web-memory-${i}.png`)});
 }
 const pose=(await state(page)).position;await page.keyboard.down('w');await page.waitForTimeout(350);await page.keyboard.up('w');expect((await state(page)).position).toEqual(pose);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const frozen=(await state(page)).memories;await page.waitForTimeout(400);expect((await state(page)).memories).toEqual(frozen);await page.screenshot({path:join(tmpdir(),'after-play-v250-web-memory-pause.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');await qa(page,{op:'recording_seek',time:(await state(page)).archive.finale.duration-.5});await expect.poll(async()=>(await state(page)).archive.finale.state).toBe('armed');expect((await state(page)).memories.visible).toBe(false);expect((await state(page)).archive.recording_locked).toBe(false);
});

test('standalone 16:9 stays proportional at 4:3 and 16:10; the fresco and its visitor share the new right-hand wall',async({page})=>{
 test.setTimeout(90000);await load(page);await page.screenshot({path:join(tmpdir(),'after-play-v230-web-menu.png')});
 for(const viewport of [{width:1280,height:960},{width:1536,height:1024}]){
  await page.setViewportSize(viewport);await expect.poll(async()=>(await state(page)).presentation.logical_size).toEqual([1920,1080]);
  await expect.poll(async()=>{const [w,h]=(await state(page)).presentation.render_size;return Math.abs(w/h-16/9);}).toBeLessThan(.004);
  await page.screenshot({path:join(tmpdir(),`after-play-v230-web-letterbox-${viewport.width}.png`)});
 }
 await page.setViewportSize({width:1920,height:1080});await clickControl(page,'Neue Nachtschicht');await skipIntro(page);
 const fresco=(await state(page)).presentation.fresco;expect(fresco[0]).toBeCloseTo(12.0);expect(fresco[2]).toBeCloseTo(1.485);
 await qa(page,{op:'warp',x:12.0,z:-4.4,yaw:Math.PI,pitch:.18});await page.waitForTimeout(600);await page.screenshot({path:join(tmpdir(),'after-play-v230-web-right-wall.png')});
 await qa(page,{op:'anomaly',id:'party_portrait'});await qa(page,{op:'warp',x:12.0,z:-1.5,yaw:Math.PI,pitch:0});
 await expect.poll(async()=>(await state(page)).terrors.triggered).toBe(true);expect((await state(page)).terrors.position[0]).toBeGreaterThan(10.5);expect((await state(page)).terrors.position[2]).toBeLessThan(1.485);
});

test('actual WASD patrol visits all areas, collides with floor, operates flashlight, pauses and chooses the real green door',async({page})=>{
 test.setTimeout(180000);await load(page);await page.screenshot({path:join(tmpdir(),'nachtwache-menu-desktop.png')});await clickControl(page,'Neue Nachtschicht');await skipIntro(page);await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await page.keyboard.press('f');await expect.poll(async()=>(await state(page)).torch).toBe(false);await page.keyboard.press('f');
 await walk(page,'w',s=>s.position[2]<10.1);await walk(page,'d',s=>s.position[0]>-6.2);await walk(page,'w',s=>s.position[2]<4.5);await expect.poll(async()=>(await state(page)).visited).toContain('Empfang');
 await walk(page,'s',s=>s.position[2]>10.3);await walk(page,'d',s=>s.position[0]>8.8);await walk(page,'s',s=>s.position[2]>12.0);await expect.poll(async()=>(await state(page)).visited).toContain('Bällebad');
 await walk(page,'a',s=>s.position[0]<6.05);await walk(page,'w',s=>s.position[2]<-8.5);await walk(page,'d',s=>s.position[0]>12.1);await walk(page,'s',s=>s.position[2]>-6.9);await expect.poll(async()=>(await state(page)).visited).toContain('Party Raum');
 await page.screenshot({path:join(tmpdir(),'nachtwache-partyroom-desktop.png')});await walk(page,'w',s=>s.position[2]<-8.5);await walk(page,'a',s=>s.position[0]<6.05);await walk(page,'w',s=>s.position[2]<-7.2);await walk(page,'a',s=>s.position[0]<-7.1);await expect.poll(async()=>(await state(page)).visited.length).toBe(4);
 await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).phase).toBe('inventory');await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await doorTrip(page,false);expect((await state(page)).streak).toBe(1);
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');await expect.poll(async()=>(await state(page)).streak).toBe(1);expect((await state(page)).position[1]).toBeGreaterThan(-.2);
});

test('v2.8 real corridors return through the entrance elevator; death resets; thirteen rounds finish at ending 1 with credits',async({page})=>{
 test.setTimeout(300000);await begin(page);
 expect((await state(page)).visited).toEqual([]);
 await qa(page,{op:'warp',x:-4.3,z:-10.5,yaw:0});await expect.poll(async()=>(await state(page)).target).toBe('green');await page.keyboard.press('e');
 await page.waitForTimeout(750);await qa(page,{op:'audit'});expect((await state(page)).layout.door_obstructions).toEqual([]);
 await page.screenshot({path:join(tmpdir(),'after-play-v291-web-open-green.png')});
 expect((await state(page)).streak).toBe(0);await walk(page,'w',s=>s.position[2]<-15.1);
 const position=(await state(page)).position;expect((await state(page)).passage.chosen).toBe(0);
 await page.keyboard.press('Escape');await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');
 expect((await state(page)).passage.chosen).toBe(0);expect((await state(page)).position[2]).toBeCloseTo(position[2],1);
 await page.screenshot({path:join(tmpdir(),'after-play-v280-web-corridor.png')});await walk(page,'w',s=>s.phase==='lift');
 await expect.poll(async()=>(await state(page)).phase,{timeout:15000}).toBe('play');expect((await state(page)).streak).toBe(1);expect((await state(page)).position[2]).toBeGreaterThan(19);
 await qa(page,{op:'anomaly',id:'balls_float'});await doorTrip(page,true);expect((await state(page)).streak).toBe(2);
 await qa(page,{op:'anomaly',id:'balls_float'});await doorTrip(page,false,{wrong:true});expect((await state(page)).failure.running).toBe(true);
 await page.waitForTimeout(150);await page.screenshot({path:join(tmpdir(),'after-play-v280-web-attacker.png')});
 await expect.poll(async()=>(await state(page)).death_text,{intervals:[30]}).toBe('2 Runden überlebt');await page.screenshot({path:join(tmpdir(),'after-play-v280-web-death.png')});
 await expect.poll(async()=>(await state(page)).phase,{timeout:15000}).toBe('play');expect((await state(page)).streak).toBe(0);expect((await state(page)).rounds).toBe(0);expect((await state(page)).intro.stage).toBe('done');
 expect((await state(page)).failure.count).toBe(1);await page.screenshot({path:join(tmpdir(),'after-play-v280-web-wake.png')});
 let anomalyRounds=0;
 for(let i=0;i<13;i++){
  const anomalous=(await state(page)).anomaly!=='none';anomalyRounds+=Number(anomalous);
  if([1,3,5,8,11].includes(i+1))expect(anomalous).toBe(false);
  await qa(page,{op:'choose',red:anomalous});await expect.poll(async()=>(await state(page)).phase,{timeout:15000}).toBe(i===12?'ending':'play');expect((await state(page)).streak).toBe(i+1);
 }
 expect(anomalyRounds).toBe(6);
 expect((await state(page)).completed).toBe(true);expect((await state(page)).ending_credits.title).toBe('ENDE 1/2');expect((await state(page)).ending_credits.second_end_hint).toBe('schau dich für Ende 2 nochmal genauer um in Runde 3,5,8 und 11');
 await expect.poll(async()=>(await state(page)).ending_credits.end_word).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-ending-1.png')});
 await expect.poll(async()=>(await state(page)).ending_credits.music).toBe(true);expect((await state(page)).ending_credits.music_track).toBe('res://assets/party/musicbox.mp3');
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:25000}).toBe(true);}finally{await page.keyboard.up('Space');}
 expect((await state(page)).phase).toBe('ending');expect((await state(page)).streak).toBe(13);await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-ending-1-clue.png')});
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('ending');expect((await state(page)).ending_credits.ending).toBe(1);expect((await state(page)).streak).toBe(13);
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:25000}).toBe(true);}finally{await page.keyboard.up('Space');}
 await clickControl(page,'Neue Nachtschicht');await skipIntro(page);expect((await state(page)).streak).toBe(0);expect((await state(page)).completed).toBe(false);
});

test('pause freezes movement and real settings controls persist volume after reload',async({page})=>{
 await begin(page);await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 const position=(await state(page)).position;await page.keyboard.down('w');await page.waitForTimeout(400);await page.keyboard.up('w');expect((await state(page)).position).toEqual(position);
 await qa(page,{op:'menu'});await page.waitForTimeout(100);await clickControl(page,'Einstellungen');await expect.poll(async()=>(await state(page)).phase).toBe('settings');await page.waitForTimeout(100);
 await clickControl(page,'Audio');await clickControl(page,'Lautstärke');await page.keyboard.press('Home');await expect.poll(async()=>(await state(page)).volume).toBe(0);await page.screenshot({path:join(tmpdir(),'nachtwache-settings-desktop.png')});await clickControl(page,'Zurück');await expect.poll(async()=>(await state(page)).phase).toBe('menu');await page.waitForTimeout(400);await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await expect.poll(async()=>(await state(page)).volume).toBe(0);
});

test('space jumps and lands; G physically lifts a toy, mouse throws it, pause freezes props and next world releases references',async({page})=>{
 test.setTimeout(90000);await begin(page);await page.waitForTimeout(250);
 await page.keyboard.press('Space');await expect.poll(async()=>(await state(page)).position[1],{intervals:[70]}).toBeGreaterThan(.5);
 await expect.poll(async()=>(await state(page)).grounded,{timeout:5000}).toBe(true);
 let toy=(await state(page)).props.find(p=>p.name==='Stoffhase');expect(toy).toBeTruthy();
 await qa(page,{op:'warp',x:toy.position[0],z:toy.position[2]+1.8,pitch:-Math.atan2(1.62-toy.position[1],1.8)});
 await page.waitForTimeout(200);await page.keyboard.press('g');await expect.poll(async()=>(await state(page)).held).toBe('Stoffhase');
 await expect.poll(async()=>(await state(page)).props.find(p=>p.name==='Stoffhase').position[1]).toBeGreaterThan(.5);
 const heldImpacts=(await state(page)).props.find(p=>p.name==='Stoffhase').impacts;await page.waitForTimeout(1200);expect((await state(page)).props.find(p=>p.name==='Stoffhase').impacts).toBe(heldImpacts);expect((await state(page)).props.find(p=>p.name==='Stoffhase').sound_active).toBe(false);
 await page.screenshot({path:join(tmpdir(),'nachtwache-v11-physics.png')});
 toy=(await state(page)).props.find(p=>p.name==='Stoffhase');await page.mouse.click(768,512);await expect.poll(async()=>(await state(page)).held).toBe('');
 await expect.poll(async()=>Math.hypot(...(await state(page)).props.find(p=>p.name==='Stoffhase').position.map((v,i)=>v-toy.position[i]))).toBeGreaterThan(.6);
 await expect.poll(async()=>(await state(page)).props.find(p=>p.name==='Stoffhase').impacts,{timeout:5000}).toBeGreaterThan(heldImpacts);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const frozen=(await state(page)).props.map(p=>p.position);await page.waitForTimeout(350);expect((await state(page)).props.map(p=>p.position)).toEqual(frozen);expect((await state(page)).props.every(p=>p.frozen)).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).props.every(p=>!p.frozen)).toBe(true);
 await qa(page,{op:'new'});expect((await state(page)).held).toBe('');expect((await state(page)).anomaly).toBe('none');
});

test('website offers a real Windows ZIP and opens the release game without any QA commands',async({page,request})=>{
 await page.route('**/api/**',route=>route.fulfill({json:route.request().url().includes('/auth/me')?{user:null}:[]}));
 await page.goto('http://127.0.0.1:4186/#games/nachtwache');await expect(page.getByRole('heading',{name:'After Play',exact:true})).toBeVisible();
 const link=page.getByRole('link',{name:'Für Windows herunterladen',exact:true});await expect(link).toHaveAttribute('href','/downloads/after-play-windows-v2.8.0.zip');
 const zip=await request.get('http://127.0.0.1:4186/downloads/after-play-windows-v2.8.0.zip',{headers:{Range:'bytes=0-3'}});expect(zip.status()).toBe(206);expect([...(await zip.body())]).toEqual([80,75,3,4]);
 await page.locator('.nightLaunchArt img').evaluate(img=>img.decode());await page.locator('.nightLaunch').screenshot({path:join(tmpdir(),'nachtwache-launcher-desktop.png')});await page.getByRole('button',{name:'Im Web spielen',exact:true}).click();
 await expect(page.getByRole('region',{name:'After Play spielen'})).toBeVisible();const iframe=page.frameLocator('iframe[title="After Play – eigenständiges 3D-Spiel"]');await expect(iframe.locator('canvas')).toBeVisible();
 const frame=page.frames().find(f=>f.url().includes('/standalone/kinderparadies/'));await frame.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu',{timeout:45000});expect(await frame.evaluate(()=>typeof window.nachtwacheQA)).toBe('undefined');expect(await frame.evaluate(()=>'anomaly' in window.nachtwacheStatus)).toBe(false);
 for(const viewport of [{width:1920,height:1080},{width:1280,height:960},{width:1536,height:1024}]){await page.setViewportSize(viewport);await expect.poll(async()=>{const box=await page.locator('.nightGameStage iframe').boundingBox();return Math.abs(box.width/box.height-16/9);}).toBeLessThan(.002);const box=await page.locator('.nightGameStage iframe').boundingBox();expect(box.x).toBeGreaterThanOrEqual(0);expect(box.y).toBeGreaterThanOrEqual(43);expect(box.x+box.width).toBeLessThanOrEqual(viewport.width+.1);expect(box.y+box.height).toBeLessThanOrEqual(viewport.height+.1);}
 await page.getByRole('button',{name:'Spiel im Vollbild öffnen'}).click();await page.waitForFunction(()=>Boolean(document.fullscreenElement));await expect.poll(async()=>{const box=await page.locator('.nightGameStage iframe').boundingBox();return Math.abs(box.width/box.height-16/9);}).toBeLessThan(.002);await page.evaluate(()=>document.exitFullscreen());
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
 expect((await state(page)).croc_jaw).toBeCloseTo(.12,2);
 await qa(page,{op:'anomaly',id:'party_burst'});await page.waitForTimeout(1100);
 await qa(page,{op:'warp',x:8.5,z:-4.9,yaw:0,pitch:0});await expect.poll(async()=>(await state(page)).encounter.triggered).toBe(true);
 await expect.poll(async()=>(await state(page)).encounter.finished).toBe(true);
 await qa(page,{op:'new'});expect((await state(page)).encounter.triggered).toBe(false);
});

test('mobile launcher explains keyboard requirement, keeps Windows download and never overflows',async({browser})=>{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});try{const page=await context.newPage();await page.route('**/api/**',route=>route.fulfill({json:route.request().url().includes('/auth/me')?{user:null}:[]}));await page.goto('http://127.0.0.1:4186/#games/nachtwache');await expect(page.getByRole('heading',{name:'After Play',exact:true})).toBeVisible();await expect(page.getByRole('button',{name:'Im Web spielen',exact:true})).toBeDisabled();await expect(page.getByRole('link',{name:'Für Windows herunterladen',exact:true})).toBeVisible();expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.locator('.nightLaunch').screenshot({path:join(tmpdir(),'nachtwache-launcher-mobile.png')});}finally{await context.close();}
});

test('polished rooms have clear walls, inward chairs, separated balls, mounted artwork and normal dense fog',async({page})=>{
 test.setTimeout(90000);await begin(page);await qa(page,{op:'audit'});
 await expect.poll(async()=>(await state(page)).layout.ball_source).toBe('renderer');
 const normal=await state(page);expect(normal.layout.wall_intersections).toEqual([]);expect(normal.layout.ball_min_distance).toBeGreaterThan(.28);expect(normal.layout.chair_back_dot).toBeGreaterThan(.95);expect(normal.layout.mounted_art).toBeGreaterThanOrEqual(20);expect(normal.layout.floating_labels).toBeLessThanOrEqual(8);expect(normal.fog.density).toBeGreaterThanOrEqual(.065);
 for(const shot of [{name:'gallery',x:14,z:-9.3,yaw:0,pitch:.22},{name:'party',x:11.8,z:-3.8,yaw:.65,pitch:-.12},{name:'pit',x:0,z:9.6,yaw:0,pitch:-.46},{name:'tower',x:6.1,z:4.7,yaw:-Math.PI/2,pitch:.3},{name:'hours',x:-8.1,z:7.4,yaw:Math.PI/2,pitch:.14}]){
  await qa(page,{op:'warp',...shot});await page.waitForTimeout(500);await page.screenshot({path:join(tmpdir(),'nachtwache-polish-web-'+shot.name+'.png')});
 }
 await qa(page,{op:'anomaly',id:'heavy_mist'});await page.waitForTimeout(300);expect((await state(page)).fog.color).not.toBe(normal.fog.color);expect((await state(page)).fog.density).toBeCloseTo(normal.fog.density,3);
 await qa(page,{op:'warp',x:-1,z:12,yaw:-.95,pitch:.09});await page.waitForTimeout(350);await page.screenshot({path:join(tmpdir(),'nachtwache-polish-web-fog-red.png')});
 await qa(page,{op:'anomaly',id:'balls_float'});await page.waitForTimeout(900);await qa(page,{op:'audit'});expect((await state(page)).layout.ball_min_distance).toBeGreaterThan(.28);
 await qa(page,{op:'anomaly',id:'mural_bleeds'});await qa(page,{op:'warp',x:-7.2,z:-2.8,yaw:Math.PI/2,pitch:.08});await page.waitForTimeout(500);await page.screenshot({path:join(tmpdir(),'nachtwache-polish-web-mural-blood.png')});
 await qa(page,{op:'new'});await page.waitForTimeout(300);expect((await state(page)).fog.color).toBe(normal.fog.color);expect((await state(page)).fog.density).toBeCloseTo(normal.fog.density,3);
});

test('party entrance, moulded slide and bridge are physically traversable through matching net openings',async({page})=>{
 test.setTimeout(120000);await begin(page);await qa(page,{op:'audit'});
 const audited=await state(page);expect(audited.layout.net_intrusions).toEqual([]);expect(audited.layout.net_panels).toBe(8);expect(audited.layout.wall_paintings).toBe(5);
 await qa(page,{op:'warp',x:5.6,z:-8.7,yaw:-Math.PI/2});await page.mouse.click(768,512);await walk(page,'w',s=>s.position[0]>7.4);await walk(page,'s',s=>s.position[0]<6.1);
 await qa(page,{op:'warp',x:2.3975,y:3.016,z:.828,yaw:Math.PI,pitch:-.2});await walk(page,'w',s=>s.position[2]>6.9);expect((await state(page)).position[1]).toBeLessThan(1.3);
 await qa(page,{op:'warp',x:4.1,y:3.01,z:3.6,yaw:-Math.PI/2});await walk(page,'w',s=>s.position[0]>10.7);expect((await state(page)).position[1]).toBeGreaterThan(2);
 await qa(page,{op:'warp',x:10.8,y:2.2,z:3.6,yaw:Math.PI/2});await walk(page,'w',s=>s.position[0]<4.1);expect((await state(page)).position[1]).toBeGreaterThan(2.7);
 for(const shot of [{name:'door-front',x:4.87,z:-8.7,yaw:-Math.PI/2,pitch:.16},{name:'door-corner',x:5.4,z:-3.1,yaw:-.49,pitch:.1},{name:'slide',x:5.9,z:9.7,yaw:.57,pitch:.08},{name:'upper-play',x:-.535,y:2.99,z:2.9,yaw:0,pitch:-.06},{name:'clown',x:-6.5,z:12.5,yaw:Math.PI/2,pitch:.28},{name:'party-mural',x:16.1,z:-7.3,yaw:-Math.PI/2,pitch:.22}]){
  await qa(page,{op:'warp',...shot});await page.waitForTimeout(600);await page.screenshot({path:join(tmpdir(),'nachtwache-v150-web-'+shot.name+'.png')});
 }
});

test('normal tube voices, crouch clearance, complete winding traversal and window watcher behave independently',async({page})=>{
 test.setTimeout(150000);await begin(page);
 await page.mouse.click(768,512);await qa(page,{op:'warp',x:-5.5,z:10.7,yaw:Math.PI});
 await page.keyboard.down('c');await walk(page,'w',s=>s.position[2]>12.9);
 expect((await state(page)).crouching).toBe(true);expect((await state(page)).tube).toBe(true);
 await page.keyboard.up('c');await page.waitForTimeout(500);expect((await state(page)).crouching).toBe(true);
 await expect.poll(async()=>(await state(page)).ambience.voice_count,{timeout:10000}).toBeGreaterThan(0);
 expect((await state(page)).anomaly).toBe('none');expect((await state(page)).watcher).toBe(false);
 expect((await state(page)).ambience.last_voice).toBe('children-laugh.ogg');
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 const paused=(await state(page)).ambience;await page.waitForTimeout(700);expect((await state(page)).ambience.clock).toBe(paused.clock);expect((await state(page)).ambience.voice_paused).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await expect.poll(async()=>(await state(page)).ambience.last_voice,{timeout:18000}).toBe('children-cry.ogg');expect((await state(page)).anomaly).toBe('none');
 await page.keyboard.down('c');
 await page.keyboard.down('w');try{
  for(const [x,z] of [[-5.5,14],[-5.26,14.9],[-4.6,15.56],[-3.7,15.8],[1.9,15.8],[2.8,15.56],[3.46,14.9],[3.7,14],[3.7,11.0]]){
   await expect.poll(async()=>{const p=(await state(page)).position;await qa(page,{op:'look',yaw:Math.atan2(p[0]-x,p[2]-z)});return Math.hypot(p[0]-x,p[2]-z);},{timeout:16000,intervals:[70]}).toBeLessThan(.3);
  }
 }finally{await page.keyboard.up('w');}
 await page.keyboard.up('c');await expect.poll(async()=>(await state(page)).crouching).toBe(false);
 await qa(page,{op:'warp',x:-1.227433,y:.31,z:15.8,yaw:0,pitch:1.3});await page.keyboard.down('c');await page.waitForTimeout(700);
 await page.screenshot({path:join(tmpdir(),'nachtwache-v160-web-window-normal.png')});
 await qa(page,{op:'anomaly',id:'tube_watcher'});await qa(page,{op:'warp',x:-1.227433,y:.31,z:15.8,yaw:0,pitch:1.3});await page.waitForTimeout(700);
 expect((await state(page)).watcher).toBe(true);await page.screenshot({path:join(tmpdir(),'nachtwache-v160-web-window-watcher.png')});
 await page.keyboard.up('c');await qa(page,{op:'new'});expect((await state(page)).watcher).toBe(false);expect((await state(page)).anomaly).toBe('none');
});

test('annex corridor, kitchen and cinema have real open routes, persistent saves, paused ambience and a one-shot clown lunge',async({page})=>{
 test.setTimeout(150000);await begin(page);await page.mouse.click(768,512);
 await qa(page,{op:'warp',x:-7.9,z:-10.3,yaw:0});await walk(page,'w',s=>s.position[2]<-29.4);
 await qa(page,{op:'look',yaw:Math.PI/2});await walk(page,'w',s=>s.position[0]<-12);
 expect((await state(page)).visited).toContain('Küche');expect((await state(page)).anomaly).toBe('none');expect((await state(page)).annex.stirring).toBe(true);expect((await state(page)).encounter.triggered).toBe(false);
 await qa(page,{op:'warp',x:-12.2,z:-30.0,yaw:1.1,pitch:.09});await page.waitForTimeout(700);await page.screenshot({path:join(tmpdir(),'nachtwache-v170-web-kitchen.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const clock=(await state(page)).annex.clock;await page.waitForTimeout(500);expect((await state(page)).annex.clock).toBe(clock);
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).position[0]).toBeLessThan(-11.5);expect((await state(page)).position[2]).toBeLessThan(-29);
 await page.mouse.click(768,512);await qa(page,{op:'warp',x:-12,z:-29.65,yaw:-Math.PI/2});await walk(page,'w',s=>s.position[0]>1.7);
 expect((await state(page)).visited).toContain('Kino');expect((await state(page)).position[1]).toBeGreaterThan(-.1);expect((await state(page)).encounter.triggered).toBe(false);
 await qa(page,{op:'warp',x:-4.6,z:-29.65,yaw:-Math.PI/2,pitch:.1});await page.waitForTimeout(700);await page.screenshot({path:join(tmpdir(),'nachtwache-v170-web-cinema.png')});
 await qa(page,{op:'anomaly',id:'clown_lunge'});await qa(page,{op:'warp',x:-12.2,z:-30.0,yaw:-2,pitch:.09});await page.waitForTimeout(1400);expect((await state(page)).encounter.triggered).toBe(false);
 await qa(page,{op:'look',yaw:1.1});await expect.poll(async()=>(await state(page)).encounter.triggered,{intervals:[50]}).toBe(true);
 await qa(page,{op:'pause'});const paused=(await state(page)).encounter.time;await page.waitForTimeout(400);expect((await state(page)).encounter.time).toBe(paused);
 await qa(page,{op:'resume'});await expect.poll(async()=>(await state(page)).encounter.finished).toBe(true);expect((await state(page)).annex.stirring).toBe(false);
 await qa(page,{op:'new'});expect((await state(page)).annex.stirring).toBe(true);expect((await state(page)).encounter.triggered).toBe(false);
});


test('detailed torch flickers briefly, freezes on pause and normal kitchen atmosphere has six extra recordings',async({page})=>{
 await begin(page);expect((await state(page)).ambience.bed_count).toBe(6);expect((await state(page)).ambience.event_count).toBe(11);
 await qa(page,{op:'flicker'});await expect.poll(async()=>(await state(page)).flashlight.count).toBe(1);await expect.poll(async()=>(await state(page)).flashlight.strength,{intervals:[20]}).toBeLessThan(1);
 await qa(page,{op:'pause'});const clock=(await state(page)).flashlight.clock;await page.waitForTimeout(400);expect((await state(page)).flashlight.clock).toBe(clock);
 await qa(page,{op:'resume'});await expect.poll(async()=>(await state(page)).flashlight.strength,{timeout:3000}).toBe(1);
 await page.mouse.click(768,512);
 for(const shot of [{name:'clown-front',x:-12.4,z:-31.25,yaw:Math.PI/2,pitch:.1},{name:'clown-profile',x:-14.4,z:-29.5,yaw:0,pitch:.14},{name:'reception',x:-9.65,z:5.2,yaw:-1.87,pitch:-.32}]){await qa(page,{op:'warp',...shot});await page.waitForTimeout(550);await page.screenshot({path:join(tmpdir(),'nachtwache-v180-web-'+shot.name+'.png')});}
});

test('play-frame ramp allows standing entry and exit in the centre and near both edges',async({page})=>{
 test.setTimeout(90000);await begin(page);
 for(const offset of [-.4,0,.4]){
  await qa(page,{op:'warp',x:-1.57,y:.403,z:(-1+offset)*1.12,yaw:Math.PI/2});await page.mouse.click(768,512);
  await walk(page,'w',s=>s.position[0]<-4.2);await expect.poll(async()=>(await state(page)).grounded).toBe(true);expect((await state(page)).position[1]).toBeLessThan(.06);
  await qa(page,{op:'warp',x:-3.985,y:0,z:(-1+offset)*1.12,yaw:-Math.PI/2});await walk(page,'w',s=>s.position[0]>-.8);expect((await state(page)).position[1]).toBeGreaterThan(.32);
 }
 await qa(page,{op:'warp',x:-4.8,z:-1.12,yaw:-Math.PI/2,pitch:-.09});await page.waitForTimeout(400);await page.screenshot({path:join(tmpdir(),'nachtwache-v193-web-entry.png')});
});

test('phantom footsteps travel through empty aisles and pause without changing the anomaly',async({page})=>{
 test.setTimeout(60000);await begin(page);const initial=(await state(page)).anomaly;
 await expect.poll(async()=>(await state(page)).ambience.ghost_playing,{timeout:18000,intervals:[100]}).toBe(true);
 const before=(await state(page)).ambience;await page.waitForTimeout(600);const after=(await state(page)).ambience;
 expect(Math.hypot(...after.ghost_position.map((v,i)=>v-before.ghost_position[i]))).toBeGreaterThan(.1);expect(after.ghost_track).toBe('ghost-walk.wav');expect((await state(page)).anomaly).toBe(initial);
 await page.keyboard.press('Escape');await page.waitForTimeout(300);const paused=(await state(page)).ambience;expect(paused.ghost_paused).toBe(true);await page.waitForTimeout(400);expect((await state(page)).ambience.ghost_clock).toBe(paused.ghost_clock);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).ambience.ghost_paused).toBe(false);
 for(const shot of [{name:'clown-front',x:-12.4,z:-31.25,yaw:Math.PI/2,pitch:.07},{name:'hand',x:-12.2,z:-30.9,yaw:1.43,pitch:-.25}]){
  await qa(page,{op:'warp',...shot});await page.waitForTimeout(500);await page.screenshot({path:join(tmpdir(),'nachtwache-v193-web-'+shot.name+'.png')});
 }
});

test('music box plays its recording, ceiling creature is shared, bulbs flicker and all pause together',async({page})=>{
 test.setTimeout(90000);await begin(page);
 await expect.poll(async()=>(await state(page)).room_horror.music).toBe(true);
 const room=(await state(page)).room_horror;expect(room.track).toBe('res://assets/party/musicbox.mp3');expect(room.creature).toBe(true);expect(room.panels).toBeGreaterThan(100);expect(room.creature_geometry.width).toBeLessThan(.8);expect(room.creature_geometry.rear).toBeGreaterThan(-.3);expect(room.creature_geometry.top).toBeGreaterThan(.85);expect(room.shaft_depth).toBeGreaterThan(1);
 await expect.poll(async()=>Math.min(...(await state(page)).room_horror.bulbs),{timeout:15000,intervals:[70]}).toBeLessThan(.5);
 await page.keyboard.press('Escape');await page.waitForTimeout(300);const frozen=(await state(page)).room_horror;expect(frozen.paused).toBe(true);await page.waitForTimeout(400);expect((await state(page)).room_horror.clock).toBe(frozen.clock);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).room_horror.paused).toBe(false);
 for(const shot of [{name:'music-box',x:17.85,z:-2.42,yaw:-Math.PI/2,pitch:-.16},{name:'kitchen-ceiling',x:-11.2,z:-28.5,yaw:.6,pitch:.6},{name:'cinema-creature',x:-4.5,z:-29.6,yaw:-.983,pitch:.345}]){
  await qa(page,{op:'warp',...shot});await page.waitForTimeout(550);await page.screenshot({path:join(tmpdir(),'nachtwache-v194-web-'+shot.name+'.png')});
 }
});

test('lift intro accepts the chief call, pauses, resumes from a pending save and opens a walkable exit after hang-up',async({page})=>{
 test.setTimeout(150000);await load(page);await clickControl(page,'Neue Nachtschicht');await expect.poll(async()=>(await state(page)).phase).toBe('intro');
 await page.keyboard.press('Space');await page.waitForTimeout(150);expect((await state(page)).phase).toBe('intro');
 await page.waitForTimeout(1400);await page.screenshot({path:join(tmpdir(),'nachtwache-v190-web-intro-ringing.png')});
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).intro.stage).toBe('call');
 const call=(await state(page)).intro;console.log('Chief call recording',call);if(call.recording){expect(call.duration).toBeGreaterThan(1);expect(call.voice_playing).toBe(true);expect(call.caption).toBe('');}
 await page.keyboard.press('Escape');const clock=(await state(page)).intro.clock;await page.waitForTimeout(500);expect((await state(page)).intro.clock).toBe(clock);if(call.recording)expect((await state(page)).intro.voice_paused).toBe(true);
 await page.keyboard.press('Escape');await page.screenshot({path:join(tmpdir(),'nachtwache-v190-web-intro-call.png')});
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('intro');expect((await state(page)).intro.stage).toBe('ringing');
 await page.waitForTimeout(1300);await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).intro.stage).toBe('call');
 await page.mouse.move(768,512);await expect.poll(async()=>(await state(page)).phase,{timeout:60000,intervals:[200]}).toBe('play');expect((await state(page)).position[2]).toBeGreaterThan(17);
 await page.mouse.click(768,512);await page.waitForTimeout(200);expect(Math.abs((await state(page)).yaw)).toBeLessThan(.02);await walk(page,'w',s=>s.position[2]<16.5);expect((await state(page)).position[1]).toBeGreaterThan(-.1);
 await page.screenshot({path:join(tmpdir(),'nachtwache-v190-web-left-lift.png')});
 await qa(page,{op:'audit'});expect((await state(page)).layout.wall_intersections).toEqual([]);
 for(const shot of [{name:'shelves',x:-7.3,z:2.1,yaw:Math.PI/2,pitch:-.07},{name:'party-wall',x:15.5,z:-4,yaw:-Math.PI/2,pitch:.1},{name:'kitchen',x:-11.5,z:-29.0,yaw:1,pitch:.05}]){await qa(page,{op:'warp',...shot});await page.waitForTimeout(550);await page.screenshot({path:join(tmpdir(),'nachtwache-v190-web-'+shot.name+'.png')});}
});


test('new menu settings drive FOV and audio, and the fake jumpscare switch scares once without altering the patrol',async({page})=>{
 test.setTimeout(90000);await begin(page);await page.keyboard.press('Escape');await qa(page,{op:'menu'});await page.waitForTimeout(300);await page.screenshot({path:join(tmpdir(),'nachtwache-v194-web-menu.png')});
 const before=await state(page);await clickControl(page,'Einstellungen');await clickControl(page,'Audio');await clickControl(page,'Lautstärke');await page.keyboard.press('Home');await expect.poll(async()=>(await state(page)).volume).toBe(0);
 await clickControl(page,'Bild');await clickControl(page,'Sichtfeld');await page.keyboard.press('End');await expect.poll(async()=>(await state(page)).settings.fov).toBe(100);
 await clickControl(page,'Spiel');await page.screenshot({path:join(tmpdir(),'nachtwache-v194-web-settings.png')});const options=(await state(page)).settings;
 await clickControl(page,'Jumpscares  Off / On');await expect.poll(async()=>(await state(page)).phase,{intervals:[30]}).toBe('menu_scare');await page.waitForTimeout(200);await page.screenshot({path:join(tmpdir(),'nachtwache-v194-web-menu-scare.png')});
 await expect.poll(async()=>(await state(page)).phase).toBe('settings');const after=await state(page);expect(after.settings_tab).toBe('Spiel');expect(after.menu_prank.count).toBe(1);expect(after.menu_prank.running).toBe(false);expect(after.settings).toEqual(options);expect(after.streak).toBe(before.streak);expect(after.rounds).toBe(before.rounds);expect(after.anomaly).toBe(before.anomaly);expect(after.menu_prank.gain).toBeLessThan(-70);
 await clickControl(page,'Zurück');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).camera_fov).toBe(100);
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');expect((await state(page)).settings.fov).toBe(100);expect((await state(page)).volume).toBe(0);expect((await state(page)).menu_prank.count).toBe(0);
});

test('After Play newspapers follow rounds 3/5/8/11, TAB reads them, saves retain them, the 6428 archive is walkable and death resets it',async({page})=>{
 test.setTimeout(180000);await begin(page);
 const snapshot=()=>state(page);
 async function lookAt(position,target,eye=1.65){const dx=target[0]-position[0],dy=target[1]-position[1]-eye,dz=target[2]-position[2];await qa(page,{op:'warp',x:position[0],y:position[1],z:position[2],yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(dy,Math.hypot(dx,dz))});}
 async function take(id,position,eye=1.65){const spawn=(await snapshot()).archive.spawned.find(s=>s.id===id);expect(spawn).toBeTruthy();await lookAt(position,spawn.position,eye);await expect.poll(async()=>(await snapshot()).target).toBe('paper:'+id);await page.keyboard.press('e');await expect.poll(async()=>(await snapshot()).archive.collected).toContain(id);expect((await snapshot()).archive.spawned.some(s=>s.id===id)).toBe(false);}
 expect((await snapshot()).archive.stage).toBe(1);expect((await snapshot()).archive.spawned.map(s=>s.id)).toEqual(['note']);
 await take('note',[-8.1,0,-9.9]);await page.keyboard.press('Tab');await expect.poll(async()=>(await snapshot()).phase).toBe('inventory');expect((await snapshot()).archive_reader).toBe('note');
 const paused=await snapshot();await page.keyboard.down('w');await page.waitForTimeout(300);await page.keyboard.up('w');expect((await snapshot()).position).toEqual(paused.position);expect((await snapshot()).room_horror.clock).toBe(paused.room_horror.clock);await page.screenshot({path:join(tmpdir(),'after-play-web-note-reader.png')});await page.keyboard.press('Tab');await expect.poll(async()=>(await snapshot()).phase).toBe('play');
 await lookAt([-8.6,0,-9.9],[-10.1,1.3,-9.9]);await expect.poll(async()=>(await snapshot()).target).toBe('archive_door');await page.keyboard.press('e');await expect.poll(async()=>(await snapshot()).phase).toBe('code');
 await page.keyboard.type('6428');await page.keyboard.press('Enter');await page.waitForTimeout(150);expect((await snapshot()).archive.unlocked).toBe(false);expect((await snapshot()).phase).toBe('code');await page.keyboard.press('Control+a');await page.keyboard.press('Backspace');await page.keyboard.type('64');await page.keyboard.press('Tab');await expect.poll(async()=>(await snapshot()).phase).toBe('inventory');await page.keyboard.press('Tab');await expect.poll(async()=>(await snapshot()).phase).toBe('code');expect((await snapshot()).archive_input).toBe('64');await page.keyboard.press('Escape');await expect.poll(async()=>(await snapshot()).phase).toBe('play');
 const schedule=[{id:'opening',stage:3,p:[10.2,0,-4.6]},{id:'missing',stage:5,p:[.9,0,-19.9]},{id:'coverup',stage:8,p:[-11.75,0,-18.45]},{id:'closure',stage:11,p:[-.977433,.31,15.8]}];
 for(const paper of schedule){
  while((await snapshot()).archive.stage<paper.stage){const before=await snapshot();await qa(page,{op:'choose',red:before.anomaly!=='none'});await expect.poll(async()=>(await snapshot()).archive.stage,{timeout:12000}).toBe(before.archive.stage+1);await expect.poll(async()=>(await snapshot()).phase).toBe('play');}
  const safeRound=await snapshot();expect(safeRound.anomaly).toBe('none');expect(safeRound.terrors.id).toBe('none');expect(safeRound.encounter.triggered).toBe(false);expect(safeRound.failure.running).toBe(false);expect(safeRound.annex.stirring).toBe(true);
  const available=safeRound.archive.spawned.filter(s=>s.id!=='note').map(s=>s.id);expect(available).toEqual([paper.id]);
  if(paper.id==='closure'){await page.keyboard.down('c');await expect.poll(async()=>(await snapshot()).crouching).toBe(true);}
  await take(paper.id,paper.p,paper.id==='closure'?.8:1.65);expect((await snapshot()).anomaly).toBe('none');
  if(paper.id==='closure')await page.keyboard.up('c');
  await page.keyboard.press('Tab');await expect.poll(async()=>(await snapshot()).phase).toBe('inventory');expect((await snapshot()).archive_reader).toBe(paper.id);await page.screenshot({path:join(tmpdir(),'after-play-web-reader-'+paper.id+'.png')});await page.keyboard.press('Escape');await expect.poll(async()=>(await snapshot()).phase).toBe('play');
  if(paper.id==='opening'){await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).archive.collected).toEqual(['note','opening']);expect((await snapshot()).archive.stage).toBe(3);expect((await snapshot()).anomaly).toBe('none');expect((await snapshot()).archive.spawned).toEqual([]);}
 }
 await lookAt([-8.6,0,-9.9],[-10.1,1.3,-9.9]);await expect.poll(async()=>(await snapshot()).target).toBe('archive_door');await page.keyboard.press('e');await expect.poll(async()=>(await snapshot()).phase).toBe('code');await page.keyboard.press('Control+a');await page.keyboard.type('7428');await expect.poll(async()=>(await snapshot()).archive_input).toBe('7428');await page.keyboard.press('Enter');await page.waitForTimeout(150);expect((await snapshot()).archive.unlocked).toBe(false);
 await page.keyboard.press('Control+a');await page.keyboard.type('6428');await expect.poll(async()=>(await snapshot()).archive_input).toBe('6428');await page.keyboard.press('Enter');await expect.poll(async()=>(await snapshot()).phase).toBe('play');await expect.poll(async()=>(await snapshot()).archive.angle).toBeLessThan(-1.7);
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2});await walk(page,'w',s=>s.position[0]<-11.5);await page.keyboard.press('Escape');await expect.poll(async()=>(await snapshot()).phase).toBe('pause');await page.waitForTimeout(300);await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).archive.unlocked).toBe(true);expect((await snapshot()).position[0]).toBeLessThan(-11.5);
 await take('casefile',[-13.8,0,-9.05]);await page.keyboard.press('Tab');await expect.poll(async()=>(await snapshot()).phase).toBe('inventory');expect((await snapshot()).archive_reader).toBe('casefile');await page.screenshot({path:join(tmpdir(),'after-play-web-archive-record.png')});await page.keyboard.press('Escape');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).streak).toBe(10);
 await qa(page,{op:'warp',x:-12.8,z:-9.9,yaw:-Math.PI/2});await walk(page,'w',s=>s.position[0]>-9.8);
 const current=await snapshot();await qa(page,{op:'choose',red:current.anomaly==='none'});await expect.poll(async()=>(await snapshot()).phase,{timeout:15000}).toBe('play');expect((await snapshot()).archive.collected).toEqual([]);expect((await snapshot()).archive.unlocked).toBe(false);expect((await snapshot()).archive.stage).toBe(1);
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).archive.collected).toEqual([]);expect((await snapshot()).archive.spawned.map(s=>s.id)).toEqual(['note']);
});

test('new visitors pursue once, freeze with their sounds in TAB and pause, respect walls, and all tube figures disappear outside',async({page})=>{
 test.setTimeout(180000);await begin(page);
 expect((await state(page)).terrors.id).toBe('none');expect((await state(page)).terrors.visible).toBe(false);
 async function aim(position,target,eye=1.65){const dx=target[0]-position[0],dy=target[1]-position[1]-eye,dz=target[2]-position[2];await qa(page,{op:'warp',x:position[0],y:position[1],z:position[2],yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(dy,Math.hypot(dx,dz))});}
 await qa(page,{op:'anomaly',id:'service_pursuit'});await aim([-6.5,0,-4],[-7.7,1.65,-8.1]);
 await expect.poll(async()=>(await state(page)).terrors.triggered).toBe(true);
 const start=(await state(page)).terrors.position;await expect.poll(async()=>Math.hypot(...(await state(page)).terrors.position.map((v,i)=>v-start[i]))).toBeGreaterThan(.3);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const paused=(await state(page)).terrors;await page.waitForTimeout(450);expect((await state(page)).terrors.attack).toBe(paused.attack);expect((await state(page)).terrors.position).toEqual(paused.position);expect(!paused.audio||paused.paused).toBe(true);expect(!paused.steps||paused.steps_paused).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).phase).toBe('inventory');const reading=(await state(page)).terrors.attack;await page.waitForTimeout(300);expect((await state(page)).terrors.attack).toBe(reading);await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await expect.poll(async()=>(await state(page)).terrors.finished,{timeout:10000}).toBe(true);const ended=(await state(page)).terrors.attack;await page.waitForTimeout(500);expect((await state(page)).terrors.attack).toBe(ended);expect((await state(page)).terrors.remnant).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v21-web-visitor.png')});
 await qa(page,{op:'anomaly',id:'tube_watcher'});await qa(page,{op:'warp',x:-1.227433,y:.31,z:15.8,yaw:0,pitch:1.3});await page.keyboard.down('c');await expect.poll(async()=>(await state(page)).watcher).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v21-web-watcher-inside.png')});await page.keyboard.up('c');await qa(page,{op:'warp',x:-1.2,y:0,z:12.2,yaw:0,pitch:.6});await expect.poll(async()=>(await state(page)).watcher).toBe(false);await page.screenshot({path:join(tmpdir(),'after-play-v21-web-watcher-outside.png')});
 for(const id of ['tube_chase','tube_window_hands']){await qa(page,{op:'anomaly',id});await qa(page,{op:'warp',x:-1.227433,y:.31,z:15.8,yaw:0,pitch:0});await page.keyboard.down('c');await expect.poll(async()=>(await state(page)).terrors.visible).toBe(true);await page.keyboard.up('c');await qa(page,{op:'warp',x:-1.2,y:0,z:12.2,yaw:0,pitch:0});await expect.poll(async()=>(await state(page)).terrors.visible).toBe(false);}
 await qa(page,{op:'anomaly',id:'none'});expect((await state(page)).terrors.id).toBe('none');expect((await state(page)).terrors.visible).toBe(false);
 await aim([13.3,0,-4.4],[13.3,2.6,1.485]);await page.waitForTimeout(500);await page.screenshot({path:join(tmpdir(),'after-play-v21-web-fresco.png')});
});

test('server room has a walkable threshold in both directions and continues from its saved interior',async({page})=>{
 test.setTimeout(120000);await begin(page);
 await qa(page,{op:'warp',x:-8.7,z:-5.4,yaw:Math.PI/2,pitch:0});
 await walk(page,'w',s=>s.position[0]<-12.1);const inside=(await state(page)).position;
 await page.screenshot({path:join(tmpdir(),'after-play-v21-web-server-room.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).position[0]).toBeLessThan(-12);expect(Math.abs((await state(page)).position[2]-inside[2])).toBeLessThan(.1);
 await qa(page,{op:'warp',x:-12.1,z:-5.4,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>-9.6);
 for(const shot of [{name:'croc-body',x:17.8,z:15.9,yaw:.83,pitch:-.04},{name:'kitchen-sink',x:-15.25,z:-28.1,yaw:1.19,pitch:-.36},{name:'ball-pit',x:.2,z:10.7,yaw:-.2,pitch:-.31}]){await qa(page,{op:'warp',...shot});await page.waitForTimeout(550);await page.screenshot({path:join(tmpdir(),'after-play-v21-web-'+shot.name+'.png')});}
});

test('0712 opens the archive immediately; E plays Marelle, reload resumes it and turning back after its end reveals the chef and credits',async({page})=>{
 test.setTimeout(180000);await begin(page);
 async function aim(position,target){const dx=target[0]-position[0],dy=target[1]-position[1]-1.65,dz=target[2]-position[2];await qa(page,{op:'warp',x:position[0],y:position[1],z:position[2],yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(dy,Math.hypot(dx,dz))});}
 expect((await state(page)).archive.collected).toEqual([]);
 await aim([-8.7,0,-9.9],[-10.2,1.3,-9.9]);await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('code');
 await page.keyboard.type('6428',{delay:25});await expect.poll(async()=>(await state(page)).archive_input).toBe('6428');await page.keyboard.press('Enter');expect((await state(page)).archive.unlocked).toBe(false);
 await page.mouse.click(275,220);await page.keyboard.press('Control+a');await page.keyboard.type('0712',{delay:25});await expect.poll(async()=>(await state(page)).archive_input).toBe('0712');await page.keyboard.press('Enter');await expect.poll(async()=>(await state(page)).phase).toBe('play');await expect.poll(async()=>(await state(page)).archive.angle).toBeLessThan(-1.7);
 expect((await state(page)).archive.creator_access).toBe(true);expect((await state(page)).archive.collected).toEqual([]);
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2});await walk(page,'w',s=>s.position[0]<-11.4);
 await aim([-11.3,0,-9.9],[-12.1,.11,-9.55]);await expect.poll(async()=>(await state(page)).target).toBe('archive_recording');await page.screenshot({path:join(tmpdir(),'after-play-v220-web-recorder.png')});await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).archive.finale.state).toBe('recording');expect((await state(page)).archive.finale.duration).toBeGreaterThan(279);expect((await state(page)).archive.finale.playing).toBe(true);
 expect((await state(page)).archive.recording_locked).toBe(true);expect((await state(page)).archive.angle).toBe(0);
 await qa(page,{op:'warp',x:-11.05,z:-9.9,yaw:-Math.PI/2,pitch:0});await expect.poll(async()=>(await state(page)).memories.visible).toBe(true);const cutscenePose=(await state(page)).position;
 await page.keyboard.down('w');await page.waitForTimeout(450);await page.keyboard.up('w');expect((await state(page)).position).toEqual(cutscenePose);expect((await state(page)).position[0]).toBeLessThan(-10.45);
 await expect.poll(async()=>(await state(page)).target).toBe('archive_door');await page.keyboard.press('e');expect((await state(page)).phase).toBe('play');expect((await state(page)).archive.target_angle).toBe(0);
 await page.keyboard.down('c');await page.keyboard.down('w');await page.waitForTimeout(400);await page.keyboard.up('w');await page.keyboard.up('c');expect((await state(page)).position[0]).toBeLessThan(-10.45);
 await page.keyboard.press('Space');await page.keyboard.down('w');await page.waitForTimeout(550);await page.keyboard.up('w');expect((await state(page)).position[0]).toBeLessThan(-10.45);
 await page.screenshot({path:join(tmpdir(),'after-play-v222-web-locked-door.png')});await aim([-11.3,0,-9.9],[-12.1,.11,-9.55]);

 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const at=(await state(page)).archive.finale.position;await page.waitForTimeout(400);expect((await state(page)).archive.finale.position).toBe(at);expect((await state(page)).archive.finale.paused).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');await qa(page,{op:'recording_seek',time:117});await expect.poll(async()=>(await state(page)).archive.finale.position).toBeGreaterThan(117);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');expect(await page.evaluate(()=>JSON.parse(localStorage.getItem('after-play:qa-nachtwache-save.json')).archive.recording_position)).toBeGreaterThan(117);await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).archive.creator_access).toBe(true);await expect.poll(async()=>(await state(page)).archive.finale.position).toBeGreaterThan(117);expect((await state(page)).archive.finale.position).toBeLessThan(123);expect((await state(page)).archive.recording_locked).toBe(true);expect((await state(page)).archive.angle).toBe(0);
 await aim([-11.3,0,-9.9],[-10.2,1.5,-9.9]);await qa(page,{op:'recording_seek',time:(await state(page)).archive.finale.duration-.12});await expect.poll(async()=>(await state(page)).archive.finale.state).toBe('armed');expect((await state(page)).phase).toBe('play');expect((await state(page)).archive.recording_locked).toBe(false);await expect.poll(async()=>(await state(page)).archive.angle).toBeLessThan(-1.7);
 await aim([-11.3,0,-9.9],[-14,1.3,-9.9]);await expect.poll(async()=>(await state(page)).archive.finale.looked_away).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v220-web-remains.png')});
 await aim([-11.3,0,-9.9],[-10.2,1.5,-9.9]);await expect.poll(async()=>(await state(page)).phase,{intervals:[20]}).toBe('archive_scare');await page.waitForTimeout(180);await page.screenshot({path:join(tmpdir(),'after-play-v220-web-chef-scare.png')});
 await expect.poll(async()=>(await state(page)).phase).toBe('ending');await expect.poll(async()=>(await state(page)).ending_credits.end_word).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v220-web-ende.png')});
 expect((await state(page)).ending_credits.title).toBe('ENDE 2/2');expect((await state(page)).ending_credits.second_end_hint).toBe('');
 expect((await state(page)).archive.finale.triggers).toBe(1);await expect.poll(async()=>(await state(page)).ending_credits.stage).toBe('credits');await expect.poll(async()=>(await state(page)).ending_credits.music).toBe(true);const credits=(await state(page)).ending_credits;expect(credits.music_track).toBe('res://assets/party/musicbox.mp3');expect(credits.author).toBe('Kyoko');expect(credits.ideas).toBe('einsmarello');expect(credits.testers).toEqual(['einsmarello','__jerry__','gingerbread','Mozart']);
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:10000}).toBe('last_look');}finally{await page.keyboard.up('Space');}
 await expect.poll(async()=>(await state(page)).ending_credits.afterglow.clock,{timeout:10000}).toBeGreaterThan(2.5);
 expect((await state(page)).ending_credits.music).toBe(true);expect((await state(page)).life.hum).toBe(false);
 await page.screenshot({path:join(tmpdir(),'after-play-v2110-web-last-look.png')});
 await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:25000}).toBe(true);expect((await state(page)).ending_credits.music).toBe(false);
 await clickControl(page,'Hauptmenü');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('ending');expect((await state(page)).archive.finale.triggers).toBe(0);
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('ending');expect((await state(page)).archive.finale.triggers).toBe(0);
});


test('v2.6 exact Dienstanweisung, party-only mascot and manufactured kitchen render without blocked doors',async({page})=>{
 test.setTimeout(90000);await load(page);await clickControl(page,'Dienstanweisung');await expect.poll(async()=>(await state(page)).phase).toBe('help');
 const copy=(await state(page)).instructions.join('\n');expect(copy).toContain('13 Rundgänge. 13 mal der gleiche Raum...oder?...');expect(copy).toContain('Geräusche und vom Spieler selbst verschobene Gegenstände zählen natürlich nicht zu den Anomalien.');expect(copy).toContain('Sterueung');expect(copy).toContain('E: interagieren');expect(copy).toContain('F11: Vollbild');expect(copy).not.toContain('Küchenclown');expect(copy).not.toContain('Normal:');
 await page.screenshot({path:join(tmpdir(),'after-play-v260-instructions-web.png')});await clickControl(page,'Zurück');await clickControl(page,'Neue Nachtschicht');await skipIntro(page);expect((await state(page)).giant_mascots).toBe(1);
 await qa(page,{op:'warp',x:-10.5,z:-29.3,yaw:1.3,pitch:-.1});await page.waitForTimeout(500);await page.screenshot({path:join(tmpdir(),'after-play-v260-kitchen-web.png')});
 await qa(page,{op:'audit'});const audit=(await state(page)).layout;expect(audit.door_obstructions).toEqual([]);expect(audit.art_overlaps).toEqual([]);expect(audit.furniture_wall_intrusions).toEqual([]);
 await qa(page,{op:'anomaly',id:'cinema_aisle_rush'});await qa(page,{op:'warp',x:-1,z:-29.65,yaw:-Math.PI/2,pitch:-.1});
 await expect.poll(async()=>(await state(page)).terrors.triggered).toBe(true);expect((await state(page)).terrors.sound).toContain('/scares-v260/bass-roar.wav');
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const scare=(await state(page)).terrors;await page.waitForTimeout(350);expect((await state(page)).terrors.position).toEqual(scare.position);expect((await state(page)).terrors.attack).toBe(scare.attack);expect(!scare.audio||scare.paused).toBe(true);
});


test('v2.9 environmental dressing has solid arcade cabinets, stable reference rooms, paused CRTs and a working green-door trip',async({page})=>{
 test.setTimeout(120000);await begin(page);await page.mouse.click(768,512);
 expect((await state(page)).details.groups).toBeGreaterThanOrEqual(17);expect((await state(page)).details.screens).toBe(2);
 await qa(page,{op:'warp',x:7.5,z:14.6,yaw:Math.PI,pitch:0});
 await page.keyboard.down('w');try{await page.waitForTimeout(1800);}finally{await page.keyboard.up('w');}
 const p=(await state(page)).position;expect(p[2]).toBeGreaterThan(15.2);expect(p[2]).toBeLessThan(16.3);
 await page.screenshot({path:join(tmpdir(),'after-play-v290-web-arcade.png')});
 await qa(page,{op:'pause'});const frozen=(await state(page)).details.clock;await page.waitForTimeout(350);expect((await state(page)).details.clock).toBe(frozen);
 await qa(page,{op:'resume'});await expect.poll(async()=>(await state(page)).details.clock).toBeGreaterThan(frozen);
 for(const shot of [{name:'lost-property',x:1.8,z:-8,yaw:0,pitch:.12},{name:'birthday',x:11.4,z:-4,yaw:.38,pitch:.15}]){
  await qa(page,{op:'warp',...shot});await page.waitForTimeout(250);await page.screenshot({path:join(tmpdir(),'after-play-v290-web-'+shot.name+'.png')});
 }
 await qa(page,{op:'audit'});const layout=(await state(page)).layout;expect(layout.door_obstructions).toEqual([]);expect(layout.furniture_wall_intrusions).toEqual([]);
 await doorTrip(page,false);expect((await state(page)).streak).toBe(1);expect((await state(page)).details.groups).toBeGreaterThanOrEqual(17);
 await qa(page,{op:'anomaly',id:'none'});
 await page.evaluate(()=>{window.nachtwacheQA(JSON.stringify({op:'warp',x:7.5,z:16.4,yaw:0}));window.nachtwacheQA(JSON.stringify({op:'pause'}));});
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');
 const continued=await state(page);expect(continued.streak).toBe(1);expect(continued.position[0]).toBeCloseTo(-6.2,1);expect(continued.position[2]).toBeCloseTo(8.5,1);

});

test('cinema aisles are walkable forwards and backwards without seat snags',async({page})=>{
 test.setTimeout(150000);await begin(page);
 for(const x of [-5.15,-3.55,-.55]){
  await qa(page,{op:'warp',x,z:-26.0,yaw:0,pitch:0});
  await walk(page,'w',s=>s.position[2]<-33.6);
  expect((await state(page)).position[0]).toBeCloseTo(x,1);
  await walk(page,'s',s=>s.position[2]>-26.2);
  expect((await state(page)).position[0]).toBeCloseTo(x,1);
 }
 await qa(page,{op:'warp',x:-5.15,z:-29.7,yaw:-Math.PI/2,pitch:0});
 await walk(page,'w',s=>s.position[0]>1.2);await walk(page,'s',s=>s.position[0]<-5.0);
 await page.screenshot({path:join(tmpdir(),'after-play-v2100-web-cinema-aisle.png')});
});

test('Happyland film can be collected, projected with synchronized sound, paused, replayed and retained across rounds',async({page})=>{
 test.setTimeout(150000);await begin(page);
 const aim=async(x,z,tx,ty,tz)=>qa(page,{op:'warp',x,z,yaw:Math.atan2(-(tx-x),-(tz-z)),pitch:Math.atan2(ty-1.65,Math.hypot(tx-x,tz-z))});
 expect((await state(page)).film.owned).toBe(false);
 await aim(-5.15,-26.1,-5.88,.92,-26.27);await expect.poll(async()=>(await state(page)).target).toBe('film_reel');await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).film.owned).toBe(true);
 await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).phase).toBe('inventory');await page.keyboard.press('Escape');
 await aim(-5.05,-27.83,-6.17,1.27,-27.83);await expect.poll(async()=>(await state(page)).target).toBe('cinema_projector');await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).film.position,{timeout:10000}).toBeGreaterThan(1);
 let film=(await state(page)).film;expect(film.playing&&film.screen).toBe(true);expect(Math.abs(film.position-film.audio_position)).toBeLessThan(.35);
 await aim(-2.8,-29.7,3.48,1.9,-29.7);await page.waitForTimeout(1400);await page.screenshot({path:join(tmpdir(),'after-play-v2100-web-film.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');await page.waitForTimeout(100);
 const before=(await state(page)).film.position;await page.waitForTimeout(400);film=(await state(page)).film;expect(Math.abs(film.position-before)).toBeLessThan(.05);expect(film.audio_paused).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).film.position).toBeGreaterThan(before+.2);
 await expect.poll(async()=>(await state(page)).film.playing,{timeout:45000,intervals:[250]}).toBe(false);
 expect((await state(page)).film.screen).toBe(false);expect((await state(page)).anomaly).toBe('none');
 await aim(-5.05,-27.83,-6.17,1.27,-27.83);await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).film.playing).toBe(true);
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).film.playing).toBe(false);
 await qa(page,{op:'pause'});await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');expect((await state(page)).film.owned).toBe(true);
 await qa(page,{op:'anomaly',id:'none'});expect((await state(page)).film.owned).toBe(true);expect((await state(page)).film.playing).toBe(false);
 await qa(page,{op:'audit'});expect((await state(page)).layout.door_obstructions).toEqual([]);expect((await state(page)).layout.art_overlaps).toEqual([]);
});

test('washroom is walkable and saved; ordinary ambience pauses and the corrected booth photo can be inspected',async({page})=>{
 test.setTimeout(150000);await begin(page);
 await qa(page,{op:'warp',x:18.3,z:7.8,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>21.2);
 expect((await state(page)).position[2]).toBeCloseTo(7.8,1);expect((await state(page)).anomaly).toBe('none');
 await page.keyboard.press('Escape');await page.waitForTimeout(100);const stopped=(await state(page)).life.clock;
 await page.waitForTimeout(400);expect((await state(page)).life.clock).toBe(stopped);expect((await state(page)).life.paused).toBe(true);
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='menu');await clickControl(page,'Schicht fortsetzen');
 expect((await state(page)).position[0]).toBeGreaterThan(21.1);expect((await state(page)).position[2]).toBeCloseTo(7.8,1);
 await page.screenshot({path:join(tmpdir(),'after-play-v2110-web-washroom.png')});await walk(page,'s',s=>s.position[0]<18.5);
 await qa(page,{op:'warp',x:25.7,z:6.8,yaw:Math.PI,pitch:0});await expect.poll(async()=>(await state(page)).target).toBe('life:locked_wc');
 await page.keyboard.press('e');expect((await state(page)).phase).toBe('play');await page.keyboard.down('w');await page.waitForTimeout(900);await page.keyboard.up('w');expect((await state(page)).position[2]).toBeLessThan(7.73);
 await expect.poll(async()=>(await state(page)).life.compressors,{timeout:10000}).toBeGreaterThan(0);expect((await state(page)).life.drips).toBeGreaterThan(0);
 const pitch=Math.atan2(.548-1.65,16.32-14.95);
 await qa(page,{op:'warp',x:12.69,z:14.95,yaw:Math.PI,pitch});await expect.poll(async()=>(await state(page)).target).toBe('life:photo');
 await page.screenshot({path:join(tmpdir(),'after-play-v2110-web-booth.png')});await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('help');
 expect((await state(page)).controls.some(c=>c.text==='Zurück zum Rundgang')).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v2110-web-photo-reader.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).anomaly).toBe('none');expect((await state(page)).streak).toBe(0);
 await qa(page,{op:'audit'});expect((await state(page)).layout.door_obstructions).toEqual([]);expect((await state(page)).layout.art_overlaps).toEqual([]);expect((await state(page)).layout.furniture_wall_intrusions).toEqual([]);
});
