load("//:erlang_app_info.bzl", "ErlangAppInfo", "flat_deps")
load("//:util.bzl", "path_join")
load(":util.bzl", "erl_libs_contents")
load(
    "//tools:erlang_toolchain.bzl",
    "erlang_dirs",
    "maybe_install_erlang",
)

def _impl(ctx):

    erl_libs_dir = ctx.attr.name + "_deps"
    erl_libs_files = erl_libs_contents(
        ctx,
        deps = flat_deps(ctx.attr.deps),
        dir = erl_libs_dir,
    )

    package = ctx.label.package

    erl_libs_path = path_join(package, erl_libs_dir)

    relx_path = path_join(erl_libs_path, "relx/ebin/")
    bbmustache_path = path_join(erl_libs_path, "bbmustache/ebin/")

    relx_path = path_join("bazel-out/k8-fastbuild/bin", relx_path)
    bbmustache_path = path_join("bazel-out/k8-fastbuild/bin", bbmustache_path)

    (erlang_home, _, runfiles) = erlang_dirs(ctx)

    rebar_config = ctx.attr.rebar_config.files

    output = ctx.actions.declare_file(ctx.attr.out)

    script = """set -euo pipefail


"{erlang_home}"/bin/erl \\
    -noshell \\
    -pa "{relx_path}" -pa "{bbmustache_path}" \\
    -eval "relx:build_tar(starlet,proplists:get_value(relx, element(2, file:consult(\\"./terminators/erlang/rebar.config\\"))))" \\
    -s erlang halt
    """.format(
        relx_path = relx_path,
        bbmustache_path = bbmustache_path,
        runfiles = runfiles.files,
        maybe_install_erlang = maybe_install_erlang(ctx),
        erlang_home = erlang_home,
        package = package,
    )

    ctx.actions.run_shell(
        command = script,
        inputs = erl_libs_files,
        tools = [rebar_config],
        outputs = [output],
        mnemonic = "ERLRELEASE",
    )


    return [DefaultInfo(files = depset([output]))]

erlang_release = rule(
    implementation = _impl,
    attrs = {
        "rebar_config": attr.label(
            mandatory = True,
            doc = "rebar.config file to use for release",
            allow_single_file = ["rebar.config"],
        ),
        "release": attr.string(),
        "deps": attr.label_list(providers = [ErlangAppInfo]),
        "out": attr.string(),
    },
    toolchains = ["//tools:toolchain_type"],
)