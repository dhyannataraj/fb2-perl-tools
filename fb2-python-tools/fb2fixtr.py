#!/usr/bin/python
# -*- coding: UTF-8 -*-

'''\
Fix some popular OCR and conversion errors in FictionBook2 files.

Usage:
     fb2fixtr.py [<options>] [<fb2-files>]
Options:быстрее
     -h              display this help message and exit
     -V              display the version and exit
     -k              create backup files
     -@ <file>       read file names from file (one name per line)
     -q              quick but use more memory
     -v              display progressbar
File name '-' means standard input/output.
'''
__author__ = 'Serhiy Storchaka <storchaka@sourceforge.net>'
__version__ = '0.1'

import sys, string, re

quick = False

rus_lowercase = u'абвгдеёжзийклмнопрстуфхцчшщъыьэюя'
rus_uppercase = rus_lowercase.upper()
rus_letters = rus_lowercase + rus_uppercase

cyr_lowercase = rus_lowercase + u'іїєґ'
cyr_uppercase = cyr_lowercase.upper()
cyr_letters = cyr_lowercase + cyr_uppercase

lat_tr = u'aABcCeEHKMnoOpPrTuxXy'
rus_tr = u'аАВсСеЕНКМпоОрРгТихХу'

lat2cyr = dict( zip( lat_tr + u'miI', rus_tr + u'міІ' ) )
cyr2lat = dict( zip( rus_tr + u'міІ', lat_tr + u'miI' ) )
lat2cyr.update( (c, c) for c in cyr_letters )
cyr2lat.update( (c, c) for c in string.ascii_letters )

word_re = re.compile( ur'([\w]+)', re.UNICODE )

def maketest( chars ):
	return re.compile( ur'\A[' + chars + ur']+\Z', re.UNICODE ).match

# islat = maketest( string.ascii_letters )
islat = maketest( string.ascii_letters + '_' )
isrus = maketest( rus_letters + '_' )
iscyr = maketest( cyr_letters + '_' )
ispseudo = maketest( lat_tr + u'iI' + rus_tr + u'іІ'  )
ispseudolat = maketest( string.ascii_letters + rus_tr )
ispseudorus = maketest( lat_tr + rus_letters )
ispseudocyr = maketest( lat_tr + cyr_letters + u'iI' )
iscyri = maketest( cyr_letters + u'i' )
isrusJ = maketest( rus_letters + u'\u0408' )
isnumber = re.compile( ur'\A\d+\Z', re.UNICODE ).match
isnote = re.compile( ur'\A(?:note|Note|footnote|child_|FbAutId_)\d+\Z', re.UNICODE ).match

isroman = re.compile( ur'\A(?:M{0,3})(?:D?C{0,3}|C[DM])(?:L?X{0,3}|X[LC])(?:V?I{0,3}|I[VX])\Z' ).match
beginnumber_re = re.compile( ur'\A([0-9]+)(\w+)\Z' )
endnumber_re = re.compile( ur'\A(\w+?)([0-9]+)\Z' )
iscross = re.compile( ur'\A[0-9]+(?:х[0-9]+)+\Z' ).match

hasdigits = re.compile( ur'\A.*[0-9].*\Z', re.UNICODE ).match

def tocyr( word ):
	return ''.join( lat2cyr[c] for c in word )

def tolat( word ):
	return ''.join( cyr2lat[c] for c in word )

is_reserved_lat = re.compile( ur'\A(?:%s)\Z' % '|'.join( line.rstrip( '\n' ).decode( 'utf-8' ) for line in open( 'reserved_lat' ) ), re.UNICODE ).match
is_reserved_cyr = re.compile( ur'\A(?:%s)\Z' % '|'.join( line.rstrip( '\n' ).decode( 'utf-8' ) for line in open( 'reserved_cyr' ) ), re.UNICODE ).match
translates = dict( line.rstrip( '\n' ).decode( 'utf-8' ).split( ' ', 1 ) for line in open( 'replaces' ) )

def showalpha1( c ):
	if c in string.ascii_letters: return 'A'
	if c in string.digits: return '0'
	if c in rus_letters: return 'R'
	if c == '_': return '_'
	return '?'

global filename
def printtrans2( word, s, *args ):
	print '%s:' % filename, word.encode( 'utf-8' ), s, ' '.join( args ).encode( 'utf-8' )

