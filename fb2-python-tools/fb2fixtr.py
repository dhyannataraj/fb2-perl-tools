#!/usr/bin/python
# -*- coding: utf-8 -*-

'''\
Fix some frequent OCR and conversion errors in FictionBook2 files.

Usage:
     fb2fixtr.py [options] [fb2-files]

Options:
     -h, --help                   display this help message and exit
     -V, --version                display the version and exit
     -k, --backup                 create backup files
     -@ FILE                      read file names from FILE (one name per line)
     -q, --quick                  quick but use more memory
     -T, --text                   process plain text
     -v, --progress               display progressbar
     -o FILE, --log-file FILE     log all fixes to FILE
     -d FILE, --dictionary FILE   use dictionary from FILE

File name '-' means standard input.
'''

from __future__ import division, print_function, unicode_literals
__author__ = 'Serhiy Storchaka <storchaka@users.sourceforge.net>'
__version__ = '0.2'
__all__ = []

import string, re
import sys, getopt, os, os.path, xml.dom.minidom, codecs, io

quick = False

rus_lowercase = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя'
rus_uppercase = rus_lowercase.upper()
rus_letters = rus_lowercase + rus_uppercase

cyr_lowercase = rus_lowercase + 'іїєґ'
cyr_uppercase = cyr_lowercase.upper()
cyr_letters = cyr_lowercase + cyr_uppercase

rus_tr = 'аАВсСеЕНКМпоОрРгТихХу'
rus_lat_tr = 'aABcCeEHKMnoOpPrTuxXy'
cyr_tr = 'аАВсСеЕНіІКМпоОрРгТихХу'
cyr_lat_tr = 'aABcCeEHiIKMnoOpPrTuxXy'

lat2cyr = dict( zip( cyr_letters + cyr_lat_tr, cyr_letters + cyr_tr ) )
cyr2lat = dict( zip( string.ascii_letters + cyr_tr, string.ascii_letters + cyr_lat_tr ) )
num2cyr = {'0': 'О', '3': 'З', '6': 'б'}

word_re = re.compile( r'([\w]+)', re.UNICODE )

def maketest( chars ):
	return re.compile( r'\A[' + chars + r']+\Z', re.UNICODE ).match

# islat = maketest( string.ascii_letters )
islat = maketest( string.ascii_letters + '_' )
isrus = maketest( rus_letters + '_' )
iscyr = maketest( cyr_letters + '_' )
iscyrlower = maketest( cyr_lowercase )
iscyrupper = maketest( cyr_uppercase )
ispseudo = maketest( cyr_lat_tr + cyr_tr  )
ispseudolat = maketest( string.ascii_letters + rus_tr )
ispseudorus = maketest( rus_letters + rus_lat_tr  )
ispseudocyr = maketest( cyr_letters + cyr_lat_tr  )
isrusJ = maketest( rus_letters + '\u0408' )
isnumber = re.compile( r'\A\d+\Z', re.UNICODE ).match
isroman = re.compile( r'\A(?:M{0,3})(?:D?C{0,3}|C[DM])(?:L?X{0,3}|X[LC])(?:V?I{0,3}|I[VX])\Z' ).match
beginnumber_re = re.compile( r'\A([0-9]+)(\w+)\Z', re.UNICODE )
endnumber_re = re.compile( r'\A(\w+?)([0-9]+)\Z', re.UNICODE )
iscross = re.compile( r'\A[0-9]+(?:х[0-9]+)+\Z' ).match

hasdigits = re.compile( r'\A.*[0-9].*\Z', re.UNICODE ).match

def tocyr( word ):
	return ''.join( lat2cyr[c] for c in word )

def tolat( word ):
	return ''.join( cyr2lat[c] for c in word )

def readlist( fname ):
	for line in io.open( fname, 'rt', encoding = 'utf-8' ):
		line = line.rstrip( '\n' )
		if line and line[0] != '#':
			yield line

reserved_tr = set()
def is_reserved_lat( word ):
	return word in  reserved_tr and tocyr( word ) not in reserved_tr

