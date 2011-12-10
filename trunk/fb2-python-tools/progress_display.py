# emacs-mode: -*- python-*-
try:
	import psyco
	psyco.full()
except:
	pass
import sys, time

class progress_display:
	def __init__( self, expected_count, width = 75, fout = sys.stderr ):
		self.__start = time.time()
		self.__expected_count = expected_count
		self.__count = 0
		self.__width = width - 25
		
		self.__fout = fout
		self.__progress( 0, 0 )

	def next( self, increment = 1 ):
		self.__count += increment
		self.__progress( float( self.__count ) / self.__expected_count, time.time() - self.__start )

	def close( self ):
		print >>self.__fout

	def __progress( self, perc, delta ):
		estimated = round( perc and delta / perc )
		width = self.__width
		if width > 0:
			bar = '|' + '#' * int( width * perc ) + '.' * ( width - int( width * perc ) ) + '|'
		else:
			bar = ''
		self.__fout.write( '\r%s%3d%% %s/%s' % ( bar, int( 100 * perc ), time.strftime( '%X', time.gmtime( round( delta ) ) ), time.strftime( '%X', time.gmtime( estimated ) ) ) )

def progress_iter( iter, width = 75, vis = None, fout = sys.stderr ):
	if not vis: vis = lambda x: x
	start = time.time()
	data = list( iter )
	width -= 25
	count = 0
	def _progress( perc, delta ):
		estimated = round( perc and delta / perc )
		if width > 0:
			bar = '|' + '#' * int( width * perc ) + '.' * ( width - int( width * perc ) ) + '|'
		else:
			bar = ''
		fout.write( '\r%s%3d%% %s/%s ' % ( bar, int( 100 * perc ), time.strftime( '%X', time.gmtime( round( delta ) ) ), time.strftime( '%X', time.gmtime( estimated ) ) ) )

	_progress( 0, 0 )
	for value in data:
		yield value
		count += 1
		_progress( float( count ) / len( data  ), time.time() - start )
	print >>fout
