<?php include 'common.php';?>

<div class="head">
	<i class="page-icon i-<?=$icon?>"></i><span class='title'><?=$title?></span><?=( i( 'close close' ).i( 'help helphead' ) )?>
</div>
<?php
function i( $icon, $id = '' ) {
	$htmlid = $id ? ' id="setting-'.$id.'"' : '';
	return '<i'.$htmlid.' class="i-'.$icon.'"></i>';
}
function iLabel( $label, $icon = '' ) {
	$htmlicon = $icon ? '<i class="i-'.$icon.'"></i>' : '&emsp;';
	return '<a class="helpmenu label">'.$label.$htmlicon.'</a>';
}
function iTab( $tab ) {
	return '<a class="helpmenu tab"><i class="i-'.strtolower( $tab ).'"></i> '.$tab.'</a>';
}
function menu( $icon, $name, $iconsub = '' ) {
	$submenu = $iconsub ? '<i class="i-'.$iconsub.' sub"></i>' : '';
	return '<a class="helpmenu"><i class="i-'.$icon.'"></i> '.$name.$submenu.'</a>';
}
// functions for use inside heredoc
$Fi      = 'i';
$FiLabel = 'iLabel';
$FiTab   = 'iTab';
$Fmenu   = 'menu';

echo '<div class="container '.$page.' hide">';

if ( $page !== 'addons' ) include 'settings/'.$page.'.php';

echo '</div>';

if ( $addonsprogress || $guide ) {
	echo '
</body>
</html>
';
	exit;
//----------------------------------------------------------------------------------
}
// .................................................................................

// bottom bar
$htmlbar = '<div id="bar-bottom">';
$prefix  = '';
if ( $camilla ) {
	$tabs   = [ 'Filters', 'Mixers', 'Processors', 'Pipeline', 'Devices', 'Config' ];
	$prefix = 'tab';
} else {
	$tabs   = [ 'Features', 'Player', 'Networks', 'System', 'Addons' ];
}
foreach ( $tabs as $tab ) {
	$id      = strtolower( $tab );
	$htmlbar.= '<div id="'.$prefix.$id.'">'.i( $id ).'<a> '.$tab.'</a></div>';
}
$htmlbar.= '</div>
<div id="debug"></div>';
echo $htmlbar;
if ( $localhost ) echo '<div id="keyboard" class="hide"><div class="simple-keyboard"></div></div>';

// <script> -----------------------------------------------------
foreach( $jsp as $j ) echo '<script src="/assets/js/plugin/'.$jfiles[ $j ].'"></script>';
foreach( $js as $j )  echo '<script src="/assets/js/'.$j.'.js'.$hash.'"></script>';
if ( $camilla ) {
	echo '
<script>
var jfiles = '.json_encode( $jfiles ).';
</script>
';
}
echo '
</body>
</html>
';