def word_fixtr( word ):
	# Слишком короткое слово -- гадать бессмысленно
	if len( word ) < 3 or len( word.replace( '_', '' ) ) < 2:
		return word

	# Слово полностью принадлежит одном алфавиту
	if iscyr( word ) or islat( word ) or isnumber( word ):
		return word

	# Слово состоит из букв, похожих и на русские (украинские) и на латиницу
	if ispseudo( word ):
		# Слово типично иноземное или римская цифра
		lat_word = tolat( word )
		if is_reserved_lat( lat_word ) or isroman( lat_word ):
			return lat_word
		# Слово типично кириллическое
		cyr_word = tocyr( word )
		if is_reserved_cyr( cyr_word ):
			return cyr_word
		# Неопределённость
		printtrans2( word, '<>', lat_word, cyr_word )
		return word

	# Слово состоит из русских букв и похожих на русские
	if ispseudorus( word ):
		return tocyr( word )

	# Слово состоит из латинских букв и похожих на латинские
	if ispseudolat( word ):
		return tolat( word )

	# Слова с цифрами
	if hasdigits( word ):
		# Метки часто содержат в себе номер
		if isnote( word ):
			return word

		# Слова вида 9x12
		if iscross( word ):
			return word

		# Сначала цифры, потом буквы
		m = beginnumber_re.match( word )
		if m and not hasdigits( m.group( 2 ) ):
			# Физические единицы отделяем неразрывным пробелом
			if m.group( 2 ) in (u'гг', u'мг', u'г', u'кг', u'мл', u'л', u'ч', u'мм', u'см', u'дм', u'м', u'км'):
				return m.expand( u'\\1\u00A0\\2' )
			# Русские окончания отделяем дефисом
			if m.group( 2 ) in (u'ый', u'ой', u'й', u'ым', u'ом', u'я', u'ая', u'е', u'ое', u'го', u'ого', u'ю', u'ую'):
				return m.expand( ur'\1-\2' )
			# А английские оставляем так
			if m.group( 2 ) in ('st', 'nd', 'rd', 'th', 's', 'd'):
				return m.expand( ur'\1\2' )
			# Иначе просто собираем статистику
			printtrans2( word, '9a>', m.expand( ur'\1-\2' ) )
			return word

		# Сначала буквы, потом цифры
		m = endnumber_re.match( word )
		if m and not hasdigits( m.group( 1 ) ):
			# Просто собираем статистику
			printtrans2( word, 'a9>', m.expand( ur'\1-\2' ) )

		# Возможно цифра -- на самом деле буква.
		# Дело тёмное и рискованное.
# 		if word == u'3а':
# 			return u'За'
# 		if word == u'0н':
# 			return u'Он'
# 		if word[0] == u'3' and len( word ) >= 3:
# 			word2 = word.replace( u'3', u'З', 1 )
# 			if ispseudorus( word2 ):
# 				return tocyr( word2 )
# 		if u'6' in word and len( word ) >= 3:
# 			word2 = word.replace( u'6', u'б' )
# 			if ispseudorus( word2 ):
# 				return tocyr( word2 )
# 		word2 = word.replace( u'3', u'З' )
# 		word2 = word.replace( u'6', u'б' )
		return word

	# Слово принадлежит европейскому языку
	for enc in ('iso-8859-2', 'iso-8859-4', 'iso-8859-7', 'iso-8859-15'):
		try:
			word.encode( enc )
			return word
		except:
			pass

	try:
		word2 = word

		# Слово состоит из кириллических букв и похожих на кириллические и содержит i с точкой
		# Явно (псевдо)украинское или старорусское
		if (u'i' in word or u'I' in word) and ispseudocyr( word ):
			# Часто 'п', за которой следуют 'о' или 'е' неправильно распознаётся
			word2 = tocyr( re.sub( u'^ii|ii(?=[еоeo])', u'п', word ) )
			printtrans2( word, 'i>', word2 )
			return word2

		# Слово состоит из русских букв и непонятного символа, похожего на J.
		# На самом деле это 'ё'
		if u'\u0408' in word and isrusJ( word ) and word.replace( u'\u0408', u'' ):
			word2 = word.replace( u'\u0408', u'ё' )
			printtrans2( word, 'J>', word2 )
			return word2

		# Возможно оригинальный текст был в европейской кодировке iso-8859-15,
		# а работали с ним как с cp1251.
		# Пока что достаточно экспериментально.
		word2 = word.encode( 'cp1251' ).decode( 'iso-8859-15' )
		if not word_re.match( word2 ):
			raise
		for c in word.encode( 'cp1251' ):
			if ord( c ) in range( 128, 192 ):
				raise
		# Если не-ASCII символов немного, то скорее всего так и есть
		count = len( c for c in word if c not in string.ascii_letters )
		if count <= 1 and 3 * count <= len( word ):
			printtrans2( word, 'E>', word2 )
			return word2

