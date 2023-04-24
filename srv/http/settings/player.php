<div id="divmpd" class="section">
<?php
$id_name = [
	  'audiooutput'   => 'Device'
	, 'autoupdate'    => [ 'name' => 'Library Auto Update',   'sub' => 'auto_update' ]
	, 'btreceiver'    => [ 'name' => 'Bluetooth',             'sub' => 'bluetoothctl' ]
	, 'buffer'        => [ 'name' => 'Buffer - Audio',        'sub' => 'audio_buffer' ]
	, 'crossfade'     => [ 'name' => 'Cross-Fading',          'sub' => 'crossfade' ]
	, 'custom'        => [ 'name' => "User's Configurations", 'sub' => 'custom' ]
	, 'dop'           => 'DSD over PCM'
	, 'ffmpeg'        => [ 'name' => 'FFmpeg',                'sub' => 'decoder' ]
	, 'hwmixer'       => 'Mixer Device'
	, 'mixertype'     => 'Volume Control'
	, 'normalization' => [ 'name' => 'Normalization',         'sub' => 'volume_normalization' ]
	, 'novolume'      => 'No Volume'
	, 'outputbuffer'  => [ 'name' => 'Buffer - Output',       'sub' => 'max_output_buffer' ]
	, 'replaygain'    => [ 'name' => 'ReplayGain',            'sub' => 'replaygain' ]
	, 'soxr'          => [ 'name' => 'SoX Resampler',         'sub' => 'resampler' ]
];
htmlHead( [ //////////////////////////////////
	  'title'  => '<a class="hideN">Music Player Daemon</a><a class="hideW">MPD</a>'
	, 'id'     => 'mpd'
	, 'status' => true
	, 'button' => [ 'playback' => 'play' ]
	, 'help'   => <<< EOF
{$Fi( 'play btn' )} {$Fi( 'pause btn' )} {$Fi( 'stop btn' )} Playback control
EOF
] );
?>
	<div class="col-l text gr">
		Version
		<br>Database
	</div>
	<div class="col-r text">
		<div id="statusvalue"></div>
	</div>
	<div style="clear:both"></div>
	<div class="helpblock hide">
<a href="https://www.musicpd.org/">MPD</a> - Music Player Daemon is a flexible, powerful, server-side application for playing music.
Through plugins and libraries it can play a variety of sound files while being controlled by its network protocol.
</div>
</div>
<?php
// ----------------------------------------------------------------------------------
$head = [ //////////////////////////////////
	  'title'  => 'Output'
	, 'id'     => 'output'
	, 'status' => true
	, 'button' => [ 'btoutputall' => 'gear' ]
	, 'help'   => <<< EOF
{$Fi( 'gear btn' )} Other outputs while Bluetooth connected
 · Should be disabled if not used simultaneously
EOF
];
$body = [
[
		  'id'          => 'btreceiver'
		, 'status'      => true
		, 'input'       => '<select id="btaplayname"></select>'
		, 'setting'     => 'custom'
		, 'settingicon' => 'volume'
		, 'help'        => <<< EOF
{$Fi( 'volume btn' )} Sender volume control
 · Should be set at 0dB and use Bluetooth buttons to control volume
EOF
	]
	, [
		  'id'      => 'audiooutput'
		, 'input'   => '<select id="audiooutput"></select>'
		, 'setting' => 'none'
		, 'help'    => <<< EOF
HDMI audio:
 · Available when connected before boot only
 · Enable plug and play: {$Ftab( 'mpd', 'Player' )}{$FlabelIcon( 'HDMI Hotplug', 'hdmi' )}
EOF
	]
	, [
		  'id'          => 'hwmixer'
		, 'input'       => '<select id="hwmixer"></select>'
		, 'setting'     => 'custom'
		, 'settingicon' => 'volume'
		, 'help'        => <<< EOF
{$Fi( 'volume btn' )}
Mixer device volume control
EOF
	]
	, [
		  'id'      => 'mixertype'
		, 'input'   => '<select id="mixertype"></select>'
		, 'setting' => 'none'
		, 'help'    => <<< EOF
Volume control for each device.
The later in the signal chain the better sound quality.
<pre>
<code>None / 0dB   </code> Best  Amplifier volume - GUI knob hidden
<code>Mixer device </code> Good  DAC hardware via GUI knob
<code>MPD software </code> Basic GUI knob
</pre>Note: <code>None / 0dB</code> Not for devices which still need volume control, e.g., DACs with on-board amplifier
EOF
	]
];
htmlSection( $head, $body, 'output' );
$head = [ 'title' => 'Bit-Perfect' ]; //////////////////////////////////
$body = [
	[
		  'id'      => 'novolume'
		, 'setting' => 'none'
		, 'help'    => <<< EOF
Disable all manipulations for bit-perfect stream from MPD to DAC output.
 · No changes in data stream until it reaches amplifier volume control.
 · Mixer device volume: <code>0dB</code>
 · Volume Control: <code>None / 0db</code>
 · Disable options: Cross-fading, Normalization, ReplayGain and SoX Resampler
 · Disable Signal Processors

Note: Not for DACs with on-board amplifier.
EOF
	]
	, [
		  'id'      => 'dop'
		, 'setting' => 'none'
		, 'help'    => <<< EOF
<wh>D</wh>SD <wh>o</wh>ver <wh>P</wh>CM for DSD-capable devices that not support native DSD
 · DoP repacks 16bit DSD stream into 24bit PCM frames. 
 · PCM frames transmitted to DAC and reassembled back to original DSD stream.
 · DoP is bit-perfect by itself. (with expense of double bandwith)
 · Enabled:
	· if DAC not support native DSD.
	· If there's static/no sound of DSD.
 · Disabled without native DSD support
	· DSD converted to PCM stream. (no bit-perfect)
EOF
	]
];
htmlSection( $head, $body, 'bitperfect' );
$head = [ 'title' => 'Volume' ]; //////////////////////////////////
$body = [
	[	  'id'       => 'crossfade'
		, 'help'     => <<< EOF
Fade-out to fade-in between playing tracks (same audio format only)
EOF
	]
	, [
		  'id'       => 'normalization'
		, 'setting'  => false
		, 'help'     => <<< EOF
Normalize the volume level of songs as they play. (16 bit PCM only)
EOF
	] 
	, [
		  'id'       => 'replaygain'
		, 'help'     => <<< EOF
<a href="https://en.wikipedia.org/wiki/ReplayGain">ReplayGain</a> - Normalize perceived loudness via ID3v2 ReplayGain tag
Support: FLAC, Ogg Vorbis, Musepack and MP3

{$Fi( 'gear btn' )}
■ Gain control - Mixer device:
 • <code>replay_gain_handler "mixer"</code>
 • Available when Volume Control = MPD software
EOF
	]
];
htmlSection( $head, $body, 'volume' );
// ----------------------------------------------------------------------------------

