using Willage.Gen.Data;
using Willage.Gen.Svet;

namespace Willage.Gen.Nastroje;

/// <summary>Porovná výšku, tvar, biom a horniny se vzorky z GDScriptu (binární výpis tools/geo_cs_vzorky.gd).</summary>
public static class PorovnejVysku
{
    public static int Spust(string bin, DataSveta data)
    {
        var s = new SvetFn(new ParametrySveta(), data);
        using var r = new BinaryReader(File.OpenRead(bin));
        int chyb = 0; double maxd = 0;
        void Cmp(string co, double gd, double cs)
        {
            double d = Math.Abs(gd - cs); maxd = Math.Max(maxd, d);
            if (BitConverter.DoubleToInt64Bits(gd) != BitConverter.DoubleToInt64Bits(cs)) { if (chyb++ < 15) Console.WriteLine($"  {co}: gd {gd:R} cs {cs:R} Δ {d:E2}"); }
        }
        foreach (var sp in s.Sopky.Seznam)
            foreach (var v in new[] { sp.X, sp.Y, sp.H, sp.R, sp.Rc, sp.D, sp.Gamma }) Cmp("sopka", r.ReadDouble(), v);
        for (int t = 0; t < 5; t++) Cmp($"rel_amp{t}", r.ReadDouble(), s.Relief.Amp[t]);
        Cmp("m87_amp", r.ReadDouble(), s.Masiv.Amp); Cmp("m87_freq", r.ReadDouble(), s.Masiv.Freq); Cmp("pod_amp", r.ReadDouble(), s.Masiv.PodAmp);
        int n = 0, biomChyb = 0, hornChyb = 0;
        while (r.BaseStream.Position < r.BaseStream.Length)
        {
            double x = r.ReadDouble(), y = r.ReadDouble();
            Cmp("vyska", r.ReadDouble(), s.Vyska(x, y)); Cmp("tvar", r.ReadDouble(), s.VyskaTvar(x, y));
            var sl = s.Sloupec(x, y);
            if (r.ReadInt32() != sl.Biom) biomChyb++;
            int k = r.ReadInt32();
            bool hs = k == sl.Horniny.Count;
            for (int i = 0; i < k; i++)
            {
                int id = r.ReadInt32(); double v = r.ReadDouble();
                if (!hs || sl.Horniny[i].id != id || sl.Horniny[i].podil != v) hs = false;
            }
            if (!hs) hornChyb++;
            n++;
        }
        Console.WriteLine($"vzorků {n}: rozdílných hodnot {chyb}, max |Δ| {maxd:E2}, biom ≠ {biomChyb}, horniny ≠ {hornChyb}");
        return chyb + biomChyb + hornChyb;
    }
}