def is_reserved_cyr( word ):
	return word in  reserved_tr and tolat( word ) not in reserved_tr

translates = {}
try:
	translates.update( line.split( ' ', 1 ) for line in readlist( 'replaces' ) )
except:
	pass
try:
	translates.update( (w, w) for w in readlist( 'reserved' ) )
except:
	pass

logfile = None
global filename
def logtr( word, type, *args ):
	if logfile:
		# hack for Python 2.x
		fn = filename.decode( 'utf-8' ) if isinstance( filename, bytes ) else filename
		print( '%s:' % fn, word, type, *args, file = logfile )

def tryconv( s, e1, e2 ):
	try:
		return s.encode( e1 ).decode( e2 )
	except UnicodeEncodeError:
		return None

def fixtr_word( word ):
	# Слишком короткое слово -- гадать бессмысленно
	if len( word ) < 3 or len( word.replace( '_', '' ) ) < 2:
		return word

	# Слово полностью принадлежит одном алфавиту
	if iscyr( word ) or islat( word ) or isnumber( word ):
		return word

	# Слово состоит из букв, похожих и на русские (украинские) и на латиницу
	if ispseudo( word ):
		lat_word = tolat( word )
		cyr_word = tocyr( word )
		# Слово типично иноземное или римская цифра
		if lat_word in  reserved_tr and cyr_word not in reserved_tr or isroman( lat_word ):
			return lat_word
		# Слово типично кириллическое
		if cyr_word in  reserved_tr and lat_word not in reserved_tr:
			return cyr_word
		# Только кириллическа 'Н' заменена на латинскую 'H' -- шуточки FIDO
		if iscyr( word.replace( 'H', 'Н' ) ):
			return cyr_word

		# Неопределённость
		logtr( word, '?<>', lat_word, cyr_word )
		return word

	# Слово состоит из русских букв и похожих на русские
	if ispseudorus( word ):
		return tocyr( word )

	# Слово состоит из латинских букв и похожих на латинские
	if ispseudolat( word ):
		return tolat( word )

	# Слова с цифрами
	if hasdigits( word ):
		# Слова вида 9x12
		if iscross( word ):
			return word

		# Сначала буквы, потом цифры
		m = endnumber_re.match( word )
		if m and not hasdigits( m.group( 1 ) ):
			# Метки часто содержат в себе номер
			if m.group( 1 ) in (r'note', r'note_', r'Note', r'footnote', r'child_', r'FbAutId_', r'comment_', r'text_', r'N', r'N_', r'No'):
				return word

			# Между словом и номером пропущен пробел
			if m.group( 1 ) in (r'Глава', r'ГЛАВА', r'глава'):
				return m.expand( r'\1 \2' )

			# Начальная единица года распозналась как 'I"
			if re.match( r'\AI[89][0-9][0-9]\Z', word ):
				return '1' + word[1:]
			# Просто собираем статистику
			logtr( word, '!' )
			return word

		# Сначала цифры, потом буквы
		m = beginnumber_re.match( word )
		if m and not hasdigits( m.group( 2 ) ):
			# Физические единицы отделяем неразрывным пробелом
			if m.group( 2 ) in ('гг', 'мг', 'г', 'кг', 'мл', 'л', 'ч', 'мм', 'см', 'дм', 'м', 'км' ):
				return m.expand( '\\1\u00A0\\2' )
			# Русские окончания отделяем дефисом
			if m.group( 2 ) in ('ый', 'ой', 'й', 'ым', 'ом', 'я', 'ая', 'е', 'ое', 'го', 'ого', 'ю', 'ую'):
				return m.expand( r'\1-\2' )
			# А английские оставляем так
			if m.group( 2 ) in ('st', 'nd', 'rd', 'th', 's', 'd', 'ff', 'mm', 'cm', 'mm', 'km', 'unt', 'cc', 'F'):
				return word
			if word[0] in '036' and ( iscyrlower( word[1:] ) or iscyrupper( word[1:] ) ):
				return num2cyr[word[0]] + word[1:]
			# Иначе просто собираем статистику
			logtr( word, '!' )
			return word

		# Начальная единица распозналась как 'I"
		m = re.match( r'\AI[0-9]+(?:st|nd|rd|th|s|d)\Z', word )
		if m:
			return '1' + word[1:]

		# Возможно цифра -- на самом деле буква.
		# Дело тёмное и рискованное.
		word2 = word.replace( 'ь1', 'ы' ).replace( 'Ь1', 'Ы' )
		if word2 != word:
			if ispseudorus( word2 ):
				return tocyr( word2 )

		if re.search( r'6[аеиоуaeuoy]|[аеиоуaeuoy]6', word ):
			word2 = word.replace( '6', 'б' )
			if ispseudorus( word2 ):
				return tocyr( word2 )

		logtr( word, '!' )
		return word

	# Слово принадлежит одному из европейских языков
	for enc in ('iso-8859-2', 'iso-8859-4', 'iso-8859-7', 'iso-8859-15'):
		try:
			word.encode( enc )
			return word
		except:
			pass

	# Слово состоит из кириллических букв и похожих на кириллические и содержит i с точкой
	# Явно (псевдо)украинское или старорусское
	if ('i' in word or 'I' in word) and ispseudocyr( word ):
		# Часто 'п', за которой следуют 'о' или 'е' неправильно распознаётся
		word2 = re.sub( '^ii|^[гт]i(?=о)|[гi]i(?=[еоeo])', 'п', word )
		# Также начальные 'Ш' и 'П'
		word2 = re.sub( '^III', 'Ш', word2 )
		word2 = re.sub( '^II', 'П', word2 )
		# Украинское окончание
		word2 = re.sub( 'ii$', 'ії', word2 )
		word2 = re.sub( 'II$', 'ІЇ', word2 )
		word2 = tocyr( word2 )
		return word2

	# Слово состоит из русских букв и непонятного символа, похожего на J.
	# На самом деле это 'ё'
	if '\u0408' in word and isrusJ( word ) and word.replace( '\u0408', '' ):
		return word.replace( '\u0408', 'ё' )
	# Слетевшая кодировка для кавычек-ёлочек
	if word[0] == '\u0458' and isrus( word[1:] ):
		return '\xab' + word[1:]
	if word[-1] == '\u0405' and isrus( word[:-1] ):
		return word[:-1] + '\xbb'

	# Для обозначения ударения в русском слове использованы диакритические знаки.
	for c in 'áéúóý':
		if isrus( word.replace( c, '' ) ):
			return word

	# Возможно оригинальный текст был в европейской кодировке iso-8859-15,
	# а работали с ним как с cp1251.
	# Пока что достаточно экспериментально.
	word2 = tryconv( word, 'cp1251', 'iso-8859-15' )
	if word2 and word_re.match( word2 ):
		# Если не-ASCII символов немного, то скорее всего так и есть
		count = len( [c for c in word if c not in string.ascii_letters] )
		if count <= 1 or 3 * count <= len( word ):
			return word2
		logtr( word, '?>', word2 )
		return word

	logtr( word, '!' )
	return word

