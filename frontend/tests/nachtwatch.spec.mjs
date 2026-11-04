import {test,expect} from '@playwright/test';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
const URL=process.env.NACHTWACHE_QA_URL;
test.skip(!URL,'Set NACHTWACHE_QA_URL to the isolated local Godot QA export.');
if(URL&&!['127.0.0.1','localhost'].includes(new globalThis.URL(URL).hostname))throw new Error('Godot QA must be local.');
test.use({viewport:{width:1920,height:1080},launchOptions:{args:['--enable-unsafe-swiftshader']}});
const state=page=>page.evaluate(()=>{window.nachtwacheQA?.(JSON.stringify({op:'state'}));return window.nachtwacheStatus;});
// A QA new-shift command rebuilds the actual room before publishing its intro state.
async function skipIntro(page,loadingTimeout=30000){await expect.poll(async()=>(await state(page)).phase,{timeout:loadingTimeout}).toBe('intro');await page.mouse.move(768,512);await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).phase,{timeout:8000,intervals:[70]}).toBe('play');}finally{await page.keyboard.up('Space');}}
async function qa(page,command){await page.evaluate(command=>window.nachtwacheQA(JSON.stringify(command)),command);if(command.op==='new')await skipIntro(page);}
async function clickControl(page,text){const control=(await state(page)).controls.find(c=>c.text===text);expect(control).toBeTruthy();const [x,y,w,h]=control.rect;await page.mouse.move(x+w/2,y+h/2);await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));await page.mouse.click(x+w/2,y+h/2);await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));}
async function waitForMenu(page){await page.waitForFunction(()=>['warning','menu'].includes(window.nachtwacheStatus?.phase)&&typeof window.nachtwacheQA==='function',null,{timeout:60000});if((await state(page)).phase==='warning')await clickControl(page,'Verstanden · Weiter');await expect.poll(async()=>(await state(page)).phase).toBe('menu');}
async function load(page){await page.goto(URL);await expect(page).toHaveTitle('After Play');await waitForMenu(page);const exported=await state(page);expect(exported.renderer).toBe('gl_compatibility');expect(exported.native_assets).toBe(false);expect(exported.shared_croc).toBe(true);expect(exported.presentation.logical_size).toEqual([1920,1080]);}
async function begin(page){await load(page);await clickControl(page,'Neue Nachtschicht');await skipIntro(page);await expect.poll(async()=>(await state(page)).phase).toBe('play');}
async function doorTrip(page,red,{wrong=false}={}){
 await qa(page,{op:'warp',x:red?-2.15:-4.3,z:-10.5,yaw:0,pitch:0});
 await expect.poll(async()=>(await state(page)).target).toBe(red?'red':'green');
 await page.keyboard.press('e');await walk(page,'w',s=>s.phase!=='play');
 if(!wrong)await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
}
async function walk(page,key,predicate){await page.keyboard.down(key);try{await expect.poll(async()=>predicate(await state(page)),{timeout:18000,intervals:[70]}).toBe(true);}catch(error){error.message+='\nPatrol state: '+JSON.stringify(await state(page));throw error;}finally{await page.keyboard.up(key);await page.waitForTimeout(180);}}
// QA teleports expose cold materials immediately; allow first-use shader compilation
// during the first lift trip (measured 16 s), while still asserting the full return.
const errors=[];

test('v3.9.0 memory album hides undiscovered endings and persists a real closing photo',async({page})=>{
 test.setTimeout(300000);await load(page);
 await clickControl(page,'Erinnerungsalbum');
 await expect.poll(async()=>(await state(page)).phase).toBe('help');
 expect((await state(page)).album.found).toEqual([]);
 expect((await state(page)).instructions.filter(t=>t==='Unentdecktes Ende')).toHaveLength(3);
 expect((await state(page)).instructions).not.toContain('Die Wahrheit hinter der Tür');
 await clickControl(page,'Zurück');
 await qa(page,{op:'show_ending',number:2});
 await expect.poll(async()=>(await state(page)).ending_credits.prepared,{timeout:90000}).toBe(true);
 await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:30000}).toBe('credits');
 await page.keyboard.press('Escape');
 await expect.poll(async()=>(await state(page)).album.photos,{timeout:30000}).toEqual(['2']);
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:30000}).toBe(true);}finally{await page.keyboard.up('Space');}
 await clickControl(page,'Hauptmenü');await clickControl(page,'Erinnerungsalbum');
 expect((await state(page)).instructions).toContain('Die Wahrheit hinter der Tür');
 expect((await state(page)).instructions.filter(t=>t==='Unentdecktes Ende')).toHaveLength(2);
 await page.screenshot({path:join(tmpdir(),'after-play-v390-browser-album.png')});
 await page.reload();await waitForMenu(page);await clickControl(page,'Erinnerungsalbum');
 expect((await state(page)).album).toEqual({found:['2'],photos:['2']});
 await clickControl(page,'Zurück');await clickControl(page,'Neue Nachtschicht');await skipIntro(page);
 expect((await state(page)).album.found).toEqual(['2']);
 expect((await state(page)).touch.reactions).toBe(2);
 expect((await state(page)).flashlight.energy).toBeCloseTo(4.9,1);
 expect((await state(page)).anomaly).toBe('none');
});

test('v3.8.14 creator code plays credits then a cheerful party in the original room without overlapping music',async({page})=>{
 test.setTimeout(420000);await begin(page);
 const patrol=(await state(page)).streak;
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2,pitch:-.22});
 await expect.poll(async()=>(await state(page)).target).toBe('archive_door');await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).phase).toBe('code');
 await page.mouse.click(275,220);await page.keyboard.type('07122000',{delay:25});
 await expect.poll(async()=>(await state(page)).archive_input).toBe('07122000');await page.keyboard.press('Enter');
 await expect.poll(async()=>(await state(page)).phase).toBe('ending');
 await expect.poll(async()=>(await state(page)).ending_credits.music,{timeout:30000}).toBe(true);
 console.log('Ending 1: credits music started');
 expect((await state(page)).ending_credits.title).toBe('ENDE 1/3');
 await expect.poll(async()=>(await state(page)).ending_credits.prepared,{timeout:90000}).toBe(true);
 expect((await state(page)).party.playing).toBe(false);
 console.log('Ending 1: party prepared');
 await page.keyboard.down('Space');
 try{
  await expect.poll(async()=>(await state(page)).ending_credits.afterglow.party,{timeout:15000}).toBe(true);
  await page.waitForTimeout(4000);expect((await state(page)).ending_credits.done).toBe(false);
 }finally{await page.keyboard.up('Space');}
 await expect.poll(async()=>(await state(page)).ending_credits.skip_released).toBe(true);
 const celebration=(await state(page)).ending_credits;
 expect(celebration.music).toBe(false);expect(celebration.afterglow.party_music).toBe(true);expect(celebration.afterglow.music_box).toBe(false);
 expect(celebration.afterglow.dancers).toBe(12);expect(celebration.afterglow.rabbit_cola).toBe(true);
 expect((await state(page)).party.track).toBe('Rolling Acid');
 const first=celebration.afterglow.camera_position;
 await expect.poll(async()=>(await state(page)).ending_credits.afterglow.dance_updates,{timeout:15000}).toBeGreaterThan(celebration.afterglow.dance_updates+8);
 expect((await state(page)).ending_credits.afterglow.camera_position).not.toEqual(first);
 await page.screenshot({path:join(tmpdir(),'after-play-v3814-web-celebration.png')});
 await page.waitForTimeout(200);
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:30000}).toBe(true);}catch(error){error.message+='\nParty skip: '+JSON.stringify((await state(page)).ending_credits);throw error;}finally{await page.keyboard.up('Space');}
 console.log('Ending 1: party skipped');
 expect((await state(page)).party.playing).toBe(false);
 await clickControl(page,'Hauptmenü');await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 expect((await state(page)).streak).toBe(patrol);expect((await state(page)).party.enabled).toBe(false);
 for(const number of [2,3]){
  await qa(page,{op:'show_ending',number});
  await expect.poll(async()=>(await state(page)).ending_credits.prepared,{timeout:60000}).toBe(true);
  await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:30000}).toBe('credits');
  await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).ending_credits.stage).toBe('last_look');
  expect((await state(page)).ending_credits.afterglow.party).toBeUndefined();expect((await state(page)).ending_credits.music).toBe(true);
 }
});

test('v3.8.10 crocodile supports repeated jumps and backing out after the tape cannot skip ending 2',async({page})=>{
 test.setTimeout(180000);await begin(page);
 await qa(page,{op:'warp',x:12.65,y:2.8,z:12.4,yaw:Math.PI/2,pitch:-.25});
 await expect.poll(async()=>(await state(page)).grounded).toBe(true);
 for(let jump=0;jump<3;jump++){
  const floor=(await state(page)).position[1];expect(floor).toBeGreaterThan(2);
  await page.keyboard.press('Space');
  await expect.poll(async()=>(await state(page)).position[1]).toBeGreaterThan(floor+.5);
  await expect.poll(async()=>(await state(page)).grounded).toBe(true);
  expect((await state(page)).position[1]).toBeGreaterThan(2);
 }
 await page.screenshot({path:join(tmpdir(),'after-play-v3810-web-croc-top.png')});
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2,pitch:-.22});
 await expect.poll(async()=>(await state(page)).target).toBe('archive_door');await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).phase).toBe('code');await page.mouse.click(275,220);await page.keyboard.type('0712',{delay:25});
 await expect.poll(async()=>(await state(page)).archive_input).toBe('0712');await page.keyboard.press('Enter');
 await expect.poll(async()=>(await state(page)).archive.angle).toBeLessThan(-1.7);
 await qa(page,{op:'warp',x:-11.3,z:-9.9,yaw:Math.atan2(.8,-.35),pitch:Math.atan2(.11-1.65,Math.hypot(.8,.35))});
 await expect.poll(async()=>(await state(page)).target).toBe('archive_recording');await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).archive.finale.state).toBe('recording');
 await qa(page,{op:'recording_seek',time:(await state(page)).archive.finale.duration-.08});
 await expect.poll(async()=>(await state(page)).archive.finale.state).toBe('armed');
 await qa(page,{op:'warp',x:-11.3,z:-9.9,yaw:Math.PI/2,pitch:0});
 await page.keyboard.down('c');try{await walk(page,'s',s=>s.phase!=='play');}finally{await page.keyboard.up('c');}
 expect((await state(page)).failure.count).toBe(1);expect((await state(page)).position[0]).toBeLessThan(-10.2);
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('ending');
 expect((await state(page)).ending_credits.ending).toBe(2);
});

