namespace Willage.Gen.Geo2;

/// <summary>Druh operace události (kontrakt 06, kap. 1.1). Jeden model, tři druhy: deformace / materiálová / transformace.</summary>
public enum Operace : byte { Uloz, Vnikni, Odstran, Vypln, Transformuj, Deformuj }

/// <summary>Typ prostoru v bodě (kontrakt 06, kap. 2.1, 3.1). <see cref="Neurceno"/> je jen stav před první událostí <c>Uloz</c>.</summary>
public enum TypProstoru : byte { Neurceno = 0, Pevne, NadPovrchem, DutinaKras, DutinaJina, Vykopano }

/// <summary>Třída cíle pro pravidlo 2.3: rozhoduje vždy právě jeden filtr.</summary>
public enum TridaCile { Neurceno, Material, Prazdno, MimoGeologii }

/// <summary>Překryv instancí téže události (1.4).</summary>
public enum Sourozenci { Unie, NejmensiSdf }

public static class Geo2Zaklad
{
    public static bool JeMaterialova(Operace o) => o is Operace.Uloz or Operace.Vnikni or Operace.Odstran or Operace.Vypln;

    /// <summary>Geometrický původ typu „těleso“ pro pravidlo <c>zdroje.telesa</c>.</summary>
    public static bool JeTeleso(Operace o) => o is Operace.Vnikni or Operace.Vypln;

    public static TridaCile Trida(TypProstoru t) => t switch
    {
        TypProstoru.Neurceno => TridaCile.Neurceno,
        TypProstoru.Pevne => TridaCile.Material,
        TypProstoru.DutinaKras or TypProstoru.DutinaJina => TridaCile.Prazdno,
        _ => TridaCile.MimoGeologii,
    };

    public static bool ZkusOperaci(string? s, out Operace o)
    {
        o = default;
        return s is not null && Enum.GetNames<Operace>().Contains(s) && Enum.TryParse(s, false, out o);
    }

    /// <summary>Typy prostoru, které smí stát v pravidle <c>prostor</c> nebo ve <c>vysledek.prostor</c>.</summary>
    public static bool ZkusTypDutiny(string? s, out TypProstoru t)
    {
        t = s switch { "DutinaKras" => TypProstoru.DutinaKras, "DutinaJina" => TypProstoru.DutinaJina, _ => TypProstoru.Neurceno };
        return t != TypProstoru.Neurceno;
    }
}