utf_illegal_pref_re = re.compile( '\u0432\u0402(?:\ufffd|[\u2000-\u203f])?', re.DOTALL )

def fix_utf_illegal_pref( m ):
	data = m.group()
	if data == '\u0432\u0402' or data == '\u0432\u0402\ufffd':
		return '\u2018'
	return data.encode( 'cp1251' ).decode( 'utf-8' )

def fixtr_text( text ):
	global quick

	changed = False
	if '\u0432\u0402' in text: #'вЂ'
		# Указана кодировка cp1251, а на самом деле -- utf-8
		text = utf_illegal_pref_re.sub( fix_utf_illegal_pref, text )
		changed = True

	# Символы номера и копирайта, оставшиеся с HTML
	text = text.replace( '&#x2116;', '\u2116' )
	text = text.replace( '&#169;', '\xa9' )

	# Разбиваем текст на слова и обрабатываем их по отдельности.
	# Потом склеиваем.
	words = word_re.split( text )
	for iword, word in enumerate( words ):
		if word_re.match( word ):
			# Для начала смотрим в словаре
			if word in translates:
				word2 = translates[word]
			else:
				word2 = fixtr_word( word )
				if quick or word != word2:
					# Переведённое слово заносим в словарь.
					# В режиме quick заносим и неизменённые слова, для ускорения.
					translates[word] = word2

			if word != word2:
				logtr( word, '->', word2 )
				words[iword] = word2
				changed = True

	if changed:
		text = ''.join( words )

	return text

