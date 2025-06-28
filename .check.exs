[
  parallel: true,
  skipped: false,
  fix: false,
  retry: false,
  tools: [
    {:compiler, true},
    {:doctor, false},
    {:gettext, false},
    {:credo, "mix credo --all --strict"},
    # custom audit command
    {:"deps.audit", "mix deps.audit --format human"},
    {:mix_audit, false}
  ]
]
