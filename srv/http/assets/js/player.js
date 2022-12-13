$( function() { // document ready start >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

var warning = `
<wh>${ iconwarning }Lower amplifier volume.</wh>

Signal will be set to original level at 0dB.
Beware of too high volume from speakers.

(Not for DACs with on-board amplifier)`;

$( '.playback' ).click( function() {
	if ( ! $( this ).hasClass( 'disabled' ) ) {
		var cmd = G.player === 'mpd' ? 'mpcplayback' : 'playerstop';
		bash( '/srv/http/bash/cmd.sh '+ cmd );
	}
} );
$( '#setting-btreceiver' ).click( function() {
	bash( [ 'volumegetbt' ], voldb => {
		var voldb = voldb.split( ' ' );
		var vol   = voldb[ 0 ];
		var db    = voldb[ 1 ];
		info( {
			  icon          : 'volume'
			, title         : 'Bluetooth Volume'
			, message       : G.btaplayname.replace( / - A2DP$/, '' )
			, rangevalue    : vol
			, footer        : db +' dB'
			, beforeshow    : () => {
				$( '#infoButtons' ).toggleClass( 'hide', db === '0.00' );
				$( '#infoRange input' ).on( 'click input', function() {
					bash( 'amixer -MD bluealsa -q sset "'+ G.btaplayname +'" '+ $( this ).val() +'%' );
				} ).on( 'touchend mouseup keyup', function() {
					bash( [ 'volumepushbt' ] );
				} );
			}
			, buttonnoreset : 1
			, buttonlabel   : '<i class="fa fa-set0"></i>0dB'
			, button        : () => bash( [ 'volume0dbbt' ] )
			, okno          : 1
		} );
	} );
} );
$( '#audiooutput' ).change( function() {
	notify( 'mpd', 'Audio Output Device', 'Change ...' );
	bash( [ 'audiooutput', $( this ).val() ] );
} );
$( '#hwmixer' ).change( function() {
	notify( 'mpd', 'Hardware Mixer', 'Change ...' );
	bash( [ 'hwmixer', D.aplayname, $( this ).val() ] );
} );
$( '#setting-hwmixer' ).click( function() {
	bash( [ 'volumeget' ], voldb => {
		var voldb    = voldb.split( ' ' );
		var vol      = voldb[ 0 ];
		var db       = voldb[ 1 ];
		var nodb     = typeof db === 'undefined';
		var json0 = {
			  icon       : 'volume'
			, title      : 'Mixer Device Volume'
			, message    : D.hwmixer
			, rangevalue : vol
		}
		if ( D.mixertype === 'none' ) {
			var json1 = {
				  footer     : '0dB (No Volume)'
				, beforeshow : () => $( '#infoRange input' ).prop( 'disabled', 1 )
				, okno       : 1
			}
		} else if ( nodb ) {
			var json1 = {
				  beforeshow : setVolumeSlider
				, okno       : 1
			}
		} else {
			var toggle = () => $( '#infoContent, .warning, #infoButtons a' ).toggleClass( 'hide' )
			var json1 = {
				  footer        : db +' dB'
				, beforeshow    : () => {
					$( '#infoContent' ).after( '<div class="infomessage warning hide">'+ warning +'</div>' );
					$( '.extrabtn' ).toggleClass( 'hide', db === '0.00' );
					$( '.extrabtn:eq( 0 ), #infoOk' ).addClass( 'hide' );
					setVolumeSlider();
				}
				, buttonnoreset : 1
				, buttonlabel   : [ 'Back', '<i class="fa fa-set0"></i>0dB' ]
				, buttoncolor   : [ $( '.switchlabel' ).css( 'background-color' ), '' ]
				, button        : [ toggle, toggle ]
				, oklabel       : 'OK'
				, ok            : () => {
					bash( [ 'volume0db' ] );
					toggle();
				}
			}
		}
		info( { ... json0, ... json1 } );
	} );
} );
$( '#mixertype' ).change( function() {
	var mixertype = $( this ).val();
	if ( mixertype === 'none' ) {
		info( {
			  icon    : 'volume'
			, title   : 'Volume Control'
			, message : warning
			, cancel  : () => $( '#mixertype' ).val( D.mixertype )
			, ok      : () => setMixerType( mixertype )
		} );
	} else {
		setMixerType( mixertype );
	}
} );
$( '#novolume' ).click( function() {
	var checked = $( this ).prop( 'checked' );
	var icon    = 'volume';
	var title   = 'No Volume';
	if ( checked ) {
		info( {
			  icon    : icon
			, title   : title
			, message : warning
			, cancel  : () => cancelSwitch( 'novolume' )
			, ok      : () => {
				notify( icon, title, 'Enable ...' );
				bash( [ 'novolume', D.aplayname, D.card, D.hwmixer ] );
			}
		} );
	} else {
		info( {
			  icon         : icon
			, title        : title
			, message      : `\
<wh>No volume</wh> will be disabled on:
&emsp; • Select a Mixer Control
&emsp; • Enable any Volume options`
			, messagealign : 'left'
		} );
		$( this ).prop( 'checked', 1 );
	}
} );
$( '#dop' ).click( function() {
	var checked = $( this ).prop( 'checked' );
	notify( 'mpd', 'DSP over PCM', checked );
	bash( [ 'dop', checked, D.aplayname ] );
} );
$( '#setting-crossfade' ).click( function() {
	var icon  = 'mpd';
	var title = 'Cross-Fading';
	info( {
		  icon         : icon
		, title        : title
		, textlabel    : 'Seconds'
		, focus        : 0
		, boxwidth     : 60
		, values       : G.crossfadeconf || 1
		, checkchanged : G.crossfade
		, checkblank   : 1
		, cancel       : () => cancelSwitch( 'crossfade' )
		, ok           : () => {
			bash( [ 'crossfade', true, infoVal() ] );
			notify( icon, title, G.crossfade ? 'Change ...' : 'Enable ...' );
		}
	} );
} );
$( '#setting-replaygain' ).click( function() {
	var icon  = 'mpd';
	var title = 'ReplayGain';
	info( {
		  icon         : icon
		, title        : title
		, radio        : { Auto: 'auto', Album: 'album', Track: 'track' }
		, values       : G.replaygainconf
		, checkchanged : G.replaygain
		, cancel       : () => cancelSwitch( 'replaygain' )
		, ok           : () => {
			bash( [ 'replaygain', true, infoVal() ] );
			notify( icon, title, G.replaygain ? 'Change ...' : 'Enable ...' );
		}
	} );
} );
$( '.filetype' ).click( function() {
	if ( $( '#divfiletype' ).is( ':empty' ) ) {
		bash( [ 'filetype' ], data => {
			$( '#divfiletype' )
				.html( data )
				.toggleClass( 'hide' );
		} );
	} else {
		$( '#divfiletype' ).toggleClass( 'hide' );
	}
} );
$( '#setting-buffer' ).click( function() {
	var icon  = 'mpd';
	var title = 'Custom Audio Buffer';
	info( {
		  icon         : icon
		, title        : title
		, textlabel    : 'audio_buffer_size <gr>(kB)</gr>'
		, focus        : 0
		, footer       : '(default: 4096)'
		, footeralign  : 'right'
		, boxwidth     : 110
		, values       : G.bufferconf
		, checkchanged : G.buffer
		, checkblank   : 1
		, cancel       : () => cancelSwitch( 'buffer' )
		, ok           : () => {
			bash( [ 'buffer', true, infoVal() ] );
			notify( icon, title, G.buffer ? 'Change ...' : 'Enable ...' );
		}
	} );
} );
$( '#setting-outputbuffer' ).click( function() {
	var icon  = 'mpd';
	var title = 'Custom Output Buffer';
	info( {
		  icon         : icon
		, title        : title
		, textlabel    : 'max_output_buffer_size <gr>(kB)</gr>'
		, focus        : 0
		, footer       : '(default: 8192)'
		, footeralign  : 'right'
		, boxwidth     : 110
		, values       : G.outputbufferconf
		, checkchanged : G.outputbuffer
		, checkblank   : 1
		, cancel       : () => cancelSwitch( 'outputbuffer' )
		, ok           : () => {
			bash( [ 'outputbuffer', true, infoVal() ] );
			notify( icon, title, G.outputbuffer ? 'Change ...' : 'Enable ...' );
		}
	} );
} );
$( '#setting-soxr' ).click( function() {
	infoSoxr( G.soxrquality || 'very high' );
} );
var custominfo = `\
<table width="100%">
<tr><td><code>mpd.conf</code></td></tr>
<tr><td><pre>
...
user                   "mpd"</pre></td></tr>
	<tr><td><textarea></textarea></td></tr>
	<tr><td><pre>
...
audio_output {
	...
	mixer_device   "hw:N"</pre></td></tr>
<tr><td><textarea style="padding-left: 39px"></textarea></td></tr>
<tr><td><pre style="margin-top: -20px">
}</pre></td></tr>
</table>`;
$( '#setting-custom' ).click( function() {
	bash( [ 'customget', D.aplayname ], val => {
		var val       = val.split( '^^' );
		var valglobal = val[ 0 ].trim(); // remove trailing
		var valoutput = val[ 1 ].trim();
		var icon      = 'mpd';
		var title     = "User's Configurations";
		info( {
			  icon         : icon
			, title        : title
			, content      : custominfo.replace( 'N', G.asoundcard )
			, values       : [ valglobal, valoutput ]
			, checkchanged : G.custom
			, cancel       : () => cancelSwitch( 'custom' )
			, ok           : () => {
				var values = infoVal();
				if ( ! values[ 0 ] && ! values[ 1 ] ) {
					bash( [ 'customdisable' ] );
					notify( icon, title, 'Disable ...', 3000 );
					return
				}
				
				bash( [ 'custom', true, values[ 0 ], values[ 1 ], D.aplayname ], mpdstart => {
					if ( ! mpdstart ) {
						bannerHide();
						info( {
							  icon    : icon
							, title   : title
							, message : 'MPD failed with the added lines'
										+'<br>Restored to previous configurations.'
						} );
					}
				}, 'json' );
				notify( icon, title, G.custom ? 'Change ...' : 'Enable ...' );
			}
		} );
	} );
} );

} ); // document ready end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

