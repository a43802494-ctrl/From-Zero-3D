"""Download pinned CC0 Kenney GLB models before importing/exporting the Godot project.
Original author: Kenney (https://kenney.nl), CC0 1.0.
Mirror: https://github.com/Hidencod/tge-assets. Do not claim ownership of assets.
"""
import pathlib
import urllib.request
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
PIN = 'd92c6e923bbef8649d4e5be3ab375a40f88672b0'
REMOTE = f'https://raw.githubusercontent.com/Hidencod/tge-assets/{PIN}/packs/'
ASSETS = {
  'city-kit-commercial': ['building-a','building-b','building-c','building-d','building-e','building-f','building-g','building-h','building-i','building-j','building-k','building-l','building-m','building-n','detail-awning','detail-awning-wide','detail-parasol-a','detail-parasol-b'],
  'city-kit-suburban': ['building-type-a','building-type-c','building-type-e','building-type-g','building-type-i','building-type-k','building-type-m','building-type-o','building-type-q','building-type-s','planter','tree-large','tree-small'],
  'city-kit-roads': ['light-curved','light-curved-double','traffic-light','road-sign-street','road-sign-stop','dumpster','construction-cone','construction-barrier','electricity-pole','road-sign-warning'],
  'car-kit': ['sedan','taxi','delivery','van','suv','hatchback-sports','truck'],
  'mini-characters': ['character-male-a','character-male-b','character-male-c','character-female-a','character-female-b','character-female-c'],
  'nature-kit': ['plant-bush','plant-bushdetailed','plant-bushlarge','pot-large','pot-small'],
}


def download():
    count = 0
    for pack, models in ASSETS.items():
        for model in models:
            relative = f'{pack}/{model}.glb'
            dest = ROOT / 'assets/models' / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.is_file() and dest.stat().st_size > 500:
                continue
            url = REMOTE + relative
            for attempt in range(3):
                try:
                    req = urllib.request.Request(url, headers={'User-Agent':'FromZero-Godot-AssetFetcher/1.0'})
                    with urllib.request.urlopen(req, timeout=45) as resp:
                        data = resp.read()
                    if data[:4] != b'glTF':
                        raise ValueError(f'Invalid glTF binary: {relative}')
                    dest.write_bytes(data)
                    print('Fetched',relative, len(data))
                    count += 1
                    break
                except Exception as exc:
                    if attempt == 2:
                        raise RuntimeError(f'Failed downloading {url}') from exc
                    time.sleep(2*(attempt+1))
    print(f'CC0 models complete; fetched {count} files.')

if __name__=='__main__':
    download()
