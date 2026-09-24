%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      requires: [
        ".code_my_spec/credo_checks/framework/**/*.ex",
        ".code_my_spec/credo_checks/local/**/*.ex"
      ],
      strict: false,
      parse_timeout: 5000,
      color: true,
      checks: %{
        # `Credo.Check.Warning.WrongTestFilename` arrived with credo 1.7.17+ and
        # flags any file that `use`s a test case without a `_test.exs` name. All
        # 374 spex are such a file by design, and the name is not negotiable:
        # `mix spex` globs `_spex.exs` and CodeMySpec's scanner keys criteria off
        # `criterion_*_spex.exs`.
        #
        # Off rather than reconfigured because credo's `checks.enabled` key
        # *replaces* the default check list rather than merging into it — listing
        # this one check there left exactly one check running. `disabled` is the
        # key that merges. The alternative is `mix credo gen.config`, which writes
        # the whole default list out to tweak one param and then drifts from it.
        #
        # What this costs: a genuinely misnamed test file (`test_foo.exs`) would no
        # longer be flagged. The check's own argument is that you would not notice
        # such a file never runs — here the analyzer runs `exunit` and `spex` as
        # separate legs, so a file in neither glob shows up as a criterion with no
        # passing spex rather than as silence.
        disabled: [
          {Credo.Check.Warning.WrongTestFilename, []}
        ],
        extra:
          if(File.exists?(".code_my_spec/credo_checks/framework/checks.exs"),
            do: elem(Code.eval_file(".code_my_spec/credo_checks/framework/checks.exs"), 0),
            else: []
          )
      }
    }
  ]
}
