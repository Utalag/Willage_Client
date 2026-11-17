# Blender 5.3 headless: N variant hranatých kamenných kusů (low-poly „odštípnuté“ kvádry) do assets/kamen_XX.glb.
# Kostka 1 × 1 × 1 → 5–8 náhodných řezů rovinou (odštípnuté rohy a hrany) → mírný šum vrcholů → normalizace do krychle.
# spuštění: blender -b -P blender/kameny.py -- <výstupní složka> [počet]
import bpy, bmesh, sys, os, random, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]; count = int(argv[1]) if len(argv) > 1 else 8
os.makedirs(out, exist_ok=True)
for i in range(count):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rnd = random.Random(2000 + i)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for c in range(rnd.randint(8, 12)):
        # směr k náhodnému rohu nebo hraně, rovina ve vzdálenosti 0,32–0,46 od středu
        d = Vector((rnd.choice([-1, 1]) * rnd.uniform(0.3, 1), rnd.choice([-1, 1]) * rnd.uniform(0.3, 1), rnd.choice([-1, 1]) * rnd.uniform(0.3, 1))).normalized()
        dist = rnd.uniform(0.34, 0.5) * (abs(d.x) + abs(d.y) + abs(d.z)) * 0.62
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=d * dist, plane_no=d, clear_outer=True)
        cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut_edges:
            bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    # jemný šum vrcholů (ne na rovinách – jen posun celých vrcholů)
    for v in bm.verts:
        v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.06
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("kamen_%02d" % i)
    bm.to_mesh(me); bm.free()
    xs = [v.co.copy() for v in me.vertices]
    mn = [min(c[k] for c in xs) for k in range(3)]; mx = [max(c[k] for c in xs) for k in range(3)]
    for v in me.vertices:
        for k in range(3):
            v.co[k] = (v.co[k] - mn[k]) / (mx[k] - mn[k]) - 0.5
    for p in me.polygons:
        p.use_smooth = True   # hladké normály kvůli obrysu; fazety kreslí shader
    ob = bpy.data.objects.new("kamen_%02d" % i, me)
    bpy.context.collection.objects.link(ob)
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    path = os.path.join(out, "kamen_%02d.glb" % i)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_materials="NONE")
    print("KAMEN", path, len(me.polygons), "trojúhelníků")
