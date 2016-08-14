/***********************************************************************
 *                                                                     *
 * Copyright (C) 2016 P.Haemmerlein (http://www.yourfritz.de)          *
 *                                                                     *
 * This program is free software; you can redistribute it and/or       *
 * modify it under the terms of the GNU General Public License         *
 * as published by the Free Software Foundation; either version 2      *
 * of the License, or (at your option) any later version.              *
 *                                                                     *
 * This program is distributed in the hope that it will be useful,     *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of      *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       *
 * GNU General Public License for more details.                        *
 *                                                                     *
 * You should have received a copy of the GNU General Public License   *
 * along with this program, please look for the file COPYING.          *
 *                                                                     *
 ***********************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <inttypes.h>

int main(int argc, char * argv[])
{
	int c, cl;
	int ioffset = 0;
	int ooffset = 0;
	
	while ((c = getchar()) != EOF)
	{
		ioffset++;
		cl = c;
		if (c == 0) 
		{
			if ((c = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading number of consecutive zero bytes (0x%x -> %02x).\n\n", ioffset, cl);
				exit(1);
			}
			ioffset++;
			if (c == 0) break; // end of compressed content before end of file
//			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d zero bytes\n", ioffset, ooffset, c);
			while (c > 0)
			{
				putchar(0);
				ooffset++;
				c--;
			}
		}
		else if (c == 128)
		{
			int cnt;
			if ((cnt = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading repetition length (0x%x -> %02x).\n\n", ioffset, cl);
				exit(1);
			}
			ioffset++;
			if ((c = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading byte value to repeat (0x%x -> %02x %02x).\n\n", ioffset, cl, cnt);
				exit(1);
			}
			ioffset++;
//			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d bytes of %02x\n", ioffset, ooffset, cnt, c);
			while (cnt > 0)
			{
				putchar(c);
				ooffset++;
				cnt--;
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
				
					fprintf(stderr, "Unexpected end of file while reading repetition length (0x%x -> %02x).\n\n", ioffset, cl);
					exit(1);
				}
				ioffset++;
				cnt += (b << shift);
				shift += 8;
				len--;
			}					
			if ((c = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading byte value to repeat (0x%x -> %02x %04x).\n\n", ioffset, cl, cnt);
				exit(1); 
			}
			ioffset++;
//			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d bytes of %02x\n", ioffset, ooffset, cnt, c);
			while (cnt > 0)
			{
				putchar(c);
				ooffset++;
				cnt--;
			}
		}
		else if (c == 130)
		{
			int cnt;
			if ((cnt = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading repetition length (0x%x -> %02x).\n\n", ioffset, cl);
				exit(1);
			}
			ioffset++;
			c = 0x20;
//			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d bytes of %02x\n", ioffset, ooffset, cnt, c);
			while (cnt > 0)
			{
				putchar(c);
				ooffset++;
				cnt--;
			}
		}
		else if (c > 130)
		{
			int cnt = c - 128;
			if ((c = getchar()) == EOF)
			{
				fprintf(stderr, "Unexpected end of file while reading byte value to repeat (0x%x -> %02x).\n\n", ioffset, cl);
				exit(1);
			}
			ioffset++;
//			fprintf(stderr, "input=0x%08x output=0x%08x repeating %d bytes of %02x\n", ioffset, ooffset, cnt, c);
			while (cnt > 0)
			{
				putchar(c);
				ooffset++;
				cnt--;
			}
		}
		else // (c <= 127) is the last possibility here
		{
//			fprintf(stderr, "input=0x%08x output=0x%08x copying %d bytes: ", ioffset, ooffset, c);
			int ilog = ioffset;
			while (c > 0)
			{
				int chr;

				if ((chr = getchar()) == EOF)
				{
					fprintf(stderr, "Unexpected end of file while reading consecutive unique bytes (0x%x -> %02x -> 0x%d).\n\n", ilog, cl, ioffset - ilog);
					exit(1);
				}
				ioffset++;
//				fprintf(stderr, "%02x", chr);	
				putchar(chr);
				ooffset++;
				c--;
			}
//			fprintf(stderr, "\n");
		}
	}
	exit(0);
}
