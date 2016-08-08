#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <inttypes.h>

int main(int argc, char * argv[])
{
	int c;
	int ioffset = 0;
	int ooffset = 0;
	
	while ((c = getchar()) != EOF)
	{
		ioffset++;
		if (c == 0) 
		{
			if ((c = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading number of consecutive zero bytes.\n\n");
				exit(1);
			}
			ioffset++;
			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d zero bytes\n", ioffset, ooffset, c);
			while (c > 0)
			{
				putchar(0);
				ooffset++;
				c--;
			}
		}
		else if (c == 129)
		{
			int len = 2;
			int shift = 0;
			int cnt = 0;
			while (len > 0)
			{
				int b;
		
				if ((b = getchar()) == EOF)
				{
					fprintf(stderr, "Unexpected end of file while reading repetition length.\n\n");
					exit(1);
				}
				ioffset++;
				cnt += (b << shift);
				shift += 8;
				len--;
			}					
			if ((c = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading byte value to repeat.\n\n");
				exit(1);
			}
			ioffset++;
			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d bytes of %02x\n", ioffset, ooffset, cnt, c);
			while (cnt > 0)
			{
				putchar(c);
				ooffset++;
				cnt--;
			}
		}
		else if (c > 129)
		{
			int cnt = c - 128;
			if ((c = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading byte value to repeat.\n\n");
				exit(1);
			}
			ioffset++;
			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d bytes of %02x\n", ioffset, ooffset, cnt, c);
			while (cnt > 0)
			{
				putchar(c);
				ooffset++;
				cnt--;
			}
		}
		else if (c <= 127)
		{
			fprintf(stderr, "input=0x%08x output=0x%08x copying %d bytes: ", ioffset, ooffset, c);
			while (c > 0)
			{
				int chr;

				if ((chr = getchar()) == EOF)
				{
					fprintf(stderr, "Unexpected end of file while reading consecutive unique bytes.\n\n");
					exit(1);
				}
				ioffset++;
				fprintf(stderr, "%02x", chr);	
				putchar(chr);
				ooffset++;
				c--;
			}
			fprintf(stderr, "\n");
		}
		else
		{
			fprintf(stderr, "input=0x%08x output=0x%08x unexpected value %02x.\n\n", ioffset, ooffset, c);
//			exit(1);
		}
	}
	exit(0);
}