test('v3.8.7 stereo fills the party room and round table stops walking and supports landing',async({page})=>{
 test.setTimeout(180000);await begin(page);expect((await state(page)).party.stereo).toBe(true);
 await qa(page,{op:'warp',x:18.52,y:.2,z:-13.25,yaw:-Math.PI/2,pitch:-.18});
 await expect.poll(async()=>(await state(page)).target).toBe('party_control');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).party.playing).toBe(true);
 const song=async()=>(await state(page)).upgrade.acoustics.sources.find(s=>s.id==='PartySong');
 for(const [x,z] of [[8,-2.8],[18.5,-10.5],[18.5,.4]]){
  await qa(page,{op:'warp',x,z});
  await expect.poll(async()=>Math.abs((await song()).gain),{timeout:8000}).toBeLessThan(.1);
  await expect.poll(async()=>(await song()).cutoff).toBeGreaterThan(17500);
 }
 await qa(page,{op:'warp',x:10.8,z:-2.4,yaw:1.26,pitch:-.18});
 await qa(page,{op:'party_seek',time:(await state(page)).party.drops[0]+1});await expect.poll(async()=>(await state(page)).party.drop).toBe(true);
 await page.screenshot({path:join(tmpdir(),'after-play-v387-web-stereo.png')});
 await qa(page,{op:'pause'});await expect.poll(async()=>(await state(page)).party.paused).toBe(true);
 await qa(page,{op:'resume'});await expect.poll(async()=>(await state(page)).party.paused).toBe(false);
 await qa(page,{op:'warp',x:4,z:-8});await expect.poll(async()=>(await song()).gain).toBeLessThan(-9);
 await qa(page,{op:'warp',x:13.7,z:-1.8,yaw:0,pitch:0});
 await page.keyboard.down('w');await page.waitForTimeout(1400);await page.keyboard.up('w');
 const stopped=(await state(page)).position;expect(stopped[2]).toBeGreaterThan(-2.5);expect(stopped[2]).toBeLessThan(-2.15);
 await qa(page,{op:'warp',x:13.7,y:1.3,z:-3.8});
 await expect.poll(async()=>Math.abs((await state(page)).position[1]-.66)).toBeLessThan(.035);
 await qa(page,{op:'warp',x:18.52,y:.2,z:-13.25,yaw:-Math.PI/2,pitch:-.18});
 await expect.poll(async()=>(await state(page)).target).toBe('party_control');await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).party.playing).toBe(false);
});

test('v3.8.6 warning blocks the menu, switches language and remembers disabled strobe',async({page})=>{
 test.setTimeout(180000);await page.goto(URL);await expect(page).toHaveTitle('After Play');
 await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='warning',null,{timeout:60000});
 expect((await state(page)).startup.visible).toBe(true);expect((await state(page)).startup.muted).toBe(true);
 expect((await state(page)).startup.content).toContain('Lichtblitze');expect((await state(page)).startup.joke).toContain('erschreckend schlechte Jumpscares');
 await page.keyboard.press('Escape');expect((await state(page)).phase).toBe('warning');
 const select=async(english)=>{const [x,y,w,h]=(await state(page)).startup.language_rect;await page.mouse.click(x+w/2,y+h/2);await expect.poll(async()=>(await state(page)).startup.dropdown.visible).toBe(true);const dropdown=(await state(page)).startup.dropdown;await page.mouse.click(dropdown.position[0]+60,dropdown.position[1]+dropdown.size[1]*((english?1:0)+.5)/2);await expect.poll(async()=>(await state(page)).startup.language).toBe(english?'en':'de');};
 await select(true);expect((await state(page)).startup.content).toContain('flashing lights');
 expect((await state(page)).controls.find(c=>c.text==='Verstanden · Weiter').rendered_text).toBe('Understood · Continue');
 await page.screenshot({path:join(tmpdir(),'after-play-v386-warning-en.png')});await select(false);
 await page.screenshot({path:join(tmpdir(),'after-play-v386-warning-de.png')});
 if((await state(page)).startup.strobe)await clickControl(page,'Stroboskopeffekte aktivieren');
 await clickControl(page,'Verstanden · Weiter');await expect.poll(async()=>(await state(page)).phase).toBe('menu');
 expect((await state(page)).settings.strobe).toBe(false);expect((await state(page)).startup.visible).toBe(false);
 await page.reload();await page.waitForFunction(()=>window.nachtwacheStatus?.phase==='warning',null,{timeout:60000});
 expect((await state(page)).startup.strobe).toBe(false);expect((await state(page)).startup.muted).toBe(true);
 await clickControl(page,'Verstanden · Weiter');await expect.poll(async()=>(await state(page)).phase).toBe('menu');
 await clickControl(page,'Neue Nachtschicht');await skipIntro(page);
 expect((await state(page)).settings.strobe).toBe(false);expect((await state(page)).phase).toBe('play');
});

async function takeParkingKey(page){
 await qa(page,{op:'warp',x:-7.89,z:-18,yaw:Math.PI/2,pitch:-.24});
 await expect.poll(async()=>(await state(page)).target).toBe('parking_key');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).parking_key).toBe(true);
}

test('v3.8.12 Rolling Acid and costume-room switch preserve music and the restart cooldown',async({page})=>{
 test.setTimeout(180000);await begin(page);
 expect((await state(page)).party.enabled).toBe(false);
 await qa(page,{op:'warp',x:-11.49,z:-3.48,yaw:-Math.PI/2,pitch:-.18});
 expect((await state(page)).target).not.toBe('party_control');
 await qa(page,{op:'warp',x:18.52,y:.2,z:-13.25,yaw:-Math.PI/2,pitch:-.18});
 await expect.poll(async()=>(await state(page)).target).toBe('party_control');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).party.playing).toBe(true);
 await qa(page,{op:'party_seek',time:12});await expect.poll(async()=>(await state(page)).party.clock).toBeGreaterThan(11);
 await expect.poll(async()=>(await state(page)).party.drop).toBe(false);
 const track=(await state(page)).party;expect(track.track).toBe('Rolling Acid');expect(track.duration).toBeGreaterThan(270);
 expect(track.drops).toHaveLength(5);expect(track.drop_ends).toHaveLength(5);
 for(let i=0;i<track.drops.length;i++){
  await qa(page,{op:'party_seek',time:track.drops[i]+1});await expect.poll(async()=>(await state(page)).party.drop).toBe(true);
  await expect.poll(async()=>(await state(page)).party.clock).toBeGreaterThan(track.drops[i]);
 }
 await qa(page,{op:'party_seek',time:150});await expect.poll(async()=>(await state(page)).party.drop).toBe(false);
 await qa(page,{op:'party_seek',time:track.duration-.4});
 await expect.poll(async()=>(await state(page)).party.clock,{timeout:6000}).toBeLessThan(4);
 expect((await state(page)).party.playing).toBe(true);
 await qa(page,{op:'party_seek',time:track.drops[0]+1});await expect.poll(async()=>(await state(page)).party.drop).toBe(true);
 await qa(page,{op:'pause'});await expect.poll(async()=>(await state(page)).party.paused).toBe(true);
 const paused=(await state(page)).party.clock;await page.waitForTimeout(300);expect((await state(page)).party.clock).toBe(paused);
 await qa(page,{op:'resume'});await expect.poll(async()=>(await state(page)).party.paused).toBe(false);
 await takeParkingKey(page);await qa(page,{op:'menu'});await clickControl(page,'Schicht fortsetzen');
 expect((await state(page)).parking_key).toBe(true);expect((await state(page)).party.enabled).toBe(true);
 await qa(page,{op:'warp',x:8.3,z:-8.8,yaw:-2.2,pitch:.4});await qa(page,{op:'party_seek',time:track.drops[1]+1});
 await expect.poll(async()=>(await state(page)).party.drop).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v385-web-party.png')});
 await qa(page,{op:'warp',x:6.25,z:7.5,yaw:-Math.PI/2,pitch:0});
 await walk(page,'w',s=>s.position[0]>11.15);expect((await state(page)).position[1]).toBeGreaterThan(2.1);
 await walk(page,'s',s=>s.position[0]<6.3);expect((await state(page)).position[1]).toBeLessThan(.2);
 await qa(page,{op:'warp',x:18.52,y:.2,z:-13.25,yaw:-Math.PI/2,pitch:-.18});
 await expect.poll(async()=>(await state(page)).target).toBe('party_control');await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).party.playing).toBe(false);
 const reboot=(await state(page)).party;expect(reboot.reboot_remaining).toBeGreaterThanOrEqual(898);
 expect(reboot.control_prompt).toContain('System startet neu');
 for(let i=0;i<5;i++)await page.keyboard.press('e');
 expect((await state(page)).party.reboot_until).toBe(reboot.reboot_until);
 expect((await state(page)).party.playing).toBe(false);
 await page.screenshot({path:join(tmpdir(),'after-play-v3812-party-restart.png')});
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 expect((await state(page)).party.reboot_until).toBe(reboot.reboot_until);
 await qa(page,{op:'warp',x:18.52,y:.2,z:-13.25,yaw:-Math.PI/2,pitch:-.18});
 await expect.poll(async()=>(await state(page)).target).toBe('party_control');await page.keyboard.press('e');
 expect((await state(page)).party.enabled).toBe(false);expect((await state(page)).party.reboot_remaining).toBeGreaterThan(850);
});

test('v3.8.4 German renders again after English and both selections survive restart',async({page})=>{
 test.setTimeout(180000);const faults=[];page.on('pageerror',e=>faults.push(e.message));
 await load(page);
 const select=async(label,index)=>{
  await clickControl(page,label);
  const dropdown=(await state(page)).dropdown;expect(dropdown.items).toEqual(['Deutsch','English']);
  await page.mouse.click(dropdown.position[0]+60,dropdown.position[1]+dropdown.size[1]*(index+.5)/2);
 };
 await clickControl(page,'Einstellungen');await clickControl(page,'Sprache');await select('Deutsch',1);
 await expect.poll(async()=>(await state(page)).language).toBe('en');
 await clickControl(page,'Back');
 expect((await state(page)).controls.find(c=>c.text==='New night shift').rendered_text).toBe('New night shift');
 await page.reload();await waitForMenu(page);
 expect((await state(page)).language).toBe('en');
 await clickControl(page,'Settings');await clickControl(page,'Language');await select('English',0);
 await expect.poll(async()=>(await state(page)).language).toBe('de');
 expect((await state(page)).controls.find(c=>c.text==='Zurück').rendered_text).toBe('Zurück');
 await clickControl(page,'Zurück');
 expect((await state(page)).controls.find(c=>c.text==='Neue Nachtschicht').rendered_text).toBe('Neue Nachtschicht');
 await page.screenshot({path:join(tmpdir(),'after-play-v384-web-german.png')});
 await page.reload();await waitForMenu(page);
 expect((await state(page)).language).toBe('de');
 expect((await state(page)).controls.find(c=>c.text==='Einstellungen').rendered_text).toBe('Einstellungen');
 expect(faults).toEqual([]);
});

