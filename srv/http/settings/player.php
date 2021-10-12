<?php
htmlHead( [ //////////////////////////////////
	  'title'  => 'Music Player Daemon'
	, 'id'     => 'divmpd'
	, 'status' => 'mpd'
] );
?>
<div class="col-l text gr">
	Version
	<br>Database
</div>
<div class="col-r text">
	<div id="statusvalue"></div>
	<div class="help-block hide">
<a href="https://www.musicpd.org/">MPD</a> - Music Player Daemon is a flexible, powerful, server-side application for playing music.
Through plugins and libraries it can play a variety of sound files while being controlled by its network protocol.
</div>
</div>
<div style="clear:both"></div>

<?php
if ( !file_exists( '/srv/http/data/shm/nosound' ) ) {
// ----------------------------------------------------------------------------------
htmlHead( [ //////////////////////////////////
	  'title'  => 'Output'
	, 'status' => 'asound'
] );
htmlSetting( [
	  'label' => 'Device'
	, 'id'    => 'audiooutput'
	, 'input' => '<select id="audiooutput"></select>'
	, 'help'  => <<<html
HDMI device available only when connected before boot.
html
] );
htmlSetting( [
	  'label'       => 'Mixer Device'
	, 'id'          => 'hwmixer'
	, 'input'       => '<select id="hwmixer"></select>'
	, 'setting'     => 'self'
	, 'settingicon' => 'volume'
] );
htmlSetting( [
	  'label' => 'Volume Control'
	, 'id'    => 'mixertype'
	, 'input' => '<select id="mixertype"></select>'
	, 'help'  => <<<html
Volume control for each device.
 &bull; <code>None / 0dB</code> Best sound quality. (Use amplifier volume)
 &bull; <code>Mixer device</code> Good and convenient. (Device hardware volume)
 &bull; <code>MPD software</code> Software volume.
html
] );
$iplus = '<i class="fa fa-plus-circle"></i>';
$isave = '<i class="fa fa-save"></i>';
htmlSetting( [
	  'label'   => 'Equalizer'
	, 'id'      => 'equalizer'
	, 'help'    => <<<html
10 band graphic equalizer with user presets.
Control: &emsp; <i class="fa fa-player"></i>Player |&ensp;<i class="fa fa-equalizer"></i>
Presets:
 &bull; <code>Flat</code>: All bands at <code>0dB</code>
 &bull; New: adjust > <?=$iplus?>> <code>NAME</code> > <?=$isave?>
 &bull; Existing: adjust > <?=$isave?>
 &bull; Adjust without <?=$isave?>will be listed as <code>(unnamed)</code>
 &bull; Save <code>(unnamed)</code>: <?=$iplus?>> <code>NAME</code> > <?=$isave?>
html
] );
htmlHead( [ 'title' => 'Bit-Perfect' ] ); //////////////////////////////////
htmlSetting( [
	  'label' => 'No Volume'
	, 'id'    => 'novolume'
	, 'help'  => <<<html
Disable all manipulations for bit-perfect stream from MPD to DAC output.
 &bull; No changes in data stream until it reaches amplifier volume control.
 &bull; Mixer device volume: 0dB (No amplitude manipulations)
 &bull; Volume Control: <code>None / 0db</code> (Hidden volume in Playback)
 &bull; Equalizer: Disabled
 &bull; Crossfade, Normalization and Replay Gain: Disabled
html
] );
htmlSetting( [
	  'label' => 'DSD over PCM'
	, 'id'    => 'dop'
	, 'help'  => <<<html
For DSD-capable devices without drivers dedicated for native DSD.
 &bull; Enable if there's static/no sound from the DAC which means not support as native DSD.
 &bull; DoP will repack 16bit DSD stream into 24bit PCM frames and transmit to the DAC. 
 &bull; PCM frames will be reassembled back to original DSD stream, COMPLETELY UNCHANGED, with expense of double bandwith.
 &bull; On-board audio and non-DSD devices will always get DSD converted to PCM stream, no bit-perfect
html
] );
// ----------------------------------------------------------------------------------
}
htmlHead( [ 'title' => 'Volume' ] ); //////////////////////////////////
htmlSetting( [
	  'label'   => 'Crossfade'
	, 'id'      => 'crossfade'
	, 'setting' => 'common'
	, 'help'    => <<<html
<code>mpc crossfade N</code>
Fade-out to fade-in between songs.
html
] );
htmlSetting( [
	  'label'   => 'Normalization'
	, 'id'      => 'normalization'
	, 'help'    => <<<html
<code>volume_normalization "yes"</code>
Normalize the volume level of songs as they play.
html
] );
htmlSetting( [
	  'label'   => 'Replay Gain'
	, 'id'      => 'replaygain'
	, 'setting' => 'common'
	, 'help'    => <<<html
<code>replaygain "N"</code>
Set gain control to setting in replaygain tag.
Currently support: FLAC, Ogg Vorbis, Musepack, and MP3 (through ID3v2 ReplayGain tags, not APEv2)
html
] );
htmlHead( [ //////////////////////////////////
	  'title'  => 'Options'
	, 'status' => 'mpdconf'
] );
htmlSetting( [
	  'label'    => 'Buffer - Audio'
	, 'id'       => 'buffer'
	, 'sublabel' => 'custom size'
	, 'setting'  => 'common'
	, 'help'     => <<<html
<code>audio_buffer_size "kB"</code>
Default buffer size: 4096 kB (24 seconds of CD-quality audio)
Increase to fix intermittent audio.
html
] );
htmlSetting( [
	  'label'    => 'Buffer - Output'
	, 'id'       => 'bufferoutput'
	, 'sublabel' => 'custom size'
	, 'setting'  => 'common'
	, 'help'     => <<<html
<code>max_output_buffer_size "kB"</code>
Default buffer size: 8192 kB
Increase to fix missing Album list with large Library.
html
] );
htmlSetting( [
	  'label'    => 'FFmpeg'
	, 'id'       => 'ffmpeg'
	, 'sublabel' => 'decoder plugin'
	, 'help'     => <<<html
<code>enable "yes"</code>
Should be disabled if not used for faster Sources update.
Decoder for audio filetypes:&emsp;<i id="filetype" class="fa fa-question-circle"></i>
<div id="divfiletype" class="hide" style="margin-left: 20px"><?=( shell_exec( '/srv/http/bash/player.sh filetype' ) )?></div>
html
] );
htmlSetting( [
	  'label'   => 'Library Auto Update'
	, 'id'      => 'autoupdate'
	, 'help'    => <<<html
<code>auto_update "yes"</code>
Automatic update MPD database when files changed.
html
] );
htmlSetting( [
	  'label'    => 'SoXR resampler'
	, 'id'       => 'soxr'
	, 'sublabel' => 'custom settings'
	, 'setting'  => 'common'
	, 'help'     => <<<html
<code>quality "custom"</code>
Default quality: very high
SoX Resampler custom settings:
 &bull; Precision - Conversion precision (20 = HQ)
 &bull; Phase Response (50 = Linear)
 &bull; Passband End - 0dB point bandwidth to preserve (100 = Nyquist)
 &bull; Stopband Begin - Aliasing/imaging control
 &bull; Attenuation - Lowers the source to prevent clipping
 &bull; Flags - Extra settings:
 &emsp; 0 - Rolloff - small (<= 0.01 dB)
 &emsp; 1 - Rolloff - medium (<= 0.35 dB)
 &emsp; 2 - Rolloff - none - For Chebyshev bandwidth
 &emsp; 8 - High precision - Increase irrational ratio accuracy
 &emsp; 16 - Double precision - even if Precision <= 20
 &emsp; 32 - Variable rate resampling
html
] );
htmlSetting( [
	  'label'   => "User's Configurations"
	, 'id'      => 'custom'
	, 'setting' => 'common'
	, 'help'    => <<<html
Insert custom configurations into <code>/etc/mpd.conf</code>.
html
] );
htmlHead( [ 'title' => 'Excluded Lists' ] ); //////////////////////////////////
htmlHead( [
	  'title'   => 'Album'
	, 'status'  => 'albumignore'
	, 'subhead' => true
	, 'help'    => <<<html
List of albums excluded from Album page.
To restore:
 &bull; Edit <code>/srv/http/data/mpd/albumignore</code>
 &bull; Remove albums to restore
 &bull; Update Library
html
] );
htmlHead( [
	  'title'   => 'Directory'
	, 'status'  => 'mpdignore'
	, 'subhead' => true
	, 'help'    => <<<html
List of <code>.mpdignore</code> files contain directories excluded from database.
To restore:
 &bull; Edit <code>.../.mpdignore</code>
 &bull; Remove directories to restore
 &bull; Update Library
</p>
html
] );
echo '
</div>'; // last closing for no following htmlHead()
