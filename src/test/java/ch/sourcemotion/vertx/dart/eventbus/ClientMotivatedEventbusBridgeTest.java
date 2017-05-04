package ch.sourcemotion.vertx.dart.eventbus;

import ch.sourcemotion.vertx.dart.AbstractClientServerTest;
import io.vertx.core.Vertx;
import io.vertx.core.eventbus.DeliveryOptions;
import io.vertx.core.http.HttpServer;
import io.vertx.core.http.HttpServerOptions;
import io.vertx.core.json.JsonObject;
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
public class ClientMotivatedEventbusBridgeTest extends AbstractClientServerTest
{
    private static final Logger LOGGER = LoggerFactory.getLogger( ClientMotivatedEventbusBridgeTest.class );

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


    @Test( timeout = 60000 )
    public void clientMotivatedEventTest ( TestContext context ) throws Exception
    {
        vertx.exceptionHandler( context.exceptionHandler() );

        final Async async = context.async( 9 );

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
            LOGGER.info( "withReply -> Body: {} of type {}", message.body(), message.body() != null ? message.body().getClass().getName() : null );
            // Tested on the client side
            message.reply( message.body(), new DeliveryOptions().setHeaders( message.headers() ) );
            async.countDown();
        } );

        // 1 time executed
        vertx.eventBus().consumer( "failing", message ->
        {
            LOGGER.info( "failing" );
            // Tested on the client side
            message.fail( 1000, "failed" );
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

        vertx.eventBus().consumer( "complexDto", message ->
        {
            LOGGER.info( "complexDto" );
            JsonObject dto = new JsonObject( message.body().toString() );

            context.assertEquals( 100, dto.getInteger( "integer" ) );
            context.assertEquals( "100", dto.getString( "integerString" ) );
            context.assertEquals( "value", dto.getString( "string" ) );
            context.assertEquals( 100.1D, dto.getDouble( "doubleValue" ) );
            context.assertEquals( "100.1", dto.getString( "doubleString" ) );
            context.assertEquals( true, dto.getBoolean( "boolean" ) );
            context.assertEquals( "true", dto.getString( "booleanString" ) );
            context.assertEquals( new JsonObject(  ), dto.getJsonObject( "obj" ) );

            message.reply( message.body(), new DeliveryOptions().setHeaders( message.headers() ) );
            async.countDown();
        } );

        startTestClient( context, async, "test/client_to_server_event_test.dart" );
    }
}
