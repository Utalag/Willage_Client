# Blender (bpy) bez okna: kawaii stavby -> ../assets/studna.glb, mlyn.glb, pole.glb
# Vchod/přední strana je na −Y (v Godotu +Z), stejně jako domek. Spuštění: blender -b --python stavby.py
import bpy, os, math

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.9
    return m

def bevel(o, w, seg=2):
    if w:
        mod = o.modifiers.new("bevel", "BEVEL"); mod.width = w; mod.segments = seg
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="bevel")

def box(size, loc, m, bv=0.04, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    bevel(o, bv)
    o.data.materials.append(m)
    return o

def cyl(r, h, loc, m, verts=16, r2=None, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.data.materials.append(m)
    return o

def export(name):
    p = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=p, export_format="GLB", export_apply=True)
    print("EXPORT OK", p)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# ---- studna (1 × 1)
reset()
stone = mat("kamen", (0.80, 0.78, 0.86)); wood = mat("drevo", (0.62, 0.45, 0.36))
roof = mat("strecha", (0.55, 0.72, 0.95)); water = mat("voda", (0.45, 0.78, 0.95))
cyl(0.42, 0.45, (0, 0, 0.225), stone, 20)
cyl(0.32, 0.05, (0, 0, 0.42), water, 20)
for x in (-0.36, 0.36):
    box((0.07, 0.07, 0.75), (x, 0, 0.8), wood, 0.01)
box((0.8, 0.06, 0.06), (0, 0, 0.95), wood, 0.01)
cyl(0.62, 0.38, (0, 0, 1.33), roof, 4, r2=0.02, rot=(0, 0, math.pi / 4))
box((0.12, 0.14, 0.12), (0, 0, 0.78), wood, 0.02)   # vědro
export("studna")

# ---- větrný mlýn (3 × 3)
reset()
wall = mat("stena", (0.98, 0.93, 0.84)); roof = mat("strecha", (0.93, 0.52, 0.62))
wood = mat("drevo", (0.62, 0.45, 0.36)); sail = mat("plachta", (1.0, 0.97, 0.92))
cyl(1.05, 2.6, (0, 0, 1.3), wall, 20, r2=0.8)
cyl(0.95, 1.0, (0, 0, 3.1), roof, 20, r2=0.05)
box((0.55, 0.1, 0.95), (0, -1.0, 0.48), wood, 0.02, rot=(math.radians(-8), 0, 0))
box((0.4, 0.1, 0.4), (0, -0.92, 1.7), mat("okno", (0.62, 0.82, 0.95)), 0.02, rot=(math.radians(-6), 0, 0))
cyl(0.12, 0.5, (0, -0.95, 2.6), wood, 10, rot=(math.pi / 2, 0, 0))
for k in range(4):
    a = k * math.pi / 2 + math.pi / 4
    c = (math.cos(a) * 0.85, -1.2, 2.6 + math.sin(a) * 0.85)
    box((0.08, 0.05, 1.7), c, wood, 0.01, rot=(0, -a + math.pi / 2, 0))
    c2 = (math.cos(a) * 0.95 + math.cos(a + math.pi / 2) * 0.18, -1.22, 2.6 + math.sin(a) * 0.95 + math.sin(a + math.pi / 2) * 0.18)
    box((0.32, 0.03, 1.2), c2, sail, 0.01, rot=(0, -a + math.pi / 2, 0))
export("mlyn")

# ---- políčko (3 × 3): záhony s plodinami, plůtek, vstup vpředu
reset()
soil = mat("hlina", (0.70, 0.52, 0.42)); leaf = mat("list", (0.55, 0.85, 0.50))
fruit = mat("plod", (1.0, 0.62, 0.42)); fence = mat("plot", (0.95, 0.88, 0.76))
for i, x in enumerate((-0.9, 0.0, 0.9)):
    box((0.7, 2.5, 0.14), (x, 0.1, 0.07), soil, 0.05)
    for j in range(5):
        y = -1.0 + j * 0.5 + 0.1
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.16, location=(x, y, 0.25))
        o = bpy.context.active_object; o.data.materials.append(leaf if (i + j) % 3 else fruit)
for s in (-1, 1):
    box((0.06, 2.9, 0.08), (s * 1.42, 0.05, 0.32), fence, 0.01)
    box((0.06, 2.9, 0.08), (s * 1.42, 0.05, 0.16), fence, 0.01)
box((2.9, 0.06, 0.08), (0, 1.48, 0.32), fence, 0.01)
for x in (-1.42, -0.5, 0.5, 1.42):
    box((0.1, 0.1, 0.45), (x, 1.48, 0.22), fence, 0.02)
for x in (-1.42, -0.5, 0.5, 1.42):
    box((0.1, 0.1, 0.45), (x, -1.42, 0.22), fence, 0.02)
for s in (-1, 1):   # přední plůtek s mezerou uprostřed
    box((0.95, 0.06, 0.08), (s * 0.96, -1.42, 0.32), fence, 0.01)
export("pole")
