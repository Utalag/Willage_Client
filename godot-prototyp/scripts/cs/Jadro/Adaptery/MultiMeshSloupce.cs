using Godot;
using Willage.Gen.Api.Dto;

namespace WillagePrototyp.Jadro.Adaptery;

/// <summary>
/// G-4: SloupecDto → MultiMesh kostek 0,25 m (jedna instance na neprázdnou buňku, barva podle MaterialId). Vzduch = materiál 0.
/// Barva je zatím jen ladicí (hash id); vzhled z katalogu Dev (visualProfiles) přijde s oknem 2.
/// </summary>
public static class MultiMeshSloupce
{
    public const float BunkaM = 0.25f;

    public static MultiMesh Sloupec(SloupecDto s)
    {
        int n = 0; for (int z = 0; z < s.Pocet; z++) if (s.Material(z) != 0) n++;
        var mm = new MultiMesh { TransformFormat = MultiMesh.TransformFormatEnum.Transform3D, UseColors = true, Mesh = new BoxMesh { Size = Vector3.One * BunkaM } };
        mm.InstanceCount = n;
        int k = 0;
        for (int z = 0; z < s.Pocet; z++)
        {
            byte mat = s.Material(z); if (mat == 0) continue;
            mm.SetInstanceTransform(k, new Transform3D(Basis.Identity, new Vector3(0, (z + 0.5f) * BunkaM, 0)));
            mm.SetInstanceColor(k, Barva(mat));
            k++;
        }
        return mm;
    }

    public static Color Barva(byte mat)
    {
        uint h = Willage.Gen.Jadro.GeologyHash.HashInt3(mat, 0, 0, 0x6B4);
        return new Color((h & 0xFF) / 255f, ((h >> 8) & 0xFF) / 255f, ((h >> 16) & 0xFF) / 255f);
    }
}
