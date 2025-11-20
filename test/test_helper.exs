ExUnit.start(stacktrace_depth: 64)

# Start the test endpoint
{:ok, _} = Oaskit.TestWeb.Endpoint.start_link()
