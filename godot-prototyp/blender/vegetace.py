# Blender (bpy) bez okna: kawaii low-poly vegetace -> ../assets/*.glb (každý model = jeden mesh, více materiálů)
# Spuštění: blender -b --python vegetace.py
import bpy, os, math

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

def mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 1.0
    return m

M = {
    "kmen": mat("kmen", (0.55, 0.38, 0.30)),
    "jehlici": mat("jehlici", (0.36, 0.68, 0.52)),
    "listi": mat("listi", (0.58, 0.84, 0.46)),
    "listi2": mat("listi2", (0.70, 0.88, 0.50)),
    "ker": mat("ker", (0.48, 0.76, 0.48)),
    "kvet": mat("kvet", (1.0, 0.62, 0.78)),
    "kaktus": mat("kaktus", (0.46, 0.74, 0.56)),
}

def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

def put(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    bpy.ops.object.shade_flat()
    return obj

def cyl(r, h, z, material, verts=8, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(0, 0, z + h / 2))
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=(0, 0, z + h / 2))
    return put(bpy.context.active_object, material)

def ball(r, loc, material, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    return put(bpy.context.active_object, material)

def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_apply=True)
    print("EXPORT", name)

# jehličnan: kmen + 3 kužely
clear()
cyl(0.16, 0.5, 0, M["kmen"])
for i, (r, h, z) in enumerate([(0.9, 1.0, 0.4), (0.7, 0.9, 0.95), (0.48, 0.8, 1.45)]):
    cyl(r, h, z, M["jehlici"], verts=8, r2=0.05)
export("jehlicnan")

# listnáč: kmen + kulaté koruny
clear()
cyl(0.17, 1.0, 0, M["kmen"])
ball(0.75, (0, 0, 1.55), M["listi"], 2)
ball(0.5, (0.45, 0.2, 1.25), M["listi2"], 2)
ball(0.45, (-0.4, -0.25, 1.3), M["listi2"], 2)
export("listnac")

# keř: tři koule + pár květů
clear()
ball(0.42, (0, 0, 0.3), M["ker"], 2)
ball(0.33, (0.35, 0.1, 0.24), M["ker"], 2)
ball(0.3, (-0.3, 0.15, 0.22), M["ker"], 2)
for p in [(0.15, -0.3, 0.55), (-0.25, -0.2, 0.45), (0.4, -0.15, 0.4)]:
    ball(0.07, p, M["kvet"], 1)
export("ker")

# kaktus: kmen + dvě ramena
clear()
cyl(0.2, 1.1, 0, M["kaktus"], verts=8)
ball(0.2, (0, 0, 1.1), M["kaktus"], 1)
for sgn, z, hh in [(1, 0.45, 0.4), (-1, 0.6, 0.3)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.12, depth=0.3, location=(sgn * 0.3, 0, z), rotation=(0, math.pi / 2, 0))
    put(bpy.context.active_object, M["kaktus"])
    cyl(0.12, hh, z, M["kaktus"], verts=8).location.x = sgn * 0.42
    ball(0.12, (sgn * 0.42, 0, z + hh), M["kaktus"], 1)
export("kaktus")
