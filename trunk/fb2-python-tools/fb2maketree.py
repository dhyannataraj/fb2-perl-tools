#!/usr/bin/env python
# -*- coding: UTF-8 -*-

'''\
Usage:
     fb2maketree.py [<options>] [<fb2-files>]
Options:
     -h                   display this help message and exit
     -V                   display the version and exit
     -f <format>          use tree format (translators, authors, authors-src, series, genres)
     -o, --output <dir>   tree base directory
     -s                   make symbolic links instead of hard links
     -@ <file>            read file names from file (one name per line)
     -v                   display progressbar
File name '-' means standard input/output.
'''

__author__ = 'Serhiy Storchaka <storchaka@users.sourceforge.net>'
__version__ = '0.1'
__all__ = []

try:
	import psyco
	psyco.full()
except:
	pass
import sys, xml.etree.ElementTree, re, getopt, os, os.path, filecmp

filesystemencoding = sys.getfilesystemencoding()
# filesystemencoding = 'utf-8'

def get_text( node ):
	if node is None:
		return ''
	text = node.text
	if text is None:
		return ''
	return text.strip()

def genname( dirname, filename, otherpath = None ):
	filename = filename.replace( '"', "'" )
	filename = filename.replace( ':', '.' )
	for c in '+/<>\\|':
		filename = filename.replace( c, '_' )
	basename, suffix = os.path.splitext( filename )
	try:
		if not os.path.exists( dirname ):
			os.makedirs( dirname )
	except os.error, e:
		print >>sys.stderr, e
		pass
	count = 0
	path = os.path.join( dirname, filename )
	while os.access( path, os.F_OK ):
		if otherpath and filecmp.cmp( path, otherpath, 0 ):
# 		if data and os.path.getsize( path ) == len( data ) and open( path ).read() == data:
			print '#', path.encode( filesystemencoding )
			return None
		count += 1
		path = os.path.join( dirname, '%s__%d%s' % (basename, count, suffix) )
	if count > 0:
		print '!', path.encode( filesystemencoding )
	return path

def mklink( src, dst ):
	try:
		os.link( src, dst )
	except OSError, err:
		os.symlink( src, dst )
		print '@', dst.encode( filesystemencoding )

def linkauthors( basedir, authornames, book_title, fb2name ):
	if len( authornames ) > 4:
		authornames_str = ', '.join( authornames[:4] ) + u',..'
	else:
		authornames_str = ', '.join( authornames )

	path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', fb2name )
	if path:
		mklink( os.path.abspath( fb2name ), path )
		if len( authornames ) > 1:
			mainname = os.path.join( '..', authornames_str, os.path.basename( path ) )
			for authorname in authornames:
				os.symlink( mainname, genname( os.path.join( basedir, authorname ), book_title + '.fb2' ) )

xml_re = re.compile( r'<\?xml version="(?:[^">]*)" encoding="(?:[^">]*)"\?>', re.DOTALL )
desc_re = re.compile( r'<description>.*?</description>', re.DOTALL )
def parse( data ):
	return xml.dom.minidom.parseString(
		xml_re.match( data ).group() +
		desc_re.search( data ).group().
		replace( 'xlink:href=', 'href=' ).
		replace( 'l:href=', 'href=' )
	)

