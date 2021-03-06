defmodule Mix.Tasks.Compile.ElixirScript do
  use Mix.Task

  @moduledoc """
  Mix compiler to allow mix to compile Elixirscript source files into JavaScript

  Looks for an `elixir_script` or `elixirscript` key in your mix project config

      def project do
        [
          app: :my_app,
          version: "0.1.0",
          elixir: "~> 1.0",
          deps: deps,
          elixir_script: [ input: "src/exjs", output: "dest/js"],
          compilers: [:elixir_script] ++ Mix.compilers
        ]
      end
    
  Available options are:
  * `input`: The folder to look for Elixirscript files in. (defaults to `lib/elixirscript`)
  * `output`: The folder to place generated JavaScript code in. (defaults to `priv/elixirscript`)
  * `format`: The module format of generated JavaScript code. (defaults to `:es`).
    Choices are:
      * `:es` - ES Modules
      * `:common` - CommonJS
      * `:umd` - UMD

  The mix compiler will also compile any dependencies that have the elixirscript compiler in its mix compilers as well
  """


  @spec run(any()) :: :ok
  def run(_) do
    elixirscript_config = get_elixirscript_config()

    elixirscript_base = Path.join([Mix.Project.build_path, "elixirscript"])
    File.mkdir_p!(elixirscript_base)
    elixirscript_path = Path.join([elixirscript_base, "#{Mix.Project.config[:app]}"])

    input_path = elixirscript_config
    |> Keyword.get(:input)
    |> List.wrap
    |> Enum.map(fn(path) ->
      Path.absname(path)
    end)
    |> Enum.join("\n")

    File.write!(elixirscript_path, input_path)

    paths = [elixirscript_base, "*"]
    |> Path.join()
    |> Path.wildcard
    |> Enum.map(fn(path) ->
      app = Path.basename(path)
      paths = path |> File.read!() |> String.split("\n")
      {app, paths}
    end)
    |> Map.new

    output_path = Keyword.get(elixirscript_config, :output)
    format = Keyword.get(elixirscript_config, :format)

    ElixirScript.compile_path(paths, %{output: output_path, format: format})
    :ok
  end

  def clean do
    elixirscript_config = get_elixirscript_config()
    output_path = Keyword.get(elixirscript_config, :output)

    output_path
    |> File.ls!
    |> Enum.each(fn(x) ->
      if String.contains?(Path.basename(x), "Elixir.") do
        File.rm!(Path.join(output_path, x))
      end
    end)

    :ok
  end

  defp get_elixirscript_config() do
    config  = Mix.Project.config
    exjs_config = cond do
      Keyword.has_key?(config, :elixir_script) ->
        Keyword.get(config, :elixir_script, [])
      Keyword.has_key?(config, :elixirscript) ->
        Keyword.get(config, :elixirscript, [])
      true ->
        defaults()
    end

    Keyword.merge(defaults(), exjs_config)
  end

  defp defaults() do
    [
      input: "lib/elixirscript",
      output: "priv/elixirscript",
      format: :es
    ]
  end

end
