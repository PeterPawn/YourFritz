using System;

namespace YourFritz.Helpers
{
    class HexDump
    {
        private HexDump() { }

        public static string Dump(byte[] input)
        {
            System.Text.StringBuilder output = new System.Text.StringBuilder();
            int index = 0;
            int lastIndex = 0;

            {
                System.Text.StringBuilder line = new System.Text.StringBuilder();
                int b;
                string lastLine = System.String.Empty;

                for (index = 0; index < input.Length; index += 16)
                {
                    line.Clear();

                    for (b = 0; b < Math.Min(16, input.Length - index); b++)
                    {
                        line.Append(String.Format("{0:x2} ", input[index + b]));
                        if (b == 7) line.Append(" ");
                    }

                    if (b < 8) line.Append(" ");
                    while (b++ < 16) line.Append("   ");

                    line.Append(" |");
                    for (b = 0; b < Math.Min(16, input.Length - index); b++)
                    {
                        if ((input[index + b] < 32) || (input[index + b] > 127))
                        {
                            line.Append(".");
                        }
                        else
                        {
                            line.Append(System.Text.Encoding.ASCII.GetChars(input, index + b, 1));
                        }
                    }
                    line.Append("|");

                    if (line.ToString().CompareTo(lastLine) != 0)
                    {
                        if ((index > 0) && (lastIndex != (index - 16)) && (index < input.Length)) output.AppendLine("*");
                        lastLine = line.ToString();
                        output.AppendLine(String.Format("{0:x8}  {1:s}", index, lastLine));
                        lastIndex = index;
                    }
                }
            }

            if (lastIndex != (index - 16)) output.AppendLine("*");

            output.AppendLine(String.Format("{0:x8}", input.Length));

            return output.ToString();
        }
    }
}