{

/*
 *
 *    _____       _             _
 *   / ____|     | |           | |
 *  | |  __ _   _| |_ ___ _ __ | |__   ___ _ __ __ _
 *  | | |_ | | | | __/ _ \ '_ \| '_ \ / _ \ '__/ _` |
 *  | |__| | |_| | ||  __/ | | | |_) |  __/ | | (_| |
 *   \_____|\__,_|\__\___|_| |_|_.__/ \___|_|  \__, |
 *                                              __/ |
 *                  GRAMMAR                    |___/
 *
 *
 * Welcome to the grammar file for Gutenberg posts!
 *
 * Please don't be distracted by the functions at the top
 * here - they're just helpers for the grammar below. We
 * try to keep them as minimal and simple as possible,
 * but the parser generator forces us to declare them at
 * the beginning of the file.
 *
 * What follows is the official specification grammar for
 * documents created or edited in Gutenberg. It starts at
 * the top-level rule `Block_List`
 *
 * The grammar is defined by a series of _rules_ and ways
 * to return matches on those rules. It's a _PEG_, a
 * parsing expression grammar, which simply means that for
 * each of our rules we have a set of sub-rules to match
 * on and the generated parser will try them in order
 * until it finds the first match.
 *
 * This grammar is a _specification_ (with as little actual
 * code as we can get away with) which is used by the
 * parser generator to generate the actual _parser_ which
 * is used by Gutenberg. We generate two parsers: one in
 * JavaScript for use the browser and one in PHP for
 * WordPress itself. PEG parser generators are available
 * in many languages, though different libraries may require
 * some translation of this grammar into their syntax.
 *
 * For more information:
 * @see https://pegjs.org
 * @see https://en.wikipedia.org/wiki/Parsing_expression_grammar
 *
 */

/** <?php
// The `maybeJSON` function is not needed in PHP because its return semantics
// are the same as `json_decode`

// array arguments are backwards because of PHP
if ( ! function_exists( 'peg_split_inner_content' ) ) {
    function peg_split_inner_content( $array ) {
        $strings  = array();
        $blocks   = array();
        $markers  = array();
        $offset   = 0;
        $string   = '';

        foreach ( $array as $item ) {
            if ( is_string( $item ) ) {
                $string .= $item;
            } else {
                $offset   += strlen( $string );
                $strings[] = $string;
                $markers[] = $offset;
                $blocks[]  = $item;
                $string    = '';
            }
        }

        if ( $string !== '' ) {
            $strings[] = $string;
        }

        return array( $strings, $blocks, $markers );
    }
}

if ( ! function_exists( 'peg_join_blocks' ) ) {
    function peg_join_blocks( $pre, $tokens, $post ) {
        $blocks = array();

        if ( ! empty( $pre ) ) {
            $blocks[] = array(
                'blockName'   => null,
                'attrs'       => array(),
                'innerBlocks' => array(),
                'innerHTML'   => $pre
            );
        }

        foreach ( $tokens as $token ) {
            list( $token, $html ) = $token;

            $blocks[] = $token;

            if ( ! empty( $html ) ) {
                $blocks[] = array(
                    'blockName'   => null,
                    'attrs'       => array(),
                    'innerBlocks' => array(),
                    'innerHTML'   => $html
                );
            }
        }

        if ( ! empty( $post ) ) {
            $blocks[] = array(
                'blockName'   => null,
                'attrs'       => array(),
                'innerBlocks' => array(),
                'innerHTML'   => $post
            );
        }

        return $blocks;
    }
}

?> **/

function freeform( s ) {
    return s.length && {
        blockName: null,
        attrs: {},
        innerBlocks: [],
        innerHTML: s,
    };
}

function joinBlocks( pre, tokens, post ) {
    var blocks = [], i, l, html, item, token;

    if ( pre.length ) {
        blocks.push( freeform( pre ) );
    }

    for ( i = 0, l = tokens.length; i < l; i++ ) {
        item = tokens[ i ];
        token = item[ 0 ];
        html = item[ 1 ];

        blocks.push( token );
        if ( html.length ) {
            blocks.push( freeform( html ) );
        }
    }

    if ( post.length ) {
        blocks.push( freeform( post ) );
    }

    return blocks;
}

function maybeJSON( s ) {
    try {
        return JSON.parse( s );
    } catch (e) {
        return null;
    }
}

/**
 * Returns bytes required to represent given string in UTF8
 *
 * Assumes input is encoded in UCS2 or UTF16 according to the ECMAScript spec
 * @see: https://www.ecma-international.org/ecma-262/9.0/index.html#sec-ecmascript-language-types-string-type
 *
 * Transparently counts bytes for invalid encodings:
 * e.g. unpaired surrogate pair characters count as three bytes
 *
 * @cite: https://stackoverflow.com/a/34920444
 *
 * @param {string} s input string
 * @return {number} how many bytes are in the UTF8 representation of the given string
 */
function utf8bytes( s ) {
    var i, l, n = 0;

    for ( i = 0, l = s.length; i < l; i++ ) {
        var lo, hi = s.charCodeAt( i );

        if ( hi < 0x0080) { // [0x0000, 0x007F]
            n += 1;
        } else if ( hi < 0x0800 ) { // [0x0080, 0x07FF]
            n += 2;
        } else if ( hi < 0xD800 ) { // [0x0800, 0xD7FF]
            n += 3;
        } else if ( hi < 0xDC00 ) { // [0xD800, 0xDBFF]
            lo = s.charCodeAt( ++i );

            if ( i < l && lo >= 0xDC00 && lo <= 0xDFFF ) { //followed by [0xDC00, 0xDFFF]
                n += 4;
            } else {
                // this is an invalid string with an unpaired surrogate.
                // transparently pass it through for byte counts
                // and back up to restart processing at the next character.
                n += 3;
                i -= 1;
            }
        } else if ( hi < 0xE000 ) { //[0xDC00, 0xDFFF]
            // these are invalid encodings in the Unicode standard
            // because they are reserved for encoding surrogate pairs.
            // transparently pass them through here for byte counts.
            n += 3;
        } else { // [0xE000, 0xFFFF]
            n += 3;
        }
    }

    return n;
}

function splitInnerContent( list ) {
    var i, l, item;
    var strings = [];
    var blocks = [];
    var markers = [];
    var offset = 0;
    var string = '';

    // nod to performance over a simpler reduce
    // and clone model we could have taken here
    for ( i = 0, l = list.length; i < l; i++ ) {
        item = list[ i ];

        if ( 'string' === typeof item ) {
            string += item;
        } else {
            offset += utf8bytes( string );
            strings.push( string );
            markers.push( offset );
            blocks.push( item );
            string = '';
        }
    };

    if ( string !== '' ) {
        strings.push( string );
    }

    return [ strings, blocks, markers ];
}

}

