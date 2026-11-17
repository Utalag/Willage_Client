# Blender (bpy) bez okna: jednoduchý pastelový domek se sedlovou střechou -> ../assets/domek.glb
# Spuštění: blender -b --python domek.py
import bpy, bmesh, os

bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.9
    return m

def box(name, size, loc, material, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier="bevel")
    o.data.materials.append(material)
    return o

wall = mat("stena", (0.98, 0.93, 0.84))
roof = mat("strecha", (0.93, 0.52, 0.62))
wood = mat("drevo", (0.62, 0.45, 0.36))
glass = mat("okno", (0.62, 0.82, 0.95))

W, D, H = 3.0, 2.6, 1.6          # šířka (x), hloubka (y), výška stěn; Blender je Z-nahoru
box("telo", (W, D, H), (0, 0, H / 2), wall)
# sedlová střecha (hřeben v ose x), lehce přesahuje
o = 0.25
rh = 1.3
me = bpy.data.meshes.new("strecha")
bm = bmesh.new()
v = [bm.verts.new(p) for p in [
    (-W/2 - o, -D/2 - o, H), (W/2 + o, -D/2 - o, H), (W/2 + o, 0, H + rh), (-W/2 - o, 0, H + rh),
    (-W/2 - o, D/2 + o, H), (W/2 + o, D/2 + o, H)]]
bm.faces.new([v[0], v[1], v[2], v[3]])
bm.faces.new([v[3], v[2], v[5], v[4]])
bm.faces.new([v[0], v[3], v[4]])
bm.faces.new([v[1], v[5], v[2]])
bm.faces.new([v[0], v[4], v[5], v[1]])
bm.normal_update()
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(me)
ro = bpy.data.objects.new("strecha", me)
bpy.context.collection.objects.link(ro)
sol = ro.modifiers.new("tloustka", "SOLIDIFY"); sol.thickness = 0.12
bpy.context.view_layer.objects.active = ro
ro.select_set(True)
bpy.ops.object.modifier_apply(modifier="tloustka")
me.materials.append(roof)
box("komin", (0.35, 0.35, 0.9), (0.8, 0.45, H + 0.9), wood, 0.03)
box("dvere", (0.6, 0.08, 1.0), (0, -D/2 - 0.02, 0.5), wood, 0.02)
box("okno_l", (0.5, 0.08, 0.5), (-0.95, -D/2 - 0.02, 0.95), glass, 0.02)
box("okno_p", (0.5, 0.08, 0.5), (0.95, -D/2 - 0.02, 0.95), glass, 0.02)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "domek.glb")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True)
print("EXPORT OK", out)
