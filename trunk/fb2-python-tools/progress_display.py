# emacs-mode: -*- python-*-
try:
	import psyco
	psyco.full()
except:
	pass
import sys, time

class progress_display:
	def __init__( self, expected_count, fout = sys.stderr ):
		self.__start = time.time()
		self.__expected_count = expected_count
		self.__count = 0
		self.__fout = fout
		self.__progress( 0, 0 )

	def next( self, increment = 1 ):
		self.__count += increment
		self.__progress( float( self.__count ) / self.__expected_count, time.time() - self.__start )

	def close( self ):
		print >>self.__fout

	def __progress( self, perc, delta ):
		estimated = round( perc and delta / perc )
		print >>self.__fout, '\r|%s%s|%3d%% %s/%s' % ( '#' * int( 50 * perc ), '.' * ( 50 - int( 50 * perc ) ), int( 100 * perc ), time.strftime( '%X', time.gmtime( round( delta ) ) ), time.strftime( '%X', time.gmtime( estimated ) ) ),

def progress_iter( iter, vis = None, fout = sys.stderr ):
	if not vis: vis = lambda x: x
	start = time.time()
	data = list( iter )
	count = 0
	def _progress( perc, delta ):
		estimated = round( perc and delta / perc )
		print >>fout, '\r|%s%s|%3d%% %s/%s' % ( '#' * int( 50 * perc ), '.' * ( 50 - int( 50 * perc ) ), int( 100 * perc ), time.strftime( '%X', time.gmtime( round( delta ) ) ), time.strftime( '%X', time.gmtime( estimated ) ) ),

	_progress( 0, 0 )
	for value in data:
		yield value
		count += 1
		_progress( float( count ) / len( data  ), time.time() - start )
	print >>fout, ' ' * 50
