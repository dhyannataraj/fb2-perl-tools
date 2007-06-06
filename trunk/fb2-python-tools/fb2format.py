#!/usr/bin/python
# -*- coding: UTF-8 -*-

try:
	import psyco
	psyco.full()
except:
	pass
import sys, xml.dom.minidom, re, base64
import os, os.path, getopt
import cStringIO, codecs

_spaces_re = re.compile( r'[ \t\r\n]{2,}|[\t\r\n]' )
_eols_re = re.compile( r'\n\n|\n \n|\n | \n' )
_end_tag_space_re = re.compile( ' (?=>)| (?=/>)' )
_start_tag_re = re.compile( '(<[^/?][^>]*>)', re.DOTALL )
_end_tag_re = re.compile( '(</[^>]*>|<[^/?][^>]*/>)', re.DOTALL )
def _make_tags_switch( tags ):
	return re.compile( '(%s)' % '|'.join( '<%s(?: [^>]*)?>.*?</%s>' % (tag, tag) for tag in tags ), re.DOTALL )
_text_re = _make_tags_switch( ('p', 'v', 'subtitle', 'text-author') )
_oneline_re = _make_tags_switch( ('title', 'author', 'translator') )
_binary_re = re.compile( '(<binary [^>]*>)([^<]*)(</binary>)', re.DOTALL )

def _remove_eols( m ):
	return m.group().replace( '\n', '' )

def _binary_repl( m ):
	data = m.group( 2 ).replace( ' ', '' )
	base64.decodestring( data ) # validate
	return m.group( 1 ) + data + m.group( 3 )

def fb2format( data, squeeze = False, encoding = 'UTF-8' ):
	data = xml.dom.minidom.parseString( data ).toxml( 'UTF-8' )
	data = _spaces_re.sub( ' ', data )
	data = _end_tag_space_re.sub( '', data )

	data = _start_tag_re.sub( r'\n\1', data )
	data = _end_tag_re.sub( r'\1\n', data )
	data = _text_re.sub( _remove_eols, data )
	data = _eols_re.sub( '\n', data ).strip()

	data = _oneline_re.sub( _remove_eols, data )
	data = _binary_re.sub( _binary_repl, data )

	if squeeze:
		data = data.replace( '\n', '' )
	else:
		data = data.replace( '>\n<title>', '><title>' )

# 	data = xml.dom.minidom.parseString( data ).toxml( encoding )
	writer = cStringIO.StringIO()
	writer = codecs.lookup( encoding )[3]( writer,  'xmlcharrefreplace' )
	xml.dom.minidom.parseString( data ).writexml( writer, encoding = encoding )
	data = writer.getvalue()
	writer.close()
	return data

__doc__ = '''Usage:
     fb2format.py [<options>] [<fb2-files>]
Options:
     -h              display this help message and exit
     -e <encoding>   output in the given encoding
     -s              sqeeze file in one line
     -k              create backup files
     -@              read file names from STDIN (one name per line)
     -v              display progressbar
'''

if __name__ == '__main__':
	import getopt
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@e:hkstv' )
	except getopt.GetoptError:
		# print help information and exit:
		print >>sys.stderr, 'Illegal option'
		sys.exit( 2 )

	encoding = 'UTF-8'
	squeeze = False
	testOnly = False
	keepBackup = False
	backupSuffix = '.bak'
	verbose = False

	for option, value in opts:
		if option == '-h':
			print __doc__
			sys.exit( 0 )
		elif option == '-@':
			args.extend( line.rstrip( '\n' ) for line in sys.stdin )
		elif option == '-e':
			encoding = value
		elif option == '-k':
			keepBackup = True
		elif option == '-s':
			squeeze = True
		elif option == '-t':
			testOnly = True
		elif option == '-v':
			verbose = True

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args, os.path.basename, sys.stderr )

	for filename in args:
		try:
			data0 = open( filename, 'r' ).read()
			data = fb2format( data0, encoding = encoding, squeeze = squeeze )
			if data != data0:
				print filename
				open( filename + '.tmp', 'w' ).write( data )
				if not testOnly:
					if keepBackup:
						os.rename( filename, filename + backupSuffix )
					os.rename( filename + '.tmp', filename )
		except (KeyboardInterrupt, SystemExit):
			raise
		except Exception, err:
			print >>sys.stderr, 'Error processing %s:' % filename
			print >>sys.stderr, err
