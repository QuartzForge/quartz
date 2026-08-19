require "spec"
require "../src/quartz"
require "./support/test_client"
require "./support/example_app"

# Builds an application wired to the given routes and middlewares and
# wraps it in the in-memory test client. The collected routes get the
# embedded OpenAPI route appended, like `Quartz.application` does.
def test_client_for(
  routes : Array(Quartz::RouteDef),
  middlewares : Array(Quartz::Middleware) = [] of Quartz::Middleware,
) : Quartz::Spec::TestClient
  all = routes.same?(Quartz::ROUTES) ? routes + [Quartz.openapi_route] : routes
  Quartz::Spec::TestClient.new(
    Quartz::Application.new(
      Quartz::Router.new(all),
      Quartz::Pipeline.new(middlewares),
    )
  )
end
