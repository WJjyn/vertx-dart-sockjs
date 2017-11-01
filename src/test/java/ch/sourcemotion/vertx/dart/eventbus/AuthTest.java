package ch.sourcemotion.vertx.dart.eventbus;

import ch.sourcemotion.vertx.dart.AbstractClientServerTest;
import io.vertx.core.AsyncResult;
import io.vertx.core.Future;
import io.vertx.core.Handler;
import io.vertx.core.Vertx;
import io.vertx.core.http.HttpServer;
import io.vertx.core.http.HttpServerOptions;
import io.vertx.core.json.JsonObject;
import io.vertx.ext.auth.AbstractUser;
import io.vertx.ext.auth.AuthProvider;
import io.vertx.ext.auth.User;
import io.vertx.ext.bridge.PermittedOptions;
import io.vertx.ext.unit.Async;
import io.vertx.ext.unit.TestContext;
import io.vertx.ext.unit.junit.RunTestOnContext;
import io.vertx.ext.unit.junit.VertxUnitRunner;
import io.vertx.ext.web.Router;
import io.vertx.ext.web.handler.CookieHandler;
import io.vertx.ext.web.handler.SessionHandler;
import io.vertx.ext.web.handler.UserSessionHandler;
import io.vertx.ext.web.handler.sockjs.BridgeOptions;
import io.vertx.ext.web.handler.sockjs.SockJSHandler;
import io.vertx.ext.web.sstore.LocalSessionStore;
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
public class AuthTest extends AbstractClientServerTest {
  private static final Logger LOGGER = LoggerFactory.getLogger(AuthTest.class);

  public static final String PERMITTED_ADDRESS_AND_AUTHORITY = "permitted";

  @Rule
  public RunTestOnContext serverRule = new RunTestOnContext();

  private Vertx vertx;


  @Before
  public void setUp() throws Exception {
    vertx = serverRule.vertx();
  }


  /**
   * Test when client sends on a permitted and not permitted address.
   *
   * @param context
   * @throws Exception
   */
  @Test(timeout = 60000)
  public void authorizationByAddress(TestContext context) throws Exception {
    vertx = serverRule.vertx();

    prepareClientsideTest("authorization_by_address_test");

    startServer(context, new PermittedOptions().setAddress(PERMITTED_ADDRESS_AND_AUTHORITY));

    final Async async = context.async(2);

    vertx.eventBus().consumer(PERMITTED_ADDRESS_AND_AUTHORITY, message ->
    {
      LOGGER.info("Permitted address reached");
      message.reply(null);
      async.countDown();
    });

    vertx.eventBus().consumer("not_permitted", message ->
    {
      context.fail("Consumer on not permitted address should not get executed");
    });

    startTestClient(context, async, "test/authorization_by_address_test.dart");
  }


  /**
   * Test when client send message without authority.
   *
   * @param context
   * @throws Exception
   */
  @Test(timeout = 60000)
  public void authorizationByAuthority(TestContext context) throws Exception {
    vertx = serverRule.vertx();

    prepareClientsideTest("authorization_by_authority_test");

    startServer(context,
        new PermittedOptions().setRequiredAuthority(PERMITTED_ADDRESS_AND_AUTHORITY),
        new NoPermitTestAuthProvider());

    final Async async = context.async(1);

    vertx.eventBus().consumer("with_authorization", message ->
    {
      context.fail("Consumer on not permitted address should not get executed");
    });

    startTestClient(context, async, "test/authorization_by_authority_test.dart");
  }


  /**
   * Test when client authentication has failed.
   *
   * @param context
   * @throws Exception
   */
  @Test(timeout = 60000)
  public void authorizationWithFailingAuthentication(TestContext context) throws Exception {
    vertx = serverRule.vertx();

    prepareClientsideTest("authentication_fail_test");

    startServer(context,
        new PermittedOptions().setRequiredAuthority(PERMITTED_ADDRESS_AND_AUTHORITY),
        new FailingTestAuthProvider());

    final Async async = context.async(1);

    vertx.eventBus().consumer("with_authorization", message ->
    {
      context.fail("Consumer on not permitted address should not get executed");
    });

    startTestClient(context, async, "test/authentication_fail_test.dart");
  }


  /**
   * Starts the Sockjs bridge server with a test specific configuration.
   *
   * @param context
   * @param inboundPermittedOptions
   * @param handler
   * @throws IOException
   */
  private void startServer(TestContext context, PermittedOptions inboundPermittedOptions,
                           AuthProvider... handler) throws IOException {
    HttpServer httpServer = vertx.createHttpServer(
        new HttpServerOptions().setHost("localhost").setPort(9000));

    final Router router = Router.router(vertx);

    SockJSHandler sockJSHandler = SockJSHandler.create(vertx);
    BridgeOptions options = new BridgeOptions();
    options.addOutboundPermitted(new PermittedOptions().setAddressRegex(".*"));
    // Only permit specific address
    options.addInboundPermitted(inboundPermittedOptions);
    sockJSHandler.bridge(options);

    if (handler.length == 1) {
      AuthProvider authProvider = handler[0];

      final LocalSessionStore sessionStore = LocalSessionStore.create(vertx);
      final SessionHandler sessionHandler = SessionHandler.create(sessionStore);
      router.route("/eventbus/*").order(0).handler(CookieHandler.create());
      router.route("/eventbus/*").order(1).handler(sessionHandler);
      router.route("/eventbus/*").order(2).handler(UserSessionHandler.create(authProvider));
      router.route("/eventbus/*").order(3).handler(rc ->
          authProvider.authenticate(null, result ->
          {
            if (result.succeeded()) {
              rc.setUser(result.result());
            }
            rc.next();
          }));

      router.route("/eventbus/*").order(4).handler(sockJSHandler);
    } else {
      router.route("/eventbus/*").order(0).handler(sockJSHandler);
    }

    httpServer.requestHandler(router::accept);
    httpServer.listen();
    vertx.exceptionHandler(context.exceptionHandler());

    LOGGER.info("Server started");
  }


  private static class FailingTestAuthProvider implements AuthProvider {
    @Override
    public void authenticate(JsonObject authInfo, Handler<AsyncResult<User>> resultHandler) {
      resultHandler.handle(Future.failedFuture("Just failed"));
    }
  }

  /**
   * Test {@link AuthProvider} thats permits nothing
   */
  private static class NoPermitTestAuthProvider implements AuthProvider {
    @Override
    public void authenticate(JsonObject jsonObject, Handler<AsyncResult<User>> handler) {
      handler.handle(Future.succeededFuture(new NotPermissionUser()));
    }
  }


  /**
   * Test user that has permission on nothing.
   */
  private static class NotPermissionUser extends AbstractUser {
    AuthProvider authProvider;


    @Override
    protected void doIsPermitted(String s, Handler<AsyncResult<Boolean>> handler) {
      handler.handle(Future.succeededFuture(Boolean.FALSE));
    }


    @Override
    public JsonObject principal() {
      return new JsonObject();
    }


    @Override
    public void setAuthProvider(AuthProvider authProvider) {
      this.authProvider = authProvider;
    }
  }
}