test('v3.8 English settings persist, sign reading works and speech has timed translated captions',async({page})=>{
 test.setTimeout(180000);const faults=[];page.on('pageerror',e=>faults.push(e.message));page.on('console',m=>{if(m.type()==='error')faults.push(m.text());});
 await load(page);await clickControl(page,'Einstellungen');await clickControl(page,'Sprache');
 await clickControl(page,'Deutsch');await page.screenshot({path:join(tmpdir(),'after-play-v380-language-dropdown.png')});
 await expect.poll(async()=>(await state(page)).dropdown?.items).toEqual(['Deutsch','English']);
 const dropdown=(await state(page)).dropdown;await page.mouse.click(dropdown.position[0]+60,dropdown.position[1]+dropdown.size[1]*.75);
 await expect.poll(async()=>(await state(page)).language).toBe('en');
 expect((await state(page)).controls.some(c=>c.text==='Speech subtitles')).toBe(true);
 await clickControl(page,'Back');await expect.poll(async()=>(await state(page)).phase).toBe('menu');
 expect((await state(page)).controls.some(c=>c.text==='New night shift')).toBe(true);
 await page.reload();await waitForMenu(page);
 expect((await state(page)).language).toBe('en');await clickControl(page,'New night shift');
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('intro');
 await page.waitForTimeout(1300);await page.keyboard.press('e');
 await expect.poll(async()=>(await state(page)).captions.source,{timeout:10000}).toBe('intro');
 expect((await state(page)).captions.text).toMatch(/new guy|listen|Welcome/);
 await page.screenshot({path:join(tmpdir(),'after-play-v380-web-english-call.png')});
 await page.keyboard.down('Space');await expect.poll(async()=>(await state(page)).phase,{timeout:10000}).toBe('play');await page.keyboard.up('Space');
 await qa(page,{op:'warp',x:-8.17,y:.008,z:5.5,yaw:Math.PI/2,pitch:.245});
 await page.mouse.click(960,540);
 await expect.poll(async()=>(await state(page)).captions.sign,{timeout:8000}).toBe('hours');
 expect((await state(page)).captions.text).toContain('10:00');expect((await state(page)).captions.text).toContain('STEP RIGHT IN');
 await page.screenshot({path:join(tmpdir(),'after-play-v380-web-english-sign.png')});
 // The saved sign preference stays enabled; German must suppress the overlay
 // independently and switching back must rescan the same physical poster.
 const selectLanguage=async(english)=>{
  await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
  await clickControl(page,english?'Einstellungen':'Settings');await clickControl(page,english?'Sprache':'Language');
  await clickControl(page,english?'Deutsch':'English');const menu=(await state(page)).dropdown;
  await page.mouse.click(menu.position[0]+60,menu.position[1]+menu.size[1]*(english?.75:.25));
  await expect.poll(async()=>(await state(page)).language).toBe(english?'en':'de');
  await clickControl(page,english?'Back':'Zurück');await clickControl(page,english?'Resume patrol':'Rundgang fortsetzen');
  await page.mouse.click(960,540);await page.waitForTimeout(100);await qa(page,{op:'look',yaw:Math.PI/2,pitch:.245});
 };
 await selectLanguage(false);expect((await state(page)).settings.sign_subtitles).toBe(true);
 await expect.poll(async()=>(await state(page)).captions.visible).toBe(false);
 await page.screenshot({path:join(tmpdir(),'after-play-v389-web-german-sign.png')});
 await selectLanguage(true);await expect.poll(async()=>(await state(page)).captions.sign).toBe('hours');
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 await clickControl(page,'Settings');await clickControl(page,'Language');
 await clickControl(page,'Speech subtitles');expect((await state(page)).settings.subtitles).toBe(false);
 await clickControl(page,'English sign translations');expect((await state(page)).settings.sign_subtitles).toBe(false);
 await clickControl(page,'Back');await clickControl(page,'Resume patrol');
 expect((await state(page)).captions.visible).toBe(false);
 expect(faults).toEqual([]);
});

test('v3.7.1 requested music plays for horse pursuit and all credits with pause and reload',async({page})=>{
 test.setTimeout(180000);const faults=[];page.on('pageerror',e=>faults.push(e.message));page.on('console',m=>{if(m.type()==='error')faults.push(m.text());});
 await begin(page);expect((await state(page)).horse_hunt.music).toBe(false);
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2,pitch:-.22});await expect.poll(async()=>(await state(page)).target).toBe('archive_door');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('code');await page.mouse.click(275,220);await page.keyboard.type('07120712',{delay:25});await page.keyboard.press('Enter');
 await expect.poll(async()=>(await state(page)).horse_hunt?.music,{timeout:30000}).toBe(true);expect((await state(page)).horse_hunt.music_track).toBe('res://assets/music-v371/music-box-chase.mp3');
 await page.waitForTimeout(1600);await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).horse_hunt.music_paused).toBe(true);const paused=(await state(page)).horse_hunt.music_position;
 await page.waitForTimeout(400);expect(Math.abs((await state(page)).horse_hunt.music_position-paused)).toBeLessThan(.15);
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).horse_hunt?.music,{timeout:30000}).toBe(true);const resumed=(await state(page)).horse_hunt;expect(resumed.music_paused).toBe(false);expect(resumed.music_position).toBeGreaterThan(paused-.15);expect(resumed.music_position).toBeLessThan(paused+2);
 for(const number of [1,2,3]){
  await qa(page,{op:'show_ending',number});await expect.poll(async()=>(await state(page)).ending_credits?.music,{timeout:30000}).toBe(true);
  expect((await state(page)).ending_credits.music_track).toBe('res://assets/music-v371/fern-and-feather.mp3');expect((await state(page)).ending_credits.ending).toBe(number);
  await expect.poll(async()=>(await state(page)).ending_credits.prepared,{timeout:30000}).toBe(true);
 }
 expect(faults).toEqual([]);
});

test('v3.7.0 lookout and transparent party loop are physically traversable and restore a crouched save',async({page})=>{
 test.setTimeout(240000);const faults=[];page.on('pageerror',e=>faults.push(e.message));page.on('console',m=>{if(m.type()==='error')faults.push(m.text());});
 await begin(page);const initial=await state(page);expect(initial.climbing.length).toBeGreaterThan(18);expect(initial.climbing.names).toBe(4);expect(initial.climbing.windows).toBeGreaterThanOrEqual(6);
 const to=async(x,y,z,crawl=false)=>{
  for(let attempt=0;attempt<35;attempt++){
   const p=(await state(page)).position;const distance=Math.hypot(x-p[0],z-p[2]);if(distance<(crawl?.14:.22)){expect(Math.abs(p[1]-y)).toBeLessThan(.24);return;}
   await qa(page,{op:'look',yaw:Math.atan2(-(x-p[0]),-(z-p[2]))});await page.keyboard.down('w');
   try{await page.waitForTimeout(Math.max(40,Math.min(450,(distance-(crawl?.09:.16))/(crawl?1.35:2.8)*1000)));}finally{await page.keyboard.up('w');}
   await page.waitForTimeout(180);
  }
  throw new Error('Blocked climbing route '+JSON.stringify({target:[x,y,z],state:await state(page)}));
 };
 await qa(page,{op:'warp',x:2.05,y:2.977,z:-.10,yaw:0,pitch:0});
 await to(2.05,4.15,-3.7);await to(2.4,4.15,-4.5);await to(3.45,4.15,-4.5);expect((await state(page)).polish.floor).toBe('wood');
 await page.keyboard.down('c');const path=initial.climbing.path;
 for(let i=0;i<path.length;i++){
  await to(...path[i],true);
  if(i===Math.floor(path.length/2)){
   expect((await state(page)).climbing.inside).toBe(true);expect((await state(page)).watcher).toBe(false);
   await page.screenshot({path:join(tmpdir(),'after-play-v370-web-transparent-tube.png')});
   await page.keyboard.up('c');await page.keyboard.press('Escape');const saved=(await state(page)).position;await page.reload();
   await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
   await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
   const restored=await state(page);expect(restored.climbing.inside).toBe(true);expect(restored.crouching).toBe(true);expect(Math.hypot(...restored.position.map((v,j)=>v-saved[j]))).toBeLessThan(.12);await page.keyboard.down('c');
  }
 }
 await to(16.05,4.15,3.65,true);await page.keyboard.up('c');await expect.poll(async()=>(await state(page)).crouching).toBe(false);
 await to(16.2,4.15,3.7);await to(16.2,2.15,8.15);await to(16.2,4.15,3.7);
 await page.keyboard.down('c');for(const p of [...path].reverse())await to(...p,true);await to(3.25,4.15,-4.5,true);await page.keyboard.up('c');
 await expect.poll(async()=>(await state(page)).crouching).toBe(false);expect((await state(page)).streak).toBe(0);expect(faults).toEqual([]);
});

test('v3.6.1 horse contact screams, survives pause and reload, then continues the same pursuit without death',async({page})=>{
 test.setTimeout(180000);const faults=[];page.on('pageerror',error=>faults.push(error.message));page.on('console',message=>{if(message.type()==='error')faults.push(message.text());});
 await begin(page);await qa(page,{op:'anomaly',id:'none'});await qa(page,{op:'choose',red:false});await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');expect((await state(page)).streak).toBe(1);
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2,pitch:-.22});await expect.poll(async()=>(await state(page)).target).toBe('archive_door');await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('code');
 await page.mouse.click(275,220);await page.keyboard.type('07120712',{delay:30});await expect.poll(async()=>(await state(page)).archive_input).toBe('07120712');await page.keyboard.press('Enter');await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 await qa(page,{op:'warp',x:-7.9,z:-25.5,yaw:0,pitch:0});
 await expect.poll(async()=>(await state(page)).horse_hunt.catch_audio,{timeout:45000,intervals:[70]}).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 const frozen=(await state(page)).horse_hunt;expect(frozen.catch_count).toBe(1);expect(frozen.closeup).toBe(true);expect(frozen.catch_paused).toBe(true);
 await page.waitForTimeout(300);expect((await state(page)).horse_hunt.clock).toBe(frozen.clock);await page.screenshot({path:join(tmpdir(),'after-play-v361-web-horse-catch.png')});
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 expect((await state(page)).streak).toBe(1);expect((await state(page)).anomaly).toBe('horse_clown_hunt');expect((await state(page)).horse_hunt.catch_count).toBe(1);expect((await state(page)).passage.red_locked).toBe(true);
 await expect.poll(async()=>(await state(page)).horse_hunt.closeup).toBe(true);
 await expect.poll(async()=>(await state(page)).horse_hunt.phase,{timeout:10000,intervals:[70]}).toBe('following');expect((await state(page)).horse_hunt.catch_count).toBe(1);
 await expect.poll(async()=>(await state(page)).horse_hunt.catch_count,{timeout:15000,intervals:[70]}).toBe(2);
 expect((await state(page)).phase).toBe('play');expect((await state(page)).streak).toBe(1);expect((await state(page)).passage.red_locked).toBe(true);expect(faults).toEqual([]);
});

