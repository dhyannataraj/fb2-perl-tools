#!/usr/bin/python
# -*- coding: UTF-8 -*-

'''\
Usage:
     fb2clean.py [<options>] [<fb2-files>]
Options:
     -h              display this help message and exit
     -V              display the version and exit
     -k              create backup files
     -@ <file>       read file names from file (one name per line)
     -v              display progressbar
File name '-' means standard input/output.
'''
__author__ = 'Serhiy Storchaka <storchaka@sourceforge.net>'
__version__ = '0.1'
__all__ = []

import re
import sys, getopt, os, os.path, xml.dom.minidom, codecs

fix_h2_re = re.compile( ur'<h2 xmlns="">Taken: \w*, 1</h2>', re.UNICODE )
# fix_style_re = re.compile( ur'(<style name="\w*">)|(</style>)' )
empty_style_re = re.compile( u'|'.join(
	ur'<%s/>|</%s><%s>|<%s></%s>' % (tag, tag, tag, tag, tag)
	for tag in ('emphasis', 'strong', 'sub', 'sup')
	) + ur'<style [^>]*/>|<style [^>]*></style>', re.DOTALL )
start_emphasis = ur'<emphasis>|<strong>|<style [^>]*>|<a [^>]*>'
end_emphasis = ur'</emphasis>|</strong>|</style>|</a>'
fix_emphasis1_re = re.compile( ur'(\s+)(%s)' % end_emphasis, re.UNICODE )
fix_emphasis2_re = re.compile( ur'(%s)(?=\w)' % end_emphasis, re.UNICODE )
fix_emphasis3_re = re.compile( ur'([ \u00A0]*[\u2013\u2014-]+)(%s)' % end_emphasis, re.UNICODE )
mdash_re = re.compile( ur'(?:[ \u00A0]|(?<=[,.?!:"\u2026]))[\u2013\u2014-]+(?:[ \u00A0]|(?=\w)|(?=<[^/]))', re.UNICODE )
end_mdash_re = re.compile( ur'[ \u00A0][\u2013\u2014-]+[ \u00A0](?:(?=</p>)|(?=</v>)|(?=</subtitle>))' )
dialog_re = re.compile( ur'(<(?:p|v|subtitle)\b[^>]*>(?:\s*(?:%s))*)\s*[\u2013\u2014-]+\s*' % start_emphasis, re.UNICODE )
# fix_emphase_re = re.compile( ur'[ \u00A0][\u2013\u2014-][ \u00A0](</emphase>)' )
empty_line_re = re.compile( ur'<empty-line/>\s*(?=<)(?!<p\b)|(?<=>)(?<!</p>)\s*<empty-line/>', re.UNICODE )
stars_re = re.compile( u'|'.join(
	ur'<%s(?: id="[^">]+")?>(?:%s)* ?(?:[*](?: [*]){2,}|[*]{3,}|x x x) ?(?:%s)*</%s>' % (start, start_emphasis, end_emphasis, end)
	for start, end in ((u'p', u'p'), (u'subtitle', u'subtitle'), (ur'/section>\s*<section>\s*<title><p', ur'p>\s*</title'))
	), re.UNICODE|re.DOTALL )


# defis_str1 = [ur'(?<=\b%s)[\u2013\u2014-][ \u00A0]' % pre for pre in
# 	(u'по', u'в', u'во', u'из', u'кое')]
# defis_str2 = [ur'([\u2013\u2014-][ \u00A0]|[ \u00A0][\u2013\u2014-])(?=%s\b)' % post for post in
# 	(u'то', u'нибудь', u'таки', u'либо', u'никак', u'никак(?:ой|им|ом|ая|ую|ое)', u'никак(?:ого|ому)', u'стрит', u'летн(?:ий|им|ем|яя|юю|ей|ее|ии|их)', u'летн(?:его|ему|ими)')]
# # 	u'й', u'х', u'го', u'е', u'м', u'я', u'мм', u'ка', u'ю', 
# fix_defis_re = re.compile( u'|'.join( defis_str1 + defis_str2 ), re.UNICODE|re.IGNORECASE )

