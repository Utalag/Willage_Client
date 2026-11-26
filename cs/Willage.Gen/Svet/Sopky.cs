using Willage.Gen.Sum;

namespace Willage.Gen.Svet;

/// <summary>Jedna sopka (1.14): střed, výška, poloměr úpatí, kráter, výška okolí.</summary>
public sealed record Sopka(double X, double Y, double H, double R, double Rc, double D, double Gamma, double VyskaOkoli);

/// <summary>
/// svet_fn.gd::_sopky a _kuzel. Středy jsou Vector2 (float32) jako v Godotu – proto float aritmetika u polohy.
/// Sopka si přepíše bod mapy biomů své buňky (typ sopečná oblast).
/// </summary>
public sealed class Sopky
{
    public readonly List<Sopka> Seznam = new();
    public readonly double TanSopka;

    public Sopky(ParametrySveta p, HashSveta h, MapaBiomu mb, Func<double, double, double[], double> vyskaBezSopek,
        Relief rel, double svetM, double stropPovrchu)
    {
        int n = p.Sopek; double d = p.SopkyRoztecM, tol = p.SopkyRoztecTol, okraj = p.SopkyOkrajM;
        double ts = Math.Tan(Gd.DegToRad(p.SopkaSklonDeg));
        TanSopka = Math.Tan(Gd.DegToRad(p.SopkaStropDeg));
        double tanRel = rel.TanStrop[MapaBiomu.Sopecna];
        var stred = new List<(float x, float y)>();
        float st0x = (float)p.StartBlok[0] * (float)p.BlokM, st0y = (float)p.StartBlok[1] * (float)p.BlokM;
        double dOut = p.SopkaOdOkrajeStartuM, strana = 384.0 + 2.0 * dOut;
        double t0 = h.U("V1_SOPKA_START", 0, 0) * 4.0 * strana;
        double x0 = st0x - dOut, y0 = st0y - dOut;
        (float x, float y) c0;
        if (t0 < strana) c0 = ((float)(x0 + t0), (float)y0);
        else if (t0 < 2.0 * strana) c0 = ((float)(x0 + strana), (float)(y0 + (t0 - strana)));
        else if (t0 < 3.0 * strana) c0 = ((float)(x0 + strana - (t0 - 2.0 * strana)), (float)(y0 + strana));
        else c0 = ((float)x0, (float)(y0 + strana - (t0 - 3.0 * strana)));
        c0.x = (float)Gd.Clampf(c0.x, okraj, svetM - okraj);
        c0.y = (float)Gd.Clampf(c0.y, okraj, svetM - okraj);
        stred.Add(c0);
        for (int i = 1; i < n; i++)
        {
            (float x, float y) c = (0f, 0f);
            for (int pokus = 0; pokus < 64; pokus++)
            {
                double uh = h.U("V1_SOPKA_U", i, pokus) * Gd.Tau;
                double dd = d * (1.0 + tol * 0.8 * (2.0 * h.U("V1_SOPKA_D", i, pokus) - 1.0));
                float fd = (float)dd;
                var pr = stred[i - 1];
                c = (pr.x + (float)Math.Cos(uh) * fd, pr.y + (float)Math.Sin(uh) * fd);
                bool ok = c.x >= okraj && c.y >= okraj && c.x <= svetM - okraj && c.y <= svetM - okraj;
                foreach (var q in stred)
                {
                    float dx = c.x - q.x, dy = c.y - q.y;
                    if (MathF.Sqrt(dx * dx + dy * dy) < d * (1.0 - tol)) ok = false;
                }
                if (ok) break;
            }
            stred.Add(c);
        }
        foreach (var c in stred)
        {
            long a = Gd.Floori(c.x / mb.S) + 2, b = Gd.Floori(c.y / mb.S) + 2;
            long k = a * mb.N + b;
            mb.X[k] = c.x; mb.Y[k] = c.y; mb.T[k] = MapaBiomu.Sopecna;
        }
        for (int i = 0; i < n; i++)
        {
            var c = stred[i];
            double t = h.U("V1_SOPKA_VEL", i, 0);
            double hs = Gd.Lerpf(p.SopkaVyskaMinM, p.SopkaVyskaMaxM, t);
            var w = mb.Vahy(c.x, c.y);
            double h0 = vyskaBezSopek(c.x, c.y, w);
            double rezerva = 2.0 * rel.Amp[MapaBiomu.Sopecna] + 0.5;
            double hmax = stropPovrchu - h0 - rezerva;
            double hef = Gd.Minf(hs, hmax);
            double rz = hef / ts;
            double rc = p.KraterRPodil * rz;
            double gamma = Gd.Minf(p.SopkaGamma, (0.95 * TanSopka - tanRel) / ts);
            double dk = Gd.Minf(p.KraterHloubkaPodil * hef, 0.5 * rc * (0.95 * TanSopka - tanRel));
            Seznam.Add(new Sopka(c.x, c.y, hef, rz + rc, rc, dk, gamma, h0));
        }
    }

    public double Kuzel(int i, double r)
    {
        var s = Seznam[i];
        if (r >= s.R) return 0.0;
        if (r >= s.Rc) return s.H * Math.Pow((s.R - r) / (s.R - s.Rc), s.Gamma);
        double q = r / s.Rc;
        return s.H - s.D * (1.0 - q * q);
    }
}
