using System.Diagnostics;
using System.Text;
using System.Text.Json.Nodes;
using Willage.Materialy.Api.Dto;
using Willage.Materialy.Api.Rozhrani;

namespace Willage.Materialy.Api.Sluzby;

/// <summary>
/// T-1 (N7): VPMG Dev mimo proces – jeden dlouho žijící proces nástroje Willage.Vpmg.Nastroj (net10) v režimu server,
/// JSON řádky přes stdin/stdout. Vláknově bezpečné (zámek, požadavky po sobě). Líný start; když nástroj chybí nebo spadne,
/// <see cref="Dostupny"/> = false a <see cref="Spust"/> vrací zástupnou texturu s popisem (editor běží dál).
/// </summary>
public sealed class ZdrojVpmgProces : IZdrojVpmg
{
    public const string RelativniNastroj = "cs/Willage.Vpmg.Nastroj/bin/Release/net10.0/Willage.Vpmg.Nastroj.dll";
    readonly object _zamek = new();
    readonly string? _dll;
    readonly string _zrcadlo;
    Process? _p;
    long _id;
    string? _chyba;

    public string? CestaNastroje => _dll;
    /// <summary>Čas startu procesu (studený start .NET 10 + načtení katalogu), ms; 0 = ještě neběžel.</summary>
    public double MsStartu { get; private set; }

    public ZdrojVpmgProces(string zrcadloKatalogu, string? cestaNastroje = null)
    {
        _zrcadlo = Path.GetFullPath(zrcadloKatalogu);
        _dll = cestaNastroje ?? Najdi(Path.GetDirectoryName(_zrcadlo)!);
        if (_dll != null && !File.Exists(_dll)) _chyba = $"zástupné: nástroj VPMG {_dll} neexistuje";
        else if (_dll is null) _chyba = "zástupné: nástroj VPMG není sestaven (cs/Willage.Vpmg.Nastroj/priprav_dev.sh + dotnet build -c Release cs/Willage.Vpmg.Nastroj)";
    }

    /// <summary>Hledá nástroj: proměnná WILLAGE_VPMG_NASTROJ, jinak nahoru od <paramref name="start"/> po kořen repa.</summary>
    public static string? Najdi(string start)
    {
        var env = Environment.GetEnvironmentVariable("WILLAGE_VPMG_NASTROJ");
        if (!string.IsNullOrEmpty(env) && File.Exists(env)) return Path.GetFullPath(env);
        for (var d = new DirectoryInfo(start); d != null; d = d.Parent)
        {
            var f = Path.Combine(d.FullName, RelativniNastroj);
            if (File.Exists(f)) return f;
        }
        return null;
    }