ndash_re = re.compile( ur'(?<=[0-9])[\u2013\u2014-][ \u00A0]?(?=[0-9])' )
fix_date_re = re.compile( ur'(?<=value=")(?P<y>\d+)\u2013(?P<m>\d+)\u2013(?P<d>\d+)(?=")' )
fix_date2_re = re.compile( ur'(?P<y>\d+)\u2013(?P<m>\d+)\u2013(?P<d>\d+)(?=</date>)' )

def fix_ndash( data ):
	data = ndash_re.sub( u'\u2013', data )
	data = fix_date_re.sub( ur'\g<y>-\g<m>-\g<d>', data, 2 )
	data = fix_date2_re.sub( ur'\g<y>-\g<m>-\g<d>', data, 2 )
	for tag in ('date', 'date', 'id', 'isbn', 'src-ocr'):
		start = data.find( '<%s>' % tag )
		if start >= 0:
			end = data.find( '</%s>' % tag, start )
			if end >= 0 and data.find( u'\u2013', start, end ) >= 0:
				data = data[:start] + data[start:end].replace( u'\u2013', u'-' ) + data[end:]

	return data

def convert( data ):
	# Remove <h2> elements
	data = fix_h2_re.sub( u'', data )
# 	data = fix_style_re.sub( u'', data )
	# Remove empty inline elements
	data = empty_style_re.sub( u'', data )
	# Move spaces out emphasis
	data = fix_emphasis1_re.sub( ur'\2\1', data )
	data = fix_emphasis2_re.sub( ur'\1 ', data )
	data = fix_emphasis3_re.sub( ur'\2\1', data )
	# Again remove empty inline elements
	data = empty_style_re.sub( u'', data )
	# Correct dash in text
	data = mdash_re.sub( u'\u00A0\u2014 ', data )
# 	data = data.replace( ur'\u00A0\u2014 \u2013 ', u'\u00A0\u2014 ' )
# 	data = fix_emphase_re.sub( ur'\1\u00A0\u2014', data )
	# Correct dash at end of paragraph
	data = end_mdash_re.sub( u'\u00A0\u2014', data )
	# Correct defis
# 	data = fix_defis_re.sub( u'-', data )
	# Correct short dash
	data = fix_ndash( data )
	# Correct dash at start of paragraph
	data = dialog_re.sub( u'\\1\u2014\u00A0', data )
	# Correct ellipsis
	data = data.replace( u'...', u'\u2026' )
	# Empty line must be only between paragraphs
	data = empty_line_re.sub( u'', data )
	# Unificate stars separator
	data = stars_re.sub( u'<subtitle>* * *</subtitle>', data )
	# Empty line must be only between paragraphs
	data = empty_line_re.sub( u'', data )
	return data

def writexml( doc, writer, encoding ):
	writer = codecs.getwriter( encoding )( writer,  'xmlcharrefreplace' )
	doc.writexml( writer, encoding = encoding )
	writer.close()


if __name__ == '__main__':
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:hkqtvV' )
	except getopt.GetoptError, err:
		print >>sys.stderr, 'Error:', err
		sys.exit(2)

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
		elif option == '-k':
			keepBackup = True
		elif option == '-v':
			verbose = True

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args, os.path.basename, sys.stderr )

	global filename
	for filename in args:
		try:
			if filename == '-':
				doc = xml.dom.minidom.parse( sys.stdin )
			else:
				doc = xml.dom.minidom.parse( open( filename, 'r' ) )
			encoding = doc.encoding or 'UTF-8'
			data0 = doc.toxml( 'UTF-8' ).decode( 'UTF-8' )
			data = convert( data0 )
			if data != data0:
				doc = xml.dom.minidom.parseString( data.encode( 'UTF-8' ) )
				if filename == '-':
					writexml( doc, sys.stdout, encoding )
				else:
					tmpfilename = filename + '.tmp'
					writexml( doc, open( tmpfilename, 'w' ), encoding )
					if keepBackup:
						os.rename( filename, filename + backupSuffix )
					os.rename( tmpfilename, filename )
		except (KeyboardInterrupt, SystemExit):
			raise
		except Exception, err:
			print >>sys.stderr, 'Error processing %s:' % filename
			print >>sys.stderr, err
