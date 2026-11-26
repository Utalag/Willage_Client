using System.Reflection;

namespace Willage.Vpmg.Nastroj;

/// <summary>Připnutý commit Dev a cesta k jeho kopii (z AssemblyMetadata při sestavení).</summary>
static class PinDev
{
    static string? Meta(string k) => typeof(PinDev).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>().FirstOrDefault(a => a.Key == k)?.Value;
    public static string Commit => Meta("WillageDevCommit") ?? "?";
    public static string Koren => Meta("WillageDevKoren") ?? "?";
    public static string Cesta(string rel) => Path.Combine(Koren, rel);
}
