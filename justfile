run: css-min
  iex -S mix oapi.phx.test

deps:
  mix deps.get

test:
  mix test

lint:
  mix compile --force --warnings-as-errors
  mix credo

dialyzer:
  mix dialyzer

_mix_format:
  mix format

_mix_check:
  mix check

_git_status:
  git status

changelog:
  git cliff -o CHANGELOG.md

css-min:
  npx css-minify -f priv/assets/error.css -o priv/assets

dump:
  mix openapi.dump Oaskit.TestWeb.PathsApiSpec --pretty -o samples/path-api.json
  mix openapi.dump Oaskit.TestWeb.DeclarativeApiSpec --pretty -o samples/decl-api.json

docs:
  mix docs
  mix rdmx.update README.md
  mix rdmx.update guides/quickstart.md

check: deps _mix_format dump _mix_check docs  _git_status

