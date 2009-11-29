#!/usr/bin/env python
# -*- coding: UTF-8 -*-

'''\
Usage:
     fb2maketree.py [options] [fb2-files]

Options:
     -h, --help                   display this help message and exit
     -V, --version                display the version and exit
     -f FORMAT, --format=FORMAT   use tree format (authors, authors-src, series, genres, translators, date)
     -o DIR, --output DIR         tree base directory
     -s, --symbolic               make symbolic links instead of hard links
     -@ FILE                      read file names from FILE (one name per line)
     -v, --progress               display progressbar

File name '-' means standard input.
'''

__author__ = 'Serhiy Storchaka <storchaka@users.sourceforge.net>'
__version__ = '0.2'
__all__ = []

try:
	import psyco
	psyco.full()
except:
	pass
import sys, xml.etree.ElementTree, re, getopt, os, os.path, filecmp

filesystemencoding = sys.getfilesystemencoding()
# filesystemencoding = 'utf-8'

def genname( dirname, filename, otherpath = None ):
	filename = filename.replace( '"', "'" )
	filename = filename.replace( ':', '.' )
	for c in '+/<>\\|':
		filename = filename.replace( c, '_' )
	basename, suffix = os.path.splitext( filename )
	try:
		if not os.path.exists( dirname ):
			os.makedirs( dirname )
	except os.error, err:
		print >>sys.stderr, err
		pass
	count = 0
	path = os.path.join( dirname, filename )
	while os.access( path, os.F_OK ):
		if otherpath:
			if os.path.samefile( path, otherpath ):
				return None
			if filecmp.cmp( path, otherpath, 0 ):
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
		print '@', dst.encode( filesystemencoding )
		os.symlink( src, dst )

def linkauthors( path, authornames, book_title ):
	if len( authornames ) > 1:
		(dirname, filename) = os.path.split( path )
		(basedir, dirname) = os.path.split( dirname )
		mainname = os.path.join( '..', dirname, filename )
		for authorname in authornames:
			os.symlink( mainname, genname( os.path.join( basedir, authorname ), book_title + '.fb2' ) )

def getauthorname( author ):
	first_name = author.findtext( 'first-name' )
	last_name = author.findtext( 'last-name' )
	middle_name = author.findtext( 'middle-name' )
	authorname = ' '.join( [name for name in [last_name, first_name, middle_name] if name] )
	nickname = author.findtext( 'nickname' )
	if nickname:
		authorname += ' [%s]' % nickname
	return authorname

xml_re = re.compile( r'<\?xml version="(?:[^">]*)" encoding="(?:[^">]*)"\?>', re.DOTALL )
desc_re = re.compile( r'<description>.*?</description>', re.DOTALL )

if __name__ == '__main__':
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:hf:o:svV', ['help', 'format=', 'output=', 'symbolic', 'version', 'progress'] )
	except getopt.GetoptError, err:
		print >>sys.stderr, 'Error:', err
		sys.exit( 2 )
	outputdir = '.'
	verbose = False
	format = None
	for option, value in opts:
		if option in ('-h', '--help'):
			sys.stdout.write( __doc__ )
			sys.exit( 0 )
		elif option in ('-V', '--version'):
			print __version__
			sys.exit( 0 )
		elif option == '-@':
			if value == '-':
				args.extend( line.rstrip( '\n' ) for line in sys.stdin )
			else:
				args.extend( line.rstrip( '\n' ) for line in open( value ) )
		elif option in ('-v', '--progress'):
			verbose = True
		elif option in ('-f', '--format'):
			format = value
		elif option in ('-o', '--output'):
			outputdir = value
		elif option in ('-s', '--symbolic'):
			mklink = os.symlink

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args )

	for fb2name in args:
		srcpath = os.path.abspath( fb2name )
		#if verbose:
		#	print fb2name
		try:
			f = open( srcpath )
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
				print doc
				raise

			title_info = description.find( 'title-info' )

			authornames = [getauthorname( author ) for author in title_info.findall( 'author' )]
			translatornames = [getauthorname( author ) for author in title_info.findall( 'translator' )]

			book_title = title_info.findtext( 'book-title' )
			lang = title_info.findtext( 'lang' )
			src_lang = title_info.findtext( 'src-lang' )

			genres = [genre.text for genre in title_info.findall( 'genre' )]
			sequences = [(sequence.get( 'name' ), sequence.get( 'number' ), sequence.get( 'src-name' )) for sequence in title_info.findall( 'sequence' )]


			if len( authornames ) > 4:
				authornames_str = ', '.join( authornames[:4] ) + ',..'
			else:
				authornames_str = ', '.join( authornames )

			if len( book_title ) > 120:
				book_title = book_title[:120] + '...'

			if format == 'authors':
				basedir = os.path.join( outputdir, lang )
				path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', srcpath )
				if path:
					mklink( srcpath, path )
					linkauthors( path, authornames, book_title )
			elif format == 'authors-src':
				basedir = os.path.join( outputdir, src_lang or lang )
				path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', srcpath )
				if path:
					mklink( srcpath, path )
					linkauthors( path, authornames, book_title )
			elif format == 'series':
				for sequence_name, sequence_number, sequence_src_name in sequences:
					dirname = sequence_name
					if sequence_src_name:
						dirname += ' [%s]' % sequence_src_name
					dirname += ' : ' + authornames_str
					filename = book_title + '.fb2'
					if sequence_number:
						filename = sequence_number + '. ' + filename
					path = genname( os.path.join( outputdir, lang, dirname[:120] ), filename, srcpath )
					if path:
						mklink( srcpath, path )
			elif format == 'genres':
				for genre in genres or ('?'):
					basedir = os.path.join( outputdir, lang, genre )
					path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', srcpath )
					if path:
						mklink( srcpath, path )
						linkauthors( path, authornames, book_title )
			elif format == 'translators':
				basedir = outputdir
				if not translatornames and lang != src_lang:
					translatornames = ('?')
				for authorname in translatornames:
					mklink( srcpath, genname( os.path.join( basedir, authorname ), ( authornames_str + '. ' + book_title )[:120] + '.fb2' ) )
			elif format == 'date':
				date = title_info.find( 'date' )
				if date is not None:
					date_str = date.text or '?'
					if date.get( 'value' ):
						date_str += ' [%s]' % date.get( 'value' )
				date_str = date_str or '?'
				basedir = os.path.join( outputdir, date_str )
				path = genname( os.path.join( basedir, authornames_str ), book_title + '.fb2', srcpath )
				if path:
					mklink( srcpath, path )
		except (KeyboardInterrupt, SystemExit):
			raise
		except Exception, err:
			print >>sys.stderr, 'Error processing "%s":' % fb2name
			print >>sys.stderr, err
			sys.exit( 1 )
