/**
 * Internal dependencies
 */
import { parse } from '../';
import { testParser } from '../../block-serialization-spec-parser/shared-tests';

describe( 'block-serialization-spec-parser', testParser( parse ) );