test('v3.5.7 stage front is walkable without jumping and the moved car leaves the party entrance clear',async({page})=>{
 test.setTimeout(180000);await begin(page);
 expect((await state(page)).backstage.stage_apron_width).toBeCloseTo(7);
 const car=(await state(page)).backstage.car_position;expect(car[0]).toBeCloseTo(4.15);expect(car[1]).toBeCloseTo(0);expect(car[2]).toBeCloseTo(-7.45);
 for(const x of [12,14.9,17.3]){
  await qa(page,{op:'warp',x,y:.12,z:-9.1,yaw:0,pitch:0});
  await walk(page,'w',s=>s.position[2]<-10.15);expect((await state(page)).position[1]).toBeGreaterThan(.18);
  await walk(page,'s',s=>s.position[2]>-8.7);expect((await state(page)).position[1]).toBeLessThan(.09);
 }
 await qa(page,{op:'warp',x:15.6,y:.08,z:-8.8,yaw:1.0,pitch:-.45});await page.waitForTimeout(600);await page.screenshot({path:join(tmpdir(),'after-play-v357-web-stage.png')});
 await qa(page,{op:'warp',x:5.9,z:-8.7,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>7.8);await walk(page,'s',s=>s.position[0]<6.0);
 await qa(page,{op:'warp',x:2.7,z:-10.0,yaw:-2.62,pitch:-.24});await page.waitForTimeout(600);await page.screenshot({path:join(tmpdir(),'after-play-v357-web-car.png')});
 await qa(page,{op:'audit'});const report=(await state(page)).layout;expect(report.door_obstructions).toEqual([]);expect(report.art_overlaps).toEqual([]);expect(report.furniture_wall_intrusions).toEqual([]);
});

test('v3.6.0 reference horse stays motionless and preserves walkable cinema access',async({page})=>{
 test.setTimeout(180000);const faults=[];page.on('pageerror',error=>faults.push(error.message));page.on('console',message=>{if(message.type()==='error')faults.push(message.text());});
 await begin(page);await qa(page,{op:'warp',x:-7.9,z:-25.6,yaw:0,pitch:.10});
 const initial=(await state(page)).room_horror.horse;expect(initial.bodyless).toBe(true);expect(initial.jaw).toBe(true);expect(initial.neck_samples).toBe(32);expect(initial.source[1]).toBeGreaterThan(3.9);
 await page.waitForTimeout(6000);expect((await state(page)).room_horror.horse).toEqual(initial);expect(initial.clock).toBe(0);expect(initial.progress).toBe(0);
 await page.keyboard.press('Escape');await page.waitForTimeout(120);const frozen=(await state(page)).room_horror.horse;await page.waitForTimeout(500);expect((await state(page)).room_horror.horse).toEqual(frozen);
 await page.keyboard.press('Escape');await page.waitForTimeout(150);await page.screenshot({path:join(tmpdir(),'after-play-v356-web-horse-peek.png')});
 await qa(page,{op:'warp',x:-7.9,z:-29.65,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>-5.05);await walk(page,'s',s=>s.position[0]<-7.8);
 await qa(page,{op:'warp',x:-7.9,z:-14,yaw:0,pitch:.25});await page.waitForTimeout(650);await page.screenshot({path:join(tmpdir(),'after-play-v356-web-ceiling.png')});
 await qa(page,{op:'audit'});const report=(await state(page)).layout;expect(report.door_obstructions).toEqual([]);expect(report.art_overlaps).toEqual([]);expect(report.furniture_wall_intrusions).toEqual([]);expect((await state(page)).anomaly).toBe('none');
 expect(faults).toEqual([]);
});

test('v3.6.0 creator keypad starts the saved horse hunt, kitchen clown repels it and red unlocks after the full return',async({page})=>{
 test.setTimeout(480000);const faults=[];page.on('pageerror',error=>faults.push(error.message));page.on('console',message=>{if(message.type()==='error')faults.push(message.text());});
 await begin(page);
 // Reach a protected newspaper round, which only the explicit creator code may override.
 for(let i=0;i<2;i++){
  await qa(page,{op:'anomaly',id:'none'});await qa(page,{op:'choose',red:false});
  await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 }
 expect((await state(page)).streak).toBe(2);expect((await state(page)).anomaly).toBe('none');
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2,pitch:-.22});await expect.poll(async()=>(await state(page)).target).toBe('archive_door');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('code');
 await page.mouse.click(275,220);await page.keyboard.type('07120712',{delay:35});
 await expect.poll(async()=>(await state(page)).archive_input).toBe('07120712');await page.keyboard.press('Enter');
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');expect((await state(page)).anomaly).toBe('horse_clown_hunt');expect((await state(page)).streak).toBe(2);
 await qa(page,{op:'warp',x:-2.15,z:-10.5,yaw:0,pitch:0});await expect.poll(async()=>(await state(page)).target).toBe('red');await page.keyboard.press('e');
 expect((await state(page)).passage.red_locked).toBe(true);expect((await state(page)).passage.horse_note).toBe(true);expect((await state(page)).passage.open[1]).toBe(false);
 await qa(page,{op:'warp',x:-7.9,z:-25.5,yaw:0,pitch:0});
 await expect.poll(async()=>(await state(page)).horse_hunt.phase,{timeout:30000}).toBe('following');
 // Short real key presses allow braking and correction when WebGL frames
 // arrive late. A single held key can overshoot a narrow turning point.
 const to=async(x,z)=>{
  for(let attempt=0;attempt<40;attempt++){
   const p=(await state(page)).position;const distance=Math.hypot(p[0]-x,p[2]-z);if(distance<.24)return;
   await qa(page,{op:'look',yaw:Math.atan2(-(x-p[0]),-(z-p[2]))});
   await page.keyboard.down('w');try{await page.waitForTimeout(Math.max(55,Math.min(700,(distance-.25)/2.8*1000)));}finally{await page.keyboard.up('w');}
   await page.waitForTimeout(220);
  }
  const p=(await state(page)).position;expect(Math.hypot(p[0]-x,p[2]-z),`Lure waypoint ${x},${z}; actual ${p}`).toBeLessThan(.24);
 };
 for(const [x,z] of [[-7.9,-10.7],[5.7,-10.7],[5.7,-8.7],[8.1,-8.7],[8.1,-10.05],[9.6,-10.05]])await to(x,z);
 await expect.poll(async()=>(await state(page)).horse_hunt.head[0],{timeout:20000}).toBeGreaterThan(6.8);
 expect((await state(page)).horse_hunt.neck_sections).toBeGreaterThan(5);
 await page.keyboard.press('Escape');const paused=(await state(page)).horse_hunt;await page.waitForTimeout(500);expect((await state(page)).horse_hunt.clock).toBe(paused.clock);
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 expect((await state(page)).streak).toBe(2);expect((await state(page)).anomaly).toBe('horse_clown_hunt');expect((await state(page)).horse_hunt.trace_points).toBeGreaterThanOrEqual(paused.trace_points);
 expect((await state(page)).passage.red_locked).toBe(true);
 for(const [x,z] of [[8.1,-10.05],[8.1,-8.7],[5.7,-8.7],[5.7,-10.7],[-7.9,-10.7],[-7.9,-29.65],[-12.3,-29.65]])await to(x,z);
 await expect.poll(async()=>(await state(page)).horse_hunt.screamed,{timeout:20000}).toBe(true);
 expect((await state(page)).passage.red_locked).toBe(true);await page.keyboard.press('Escape');
 const clownPause=(await state(page)).horse_hunt;await page.waitForTimeout(350);expect((await state(page)).horse_hunt.clock).toBe(clownPause.clock);expect((await state(page)).horse_hunt.audio_paused).toBe(true);await page.keyboard.press('Escape');
 await expect.poll(async()=>(await state(page)).horse_hunt.phase,{timeout:45000}).toBe('resolved');
 expect((await state(page)).horse_hunt.screamed).toBe(true);expect((await state(page)).passage.red_locked).toBe(false);expect((await state(page)).passage.horse_note).toBe(false);
 await qa(page,{op:'warp',x:-2.15,z:-10.5,yaw:0,pitch:0});await expect.poll(async()=>(await state(page)).target).toBe('red');await page.keyboard.press('e');expect((await state(page)).passage.open[1]).toBe(true);
 // A completed encounter must restore the already-entered red corridor too.
 await qa(page,{op:'warp',x:-2.15,z:-15.2,yaw:0,pitch:0});await expect.poll(async()=>(await state(page)).passage.chosen).toBe(1);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');await page.reload();
 await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 expect((await state(page)).horse_hunt.phase).toBe('resolved');expect((await state(page)).passage.open[1]).toBe(true);expect((await state(page)).passage.chosen).toBe(1);expect((await state(page)).passage.red_locked).toBe(false);
 expect(faults).toEqual([]);
});

test('v3.5.5 aged timber portal stays walkable and the complete snackbar occupies the party wall',async({page})=>{
 test.setTimeout(180000);await begin(page);
 await qa(page,{op:'warp',x:-7.9,z:-10,yaw:0,pitch:0});
 await walk(page,'w',s=>s.position[2]<-15.2);await walk(page,'s',s=>s.position[2]>-10);
 await qa(page,{op:'warp',x:-7.9,z:-8.9,yaw:0,pitch:.05});await page.waitForTimeout(700);
 await page.screenshot({path:join(tmpdir(),'after-play-v355-web-timber-frame.png')});
 const place=(await state(page)).life.snack_position;expect(place[0]).toBeCloseTo(12);expect(place[2]).toBeCloseTo(.71);
 expect((await state(page)).life.slush_machines).toBe(2);expect((await state(page)).presentation.fresco[1]).toBeCloseTo(3.95);
 await qa(page,{op:'warp',x:8.1,z:-6.2,yaw:Math.PI,pitch:0});await walk(page,'w',s=>s.position[2]>-.7);
 await qa(page,{op:'warp',x:11,z:-1.2,yaw:Math.PI,pitch:0});
 await page.keyboard.down('w');await page.waitForTimeout(850);await page.keyboard.up('w');
 expect((await state(page)).position[2]).toBeLessThan(-.12);
 await qa(page,{op:'warp',x:12,z:-3.5,yaw:Math.PI,pitch:.1});await page.waitForTimeout(700);
 await page.screenshot({path:join(tmpdir(),'after-play-v355-web-party-snackbar.png')});
 for(const encounter of [{id:'snackbar_visitor',x:12,z:-2.85},{id:'party_portrait',x:9.3,z:-2.15}]){
  await qa(page,{op:'anomaly',id:encounter.id});await qa(page,{op:'warp',...encounter,y:.03,yaw:Math.PI,pitch:0});
  await expect.poll(async()=>(await state(page)).terrors.triggered,{timeout:15000}).toBe(true);
 }
 await qa(page,{op:'anomaly',id:'none'});await qa(page,{op:'audit'});
 const layout=(await state(page)).layout;expect(layout.door_obstructions).toEqual([]);expect(layout.art_overlaps).toEqual([]);expect(layout.furniture_wall_intrusions).toEqual([]);
});

