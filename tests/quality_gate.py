from pathlib import Path
root=Path(__file__).resolve().parents[1]
read=lambda name:(root/name).read_text(encoding="utf8")
assert 'realworld/vehicles' in read('scripts/world.gd')
assert 'realworld/people' in read('scripts/world.gd')
assert 'realworld/architecture' in read('scripts/world.gd')
assert 'build_service_desk' in read('scripts/world.gd')
assert 'TorusMesh.new()' in read('scripts/game.gd')
assert 'حفظ ورجوع' in read('scripts/hud.gd')
assert 'LAYOUT_DIRECTION_LTR' in read('scripts/hud.gd')
assert 'screen_pos.x < viewport.x * 0.38' in read('scripts/stick.gd')
print('SOURCE ART/DESIGN/ARABIC/CAMERA/CONTROLS CHECK: PASS')