# 		if '__' in word:
# 			return word
# 		if word[0] == '_' or word[-1] == '_':
# 			word2 = word.replace( u'_', u'' )
# 			if isrus( word2 ):
# 				if word[0] == '_':
# 					word2 = '<emphasis>' + word2
# 				if word[-1] == '_':
# 					word2 = word2 + '</emphasis>'
# 				return word2

		printtrans2( word, '?>', word2 )
	except:
		printtrans2( word, '!>', word2 )
	return word

# [s.encode( 'utf-8' ).decode( 'cp1251', 'replace' ) for s in sorted( list( set( sum( [chr( i ).decode( enc ) for i in range( 128, 256 )] for enc in ('iso-8859-2', 'iso-8859-15'), [] ) ) ) )]

utf_illegal_pref_re = re.compile( '(?<=\xe2\x80)(?![\x80-\xbf])', re.DOTALL )
utf_illegal_pref_re = re.compile( u'\u0432\u0402(?:\ufffd|[\u2000-\u203f])?', re.DOTALL )

def fix_utf_illegal_pref( m ):
	data = m.group()
	if data == u'\u0432\u0402' or data == u'\u0432\u0402\ufffd':
		return u'\u2018'
	return data.encode( 'cp1251' ).decode( 'utf-8' )

def text_fixtr( text ):
	global quick

	changed = False
	if u'\u0432\u0402' in text: #'вЂ'
		# Указана кодировка cp1251, а на самом деле -- utf-8
		text = utf_illegal_pref_re.sub( fix_utf_illegal_pref, text )
		changed = True

	# Разбиваем текст на слова и обрабатываем их по отдельности.
	# Потом склеиваем.
	words = word_re.split( text )
	for iword, word in enumerate( words ):
		if word_re.match( word ):
			# Для начала смотрим в словаре
			if word in translates:
				word2 = translates[word]
			else:
				word2 = word_fixtr( word )
				if quick or word != word2:
					# Переведённое слово заносим в словарь.
					# В режиме quick заносим и неизменённые слова, для ускорения.
					translates[word] = word2

# 			print word.encode( 'utf-8' ), word2 and word2.encode( 'utf-8' )
# 			sys.stdout.flush()
			if word != word2:
				printtrans2( word, '->', word2 )
				words[iword] = word2
				changed = True

	if changed:
		text = u''.join( words )

	return text

split_re = re.compile( ur'(<binary.+?</binary>|<id.+?</id>|<.+?>)', re.UNICODE|re.DOTALL )

def fb2fixtr( data ):
	# Разбиваем текст на куски подлежащие коррекции и нет (теги, binary, id).
	# Обрабатываем куски по отдельности а затем склеиваем.
	changed = False
	sketches = split_re.split( data )
	for isketch, sketch in enumerate( sketches ):
		if not split_re.match( sketch ):
			sketch2 = text_fixtr( sketch )
			if sketch != sketch2:
				sketches[isketch] = sketch2
				changed = True

	if changed:
		data = u''.join( sketches )
	return data

def getencoding( data ):
	m = re.match( r'<\?xml version="(?:[^">]*)" encoding="([^">]*)"\?>', data )
	if m:
		return m.group( 1 )
	else:
		return 'utf-8'

if __name__ == '__main__':
	import getopt
	try:
		opts, args = getopt.getopt( sys.argv[1:], '@:hkqtvV' )
	except getopt.GetoptError:
		print >>sys.stderr, 'Error:', err
		sys.exit(2)

	testOnly = False
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
		elif option == '-q':
			quick = True
		elif option == '-t':
			testOnly = True
		elif option == '-v':
			verbose = True

	if verbose:
		import progress_display
		args = progress_display.progress_iter( args, os.path.basename, sys.stderr )

	global filename
	for filename in args:
		try:
			if filename == '-':
				data0 = sys.stdin.read()
			else:
				data0 = open( filename, 'r' ).read()
			encoding = getencoding( data0 )
			data0 = data0.decode( encoding )
			data = fb2fixtr( data0 )
			if data != data0:
				print filename
				data = data.encode( encoding )
				if filename == '-':
					if not testOnly:
						sys.stdout.write( data )
				else:
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

# 	translatesfile = open( 'translates', 'w' )
# 	for word, word2 in translates.iteritems():
# 		print >>translatesfile, word.encode( 'utf-8' ), word2.encode( 'utf-8' )
# 	translatesfile.close()
