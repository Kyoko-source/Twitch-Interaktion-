import test from 'node:test';
import assert from 'node:assert/strict';
import {atmosphereVisuals as visual} from './atmosphere.js';

test('outages last twelve active seconds, repeat with quiet gaps and stop outside play',()=>{
  for(const outage_start of [40,45,50]){
    const base={running:true,remaining:100,outage_start};
    assert.equal(visual({...base,played:outage_start-.01}).blackout,false);
    for(const n of [0,1,2]){
      assert.equal(visual({...base,played:outage_start+75*n}).blackout,true);
      assert.equal(visual({...base,played:outage_start+75*n+11.99}).blackout,true);
      assert.equal(visual({...base,played:outage_start+75*n+12}).blackout,false);
    }
    assert.equal(visual({...base,played:outage_start,running:false}).blackout,false);
  }
});
test('hallucinations need both sustained untreated stress and low remaining time; pills clear them',()=>{
  const base={running:true,remaining:50,played:130,untreated:130,scare_remaining:1,scare_id:'round'};
  assert.equal(visual(base).hallucination,1);assert.equal(visual(base).scare,true);
  for(const calm of [.01,30]){assert.equal(visual({...base,calm}).hallucination,0);assert.equal(visual({...base,calm}).scare,false);}
  assert.equal(visual({...base,untreated:50}).hallucination,0);
  assert.equal(visual({...base,remaining:120}).hallucination,0);
  assert.equal(visual({...base,running:false}).scare,false);
  assert.equal(visual({...base,remaining:0}).hallucination,0);
  assert.equal(visual({...base,scare_remaining:0}).scare,false);
});