//////////////////////////////////////////////////////
//
//   Here starts the grammar proper!
//
//////////////////////////////////////////////////////

Block_List
  = pre:$(!Block .)*
    bs:(b:Block html:$((!Block .)*) { /** <?php return array( $b, $html ); ?> **/ return [ b, html ] })*
    post:$(.*)
  { /** <?php return peg_join_blocks( $pre, $bs, $post ); ?> **/
    return joinBlocks( pre, bs, post );
  }

Block
  = Block_Void
  / Block_Balanced

Block_Void
  = "<!--" __ "wp:" blockName:Block_Name __ attrs:(a:Block_Attributes __ {
    /** <?php return $a; ?> **/
    return a;
  })? "/-->"
  {
    /** <?php
    return array(
      'blockName'    => $blockName,
      'attrs'        => isset( $attrs ) ? $attrs : array(),
      'innerBlocks'  => array(),
      'innerHTML'    => '',
      'blockMarkers' => array(),
    );
    ?> **/

    return {
      blockName: blockName,
      attrs: attrs || {},
      innerBlocks: [],
      innerHTML: '',
      blockMarkers: [],
    };
  }

Block_Balanced
  = s:Block_Start children:(Block / $(!Block_End .))* e:Block_End
  {
    /** <?php
    list( $innerHTML, $innerBlocks, $blockMarkers ) = peg_split_inner_content( $children );

    return array(
      'blockName'    => $s['blockName'],
      'attrs'        => $s['attrs'],
      'innerBlocks'  => $innerBlocks,
      'innerHTML'    => implode( '', $innerHTML ),
      'blockMarkers' => $blockMarkers,
    );
    ?> **/

    var innerContent = splitInnerContent( children );
    var innerHTML = innerContent[ 0 ];
    var innerBlocks = innerContent[ 1 ];
    var blockMarkers = innerContent[ 2 ];

    return {
      blockName: s.blockName,
      attrs: s.attrs,
      innerBlocks: innerBlocks,
      innerHTML: innerHTML.join( '' ),
      blockMarkers: blockMarkers,
    };
  }

Block_Start
  = "<!--" __ "wp:" blockName:Block_Name __ attrs:(a:Block_Attributes __ {
    /** <?php return $a; ?> **/
    return a;
  })? "-->"
  {
    /** <?php
    return array(
      'blockName' => $blockName,
      'attrs'     => isset( $attrs ) ? $attrs : array(),
    );
    ?> **/

    return {
      blockName: blockName,
      attrs: attrs || {}
    };
  }

Block_End
  = "<!--" __ "/wp:" blockName:Block_Name __ "-->"
  {
    /** <?php
    return array(
      'blockName' => $blockName,
    );
    ?> **/

    return {
      blockName: blockName
    };
  }

Block_Name
  = Namespaced_Block_Name
  / Core_Block_Name

Namespaced_Block_Name
  = $( Block_Name_Part "/" Block_Name_Part )

Core_Block_Name
  = type:$( Block_Name_Part )
  {
    /** <?php return "core/$type"; ?> **/
    return 'core/' + type;
  }

Block_Name_Part
  = $( [a-z][a-z0-9_-]* )

Block_Attributes
  "JSON-encoded attributes embedded in a block's opening comment"
  = attrs:$("{" (!("}" __ """/"? "-->") .)* "}")
  {
    /** <?php return json_decode( $attrs, true ); ?> **/
    return maybeJSON( attrs );
  }

__
  = [ \t\r\n]+
