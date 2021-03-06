defmodule ElixirScript.ModuleSystems.UMD do
  @moduledoc false
  alias ESTree.Tools.Builder, as: JS
  alias ElixirScript.Translator
  alias ElixirScript.Translator.State
  alias ElixirScript.Translator.Utils

  def build(body, exports, env) do
    js_module_refs = State.get_javascript_module_references(env.state, env.module)
    std_import = make_std_lib_import(env)
    module_refs = State.get_module_references(env.state, env.module) -- [env.module]
    |> module_imports_to_js_imports(env)

    imports = js_module_refs ++ std_import
    |> Enum.map(fn
      {module, path, true} -> import_module(module, path, env)
      {module, path, false} -> import_namespace_module(module, path, env)
    end)

    imports = Enum.uniq(imports ++ module_refs)

    export = export_module(exports)

    List.wrap(make_umd(imports, body, export))
  end

  defp module_imports_to_js_imports(module_refs, env) do
    Enum.map(module_refs, fn(x) ->
      module_name = Utils.name_to_js_name(x)
      app_name = State.get_module(env.state, x).app
      path = Utils.make_local_file_path(app_name, Utils.name_to_js_file_name(x), env)
      import_module(module_name, path)
    end)
  end

  defp make_std_lib_import(env) do
    compiler_opts = State.get(env.state).compiler_opts
    case compiler_opts.import_standard_libs do
      true ->
        [{:Elixir, Utils.make_local_file_path(:elixir, compiler_opts.core_path, env), true }]
      false ->
        []
    end
  end

  def import_namespace_module(module_name, from, env) do
    {Translator.translate!(module_name, env), JS.literal(from)}
  end

  def import_module(:Elixir, from, env) do
    {JS.identifier("Elixir"), JS.literal(from)}
  end

  def import_module(module_name, from, env) do
    {Translator.translate!(module_name, env), JS.literal(from)}
  end

  def import_module(import_name, from) do
    {JS.identifier(import_name), JS.literal(from)}
  end

  def export_module(exported_object) do
    exported_object
  end

  def make_umd(imports, body, exports) do
    import_paths = Enum.map(imports, fn({_, path}) -> path end)
    import_identifiers = Enum.map(imports, fn({id, _}) -> id end)

    JS.expression_statement(
      JS.call_expression(
         JS.function_expression([JS.identifier("root"), JS.identifier("factory")], [], JS.block_statement([
          JS.if_statement(
            JS.logical_expression(
              :&&,
              JS.binary_expression(
                :===,
                JS.unary_expression(:typeof, true, JS.identifier("define")),
                JS.literal("function")
              ),
              JS.member_expression(
                JS.identifier("define"),
                JS.identifier("amd")
              )
            ),
            JS.block_statement([
              JS.call_expression(
                JS.identifier("define"),
                [JS.array_expression(import_paths), JS.identifier("factory")]
              )
            ]),
            JS.if_statement(
              JS.binary_expression(
                :===,
                JS.unary_expression(:typeof, true, JS.identifier("exports")),
                JS.literal("object")
              ),
              JS.block_statement([
                JS.assignment_expression(
                  :=,
                  JS.member_expression(
                    JS.identifier("module"),
                    JS.identifier("exports")
                  ),
                  JS.call_expression(
                    JS.identifier("factory"),
                    Enum.map(import_paths, fn x ->
                      JS.call_expression(
                        JS.identifier("require"),
                        [x]
                      )
                    end)
                  )
                )
              ]),
              JS.block_statement([
                JS.assignment_expression(
                  :=,
                  JS.member_expression(
                    JS.identifier("root"),
                    JS.identifier("returnExports")
                  ),
                  JS.call_expression(
                    JS.identifier("factory"),
                    Enum.map(import_identifiers, fn x ->
                      JS.member_expression(
                        JS.identifier("root"),
                        x
                      )
                    end)
                  )
                )
              ])
            )
          )
        ])),
        [JS.this_expression(), JS.function_expression(import_identifiers, [], JS.block_statement(body ++ [JS.return_statement(exports)]))]
      )
    )
  end
end