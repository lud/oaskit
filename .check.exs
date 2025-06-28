[
  parallel: true,
  skipped: true,
  fix: false,
  retry: false,
  tools: [
    {:compiler, true},
    {:doctor, false},
    {:gettext, false},
    {:dialyzer, true},
    {:credo, "mix credo --all --strict"},
    # custom audit command
    {:"deps.audit", "mix deps.audit --format human"},
    {:sobelow, "mix sobelow --skip"},
    {:mix_audit, false}
  ]
]
