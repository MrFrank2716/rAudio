#!/usr/bin/python

from lcdcharconfig import *
import sys
import os

icon = {
      'pause' : '\x00 '
    , 'play'  : '\x01 '
    , 'stop'  : '\x02 '
}
irr = '\x03\x04'
idots = '\x05  \x05  \x05'
rn = '\r\n'

spaces = ' ' * ( ( cols - 6 ) // 2 + 1 )
logo = rows > 2 and rn or ''
logo += spaces + irr + rn + spaces +'rAudio'

argvL = len( sys.argv )
if argvL == 2: # 1 argument
    val = sys.argv[ 1 ]
    if val == 'off': # backlight off
        lcd.backlight_enabled = False
    elif val == 'logo':
        lcd.write_string( logo )
    elif val == 'clear':
        lcd.clear()
    else:            # string
        lcd.write_string( val.replace( '\n', rn ) )
    lcd.close()
    quit()
    
import math
import time

def backlightOff():
    global backlight
    time.sleep( 60 )
    lcd.backlight_enabled = False
    lcd.close()
    quit()
    
def second2hhmmss( sec ):
    hh = math.floor( sec / 3600 )
    mm = math.floor( ( sec % 3600 ) / 60 )
    ss = sec % 60
    HH = hh > 0 and str( hh ) +':' or ''
    mmt = str( mm )
    MM = hh > 0 and ( mm > 9 and mmt +':' or '0'+ mmt +':' ) or ( mm > 0 and mmt +':' or '' )
    sst = str( ss )
    SS = mm > 0 and ( ss > 9 and sst or '0'+ sst ) or sst
    return HH + MM + SS
    
sys.path.append( '/srv/http/data/shm' )
from statuslcd import *
if 'station' not in locals(): station=""
if 'webradio' not in locals(): webradio=False

if charmap == 'A00':
    import unicodedata
    def normalize( str ):
        return ''.join( c for c in unicodedata.normalize( 'NFD', str )
                        if unicodedata.category( c ) != 'Mn' )
                        
    Artist = normalize( Artist )
    Title = normalize( Title )
    Album = normalize( Album )
    station = normalize( station )
    file = normalize( file )
    
Artist = Artist[ :cols ]
Title = Title[ :cols ]
Album = Album[ :cols ]
station = station[ :cols ]
file = file[ :cols ]

if webradio:
    if state != 'play':
        Artist = station
        Album = file
    else:
        if not Artist and not Title: Artist = station
        if not Album: Album = station or file
        
if not Artist: Artist = idots
if not Title: Title = idots
if not Album: Album = idots
if rows == 2:
    if state == 'play':
        lines = Title
    elif backlight:
        backlightOff()
else:
    lines = Artist + rn + Title + rn + Album

Timehhmmss = Time and second2hhmmss( round( float( Time ) ) ) or ''

if state == 'stop':
    progress = ( Timehhmmss + ' ' * cols )[ :cols - 4 ]
else:
    if elapsed is False: # can be 0
        elapsedhhmmss = ''
        slash = ''
    else:
        elapsed = round( float( elapsed ) )
        elapsedhhmmss = second2hhmmss( elapsed )
        slash = cols > 16 and ' / ' or '/'
    if Time: Timehhmmss = slash + Timehhmmss
    progress = ( elapsedhhmmss + Timehhmmss + ' ' * cols )[ :cols - 4 ]

lcd.write_string( lines + rn + icon[ state ] + progress + irr )

if backlight and state != 'play': backlightOff()

if elapsed is False: quit()

row = rows - 1
starttime = time.time()
elapsed += round( starttime - timestamp / 1000 )
iplay = icon[ 'play' ]

while True:
    sl = 1 - ( ( time.time() - starttime ) % 1 )
    lcd.cursor_pos = ( row, 0 )
    lcd.write_string( iplay + second2hhmmss( elapsed ) + Timehhmmss )
    elapsed += 1
    time.sleep( sl )
    