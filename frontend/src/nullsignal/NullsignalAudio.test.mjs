import test from 'node:test';
import assert from 'node:assert/strict';
import {countdownInterval} from './NullsignalAudio.js';

test('countdown has a steady pulse from mission start, then faster tiers at 60 and 30 seconds',()=>{
  assert.equal(countdownInterval(540),1);assert.equal(countdownInterval(61),1);
  assert.equal(countdownInterval(60),.5);assert.equal(countdownInterval(31),.5);
  assert.ok(countdownInterval(30)<countdownInterval(31));
  let previous=countdownInterval(30);
  for(let seconds=29;seconds>0;seconds--){const current=countdownInterval(seconds);assert.ok(current<previous);previous=current;}
});
test('every mistake accelerates every time tier without unbounded overlapping beeps',()=>{
  for(const remaining of [540,61,60,31,30,15,5,1,.01]){
    assert.ok(countdownInterval(remaining,1)<countdownInterval(remaining,0));
    assert.ok(countdownInterval(remaining,2)<=countdownInterval(remaining,1));
    assert.ok(countdownInterval(remaining,2)>=.05);
  }
});
test('expired and invalid countdowns do not schedule any beep',()=>{
  for(const remaining of [0,-1,NaN,Infinity])assert.equal(countdownInterval(remaining,2),Infinity);
});
