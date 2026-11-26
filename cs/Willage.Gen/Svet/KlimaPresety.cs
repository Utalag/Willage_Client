using System.Globalization;
using Willage.Gen.Data;

namespace Willage.Gen.Svet;

/// <summary>Port scripts/v1/klima.gd: presety z data/klima_presety.csv a jejich uplatnění na parametry.</summary>
public static class KlimaPresety
{
    public sealed record Preset(string Id, double KPrevyseni, double KVlna, double KDrsnost, double DPosunM, double[] Podil,
        double KMasivAmp, double KMasivZdvih, double KPodhuri, double KHorniny, double KVoda);

    public static (Dictionary<string, Preset> podleId, List<string> ids) Nacti(string cesta)
    {
        var podle = new Dictionary<string, Preset>(); var ids = new List<string>();
        string[]? hlava = null;
        foreach (var r in Csv.Radky(File.ReadAllText(cesta)))
        {
            if (r.Count == 0 || r[0].Trim().Length == 0 || r[0].Trim().StartsWith('#')) continue;
            if (hlava is null) { hlava = r.ToArray(); continue; }
            if (r.Count < hlava.Length) continue;
            var d = new Dictionary<string, string>();
            for (int i = 0; i < hlava.Length; i++) d[hlava[i]] = r[i];
            string id = d["id"].Trim(); if (id.Length == 0) continue;
            double G(string k, string def) => Cislo(d.TryGetValue(k, out var v) ? v : def);
            podle[id] = new Preset(id, G("k_prevyseni", "1"), G("k_vlna", "1"), G("k_drsnost", "1"), G("d_posun_m", "0"),
                new[] { G("podil_nizina", "0"), G("podil_mokrad", "0"), G("podil_pahorkatina", "0"), G("podil_hornatina", "0"), G("podil_sopecna", "0") },
                G("k_masiv_amp", "1"), G("k_masiv_zdvih", "1"), G("k_podhuri", "1"), G("k_horniny", "1"), G("k_voda", "1"));
            if (!ids.Contains(id)) ids.Add(id);
        }
        return (podle, ids);
    }

    private static double Cislo(string s)
    {
        var t = s.Trim();
        if (t.Length == 0 || t == "–" || t == "-") return 0.0;
        t = t.Split(' ')[0];
        return double.TryParse(t, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? v : 0.0;
    }

    public static void Uplatni(ParametrySveta p, Preset pr)
    {
        foreach (var b in p.Biomy)
        {
            b.PosunM += pr.DPosunM; b.PrevyseniM *= pr.KPrevyseni; b.VlnaM *= pr.KVlna; b.Drsnost *= pr.KDrsnost;
        }
        p.Podil = (double[])pr.Podil.Clone();
        p.P87AmpM *= pr.KMasivAmp; p.MasivZdvihM *= pr.KMasivZdvih; p.PodhuriM *= pr.KPodhuri;
        p.KlimaKVoda = pr.KVoda; p.KlimaKHorniny = pr.KHorniny;
    }
}
