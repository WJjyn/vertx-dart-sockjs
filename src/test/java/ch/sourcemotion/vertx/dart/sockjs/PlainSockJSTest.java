package ch.sourcemotion.vertx.dart.sockjs;

import io.vertx.core.Vertx;
import io.vertx.core.http.HttpServer;
import io.vertx.core.http.HttpServerOptions;
import io.vertx.ext.unit.Async;
import io.vertx.ext.unit.TestContext;
import io.vertx.ext.unit.junit.RunTestOnContext;
import io.vertx.ext.unit.junit.VertxUnitRunner;
import io.vertx.ext.web.Router;
import io.vertx.ext.web.handler.sockjs.SockJSHandler;
import org.junit.After;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Test for events they are initial send from server side
 *
 * @author Michel Werren
 */
@RunWith( VertxUnitRunner.class )
public class PlainSockJSTest extends AbstractClientServerTest
{
    private static final Logger LOGGER = LoggerFactory.getLogger( PlainSockJSTest.class );

    @Rule
    public RunTestOnContext serverRule = new RunTestOnContext();


    private Vertx vertx;

    private HttpServer httpServer;

    private SockJSHandler sockJSHandler;


    @Before
    public void setUp () throws Exception
    {
        prepareClientsideTest();

        vertx = serverRule.vertx();
        httpServer = vertx.createHttpServer( new HttpServerOptions().setHost( "localhost" ).setPort( 9000 ) );

        final Router router = Router.router( vertx );

        sockJSHandler = SockJSHandler.create( vertx );

        router.route( "/sockjs/*" ).handler( sockJSHandler );

        httpServer.requestHandler( router::accept );

        httpServer.listen();

        LOGGER.info( "Test server started" );
    }


    @After
    public void tearDown () throws Exception
    {
        httpServer.close();
    }


    @Test( timeout = 10000 )
    public void testMessagePingPongWithClient ( TestContext context ) throws Exception
    {
        final Async async = context.async( 2 );

        sockJSHandler.socketHandler( socket ->
        {
            socket.handler( buffer ->
            {
                context.assertEquals( 1, Integer.parseInt( buffer.toString() ) );
                socket.write( buffer );

                async.countDown();
            } );
        } );

        startTestClient( context, async, "test/sockjs_test.dart" );
    }
}
