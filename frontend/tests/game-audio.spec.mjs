import {test,expect} from '@playwright/test';

async function watchAudio(page){
  await page.addInitScript(()=>{
    window.sampleProof={oscillators:0,played:[]};
    const Context=window.AudioContext||window.webkitAudioContext,oscillator=Context.prototype.createOscillator,buffer=Context.prototype.createBufferSource;
    Context.prototype.createOscillator=function(...args){window.sampleProof.oscillators++;return oscillator.apply(this,args);};
    Context.prototype.createBufferSource=function(...args){const source=buffer.apply(this,args),start=source.start.bind(source);source.start=(...when)=>{if(source.buffer){const data=source.buffer.getChannelData(0);let energy=0;for(let i=0;i<data.length;i+=100)energy+=data[i]*data[i];window.sampleProof.played.push({duration:source.buffer.duration,energy,loop:source.loop});}return start(...when);};return source;};
    localStorage.setItem('pepple-survivor-settings-v1',JSON.stringify({audioOn:true,volume:.7,controlMode:'wasd'}));
  });
  await page.route('**/api/**',route=>route.fulfill({json:route.request().url().includes('auth/me')?{user:null}:[]}));
}

test('Survivor plays decoded weapon samples, no oscillator melody or MP3 loop, mute stops audio',async({page})=>{
  await watchAudio(page);const music=[];page.on('request',request=>{if(request.url().endsWith('.mp3'))music.push(request.url());});
  await page.goto('/#games/braincell-survivor');await page.getByRole('button',{name:'Spiel starten',exact:true}).click();
  await page.locator('.survivorCanvas').evaluate(canvas=>{const g=canvas.__survivorGame;g.state.obstacles=[];g.state.player.invuln=60000;g.state.weapons.rail=8;g.state.weapons.comet=8;g.state.weapons.laser=8;g.spawnBoss();});
  await page.keyboard.down('d');
  await expect.poll(()=>page.evaluate(()=>window.sampleProof.played.length)).toBeGreaterThan(3);
  await page.keyboard.up('d');
  const proof=await page.evaluate(()=>window.sampleProof);expect(proof.oscillators).toBe(0);expect(proof.played.some(p=>p.energy>0&&p.duration>.1&&!p.loop)).toBe(true);expect(music).toEqual([]);
  await page.getByRole('button',{name:'Sound ausschalten',exact:true}).click();
  await page.waitForTimeout(200);const count=await page.evaluate(()=>window.sampleProof.played.length);await page.waitForTimeout(500);expect(await page.evaluate(()=>window.sampleProof.played.length)).toBe(count);
});

test('Pinball uses quiet impact files and has zero continuous rolling oscillator; held flipper no longer powers a rescue',async({page})=>{
  await watchAudio(page);await page.goto('/#games/chicken-flipper');await page.getByRole('button',{name:'Spiel starten',exact:true}).click();await page.keyboard.press('Space');
  const state=await page.locator('.pinballMount').evaluate(async node=>{
    const g=node.__pinballGame;g.paused=true;await g.audio.samples.load('bumper');g.audio.play('bumper');
    const ball=g.balls[0],flipper=g.flippers[0],item=[...g.contacts.values()].find(i=>i.kind==='flipper'&&i.flipper===flipper);
    g.keys.left=true;flipper.moving=false;flipper.angle=flipper.active;ball.body.setTranslation({x:-.55,y:.15,z:2.8},true);ball.body.setLinvel({x:0,y:0,z:3},true);item.lastHit=-100;g.contact(ball,item);const held=ball.body.linvel().z;
    flipper.moving=true;item.lastHit=-100;g.contact(ball,item);return {held,timed:ball.body.linvel().z,gravity:g.world.gravity.z,length:flipper.len,save:g.saveUntil-g.time};
  });
  expect(state.held).toBe(3);expect(state.timed).toBeLessThan(-8);expect(state.gravity).toBe(4.2);expect(state.length).toBe(.9);expect(state.save).toBeLessThanOrEqual(2.5);
  await expect.poll(()=>page.evaluate(()=>window.sampleProof.played.length)).toBeGreaterThan(0);
  const proof=await page.evaluate(()=>window.sampleProof);expect(proof.oscillators).toBe(0);expect(proof.played.every(p=>!p.loop)).toBe(true);
});
