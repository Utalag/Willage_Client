using Godot;
using Willage.Gen.Api.Dto;

namespace WillagePrototyp.Jadro.Adaptery;

/// <summary>G-4: RezDto → ArrayMesh – svislý profil povrchu (pás trojúhelníků od podlahy po povrch), osa X = vzdálenost, Y = výška.</summary>
public static class SitRezu
{
    public static ArrayMesh Sit(RezDto r, float podlahaM = 0f)
    {
        int n = r.PovrchM.Length;
        var v = new Vector3[2 * n];
        for (int i = 0; i < n; i++)
        {
            float x = (float)(i * r.KrokM);
            v[2 * i] = new Vector3(x, podlahaM, 0); v[2 * i + 1] = new Vector3(x, (float)r.PovrchM[i], 0);
        }
        var a = new Godot.Collections.Array(); a.Resize((int)Mesh.ArrayType.Max);
        a[(int)Mesh.ArrayType.Vertex] = v;
        var m = new ArrayMesh();
        if (n >= 2) m.AddSurfaceFromArrays(Mesh.PrimitiveType.TriangleStrip, a);
        return m;
    }
}
