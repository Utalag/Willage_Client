using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Willage.Gen.Data;

namespace Willage.Gen.Katalogy;

/// <summary>Jeden datový soubor v manifestu: cesta relativně ke kořeni dat (oddělovač '/'), velikost a SHA-256 (hex, malá písmena).</summary>
public sealed record PolozkaManifestu(string Cesta, long Velikost, string Sha256);

/// <summary>
/// G-1: manifest katalogů = SHA-256 všech souborů v kořeni dat (godot-prototyp/data, rekurzivně, bez manifestu samého)
/// a souhrnná SHA (textové soubory s CRLF → LF). Klíče modulů berou SHA svých souborů odtud (opravuje riziko, že DataSveta.SouborySveta má jen 3 soubory).
/// Pořadí je ordinální podle cesty, takže manifest i souhrn jsou deterministické na každém stroji.
/// </summary>
public sealed class ManifestKatalogu
{
    public const string Format = "willage-manifest-katalogu-v1";
    public const string NazevSouboru = "manifest_katalogu_v1.json";

    private readonly Dictionary<string, PolozkaManifestu> _podle;
    public IReadOnlyList<PolozkaManifestu> Polozky { get; }
    /// <summary>SHA-256 přes „cesta=sha“ všech položek v pořadí.</summary>
    public string Souhrn { get; }

    public ManifestKatalogu(IEnumerable<PolozkaManifestu> polozky)
    {
        Polozky = polozky.OrderBy(p => p.Cesta, StringComparer.Ordinal).ToList();
        _podle = Polozky.ToDictionary(p => p.Cesta, StringComparer.Ordinal);
        var sb = new StringBuilder(Format);
        foreach (var p in Polozky) sb.Append('\n').Append(p.Cesta).Append('=').Append(p.Sha256);
        Souhrn = Sha(Encoding.UTF8.GetBytes(sb.ToString()));
    }

    public static string Sha(byte[] b) => Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();

    /// <summary>Spočte manifest ze souborů v kořeni dat.</summary>
    public static ManifestKatalogu Spocti(string koren)
    {
        var full = Path.GetFullPath(koren);
        var pol = new List<PolozkaManifestu>();
        foreach (var f in Directory.EnumerateFiles(full, "*", SearchOption.AllDirectories))
        {
            string rel = Relativni(full, f);
            if (rel == NazevSouboru || ArtefaktGodotu(rel)) continue;
            var b = Obsah(f);
            pol.Add(new PolozkaManifestu(rel, b.LongLength, Sha(b)));
        }
        return new ManifestKatalogu(pol);
    }

    /// <summary>
    /// G-4: soubory, které vyrobí import Godotu při otevření projektu (CSV se importuje jako překlad: *.csv.import, *.translation;
    /// *.uid). Nejsou to data generátoru, do manifestu nepatří (jinak by headless spuštění Godotu změnilo klíče).
    /// </summary>
    public static bool ArtefaktGodotu(string rel) => rel.EndsWith(".import", StringComparison.Ordinal) || rel.EndsWith(".translation", StringComparison.Ordinal) || rel.EndsWith(".uid", StringComparison.Ordinal);

    /// <summary>Bajty souboru pro SHA: textová data (.json, .csv, .txt, .md) s CRLF → LF, aby SHA nezávisela na git autocrlf (Windows).</summary>
    public static byte[] Obsah(string cesta)
    {
        var b = File.ReadAllBytes(cesta);
        string e = Path.GetExtension(cesta).ToLowerInvariant();
        if (e is not (".json" or ".csv" or ".txt" or ".md") || Array.IndexOf(b, (byte)'\r') < 0) return b;
        var o = new List<byte>(b.Length);
        for (int i = 0; i < b.Length; i++) if (!(b[i] == (byte)'\r' && i + 1 < b.Length && b[i + 1] == (byte)'\n')) o.Add(b[i]);
        return o.ToArray();
    }

    public static ManifestKatalogu Spocti(DataSveta d) => Spocti(d.Koren);

    public static string Relativni(string koren, string cesta) => Path.GetRelativePath(Path.GetFullPath(koren), Path.GetFullPath(cesta)).Replace('\\', '/');

    public bool Obsahuje(string rel) => _podle.ContainsKey(rel);

    /// <summary>SHA souboru podle relativní cesty; chybějící soubor = výjimka (modul nesmí číst soubor mimo manifest).</summary>
    public string ShaSouboru(string rel) => _podle.TryGetValue(rel, out var p) ? p.Sha256 : throw new KeyNotFoundException("soubor není v manifestu katalogů: " + rel);

    /// <summary>Cesty, které se liší (přidané, odebrané nebo změněné), ordinálně seřazené.</summary>
    public IReadOnlyList<string> Rozdily(ManifestKatalogu jiny) =>
        _podle.Keys.Union(jiny._podle.Keys).Where(k => !_podle.TryGetValue(k, out var a) || !jiny._podle.TryGetValue(k, out var b) || a != b)
            .OrderBy(k => k, StringComparer.Ordinal).ToList();

    public string ToJson()
    {
        var o = new
        {
            format = Format,
            souhrn = Souhrn,
            soubory = Polozky.Select(p => new { cesta = p.Cesta, velikost = p.Velikost, sha256 = p.Sha256 }),
        };
        return JsonSerializer.Serialize(o, new JsonSerializerOptions { WriteIndented = true }) + "\n";
    }

    public static ManifestKatalogu ZJson(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var r = doc.RootElement;
        if (r.GetProperty("format").GetString() != Format) throw new FormatException("neznámý formát manifestu");
        var m = new ManifestKatalogu(r.GetProperty("soubory").EnumerateArray().Select(e =>
            new PolozkaManifestu(e.GetProperty("cesta").GetString()!, e.GetProperty("velikost").GetInt64(), e.GetProperty("sha256").GetString()!)));
        if (m.Souhrn != r.GetProperty("souhrn").GetString()) throw new FormatException("souhrn manifestu nesedí s položkami");
        return m;
    }

    /// <summary>Uloží manifest do kořene dat (data/manifest_katalogu_v1.json).</summary>
    public void Uloz(string koren) => File.WriteAllText(Path.Combine(koren, NazevSouboru), ToJson());
}
