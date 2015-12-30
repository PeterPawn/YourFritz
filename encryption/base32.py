#! /usr/bin/python3
import sys
import os

class Base32Exception(Exception):
	pass	

class Base32:
	def Encode(self, input):
		if type(input).__name__ != 'bytes':
			raise Base32Exception("Input data has to be of type 'bytes'.")
		if (len(input) % 5) != 0:
			raise Base32Exception('Invalid length of binary input data.')
		output = b''
		index_input = 0
		while index_input < len(input):
			binary = bytes(input[index_input:index_input+5])
			p = int.from_bytes(binary, byteorder='big', signed=False)
			s = b''
			for j in range(8):
				k = (p >> (j * 5)) & 31
				c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ123456'[k]
				s = bytes(c, 'ascii') + s
			output += s
			index_input += 5
		return output

	def Decode(self, input):
		if type(input).__name__ != 'bytes':
			raise Base32Exception("Input data has to be of type 'bytes'.")
		if (len(input) % 8) != 0:
			raise Base32Exception('Invalid length of text input data.')
		output = bytearray()
		index_input = 0
		while index_input < len(input):
			out = bytearray(5)
			val = 0
			for j in range(8):
				c = input[index_input + j]
				try:
					v = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ123456'.index(chr(c))
				except ValueError:
					raise Base32Exception('Invalid character found at text input data.')
				val = (val << 5) + v
			for k in range(5):
				o = val & 255
				out[4 - k] = o	
				val = val >> 8
			output.extend(out)
			index_input += 8
		return output
	
if __name__ == '__main__':
	rc = 1
	if sys.argv[1] == 'test':
		if Base32().Encode(b'\xFF\xFF\xFF\xFF\xFF') != b'66666666':
			raise Base32Exception('Error encoding all-ones buffer.')
		if Base32().Encode(b'\x00\x00\x00\x00\x00') != b'AAAAAAAA':
			raise Base32Exception('Error encoding all-zeros buffer.')
		if Base32().Encode(b'\x00\x44\x32\x14\xC7') != b'ABCDEFGH':
			raise Base32Exception("Error encoding to 'ABCDFEGH'.")
		if Base32().Encode(b'\x39\x8A\x41\x88\x20') != b'HGFEDCBA':
			raise Base32Exception("Error encoding to 'HGFEDCBA'.")
		if Base32().Decode(bytes('66666666', 'ascii')) != b'\xFF\xFF\xFF\xFF\xFF':
			raise Base32Exception('Error decoding to all-ones buffer.')
		if Base32().Decode(bytes('AAAAAAAA', 'ascii')) != b'\x00\x00\x00\x00\x00':
			raise Base32Exception('Error decoding to all-zeros buffer.')
		if Base32().Decode(bytes('ABCDEFGH', 'ascii')) != b'\x00\x44\x32\x14\xC7':
			raise Base32Exception("Error decoding from 'ABCDFEGH'.")
		if Base32().Decode(bytes('HGFEDCBA', 'ascii')) != b'\x39\x8A\x41\x88\x20':
			raise Base32Exception("Error decoding from 'HGFEDCBA'.")
		for i in range(10):
			binary = bytes(os.urandom(i*5))
			encoded = Base32().Encode(binary)
			decoded = Base32().Decode(encoded)
			if binary != decoded:
				raise Base32Exception("Error comparing original byte array contents and result after encoding/decoding calls.")
		print('Tests done.', file=sys.stderr)
		rc = 0
	elif sys.argv[1] == 'encode':
		input = sys.stdin.buffer.read()
		output = Base32().Encode(input)
		sys.stdout.write(output.decode('ascii'))
		rc = 0
	elif sys.argv[1] == 'decode':
		input = sys.stdin.buffer.read()
		sys.stdout.buffer.write(Base32().Decode(input))
		rc = 0
	else:
		print("Unknown mode '{0:s}'.".format(sys.argv[1]), file=sys.stderr)
	sys.exit(rc)
