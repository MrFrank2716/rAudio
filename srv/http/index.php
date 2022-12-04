<?php
// <!DOCTYPE html> ---------------------------------------------
include 'common.php';

$localhost = in_array( $_SERVER[ 'REMOTE_ADDR' ], ['127.0.0.1', '::1'] );
$equalizer = file_exists( '/srv/http/data/system/equalizer' );
$css       = [ 'roundslider', 'main' ];
if ( $equalizer ) array_push( $css, ...[ 'equalizer',      'selectric' ] );
if ( $localhost ) array_push( $css, ...[ 'simplekeyboard', 'keyboard' ] );
$cssfiles  = glob( '/srv/http/assets/css/*.min.*' );
$clist     = [];
foreach( $cssfiles as $file ) {
	$name                    = basename( $file );
	$name_ver                = explode( '-', $name );
	$clist[ $name_ver[ 0 ] ] = $name;
}
$style     = '';
foreach( $css as $c ) {
	if ( $c === 'roundslider' || $c === 'simplekeyboard' ) {
		$style.= '<link rel="stylesheet" href="/assets/css/'.$clist[ $c ].'">';
	} else {
		$style.= '<link rel="stylesheet" href="/assets/css/'.$c.'.css'.$hash.'">';
	}
}

// <style> -----------------------------------------------------
echo $style;

// </head><body> -----------------------------------------------
include 'common-body.php';

if ( file_exists( '/srv/http/data/system/login' ) ) {
	session_start();
	if ( ! $_SESSION[ 'login' ] ) {
		include 'login.php';
		exit;
	}
}

include 'main.php';

$jsp       = [ 'jquery', 'html5kellycolorpicker', 'lazysizes', 'pica', 'pushstream', 'qrcode', 'roundslider', 'Sortable' ];
$js        = [ 'common', 'context', 'function', 'main', 'passive' ];
if ( $equalizer ) {
	$jsp[] = 'jquery.selectric';
	$js[]  = 'equalizer';
}
if ( $localhost ) {
	$jsp[] = 'simplekeyboard';
	$js[]  = 'keyboard';
	echo '
<div id="keyboard" class="hide"><div class="simple-keyboard"></div></div>';
}
$script    = '';
foreach( $jsp as $j ) $script.= '
<script src="/assets/js/plugin/'.$jlist[ $j ].'"></script>';
// with cache busting
foreach( $js as $j ) $script.= '
<script src="/assets/js/'.$j.'.js'.$hash.'"></script>';
echo $script;
?>

</body>
</html>

