using System.Diagnostics;
using System.Text.Json;
using Willage.World.Materials.Catalog;
using Willage.World.Materials.Domain;
using Willage.World.Materials.Ports;
using Willage.World.Vpmg;
using Willage.World.Vpmg.Pipeline;
using Willage.World.Vpmg.Recipe;

namespace Willage.Vpmg.Nastroj;

/// <summary>Výsledek běhu receptury.</summary>
public sealed record BehVpmg(VpmgTextureLayer Vrstva, uint Checksum, double Ms);

/// <summary>Tenký obal nad VPMG Dev: registr, runner, golden, kontrola zrcadla. Žádná vlastní operace.</summary>
public sealed class PrikazyVpmg
{
    public IMaterialCatalog Katalog { get; }
    public string ZdrojKatalogu { get; }
    public VpmgOperationRegistry Registr { get; } = VpmgDefaults.CreateDefaultRegistry();

    public PrikazyVpmg(string? katalog)
    {
        ZdrojKatalogu = katalog ?? "Dev (embedded Data/materials-catalog-v1.json)";
        Katalog = katalog is null ? MaterialCatalogLoader.LoadFromEmbeddedOrDefault() : MaterialCatalogLoader.LoadFromFile(katalog);
    }

    /// <summary>Operace registru Dev: všechny implementace IVpmgStepOperation v sestavě Dev, které výchozí registr umí.</summary>
    public IReadOnlyList<string> Operace() => typeof(VpmgDefaults).Assembly.GetTypes()
        .Where(t => typeof(IVpmgStepOperation).IsAssignableFrom(t) && t is { IsAbstract: false, IsInterface: false } && t.GetConstructor(Type.EmptyTypes) != null)
        .Select(t => ((IVpmgStepOperation)Activator.CreateInstance(t)!).TypeId)
        .Where(Registr.CanResolve).OrderBy(x => x, StringComparer.Ordinal).ToList();

    /// <summary>Výchozí receptura = tools/VpmgPreview Dev (base_fill albedo + hash_grain).</summary>
    public static VpmgRecipe Vychozi(byte material, int rozliseni = 64) => new(1, MaterialId.From(material), "default", rozliseni,
    [
        new VpmgRecipeStep("s1", "base_fill", true, new Dictionary<string, string> { ["layer"] = "albedo" }),
        new VpmgRecipeStep("s2", "hash_grain", true, new Dictionary<string, string>()),
    ]);

    public BehVpmg Spust(VpmgRecipe r, uint seed, NavrhProfilu? navrh = null)
    {
        var sw = Stopwatch.StartNew();
        var kat = KatalogSNavrhem.S(Katalog, r.MaterialId, r.VisualProfileName, navrh);
        var v = new VpmgPipelineRunner(kat, Registr).Run(r, seed);
        return new BehVpmg(v, v.ComputeFnvChecksum(), sw.Elapsed.TotalMilliseconds);
    }

    /// <summary>Golden fixture z připnuté kopie Dev (stejná receptura jako test Dev).</summary>
    public (uint Ocekavany, uint Spocteny) Golden()
    {
        using var d = JsonDocument.Parse(File.ReadAllText(PinDev.Cesta("tests/Willage.World.Vpmg.Tests/Fixtures/vpmg-golden-v1.json")));
        var root = d.RootElement;
        uint seed = Convert.ToUInt32(root.GetProperty("seed").GetString(), 16);
        var b = Spust(Vychozi((byte)root.GetProperty("materialId").GetInt32(), root.GetProperty("resolution").GetInt32()), seed);
        return (root.GetProperty("checksum").GetUInt32(), b.Checksum);
    }

    /// <summary>T-2b: goldeny receptur v1 z fixture Dev v pinu (receptura i checksum z Dev, katalog = zrcadlo / embedded).</summary>
    public IReadOnlyList<(string Soubor, uint Ocekavany, uint Spocteny)> GoldenyReceptur()
    {
        const string F = "tests/Willage.World.Vpmg.Tests/Fixtures/";
        using var d = JsonDocument.Parse(File.ReadAllText(PinDev.Cesta(F + "vpmg-recipe-goldens-v1.json")));
        uint seed = Convert.ToUInt32(d.RootElement.GetProperty("seed").GetString(), 16);
        return d.RootElement.GetProperty("cases").EnumerateArray().Select(c =>
        {
            string soubor = c.GetProperty("recipeFile").GetString()!;
            var r = VpmgRecipeJson.Parse(File.ReadAllText(PinDev.Cesta(F + "recipes/" + soubor)));
            return (soubor, c.GetProperty("checksum").GetUInt32(), Spust(r, seed).Checksum);
        }).ToList();
    }

    /// <summary>Zrcadlo katalogu proti katalogu Dev v pinu: bajty bez koncových bílých znaků a záznamy po načtení loaderem Dev.</summary>
    public static (bool BajtyBezKonce, bool Zaznamy, int Pocet, int PocetDev, string Rozdil) KontrolaZrcadla(string zrcadlo)
    {
        string dev = PinDev.Cesta("src/Modules/World/Willage.World.Materials/Data/materials-catalog-v1.json");
        string a = File.ReadAllText(zrcadlo).TrimEnd(), b = File.ReadAllText(dev).TrimEnd();
        var ka = MaterialCatalogLoader.LoadFromFile(zrcadlo); var kb = MaterialCatalogLoader.LoadFromFile(dev);
        string ja = JsonSerializer.Serialize(ka.All), jb = JsonSerializer.Serialize(kb.All);
        string rozdil = File.ReadAllBytes(dev).Length - File.ReadAllBytes(zrcadlo).Length is var d && d != 0 ? $"Dev má o {d} B víc (koncové bílé znaky)" : "žádný";
        return (a == b, ja == jb, ka.All.Count, kb.All.Count, rozdil);
    }
}
