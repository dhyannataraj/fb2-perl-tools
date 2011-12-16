#!/usr/bin/python
# -*- coding: utf-8 -*-

'''\
Usage:
     fb2format.py [options] [fb2-files]

Options:
     -h, --help                        display this help message and exit
     -V, --version                     display the version and exit
     -e ENCODING, -encoding ENCODING   output in the given encoding
     -f, --format                      convert file to human readable format
     -s, --squeeze                     squeeze file in one line
     -b, --squeeze-binaries            squeeze binaries in one line
     -k, --backup                      create backup files
     -@ FILE                           read file names from FILE (one name per line)
     -v, --progress                    display progressbar

File name '-' means standard input.
'''

from __future__ import division, print_function, unicode_literals
__author__ = 'Serhiy Storchaka <storchaka@users.sourceforge.net>'
__version__ = '0.2'

try:
	import psyco
	psyco.full()
except:
	pass

import re, base64
import sys, getopt, os, os.path, xml.dom.minidom, codecs, io

_spaces_re = re.compile( br'[ \t\r\n]{2,}|[\t\r\n]' )
_empty_element_re = re.compile( br'<([^ >]+)([^>]*)(?<!/)></\1>' )
def _make_tags_switch( tags ):
	return re.compile( b'(' + b'|'.join( b'<' + tag + b'(?: [^>]*)?>.*?</' + tag + b'>' for tag in tags ) + b')', re.DOTALL )
_text_re = _make_tags_switch( (b'p', b'v', b'subtitle', b'text-author', b'th', b'td') )
_oneline_re = _make_tags_switch( (b'title', b'author', b'translator') )
_binary_re = re.compile( b'(<binary [^>]*>)([^<]*)(</binary>)', re.DOTALL )

def _remove_eols( m ):
	return m.group().replace( b'\n', b'' )

def _binary_squeeze( m ):
	return m.group( 1 ) + m.group( 2 ).replace( b' ', b'' ) + m.group( 3 )

def _binary_recode( m ):
	return m.group( 1 ) + base64.b64encode( base64.b64decode( m.group( 2 ) ) ) + m.group( 3 )

def _squeeze_tag( s ):
	if _text_re.match( s ):
		return s
	else:
		return _empty_element_re.sub( br'<\1\2/>', s.strip( b' ' ).replace( b'> ', b'>' ).replace( b' <', b'<' ) )

def _format_tag( s ):
	if _text_re.match( s ):
		return s
	else:
		return _empty_element_re.sub( br'<\1\2/>', s.strip( b' ' ).replace( b'> ', b'>' ).replace( b' <', b'<' ) ).replace( b'><', b'>\n<' )

def fb2format( data, squeeze = False, squeezeBinary = False ):
	data = _spaces_re.sub( b' ', data )

	if squeeze:
		data = b''.join( _squeeze_tag( s ) for s in _text_re.split( data ) )
		data = data.replace( b'>', b'>\n', 1 )
	else:
		data = b'\n'.join( s for s in (_format_tag( s ) for s in _text_re.split( data )) if s )
		data = _oneline_re.sub( _remove_eols, data )
		data = data.replace( b'>\n<title>', b'><title>' )

	if squeezeBinary or squeeze:
		data = _binary_re.sub( _binary_squeeze, data )
	else:
		data = _binary_re.sub( _binary_recode, data )

	return data


if __name__ == '__main__':
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:be:fhksvV',
			['backup', 'encoding=', 'format', 'help', 'progress', 'squeeze', 'squeeze-binaries', 'version'] )
	except getopt.GetoptError as err:
		print( 'Error:', err, file = sys.stderr )
		sys.exit( 2 )

	forceEncoding = None
	format = False
	squeeze = False
	squeezeBinary = False
	keepBackup = False
	backupSuffix = '.bak'
	verbose = False

	for option, value in opts:
		if option in ('-h', '--help'):
			sys.stdout.write( __doc__ )
			sys.exit( 0 )
		elif option in ('-V', '--version'):
			print( __version__ )
			sys.exit( 0 )
		elif option == '-@':
			if value == '-':
				args.extend( line.rstrip( str( '\n' ) ) for line in sys.stdin )
			else:
				args.extend( line.rstrip( '\n' ) for line in open( value ) )
		elif option in ('-e', '--encoding'):
			forceEncoding = value
		elif option in ('-k', '--backup'):
			keepBackup = True
		elif option in ('-f', '--format'):
			format = True
		elif option in ('-s', '--squeeze'):
			format = True
			squeeze = True
		elif option in ('-b', '--squeeze-binaries'):
			squeezeBinary = True
		elif option in ('-v', '--progress'):
			verbose = True

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args )

	for filename in args:
		try:
			if filename == str( '-' ):
				if sys.version_info[0] >= 3:
					f = sys.stdin.buffer.raw
				else:
					f = sys.stdin
				data0 = f.read()
			else:
				data0 = open( filename, 'rb' ).read()

			doc = xml.dom.minidom.parse( io.BytesIO( data0 ) )
			encoding = forceEncoding or doc.encoding or str( 'utf-8' )
			writer = io.BytesIO()
			writer = codecs.getwriter( encoding )( writer,  'xmlcharrefreplace' )
			doc.writexml( writer, encoding = encoding )
			data = writer.getvalue()
			writer.close()

			if format:
				data = fb2format( data, squeeze = squeeze, squeezeBinary = squeezeBinary )

			if filename == str( '-' ):
				if sys.version_info[0] >= 3:
					f = sys.stdout.buffer.raw
				else:
					f = sys.stdout
				f.write( data )
			elif data != data0:
				tmpfilename = filename + str( '.tmp' )
				open( tmpfilename, 'wb' ).write( data )
				if keepBackup:
					os.rename( filename, filename + backupSuffix )
				os.rename( tmpfilename, filename )
		except (KeyboardInterrupt, SystemExit):
			raise
		except Exception as err:
			print( str( 'Error processing "%s":' ) % filename, file = sys.stderr )
			print( err, file = sys.stderr )
