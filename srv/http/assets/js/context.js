function addReplace( cmd, command, title, msg ) {
	var play = cmd === 'addplay' || cmd === 'replaceplay';
	if ( play || cmd === 'replace' ) $( '#stop' ).click();
	bash( command );
	banner( 'playlist', title, msg );
}
function addSimilar() {
	banner( 'lastfm blink', 'Playlist - Add Similar', 'Fetch similar list ...', -1 );
	var url = 'http://ws.audioscrobbler.com/2.0/?method=track.getsimilar'
			+'&artist='+ encodeURI( G.list.artist )
			+'&track='+ encodeURI( G.list.name )
			+'&api_key='+ G.apikeylastfm
			+'&format=json'
			+'&autocorrect=1';
	$.post( url, function( data ) {
		var title = 'Playlist - Add Similar';
		if ( 'error' in data || ! data.similartracks.track.length ) {
			banner( 'lastfm', title, 'Track not found.' );
		} else {
			var val = data.similartracks.track;
			var iL = val.length;
			var similar = '';
			for ( i = 0; i < iL; i++ ) {
				similar += val[ i ].artist.name +'\n'+ val[ i ].name +'\n';
			}
			banner( 'library blink', title, 'Find similar tracks from Library ...', -1 );
			bash( [ 'mpcsimilar', similar ], count => {
				getPlaylist();
				setButtonControl();
				banner( 'library', title, count +' tracks added.' );
			} );
		}
	}, 'json' );
}
function bookmarkNew() {
	// #1 - track list - show image from licover
	// #2 - dir list   - show image from path + coverart.jpg
	// #3 - no cover   - icon + directory name
	if ( [ 'http', 'rtsp' ].includes( G.list.path.slice( 0, 4 ) ) ) {
		var $img = G.list.li.find( '.iconthumb' );
		var src = $img.length ? $img.attr( 'src' ).replace( /-thumb.jpg\?v=.*$/, '.jpg' ) : '';
		var path    = G.list.path;
		var name    = G.list.name;
		var msgpath = name;
	} else {
		if ( G.mode.slice( -5 ) === 'radio' ) {
			var path = G.mode +'/'+ G.list.path;
			var src  = '/data/'+ path +'/coverart.jpg';
		} else {
			var path = G.list.path.slice( -4 ) === '.cue' ? dirName( path ) : G.list.path;
			var src  = '/mnt/MPD/'+ path +'/coverart.jpg';
		}
		var msgpath = path;
		var name    = path.split( '/' ).pop()
	}
	info( {
		  icon       : 'bookmark'
		, title      : 'Add Bookmark'
		, message    : '<img src="'+ src + versionHash() +'">'
					  +'<br><br><wh>'+ msgpath +'</wh>'
		, textlabel  : 'As:'
		, focus      : 0
		, values     : name
		, checkblank : 1
		, beforeshow : () => {
			$( '#infoContent input' ).parents( 'tr' ).addClass( 'hide' );
			$( '#infoContent img' ).off( 'error' ).on( 'error', function() {
				imageOnError( this, 'bookmark' );
			} );
		}
		, ok         : () => {
			var name = infoVal();
			bash( [ 'bookmarkadd', name, path ], std => {
				if ( std == -1 ) {
					bannerHide();
					info( {
						  icon    : 'bookmark'
						, title   : 'Add Bookmark'
						, message : 'Bookmark <wh>'+ name +'</wh> already exists.'
					} );
				} else {
					banner( 'bookmark', 'Bookmark Added', name );
				}
			} );
		}
	} );
}
function infoReplace( callback ) {
	info( {
		  icon    : 'playlist'
		, title   : 'Playlist Replace'
		, message : 'Replace current playlist?'
		, ok      : callback
	} );
}
function playlistDelete() {
	info( {
		  icon    : 'file-playlist'
		, title   : 'Delete Playlist'
		, message : 'Delete?'
				   +'<br><wh>'+ G.list.name +'</wh>'
		, oklabel : '<i class="fa fa-minus-circle"></i>Delete'
		, okcolor : red
		, ok      : () => bash( [ 'savedpldelete', G.list.name ] )
	} );
}
function playlistLoad( path, play, replace ) {
	G.local = 1;
	banner( 'file-playlist blink', 'Saved Playlist', 'Load ...', -1 );
	list( {
		  cmd     : 'load'
		, name    : path
		, play    : play
		, replace : replace
	}, function( data ) {
		G.local = 0;
		G.status.pllength = +data;
		banner( 'playlist', replace ? 'Playlist Replaced' : 'Playlist Added', 'Done' );
	} );
}
function playlistNew( name ) {
	info( {
		  icon         : 'file-playlist'
		, title        : 'Save Playlist'
		, message      : 'Save current playlist as:'
		, textlabel    : 'Name'
		, focus        : 0
		, values       : name
		, checkblank   : 1
		, ok           : () => playlistSave( infoVal() )
	} );
}
function playlistRename() {
	var name = G.list.name;
	info( {
		  icon         : 'file-playlist'
		, title        : 'Rename Playlist'
		, message      : 'From: <wh>'+ name +'</wh>'
		, textlabel    : 'To'
		, focus        : 0
		, values       : name
		, checkchanged : 1
		, checkblank   : 1
		, oklabel      : '<i class="fa fa-flash"></i>Rename'
		, ok           : () => playlistSave( infoVal(), name )
	} );
}
function playlistSave( name, oldname, replace ) {
	if ( oldname ) {
		bash( [ 'savedplrename', oldname, name, replace ], data => {
			if ( data == -1 ) playlistSaveExist( 'rename', name, oldname );
		} );
	} else {
		bash( [ 'savedplsave', name, replace ], data => {
			if ( data == -1 ) {
				playlistSaveExist( 'save', name );
			} else {
				banner( 'playlist', 'Playlist Saved', name );
			}
		} );
	}
}
function playlistSaveExist( type, name, oldname ) {
	var rename = type === 'rename';
	info( {
		  icon        : 'file-playlist'
		, title       : rename ? 'Rename Playlist' : 'Save Playlist'
		, message     : 'Playlist: <wh>'+ name +'</wh>'
					   +'<br>Already exists.'
		, buttonlabel : '<i class="fa fa-undo"></i>Rename'
		, buttoncolor : orange
		, button      : () => setTimeout( () => rename ? playlistRename() : playlistNew( name ), 0 ) // fix error on repeating
		, oklabel     : '<i class="fa fa-flash"></i>Replace'
		, ok          : () => rename ? playlistSave( name, oldname, 'replace' ) : playlistSave( name, '' , 'replace' )
	} );
}
function tagEditor() {
	var name   = [ 'Album', 'AlbumArtist', 'Artist', 'Composer', 'Conductor', 'Genre', 'Date', 'Title', 'Track' ];
	var format = name.map( el => el.toLowerCase() );
	var file   = G.list.path;
	var cue    = file.slice( -4 ) === '.cue';
	if ( !G.playlist && G.list.licover ) format = format.slice( 0, -2 );
	var query = {
		  query  : 'track'
		, file   : G.list.path
		, format : format
	}
	list( query, function( values ) {
		name[ 1 ]    = 'Album Artist';
		var label    = [];
		format.forEach( ( el, i ) => {
			if ( G.playlist && ! values[ i ] ) {
				delete values[ i ];
				return
			}
			
			label.push( '<span class="taglabel gr hide">'+ name[ i ] +'</span> <i class="fa fa-'+ el +' wh" data-mode="'+ el +'"></i>' );
		} );
		if ( G.library ) {
			var $img = $( '.licover' ).length ? $( '.licoverimg img' ) : G.list.li.find( 'img' );
			var src  = $img.length ? $img.attr( 'src' ) : G.coverdefault;
		} else {
			var $img =  G.list.li.find( 'img' );
			var src  = $img.length ? $img.attr( 'src' ).replace( '/thumb.', '/coverart.' ) : G.coverdefault;
			values   = values.filter( val => val ); // reindex after deleting blank elements
		}
		var fileicon = cue ? 'file-music' : 'file-playlist';
		var message  = '<img src="'+ src +'"><a class="tagpath hide">'+ file +'</a>'
					 +'<div>';
		if ( G.list.licover ) {
			message += '<i class="fa fa-folder"></i>'+ file;
		} else {
			message += '<i class="fa fa-folder gr"></i><gr>'+ file +'</gr><br><i class="fa fa-'+ fileicon +'"></i>'+ file.split( '/' ).pop();
		}
		message     += '</div>';
		var footer   = '';
		footer      += '<div id="taglabel"><i class="fa fa-help fa-lg"></i>&emsp;Label</div>';
		if ( G.list.licover ) footer += '<div><code> * </code>&ensp;Various values in tracks</div>';
		info( {
			  icon         : G.playlist ? 'info-circle' : 'tag'
			, title        : G.playlist ? 'Track Info' : 'Tag Editor'
			, width        : 500
			, message      : message
			, messagealign : 'left'
			, footer       : footer
			, footeralign  : 'left'
			, textlabel    : label
			, boxwidth     : 'max'
			, values       : values
			, checkchanged : 1
			, beforeshow   : () => {
				$( '#infoContent .infomessage' ).addClass( 'tagmessage' );
				$( '#infoContent .infofooter' ).addClass( 'tagfooter' );
				$( '#infoContent td i' ).css( 'cursor', 'pointer' );
				if ( G.playlist ) $( '#infoContent input' ).prop( 'disabled', 1 );
				var tableW = $( '#infoContent table' ).width();
				$( '#infoContent' ).on( 'click', '#taglabel', function() {
					if ( $( '.taglabel' ).hasClass( 'hide' ) ) {
						$( '.taglabel' ).removeClass( 'hide' );
						$( '#infoContent table' ).width( tableW );
					} else {
						$( '.taglabel' ).addClass( 'hide' );
					}
				} ).on( 'click', 'table i', function() {
					var $this  = $( this );
					var mode   = $this.data( 'mode' );
					if ( [ 'title', 'track' ].includes( mode ) ) return
					
					var string = $this.parent().next().find( 'input' ).val();
					if ( ! string ) return
					
					var query  = {
						  query  : 'find'
						, mode   : mode
						, string : string
						, format : [ 'album', 'artist' ]
					}
					list( query, function( html ) {
						var data = {
							  html      : html
							, modetitle : string
							, path      : string
						}
						G.mode = mode;
						renderLibraryList( data );
						query.gmode = mode;
						query.modetitle = string;
						tagModeSwitch();
						G.query.push( query );
					} );
				} );
				$( '.infomessage' ).click( function() {
					if ( G.library ) return
					
					var query = {
						  query  : 'ls'
						, string : file
						, format : [ 'file' ]
					}
					if ( cue ) file = dirName( file );
					list( query, function( html ) {
						var data = {
							  html      : html
							, modetitle : file
							, path      : file
						}
						G.mode = file.split( '/' )[ 0 ].toLowerCase();
						tagModeSwitch();
						renderLibraryList( data );
					} );
				} );
			}
			, okno         : G.playlist
			, ok           : G.playlist ? '' : () => {
				var tag       = [ 'cmd-tageditor.sh', file, G.list.licover, cue ];
				var newvalues = infoVal();
				var val;
				newvalues.forEach( ( v, i ) => {
					val = ( v === values[ i ] ) ? '' : ( v || -1 );
					tag.push( val );
				} );
				banner( 'tag blink', 'Tag Editor', 'Change tags ...', -1 );
				setTimeout( () => banner( 'tag blink', 'Tag Editor', 'Update Library ...' ), 3000 );
				$.post( 'cmd.php', { cmd: 'sh', sh: tag } );
				if ( G.list.licover ) {
					var tags = [ 'album', 'albumartist', 'artist', 'composer', 'conductor', 'genre', 'date' ];
					for ( i = 0; i < 7; i++ ) {
						var v = newvalues[ i ];
						if ( v !== '*' ) $( '.li'+ tags[ i ] ).text( v );
					}
				} else {
					G.list.li.find( '.li1' ).text( newvalues[ 7 ] );
					G.list.li.find( '.track' ).text( newvalues[ 8 ] );
				}
			}
		} );
	}, 'json' );
}
function tagModeSwitch() {
	$( '#infoX' ).click();
	if ( G.playlist ) {
		$( '#page-playlist' ).addClass( 'hide' );
		$( '#page-library' ).removeClass( 'hide' );
		G.playlist = 0;
		G.library  = 1;
		G.page     = 'library';
	}
}
function webRadioCoverart() {
	if ( G.playback ) {
		var coverart  = G.status.stationcover || G.coverdefault;
		var type      = G.status.icon === 'dabradio' ? 'dabradio' : 'webradio';
		var url       = G.status.file;
		var name      = G.status.station;
	} else {
		var coverart  = G.coverdefault;
		var src       = G.list.li.find( '.lib-icon' ).attr( 'src' );
		var type      = G.mode;
		var pathsplit = G.list.li.find( '.lipath' ).text().split( '//' );
		var url       = pathsplit[ 0 ].replace( /.*\//, '' ) +'//'+ pathsplit[ 1 ];
		var name      =  G.list.name;
	}
	var imagefilenoext = '/srv/http/data/'+ type +'/img/'+ url.replace( /\//g, '|' );
	$( '#coverart' ).removeAttr( 'style' );
	$( '.coveredit' ).remove();
	info( {
		  icon        : iconcover
		, title       : ( type === 'webradio' ? 'Web' : 'DAB' ) +' Radio Cover Art'
		, message     : '<img class="imgold" src="'+ coverart +'" >'
					  + '<p class="infoimgname">'+ name +'</p>'
		, filelabel   : '<i class="fa fa-folder-open"></i>File'
		, fileoklabel : '<i class="fa fa-flash"></i>Replace'
		, filetype    : 'image/*'
		, beforeshow  : () => {
			$( '.extrabtn' ).toggleClass( 'hide', coverart === G.coverdefault );
			if ( src ) {
				bash( [ 'coverartget', imagefilenoext, 'radio' ], coverart => {
					if ( coverart ) {
						$( '#infoContent .imgold' ).attr( 'src', coverart );
						$( '.extrabtn' ).removeClass( 'hide' );
					}
				} );
			}
		}
		, buttonlabel : '<i class="fa fa-'+ type +'"></i>Default'
		, buttoncolor : orange
		, button      : () => bash( [ 'webradiocoverreset', imagefilenoext, type ] )
		, ok          : () => imageReplace( type, imagefilenoext )
	} );
}
function webRadioDelete() {
	var name = G.list.name;
	var img  = G.list.li.find( 'img' ).attr( 'src' ) || G.coverdefault;
	var url  = G.list.li.find( '.li2' ).text();
	info( {
		  icon    : G.mode
		, title   : 'Delete '+ ( G.mode === 'webradio' ? 'Web Radio' : 'DAB Radio' )
		, width   : 500
		, message : '<br><img src="'+ img +'">'
				   +'<br><wh>'+ name +'</wh>'
				   +'<br>'+ url
		, oklabel : '<i class="fa fa-minus-circle"></i>Delete'
		, okcolor : red
		, ok      : () => {
			G.list.li.remove();
			var dir = $( '#lib-path .lipath' ).text();
			bash( ['webradiodelete', dir, url, G.mode ] );
		}
	} );
}
var htmlwebradio = `\
<table>
<tr><td>Name</td><td colspan="2"><input type="text"></td></tr>
<tr><td>URL</td><td colspan="2"><input type="text"></td></tr>
<tr><td>Charset</td><td><input type="text">
	&nbsp;<a href="https://en.wikipedia.org/wiki/Character_encoding#Common_character_encodings" target="_blank"><i class="fa fa-help fa-lg gr"></i></a></td>
	<td style="width: 50%; text-align: right">
		<a id="addwebradiodir" style="cursor: pointer"><i class="fa fa-folder-plus" style="vertical-align: 0"></i>&ensp;New folder&ensp;</a>
	</td>
</tr>
</table>
`;
function webRadioEdit() {
	var name      = G.list.name;
	var img       = G.list.li.find( 'img' ).attr( 'src' ) || G.coverdefault;
	var pathsplit = G.list.path.split( '//' );
	var url       = pathsplit[ 0 ].replace( /.*\//, '' ) +'//'+ pathsplit[ 1 ];
	var charset   = G.list.li.data( 'charset' );
	info( {
		  icon         : 'webradio'
		, title        : 'Edit Web Radio'
		, content      : htmlwebradio
		, values       : [ name, url, charset || 'UTF-8' ]
		, checkchanged : 1
		, checkblank   : [ 0, 1 ]
		, boxwidth     : 'max'
		, beforeshow   : () => {
			$( '#addwebradiodir' ).remove();
			if ( url.includes( 'stream.radioparadise.com' ) || url.includes( 'icecast.radiofrance.fr' ) ) {
				$( '#infoContent' ).find( 'tr:eq( 2 ), tr:eq( 3 )' ).remove();
			}
		}
		, oklabel      : '<i class="fa fa-save"></i>Save'
		, ok           : () => {
			var dir        = $( '#lib-path .lipath' ).text();
			var values     = infoVal();
			var newname    = values[ 0 ];
			var newurl     = values[ 1 ];
			var newcharset = values[ 2 ].replace( /UTF-8|iso *-*/, '' );
			bash( [ 'webradioedit', dir, newname, newurl, newcharset, url ], error => {
				if ( error ) webRadioExists( error, '', newurl );
			} );
		}
	} );
}
function webRadioExists( error, name, url, charset ) {
	info( {
		  icon    : 'webradio'
		, title   : 'Add Web Radio'
		, message : iconwarning + error
					+'<br><br><wh>'+ url +'</wh>'
		, ok      : () => setTimeout( () => name ? webRadioNew( name, url, charset ) : webRadioEdit(), 300 )
	} );
}
function webRadioNew( name, url, charset ) {
	info( {
		  icon         : 'webradio'
		, title        : 'Add Web Radio'
		, boxwidth     : 'max'
		, content      : htmlwebradio
		, focus        : 0
		, values       : name ? [ name, url, charset ] : [ '', '', 'UTF-8' ]
		, checkblank   : [ 0, 1 ]
		, beforeshow   : () => {
			if ( $( '#lib-path .lipath' ).text() ) {
				$( '#addwebradiodir' ).remove();
			} else {
				$( '#addwebradiodir' ).click( function() {
					info( {
						  icon       : 'webradio'
						, title      : 'Add New Folder'
						, textlabel  : 'Name'
						, focus      : 0
						, checkblank : 1
						, ok         : () => bash( [ 'wrdirnew', $( '#lib-path .lipath' ).text(), infoVal() ] )
					} );
				} );
			}
		}
		, ok           : () => {
			var values  = infoVal();
			var name    = values[ 0 ];
			var url     = values[ 1 ];
			var charset = values[ 2 ].replace( /UTF-8|iso *-*/, '' );
			var dir     = $( '#lib-path .lipath' ).text();
			bash( [ 'webradioadd', dir, name, url, charset ], error => {
				if ( error ) webRadioExists( error, name, url, charset );
				bannerHide();
			} );
			if ( [ 'm3u', 'pls' ].includes( url.slice( -3 ) ) ) banner( 'webradio blink', 'Web Radio', 'Add ...', -1 );
		}
	} );
}
function webRadioSave( name ) {
	var url = G.list.li.find( '.lipath' ).text();
	info( {
		  icon       : 'webradio'
		, title      : 'Save Web Radio'
		, message    : url
		, textlabel  : 'Name'
		, values     : name || ''
		, focus      : 0
		, checkblank : 1
		, ok         : () => {
			G.local     = 1;
			var newname = infoVal().toString().replace( /\/\s*$/, '' ); // omit trailling / and space
			bash( [ 'webradioadd', '', newname, url ], error => {
				if ( error ) {
					bannerHide();
					info( {
						  icon    : 'webradio'
						, title   : 'Save Web Radio'
						, message : iconwarning + error
									+'<br><br><wh>'+ url +'</wh>'
						, ok      : () => setTimeout( () => webRadioSave( newname ), 300 )
					} );
					return
				}
				
				G.list.li.find( '.liname, .radioname' ).text( newname );
				G.list.li.find( '.li2 .radioname' ).append( ' • ' );
				G.list.li.find( '.savewr' ).remove();
				G.list.li.removeClass( 'notsaved' );
				G.local = 0;
			} );
		}
	} );
}
//----------------------------------------------------------------------------------------------
$( '.contextmenu a, .contextmenu .submenu' ).click( function() {
	var $this = $( this );
	var cmd   = $this.data( 'cmd' );
	menuHide();
	$( 'li.updn' ).removeClass( 'updn' );
	// playback //////////////////////////////////////////////////////////////
	if ( [ 'play', 'pause', 'stop' ].includes( cmd ) ) {
		if ( cmd === 'play' ) {
			if ( G.status.player !== 'mpd' ) {
				$( '#stop' ).click();
				G.status.player = 'mpd';
			}
			$( '#pl-list li' ).eq( G.list.li.index() ).click();
		} else {
			$( '#'+ cmd ).click();
		}
		return
	}
	
	switch ( cmd ) {
		case 'current':
			bash( [ 'mpcsetcurrent', G.list.index + 1 ] );
			return
		case 'directory':
			if ( G.mode === 'latest' ) {
				var path      = dirName( G.list.path );
				var query     = {
					  query  : 'ls'
					, string : path
					, format : [ 'file' ]
				}
				var modetitle = path;
				query.gmode   = G.mode;
				list( query, function( data ) {
					G.mode         = path.split( '/' )[ 0 ].toLowerCase();
					G.gmode        = 'latest';
					data.path      = path;
					data.modetitle = modetitle;
					renderLibraryList( data );
				}, 'json' );
				query.path      = path;
				query.modetitle = modetitle;
				G.query.push( query );
			} else {
				$( '#lib-list .liinfopath' ).click();
			}
			return
		case 'exclude':
			info( {
				  icon    : 'folder-forbid'
				, title   : 'Exclude Directory'
				, message : 'Exclude from Library:'
							+'<br><i class="fa fa-folder"></i>&ensp;<wh>'+ G.list.path +'</wh>'
				, ok      : () => {
					bash( [ 'ignoredir', G.list.path ], () => G.list.li.remove() );
					var dir = G.list.path.split( '/' ).pop();
				}
			} );
			return
		case 'remove':
			G.contextmenu = 1;
			setTimeout( () => G.contextmenu = 0, 500 );
			playlistRemove( G.list.li );
			return
		case 'savedpladd':
			if ( G.playlist ) {
				var album = G.list.li.find( '.album' ).text();
				var file  = G.list.path;
			} else {
				var album = $( '.licover .lialbum' ).text();
				var file  = G.list.li.find( '.lipath' ).text();
			}
			saveToPlaylist( G.list.name, album, file );
			return
		case 'savedplremove':
			local();
			var plname = $( '#pl-path .lipath' ).text();
			bash( [ 'savedpledit', plname, 'remove', G.list.li.index() + 1 ] );
			G.list.li.remove();
			return
		case 'similar':
			if ( G.display.plsimilar ) {
				info( {
					  icon    : 'lastfm'
					, title   : 'Add Similar'
					, message : 'Search and add similar tracks from Library?'
					, ok      : addSimilar
				} );
			} else {
				addSimilar();
			}
			return
		case 'tag':
			tagEditor();
			return
		case 'thumb':
			info( {
				  icon    : iconcover
				, title   : 'Album Thumbnails'
				, message : 'Update album thumbnails in:'
							+'<br><i class="fa fa-folder"></i> <wh>'+ G.list.path +'</wh>'
				, ok      : () => thumbUpdate( G.list.path )
			} );
			return
		case 'update':
			if ( G.list.path.slice( -3 ) === 'cue' ) G.list.path = dirName( G.list.path );
			infoUpdate( G.list.path );
			return
		case 'wrdirdelete':
			var path = G.list.li.find( '.lipath' ).text();
			info( {
				  icon    : G.mode
				, title   : 'Delete Folder'
				, message : 'Folder:'
							+'<br><wh>'+ path +'</wh>'
				, oklabel : '<i class="fa fa-minus-circle"></i>Delete'
				, okcolor : red
				, ok      : () => {
					bash( [ 'wrdirdelete', path, G.mode ], std => {
						if ( std == -1 ) {
							info( {
								  icon    : 'webradio'
								, title   : 'Web Radio Delete'
								, message : 'Folder not empty:'
											+'<br><wh>'+ path +'</wh>'
											+'<br>Confirm delete?'
								, oklabel : '<i class="fa fa-minus-circle"></i>Delete'
								, okcolor : red
								, ok      : () => bash( [ 'wrdirdelete', path, G.mode, 'noconfirm' ] )
							} );
						}
					} );
				}
			} );
			return
		case 'wrdirrename':
			var path = G.list.li.find( '.lipath' ).text().split( '/' );
			var name = path.pop();
			var path = path.join( '/' );
			info( {
				  icon        : G.mode
				, title       : 'Rename Folder'
				, textlabel   : 'Name'
				, focus       : 0
				, values      : name
				, checkblank  : 1
				, checkchange : 1
				, oklabel     : 'Rename'
				, ok          : () => bash( [ 'wrdirrename', path, name, infoVal(), G.mode ] )
			} );
			return
		case 'wrsave':
			webRadioSave();
			return
	}
	
	// functions with dialogue box ////////////////////////////////////////////
	var contextFunction = {
		  bookmark   : bookmarkNew
		, plrename   : playlistRename
		, pldelete   : playlistDelete
		, wrcoverart : webRadioCoverart
		, wrdelete   : webRadioDelete
		, wredit     : webRadioEdit
	}
	if ( cmd in contextFunction ) {
		contextFunction[ cmd ]();
		return
	}
	
	// replaceplay|replace|addplay|add //////////////////////////////////////////
	var path = G.list.path;
	if ( G.mode.slice( -5 ) === 'radio' ) {
		var pathsplit = path.split( '//' );
		path = pathsplit[ 0 ].replace( /.*\//, '' ) +'//'+ pathsplit[ 1 ];
	}
	var mpccmd;
	// must keep order otherwise replaceplay -> play, addplay -> play
	var mode = cmd.replace( /replaceplay|replace|addplay|add/, '' );
	switch ( mode ) {
		case '':
			if ( G.list.singletrack || G.mode.slice( -5 ) === 'radio' ) { // single track
				mpccmd = [ 'mpcadd', path ];
			} else if ( $( '.licover' ).length && ! $( '.licover .lipath' ).length ) {
				mpccmd = [ 'mpcfindadd', 'multi', G.mode, path, 'album', G.list.album ];
			} else { // directory or album
				mpccmd = [ 'mpcls', path ];
			}
			break;
		case 'pl':
			cmd = cmd.slice( 2 );
			if ( G.library ) {
				mpccmd = [ 'mpcload', path ];
			} else { // saved playlist
				var play = cmd.slice( -1 ) === 'y' ? 1 : 0;
				var replace = cmd.slice( 0, 1 ) === 'r' ? 1 : 0;
				if ( replace && G.display.plclear && G.status.pllength ) {
					infoReplace( () => playlistLoad( path, play, replace ) );
				} else {
					playlistLoad( path, play, replace );
				}
				return
			}
			break;
		case 'playnext':
			mpccmd = [ 'mpcaddplaynext', path ];
			break
		case 'wr':
			cmd = cmd.slice( 2 );
			var charset = G.list.li.data( 'charset' );
			if ( charset ) path += '#charset='+ charset
			mpccmd = [ 'mpcadd', path ];
			break;
		default:
			if ( ! G.list.name ) {
				mpccmd = [ 'mpcfindadd', mode, path ];
				if ( G.list.artist ) mpccmd.push( 'artist', G.list.artist );
			} else {
				mpccmd = [ 'mpcfindadd', 'multi', G.mode, $( '#mode-title' ).text(), 'album', G.list.name ];
			}
	}
	if ( ! mpccmd ) mpccmd = [];
	var sleep = G.mode.slice( -5 ) === 'radio' ? 1 : 0.2;
	if ( G.status.state === 'play' && G.status.webradio ) sleep += 1;
	var contextCommand = {
		  add         : mpccmd
		, playnext    : mpccmd
		, addplay     : mpccmd.concat( [ 'addplay', sleep ] )
		, replace     : mpccmd.concat(  'replace' )
		, replaceplay : mpccmd.concat( [ 'replaceplay', sleep ] )
	}
	cmd         = cmd.replace( /album|artist|composer|conductor|date|genre/g, '' );
	var command = contextCommand[ cmd ];
	if ( cmd === 'add' ) {
		var title = 'Add to Playlist';
	} else if ( cmd === 'addplay' ) {
		var title = 'Add to Playlist and play';
	} else if ( cmd === 'playnext' ) {
		var title = 'Add to Playlist to play next';
	} else {
		var title = 'Replace Playlist'+ ( cmd === 'replace' ? '' : ' and play' );
	}
	if ( G.list.li.hasClass( 'licover' ) ) {
		var msg = G.list.li.find( '.lialbum' ).text()
				+'<a class="li2">'+ G.list.li.find( '.liartist' ).text() +'</a>';
	} else if ( G.list.li.find( '.li1' ).length ) {
		var msg = G.list.li.find( '.li1' )[ 0 ].outerHTML
				+ G.list.li.find( '.li2' )[ 0 ].outerHTML;
		msg     = msg.replace( '<bl>', '' ).replace( '</bl>', '' );
	} else {
		var msg = G.list.li.find( '.lipath' ).text() || G.list.li.find( '.liname' ).text();
	}
	if ( G.display.plclear && ( cmd === 'replace' || cmd === 'replaceplay' ) ) {
		infoReplace( () => addReplace( cmd, command, title, msg ) );
	} else {
		addReplace( cmd, command, title, msg );
	}
} );