test('v3.5.3 boarded window preserves a viewing slit and weather plays audible spaced thunder',async({page})=>{
 test.setTimeout(180000);await begin(page);
 await qa(page,{op:'warp',x:-8,z:1.7});
 expect((await state(page)).upgrade.graphics.window_boards).toBe(6);
 expect((await state(page)).upgrade.graphics.window_curtains).toBe(2);
 await qa(page,{op:'warp',x:-9.2,z:1.7,yaw:Math.PI/2,pitch:0});
 await page.waitForTimeout(700);
 await page.screenshot({path:join(tmpdir(),'after-play-v353-web-window.png')});
 await page.keyboard.down('w');await page.waitForTimeout(800);await page.keyboard.up('w');
 expect((await state(page)).position[0]).toBeGreaterThan(-10.1);
 await expect.poll(async()=>(await state(page)).weather.rain_playing).toBe(true);
 await expect.poll(async()=>(await state(page)).weather.rain_db,{timeout:10000}).toBeGreaterThan(-20);
 expect((await state(page)).weather.bus).toBe('AP.Weather');
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).weather.paused).toBe(true);
 const paused=(await state(page)).weather;await page.waitForTimeout(350);
 expect((await state(page)).weather.clock).toBe(paused.clock);expect((await state(page)).weather.next_roll).toBe(paused.next_roll);
 await page.keyboard.press('Escape');await qa(page,{op:'warp',x:-1,z:-31});
 await expect.poll(async()=>(await state(page)).weather.area).toBe('cinema');
 await expect.poll(async()=>(await state(page)).weather.rain_db,{timeout:10000}).toBeLessThan(-23);
 await expect.poll(async()=>{const weather=(await state(page)).weather;return weather.count>0&&weather.thunder_playing;},{timeout:90000,intervals:[150]}).toBe(true);
 const rolled=(await state(page)).weather;expect(rolled.thunder_playing).toBe(true);expect(rolled.thunder_db).toBeGreaterThan(-12);expect(rolled.next_roll).toBeGreaterThan(35);
 expect((await state(page)).anomaly).toBe('none');
 await page.screenshot({path:join(tmpdir(),'after-play-v353-web-weather.png')});
});

test('v3.5.1 elevator readouts follow rounds, saved progress and death',async({page})=>{
 test.setTimeout(240000);await begin(page);
 const checkFloor=(snapshot,number)=>{
  const formatted=String(number).padStart(2,'0');
  expect(snapshot.intro.floor).toBe(number);expect(snapshot.passage.floor).toBe(number);
  expect(snapshot.intro.floor_texts).toEqual([formatted+'  ▲',formatted+'  ▲']);
  expect(snapshot.passage.floor_texts).toEqual([formatted+' / AUFZUG',formatted+' / AUFZUG']);
 };
 checkFloor(await state(page),1);
 for(let round=1;round<5;round++){
  await qa(page,{op:'choose',red:(await state(page)).anomaly!=='none'});
  await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
  expect((await state(page)).streak).toBe(round);checkFloor(await state(page),round+1);
 }
 await page.keyboard.press('Escape');await page.reload();
 await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');checkFloor(await state(page),5);
 await page.screenshot({path:join(tmpdir(),'after-play-v351-web-floor-05.png')});
 await qa(page,{op:'choose',red:(await state(page)).anomaly==='none'});
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 expect((await state(page)).streak).toBe(0);checkFloor(await state(page),1);
 await page.screenshot({path:join(tmpdir(),'after-play-v351-web-floor-reset.png')});
});

test('v3.5 Play reuses the menu venue and holding Skip switches to the prepared ending without rebuilding',async({page})=>{
 test.setTimeout(240000);await load(page);const builds=(await state(page)).performance.world_builds;
 await clickControl(page,'Neue Nachtschicht');await skipIntro(page);
 expect((await state(page)).performance.world_builds).toBe(builds);
 await qa(page,{op:'show_ending',number:1});await expect.poll(async()=>(await state(page)).phase).toBe('ending');
 await expect.poll(async()=>(await state(page)).ending_credits.prepared,{timeout:90000}).toBe(true);
 const readyBuilds=(await state(page)).performance.world_builds;
 const baseline=await page.evaluate(()=>new Promise(resolve=>{const times=[];let previous=performance.now();const frame=now=>{times.push(now-previous);previous=now;if(times.length===16)resolve(times);else requestAnimationFrame(frame);};requestAnimationFrame(frame);}));
 await page.evaluate(()=>{window.skipFrameTimes=[];window.captureSkip=true;let previous=performance.now();const frame=now=>{window.skipFrameTimes.push(now-previous);previous=now;if(window.captureSkip)requestAnimationFrame(frame);};requestAnimationFrame(frame);});
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:15000}).toBe('last_look');}finally{await page.keyboard.up('Space');await page.evaluate(()=>window.captureSkip=false);}
 await expect.poll(async()=>(await state(page)).ending_credits.skip_released).toBe(true);
 expect((await state(page)).performance.world_builds).toBe(readyBuilds);
 const deltas=await page.evaluate(()=>window.skipFrameTimes);const p95=xs=>[...xs].sort((a,b)=>a-b)[Math.floor((xs.length-1)*.95)];
 expect(deltas.length).toBeGreaterThan(5);expect(p95(deltas)).toBeLessThan(Math.max(200,p95(baseline)*2));
 console.log('Skip frame timing p95 ms',p95(deltas),'baseline',p95(baseline));
 await page.screenshot({path:join(tmpdir(),'after-play-v350-web-last-look.png')});
 await expect.poll(async()=>(await state(page)).ending_credits.afterglow.clock,{timeout:10000}).toBeGreaterThan(2.1);
 // Full-world telemetry is synchronous in WASM. Poll at the normal cadence so
 // the software renderer gets frames between state requests during the hold.
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:30000}).toBe(true);}catch(error){error.message+='\nEnding state: '+JSON.stringify((await state(page)).ending_credits);throw error;}finally{await page.keyboard.up('Space');}
 await clickControl(page,'Hauptmenü');await expect.poll(async()=>(await state(page)).phase).toBe('menu');
 await clickControl(page,'Neue Nachtschicht');await expect.poll(async()=>(await state(page)).phase,{timeout:60000}).toBe('intro');await skipIntro(page);
 expect((await state(page)).streak).toBe(0);expect((await state(page)).performance.world_builds).toBe(readyBuilds+1);
});

test('v3.4 fitted floors, cinema facade and repairs preserve physical room access and floor sounds',async({page})=>{
 test.setTimeout(240000);await begin(page);
 const craft=(await state(page)).craft;
 expect(craft.floor_finishes).toBe(3);expect(craft.handles).toBe(5);expect(craft.worn_surfaces).toBe(2);expect(craft.ticket_desk).toBe(true);expect(craft.litter_clusters).toBe(5);
 for(const sample of [{x:-2.15,z:-3.7,yaw:0,floor:'rubber'},{x:-5.3,z:-29.65,yaw:0,floor:'carpet'},{x:-11.8,z:-29.65,yaw:Math.PI/2,floor:'concrete'}]){
  await qa(page,{op:'warp',...sample});await expect.poll(async()=>(await state(page)).polish.floor).toBe(sample.floor);
  const before=(await state(page)).polish.steps;await walk(page,'w',s=>s.polish.steps>before);
  expect((await state(page)).polish.last_surface).toBe(sample.floor);
 }
 for(const x of [-9.4,-6.4]){
  await qa(page,{op:'warp',x:x-1.1,z:-29.3,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>x+.9);await walk(page,'s',s=>s.position[0]<x-.9);
  expect(Math.abs((await state(page)).position[1])).toBeLessThan(.06);
 }
 await qa(page,{op:'warp',x:-5.3,z:-30.8,yaw:0,pitch:0});await walk(page,'w',s=>s.position[2]<-33.3);await walk(page,'s',s=>s.position[2]>-30.8);
 await qa(page,{op:'audit'});const layout=(await state(page)).layout;
 expect(layout.door_obstructions).toEqual([]);expect(layout.art_overlaps).toEqual([]);expect(layout.furniture_wall_intrusions).toEqual([]);
 await page.screenshot({path:join(tmpdir(),'after-play-v340-web-cinema.png')});
});


test('v3.3 continue preserves a clear foyer pose and rejects an old save inside the new bench',async({page})=>{
 test.setTimeout(240000);await begin(page);
 await qa(page,{op:'warp',x:-13.2,z:9.4,yaw:Math.PI/2,pitch:0});await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).position[0]).toBeCloseTo(-13.2,1);expect((await state(page)).position[2]).toBeCloseTo(9.4,1);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 await page.evaluate(()=>{const key='after-play:qa-nachtwache-save.json';const save=JSON.parse(localStorage.getItem(key));save.pose=[-13.2,0,10.34,Math.PI/2,0];save.layout_version=11;localStorage.setItem(key,JSON.stringify(save));});
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).phase).toBe('play');const position=(await state(page)).position;expect(Math.hypot(position[0]+13.2,position[2]-10.34)).toBeGreaterThan(2);expect(position[0]).toBeCloseTo(-6.2,1);expect(position[2]).toBeCloseTo(8.5,1);
});

