#!/usr/bin/python
# -*- coding: utf-8 -*-

'''\
Usage:
     fb2clean.py [options] [fb2-files]

Options:
     -h, --help       display this help message and exit
     -V, --version    display the version and exit
     -k, --backup     create backup files
     -@ FILE          read file names from FILE (one name per line)
     -v, --progress   display progressbar

File name '-' means standard input.
'''
from __future__ import division, print_function, unicode_literals
__author__ = 'Serhiy Storchaka <storchaka@users.sourceforge.net>'
__version__ = '0.2'
__all__ = []

import re
import sys, getopt, os, os.path, xml.dom.minidom, codecs, io

fix_h2_re = re.compile( r'<h2 xmlns="">Taken: \w*, 1</h2>', re.UNICODE )
# fix_style_re = re.compile( r'(<style name="\w*">)|(</style>)' )
empty_style_re = re.compile( '|'.join(
	r'<%s/>|</%s><%s>|<%s></%s>' % (tag, tag, tag, tag, tag)
	for tag in ('emphasis', 'strong', 'sub', 'sup')
	) + r'<style [^>]*/>|<style [^>]*></style>', re.DOTALL )
start_emphasis = r'<emphasis>|<strong>|<style [^>]*>|<a [^>]*>'
end_emphasis = r'</emphasis>|</strong>|</style>|</a>'
fix_emphasis1_re = re.compile( r'(\s+)(%s)' % end_emphasis, re.UNICODE )
fix_emphasis2_re = re.compile( r'(%s)(?=\w)' % end_emphasis, re.UNICODE )
fix_emphasis3_re = re.compile( r'([ \u00A0]*[\u2013\u2014-]+)(%s)' % end_emphasis, re.UNICODE )
mdash_re = re.compile( r'(?:[ \u00A0]|(?<=[,.?!:"\u2026]))[\u2013\u2014-]+(?:[ \u00A0]|(?=\w)|(?=<[^/]))', re.UNICODE )
end_mdash_re = re.compile( r'[ \u00A0][\u2013\u2014-]+[ \u00A0](?:(?=</p>)|(?=</v>)|(?=</subtitle>))' )
dialog_re = re.compile( r'(<(?:p|v|subtitle)\b[^>]*>(?:\s*(?:%s))*)\s*[\u2013\u2014-]+\s*' % start_emphasis, re.UNICODE )
# fix_emphase_re = re.compile( r'[ \u00A0][\u2013\u2014-][ \u00A0](</emphase>)' )
empty_line_re = re.compile( r'<empty-line/>\s*(?=<)(?!<p\b)|(?<=>)(?<!</p>)\s*<empty-line/>', re.UNICODE )
stars_re = re.compile( '|'.join(
	r'<%s(?: id="[^">]+")?>(?:%s)* ?(?:[*](?: [*]){2,}|[*]{3,}|x x x) ?(?:%s)*</%s>' % (start, start_emphasis, end_emphasis, end)
	for start, end in (('p', 'p'), ('subtitle', 'subtitle'), (r'/section>\s*<section>\s*<title><p', r'p>\s*</title'))
	), re.UNICODE|re.DOTALL )


# defis_str1 = [r'(?<=\b%s)[\u2013\u2014-][ \u00A0]' % pre for pre in
# 	('по', 'в', 'во', 'из', 'кое')]
# defis_str2 = [r'([\u2013\u2014-][ \u00A0]|[ \u00A0][\u2013\u2014-])(?=%s\b)' % post for post in
# 	('то', 'нибудь', 'таки', 'либо', 'никак', 'никак(?:ой|им|ом|ая|ую|ое)', 'никак(?:ого|ому)', 'стрит', 'летн(?:ий|им|ем|яя|юю|ей|ее|ии|их)', 'летн(?:его|ему|ими)')]
# # 	'й', 'х', 'го', 'е', 'м', 'я', 'мм', 'ка', 'ю',
# fix_defis_re = re.compile( '|'.join( defis_str1 + defis_str2 ), re.UNICODE|re.IGNORECASE )

ndash_re = re.compile( r'(?<=[0-9])[\u2013\u2014-][ \u00A0]?(?=[0-9])' )
fix_date_re = re.compile( r'(?<=value=")(?P<y>\d+)\u2013(?P<m>\d+)\u2013(?P<d>\d+)(?=")' )
fix_date2_re = re.compile( r'(?P<y>\d+)\u2013(?P<m>\d+)\u2013(?P<d>\d+)(?=</date>)' )

