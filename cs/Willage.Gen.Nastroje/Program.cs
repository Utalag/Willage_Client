using Willage.Gen.Data;
using Willage.Gen.Nastroje;

var data = DataSveta.Najdi(AppContext.BaseDirectory);
string cmd = args.Length > 0 ? args[0] : "";
return cmd switch
{
    "vyska" => PorovnejVysku.Spust(args[1], data) == 0 ? 0 : 1,
    "det3" => Det3(args, data),
    "voda" => Voda(args, data),
    _ => Napoveda(),
};

static int Napoveda() { Console.WriteLine("použití: vyska <bin>"); return 2; }

static int Det3(string[] a, Willage.Gen.Data.DataSveta d)
{
    bool opravy = a.Contains("--opravy");
    var p = opravy ? new Willage.Gen.Svet.ParametrySveta() : Willage.Gen.Svet.ParametrySveta.Puvodni();
    var (o, n, ms) = OtiskKrok3.Spocti(p, d);
    Console.WriteLine($"det3 {(opravy ? "opravy" : "puvodni")}: {o} {n} buněk, {ms:F0} ms");
    return 0;
}

static int Voda(string[] a, Willage.Gen.Data.DataSveta d)
{
    bool opravy = a.Contains("--opravy");
    var (o, n, init, ms) = VodaBlok.Spust(opravy, d);
    Console.WriteLine($"voda {(opravy ? "opravy" : "puvodni")} blok 14,14: {o}, pramenů {n}, init {init:F0} ms, blok {ms:F0} ms");
    return 0;
}
