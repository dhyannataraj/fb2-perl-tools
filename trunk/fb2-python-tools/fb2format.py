#!/usr/bin/python
# -*- coding: UTF-8 -*-

'''\
Usage:
     fb2format.py [<options>] [<fb2-files>]
Options:
     -h              display this help message and exit
     -V              display the version and exit
     -e <encoding>   output in the given encoding
     -s              sqeeze file in one line
     -b              sqeeze binaries in one line
     -k              create backup files
     -@ <file>       read file names from file (one name per line)
     -v              display progressbar
File name '-' means standard input/output.
'''

__author__ = 'Serhiy Storchaka <storchaka@sourceforge.net>'
__version__ = '0.1'

try:
	import psyco
	psyco.full()
except:
	pass

import re, base64
import sys, getopt, os, os.path, xml.dom.minidom, codecs, cStringIO

_spaces_re = re.compile( r'[ \t\r\n]{2,}|[\t\r\n]' )
_eols_re = re.compile( r'\n\n|\n \n|\n | \n' )
_end_tag_space_re = re.compile( ' (?=>)| (?=/>)' )
_start_tag_re = re.compile( '(<[^/?][^>]*>)', re.DOTALL )
_end_tag_re = re.compile( '(</[^>]*>|<[^/?][^>]*/>)', re.DOTALL )
def make_tags_switch( tags ):
	return re.compile( '(%s)' % '|'.join( '<%s(?: [^>]*)?>.*?</%s>' % (tag, tag) for tag in tags ), re.DOTALL )
def _make_tags_switch( tags ):
	return re.compile( '(%s)' % '|'.join( '<%s(?: [^>]*)?>.*?</%s>' % (tag, tag) for tag in tags ), re.DOTALL )
_text_re = _make_tags_switch( ('p', 'v', 'subtitle', 'text-author') )
_oneline_re = _make_tags_switch( ('title', 'author', 'translator') )
_binary_re = re.compile( '(<binary [^>]*>)([^<]*)(</binary>)', re.DOTALL )

def _remove_eols( m ):
	return m.group().replace( '\n', '' )

def _binary_squeeze( m ):
	return m.group( 1 ) + m.group( 2 ).replace( ' ', '' ) + m.group( 3 )

def _binary_recode( m ):
	return m.group( 1 ) + base64.encodestring( base64.decodestring( m.group( 2 ) ) ) + m.group( 3 )

def fb2format( data, squeeze = False, squeezeBinary = False ):
	data = _spaces_re.sub( ' ', data )
	data = _end_tag_space_re.sub( '', data )

	data = _start_tag_re.sub( r'\n\1', data )
	data = _end_tag_re.sub( r'\1\n', data )
	data = _text_re.sub( _remove_eols, data )
	data = _eols_re.sub( '\n', data ).strip()

	data = _oneline_re.sub( _remove_eols, data )
	if squeezeBinary:
		data = _binary_re.sub( _binary_squeeze, data )
	else:
		data = _binary_re.sub( _binary_recode, data )

	if squeeze:
		data = data.replace( '\n', '' )
	else:
		data = data.replace( '>\n<title>', '><title>' )

	return data


if __name__ == '__main__':
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:e:hkstvV' )
	except getopt.GetoptError, err:
		print >>sys.stderr, 'Error:', err
		sys.exit( 2 )

	forceEncoding = None
	squeeze = False
	squeezeBinary = False
	keepBackup = False
	backupSuffix = '.bak'
	verbose = False

	for option, value in opts:
		if option == '-h':
			print __doc__
			sys.exit( 0 )
		elif option == '-V':
			print __version__
			sys.exit( 0 )
		elif option == '-@':
			if value == '-':
				args.extend( line.rstrip( '\n' ) for line in sys.stdin )
			else:
				args.extend( line.rstrip( '\n' ) for line in open( value ) )
		elif option == '-e':
			forceEncoding = value
		elif option == '-k':
			keepBackup = True
		elif option == '-s':
			squeeze = True
		elif option == '-b':
			squeezeBinary = True
		elif option == '-v':
			verbose = True

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args, os.path.basename, sys.stderr )

	for filename in args:
		try:
			if filename == '-':
				data0 = sys.stdin.read()
			else:
				data0 = open( filename, 'r' ).read()

			doc = xml.dom.minidom.parseString( data0 )
			encoding = forceEncoding or doc.encoding or 'UTF-8'
			data = doc.toxml( 'UTF-8' )
			data = fb2format( data, squeeze = squeeze, squeezeBinary = squeezeBinary )
			doc = xml.dom.minidom.parseString( data )

			if filename == '-':
				writer = codecs.getwriter( encoding )( sys.stdout,  'xmlcharrefreplace' )
				doc.writexml( writer, encoding = encoding )
				writer.close()
			else:
				writer = cStringIO.StringIO()
				writer = codecs.getwriter( encoding )( writer,  'xmlcharrefreplace' )
				doc.writexml( writer, encoding = encoding )
				data = writer.getvalue()
				writer.close()
				if data != data0:
					open( filename + '.tmp', 'w' ).write( data )
					if keepBackup:
						os.rename( filename, filename + backupSuffix )
					os.rename( filename + '.tmp', filename )
		except (KeyboardInterrupt, SystemExit):
			raise
		except Exception, err:
			print >>sys.stderr, 'Error processing %s:' % filename
			print >>sys.stderr, err
