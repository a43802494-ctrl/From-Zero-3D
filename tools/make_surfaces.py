"""Generate seamless neutral micro-detail maps for the neighbourhood; no external font or art files."""
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np

ROOT=Path(__file__).resolve().parents[1]/'assets/textures'
ROOT.mkdir(parents=True, exist_ok=True)
SIZE=512
rng=np.random.default_rng(9031)

def noise(large_sigma, contrast=.12):
    coarse=rng.integers(0,256,(SIZE,SIZE),dtype=np.uint8)
    image=Image.fromarray(coarse,'L').filter(ImageFilter.GaussianBlur(large_sigma))
    pixels=np.asarray(image,dtype=np.float32)
    return (pixels-128)/128 * contrast

for name in ('asphalt','concrete','plaster','pavement','brick'):
    fine=rng.normal(0,.052,(SIZE,SIZE))
    broad=noise(24,.15)
    mid=noise(4,.11)
    map_v=np.clip(.84+fine+mid+broad, .25, 1)
    if name=='asphalt':
        particles=rng.uniform(0,1,(SIZE,SIZE))
        map_v=np.where(particles>.987,map_v*.52,map_v)
        map_v=np.where(particles<.02,np.minimum(map_v*1.25,1),map_v)
    if name=='concrete':
        map_v=np.clip(map_v-.04,0,1)
        for x in [2,255,510]: map_v[:,x:x+2]*=.75
        for y in [2,255,510]: map_v[y:y+2,:]*=.75
    if name=='pavement':
        for i in range(0,SIZE,96):
            map_v[i:i+3,:]*=.63
            map_v[:,i:i+3]*=.63
    if name=='brick':
        for row in range(0,SIZE,45):
            map_v[row:row+3,:]*=.52
            shift=52 if row//45%2 else 0
            for x in range(-shift,SIZE,105):
                map_v[row:row+45,max(x,0):min(x+3,SIZE)]*=.60
        map_v=np.clip(map_v+.08,0,1)
    if name=='plaster':
        map_v=np.clip(map_v+.01,0,1)
    arr=np.uint8(np.clip(map_v*255,0,255))
    Image.fromarray(arr,'L').convert('RGB').save(ROOT/f'{name}_albedo.png', optimize=True)
    y,x=np.gradient(map_v.astype(np.float32))
    v=np.stack([-x*2.8,-y*2.8,np.ones_like(x)],axis=-1)
    v/=np.linalg.norm(v,axis=-1,keepdims=True)
    nm=(v*.5+.5)*255
    Image.fromarray(np.clip(nm,0,255).astype(np.uint8),'RGB').save(ROOT/f'{name}_normal.png',optimize=True)
    print(name,(ROOT/f'{name}_albedo.png').stat().st_size)
