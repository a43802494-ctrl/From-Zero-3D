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
    # Textured, skinned and genuinely animated glTF. Creative Commons BY 4.0.
    # Source and required attribution: assets/ATTRIBUTIONS.md.
    cesium = ROOT / 'assets/models/animated-npc/CesiumMan.glb'
    cesium.parent.mkdir(parents=True, exist_ok=True)
    if not cesium.exists() or cesium.stat().st_size < 10000:
        url='https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMan/glTF-Binary/CesiumMan.glb'
        req=urllib.request.Request(url,headers={'User-Agent':'FromZero-Godot-AssetFetcher/1.0'})
        with urllib.request.urlopen(req,timeout=90) as response:
            raw=response.read()
        if raw[:4] != b'glTF': raise ValueError('Invalid animated glb')
        cesium.write_bytes(raw)
        print('Fetched animated human',len(raw))
    print(f'3D models complete; fetched {count} files.')

if __name__=='__main__':
    download()


# CC0 detailed, real-world-scale assets by Innerscene (https://www.innerscene.com/).
# See assets/ATTRIBUTIONS.md. These are full 3D GLB meshes, not flat illustrations.
DETAILED_ASSETS = {
    "architecture/apartment-block": "four-storey-apartment-block-331e1924",
    "architecture/office-building": "three-storey-office-building-16b33ce5",
    "architecture/supermarket": "supermarket-building-52b858d3",
    "vehicles/white-sedan": "white-four-door-sedan-1f271353",
    "vehicles/red-sedan": "red-four-door-sedan-1d32e180",
    "vehicles/silver-hatchback": "silver-five-door-compact-hatchback-6bf4a878",
    "vehicles/pickup": "pickup-truck-da45aa3f",
    "people/sam-walk": "relaxed-walk-sam-3d-person-animated-732f1206",
    "people/harper-walk": "relaxed-walk-harper-3d-person-animated-b504cbac",
    "people/maya-locomotion": "locomotion-collection-maya-3d-person-animated-1499b2fd",
}

def download_detail_assets():
    import urllib.error
    for asset_id, slug in DETAILED_ASSETS.items():
        dest = ROOT / f'assets/models/realworld/{asset_id}.glb'
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists() and dest.stat().st_size > 100000:
            continue
        url = f'https://www.innerscene.com/api/library/{slug}/download'
        for attempt in range(3):
            try:
                request = urllib.request.Request(url, headers={
                    'User-Agent': 'Mozilla/5.0 FromZeroGame/0.7 (open-source CC0 asset loader)',
                    'Accept': 'application/octet-stream,*/*',
                })
                with urllib.request.urlopen(request, timeout=95) as response:
                    raw = response.read()
                if not raw.startswith(b'glTF') or len(raw) < 100000:
                    raise ValueError(f'Unexpected GLB response: {slug}, bytes={len(raw)}')
                dest.write_bytes(raw)
                print('RealWorldCC0:', asset_id, len(raw), 'bytes')
                break
            except Exception as ex:
                if attempt == 2:
                    raise RuntimeError(f'Asset fetch failed: {url}: {ex}') from ex
                time.sleep(3 * (attempt + 1))

if __name__ == '__main__':
    download_detail_assets()
