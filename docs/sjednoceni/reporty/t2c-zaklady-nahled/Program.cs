// DOČASNÝ NÁHLED – není součást klienta ani Dev: spustí receptury v2 (base_texture + modifikátory) z Dev 04ed4d9
// nad dočasnou kopií katalogu, do které jsou vloženy baseTile dlaždic Gemini. Použití: <katalog.json> <recepturyDir> <outDir>
using Willage.World.Materials.Catalog;
using Willage.World.Vpmg;
using Willage.World.Vpmg.Export.Png;
using Willage.World.Vpmg.Pipeline;
using Willage.World.Vpmg.Ports;
using Willage.World.Vpmg.Recipe;

var catalog = MaterialCatalogLoader.LoadFromFile(args[0]);
var runner = new VpmgPipelineRunner(catalog, VpmgDefaults.CreateDefaultRegistry(), new FileVpmgTileSource(Path.GetDirectoryName(args[0])!));
var mats = new (byte Id, string Key, string File)[] { (1, "grass", "grass"), (2, "topsoil", "topsoil"), (3, "gravel_sand", "gravel-sand"), (5, "cave_limestone", "cave-limestone"), (6, "granite", "granite") };
Directory.CreateDirectory(args[2]);
if (args.Length > 3 && args[3] == "--kroky")
{
    foreach (var (id, key, f) in mats)
    {
        var r = VpmgRecipeJson.Parse(File.ReadAllText(Path.Combine(args[1], $"recipe-{f}-v2.json"))) with { Resolution = 128 };
        for (var k = 1; k <= r.Steps.Count; k++)
        {
            var l = runner.Run(r with { Steps = r.Steps.Take(k).ToList() }, 0xC0FFEE00u + 7919u);
            using var fs = File.Create(Path.Combine(args[2], $"kroky-{id}-{k}-{r.Steps[k - 1].Type}.png"));
            RgbaPngWriter.Write(l, fs);
        }
    }
    return;
}
const uint seed0 = 0xC0FFEE00u;
foreach (var (id, key, f) in mats)
{
    var r = VpmgRecipeJson.Parse(File.ReadAllText(Path.Combine(args[1], $"recipe-{f}-v2.json")));
    var g = runner.Run(r, seed0);
    Console.WriteLine($"{id} {key} v2 res {r.Resolution} seed {seed0} checksum {g.ComputeFnvChecksum()}");
    var r128 = r with { Resolution = 128 };
    for (var i = 0; i <= 4; i++)
    {
        var s = unchecked(seed0 + (uint)i * 7919u);
        var l = runner.Run(r128, s);
        using var fs = File.Create(Path.Combine(args[2], $"{id}-{key}-s{i}.png"));
        RgbaPngWriter.Write(l, fs);
        Console.WriteLine($"  128 seed {s} checksum {l.ComputeFnvChecksum()}");
    }
}
