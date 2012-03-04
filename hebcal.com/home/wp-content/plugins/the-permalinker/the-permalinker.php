<?php
/*
Plugin Name: The Permalinker
Plugin Author: Andy Stratton
Plugin URI: http://theandystratton.com/2009/the-permalinker-wordpress-plugin-dynamic-permalinks
Author URI: http://theandystratton.com
Version: 1.7
Description: Add dynamically created permalinks using the short code tag [permalink] and output dynamic links to your current template directory using short code [template_uri]. <a href="options-general.php?page=permalinker_help">Need help?</a>
*/

// Example:
// [permalink id=123]My 123rd post![/permalink]
//
function permalinker_links($atts, $content = null) {
	extract(shortcode_atts(array(
		'id' => null,
		'target' => null,
		'class' => '',
		'rel' => null,
		'append' => ''
	), $atts));
	if ( empty($id) ) {
		$id = get_the_ID();
	}
	$content = trim($content);
	if ( !empty($content) ) {
		$output = '<a href="' . get_permalink($id) . esc_attr($append) . '"';
		if ( !empty($target) ) {
			$output .= ' target="' . $target . '"';
		}
		$output .= ' class="permalinker_link ' . $class . '"';
		if ( !empty($rel) )
			$output .= ' rel="' . $rel . '"';
		$output .= '>' . str_replace('%post_title%', get_the_title($id), $content) . '</a>';
	}
	else {
		$output = get_permalink($id) . $append;
	}
	return $output;
}

// Example:
// <img src="[template_uri]/images/my_inline_image.jpg" alt="Photo" />
//
function permalinker_template_uri( $atts, $content = null ) {
	return get_template_directory_uri();
}

function permalinker_help() {
?>
<div class="wrap" style="width:80%;">
	<h2>Help With The Permalinker</h2>
	<p><strong>The Basics</strong></p>
	<p>Inserting a permalink is easy using the <code>[permalink]</code> short code:</p>
	<pre><code>[permalink]This is a link to the current post[/permalink]</code></pre>
	<p>If you'd like create a permalink to a different post than the one being displayed, 
	use the ID attribute:</p>
	<pre><code>[permalink id=23]This is a link to post 23[/permalink]</code></pre>
	
	<p><strong>Anchor Element Attributes</strong></p>
	<p>Some users may want to add a CSS <code>class</code>, relationship (<code>rel</code>), 
	or even a <code>target</code> attribute to the links that The Permalinker outputs.</p>
	<p>The latter 3 attributes are supported in your <code>[permalink]</code> short code:</p>
	<pre><code>[permalink id=23 rel="post" class="my_class" target="_blank"]Open post 23 in a new window[/permalink]</code></pre>
	
	<p><strong>Other Permalinker Notes</strong></p>
	<p>Just a few quick final notes:</p>
	<ul style="list-style:disc;margin: 1em 0 1em 3em;">
		<li>Leading and trailing whitespace is ignored.</li>
		<li>The class <code>permalinker_link</code> is always applied to a link generated from our short code.
		<li>
			If you are experiencing unexpected results when using terminating (<code>[permalink]anchor text[/permalink]</code>) and non-terminating
			(<code>[permalink]</code>) permalink short codes, change all non-terminating short codes to terminating short codes containing 
			only whitespace:<br /><br /><code>[permalink] [/permalink]</code>
		</li>
	</ul>
	<p>If you need more support, email Andy <a href="mailto:hello@theandystratton.com">hello@theandystratton.com</a>
	or visit his blog at <a href="http://theandystratton.com/blog/" target="_blank">theandystratton.com</a>
	
	<p><strong>Template URI Short Code</strong></p>
	<p>The <code>[template_uri]</code> short code was added for designers/developers that
	want to easily get their current theme's directory URI when linking to resources that 
	exist in their theme directory, such as stock photos, flash movies, etc.</p>
	<p><em>Example of Template URI usage:</em></p>
	<pre><code>&lt;img src="[template_uri]/photos/yoda.jpg" alt="A photo of Yoda." /&gt;</code></pre>
	
</div>
<?php 
}

function permalinker_admin_menu(){
	add_submenu_page('options-general.php', 'Permalinker Help', 'Permalinker Help', 1, 'permalinker_help', 'permalinker_help');
}

add_action('admin_menu', 'permalinker_admin_menu');
add_shortcode('permalink', 'permalinker_links');
add_shortcode('template_uri', 'permalinker_template_uri');
