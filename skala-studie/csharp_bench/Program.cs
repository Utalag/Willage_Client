// Benchmark horké smyčky přístupu C (rock_volume.gd) v C#: stejný algoritmus, stejné vstupy (buňky z Godotu),
// stejný šum (FastNoiseLite.cs, MIT, Jordan Peck [9]). Nepotřebuje Godot .NET – jen dotnet SDK.
// Spuštění: dotnet run -c Release -- hora7777.bin
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Numerics;

class Vol {
    public int nx = 32, nz = 32, ny = 64, chunk = 16;
    public byte[] cells;
    public float res = 2f, s, noiseAmp = 0.2f, ledges = 0.09f, jit = 0.04f;
    public Vector3 o = new Vector3(-1f, -0.25f, -1f), cell = new Vector3(0.5f);
    public int gx, gy, gz;
    public float[] d; public byte[] dok;
    public long[] col; public float[] blur; public byte[] blok;
    public int[] cubeVid, cubeStamp; public int stamp;
    public FastNoiseLite fn;
    public long tris, noiseSamples;

    public Vol(byte[] c, float r) {
        cells = c; res = r; s = 1f / res;
        gx = (int)((nx + 2) * res) + 1; gy = (int)((ny + 1.25f) * res) + 1; gz = (int)((nz + 2) * res) + 1;
        d = new float[gx * gy * gz]; dok = new byte[d.Length];
        int nc = (gx - 1) * (gy - 1) * (gz - 1); cubeVid = new int[nc]; cubeStamp = new int[nc];
        blur = new float[(nx + 2) * (ny + 2) * (nz + 2)]; blok = new byte[blur.Length];
        fn = new FastNoiseLite(7 + 17); fn.SetNoiseType(FastNoiseLite.NoiseType.OpenSimplex2S);
        fn.SetFrequency(0.9f); fn.SetFractalType(FastNoiseLite.FractalType.FBm); fn.SetFractalOctaves(2);
        col = new long[(nx + 2) * (nz + 2)];
        for (int x = 0; x < nx; x++) for (int z = 0; z < nz; z++) {
            long m = 0; int b = (x * nz + z) * ny;
            for (int y = 0; y < ny; y++) if (cells[b + y] != 0) m |= 1L << y;
            col[(x + 1) * (nz + 2) + z + 1] = m;
        }
    }
    long Col(int x, int z) => (x < -1 || z < -1 || x > nx || z > nz) ? 0 : col[(x + 1) * (nz + 2) + z + 1];
    float Blur(int x, int y, int z) {
        if (x < -1 || z < -1 || y < -1 || x > nx || z > nz || y > ny) return 0;
        int i = ((x + 1) * (nz + 2) + z + 1) * (ny + 2) + y + 1;
        if (blok[i] != 0) return blur[i];
        int a = 0;
        for (int dx = -1; dx <= 1; dx++) for (int dz = -1; dz <= 1; dz++) {
            long c = Col(x + dx, z + dz); if (c == 0) continue;
            for (int dy = -1; dy <= 1; dy++) { int yy = y + dy; if (yy < ny) a += (int)((c >> Math.Max(yy, 0)) & 1); }
        }
        blok[i] = 1; return blur[i] = a / 27f;
    }
    static float Sm(float f) => f * f * (3 - 2 * f);
    float Density(Vector3 p) {
        Vector3 q = p - new Vector3(0.5f);
        int cx = (int)MathF.Floor(q.X), cy = (int)MathF.Floor(q.Y), cz = (int)MathF.Floor(q.Z);
        long c00 = Col(cx, cz), c10 = Col(cx + 1, cz), c01 = Col(cx, cz + 1), c11 = Col(cx + 1, cz + 1);
        int y0 = Math.Max(cy, 0), y1 = Math.Max(cy + 1, 0);
        int lo = cy < ny ? 1 : 0, hi = cy + 1 < ny ? 1 : 0;
        int o000 = (int)((c00 >> y0) & 1) * lo, o100 = (int)((c10 >> y0) & 1) * lo, o001 = (int)((c01 >> y0) & 1) * lo, o101 = (int)((c11 >> y0) & 1) * lo;
        int o010 = (int)((c00 >> y1) & 1) * hi, o110 = (int)((c10 >> y1) & 1) * hi, o011 = (int)((c01 >> y1) & 1) * hi, o111 = (int)((c11 >> y1) & 1) * hi;
        int sum = o000 + o100 + o001 + o101 + o010 + o110 + o011 + o111;
        if (sum == 0) return -0.5f; if (sum == 8) return 0.5f;
        noiseSamples++;
        float fx = Sm(q.X - cx), fy = Sm(q.Y - cy), fz = Sm(q.Z - cz), gxv = 1 - fx, gyv = 1 - fy, gzv = 1 - fz;
        float v = gxv * gyv * gzv * o000 + fx * gyv * gzv * o100 + gxv * gyv * fz * o001 + fx * gyv * fz * o101
                + gxv * fy * gzv * o010 + fx * fy * gzv * o110 + gxv * fy * fz * o011 + fx * fy * fz * o111;
        float mass = gxv * gyv * gzv * Blur(cx, cy, cz) + fx * gyv * gzv * Blur(cx + 1, cy, cz) + gxv * gyv * fz * Blur(cx, cy, cz + 1)
                + fx * gyv * fz * Blur(cx + 1, cy, cz + 1) + gxv * fy * gzv * Blur(cx, cy + 1, cz) + fx * fy * gzv * Blur(cx + 1, cy + 1, cz)
                + gxv * fy * fz * Blur(cx, cy + 1, cz + 1) + fx * fy * fz * Blur(cx + 1, cy + 1, cz + 1);
        Vector3 ph = p * cell;
        float t = Math.Clamp((mass - 0.12f) / 0.33f, 0, 1); float rough = t * t * (3 - 2 * t);
        float led = rough * ledges * MathF.Sin(p.Y * MathF.Tau * 2f + 1.3f * fn.GetNoise(ph.X, ph.Z)) * Math.Clamp(v * 4f * (1 - v), 0, 1);
        return v + (0.35f + 0.65f * rough) * noiseAmp * fn.GetNoise(ph.X * 2.8f, ph.Y * 2.8f, ph.Z * 2.8f) + led - 0.5f;
    }
    float GetD(int i, int j, int k) {
        int idx = (i * gz + k) * gy + j;
        if (dok[idx] != 0) return d[idx];
        dok[idx] = 1; return d[idx] = Density(o + new Vector3(i, j, k) * s);
    }
    (int, int) CRange(int c, int n, float oa, int g) {
        int a = c == 0 ? 0 : (int)MathF.Ceiling((c * chunk - oa) / s);
        int b = c == n - 1 ? g - 1 : (int)MathF.Ceiling(((c + 1) * chunk - oa) / s);
        return (Math.Clamp(a, 0, g - 1), Math.Clamp(b, 0, g - 1));
    }
    static float Hf(int a, int b, int c, int dd) {
        long v = ((long)a * 73856093) ^ ((long)b * 19349663) ^ ((long)c * 83492791) ^ ((long)dd * 2654435761);
        v = (v ^ (v >> 13)) * 1274126177; v ^= v >> 16; return (v & 0xFFFF) / 32768f - 1f;
    }
    public void BuildChunk(int chx, int chy, int chz) {
        int ccx = (nx + chunk - 1) / chunk, ccy = (ny + chunk - 1) / chunk, ccz = (nz + chunk - 1) / chunk;
        var rx = CRange(chx, ccx, o.X, gx); var ry = CRange(chy, ccy, o.Y, gy); var rz = CRange(chz, ccz, o.Z, gz);
        stamp++;
        int ncy = gy - 1, ncz = gz - 1;
        var cand = new List<int>();
        int bx0 = (int)MathF.Floor(o.X + (rx.Item1 - 1) * s - 0.5f), bx1 = (int)MathF.Floor(o.X + rx.Item2 * s - 0.5f);
        int bz0 = (int)MathF.Floor(o.Z + (rz.Item1 - 1) * s - 0.5f), bz1 = (int)MathF.Floor(o.Z + rz.Item2 * s - 0.5f);
        int by0 = (int)MathF.Floor(o.Y + (ry.Item1 - 1) * s - 0.5f), by1 = (int)MathF.Floor(o.Y + ry.Item2 * s - 0.5f);
        long ymask = 0; for (int y = Math.Max(by0, 0); y <= Math.Min(by1, ny - 2); y++) ymask |= 1L << y;
        var ys = new List<int>();
        for (int bx = Math.Max(bx0, -1); bx <= Math.Min(bx1, nx - 1); bx++)
        for (int bz = Math.Max(bz0, -1); bz <= Math.Min(bz1, nz - 1); bz++) {
            long c1 = Col(bx, bz), c2 = Col(bx + 1, bz), c3 = Col(bx, bz + 1), c4 = Col(bx + 1, bz + 1);
            long A = c1 & c2 & c3 & c4, O = c1 | c2 | c3 | c4; if (O == 0) continue;
            ulong m = (ulong)((O | (O >> 1)) & ~(A & (A >> 1)) & ymask) & 0x7FFFFFFFFFFFFFFFUL;
            ys.Clear();
            while (m != 0) { ys.Add(BitOperations.TrailingZeroCount(m)); m &= m - 1; }
            if (by0 <= -1 && (A & 1) == 0 && (O & 1) == 1) ys.Add(-1);
            if (by1 >= ny - 1 && ((O >> (ny - 1)) & 1) == 1) ys.Add(ny - 1);
            foreach (int by in ys) {
                int i0 = (int)MathF.Ceiling((bx + 0.5f - o.X) / s) - 1, i1 = (int)MathF.Ceiling((bx + 1.5f - o.X) / s) - 1;
                int j0 = (int)MathF.Ceiling((by + 0.5f - o.Y) / s) - 1, j1 = (int)MathF.Ceiling((by + 1.5f - o.Y) / s) - 1;
                int k0 = (int)MathF.Ceiling((bz + 0.5f - o.Z) / s) - 1, k1 = (int)MathF.Ceiling((bz + 1.5f - o.Z) / s) - 1;
                for (int i = Math.Max(Math.Max(i0, rx.Item1 - 1), 0); i <= Math.Min(i1, rx.Item2 - 1); i++)
                for (int k = Math.Max(Math.Max(k0, rz.Item1 - 1), 0); k <= Math.Min(k1, rz.Item2 - 1); k++)
                for (int j = Math.Max(Math.Max(j0, ry.Item1 - 1), 0); j <= Math.Min(j1, ry.Item2 - 1); j++) {
                    int ci = (i * ncz + k) * ncy + j;
                    if (cubeStamp[ci] != stamp) { cubeStamp[ci] = stamp; cubeVid[ci] = -2; cand.Add(ci); }
                }
            }
        }
        var vpos = new List<Vector3>(); var vn = new List<Vector3>(); var vmat = new List<int>(); var vk = new List<float>();
        var own = new List<int>(); Span<float> vals = stackalloc float[8];
        foreach (int ci in cand) {
            int j = ci % ncy, k = (ci / ncy) % ncz, i = ci / (ncy * ncz);
            int pos = 0;
            for (int t = 0; t < 8; t++) { float v = GetD(i + (t & 1), j + ((t >> 1) & 1), k + ((t >> 2) & 1)); vals[t] = v; if (v > 0) pos++; }
            if (pos == 0 || pos == 8) { cubeVid[ci] = -1; continue; }
            Vector3 acc = Vector3.Zero; int n = 0;
            for (int e = 0; e < 12; e++) {
                int a, b;
                if (e < 4) { a = new[] { 0, 2, 4, 6 }[e]; b = a + 1; } else if (e < 8) { a = new[] { 0, 1, 4, 5 }[e - 4]; b = a + 2; } else { a = e - 8; b = a + 4; }
                float va = vals[a], vb = vals[b];
                if ((va > 0) != (vb > 0)) {
                    float tt = va / (va - vb);
                    acc += Vector3.Lerp(new Vector3(a & 1, (a >> 1) & 1, (a >> 2) & 1), new Vector3(b & 1, (b >> 1) & 1, (b >> 2) & 1), tt); n++;
                }
            }
            var g = new Vector3((vals[1] + vals[3] + vals[5] + vals[7]) - (vals[0] + vals[2] + vals[4] + vals[6]),
                                (vals[2] + vals[3] + vals[6] + vals[7]) - (vals[0] + vals[1] + vals[4] + vals[5]),
                                (vals[4] + vals[5] + vals[6] + vals[7]) - (vals[0] + vals[1] + vals[2] + vals[3]));
            Vector3 nrm = g.Length() > 1e-6f ? -Vector3.Normalize(g) : Vector3.UnitY;
            Vector3 p = o + (new Vector3(i, j, k) + acc / n) * s;
            p += new Vector3(Hf(i, j, k, 1), Hf(i, j, k, 2) * 0.6f, Hf(i, j, k, 3)) * jit * Math.Clamp(p.Y / 0.6f, 0, 1);
            Vector3 ins = p - nrm * 0.35f; int mx = (int)MathF.Floor(ins.X), my = (int)MathF.Floor(ins.Y), mz = (int)MathF.Floor(ins.Z);
            int mat = (mx < 0 || mz < 0 || mx >= nx || mz >= nz || my >= ny) ? 0 : cells[(mx * nz + mz) * ny + Math.Max(my, 0)];
            Vector3 fr = p + nrm * 0.7f;
            float cav = Math.Clamp(Blur((int)MathF.Floor(fr.X), (int)MathF.Floor(fr.Y), (int)MathF.Floor(fr.Z)) * 2.2f - 0.3f, 0, 1);
            cubeVid[ci] = vpos.Count; vpos.Add(p * cell); vn.Add(nrm); vmat.Add(mat); vk.Add(1 - 0.42f * cav);
            if (i >= rx.Item1 && j >= ry.Item1 && k >= rz.Item1) own.Add(ci);
        }
        var inds = new List<int>(); Span<int> q = stackalloc int[4];
        foreach (int ci in own) {
            int j = ci % ncy, k = (ci / ncy) % ncz, i = ci / (ncy * ncz);
            float v0 = GetD(i, j, k);
            for (int ax = 0; ax < 3; ax++) {
                if ((ax == 0 && (j == 0 || k == 0)) || (ax == 1 && (i == 0 || k == 0)) || (ax == 2 && (i == 0 || j == 0))) continue;
                float v1 = ax == 0 ? GetD(i + 1, j, k) : ax == 1 ? GetD(i, j + 1, k) : GetD(i, j, k + 1);
                if ((v0 > 0) == (v1 > 0)) continue;
                // u, w podle osy (stejně jako GDScript)
                int ux = 0, uy = 0, uz = 0, wx = 0, wy = 0, wz = 0;
                if (ax == 0) { uy = 1; wz = 1; } else if (ax == 1) { uz = 1; wx = 1; } else { ux = 1; wy = 1; }
                int[,] cs = { { i - ux - wx, j - uy - wy, k - uz - wz }, { i - wx, j - wy, k - wz }, { i, j, k }, { i - ux, j - uy, k - uz } };
                bool ok = true;
                for (int c = 0; c < 4; c++) {
                    int cj = (cs[c, 0] * ncz + cs[c, 2]) * ncy + cs[c, 1];
                    if (cubeStamp[cj] != stamp || cubeVid[cj] < 0) { ok = false; break; }
                    q[c] = cubeVid[cj];
                }
                if (!ok) continue;
                Vector3 outd = Vector3.Zero; float sg0 = v0 > 0 ? -1 : 1;
                if (ax == 0) outd.X = sg0; else if (ax == 1) outd.Y = sg0; else outd.Z = sg0;
                Vector3 p0 = vpos[q[0]], p1 = vpos[q[1]], p2 = vpos[q[2]], p3 = vpos[q[3]];
                Vector3 qn = Vector3.Cross(p1 - p0, p2 - p0) + Vector3.Cross(p2 - p0, p3 - p0);
                bool flip = Vector3.Dot(qn, outd) < 0; float sg = flip ? -1 : 1;
                float sa = Math.Min(sg * Vector3.Dot(Vector3.Normalize(Vector3.Cross(p1 - p0, p2 - p0)), outd), sg * Vector3.Dot(Vector3.Normalize(Vector3.Cross(p2 - p0, p3 - p0)), outd));
                float sb = Math.Min(sg * Vector3.Dot(Vector3.Normalize(Vector3.Cross(p1 - p0, p3 - p0)), outd), sg * Vector3.Dot(Vector3.Normalize(Vector3.Cross(p2 - p1, p3 - p1)), outd));
                int[] tri = sb > sa ? new[] { q[0], q[1], q[3], q[1], q[2], q[3] } : new[] { q[0], q[1], q[2], q[0], q[2], q[3] };
                for (int tt = 0; tt < 2; tt++)
                    if (flip) { inds.Add(tri[tt * 3]); inds.Add(tri[tt * 3 + 2]); inds.Add(tri[tt * 3 + 1]); }
                    else { inds.Add(tri[tt * 3]); inds.Add(tri[tt * 3 + 1]); inds.Add(tri[tt * 3 + 2]); }
            }
        }
        tris += inds.Count / 3;
    }
    public void BuildAll() {
        for (int a = 0; a < (nx + chunk - 1) / chunk; a++) for (int b = 0; b < (ny + chunk - 1) / chunk; b++) for (int c = 0; c < (nz + chunk - 1) / chunk; c++) BuildChunk(a, b, c);
    }
}

static class Program {
    static void Main(string[] args) {
        var cells = File.ReadAllBytes(args.Length > 0 ? args[0] : "hora7777.bin");
        foreach (float r in new[] { 2f, 1f }) {
            for (int rep = 0; rep < 4; rep++) {   // 1. běh = studený JIT, další = ustálený stav
                var sw = Stopwatch.StartNew();
                var v = new Vol(cells, r);
                v.BuildAll();
                sw.Stop();
                Console.WriteLine($"C# res {r}: běh {rep + 1}: {sw.Elapsed.TotalMilliseconds:F0} ms, trojúhelníků {v.tris}, vzorků se šumem {v.noiseSamples}");
            }
        }
        // úprava: vykopat buňku uprostřed bloku na povrchu a přestavět 1 chunk (bez zneplatnění – jen cena přestavby chunku)
        var vol = new Vol(cells, 2f); vol.BuildAll();
        var sw2 = Stopwatch.StartNew();
        for (int t = 0; t < 20; t++) { Array.Clear(vol.dok); vol.BuildChunk(1, 2, 1); }
        Console.WriteLine($"C# přestavba 1 chunku 16³ (hustota znovu): {sw2.Elapsed.TotalMilliseconds / 20:F1} ms");
    }
}