test('v3.3 cloakroom glass door is physical; stepping outside shows the secret car ending and saved credits',async({page})=>{
 test.setTimeout(420000);await begin(page);expect((await state(page)).arrival.parts).toBeGreaterThan(220);
 await qa(page,{op:'warp',x:-8.8,z:9.4,yaw:Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]<-13.5);
 expect((await state(page)).phase).toBe('play');expect((await state(page)).secret_ending).toBe(false);
 await page.keyboard.down('w');try{await page.waitForTimeout(1600);}finally{await page.keyboard.up('w');}
 expect((await state(page)).position[0]).toBeGreaterThan(-15.6);
 await qa(page,{op:'warp',x:-14.4,z:9.4,yaw:Math.PI/2,pitch:-.20});
 await expect.poll(async()=>(await state(page)).target).toBe('delivery_exit');await page.screenshot({path:join(tmpdir(),'after-play-v330-web-glass.png')});
 await page.keyboard.press('e');await page.waitForTimeout(300);expect((await state(page)).backstage.exit_angle).toBeLessThan(.01);
 await takeParkingKey(page);await qa(page,{op:'warp',x:-14.4,z:9.4,yaw:Math.PI/2,pitch:-.20});
 await expect.poll(async()=>(await state(page)).target).toBe('delivery_exit');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).backstage.exit_angle).toBeGreaterThan(1.45);
 expect((await state(page)).phase).toBe('play');await qa(page,{op:'audit'});
 expect((await state(page)).layout.door_obstructions).toEqual([]);expect((await state(page)).layout.furniture_wall_intrusions).toEqual([]);
 // Cross the door frame before turning right, as in the reported escape.
 await walk(page,'w',s=>s.position[0]<-16.0);
 await page.keyboard.down('d');try{await walk(page,'w',s=>s.phase==='ending');}finally{await page.keyboard.up('d');}
 expect((await state(page)).position[1]).toBeGreaterThan(-.4);await expect.poll(async()=>(await state(page)).ending_credits.car).toBe(true);
 // Preparing the final room is slower with the headless browser's renderer.
 await expect.poll(async()=>(await state(page)).ending_credits.end_word,{timeout:60000}).toBe(true);
 const end=(await state(page)).ending_credits;expect(end.ending).toBe(3);expect(end.title).toBe('Geheimes Ende');
 expect(end.secret_line).toBe('Was eine dumme Horror Scheiße, ich bin Weg und Kündige');
 await page.screenshot({path:join(tmpdir(),'after-play-v330-web-secret-ending.png')});
 await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:15000}).toBe('credits');expect((await state(page)).ending_credits.music).toBe(true);expect((await state(page)).ending_credits.car).toBe(false);
 await page.waitForTimeout(1300);await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:8000}).toBe('last_look');}finally{await page.keyboard.up('Space');}
 await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:60000}).toBe(true);await clickControl(page,'Hauptmenü');
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 await expect.poll(async()=>(await state(page)).ending_credits.ending).toBe(3);await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:60000}).toBe('credits');
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:60000}).toBe(true);await clickControl(page,'Neue Nachtschicht');await skipIntro(page,60000);
 expect((await state(page)).secret_ending).toBe(false);expect((await state(page)).streak).toBe(0);
});

test('v3.3 detailed annex keeps its centre and both room openings clear',async({page})=>{
 test.setTimeout(180000);await begin(page);await qa(page,{op:'warp',x:-7.9,z:-13.6,yaw:0,pitch:0});
 await page.screenshot({path:join(tmpdir(),'after-play-v330-web-corridor.png')});await walk(page,'w',s=>s.position[2]<-29.65);
 await qa(page,{op:'warp',x:-7.9,z:-29.65,yaw:Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]<-11.0);await walk(page,'s',s=>s.position[0]>-7.8);
 await qa(page,{op:'warp',x:-7.9,z:-29.65,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>-4.8);await walk(page,'s',s=>s.position[0]<-7.8);
 await qa(page,{op:'warp',x:-7.9,z:-29.65,yaw:Math.PI,pitch:0});await walk(page,'w',s=>s.position[2]>-13.5);
 await qa(page,{op:'audit'});const layout=(await state(page)).layout;
 expect(layout.door_obstructions).toEqual([]);expect(layout.art_overlaps).toEqual([]);expect(layout.furniture_wall_intrusions).toEqual([]);
});

test('v3.2 parking window is sealed and machinery responds to walls, pause and crawl acoustics',async({page})=>{
 test.setTimeout(150000);await begin(page);
 expect((await state(page)).upgrade.graphics.window).toBe(true);
 expect((await state(page)).upgrade.acoustics.source_count).toBe(35);
 expect((await state(page)).anomaly).toBe('none');
 await qa(page,{op:'warp',x:-7,y:.02,z:1.7,yaw:Math.PI/2,pitch:.13});
 await page.keyboard.down('w');try{await page.waitForTimeout(1500);await page.keyboard.press('Space');await page.waitForTimeout(800);}finally{await page.keyboard.up('w');}
 expect((await state(page)).position[0]).toBeGreaterThan(-10);
 await page.screenshot({path:join(tmpdir(),'after-play-v320-web-window.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 const paused=(await state(page)).upgrade.acoustics.clock;await page.waitForTimeout(450);expect((await state(page)).upgrade.acoustics.clock).toBe(paused);
 for(const source of (await state(page)).upgrade.acoustics.sources.filter(s=>['OrbitCabinetElectronics','PrizeCabinetMotor','ServiceTransformer','PlasticTubeAir'].includes(s.id)))expect(source.playing&&!source.paused).toBe(false);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 const projector=async()=>(await state(page)).upgrade.acoustics.sources.find(s=>s.file.endsWith('projector-mechanism.ogg'));
 await qa(page,{op:'warp',x:-4.4,y:.02,z:-29.65,yaw:Math.PI/2,pitch:.1});
 await expect.poll(async()=>(await projector()).cutoff).toBeGreaterThan(14000);
 await qa(page,{op:'warp',x:-12,y:.02,z:-32,yaw:Math.PI/2,pitch:.1});
 await expect.poll(async()=>(await projector()).cutoff).toBeLessThan(5500);
 expect((await projector()).portal).toBe(true);expect((await projector()).gain).toBeLessThan(-2);
 await page.keyboard.down('c');
 try{
  await qa(page,{op:'warp',x:-1.2,y:.25,z:15.8,yaw:-Math.PI/2,pitch:0});
  await expect.poll(async()=>(await state(page)).upgrade.acoustics.room).toBe('tube');
  await expect.poll(async()=>(await state(page)).upgrade.acoustics.step_cutoff).toBeLessThan(8000);
 }finally{await page.keyboard.up('c');}
 expect((await state(page)).anomaly).toBe('none');
});

test('v3.0 has distinct scare voices without immediate repeats and a fitted kitchen prep station',async({page})=>{
 // This flow rebuilds ten complete WebGL scenes, in addition
 // to loading and compiling the release materials. Keep the interaction and
 // encounter assertions unchanged while allowing that rendering setup time.
 test.setTimeout(240000);await begin(page);
 for(const [id,family,p,height] of [['cinema_aisle_rush','charge',[-1,0,-29.65],1.4],['kitchen_floor_crawler','crawler',[-12.9,0,-27.5],.7],['service_ceiling','ossuary',[-8.9,0,-3],-1.6],['wc_stall_watcher','whisper',[23.5,0,7],1.4],['party_guests','crowd',[12.4,0,-3],1.4]]){
  let previous='';
  for(let i=0;i<2;i++){
   await qa(page,{op:'anomaly',id});const actor=(await state(page)).terrors.position;const dx=actor[0]-p[0],dz=actor[2]-p[2];
   await qa(page,{op:'warp',x:p[0],y:.02,z:p[2],yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(actor[1]+height-1.65,Math.hypot(dx,dz))});
   await expect.poll(async()=>(await state(page)).terrors.triggered).toBe(true);const sound=(await state(page)).terrors.sound;
   expect(sound).toMatch(new RegExp('/revamp-v300/'+family+'-[123]\\.wav$'));expect(sound).not.toBe(previous);previous=sound;
  }
 }
 await qa(page,{op:'new'});await qa(page,{op:'warp',x:-13.3,y:.02,z:-27.5,yaw:Math.PI,pitch:-.08});
 await page.keyboard.down('w');try{await page.waitForTimeout(1000);}finally{await page.keyboard.up('w');}
 const position=(await state(page)).position;expect(position[2]).toBeGreaterThan(-27.2);expect(position[2]).toBeLessThan(-26.62);
 await page.screenshot({path:join(tmpdir(),'after-play-v300-web-prep-station.png')});
});

test('round 5 cinema newspaper can be collected with E from the aisle and stays in the saved inventory',async({page})=>{
 test.setTimeout(240000);await begin(page);
 for(let i=0;i<4;i++){
  await qa(page,{op:'choose',red:(await state(page)).anomaly!=='none'});await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 }
 expect((await state(page)).streak).toBe(4);expect((await state(page)).anomaly).toBe('none');expect((await state(page)).archive.spawned.some(p=>p.id==='missing')).toBe(true);
 await qa(page,{op:'warp',x:1.2,y:.03,z:-31.90,yaw:Math.PI/2,pitch:-.85});await expect.poll(async()=>(await state(page)).target).toBe('paper:missing');
 await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-cinema-newspaper.png')});await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).archive.collected.includes('missing')).toBe(true);
 expect((await state(page)).archive.spawned.some(p=>p.id==='missing')).toBe(false);await page.keyboard.press('Tab');expect((await state(page)).archive_reader).toBe('missing');await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-newspaper-reader.png')});await page.keyboard.press('Escape');
 await page.keyboard.press('Escape');await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).streak).toBe(4);expect((await state(page)).archive.collected).toContain('missing');expect((await state(page)).archive.spawned.some(p=>p.id==='missing')).toBe(false);
});

test('v3.5.4 reception entrance and staff side remain walkable; CCTV and physical pit balls work',async({page})=>{
 test.setTimeout(180000);await begin(page);
 await qa(page,{op:'warp',x:-11.3,z:9.4,yaw:-Math.PI/2,pitch:0});
 await walk(page,'w',s=>s.position[0]>-6.3);
 await qa(page,{op:'warp',x:-6.3,z:9.4,yaw:0,pitch:0});
 await walk(page,'w',s=>s.position[2]<6.75);
 await qa(page,{op:'warp',x:-6.3,z:6.75,yaw:Math.PI/2,pitch:0});
 await walk(page,'w',s=>s.position[0]<-7.3);
 await qa(page,{op:'warp',x:-7.4,y:.02,z:6.75,yaw:Math.atan2(.75,-1.1),pitch:-.27});
 await expect.poll(async()=>(await state(page)).target).toBe('reception_cctv');
 await page.screenshot({path:join(tmpdir(),'after-play-v354-web-reception.png')});
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('surveillance');
 expect((await state(page)).watch.world_shared).toBe(true);expect((await state(page)).watch.count).toBe(7);
 const position=(await state(page)).position;await page.keyboard.down('w');await page.waitForTimeout(250);await page.keyboard.up('w');expect((await state(page)).position).toEqual(position);
 for(let i=0;i<7;i++){
  await clickControl(page,`Kamera 0${i+1}`);await expect.poll(async()=>(await state(page)).watch.feed).toBe(i);
 }
 await page.screenshot({path:join(tmpdir(),'after-play-v2120-web-cctv.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).watch.opened).toBe(false);expect((await state(page)).watch.updates).toBe(0);
 await qa(page,{op:'warp',x:-7.85,y:.02,z:-18.75,yaw:-Math.PI/2,pitch:.25});await expect.poll(async()=>(await state(page)).target).toBe('memory_wall');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).phase).toBe('help');expect((await state(page)).instructions.join(' ')).toContain('Die Geburtstage von damals');await page.screenshot({path:join(tmpdir(),'after-play-v2120-web-photos.png')});await clickControl(page,'Zurück zum Rundgang');
 await qa(page,{op:'warp',x:1.1,y:.03,z:7.8,yaw:0,pitch:-.55});await page.keyboard.down('w');
 await expect.poll(async()=>(await state(page)).ball_pit.kicks,{timeout:12000}).toBeGreaterThan(0);await page.keyboard.up('w');
 expect((await state(page)).ball_pit.count).toBe(360);await page.screenshot({path:join(tmpdir(),'after-play-v2120-web-ball-physics.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');expect((await state(page)).ball_pit.running).toBe(false);
 await clickControl(page,'Rundgang fortsetzen');await expect.poll(async()=>(await state(page)).ball_pit.running).toBe(true);
 for(const encounter of [{id:'wc_stall_watcher',x:23.5,z:7,yaw:Math.PI,pitch:0},{id:'wc_ceiling_guest',x:22.4,z:7.1,yaw:-Math.PI/2,pitch:-.12},{id:'snackbar_visitor',x:12,z:-2.85,yaw:Math.PI,pitch:0}]){
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
 await page.keyboard.press('Escape');await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
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
 test.setTimeout(150000);await begin(page);await qa(page,{op:'choose',red:false});await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');
 await qa(page,{op:'anomaly',id:'false_exit'});await qa(page,{op:'warp',x:-14.4,z:9.4,yaw:Math.PI/2,pitch:-.20});await expect.poll(async()=>(await state(page)).target).toBe('delivery_exit');
 await page.keyboard.press('e');await expect.poll(async()=>(await state(page)).backstage.exit_started).toBe(true);expect((await state(page)).backstage.clean_corridor).toBe(true);
 await page.keyboard.press('Tab');await expect.poll(async()=>(await state(page)).phase).toBe('inventory');const paused=(await state(page)).backstage.exit_clock;await page.waitForTimeout(500);expect((await state(page)).backstage.exit_clock).toBe(paused);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).backstage.exit_finished,{timeout:12000}).toBe(true);expect((await state(page)).backstage.clean_corridor).toBe(false);
 await expect.poll(async()=>(await state(page)).backstage.exit_angle).toBeGreaterThan(1.45);
 await qa(page,{op:'warp',x:-11.1,z:9.4,yaw:Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]<-12.3);await page.screenshot({path:join(tmpdir(),'after-play-v270-web-exit.png')});
 await page.keyboard.press('Escape');await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).backstage.exit_finished).toBe(true);expect((await state(page)).backstage.exit_open).toBe(true);expect((await state(page)).position[0]).toBeLessThan(-12.2);await walk(page,'s',s=>s.position[0]>-9.8);
});

test('v2.7 hanging costume and seated guest react in 3D; the costume remains changed when the shift resumes',async({page})=>{
 test.setTimeout(120000);await begin(page);await qa(page,{op:'choose',red:false});await expect.poll(async()=>(await state(page)).phase).toBe('play');
 await qa(page,{op:'anomaly',id:'costume_wakes'});await qa(page,{op:'warp',x:16.15,y:.2,z:-15.1,yaw:0,pitch:.15});await expect.poll(async()=>(await state(page)).backstage.costume_triggered).toBe(true);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const frozen=(await state(page)).backstage.costume_attack;await page.waitForTimeout(400);expect((await state(page)).backstage.costume_attack).toBe(frozen);
 expect((await state(page)).backstage.costume_paused).toBe(true);await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
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
 await qa(page,{op:'anomaly',id:'party_portrait'});await qa(page,{op:'warp',x:9.3,z:-2.15,yaw:Math.PI,pitch:0});
 await expect.poll(async()=>(await state(page)).terrors.triggered).toBe(true);expect((await state(page)).terrors.position[0]).toBeGreaterThan(8.5);expect((await state(page)).terrors.position[2]).toBeLessThan(1.485);
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
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');await expect.poll(async()=>(await state(page)).streak).toBe(1);expect((await state(page)).position[1]).toBeGreaterThan(-.2);
});

test('v2.8 real corridors return through the entrance elevator; death resets; thirteen rounds finish at ending 1 with credits',async({page})=>{
 // Full patrol, death, two credit sequences and cold page reloads in one flow.
 test.setTimeout(450000);await begin(page);
 expect((await state(page)).visited).toEqual([]);
 await qa(page,{op:'warp',x:-4.3,z:-10.5,yaw:0});await expect.poll(async()=>(await state(page)).target).toBe('green');await page.keyboard.press('e');
 await page.waitForTimeout(750);await qa(page,{op:'audit'});expect((await state(page)).layout.door_obstructions).toEqual([]);
 await page.screenshot({path:join(tmpdir(),'after-play-v291-web-open-green.png')});
 expect((await state(page)).streak).toBe(0);await walk(page,'w',s=>s.position[2]<-15.1);
 const position=(await state(page)).position;expect((await state(page)).passage.chosen).toBe(0);
 await page.keyboard.press('Escape');await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 expect((await state(page)).passage.chosen).toBe(0);expect((await state(page)).position[2]).toBeCloseTo(position[2],1);
 await page.screenshot({path:join(tmpdir(),'after-play-v280-web-corridor.png')});await walk(page,'w',s=>s.phase==='lift');
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');expect((await state(page)).streak).toBe(1);expect((await state(page)).position[2]).toBeGreaterThan(19);
 await qa(page,{op:'anomaly',id:'balls_float'});await doorTrip(page,true);expect((await state(page)).streak).toBe(2);
 await qa(page,{op:'anomaly',id:'balls_float'});await doorTrip(page,false,{wrong:true});expect((await state(page)).failure.running).toBe(true);
 await page.waitForTimeout(150);await page.screenshot({path:join(tmpdir(),'after-play-v280-web-attacker.png')});
 await expect.poll(async()=>(await state(page)).death_text,{intervals:[30]}).toBe('2 Runden überlebt');await page.screenshot({path:join(tmpdir(),'after-play-v280-web-death.png')});
 await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe('play');expect((await state(page)).streak).toBe(0);expect((await state(page)).rounds).toBe(0);expect((await state(page)).intro.stage).toBe('done');
 expect((await state(page)).failure.count).toBe(1);await page.screenshot({path:join(tmpdir(),'after-play-v280-web-wake.png')});
 let anomalyRounds=0;
 for(let i=0;i<13;i++){
  const anomalous=(await state(page)).anomaly!=='none';anomalyRounds+=Number(anomalous);
  if([1,3,5,8,11].includes(i+1))expect(anomalous).toBe(false);
  await qa(page,{op:'choose',red:anomalous});await expect.poll(async()=>(await state(page)).phase,{timeout:30000}).toBe(i===12?'ending':'play');expect((await state(page)).streak).toBe(i+1);
 }
 expect(anomalyRounds).toBe(6);
 expect((await state(page)).completed).toBe(true);expect((await state(page)).ending_credits.title).toBe('ENDE 1/3');expect((await state(page)).ending_credits.second_end_hint).toBe('schau dich für Ende 2 nochmal genauer um in Runde 3,5,8 und 11');
 await expect.poll(async()=>(await state(page)).ending_credits.end_word).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-ending-1.png')});
 await expect.poll(async()=>(await state(page)).ending_credits.music,{timeout:30000,intervals:[70]}).toBe(true);expect((await state(page)).ending_credits.music_track).toBe('res://assets/music-v371/fern-and-feather.mp3');
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:25000}).toBe(true);}finally{await page.keyboard.up('Space');}
 expect((await state(page)).phase).toBe('ending');expect((await state(page)).streak).toBe(13);await page.screenshot({path:join(tmpdir(),'after-play-v2121-web-ending-1-clue.png')});
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('ending');expect((await state(page)).ending_credits.ending).toBe(1);expect((await state(page)).streak).toBe(13);
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:25000}).toBe(true);}finally{await page.keyboard.up('Space');}
 await clickControl(page,'Neue Nachtschicht');await skipIntro(page);expect((await state(page)).streak).toBe(0);expect((await state(page)).completed).toBe(false);
});