def fixtr_fb2( node ):
	changed = False
	if node.nodeType == xml.dom.Node.TEXT_NODE:
		data = fixtr_text( node.data )
		if data != node.data:
			node.data = data
			changed = True
	elif node.nodeType != xml.dom.Node.ELEMENT_NODE or node.tagName not in ('binary', 'id', 'email', 'src-url', 'program-used'):
		# Рекурсивно обрабатываем элементы, кроме тех, где исправлять текст бессмысленно и опасно
		for n in node.childNodes:
			changed = fixtr_fb2( n ) or changed
	return changed

def update_trdict( word ):
	if ispseudo( word ):
		reserved_tr.add( word )

def read_trdict( fname ):
	for word in readlist( fname ):
		update_trdict( word )
		tword = word[0].upper() + word[1:]
		if tword != word:
			update_trdict( tword )
		uword = word.upper()
		if uword != word:
			update_trdict( uword )

def writexml( doc, writer, encoding ):
	writer = codecs.getwriter( encoding )( writer,  'xmlcharrefreplace' )
	doc.writexml( writer, encoding = encoding )
	writer.close()


if __name__ == '__main__':
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:d:hko:qTvV',
			['backup', 'dictionary=', 'help', 'log-file', 'progress', 'quick', 'text', 'version'] )
	except getopt.GetoptError as err:
		print( 'Error:', err, file = sys.stderr )
		sys.exit( 2 )

	keepBackup = False
	backupSuffix = str( '.bak' )
	verbose = False
	plainText = False

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
		elif option in ('-q', '--quick'):
			quick = True
		elif option in ('-v', '--progress'):
			verbose = True
		elif option in ('-T', '--text'):
			plainText = True
		elif option in ('-o', '--log-file'):
			logfile = io.open( value, 'wt', encoding = 'utf-8' )
		elif option in ('-d', '--dictionary'):
			read_trdict( value )

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args )

	global filename
	for filename in args:
		try:
			if plainText:
				# Process plain text in UTF-8
				if filename == str( '-' ):
					if sys.version_info[0] >= 3:
						data0 = sys.stdin.read()
						data = fixtr_text( data0 )
						sys.stdout.write( data )
					else:
						data0 = sys.stdin.read().decode( 'utf-8' )
						data = fixtr_text( data0 )
						sys.stdout.write( data.encode( 'utf-8' ) )
				else:
					data0 = io.open( filename, 'rt', encoding = 'utf-8' )
					data = fixtr_text( data0 )
					if data != data0:
						tmpfilename = filename + str( '.tmp' )
						io.open( tmpfilename, 'wt', encoding = 'utf-8' ).write( data )
						if keepBackup:
							os.rename( filename, filename + backupSuffix )
						os.rename( tmpfilename, filename )
			else:
				# Process FB2
				if filename == str( '-' ):
					if sys.version_info[0] >= 3:
						f = sys.stdin.buffer.raw
					else:
						f = sys.stdin
					doc = xml.dom.minidom.parse( f )
					encoding = doc.encoding or str( 'utf-8' )
					fixtr_fb2( doc )
					if sys.version_info[0] >= 3:
						f = sys.stdout.buffer.raw
					else:
						f = sys.stdout
					writexml( doc, f, encoding )
				else:
					doc = xml.dom.minidom.parse( open( filename, 'rb' ) )
					encoding = doc.encoding or str( 'utf-8' )
					if fixtr_fb2( doc ):
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
			raise

	if logfile:
		logfile.close()
