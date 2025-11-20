install:
  mix deps.get

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
  mix format --migrate

_mix_check:
  mix check

_git_status:
  git status

changelog:
  git cliff -o CHANGELOG.md

css-min:
  npx css-minify -f priv/assets/error.css -o priv/assets

dump: dump-paths dump-declarative dump-security dump-orval

dump-paths:
  mix openapi.dump Oaskit.TestWeb.PathsApiSpec --pretty -o samples/path-api.json

dump-declarative:
  mix openapi.dump Oaskit.TestWeb.DeclarativeApiSpec --pretty -o samples/decl-api.json

dump-security:
  mix openapi.dump Oaskit.TestWeb.SecurityApiSpec --pretty -o samples/security-api.json

dump-orval:
  mix openapi.dump Oaskit.TestWeb.OrvalApiSpec --pretty -o samples/orval-api.json
  cd test/support/orval && npm install && npm run generate

test-orval: dump-orval
  cd test/support/orval && npm start

docs: readmix
  mix docs

readmix:
  mix rdmx.update README.md
  rg rdmx guides -l0 | xargs -0 -n 1 mix rdmx.update

check: install _mix_format dump deps _mix_format dump _mix_check docs  _git_status

