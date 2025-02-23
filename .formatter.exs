# Used by "mix format"
[
  import_deps: [:ecto, :ecto_sql],
  subdirectories: ["test/*/migrations"],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
