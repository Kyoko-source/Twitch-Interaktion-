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

test('Pinball plays real CC0 samples for parts and jingles, never an oscillator or looping buffer',async({page})=>{
  await watchAudio(page);await page.goto('/#games/chicken-flipper');
  await page.waitForFunction(()=>document.querySelector('.pbStage')?.__pinball?.renderer?.composer,null,{timeout:30000});
  await page.getByRole('button',{name:'Übungsrunde starten',exact:true}).click();
  await page.locator('.pbStage').evaluate(async node=>{const s=node.__pinball;await s.audio.load('bumper-thump');await s.audio.load('jackpot');s.engine.emit('bumper',{index:0,x:4,y:5});s.engine.emit('jackpot',{value:1});});
  await page.keyboard.down('KeyA');await page.waitForTimeout(150);await page.keyboard.up('KeyA');
  await expect.poll(()=>page.evaluate(()=>window.sampleProof.played.length)).toBeGreaterThan(1);
  const proof=await page.evaluate(()=>window.sampleProof);expect(proof.oscillators).toBe(0);expect(proof.played.every(p=>!p.loop)).toBe(true);expect(proof.played.some(p=>p.energy>0)).toBe(true);
});
