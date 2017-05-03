package ch.sourcemotion.vertx.dart.eventbus;

import ch.sourcemotion.vertx.dart.AbstractClientServerTest;
import io.vertx.core.MultiMap;
import io.vertx.core.Vertx;
import io.vertx.core.eventbus.DeliveryOptions;
import io.vertx.core.eventbus.Message;
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
 * Test for events they are initial send from server side
 *
 * @author Michel Werren
 */
@RunWith( VertxUnitRunner.class )
public class ServerMotivatedEventBusBridgeTest extends AbstractClientServerTest
{
    private static final String WORK_DIR_CONFIG_KEY = "working.dir";

    private static final Logger LOGGER = LoggerFactory.getLogger( ServerMotivatedEventBusBridgeTest.class );

    @Rule
    public RunTestOnContext serverRule = new RunTestOnContext();

    private Vertx vertx;

    private HttpServer httpServer;


    @Before
    public void setUp () throws Exception
    {
        prepareClientsideTest("event-bus");

        vertx = serverRule.vertx();
        httpServer = vertx.createHttpServer( new HttpServerOptions().setHost( "localhost" ).setPort( 9000 ) );

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
    public void serverMotivatedEventTest ( TestContext context ) throws Exception
    {
        final Async async = context.async( 4 );

        startTestClient( context, async, "test/server_to_client_event_test.dart" );

        vertx.setPeriodic( 5000, id ->
        {
            LOGGER.info( "Event send to client on address: {}", "simpleSendConsumer" );
            vertx.eventBus().send( "simpleSendConsumer", 1, new DeliveryOptions().addHeader( "headerName", "headerValue" ) );
            async.countDown();
            vertx.eventBus().publish( "publishConsumer", 2, new DeliveryOptions().addHeader( "headerName", "headerValue" ) );
            async.countDown();
            vertx.eventBus().send( "consumerWithReply", 3, new DeliveryOptions().addHeader( "headerName", "headerValue" ), event ->
            {

                LOGGER.info( "Reply received, looks nice!!!" );

                final Message<Object> message = event.result();
                final MultiMap headers = message.headers();
                context.assertEquals( "headerValue", headers.get( "headerName" ) );
                context.assertEquals( 3, message.body() );

                async.countDown();
            } );


            vertx.cancelTimer( id );
        } );
    }
}
