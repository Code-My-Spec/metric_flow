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
        extra:
          if(File.exists?(".code_my_spec/credo_checks/framework/checks.exs"),
            do: elem(Code.eval_file(".code_my_spec/credo_checks/framework/checks.exs"), 0),
            else: []
          )
      }
    }
  ]
}
