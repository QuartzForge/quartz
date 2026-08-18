require "spec"
require "../src/quartz"
require "./support/test_client"

# Builds an application wired to the given routes and middlewares and
# wraps it in the in-memory test client.
def test_client_for(
  routes : Array(Quartz::RouteDef),
  middlewares : Array(Quartz::Middleware) = [] of Quartz::Middleware,
) : Quartz::Spec::TestClient
  Quartz::Spec::TestClient.new(
    Quartz::Application.new(
      Quartz::Router.new(routes),
      Quartz::Pipeline.new(middlewares),
    )
  )
end