if ( $addons ) exit;
//----------------------------------------------------------------------------------
/*
$id_data = [ 'ID' => [               // REQUIRED
	  'label'   => 'LABEL'
	, 'sub'     => 'SUBLABEL'
	, 'setting' => 'TYPE'
	, 'status'  => 'SCRIPTCOMMAND'
];
$head = [
	  'title'   => 'TITLE'           // REQUIRED
	, 'subhead' => true/false        // with no help icon
	, 'status'  => 'COMMAND'         // include status icon and status box
	, 'button'  => [ 'ICON', ... ]   // icon button
	, 'back'    => true/false        // back button
	, 'nohelp'  => true/false
	, 'help'    => 'HELP'
];
$body = [
	 'HTML'                          // for non-switch section
	, [
		  'id'       => 'ID'         // REQUIRED
		, 'input'    => 'HTML/ID'    // alternative - if not switch (ID - select)
		, 'setting'  => TYPE         // default  = $( '#setting-'+ id ).click() before enable
		                             // false    = no setting
		                             // 'custom' = custom setting
		                             // 'none'   = no setting - custom enable
		, 'disabled' => 'MESSAGE'    // set data-diabled - prompt on click setting
		                             // 'js'     = set by js condition
		, 'help'     => 'HELP'
		, 'exist'    => 'COMMAND'    // hide if COMMAND = false
	]
	, ...
];
htmlSection( $head, $body[, $id] );
*/
function htmlHead( $data ) {
	if ( isset( $data[ 'exist' ] ) && ! $data[ 'exist' ] ) return;
	
	$title   = $data[ 'title' ];
	$id      = $data[ 'id' ] ?? false;
	$status  = $data[ 'status' ] ?? false;
	$button  = $data[ 'button' ] ?? false;
	$help    = $data[ 'help' ] ?? false;
	$class   = $status ? 'status' : '';
	
	$html    = '<heading '.( $id ? ' id="'.$id.'"' : '' ).( $status ? ' data-status="'.$status.'"' : '' );
	$html   .= $class ? ' class="'.$class.'">' : '>';
	$html   .= '<span class="headtitle">'.$title.'</span>';
	if ( $button ) {
		if ( is_Array( $button ) ) {
			foreach( $button as $icon ) $html.= i( $icon );
		} else {
			$html.= i( $button );
		}
	}
	$html   .= isset( $data[ 'nohelp' ] ) ? '' : i( 'help help' );
	$html   .= isset( $data[ 'back' ] ) ? i( 'back back' ) : '';
	$html   .= '</heading>';
	$html   .= $help ? '<span class="helpblock hide">'.$help.'</span>' : '';
	$html   .= $status ? '<pre id="code'.$status.'" class="status hide"></pre>' : '';
	echo str_replace( '|', '<g>|</g>', $html );
}
function htmlSection( $head, $body, $id = '' ) {
	$html = '<div';
	$html.= $id ? ' id="div'.$id.'"' : '';
	$html.= ' class="section">';
	echo $html;
	if ( $head ) htmlHead( $head );
	foreach( $body as $data ) {
		if ( is_array( $data ) ) {
			htmlSetting( $data );
		} else {
			echo $data;
		}
	}
	echo '</div>';
}
function htmlSectionStatus( $id, $labels = '', $values = '', $help = '' ) {
	if ( ! $labels ) $labels = '&nbsp;';
	if ( $help ) $help = '<div class="helpblock hide">'.$help.'</div>';
	return '
<div id="div'.$id.'" class="row">
<div class="col-l text label gr">'.$labels.'</div>
<div class="col-r text value">'.$values.'</div>
'.$help.'
</div>';
}
function htmlSetting( $data ) {
	global $id_data;
	$id          = $data[ 'id' ];
	$iddata      = $id_data[ $id ];
	if ( isset( $iddata[ 'exist' ] ) && ! file_exists( '/usr/bin/'.$iddata[ 'exist' ] ) ) return;
	
	if ( isset( $data[ 'html' ] ) ) {
		echo str_replace( '|', '<g>|</g>', $data[ 'html' ] );
		return;
	}
	
	global $page;
	$id          = $data[ 'id' ];
	$iddata      = $id_data[ $id ];
	$label       = $iddata[ 'label' ];
	$sublabel    = $iddata[ 'sub' ] ?? false;
	$status      = $iddata[ 'status' ] ?? false;
	$setting     = $iddata[ 'setting' ] ?? 'common';
	$label       = '<span class="label">'.$label.'</span>';
	$input       = $data[ 'input' ] ?? false;
	$settingicon = ! $setting || $setting === 'none' ? false : 'gear';
	$help        = $data[ 'help' ] ?? false;
	$icon        = $data[ 'icon' ] ?? false;
	if ( $page === 'features' || $page === 'system' ) $icon = $id;
	
	$html        = '<div id="div'.$id.'" class="row">';
	// col-l
	$html       .= '<div class="col-l';
	$html       .= $sublabel ? '' : ' single';
	$html       .= $status ? ' status" data-status="'.$id.'">' : '">';
	$html       .= $sublabel ? '<a>'.$label.'<gr>'.$sublabel.'</gr></a>' : $label;
	$html       .= $icon ? i( $icon ) : ''; // icon
	$html       .= '</div>';
	// col-r
	$html       .= '<div class="col-r">';
	if ( ! $input ) {
		$disabled = isset( $data[ 'disabled' ] ) ? '<span class="hide">'.$data[ 'disabled' ].'</span>' : '';
		$html    .= '<label>'.$disabled.'<input type="checkbox" id="'.$id.'" class="switch '.$setting.'"><div class="switchlabel"></div></label>';
	} else {
		if ( ltrim( $input )[ 0 ] == '<' ) {
			$html.= $input;
		} else { // select
			$html.= '<select id="'.$input.'"></select>';
		}
	}
	// setting
	$html       .= $settingicon ? i( $settingicon.' setting', $id ) : '';
	// help
	$html       .= $help ? '<span class="helpblock hide">'.$help.'</span>' : '';
	$html       .= '</div>
					</div>';
	// status
	$html       .= $status ? '<pre id="code'.$id.'" class="status hide"></pre>' : '';
	if ( isset( $data[ 'returnhtml' ] ) ) return $html;
	
	echo $html;
}
