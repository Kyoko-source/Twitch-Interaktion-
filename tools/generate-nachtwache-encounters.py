"""Original non-musical horror foley; deterministic PCM, no copyrighted samples."""
import math, random, struct, wave
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/'games/kinderparadies/assets'
RATE=24000

def write(name,seconds,sample,loop=False):
    rng=random.Random(1303);data=[];previous=0
    for i in range(int(RATE*seconds)):
        t=i/RATE;n=rng.uniform(-1,1);previous=previous*.86+n*.14
        v=sample(t,n,previous)
        if not loop:v*=min(1,t/.007)*min(1,(seconds-t)/.04)
        data.append(max(-.85,min(.85,v)))
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(b''.join(struct.pack('<h',round(v*32767)) for v in data))

write('rabbit-scare',1.5,lambda t,n,low:(n*.22+low*.7)*math.exp(-t*5)+math.sin(math.tau*(310*t+85*t*t+5*math.sin(t*39)))*.22*math.exp(-t*2.7)+math.sin(math.tau*61*t)*.28*math.exp(-t*8))
write('croc-snap',1.5,lambda t,n,low:n*.38*math.exp(-t*14)+low*.8*math.exp(-t*3)+math.sin(math.tau*(48*t+9*(1-math.exp(-t*8))))*.3*math.exp(-t*4))
write('party-burst',1,lambda t,n,low:n*.65*math.exp(-t*33)+low*.65*math.exp(-t*5))
write('fan',4,lambda t,n,low:low*.21+math.sin(math.tau*48*t)*.035+math.sin(math.tau*96*t)*.012,True)
print('Generated 4 original foley files')
