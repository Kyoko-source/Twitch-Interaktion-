import test from 'node:test';
import assert from 'node:assert/strict';
import {pressureVisuals} from './pressure.js';

test('pressure increases throughout each mission and blur builds in its final two minutes',()=>{
  for(const duration of [360,480,540]){
    let previous=pressureVisuals({remaining:duration,duration,running:true});
    assert.equal(previous.blur,0);
    for(let remaining=duration-1;remaining>0;remaining--){
      const current=pressureVisuals({remaining,duration,running:true});
      assert.ok(current.intensity>previous.intensity);assert.ok(current.period<previous.period);
      assert.ok(current.blur>=previous.blur&&current.blur<=2.4);previous=current;
    }
  }
});
test('a calming pill clears blur while preserving the time-pressure warning',()=>{
  const stressed=pressureVisuals({remaining:10,duration:540,running:true});
  const calm=pressureVisuals({remaining:10,duration:540,running:true,calm:30});
  assert.ok(stressed.blur>2);assert.equal(calm.blur,0);assert.equal(calm.intensity,stressed.intensity);
});
test('paused, completed and expired missions have no pressure effect',()=>{
  for(const options of [{remaining:5,running:false},{remaining:0,running:true}]){
    const state=pressureVisuals(options);assert.equal(state.intensity,0);assert.equal(state.blur,0);
  }
});
