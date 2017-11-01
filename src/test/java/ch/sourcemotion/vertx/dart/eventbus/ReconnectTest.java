package ch.sourcemotion.vertx.dart.eventbus;

import ch.sourcemotion.vertx.dart.AbstractClientServerTest;
import io.vertx.core.Vertx;
import io.vertx.core.http.HttpServer;
import io.vertx.core.http.HttpServerOptions;
import io.vertx.ext.bridge.PermittedOptions;
import io.vertx.ext.unit.Async;
import io.vertx.ext.unit.TestContext;
import io.vertx.ext.unit.junit.RunTestOnContext;
import io.vertx.ext.unit.junit.VertxUnitRunner;
import io.vertx.ext.web.Router;
import io.vertx.ext.web.handler.sockjs.BridgeOptions;
import io.vertx.ext.web.handler.sockjs.SockJSHandler;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;

/**
 * @author Michel Werren
 */
@RunWith(VertxUnitRunner.class)
public class ReconnectTest extends AbstractClientServerTest {
  private static final Logger LOGGER = LoggerFactory.getLogger(ReconnectTest.class);

  @Rule
  public RunTestOnContext serverRule = new RunTestOnContext();

  private Vertx vertx;


  @Before
  public void setUp() throws Exception {
    vertx = serverRule.vertx();
  }


  /**
   * Test for 2 connection losts in a row.
   *
   * @param context
   * @throws Exception
   */
  @Test(timeout = 60000)
  public void testReconnectionOnClientSide(TestContext context) throws Exception {
    final Async async = context.async(2);
    vertx = serverRule.vertx();

    prepareClientsideTest("reconnect_test");

    final HttpServer httpServer = startServer(context);
    startTestClient(context, async, "test/reconnect_test.dart");

    // Wait until client is started
    vertx.setTimer(15000, init -> {
      // Simluate connection lost on client side
      httpServer.close();
      // Ensure for multiple reconnection tries on the client side
      vertx.setTimer(3000, restartServer -> {
        try {
          final HttpServer reopened = startServer(context);
          // Give client time to establish connection
          vertx.setTimer(2000, sendToClient -> {
            vertx.eventBus().send("after", null, reply -> {

              // Close again to test the reattachment on the client side
              reopened.close();
              try {
                // Restart directly
                startServer(context);
                vertx.setTimer(4000, sendToClientSecond -> {
                  vertx.eventBus().send("after", null, secondReply -> {

                    // Close again to test the reattachment on the client side
                    async.countDown();
                  });
                });
              } catch (IOException e) {
                e.printStackTrace();
              }
            });
          });
        } catch (IOException e) {
          LOGGER.error("Failed to restart server", e);
        }
      });
    });
  }


  /**
   * Starts the Sockjs bridge server with a test specific configuration.
   *
   * @param context
   * @throws IOException
   */
  private HttpServer startServer(TestContext context) throws IOException {
    HttpServer httpServer = vertx.createHttpServer(
        new HttpServerOptions().setHost("localhost").setPort(9000));

    final Router router = Router.router(vertx);

    SockJSHandler sockJSHandler = SockJSHandler.create(vertx);
    BridgeOptions options = new BridgeOptions();
    options.addOutboundPermitted(new PermittedOptions().setAddressRegex(".*"));
    // Only permit specific address
    options.addInboundPermitted(new PermittedOptions().setAddressRegex(".*"));
    sockJSHandler.bridge(options);

    router.route("/eventbus/*").order(0).handler(sockJSHandler);

    httpServer.requestHandler(router::accept);
    httpServer.listen();
    vertx.exceptionHandler(context.exceptionHandler());

    LOGGER.info("Server started");

    return httpServer;
  }
}