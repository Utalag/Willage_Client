using System.Text;

namespace Willage.Gen.Data;

/// <summary>Jednoduché čtení CSV jako FileAccess.get_csv_line (čárka, uvozovky, "" uvnitř uvozovek).</summary>
public static class Csv
{
    public static IEnumerable<List<string>> Radky(string text)
    {
        var row = new List<string>(); var cell = new StringBuilder(); bool q = false;
        for (int i = 0; i < text.Length; i++)
        {
            char c = text[i];
            if (q)
            {
                if (c == '"') { if (i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; } else q = false; }
                else cell.Append(c);
            }
            else if (c == '"') q = true;
            else if (c == ',') { row.Add(cell.ToString()); cell.Clear(); }
            else if (c == '\n' || c == '\r')
            {
                if (c == '\r' && i + 1 < text.Length && text[i + 1] == '\n') i++;
                row.Add(cell.ToString()); cell.Clear(); yield return row; row = new List<string>();
            }
            else cell.Append(c);
        }
        if (cell.Length > 0 || row.Count > 0) { row.Add(cell.ToString()); yield return row; }
    }
}