def fix_ndash( data ):
	data = ndash_re.sub( '\u2013', data )
	data = fix_date_re.sub( r'\g<y>-\g<m>-\g<d>', data, 2 )
	data = fix_date2_re.sub( r'\g<y>-\g<m>-\g<d>', data, 2 )
	for tag in ('date', 'date', 'id', 'isbn', 'src-ocr'):
		start = data.find( '<%s>' % tag )
		if start >= 0:
			end = data.find( '</%s>' % tag, start )
			if end >= 0 and data.find( '\u2013', start, end ) >= 0:
				data = data[:start] + data[start:end].replace( '\u2013', '-' ) + data[end:]

	return data

def convert( data ):
	# Remove <h2> elements
	data = fix_h2_re.sub( '', data )
# 	data = fix_style_re.sub( '', data )
	# Remove empty inline elements
	data = empty_style_re.sub( '', data )
	# Move spaces out emphasis
	data = fix_emphasis1_re.sub( r'\2\1', data )
	data = fix_emphasis2_re.sub( r'\1 ', data )
	data = fix_emphasis3_re.sub( r'\2\1', data )
	# Again remove empty inline elements
	data = empty_style_re.sub( '', data )
	# Correct dash in text
	data = mdash_re.sub( '\u00A0\u2014 ', data )
# 	data = data.replace( r'\u00A0\u2014 \u2013 ', '\u00A0\u2014 ' )
# 	data = fix_emphase_re.sub( r'\1\u00A0\u2014', data )
	# Correct dash at end of paragraph
	data = end_mdash_re.sub( '\u00A0\u2014', data )
	# Correct defis
# 	data = fix_defis_re.sub( '-', data )
	# Correct short dash
	data = fix_ndash( data )
	# Correct dash at start of paragraph
	data = dialog_re.sub( '\\1\u2014\u00A0', data )
	# Correct ellipsis
	data = data.replace( '...', '\u2026' )
	# Empty line must be only between paragraphs
	data = empty_line_re.sub( '', data )
	# Unificate stars separator
	data = stars_re.sub( '<subtitle>* * *</subtitle>', data )
	# Empty line must be only between paragraphs
	data = empty_line_re.sub( '', data )
	return data

def writexml( doc, writer, encoding ):
	writer = codecs.getwriter( encoding )( writer,  'xmlcharrefreplace' )
	doc.writexml( writer, encoding = encoding )
	writer.close()


if __name__ == '__main__':
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:hkqtvV',
			['backup', 'help', 'progress', 'version'] )
	except getopt.GetoptError as err:
		print( 'Error:', err, file = sys.stderr )
		sys.exit( 2 )

	keepBackup = False
	backupSuffix = str( '.bak' )
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
				args.extend( line.rstrip( str( '\n' ) ) for line in open( value ) )
		elif option in ('-k', '--backup'):
			keepBackup = True
		elif option in ('-v', '--progress'):
			verbose = True

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args )

	global filename
	for filename in args:
		try:
			if filename == str( '-' ):
				if sys.version_info[0] >= 3:
					f = sys.stdin.buffer.raw
				else:
					f = sys.stdin
				doc = xml.dom.minidom.parse( f )
			else:
				doc = xml.dom.minidom.parse( open( filename, 'rb' ) )
			encoding = doc.encoding or str( 'utf-8' )
			data0 = doc.toxml( 'utf-8' ).decode( 'utf-8' )
			data = convert( data0 )
			if data != data0:
				doc = xml.dom.minidom.parse( io.BytesIO( data.encode( 'utf-8' ) ) )
				if filename == str( '-' ):
					writexml( doc, sys.stdout, encoding )
				else:
					tmpfilename = filename + str( '.tmp' )
					writexml( doc, open( tmpfilename, 'wb' ), encoding )
					if keepBackup:
						os.rename( filename, filename + backupSuffix )
					os.rename( tmpfilename, filename )
		except (KeyboardInterrupt, SystemExit):
			raise
		except Exception as err:
			print( str( 'Error processing "%s":' ) % filename, file = sys.stderr )
			print( err, file = sys.stderr )
