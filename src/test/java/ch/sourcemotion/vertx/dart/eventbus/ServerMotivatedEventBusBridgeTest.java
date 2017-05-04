package ch.sourcemotion.vertx.dart.eventbus;

import ch.sourcemotion.vertx.dart.AbstractClientServerTest;
import io.vertx.core.MultiMap;
import io.vertx.core.Vertx;
import io.vertx.core.eventbus.DeliveryOptions;
import io.vertx.core.eventbus.EventBus;
import io.vertx.core.eventbus.Message;
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
 * Test for events they are initial send from server side
 *
 * @author Michel Werren
 */
@RunWith( VertxUnitRunner.class )
public class ServerMotivatedEventBusBridgeTest extends AbstractClientServerTest
{
    private static final Logger LOGGER = LoggerFactory.getLogger( ServerMotivatedEventBusBridgeTest.class );

    @Rule
    public RunTestOnContext serverRule = new RunTestOnContext();

    private Vertx vertx;

    private EventBus eventBus;


    @Before
    public void setUp () throws Exception
    {
        prepareClientsideTest( "server-motivated" );

        vertx = serverRule.vertx();
        eventBus = vertx.eventBus();
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
    public void serverMotivatedEventTest ( TestContext context ) throws Exception
    {
        vertx.exceptionHandler( context.exceptionHandler() );

        final Async async = context.async( 6 );

        startTestClient( context, async, "test/server_to_client_event_test.dart" );

        vertx.setPeriodic( 10000, id ->
        {
            LOGGER.info( "Start test" );

            eventBus.send( "simpleSend", 1, new DeliveryOptions().addHeader( "headerName", "headerValue" ) );
            async.countDown();

            vertx.eventBus().publish( "publish", 2, new DeliveryOptions().addHeader( "headerName", "headerValue" ) );
            async.countDown();

            vertx.eventBus().send( "withReply", 3, new DeliveryOptions().addHeader( "headerName", "headerValue" ), event ->
            {
                LOGGER.info( "Reply received" );

                final Message<Object> message = event.result();
                final MultiMap headers = message.headers();
                context.assertTrue(event.succeeded());
                context.assertEquals( "headerValue", headers.get( "headerName" ) );
                context.assertEquals( 3, message.body() );

                async.countDown();
            } );
            eventBus.send( "doubleReply", 4, new DeliveryOptions().addHeader( "headerName", "headerValue" ), event ->
            {
                LOGGER.info( "First double reply received" );

                final Message<Object> message = event.result();
                final MultiMap headers = message.headers();
                context.assertTrue(event.succeeded());
                context.assertEquals( "headerValue", headers.get( "headerName" ) );
                context.assertEquals( 4, message.body() );

                message.reply( message.body(), new DeliveryOptions().setHeaders( headers ), event2 ->
                {
                    LOGGER.info( "Second double reply received" );

                    final Message<Object> message2 = event.result();
                    final MultiMap headers2 = message2.headers();
                    context.assertTrue(event2.succeeded());
                    context.assertEquals( "headerValue", headers2.get( "headerName" ) );
                    context.assertEquals( 4, message2.body() );

                    async.countDown();
                } );
            } );

            JsonObject dto = new JsonObject();
            dto.put( "integer", 100 );
            dto.put( "integerString", "100" );
            dto.put( "string", "value" );
            dto.put( "doubleValue", 100.1D );
            dto.put( "doubleString", "100.1" );
            dto.put( "boolean", true );
            dto.put( "booleanString", "true" );
            dto.put( "obj", new JsonObject() );

            vertx.eventBus().send( "complexWithReply", dto, new DeliveryOptions().addHeader( "headerName", "headerValue" ), event ->
            {
                LOGGER.info( "complexWithReply received" );

                final Message<Object> message = event.result();
                final MultiMap headers = message.headers();
                context.assertTrue(event.succeeded());
                context.assertEquals( "headerValue", headers.get( "headerName" ) );
                final JsonObject bodyObject = new JsonObject( message.body().toString() );
                context.assertEquals( dto.getInteger( "integer" ), bodyObject.getInteger( "integer" ) );
                context.assertEquals( dto.getString( "integerString" ), bodyObject.getString( "integerString" ) );
                context.assertEquals( dto.getString( "string" ), bodyObject.getString( "string" ) );
                context.assertEquals( dto.getDouble( "doubleValue" ), bodyObject.getDouble( "doubleValue" ) );
                context.assertEquals( dto.getString( "doubleString" ), bodyObject.getString( "doubleString" ) );
                context.assertEquals( dto.getBoolean( "boolean" ), bodyObject.getBoolean( "boolean" ) );
                context.assertEquals( dto.getString( "booleanString" ), bodyObject.getString( "booleanString" ) );
                context.assertEquals( dto.getJsonObject( "obj" ), bodyObject.getJsonObject( "obj" ) );

                async.countDown();
            } );

            vertx.cancelTimer( id );
        } );
    }
}