var soxr       = `\
<table>
<tr><td>Quality</td>
	<td><select>
		<option value="very high">Very high</option>
		<option value="high">High</option>
		<option value="medium">Medium</option>
		<option value="low">Low</option>
		<option value="quick">Quick</option>
	</select></td>
</tr>
<tr><td>Threads</td>
	<td><label><input type="radio" name="soxr" value="0">Auto</label>&emsp;
		<label><input type="radio" name="soxr" value="1">Single</label></td>
</tr>
<table>`;
var soxrcustom = `
<table>
<tr><td>Precision</td>
	<td><select>
		<option value="16">16</option>
		<option value="20">20</option>
		<option value="24">24</option>
		<option value="28">28</option>
		<option value="32">32</option>
		</select></td><td>&nbsp;<gr>bit</gr></td>
</tr>
<tr><td>Phase Response</td>
	<td><input type="text"></td><td style="width: 115px">&nbsp;<gr>0-100</gr></td>
</tr>
<tr><td>Passband End</td>
	<td><input type="text"></td><td>&nbsp;<gr>0-100%</gr></td>
</tr>
<tr><td>Stopband Begin</td>
	<td><input type="text"></td><td>&nbsp;<gr>100-150%</gr></td>
</tr>
<tr><td>Attenuation</td>
	<td><input type="text"></td><td>&nbsp;<gr>0-30dB</gr></td>
</tr>
<tr><td>Bitmask Flag</td>
	<td colspan="2"><select>
			<option value="0">0 - Rolloff - Small</option>
			<option value="1">1 - Rolloff - Medium</option>
			<option value="2">2 - Rolloff - None</option>
			<option value="8">8 - High precision</option>
			<option value="16">16 - Double precision</option>
			<option value="32">32 - Variable rate</option>
		</select>
	</td>
</tr>
</table>`;
function infoSoxr( quality ) {
	var custom = quality === 'custom';
	var icon   = 'mpd';
	var title   = 'SoX Resampler';
	info( {
		  icon         : icon
		, title        : title
		, tab          : [ 'Presets', 'Custom' ]
		, tabfunction  : [ infoSoxrPreset, infoSoxrCustom ]
		, tabactive    : custom ? 1 : 0
		, content      : custom ? soxrcustom : soxr
		, values       : custom ? G.soxrcustomconf : G.soxrconf
		, checkblank   : 1
		, checkchanged : G.soxr && quality === G.soxrquality
		, boxwidth     : custom ? 85 : 180
		, cancel       : () => cancelSwitch( 'soxr' )
		, ok           : () => {
			if ( custom ) {
				bash( [ 'soxr', true, 'custom', ...infoVal() ] );
			} else {
				bash( [ 'soxr', true, ...infoVal() ] );
			}
			notify( icon, title, G.soxr ? 'Change ...' : 'Enable ...' );
		}
	} );
}
function infoSoxrCustom() {
	infoSoxr( 'custom' );
}
function infoSoxrPreset() {
	infoSoxr( G.soxrquality === 'custom' ? 'very high' : G.soxrquality );
}
function playbackIcon() {
	$( '.playback' )
		.removeClass( 'fa-pause fa-play fa-stop' )
		.addClass( 'fa fa-'+ G.state )
		.toggleClass( 'disabled', G.player !== 'mpd' && G.state !== 'play' );
}
function renderPage() {
	playbackIcon();
	var htmlstatus =  G.version +'<br>'
					+'<i class="fa fa-song gr"></i>&ensp;'+ ( G.counts.song || 0 ).toLocaleString() +'&emsp; '
					+'<i class="fa fa-album gr"></i>&ensp;'+ ( G.counts.album || 0 ).toLocaleString() +'<wide>&emsp; '
					+'<i class="fa fa-webradio gr"></i>&ensp;'+ ( G.counts.webradio || 0 ).toLocaleString() +'</wide>';
	$( '#statusvalue' ).html( htmlstatus );
	if ( G.btaplayname ) {
		$( '#divbtreceiver' ).removeClass( 'hide' );
		$( '#btaplayname' ).html( '<option>'+ G.btaplayname.replace( / - A2DP$/, '' ) +'</option>' );
		$( '#setting-btreceiver' ).removeClass( 'hide' );
	} else {
		$( '#divbtreceiver' ).addClass( 'hide' );
	}
	if ( G.asoundcard === -1 ) {
		$( '#divoutput, #divbitperfect, #divvolume' ).addClass( 'hide' );
	} else {
		D               = G.devices[ G.asoundcard ];
		G.resampled     = G.crossfade || G.normalization || G.replaygain || G.camilladsp || G.equalizer || G.soxr;
		G.novolume      = D.mixertype === 'none' && ! G.resampled;
		var htmldevices = '';
		$.each( G.devices, ( i, el ) => {
			if ( el.aplayname !== 'Loopback' ) htmldevices += '<option value="'+ el.card +'">'+ el.name +'</option>';
		} );
		$( '#divoutput, #divbitperfect, #divvolume' ).removeClass( 'hide' );
		$( '#audiooutput' )
			.html( htmldevices )
			.val( G.asoundcard );
		var htmlhwmixer      = D.mixermanual ? '<option value="auto">Auto</option>' : '';
		if ( 'mixerdevices' in D ) {
			D.mixerdevices.forEach( mixer => htmlhwmixer += '<option value="'+ mixer +'">'+ mixer +'</option>' );
		}
		$( '#hwmixer' )
			.html( htmlhwmixer )
			.val( D.hwmixer );
		var htmlmixertype = '<option value="none">None / 0dB</option>';
		if ( D.mixers ) htmlmixertype += '<option value="hardware">Mixer device</option>';
		htmlmixertype    += '<option value="software">MPD software</option>';
		$( '#mixertype' )
			.html( htmlmixertype )
			.val( D.mixertype );
		$( '#setting-hwmixer' ).toggleClass( 'hide', D.mixers === 0 );
		$( '#novolume' ).prop( 'checked', G.novolume );
		$( '#divdop' ).toggleClass( 'disabled', D.aplayname.slice( 0, 7 ) === 'bcm2835' );
		$( '#dop' ).prop( 'checked', G.dop );
		$( '#ffmpeg' ).toggleClass( 'disabled', G.dabradio );
		if ( G.camilladsp ) {
			var label = '<i class="fa fa-camilladsp"></i>';
		} else if ( G.equalizer ) {
			var label = 'Equalizer<i class="fa fa-equalizer"></i>';
		} else {
			var label = 'Device';
		}
		$( '#divaudiooutput div' ).eq( 0 ).html( label );
	}
	if ( $( '#infoRange .value' ).length ) {
		var cmd = I.title === 'Mixer Device Volume' ? [ 'volumeget' ] : [ 'volumegetbt' ];
		bash( cmd, voldb => {
			var voldb = voldb.split( ' ' );
			var vol   = voldb[ 0 ];
			var db    = voldb[ 1 ];
			$( '#infoRange .value' ).text( vol );
			$( '#infoRange input' ).val( vol );
			$( '.infofooter' ).text( db +' dB' );
			$( '#infoButtons a' ).eq( 1 ).toggleClass( 'hide', db === '0.00' );
		} );
	}
	$( '#divlists' ).toggleClass( 'hide', !G.lists.includes( true ) );
	for ( i = 0; i < 3; i++ ) $( '#divlists .sub' ).eq( i ).toggleClass( 'hide', !G.lists[ i ] );
	showContent();
}
function setMixerType( mixertype ) {
	var hwmixer = D.mixers ? D.hwmixer : '';
	notify( 'mpd', 'Mixer Control', 'Change ...' );
	bash( [ 'mixertype', mixertype, D.aplayname, hwmixer ] );
}
function setVolumeSlider() {
	$( '#infoRange input' ).on( 'click input keyup', function() {
		bash( 'amixer -c '+ G.asoundcard +' -Mq sset "'+ D.hwmixer +'" '+ $( this ).val() +'%' );
	} ).on( 'touchend mouseup keyup', function() {
		bash( [ 'volumepush' ] );
	} );
}