test('pause freezes movement and real settings controls persist volume after reload',async({page})=>{
 await begin(page);await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');
 const position=(await state(page)).position;await page.keyboard.down('w');await page.waitForTimeout(400);await page.keyboard.up('w');expect((await state(page)).position).toEqual(position);
 await qa(page,{op:'menu'});await page.waitForTimeout(100);await clickControl(page,'Einstellungen');await expect.poll(async()=>(await state(page)).phase).toBe('settings');await page.waitForTimeout(100);
 await clickControl(page,'Audio');await clickControl(page,'Lautstärke');await page.keyboard.press('Home');await expect.poll(async()=>(await state(page)).volume).toBe(0);await page.screenshot({path:join(tmpdir(),'nachtwache-settings-desktop.png')});await clickControl(page,'Zurück');await expect.poll(async()=>(await state(page)).phase).toBe('menu');await page.waitForTimeout(400);await page.reload();await waitForMenu(page);await expect.poll(async()=>(await state(page)).volume).toBe(0);
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
 const frame=page.frames().find(f=>f.url().includes('/standalone/kinderparadies/'));await frame.waitForFunction(()=>window.nachtwacheStatus?.phase==='warning',null,{timeout:60000});expect(await frame.evaluate(()=>typeof window.nachtwacheQA)).toBe('undefined');expect(await frame.evaluate(()=>'anomaly' in window.nachtwacheStatus)).toBe(false);
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
 test.setTimeout(240000);await begin(page);await page.mouse.click(768,512);
 await qa(page,{op:'warp',x:-7.9,z:-10.3,yaw:0});await walk(page,'w',s=>s.position[2]<-29.4);
 await qa(page,{op:'look',yaw:Math.PI/2});await walk(page,'w',s=>s.position[0]<-12);
 expect((await state(page)).visited).toContain('Küche');expect((await state(page)).anomaly).toBe('none');expect((await state(page)).annex.stirring).toBe(true);expect((await state(page)).encounter.triggered).toBe(false);
 await qa(page,{op:'warp',x:-12.2,z:-30.0,yaw:1.1,pitch:.09});await page.waitForTimeout(700);await page.screenshot({path:join(tmpdir(),'nachtwache-v170-web-kitchen.png')});
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const clock=(await state(page)).annex.clock;await page.waitForTimeout(500);expect((await state(page)).annex.clock).toBe(clock);
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');expect((await state(page)).position[0]).toBeLessThan(-11.5);expect((await state(page)).position[2]).toBeLessThan(-29);
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
 const room=(await state(page)).room_horror;expect(room.track).toBe('res://assets/party/musicbox.mp3');expect(room.creature).toBe(true);expect(room.panels).toBeGreaterThan(100);expect(room.creature_geometry.width).toBeLessThan(.8);expect(room.creature_geometry.bodyless).toBe(true);expect(room.horse.source[1]).toBeGreaterThan(3.9);expect(room.shaft_depth).toBeGreaterThan(1);
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
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('intro');expect((await state(page)).intro.stage).toBe('ringing');
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
 await page.reload();await waitForMenu(page);expect((await state(page)).settings.fov).toBe(100);expect((await state(page)).volume).toBe(0);expect((await state(page)).menu_prank.count).toBe(0);
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
  if(paper.id==='opening'){await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).archive.collected).toEqual(['note','opening']);expect((await snapshot()).archive.stage).toBe(3);expect((await snapshot()).anomaly).toBe('none');expect((await snapshot()).archive.spawned).toEqual([]);}
 }
 await lookAt([-8.6,0,-9.9],[-10.1,1.3,-9.9]);await expect.poll(async()=>(await snapshot()).target).toBe('archive_door');await page.keyboard.press('e');await expect.poll(async()=>(await snapshot()).phase).toBe('code');await page.keyboard.press('Control+a');await page.keyboard.type('7428');await expect.poll(async()=>(await snapshot()).archive_input).toBe('7428');await page.keyboard.press('Enter');await page.waitForTimeout(150);expect((await snapshot()).archive.unlocked).toBe(false);
 await page.keyboard.press('Control+a');await page.keyboard.type('6428');await expect.poll(async()=>(await snapshot()).archive_input).toBe('6428');await page.keyboard.press('Enter');await expect.poll(async()=>(await snapshot()).phase).toBe('play');await expect.poll(async()=>(await snapshot()).archive.angle).toBeLessThan(-1.7);
 await qa(page,{op:'warp',x:-8.7,z:-9.9,yaw:Math.PI/2});await walk(page,'w',s=>s.position[0]<-11.5);await page.keyboard.press('Escape');await expect.poll(async()=>(await snapshot()).phase).toBe('pause');await page.waitForTimeout(300);await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).archive.unlocked).toBe(true);expect((await snapshot()).position[0]).toBeLessThan(-11.5);
 await take('casefile',[-13.8,0,-9.05]);await page.keyboard.press('Tab');await expect.poll(async()=>(await snapshot()).phase).toBe('inventory');expect((await snapshot()).archive_reader).toBe('casefile');await page.screenshot({path:join(tmpdir(),'after-play-web-archive-record.png')});await page.keyboard.press('Escape');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).streak).toBe(10);
 await qa(page,{op:'warp',x:-12.8,z:-9.9,yaw:-Math.PI/2});await walk(page,'w',s=>s.position[0]>-9.8);
 const current=await snapshot();await qa(page,{op:'choose',red:current.anomaly==='none'});await expect.poll(async()=>(await snapshot()).phase,{timeout:30000}).toBe('play');expect((await snapshot()).archive.collected).toEqual([]);expect((await snapshot()).archive.unlocked).toBe(false);expect((await snapshot()).archive.stage).toBe(1);
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await snapshot()).phase).toBe('play');expect((await snapshot()).archive.collected).toEqual([]);expect((await snapshot()).archive.spawned.map(s=>s.id)).toEqual(['note']);
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
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).position[0]).toBeLessThan(-12);expect(Math.abs((await state(page)).position[2]-inside[2])).toBeLessThan(.1);
 await qa(page,{op:'warp',x:-12.1,z:-5.4,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>-9.6);
 for(const shot of [{name:'croc-body',x:17.8,z:15.9,yaw:.83,pitch:-.04},{name:'kitchen-sink',x:-15.25,z:-28.1,yaw:1.19,pitch:-.36},{name:'ball-pit',x:.2,z:10.7,yaw:-.2,pitch:-.31}]){await qa(page,{op:'warp',...shot});await page.waitForTimeout(550);await page.screenshot({path:join(tmpdir(),'after-play-v21-web-'+shot.name+'.png')});}
});

