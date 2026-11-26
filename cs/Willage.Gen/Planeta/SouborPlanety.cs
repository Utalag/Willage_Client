using System.IO.Compression;
using System.Text;
using Willage.Gen.Katalogy;

namespace Willage.Gen.Planeta;

/// <summary>
/// G-3: soubor planety WPLN v1 (Deflate jako WGER). Pořadí: magie „WPLN“, verze (int), gen_ver, seed (i64), souhrn manifestu,
/// počet položek manifestu + (cesta, velikost, sha), sada parametrů (JSON), počet klíčů + (id, klíč), potvrzeno (bool),
/// počet úprav + úpravy (U-1, ve v1 0). Řetězce BinaryWriter (UTF-8, délka 7bit). Deterministické: stejný obsah → stejné bajty.
/// </summary>
public static class SouborPlanety
{
    public const string Magie = "WPLN";
    public const int Verze = 1;
    public const string Pripona = ".wpln";

    public static byte[] Bajty(PlanetaV1 p)
    {
        using var ms = new MemoryStream();
        using (var z = new DeflateStream(ms, CompressionLevel.Optimal, leaveOpen: true))
        using (var w = new BinaryWriter(z, Encoding.UTF8))
        {
            w.Write(Encoding.ASCII.GetBytes(Magie)); w.Write(Verze);
            w.Write(p.GenVer); w.Write(p.Seed); w.Write(p.ManifestSouhrn);
            w.Write(p.Manifest.Count);
            foreach (var m in p.Manifest) { w.Write(m.Cesta); w.Write(m.Velikost); w.Write(m.Sha256); }
            w.Write(p.SadaJson);
            w.Write(p.Klice.Count);
            foreach (var (id, k) in p.Klice) { w.Write(id); w.Write(k); }
            w.Write(p.Potvrzena);
            w.Write(p.Upravy.Count);
            foreach (var u in p.Upravy) { w.Write(u.Druh); w.Write(u.Modul); w.Write(u.X0M); w.Write(u.Y0M); w.Write(u.X1M); w.Write(u.Y1M); w.Write(u.ParametryJson); }
        }
        return ms.ToArray();
    }

    /// <summary>Načte planetu; špatná magie nebo verze → <see cref="InvalidDataException"/>.</summary>
    public static PlanetaV1 ZBajtu(byte[] b)
    {
        using var z = new DeflateStream(new MemoryStream(b), CompressionMode.Decompress);
        using var r = new BinaryReader(z, Encoding.UTF8);
        var mag = Encoding.ASCII.GetString(r.ReadBytes(4));
        if (mag != Magie) throw new InvalidDataException("není soubor planety WPLN");
        int v = r.ReadInt32();
        if (v != Verze) throw new InvalidDataException($"nepodporovaná verze WPLN {v} (umím {Verze})");
        string gen = r.ReadString(); long seed = r.ReadInt64(); string souhrn = r.ReadString();
        var man = new List<PolozkaManifestu>(); int n = r.ReadInt32();
        for (int i = 0; i < n; i++) man.Add(new PolozkaManifestu(r.ReadString(), r.ReadInt64(), r.ReadString()));
        string sada = r.ReadString();
        var kl = new List<KeyValuePair<string, string>>(); n = r.ReadInt32();
        for (int i = 0; i < n; i++) kl.Add(new(r.ReadString(), r.ReadString()));
        bool pot = r.ReadBoolean();
        var up = new List<UpravaRegionu>(); n = r.ReadInt32();
        for (int i = 0; i < n; i++) up.Add(new UpravaRegionu(r.ReadString(), r.ReadString(), r.ReadDouble(), r.ReadDouble(), r.ReadDouble(), r.ReadDouble(), r.ReadString()));
        return new PlanetaV1 { GenVer = gen, Seed = seed, ManifestSouhrn = souhrn, Manifest = man, SadaJson = sada, Klice = kl, Potvrzena = pot, Upravy = up };
    }

    public static void Uloz(string cesta, PlanetaV1 p) => File.WriteAllBytes(cesta, Bajty(p));
    public static PlanetaV1 Nacti(string cesta) => ZBajtu(File.ReadAllBytes(cesta));

    /// <summary>Rozdíly verzí dat planety proti aktuálnímu manifestu (prázdné = planeta odpovídá datům).</summary>
    public static IReadOnlyList<string> RozdilyDat(PlanetaV1 p, ManifestKatalogu aktualni) =>
        new ManifestKatalogu(p.Manifest).Rozdily(aktualni);

    /// <summary>Kanonický text obsahu (pro porovnání nezávisle na kompresi).</summary>
    public static string Kanonicky(PlanetaV1 p) =>
        $"{p.GenVer}|{p.Seed}|{p.ManifestSouhrn}|{string.Join(";", p.Manifest.Select(m => $"{m.Cesta},{m.Velikost},{m.Sha256}"))}|{p.SadaJson}|" +
        $"{string.Join(";", p.Klice.Select(k => k.Key + "=" + k.Value))}|{p.Potvrzena}|{p.Upravy.Count}";
}
