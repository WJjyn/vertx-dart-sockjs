package ch.sourcemotion.vertx.dart.eventbus;

import ch.sourcemotion.vertx.dart.sockjs.AbstractClientServerTest;
import io.vertx.core.Vertx;
import io.vertx.core.eventbus.DeliveryOptions;
import io.vertx.core.http.HttpServer;
import io.vertx.core.http.HttpServerOptions;
import io.vertx.ext.unit.Async;
import io.vertx.ext.unit.TestContext;
import io.vertx.ext.unit.junit.RunTestOnContext;
import io.vertx.ext.unit.junit.VertxUnitRunner;
import io.vertx.ext.web.Router;
import io.vertx.ext.web.handler.sockjs.BridgeOptions;
import io.vertx.ext.web.handler.sockjs.PermittedOptions;
import io.vertx.ext.web.handler.sockjs.SockJSHandler;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * @author Michel Werren
 */
@RunWith( VertxUnitRunner.class )
public class ClientMotivatedEventbusTest extends AbstractClientServerTest
{
    private static final Logger LOGGER = LoggerFactory.getLogger( ClientMotivatedEventbusTest.class );

    @Rule
    public RunTestOnContext serverRule = new RunTestOnContext();

    private Vertx vertx;


    @Before
    public void setUp () throws Exception
    {
        prepareClientsideTest( "client-motivated" );

        vertx = serverRule.vertx();
        HttpServer httpServer = vertx.createHttpServer( new HttpServerOptions().setHost( "localhost" ).setPort( 9000 ) );

        final Router router = Router.router( vertx );

        SockJSHandler sockJSHandler = SockJSHandler.create( vertx );
        BridgeOptions options = new BridgeOptions();
        options.addOutboundPermitted( new PermittedOptions().setAddressRegex( ".*" ) );
        options.addInboundPermitted( new PermittedOptions().setAddressRegex( ".*" ) );
        sockJSHandler.bridge( options );

        router.route( "/eventbus/*" ).handler( sockJSHandler );

        httpServer.requestHandler( router::accept );

        httpServer.listen();

        LOGGER.info( "Test server started" );
    }


    @Test( timeout = 10000 )
    public void clientMotivatedEventTest ( TestContext context ) throws Exception
    {
        final Async async = context.async( 4 );

        // 1 time executed
        vertx.eventBus().consumer( "simpleSend", message ->
        {
            LOGGER.info( "simpleSend" );

            context.assertEquals( "headerValue", message.headers().get( "headerName" ) );
            context.assertEquals( 1, message.body() );
            async.countDown();
        } );

        // 1 time executed
        vertx.eventBus().consumer( "publish", message ->
        {
            LOGGER.info( "publish" );
            context.assertEquals( "headerValue", message.headers().get( "headerName" ) );
            context.assertEquals( 2, message.body() );
            async.countDown();
        } );

        // 3 times executed
        vertx.eventBus().consumer( "withReply", message ->
        {
            LOGGER.info( "withReply" );
            // Tested on the client side
            message.reply( message.body(), new DeliveryOptions().setHeaders( message.headers() ) );
            async.countDown();
        } );

        // 1 time executed
        vertx.eventBus().consumer( "doubleReply", message ->
        {
            LOGGER.info( "doubleReply" );
            // Tested on the client side
            message.reply( message.body(), new DeliveryOptions().setHeaders( message.headers() ), r1 -> {
                r1.result().reply( r1.result().body(), new DeliveryOptions( ).setHeaders( r1.result().headers() ) );
                async.countDown();
            } );
        } );

        // 1 time executed
        vertx.eventBus().consumer( "failing", message ->
        {
            LOGGER.info( "failing" );
            // Tested on the client side
            message.fail( 1000, "failed" );
            async.countDown();
        } );

        startTestClient( context, async, "test/client_to_server_event_test.dart" );
    }
}
