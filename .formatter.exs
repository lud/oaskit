locals_without_parens = [
  operation: 1,
  operation: 2,
  parameter: 2,
  tags: 1,
  use_operation: 2,
  with_decimal: 1
]

[
  import_deps: [:phoenix, :jsv],
  inputs: ["*.exs", "{config,lib,test,tmp}/**/*.{ex,exs}"],
  force_do_end_blocks: true,
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