$head = [ 'title' => 'Options' ]; //////////////////////////////////
$body = [
	[
		  'id'       => 'buffer'
		, 'help'     => <<< EOF
Increase to fix intermittent audio.

(default: <code>4096</code> kB - 24s of CD-quality audio)
EOF
	]
	, [
		  'id'       => 'outputbuffer'
		, 'help'     => <<< EOF
Increase to fix missing Album list with large Library.

(default: <code>8192</code> kB)
EOF
	]
	, [
		  'id'       => 'ffmpeg'
		, 'setting'  => false
		, 'disabled' => labelIcon( 'DAB Radio', 'dabradio' ).' is currently enabled.'
		, 'help'     => <<< EOF
<a href="https://ffmpeg.org/about.html">FFmpeg</a> - Decoder for more audio filetypes {$Fi( 'help filetype' )}
<pre id="prefiletype" class="hide"></pre>
Note: Should be disabled for faster Library update if not used.
EOF
	]
	, [
		  'id'       => 'autoupdate'
		, 'setting'  => false
		, 'help'     => 'Automatic update MPD database when files changed.'
	]
	, [
		 'id'       => 'soxr'
		, 'help'     => <<< EOF
<a href="https://sourceforge.net/p/soxr/wiki/Home/">SoX Resampler library</a> - One-dimensional sample-rate conversion
{$Fi( 'gear btn' )}
 • Presets:
	(default: Quality <code>Very high</code>  Threads <code>Single</code>)
	
 • Custom quality:
	· Precision - Conversion precision (20 = HQ)
	· Phase Response (50 = Linear)
	· Passband End - 0dB point bandwidth to preserve (100 = Nyquist)
	· Stopband Begin - Aliasing/imaging control
	· Attenuation - Lowers the source to prevent clipping
	· Flags / Extra settings:
<pre>
<code> 0 - Rolloff - small </code> (<= 0.01 dB)
<code> 1 - Rolloff - medium</code> (<= 0.35 dB)
<code> 2 - Rolloff - none  </code> For Chebyshev bandwidth
<code> 8 - High precision  </code> Increase irrational ratio accuracy
<code>16 - Double precision</code> even if Precision <= 20
<code>32 - Variable rate   </code>
</pre>
EOF
	]
	, [
		  'id'       => 'custom'
		, 'help'     => 'Insert custom configurations into <c>mpd.conf</c>.'
	]
];
htmlSection( $head, $body, 'options' );

echo '
<div id="divlists" class="section">
	<heading><span class="headtitle">Lists</span></heading>';
htmlHead( [
	  'title'   => 'Ignored Album'
	, 'id'      => 'albumignore'
	, 'subhead' => true
	, 'status'  => true
	, 'help'    => <<< EOF
List of albums excluded from Album page.
To restore:
 · Edit <c>/srv/http/data/mpd/albumignore</c>
 · Remove albums to restore
 · Update Library
EOF
] );
htmlHead( [
	  'title'   => 'Ignored Directory'
	, 'id'      => 'mpdignore'
	, 'subhead' => true
	, 'status'  => true
	, 'help'    => <<< EOF
List of <c>.mpdignore</c> files contain directories excluded from database.
To restore:
• Edit <c>.../.mpdignore</c>
• Remove directories to restore
• Update Library
EOF
] );
htmlHead( [
	  'title'   => 'Non UTF-8 Files'
	, 'id'      => 'nonutf8'
	, 'subhead' => true
	, 'status'  => true
	, 'help'    => 'List of files with metadata is not UTF-8 encoding which must be corrected.'
] );
echo '
</div>';
