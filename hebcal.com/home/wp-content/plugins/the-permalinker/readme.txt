=== The Permalinker ===
Contributors: theandystratton
Donate link: http://theandystratton.com/donate
Tags: permalinks, linking, development, staging, migration
Requires at least: 2.6
Tested up to: 3.3.1
Stable tag: trunk

== Description ==

Use short codes to dynamically link to your WordPress pages and posts. All you need is the ID. This can come in handy when developing content for WordPress sites. Makes for a cleaner migration with no need to manipulate content when moving from one subdirectory or domain to another. 

Attributes of `append` `class`, `rel`, and `target` are supported within the `[permalink]` opening tag. See FAQs. You can insert the token `%post_title%` to dynamically insert the post's title into anchor text (content between the opening and closing shortcode).

A short code for `[template_uri]` exists if you'd like to dynamically grab the full URL to your current template directory (useful for adding images and other resources bundled in a template via the page/post editor).

*Example 1: Create link.*

`[permalink id=2 rel="internal"]Check out my latest post named %post_title%[/permalink]` or use `[permalink]this link[/permalink]` to link to this post.

*Example 2: Output Permalink URL.*

`<a href="[permalink]">;This post.</a>;`

*Example 3: Template Directory URI*

`<img src="[template_uri]/photos/me_grandma.jpg" alt="A Photo of Me and My Grandma" />`


== Installation ==

1. Download and unzip to the 'wp-content/plugins/' directory 
1. Activate the plugin.

== Changelog ==

= 1.7 (2012-01-06) =
* Added ability to dynamically insert post_title into anchor text using the token %post_title%

== Frequently Asked Questions ==

= I've got multiple permalinker short codes and it's interpreting them incorrectly and not creating the anchor tags properly. What gives? =

It is recommended that if you are mixing non-terminating short codes with terminating codes, that you change all non-terminating
short codes into terminating short codes with whitespace as the content:

`[permalink]` becomes `[permalink] [/permalink]`

Leading or trailing whitespace is trimmed off of any content within the permalinker short code tags.

= Can I add a class, rel, or target attribute to the permalinker output? =

Yes. Simply add `class`, `rel`, or `target` attributes to the `[permalink]` short code and they will be added to the resulting anchor element:

<pre>[permalink id="232" rel="related" target="_blank" class="highlight"]My favorite post[/permalink]</pre>

= Can I append a named anchor/ID/query string to the generated permalink? =

Yes! Simply use the new `append` attribute (added in version 1.6):

<pre>[permalink id="232" append="#comments"]People are talking, talking 'bout people.[/permalink]</pre>

== Screenshots ==

1. Content with short codes.
2. The dynamic output.
3. Markup.	
