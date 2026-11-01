"""Offline structural checks; does NOT replace the Godot CI smoke test."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
assert (root/'project.godot').is_file()
assert (root/'scenes/main.tscn').is_file()
assert (root/'export_presets.cfg').is_file()
assert (root/'.github/workflows/android.yml').is_file()
for path in list((root/'scripts').glob('*.gd')) + list((root/'scenes').glob('*.tscn')):
    data = path.read_text()
    assert not '\r' in data, path
    for res in re.findall(r'res://([\w./-]+)', data):
        assert (root/res).is_file(), f'{path}: missing res://{res}'
for ogg in (root/'audio').glob('*.ogg'):
    assert ogg.read_bytes().startswith(b'OggS') and ogg.stat().st_size > 500, ogg
source = (root/'scripts/game.gd').read_text()
assert 'ContractEconomy.payout' in source
assert 'save_progress()' in source
assert 'hud.update_radar' in source
assert 'hud.show_contract_board' in source
assert 'contract_seconds' in source
print(f'OFFLINE BUNDLE CHECKS PASS — {len(list((root/"scripts").glob("*.gd")))} scripts / {len(list((root/"audio").glob("*.ogg")))} sounds')
