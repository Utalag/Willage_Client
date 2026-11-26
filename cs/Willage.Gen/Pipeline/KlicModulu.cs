using System.Text;
using Willage.Gen.Katalogy;

namespace Willage.Gen.Pipeline;

/// <summary>
/// G-1: klíč modulu = SHA-256(formát | gen_ver | id | verze algoritmu | kanonické parametry | „soubor=SHA“ jeho souborů z manifestu
/// | „id=klíč“ vstupních modulů). Změna modulu N tak změní klíč N a jeho závislých, klíče modulů před ním ne.
/// Dnešní klíče (WGER SouborMapy.KlicKese, MapaKlimatu.KlicKlimatu) se nemění a dál chrání soubory keše.
/// </summary>
public static class KlicModulu
{
    public const string Format = "willage-modul-klic-v1";
    /// <summary>Verze generátoru V1 (plán 01: gen_ver Vmajor.minor).</summary>
    public const string GenVer = "V1.0";

    public static string Spocti(IModul m, string parametry, ManifestKatalogu man, IReadOnlyDictionary<string, string> kliceZavislosti)
    {
        var sb = new StringBuilder();
        sb.Append(Format).Append('|').Append(GenVer).Append('|').Append(m.Id).Append('|').Append(m.VerzeAlgoritmu).Append('|').Append(parametry);
        foreach (var f in m.Soubory.OrderBy(f => f, StringComparer.Ordinal)) sb.Append("|f:").Append(f).Append('=').Append(man.ShaSouboru(f));
        foreach (var z in m.Zavislosti.Distinct().OrderBy(z => z, StringComparer.Ordinal)) sb.Append("|z:").Append(z).Append('=').Append(kliceZavislosti[z]);
        return ManifestKatalogu.Sha(Encoding.UTF8.GetBytes(sb.ToString()));
    }
}
