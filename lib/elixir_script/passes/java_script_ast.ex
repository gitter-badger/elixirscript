defmodule ElixirScript.Passes.JavaScriptAST do
  @moduledoc false
  alias ElixirScript.Translator.Utils
  alias ElixirScript.Translator.State

  def execute(compiler_data, opts) do

    State.set_module_data(compiler_data.state, compiler_data.data)
    State.set_loaded_modules(compiler_data.state, Map.get(compiler_data, :loaded_modules, []))

    parent = self

    data = State.get_module_data(compiler_data.state)
    |> Enum.map(fn({module_name, module_data}) ->

      spawn_link fn ->
        module_data = compile(module_data, opts, compiler_data.state)
        result = {module_name, module_data}
        send parent, {self, result }
      end

    end)
    |> Enum.map(fn pid ->
      receive do
        {^pid, result} ->
          result
      end
    end)

    %{ compiler_data | data: data }
  end

  defp compile(%{load_only: true} = module_data, opts, state) do
    module_data
  end

  defp compile(module_data, opts, state) do

    env = ElixirScript.Translator.LexicalScope.module_scope(module_data.name,  Utils.name_to_js_file_name(module_data.name) <> ".js", opts.env, state, opts)

    module = case module_data.type do
               :module ->
                 ElixirScript.Translator.Defmodule.make_module(module_data.name, module_data.ast, env)
               :protocol ->
                 ElixirScript.Translator.Defprotocol.make(module_data.name, module_data.functions, env)
               :impl ->
                 ElixirScript.Translator.Defimpl.make(module_data.name, module_data.for, module_data.ast, env)
             end

    Map.put(module_data, :javascript_ast, module.body)
  end
end
