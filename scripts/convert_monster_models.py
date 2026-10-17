# モンスターの 3D モデル（glTF）を、アプリで使う USDZ に変換する Blender のスクリプト
#
# 元のモデル：Quaternius「Ultimate Monsters」（CC0）の glTF/*.gltf
# 1 体ずつ変換する。全部変換するときは、たとえば次のように回す（Blender は `brew install --cask blender` で入る）
#
#   for f in Big/glTF/*.gltf; do
#     blender -b --factory-startup --python scripts/convert_monster_models.py -- "$f" "out/$(basename "$f" .gltf).usdz" "out/clips.json"
#   done
#
# 書き出した USDZ を ARApp/Resources/Models に `monster-<名前>.usdz`（例：MushroomKing → monster-mushroom-king）として置く
#
# USDZ はアニメーションを 1 本の流れとしてしか持てないので、14 種類のアニメーションを名前順に、間を 1 フレームあけて並べる
# 各アニメーションが何秒目から何秒目かを clips.json に書き出す。アプリはこの区間を切り出して流す（MonsterAnimation.swift）
# 区間は全モンスターで同じになる

import bpy
import json
import math
import sys

src, dst, clips_path = sys.argv[sys.argv.index("--") + 1:][:3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
fps = scene.render.fps

armature = next(o for o in scene.objects if o.type == 'ARMATURE')
# ボーンの見た目用に読み込まれる、どこにもつながっていないメッシュ（Icosphere など）は消す
for o in list(scene.objects):
    if o.type == 'MESH' and o.parent is None and not any(m.type == 'ARMATURE' for m in o.modifiers):
        bpy.data.objects.remove(o)

# glTF の各アニメーションは別々のトラックとして読み込まれるので、1 本のトラックに並べ直す
animation_data = armature.animation_data
animation_data.action = None
for track in list(animation_data.nla_tracks):
    animation_data.nla_tracks.remove(track)

track = animation_data.nla_tracks.new()
track.name = "All"
clips = []
cursor = 1
for action in sorted(bpy.data.actions, key=lambda a: a.name):
    first, last = action.frame_range
    length = math.ceil(last - first)
    strip = track.strips.new(action.name, cursor, action)
    if getattr(strip, "action_slot", None) is None and len(action.slots):
        strip.action_slot = action.slots[0]
    strip.action_frame_start = first
    strip.action_frame_end = first + length
    strip.frame_end = cursor + length
    strip.extrapolation = 'NOTHING'
    # USDZ の 1 フレーム目が、アプリでの 0 秒になる
    clips.append({"name": action.name, "start": (cursor - 1) / fps, "end": (cursor - 1 + length) / fps})
    # 次のアニメーションとの間を 1 フレームあけて、つなぎ目で前後のポーズが混ざらないようにする
    cursor += length + 1

scene.frame_start = 1
scene.frame_end = cursor - 1
# RealityKit に合わせて Y を上にする。モデルの正面（glTF の +Z）は、USDZ でも +Z になる
bpy.ops.wm.usd_export(
    filepath=dst,
    export_animation=True,
    export_armatures=True,
    only_deform_bones=True,
    export_materials=True,
    generate_preview_surface=True,
    convert_orientation=True,
    export_global_forward_selection='NEGATIVE_Z',
    export_global_up_selection='Y',
)
with open(clips_path, "w") as f:
    json.dump({"fps": fps, "clips": clips}, f, indent=1)
