using System.Diagnostics;

namespace Willage.Gen.Testy.Vykon;

/// <summary>Zaznamená zátěž boxu (loadavg a nejvytíženější procesy mimo měření). Procesy se jen čtou, nikdy se neukončují.</summary>
public static class VykonZatez
{
    public static string Loadavg() { try { return File.ReadAllText("/proc/loadavg").Split(' ')[0]; } catch { return "?"; } }

    /// <summary>Součet CPU % procesů mimo tento proces (a jeho potomky) z <c>ps</c> a seznam největších.</summary>
    public static (double CpuCizi, string Popis) Cizi()
    {
        try
        {
            var psi = new ProcessStartInfo("ps", "-eo pid,pcpu,rss,args --sort=-pcpu") { RedirectStandardOutput = true, UseShellExecute = false };
            using var p = Process.Start(psi)!; var txt = p.StandardOutput.ReadToEnd(); p.WaitForExit();
            double suma = 0; var top = new List<string>(); int me = Environment.ProcessId;
            foreach (var r in txt.Split('\n').Skip(1))
            {
                var t = r.Trim(); if (t.Length == 0) continue;
                var c = t.Split(' ', 4, StringSplitOptions.RemoveEmptyEntries); if (c.Length < 4) continue;
                if (!int.TryParse(c[0], out int pid) || pid == me) continue;
                if (c[3].Contains("Willage.Gen.Testy") || c[3].StartsWith("ps ")) continue;
                if (!double.TryParse(c[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out double cpu)) continue;
                if (cpu < 20) continue;
                suma += cpu; top.Add($"PID {pid} {cpu:F0} % {(c[3].Length > 40 ? c[3][..40] : c[3])}");
            }
            return (suma, string.Join("; ", top.Take(4)));
        }
        catch { return (double.NaN, "ps nedostupný"); }
    }
}
