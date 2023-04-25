<?php include 'common.php';?>

<div class="head">
	<i class="page-icon i-<?=$icon?>"></i><span class='title'><?=$title?></span><?=( i( 'close close' ).i( 'help helphead' ) )?>
</div>
<?php
function i( $icon, $id = '' ) {
	$htmlid = $id ? ' id="setting-'.$id.'"' : '';
	if ( $icon === 'localbrowser' && file_exists( '/usr/bin/firefox' ) ) $icon = 'firefox';
	return '<i'.$htmlid.' class="i-'.$icon.'"></i>';
}
function labelIcon( $name, $icon ) {
	return '<a class="helpmenu label">'.$name.'<i class="i-'.$icon.'"></i></a>';
}
function menu( $icon, $name, $iconsub = '' ) {
	$submenu = $iconsub ? '<i class="i-'.$iconsub.' sub"></i>' : '';
	return '<a class="helpmenu"><i class="i-'.$icon.'"></i> '.$name.$submenu.'</a>';
}
function tab( $icon, $name ) {
	return '<a class="helpmenu tab"><i class="i-'.$icon.'"></i> '.$name.'</a>';
}
// functions for use inside heredoc
$Fi         = 'i';
$FlabelIcon = 'labelIcon';
$Fmenu      = 'menu';
$Ftab       = 'tab';

echo '<div class="container hide">';

if ( $page !== 'addons' ) include 'settings/'.$page.'.php';

echo '</div>';

if ( $addonsprogress || $guide ) {
	echo '
</body>
</html>
';
	exit;
}
// .................................................................................

// bottom bar
$htmlbar = '<div id="bar-bottom">';
foreach ( [ 'Features', 'Player', 'Networks', 'System', 'Addons' ] as $name ) {
	$id      = strtolower( $name );
	$active  = $id === $pagetitle ? ' class="active"' : '';
	$htmlbar.= '<div id="'.$id.'"'.$active.'>'.i( $id ).'<a> '.$name.'</a></div>';
}
$htmlbar.= '</div>
<div id="debug"></div>';
echo $htmlbar;
if ( $localhost ) echo '<div id="keyboard" class="hide"><div class="simple-keyboard"></div></div>';

// <script> -----------------------------------------------------
foreach( $jsp as $j ) echo '<script src="/assets/js/plugin/'.$jfiles[ $j ].'"></script>';
foreach( $js as $j )  echo '<script src="/assets/js/'.$j.'.js'.$hash.'"></script>';
echo '
</body>
</html>
';

if ( $addons ) exit;

/*
$head = [
	  'title'   => 'TITLE'                  // REQUIRED
	, 'subhead' => true/false               // with no help icon
	, 'status'  => 'COMMAND'                // include status icon and status box
	, 'button'  => [ 'ID' => 'ICON', ... ]  // icon button
	, 'back'    => true/false               // back button
	, 'nohelp'  => true/false
	, 'help'    => 'HELP'
];
$body = [
	[
		  'label'       => 'LABEL'      // REQUIRED
		, 'sublabel'    => 'SUB LABEL'
		, 'id'          => 'ID'         // REQUIRED
		, 'status'      => 'COMMAND'    // include status icon and status box
		, 'input'       => 'HTML'       // alternative - if not switch
		, 'setting'     =>  ***         // default  = $( '#setting-'+ id ).click() before enable
		                                // false    = no setting
		                                // 'custom' = custom setting
		                                // 'none'   = no setting - custom enable
		, 'settingicon' => 'ICON'       // default = 'gear' 
		                                // false   = no icon
		, 'disabled'    => 'MESSAGE'    // set data-diabled - prompt on setting
		                                // 'js' = set by js condition
		, 'help'        => 'HELP'
		, 'exist'       => ***          // omit if not exist
	]
	, ...
];
htmlSection( $head, $body[, $id] );
*/
function htmlHead( $data ) {
	if ( isset( $data[ 'exist' ] ) && ! $data[ 'exist' ] ) return;
	
	$id      = $data[ 'id' ] ?? '';
	$title   = $data[ 'title' ];
	$subhead = $data[ 'subhead' ] ?? '';
	$status  = $data[ 'status' ] ?? '';
	$button  = $data[ 'button' ] ?? '';
	$help    = $data[ 'help' ] ?? '';
	$class   = $status ? 'status' : '';
	$class  .= $subhead ? ' subhead' : '';
	
	$html    = '<heading '.( $id ? ' id="'.$id.'"' : '' );
	$html   .= $class ? ' class="'.$class.'">' : '>';
	$html   .= '<span class="headtitle">'.$title.'</span>';
	if ( $button ) foreach( $button as $btnid => $icon ) $html.= i( $icon.' '.$btnid );
	$html   .= isset( $data[ 'nohelp' ] ) || $subhead ? '' : i( 'help help' );
	$html   .= isset( $data[ 'back' ] ) ? i( 'arrow-left back' ) : '';
	$html   .= '</heading>';
	$html   .= $help ? '<span class="helpblock hide">'.$help.'</span>' : '';
	$html   .= $status ? '<pre id="code'.$id.'" class="status hide"></pre>' : '';
	echo str_replace( '|', '<g>|</g>', $html );
}
function htmlSetting( $data ) {
	if ( isset( $data[ 'exist' ] ) && ! $data[ 'exist' ] ) return;
	
	if ( isset( $data[ 'html' ] ) ) {
		echo str_replace( '|', '<g>|</g>', $data[ 'html' ] );
		return;
	}
	
	global $page;
	global $id_data;
	// col-l
	$id          = $data[ 'id' ] ?? '';
	$iddata      = $id_data[ $id ];
	$name        = $iddata[ 'name' ];
	$sublabel    = $iddata[ 'sub' ] ?? '';
	$status      = $iddata[ 'status' ] ?? false;
	$setting     = $iddata[ 'setting' ] ?? 'common';
	$label       = '<span class="label">'.$name.'</span>';
	$input       = $data[ 'input' ] ?? '';
	$settingicon = ! $setting || $setting === 'none' ? '' : $data[ 'settingicon' ] ?? 'gear';
	$disabled    = $data[ 'disabled' ] ?? '';
	$help        = $data[ 'help' ] ?? '';
	$html        = '<div id="div'.$id.'"><div class="col-l';
	$html       .= $sublabel ? '' : ' single';
	$html       .= $status ? ' status">' : '">';
	$html       .= $sublabel ? '<a>'.$label.'<gr>'.$sublabel.'</gr></a>' : $label;
	$html       .= $page === 'features' || $page === 'system' ? i( $id ) : ''; // icon
	$html       .= '</div>';
	// col-r
	$html       .= '<div class="col-r">';
	if ( ! $input ) {
		$html   .= $disabled ? '<span class="hide">'.$disabled.'</span>' : '';
		$html   .= '<input type="checkbox" id="'.$id.'" class="switch '.$setting.'"><div class="switchlabel" for="'.$id.'">';
		$html   .= '</div>';
	} else {
		$html   .= $input;
	}
	$html       .= $settingicon ? i( $settingicon.' setting', $id ) : '';
	$html       .= $help ? '<span class="helpblock hide">'.$help.'</span>' : '';
	$html       .= '</div>
			 </div>';
	$html       .= $status ? '<pre id="code'.$id.'" class="status hide"></pre>' : '';
	echo $html;
}
function htmlSection( $head, $body, $id = '' ) {
	$html = '<div';
	$html.= $id ? ' id="div'.$id.'"' : '';
	$html.= ' class="section">';
	echo $html;
	htmlHead( $head );
	foreach( $body as $data ) htmlSetting( $data );
	echo '</div>';
}
