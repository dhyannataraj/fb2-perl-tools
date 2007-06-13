#!/usr/bin/python
# -*- coding: UTF-8 -*-

'''\
Fix some popular OCR and conversion errors in FictionBook2 files.

Usage:
     fb2fixtr.py [<options>] [<fb2-files>]
Options:
     -h              display this help message and exit
     -V              display the version and exit
     -k              create backup files
     -@ <file>       read file names from file (one name per line)
     -q              quick but use more memory
     -T              process plain text
     -v              display progressbar
     -o logfile      log all fixes to logfile
File name '-' means standard input/output.
'''
__author__ = 'Serhiy Storchaka <storchaka@sourceforge.net>'
__version__ = '0.1'
__all__ = []

import string, re
import sys, getopt, os, os.path, xml.dom.minidom, codecs

quick = False

rus_lowercase = u'абвгдеёжзийклмнопрстуфхцчшщъыьэюя'
rus_uppercase = rus_lowercase.upper()
rus_letters = rus_lowercase + rus_uppercase

cyr_lowercase = rus_lowercase + u'іїєґ'
cyr_uppercase = cyr_lowercase.upper()
cyr_letters = cyr_lowercase + cyr_uppercase

rus_tr = u'аАВсСеЕНКМпоОрРгТихХу'
rus_lat_tr = u'aABcCeEHKMnoOpPrTuxXy'
cyr_tr = u'аАВсСеЕНіІКМпоОрРгТихХу'
cyr_lat_tr = u'aABcCeEHiIKMnoOpPrTuxXy'

lat2cyr = dict( zip( cyr_letters + cyr_lat_tr, cyr_letters + cyr_tr ) )
cyr2lat = dict( zip( string.ascii_letters + cyr_tr, string.ascii_letters + cyr_lat_tr ) )
num2cyr = {u'0': u'О', u'3': u'З', u'6': u'б'}

word_re = re.compile( ur'([\w]+)', re.UNICODE )

def maketest( chars ):
	return re.compile( ur'\A[' + chars + ur']+\Z', re.UNICODE ).match

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
isrusJ = maketest( rus_letters + u'\u0408' )
isnumber = re.compile( ur'\A\d+\Z', re.UNICODE ).match
isroman = re.compile( ur'\A(?:M{0,3})(?:D?C{0,3}|C[DM])(?:L?X{0,3}|X[LC])(?:V?I{0,3}|I[VX])\Z' ).match
beginnumber_re = re.compile( ur'\A([0-9]+)(\w+)\Z', re.UNICODE )
endnumber_re = re.compile( ur'\A(\w+?)([0-9]+)\Z', re.UNICODE )
iscross = re.compile( ur'\A[0-9]+(?:х[0-9]+)+\Z' ).match

hasdigits = re.compile( ur'\A.*[0-9].*\Z', re.UNICODE ).match

def tocyr( word ):
	return ''.join( lat2cyr[c] for c in word )

def tolat( word ):
	return ''.join( cyr2lat[c] for c in word )

def readlist( f ):
	for line in f:
		line = line.rstrip( '\n' ).decode( 'utf-8' )
		if len( line ) > 0 and line[0] != '#':
			yield line

reserved_tr = set()
def is_reserved_lat( word ):
	return word in  reserved_tr and tocyr( word ) not in reserved_tr

def is_reserved_cyr( word ):
	return word in  reserved_tr and tolat( word ) not in reserved_tr

translates = {}
try:
	translates.update( line.split( ' ', 1 ) for line in readlist( open( 'replaces' ) ) )
except:
	pass
try:
	translates.update( (w, w) for w in readlist( open( 'reserved' ) ) )
except:
	pass