test('0712 opens the archive immediately; E plays Marelle, reload resumes it and turning back after its end reveals the chef and credits',async({page})=>{
 test.setTimeout(300000);await begin(page);
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
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');expect(await page.evaluate(()=>JSON.parse(localStorage.getItem('after-play:qa-nachtwache-save.json')).archive.recording_position)).toBeGreaterThan(117);await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('play');
 expect((await state(page)).archive.creator_access).toBe(true);await expect.poll(async()=>(await state(page)).archive.finale.position).toBeGreaterThan(117);expect((await state(page)).archive.finale.position).toBeLessThan(123);expect((await state(page)).archive.recording_locked).toBe(true);expect((await state(page)).archive.angle).toBe(0);
 await aim([-11.3,0,-9.9],[-10.2,1.5,-9.9]);await qa(page,{op:'recording_seek',time:(await state(page)).archive.finale.duration-.12});await expect.poll(async()=>(await state(page)).archive.finale.state).toBe('armed');expect((await state(page)).phase).toBe('play');expect((await state(page)).archive.recording_locked).toBe(false);await expect.poll(async()=>(await state(page)).archive.angle).toBeLessThan(-1.7);
 await aim([-11.3,0,-9.9],[-14,1.3,-9.9]);await expect.poll(async()=>(await state(page)).archive.finale.looked_away).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v220-web-remains.png')});
 await aim([-11.3,0,-9.9],[-10.2,1.5,-9.9]);await expect.poll(async()=>(await state(page)).phase,{intervals:[20]}).toBe('archive_scare');await page.waitForTimeout(180);await page.screenshot({path:join(tmpdir(),'after-play-v220-web-chef-scare.png')});
 await expect.poll(async()=>(await state(page)).phase).toBe('ending');await expect.poll(async()=>(await state(page)).ending_credits.end_word).toBe(true);await page.screenshot({path:join(tmpdir(),'after-play-v220-web-ende.png')});
 expect((await state(page)).ending_credits.title).toBe('ENDE 2/3');expect((await state(page)).ending_credits.second_end_hint).toBe('');
 expect((await state(page)).archive.finale.triggers).toBe(1);await expect.poll(async()=>(await state(page)).ending_credits.stage).toBe('credits');await expect.poll(async()=>(await state(page)).ending_credits.music).toBe(true);const credits=(await state(page)).ending_credits;expect(credits.music_track).toBe('res://assets/music-v371/fern-and-feather.mp3');expect(credits.author).toBe('Kyoko');expect(credits.ideas).toBe('einsmarello');expect(credits.testers).toEqual(['einsmarello','__jerry__','gingerbread','Mozart']);
 await page.keyboard.down('Space');try{await expect.poll(async()=>(await state(page)).ending_credits.stage,{timeout:10000}).toBe('last_look');}finally{await page.keyboard.up('Space');}
 await expect.poll(async()=>(await state(page)).ending_credits.afterglow.clock,{timeout:10000}).toBeGreaterThan(2.5);
 expect((await state(page)).ending_credits.music).toBe(true);expect((await state(page)).life.hum).toBe(false);
 await page.screenshot({path:join(tmpdir(),'after-play-v2110-web-last-look.png')});
 await expect.poll(async()=>(await state(page)).ending_credits.done,{timeout:25000}).toBe(true);expect((await state(page)).ending_credits.music).toBe(false);
 await clickControl(page,'Hauptmenü');await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('ending');expect((await state(page)).archive.finale.triggers).toBe(0);
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');await expect.poll(async()=>(await state(page)).phase).toBe('ending');expect((await state(page)).archive.finale.triggers).toBe(0);
});


test('v2.6 exact Dienstanweisung, party-only mascot and manufactured kitchen render without blocked doors',async({page})=>{
 test.setTimeout(180000);await load(page);await clickControl(page,'Dienstanweisung');await expect.poll(async()=>(await state(page)).phase).toBe('help');
 const copy=(await state(page)).instructions.join('\n');expect(copy).toContain('13 Rundgänge. 13 mal der gleiche Raum...oder?...');expect(copy).toContain('Geräusche und vom Spieler selbst verschobene Gegenstände zählen natürlich nicht zu den Anomalien.');expect(copy).toContain('Sterueung');expect(copy).toContain('E: interagieren');expect(copy).toContain('F11: Vollbild');expect(copy).not.toContain('Küchenclown');expect(copy).not.toContain('Normal:');
 await page.screenshot({path:join(tmpdir(),'after-play-v260-instructions-web.png')});await clickControl(page,'Zurück');await clickControl(page,'Neue Nachtschicht');await skipIntro(page);expect((await state(page)).giant_mascots).toBe(1);
 await qa(page,{op:'warp',x:-10.5,z:-29.3,yaw:1.3,pitch:-.1});await page.waitForTimeout(500);await page.screenshot({path:join(tmpdir(),'after-play-v260-kitchen-web.png')});
 await qa(page,{op:'audit'});const audit=(await state(page)).layout;expect(audit.door_obstructions).toEqual([]);expect(audit.art_overlaps).toEqual([]);expect(audit.furniture_wall_intrusions).toEqual([]);
 await qa(page,{op:'anomaly',id:'cinema_aisle_rush'});await qa(page,{op:'warp',x:-1,z:-29.65,yaw:-Math.PI/2,pitch:-.1});
 await expect.poll(async()=>(await state(page)).terrors.triggered).toBe(true);expect((await state(page)).terrors.sound).toMatch(/\/revamp-v300\/charge-[123]\.wav$/);
 await page.keyboard.press('Escape');await expect.poll(async()=>(await state(page)).phase).toBe('pause');const scare=(await state(page)).terrors;await page.waitForTimeout(350);expect((await state(page)).terrors.position).toEqual(scare.position);expect((await state(page)).terrors.attack).toBe(scare.attack);expect(!scare.audio||scare.paused).toBe(true);
});


test('v2.9 environmental dressing has solid arcade cabinets, stable reference rooms, paused CRTs and a working green-door trip',async({page})=>{
 test.setTimeout(240000);await begin(page);await page.mouse.click(768,512);
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
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
 const continued=await state(page);expect(continued.streak).toBe(1);expect(continued.position[0]).toBeCloseTo(-6.2,1);expect(continued.position[2]).toBeCloseTo(8.5,1);

});

test('cinema aisles are walkable forwards and backwards without seat snags',async({page})=>{
 test.setTimeout(240000);await begin(page);
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
 await qa(page,{op:'pause'});await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');expect((await state(page)).film.owned).toBe(true);
 await qa(page,{op:'anomaly',id:'none'});expect((await state(page)).film.owned).toBe(true);expect((await state(page)).film.playing).toBe(false);
 await qa(page,{op:'audit'});expect((await state(page)).layout.door_obstructions).toEqual([]);expect((await state(page)).layout.art_overlaps).toEqual([]);
});

test('washroom is walkable and saved; ordinary ambience pauses and the corrected booth photo can be inspected',async({page})=>{
 test.setTimeout(150000);await begin(page);
 await qa(page,{op:'warp',x:18.3,z:7.8,yaw:-Math.PI/2,pitch:0});await walk(page,'w',s=>s.position[0]>21.2);
 expect((await state(page)).position[2]).toBeCloseTo(7.8,1);expect((await state(page)).anomaly).toBe('none');
 await page.keyboard.press('Escape');await page.waitForTimeout(100);const stopped=(await state(page)).life.clock;
 await page.waitForTimeout(400);expect((await state(page)).life.clock).toBe(stopped);expect((await state(page)).life.paused).toBe(true);
 await page.reload();await waitForMenu(page);await clickControl(page,'Schicht fortsetzen');
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