    /// <summary>Spustitelný dotnet: WILLAGE_DOTNET, DOTNET_HOST_PATH, DOTNET_ROOT/dotnet, ~/.dotnet/dotnet, jinak „dotnet“ z PATH.</summary>
    public static string Dotnet()
    {
        foreach (var c in new[]
        {
            Environment.GetEnvironmentVariable("WILLAGE_DOTNET"), Environment.GetEnvironmentVariable("DOTNET_HOST_PATH"),
            Environment.GetEnvironmentVariable("DOTNET_ROOT") is { Length: > 0 } r ? Path.Combine(r, "dotnet") : null,
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".dotnet", "dotnet"),
        })
            if (!string.IsNullOrEmpty(c) && File.Exists(c)) return c;
        return "dotnet";
    }

    public bool Dostupny => _dll != null && _chyba == null;
    public string Popis => _chyba ?? $"VPMG mimo proces: {_dll}";

    void Start()
    {
        if (_p is { HasExited: false }) return;
        var sw = Stopwatch.StartNew();
        var psi = new ProcessStartInfo(Dotnet())
        {
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false,
            StandardOutputEncoding = new UTF8Encoding(false), StandardInputEncoding = new UTF8Encoding(false),
        };
        psi.ArgumentList.Add(_dll!); psi.ArgumentList.Add("--katalog"); psi.ArgumentList.Add(_zrcadlo); psi.ArgumentList.Add("server");
        _p = Process.Start(psi) ?? throw new InvalidOperationException("proces nástroje VPMG nešel spustit");
        _p.ErrorDataReceived += (_, _) => { };
        _p.BeginErrorReadLine();
        Pozadavek(new JsonObject { ["prikaz"] = "info" }); // zahřátí: načtení katalogu a registru
        MsStartu = sw.Elapsed.TotalMilliseconds;
    }

    /// <summary>Jeden požadavek → odpověď se stejným id. Výjimka = nástroj nedostupný nebo chyba protokolu.</summary>
    public JsonObject Pozadavek(JsonObject q)
    {
        lock (_zamek)
        {
            if (_dll is null) throw new InvalidOperationException(Popis);
            if (_p is null || _p.HasExited) { _p = null; StartBezZamku(); }
            long id = ++_id;
            q["id"] = id;
            _p!.StandardInput.WriteLine(q.ToJsonString());
            _p.StandardInput.Flush();
            while (true)
            {
                var r = _p.StandardOutput.ReadLine() ?? throw new InvalidOperationException("nástroj VPMG skončil (exit " + (_p.HasExited ? _p.ExitCode : -1) + ")");
                var o = JsonNode.Parse(r)!.AsObject();
                if ((long?)o["id"] == id) return o;
            }
        }
    }

    void StartBezZamku() { var p = _p; if (p is { HasExited: false }) return; Start(); }

    JsonObject Ok(JsonObject q)
    {
        var o = Pozadavek(q);
        if ((bool?)o["ok"] != true) throw new InvalidOperationException((string?)o["chyba"] ?? "chyba nástroje VPMG");
        return o;
    }

    public InfoVpmgDto Info()
    {
        if (!Dostupny) return new InfoVpmgDto(false, Popis, "", "", 0, Array.Empty<string>(), "");
        try
        {
            var o = Ok(new JsonObject { ["prikaz"] = "info" });
            return new InfoVpmgDto(true, Popis, (string)o["devCommit"]!, (string)o["katalog"]!, (int)o["materialu"]!,
                o["operace"]!.AsArray().Select(x => (string)x!).ToList(), (string)o["runtime"]!);
        }
        catch (Exception e) { _chyba = "zástupné: nástroj VPMG selhal – " + e.Message; return new InfoVpmgDto(false, Popis, "", "", 0, Array.Empty<string>(), ""); }
    }

    public TexturaVpmgDto Spust(RecepturaVpmgDto receptura, uint seed, NavrhProfiluDto? navrh = null)
    {
        var sw = Stopwatch.StartNew();
        if (!Dostupny) return Zastupna(receptura, Popis);
        var q = new JsonObject { ["prikaz"] = "spust", ["receptura"] = RecepturyVpmg.DoJson(receptura), ["seed"] = seed };
        if (navrh is { Prazdny: false })
        {
            var n = new JsonObject();
            if (navrh.Style != null) n["style"] = navrh.Style;
            if (navrh.BaseColor != null) n["baseColor"] = navrh.BaseColor;
            if (navrh.GrainScalePermille != null) n["grainScalePermille"] = navrh.GrainScalePermille;
            if (navrh.LayerDensityPermille != null) n["layerDensityPermille"] = navrh.LayerDensityPermille;
            if (navrh.IrregularityPermille != null) n["irregularityPermille"] = navrh.IrregularityPermille;
            if (navrh.Palette != null) n["palette"] = new JsonArray(navrh.Palette.Select(x => (JsonNode)x).ToArray());
            q["navrh"] = n;
        }
        JsonObject o;
        try { o = Pozadavek(q); }
        catch (Exception e) { _chyba = "zástupné: nástroj VPMG selhal – " + e.Message; return Zastupna(receptura, Popis); }
        if ((bool?)o["ok"] != true)
            return new TexturaVpmgDto(false, (string?)o["chyba"], 0, 0, "", 0, Array.Empty<byte>(), 0, sw.Elapsed.TotalMilliseconds);
        return new TexturaVpmgDto(true, null, (int)o["sirka"]!, (int)o["vyska"]!, (string)o["vrstva"]!, (uint)o["checksum"]!,
            Convert.FromBase64String((string)o["rgba"]!), (double)o["ms"]!, sw.Elapsed.TotalMilliseconds);
    }

    static TexturaVpmgDto Zastupna(RecepturaVpmgDto r, string popis) =>
        new(false, popis, r.Resolution, r.Resolution, "zastupna", 0, new byte[r.Resolution * r.Resolution * 4], 0, 0, true);

    public (uint Ocekavany, uint Spocteny) Golden()
    {
        var o = Ok(new JsonObject { ["prikaz"] = "golden" });
        return ((uint)o["ocekavany"]!, (uint)o["spocteny"]!);
    }

    /// <summary>T-2b: goldeny receptur v1 z fixture Dev v pinu (soubor, očekávaný, spočtený).</summary>
    public IReadOnlyList<(string Soubor, uint Ocekavany, uint Spocteny)> Goldeny() =>
        Ok(new JsonObject { ["prikaz"] = "goldeny" })["pripady"]!.AsArray().Select(x => ((string)x!["soubor"]!, (uint)x["ocekavany"]!, (uint)x["spocteny"]!)).ToList();

    /// <summary>T-2b: živý rozbor parametrů operací z Dev (stejný formát jako data/vpmg/operace_dev_v1.json).</summary>
    public string ParametryDevJson() => Ok(new JsonObject { ["prikaz"] = "parametry" }) is var o ? Ocisti(o).ToJsonString() : "";
    static JsonObject Ocisti(JsonObject o) { o.Remove("ok"); o.Remove("id"); return o; }

    public KontrolaZrcadlaDto KontrolaZrcadla(string zrcadlo)
    {
        var o = Ok(new JsonObject { ["prikaz"] = "katalog", ["zrcadlo"] = Path.GetFullPath(zrcadlo) });
        return new KontrolaZrcadlaDto((bool)o["bajtyBezKonce"]!, (bool)o["zaznamy"]!, (int)o["pocet"]!, (int)o["pocetDev"]!, (string)o["rozdil"]!);
    }

    public string Kanon(string recepturaJson) => (string)Ok(new JsonObject { ["prikaz"] = "kanon", ["receptura"] = recepturaJson })["receptura"]!;

    public void Dispose()
    {
        lock (_zamek)
        {
            if (_p is null) return;
            try
            {
                if (!_p.HasExited) { _p.StandardInput.WriteLine("{\"prikaz\":\"konec\"}"); _p.StandardInput.Flush(); if (!_p.WaitForExit(3000)) _p.Kill(); }
            }
            catch { }
            _p.Dispose(); _p = null;
        }
    }
}