logfile = None
global filename
def logtr( word, type, *args ):
	if logfile:
		print >>logfile, '%s:' % filename, word.encode( 'utf-8' ), type, ' '.join( args ).encode( 'utf-8' )

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
		if iscyr( word.replace( u'H', u'Н' ) ):
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
			if m.group( 1 ) in (ur'note', ur'note_', ur'Note', ur'footnote', ur'child_', ur'FbAutId_', ur'comment_', ur'text_', ur'N', ur'N_', ur'No'):
				return word
	
			# Между словом и номером пропущен пробел
			if m.group( 1 ) in (ur'Глава', ur'ГЛАВА', ur'глава'):
				return m.expand( ur'\1 \2' )

			# Начальная единица года распозналась как 'I"
			if re.match( ur'\AI[89][0-9][0-9]\Z', word ):
				return u'1' + word[1:]
			# Просто собираем статистику
			logtr( word, '!' )
			return word

		# Сначала цифры, потом буквы
		m = beginnumber_re.match( word )
		if m and not hasdigits( m.group( 2 ) ):
			# Физические единицы отделяем неразрывным пробелом
			if m.group( 2 ) in (u'гг', u'мг', u'г', u'кг', u'мл', u'л', u'ч', u'мм', u'см', u'дм', u'м', u'км' ):
				return m.expand( u'\\1\u00A0\\2' )
			# Русские окончания отделяем дефисом
			if m.group( 2 ) in (u'ый', u'ой', u'й', u'ым', u'ом', u'я', u'ая', u'е', u'ое', u'го', u'ого', u'ю', u'ую'):
				return m.expand( ur'\1-\2' )
			# А английские оставляем так
			if m.group( 2 ) in ('st', 'nd', 'rd', 'th', 's', 'd', 'ff', 'mm', 'cm', 'mm', 'km', 'unt', 'cc', 'F'):
				return word
			if word[0] in u'036' and ( iscyrlower( word[1:] ) or iscyrupper( word[1:] ) ):
				return num2cyr[word[0]] + word[1:]
			# Иначе просто собираем статистику
			logtr( word, '!' )
			return word

		# Начальная единица распозналась как 'I"
		m = re.match( ur'\AI[0-9]+(?:st|nd|rd|th|s|d)\Z', word )
		if m:
			return u'1' + word[1:]

		# Возможно цифра -- на самом деле буква.
		# Дело тёмное и рискованное.
		word2 = word.replace( u'ь1', u'ы' ).replace( u'Ь1', u'Ы' )
		if word2 != word:
			if ispseudorus( word2 ):
				return tocyr( word2 )

		if re.search( ur'6[аеиоуaeuoy]|[аеиоуaeuoy]6', word ):
			word2 = word.replace( u'6', u'б' )
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
	if (u'i' in word or u'I' in word) and ispseudocyr( word ):
		# Часто 'п', за которой следуют 'о' или 'е' неправильно распознаётся
		word2 = re.sub( u'^ii|^[гт]i(?=о)|[гi]i(?=[еоeo])', u'п', word )
		# Также начальные 'Ш' и 'П'
		word2 = re.sub( u'^III', u'Ш', word2 )
		word2 = re.sub( u'^II', u'П', word2 )
		# Украинское окончание
		word2 = re.sub( u'ii$', u'ії', word2 )
		word2 = re.sub( u'II$', u'ІЇ', word2 )
		word2 = tocyr( word2 )
		return word2

	# Слово состоит из русских букв и непонятного символа, похожего на J.
	# На самом деле это 'ё'
	if u'\u0408' in word and isrusJ( word ) and word.replace( u'\u0408', u'' ):
		return word.replace( u'\u0408', u'ё' )
	# Слетевшая кодировка для кавычек-ёлочек
	if word[0] == u'\u0458' and isrus( word[1:] ):
		return u'\xab' + word[1:]
	if word[-1] == u'\u0405' and isrus( word[:-1] ):
		return word[:-1] + u'\xbb'

	# Для обозначения ударения в русском слове использованы диакритические знаки.
	for c in u'áéúóý':
		if isrus( word.replace( c, u'' ) ):
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

utf_illegal_pref_re = re.compile( u'\u0432\u0402(?:\ufffd|[\u2000-\u203f])?', re.DOTALL )

def fix_utf_illegal_pref( m ):
	data = m.group()
	if data == u'\u0432\u0402' or data == u'\u0432\u0402\ufffd':
		return u'\u2018'
	return data.encode( 'cp1251' ).decode( 'utf-8' )

def fixtr_text( text ):
	global quick

	changed = False
	if u'\u0432\u0402' in text: #'вЂ'
		# Указана кодировка cp1251, а на самом деле -- utf-8
		text = utf_illegal_pref_re.sub( fix_utf_illegal_pref, text )
		changed = True

	# Символы номера и копирайта, оставшиеся с HTML
	text = text.replace( u'&#x2116;', u'\u2116' )
	text = text.replace( u'&#169;', u'\xa9' )

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
		text = u''.join( words )

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
	for word in readlist( open( fname ) ):
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
		opts, args = getopt.getopt( sys.argv[1:], '@:d:hko:qTvV' )
	except getopt.GetoptError, err:
		print >>sys.stderr, 'Error:', err
		sys.exit(2)

	keepBackup = False
	backupSuffix = '.bak'
	verbose = False
	plainText = False

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
		elif option == '-q':
			quick = True
		elif option == '-v':
			verbose = True
		elif option == '-T':
			plainText = True
		elif option == '-o':
			logfile = open( value, 'w' )
		elif option == '-d':
			read_trdict( value )

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args, os.path.basename, sys.stderr )

	global filename
	for filename in args:
		try:
			if plainText:
				# Process plain text in UTF-8
				if filename == '-':
					data0 = sys.stdin.read().decode( 'UTF-8' )
					data = fixtr_text( data0 )
					sys.stdout.write( data.encode( 'UTF-8' ) )
				else:
					data0 = open( filename, 'r' ).read().decode( 'UTF-8' )
					data = fixtr_text( data0 )
					if data != data0:
						tmpfilename = filename + '.tmp'
						open( tmpfilename, 'w' ).write( data.encode( 'UTF-8' ) )
						if keepBackup:
							os.rename( filename, filename + backupSuffix )
						os.rename( tmpfilename, filename )
			else:
				# Process FB2
				if filename == '-':
					doc = xml.dom.minidom.parse( sys.stdin )
					encoding = doc.encoding or 'UTF-8'
					fixtr_fb2( doc )
					writexml( doc, sys.stdout, encoding )
				else:
					doc = xml.dom.minidom.parse( open( filename, 'r' ) )
					encoding = doc.encoding or 'UTF-8'
					if fixtr_fb2( doc ):
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
			raise

	if logfile:
		logfile.close()
