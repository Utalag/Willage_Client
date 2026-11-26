namespace Willage.Gen.Eroze;

/// <summary>Periodická mřížka uzlů na torusu: uzel (i, j) leží v (i·krok, j·krok), index k = j·nx + i.</summary>
public sealed class Torus
{
    public readonly int Nx, Ny; public readonly double Krok;
    public int N => Nx * Ny;
    /// <summary>D8: dx, dy a délka kroku (v násobcích kroku mřížky).</summary>
    public static readonly int[] Dx = { 1, -1, 0, 0, 1, 1, -1, -1 }, Dy = { 0, 0, 1, -1, 1, -1, 1, -1 };
    public static readonly double[] Delka = { 1, 1, 1, 1, Math.Sqrt(2), Math.Sqrt(2), Math.Sqrt(2), Math.Sqrt(2) };

    public Torus(int nx, int ny, double krok) { Nx = nx; Ny = ny; Krok = krok; }

    public static int Mod(int a, int n) { int r = a % n; return r < 0 ? r + n : r; }
    public int K(int i, int j) => Mod(j, Ny) * Nx + Mod(i, Nx);
    public int Soused(int k, int d) => K(k % Nx + Dx[d], k / Nx + Dy[d]);
    public (double x, double y) Poloha(int k) => (k % Nx * Krok, k / Nx * Krok);
}
