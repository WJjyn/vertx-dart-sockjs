@JS( )
library ch.sourcemotion.sockjs.external;

import 'package:js/js.dart';

@JS( "SockJS" )
class SockJSImpl
{
    external SockJSImpl( String url );

    external void set onopen( dynamic callback );

    external void set onmessage( dynamic callback );

    external void set onclose( dynamic callback );

    external send( String data );

    external int get readyState;
}

