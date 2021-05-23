$( function() { // document ready start >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

function passwordWrong() {
	info( {
		  icon    : 'lock-circle'
		, title   : 'Password Login'
		, nox     : 1
		, message : 'Wrong existing password.'
	} );
	$( '#login' ).prop( 'checked', G.login );
}

refreshData = function() { // system page: use resetLocal() to aviod delay
	bash( '/srv/http/bash/features-data.sh', function( list ) {
		var list2G = list2JSON( list );
		if ( !list2G ) return
		
		$( '#shairport-sync' ).prop( 'checked', G[ 'shairport-sync' ] );
		$( '#spotifyd' ).prop( 'checked', G.spotifyd );
		$( '#snapclient' ).prop( 'checked', G.snapclient );
		disableSwitch( '#snapclient', G.snapserver );
		$( '#setting-snapclient' ).toggleClass( 'hide', !G.snapclient );
		$( '#upmpdcli' ).prop( 'checked', G.upmpdcli );
		$( '#streaming' ).prop( 'checked', G.streaming );
		$( '#snapserver' ).prop( 'checked', G.snapserver );
		disableSwitch( '#snapserver', G.snapclient );
		$( '#hostapd, #hostapdchk' ).prop( 'checked', G.hostapd );
		$( '#setting-hostapd' ).toggleClass( 'hide', !G.hostapd );
		$( '#transmission' ).prop( 'checked', G.transmission );
		$( '#localbrowser' ).prop( 'checked', G.localbrowser );
		$( '#setting-localbrowser' ).toggleClass( 'hide', !G.localbrowser );
		$( '#aria2' ).prop( 'checked', G.aria2 );
		$( '#smb' ).prop( 'checked', G.smb );
		$( '#setting-smb' ).toggleClass( 'hide', !G.smb );
		$( '#mpdscribble' ).prop( 'checked', G.mpdscribble );
		$( '#setting-mpdscribble' ).toggleClass( 'hide', !G.mpdscribble );
		$( '#login' ).prop( 'checked', G.login );
		$( '#setting-login' ).toggleClass( 'hide', !G.login );
		$( '#autoplaycd' ).prop( 'checked', G.autoplaycd );
		$( '#autoplay' ).prop( 'checked', G.autoplay );
		[ 'hostapd', 'localbrowser', 'mpdscribble', 'shairport-sync', 'smb', 'snapserver', 'spotifyd', 'upmpdcli' ].forEach( function( id ) {
			codeToggle( id, 'status' );
		} );
		resetLocal();
		showContent();
	} );
}
refreshData();
// hostapd
if ( set ) setTimeout( function() { $( '#'+ set ).click() }, 900 );

$( '#ip' ).html( 'http://'+ location.host +':8000' );
if ( $( '#transmission' ).length ) {
	var url = location.host +':9091';
	$( '#urltran' ).html( '<a href="http://'+ url +'">'+ url +'</a>' );
}
if ( $( '#aria2' ).length ) {
	var url = location.host +'/aria2/index.html';
	$( '#urlaria' ).html( '<a href="http://'+ url +'">'+ url +'</a>' );
}
//---------------------------------------------------------------------------------------
$( '.enable' ).click( function() {
	var checked = $( this ).prop( 'checked' );
	if ( $( this ).hasClass( 'disabled' ) ) {
		$( this ).prop( 'checked', !checked );
		return
	}
	
	var idname = {
		  hostapd      : [ 'RPi Access Point',     'wifi' ]
		, localbrowser : [ 'Browser on RPi',       'chromium' ]
		, login        : [ 'Password Login',       'lock-circle' ]
		, mpdscribble  : [ 'Last.fm Scrobbler',    'lastfm' ]
		, smb          : [ 'Samba - File Sharing', 'networks' ]
		, snapclient   : [ 'SnapClient Renderer',  'snapcast' ]
	}
	var id = this.id;
	if ( checked ) {
		$( '#setting-'+ id ).click();
	} else {
		if ( id !== 'login' ) {
			var nameicon = idname[ id ];
			notify( nameicon[ 0 ], 'Disable ...', nameicon[ 1 ] );
			bash( [ id +'disable' ] );
		} else {
			$( '#login' ).prop( 'checked', G.login );
			info( {
				  icon          : 'lock-circle'
				, title         : 'Password Login'
				, message       : 'Disable:'
				, passwordlabel : 'Password'
				, pwdrequired   : 1
				, ok            : function() {
					$.post( 'cmd.php', {
						  cmd      : 'login'
						, password : $( '#infoPasswordBox' ).val()
					}, function( std ) {
						if ( std ) {
							notify( 'Password Login', 'Disable ...', 'lock-circle' );
							bash( [ id +'disable' ] );
						} else {
							passwordWrong();
						}
					} );
				}
			} );
		}
	}
} );
$( '.enablenoset' ).click( function() {
	var idname = {
		  autoplay         : [ 'Play on Startup',                  'refresh-play' ]
		, autoplaycd       : [ 'Play on Insert CD',                'audiocdplay' ]
		, localbrowser     : [ 'Chromium - Browser on RPi',        'chromium' ]
		, 'shairport-sync' : [ 'AirPlay Renderer',                 'airplay' ]
		, snapserver       : [ 'Snapcast - Sync Streaming Server', 'snapcast' ]
		, spotifyd         : [ 'Spotify Connect',                  'spotify' ]
		, streaming        : [ 'HTTP Streaming',                   'mpd' ]
		, upmpdcli         : [ 'UPnP Renderer',                    'upnp' ]
	}
	var id = this.id;
	var checked = $( this ).prop( 'checked' );
	var nameicon = idname[ id ];
	notify( nameicon[ 0 ], checked, nameicon[ 1 ] );
	bash( [ id, checked ] );
} );

$( '#setting-snapclient' ).click( function() {
	info( {
		  icon         : 'snapcast'
		, title        : 'SnapClient'
		, message      : 'Sync SnapClient with SnapServer:'
		, textlabel    : 'Latency <gr>(ms)</gr>'
		, textrequired : [ 0 ]
		, values       : G.snaplatency || 800
		, boxwidth     : 100
		, checkchange  : ( G.snapclient ? [ G.snaplatency ] : '' )
		, cancel       : function() {
			$( '#snapclient' ).prop( 'checked', G.snapclient );
		}
		, ok           : function() {
			var snaplatency = Math.abs( infoVal() );
			bash( [ 'snapclientset', snaplatency ] );
			notify( 'Snapclient', G.snapclient ? 'Change ...' : 'Enable ...', 'snapcast' );
		}
	} );
} );
$( '#hostapdchk' ).click( function() {
	var checked = $( this ).prop( 'checked' );
	if ( !G.hostapd && G.wlanconnect && checked ) {
		info( {
			  icon    : 'network'
			, title   : 'RPi Access Point'
			, message : '<wh>Wi-Fi is currently connected.</wh>'
						 +'<br>Disconnect and continue?'
			, cancel  : function() {
				if ( set ) {
					loader();
					location.href = '/settings.php?p=networks';
				} else {
					$( '#hostapd, #hostapdchk' ).prop( 'checked', 0 );
				}
			}
			, ok      : function() {
				$( '#hostapd' ).click();
			}
		} );
	} else {
		$( '#hostapd' ).click();
	}
} );
$( '#setting-hostapd' ).click( function() {
	info( {
		  icon         : 'network'
		, title        : 'RPi Access Point Settings'
		, message      : 'Password - 8 characters or more'
		, textlabel    : [ 'Password', 'IP' ]
		, values       : [ G.hostapdpwd, G.hostapdip ]
		, checkchanged : ( G.hostapd ? 1 : 0 )
		, textrequired : [ 0, 1 ]
		, textlength   : { 0: 8 }
		, cancel       : function() {
			if ( set ) {
				loader();
				location.href = '/settings.php?p=networks';
			} else {
				$( '#hostapd, #hostapdchk' ).prop( 'checked', G.hostapd );
			}
		}
		, ok           : function() {
			var values = infoVal();
			var pwd = values[ 0 ];
			var ip = values[ 1 ];
			var ips = ip.split( '.' );
			var ip3 = ips.pop();
			var ip012 = ips.join( '.' );
			var iprange = ip012 +'.'+ ( +ip3 + 1 ) +','+ ip012 +'.254,24h';
			bash( [ 'hostapdset', iprange, ip, pwd ] );
			notify( 'RPi Access Point', G.hostapd ? 'Change ...' : 'Enable ...', 'wifi' );
		}
	} );
} );
var localbrowserinfo = heredoc( function() { /*
	<table>
		<tr><td>Screen off</td>
			<td><input type="text">&ensp;<gr>min</gr></td>
		</tr>
		<tr><td>Zoom</td>
			<td><input type="text">&ensp;<gr>0.5-2.0</gr></td>
		</tr>
	</table>
	<hr>
	Screen rotation<br>
	<table>
		<tr><td></td><td style="text-align: center;">0°</td><td></td></tr>
		<tr><td></td><td><label><input type="radio" name="inforadio" value="NORMAL"></label></td><td></td></tr>
		<tr>
			<td><label>90° <i class="fa fa-undo"></i> <input type="radio" name="inforadio" value="CCW"></label></td>
			<td></td>
			<td><input type="radio" name="inforadio" value="CW"> <i class="fa fa-redo gr" style="font-size: 22px"></i>&nbsp; 90°</label></td>
		</tr>
		<tr><td></td><td><input type="radio" name="inforadio" value="UD"></label></td><td></td></tr>
		<tr><td></td><td>180°</td><td></td></tr>
	</table>
	<hr>
	<label><input type="checkbox">Mouse pointer</label><br>
*/ } );
if ( G.lcd ) localbrowserinfo += '<br><gr>(Rotate TFT LCD: Reboot required.)</gr>';
$( '#setting-localbrowser' ).click( function() {
	info( {
		  icon         : 'chromium'
		, title        : 'Browser on RPi'
		, content      : localbrowserinfo
		, boxwidth     : 60
		, values       : [ G.localscreenoff, G.localzoom, G.localrotate, G.localcursor ]
		, checkchanged : ( G.localbrowser ? 1 : 0 )
		, textrequired : [ 0, 1 ]
		, buttonlabel  : '<i class="fa fa-refresh"></i>Refresh'
		, buttoncolor  : orange
		, button       : function() {
			bash( 'curl -s -X POST http://127.0.0.1/pub?id=reload -d 1' );
		}
		, cancel       : function() {
			$( '#localbrowser' ).prop( 'checked', G.localbrowser );
		}
		, ok           : function() {
			var values = infoVal();
			var localscreenoff = values[ 0 ] * 60;
			var localzoom = parseFloat( values[ 1 ] ) || 1;
			var localrotate    = values[ 2 ];
			var localcursor    = values[ 3 ];
			bash( [ 'localbrowserset', localscreenoff, localzoom, localrotate, localcursor ] );
			notify( 'Chromium - Browser on RPi', G.localbrowser ? 'Change ...' : 'Enable ...', 'chromium' );
		}
	} );
} );
$( '#setting-smb' ).click( function() {
	info( {
		  icon         : 'network'
		, title        : 'Samba File Sharing'
		, message      : '<wh>Write</wh> permission:</gr>'
		, checkbox     : [ '<gr>/mnt/MPD/</gr>SD', '<gr>/mnt/MPD/</gr>USB' ]
		, values       : [ G.smbwritesd, G.smbwriteusb ]
		, checkchanged : ( G.smb ? 1 : 0 )
		, cancel       : function() {
			$( '#smb' ).prop( 'checked', G.smb );
		}
		, ok           : function() {
			var values = infoVal();
			bash( [ 'smbset', values[ 0 ], values[ 1 ] ] );
			notify( 'Samba - File Sharing', G.smb ? 'Change ...' : 'Enable ...', 'network' );
		}
	} );
} );
$( '#setting-mpdscribble' ).click( function() {
	info( {
		  icon          : 'lastfm'
		, title         : 'Last.fm Scrobbler'
		, textlabel     : 'User'
		, passwordlabel : 'Password'
		, values        : ( G.mpdscribbleval ? G.mpdscribbleval.split( '^' ) : '' )
		, checkchanged  : ( G.mpdscribble ? 1 : 0 )
		, textrequired : [ 0, 1 ]
		, cancel        : function() {
			$( '#mpdscribble' ).prop( 'checked', G.mpdscribble );
		}
		, ok            : function() {
			var values = infoVal();
			bash( [ 'mpdscribbleset', escapeUsrPwd( values[ 0 ] ), escapeUsrPwd( values[ 1 ] ) ], function( std ) {
				if ( std == -1 ) {
					info( {
						  icon    : 'lastfm'
						, title   : 'Last.fm Scrobbler'
						, message : 'Last.fm Login failed.'
					} );
					$( '#mpdscribble' ).prop( 'checked', 0 );
				}
			} );
			notify( 'Scrobbler', G.mpdscribble ? 'Change ...' : 'Enable ...', 'lastfm' );
		}
	} );
} );
$( '#setting-login' ).click( function() {
	info( {
		  icon          : 'lock-circle'
		, title         : 'Password Login'
		, message       : ( G.login ? 'Change password:' : 'New setup:' )
		, passwordlabel : ( G.login ? [ 'Existing', 'New' ] : 'Password' )
		, textrequired  : [ 0 ]
		, cancel        : function() {
			$( '#login' ).prop( 'checked', G.login );
		}
		, ok            : function() {
			var values = infoVal();
			notify( 'Password Login', G.login ? 'Change ...' : 'Enable...', 'lock-circle' );
			$.post( 'cmd.php', {
				  cmd      : 'login'
				, password : escapeUsrPwd( values[ 0 ] )
				, pwdnew   : escapeUsrPwd( values[ 1 ] )
			}, function( std ) {
				if ( !std ) passwordWrong();
				bannerHide();
			} );
		}
	} );
} );

} );