if __name__ == '__main__':
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:hf:o:svV', ['output='] )
	except getopt.GetoptError:
		# print help information and exit:
		print >>sys.stderr, 'Illegal option'
		sys.exit( 2 )
	outputdir = '.'
	verbose = False
	format = None
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
		elif option == '-v':
			verbose = True
		elif option == '-f':
			format = value
		elif option in ('-o', '--output'):
			outputdir = value
		elif option == '-s':
			mklink = os.symlink

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args, os.path.basename, sys.stderr )

	for fb2name in args:
		#if verbose:
		#	print fb2name
		f = file( fb2name )
		data = ''
		while True:
			data += f.read( 1 << 13 )
			try:
				doc = xml_re.match( data ).group() + '\n' + desc_re.search( data ).group()
			except AttributeError:
				continue
			break
		f.close()
		doc = doc.replace( 'xlink:href=', 'href=' ).replace( 'l:href=', 'href=' )

		try:
			description = xml.etree.ElementTree.fromstring( doc )
		except:
			print description
			raise

		title_info = description.find( 'title-info' )

		authornames = []
		for author in title_info.findall( 'author' ):
			first_name = get_text( author.find( 'first-name' ) )
			last_name = get_text( author.find( 'last-name' ) )
			authorname = [last_name, first_name] + [get_text( middle_name ) for middle_name in author.findall( 'middle-name' )]
			authorname = ' '.join( [name for name in authorname if name] )
			nickname = get_text( author.find( 'nickname' ) )
			if nickname:
				authorname += ' [%s]' % nickname
			authornames.append( authorname )
		translatornames = []
		for author in title_info.findall( 'translator' ):
			first_name = get_text( author.find( 'first-name' ) )
			last_name = get_text( author.find( 'last-name' ) )
			authorname = [last_name, first_name] + [get_text( middle_name ) for middle_name in author.findall( 'middle-name' )]
			authorname = ' '.join( [name for name in authorname if name] )
			nickname = get_text( author.find( 'nickname' ) )
			if nickname:
				authorname += ' [%s]' % nickname
			translatornames.append( authorname )


		book_title = get_text( title_info.find( 'book-title' ) )
		lang = get_text( title_info.find( 'lang' ) )
		srclang = get_text( title_info.find( 'src-lang' ) ) or os.path.join( 'unknown', lang )

		genres = [get_text( genre ) for genre in title_info.findall( 'genre' )]
		sequences = [(sequence.get( 'name' ), sequence.get( 'number' ), sequence.get( 'src-name' )) for sequence in title_info.findall( 'sequence' )]


		#print ('%s "%s"' % (', '.join( authornames ), book_title)).ljust(50)[:50].encode( filesystemencoding ),

		if len( authornames ) > 4:
			authornames_str = ', '.join( authornames[:4] ) + u',..'
		else:
			authornames_str = ', '.join( authornames )

		try:
			if format == 'translators':
				basedir = outputdir.decode( filesystemencoding )
				for authorname in translatornames:
					os.symlink( os.path.abspath( fb2name ), genname( os.path.join( basedir, authorname ), book_title + '.fb2' ) )
			if format == 'authors':
				basedir = os.path.join( outputdir.decode( filesystemencoding ), lang )
				path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', fb2name )
				if path:
					mklink( os.path.abspath( fb2name ), path )
					if len( authornames ) > 1:
						mainname = os.path.join( '..', authornames_str, os.path.basename( path ) )
						for authorname in authornames:
							os.symlink( mainname, genname( os.path.join( basedir, authorname ), book_title + '.fb2' ) )
			if format == 'authors-src':
				basedir = os.path.join( outputdir.decode( filesystemencoding ), srclang )
				path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', fb2name )
				if path:
					mklink( os.path.abspath( fb2name ), path )
					if len( authornames ) > 1:
						mainname = os.path.join( '..', authornames_str, os.path.basename( path ) )
						for authorname in authornames:
							os.symlink( mainname, genname( os.path.join( basedir, authorname ), book_title + '.fb2' ) )
			if format == 'series':
				for sequence_name, sequence_number, sequence_src_name in sequences:
					if sequence_src_name:
						path0 = os.path.join( outputdir, lang, ( '%s [%s] : %s' % ( sequence_name, sequence_src_name, authornames_str ) )[:120] )
					else:
						path0 = os.path.join( outputdir, lang, ( '%s : %s' % ( sequence_name, authornames_str ) )[:120] )
			#		path0 = os.path.join( outputdir, lang, sequence_name, authornames_str )
					if sequence_number != '':
						path = genname( path0, '%s. %s.fb2' % ( sequence_number, book_title ), fb2name )
					else:
						path = genname( path0, '%s.fb2' % book_title, fb2name )
					if path:
						mklink( os.path.abspath( fb2name ), path )
			if format == 'genres':
				for genre in genres:
					basedir = os.path.join( outputdir, lang, genre )
					path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', fb2name )
					if path:
						mklink( os.path.abspath( fb2name ), path )
						mainname = os.path.join( '..', authornames_str, os.path.basename( path ) )
						if len( authornames ) > 1:
							for authorname in authornames:
								os.symlink( mainname, genname( os.path.join( basedir, authorname ), book_title + '.fb2' ) )
		except (KeyboardInterrupt, SystemExit):
			raise
		except Exception, err:
			print >>sys.stderr, 'Error processing %s:' % fb2name
			print >>sys.stderr, err
			sys.exit( 1 )
