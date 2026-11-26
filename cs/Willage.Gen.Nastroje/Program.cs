using Willage.Gen.Data;
using Willage.Gen.Nastroje;

var data = DataSveta.Najdi(AppContext.BaseDirectory);
string cmd = args.Length > 0 ? args[0] : "";
return cmd switch
{
    "vyska" => PorovnejVysku.Spust(args[1], data) == 0 ? 0 : 1,
    _ => Napoveda(),
};

static int Napoveda() { Console.WriteLine("použití: vyska <bin>"); return 2; }
