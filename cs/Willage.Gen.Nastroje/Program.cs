using Willage.Gen.Data;
using Willage.Gen.Nastroje;

var data = DataSveta.Najdi(AppContext.BaseDirectory);
args = ErozeNastroj.Volby(args);
ErozeNastroj.D = data;
string cmd = args.Length > 0 ? args[0] : "";
return cmd switch
{
    "vyska" => PorovnejVysku.Spust(args[1], data) == 0 ? 0 : 1,
    "det3" => Det3(args, data),
    "voda" => Voda(args, data),
    "sevy" => Sevy(args, data),
    "rez" => Rez(args, data),
    "sopka" => Sopka(data),
    "pobrezi" => args[1] switch
    {
        "tabulka" => PobrezniNastroj.Tabulka(data),
        "brehy" => PobrezniNastroj.Brehy(args, data),
        "vliv" => PobrezniNastroj.Vliv(args, data),
        _ => Napoveda(),
    },
    "prusak" => PrusakSimulace.Spust(data, args.Length > 1 ? args[1] : "vystup-prusak"),
    "prameny" => Prameny(data),
    "cas" => Cas(args, data),
    "par" => Paralelne.Spust(data, args.Contains("--puvodni"), args.Skip(1).Where(s => int.TryParse(s, out _)).Select(int.Parse).DefaultIfEmpty(1).ToArray()) == 0 ? 0 : 1,
    "klima" => args[1] switch
    {
        "mapa" => KlimaNastroj.Mapa(args, data),
        "otisky" => KlimaNastroj.Otisky(args, data),
        "prameny" => KlimaNastroj.Prameny(args, data),
        _ => Napoveda(),
    },
    "eroze" => args[1] switch
    {
        "svetmax" => ErozeNastroj.SvetMax(data),
        "mapa" => ErozeNastroj.Mapa(args, data),
        "otisky" => ErozeNastroj.Otisky(args, data),
        "detail" => ErozeNastroj.Detail(args, data),
        "prameny" => ErozeNastroj.PramenyDiag(args, data),
        "interp" => ErozeNastroj.InterpMer(args, data),
        "vse" => ErozeNastroj.Vse(args, data),
        "rez" => ErozeNastroj.Rez(args, data),
        _ => Napoveda(),
    },
    _ => Napoveda(),
};

static int Napoveda() { Console.WriteLine("použití: vyska <bin>"); return 2; }

static int Det3(string[] a, Willage.Gen.Data.DataSveta d)
{
    bool opravy = a.Contains("--opravy");
    var p = opravy ? new Willage.Gen.Svet.ParametrySveta() : Willage.Gen.Svet.ParametrySveta.Puvodni();
    if (a.Contains("--presny")) p.UtvaryKlicGd = false;
    if (a.Contains("--klic-gd")) p.UtvaryKlicGd = true;
    var (o, n, ms) = OtiskKrok3.Spocti(p, d);
    Console.WriteLine($"det3 {(opravy ? "opravy" : "puvodni")} klíč {(p.UtvaryKlicGd ? "gd" : "přesný")}: {o} {n} buněk, {ms:F0} ms");
    return 0;
}

static int Voda(string[] a, Willage.Gen.Data.DataSveta d)
{
    bool opravy = a.Contains("--opravy");
    var (o, n, init, ms) = VodaBlok.Spust(opravy, d);
    Console.WriteLine($"voda {(opravy ? "opravy" : "puvodni")} blok 14,14: {o}, pramenů {n}, init {init:F0} ms, blok {ms:F0} ms");
    return 0;
}

static int Sevy(string[] a, Willage.Gen.Data.DataSveta d)
{
    string o = a.Length > 1 ? a[1] : "vystup";
    SevyMince.Spust(d, o);
    return 0;
}

static int Rez(string[] a, Willage.Gen.Data.DataSveta d)
{
    // rez <výstupní složka> [xs] [y] [pul]
    string o = a[1];
    double xs = a.Length > 2 ? double.Parse(a[2], System.Globalization.CultureInfo.InvariantCulture) : 2048.0;
    double y = a.Length > 3 ? double.Parse(a[3], System.Globalization.CultureInfo.InvariantCulture) : 1984.0;
    double pul = a.Length > 4 ? double.Parse(a[4], System.Globalization.CultureInfo.InvariantCulture) : 48.0;
    SevyMince.Rez(d, Path.Combine(o, "rez_puvodni.bin"), false, xs, y, pul);
    SevyMince.Rez(d, Path.Combine(o, "rez_opravy.bin"), true, xs, y, pul);
    return 0;
}

static int Sopka(Willage.Gen.Data.DataSveta d) { SopkaVoda.Spust(d); return 0; }

static int Prameny(Willage.Gen.Data.DataSveta d) { HustotaPramenu.Spust(d); return 0; }

static int Cas(string[] a, Willage.Gen.Data.DataSveta d) { Casy.Spust(d, a.Contains("--opravy"), a.Contains("--blok")); return 0; }
