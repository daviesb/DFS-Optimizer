using System;
using System.Diagnostics;
using System.IO;

namespace DFS_Optimizer
{
    class Program
    {
        static void Main(string[] args)
        {
            string rpath = @"/usr/bin/R";
            string scriptpath = @"'~/Documents/sources/DFS-Optimizer/NBAOptimizer.R";
            string output = RunRScript(rpath, scriptpath);

            Console.WriteLine(output);
            Console.ReadLine();

        }

        private static string RunRScript(string rpath, string scriptpath)
        {
            try
            {
                var info = new ProcessStartInfo
                {
                    FileName = rpath,
                    WorkingDirectory = Path.GetDirectoryName(scriptpath),
                    Arguments = scriptpath,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true,
                    UseShellExecute = false
                };

                using(var proc = new Process {StartInfo = info})
                {
                    proc.Start();
                    return proc.StandardOutput.ReadToEnd();

                }
                
            }
            catch(Exception ex)
            {
                Console.WriteLine(ex.StackTrace);
                Console.WriteLine(ex.Message);
            }
            return string.Empty;
        }
    }
}