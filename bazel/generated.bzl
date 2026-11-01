"""
    Public generated repo extension.
"""

def _generated_repo_impl(repository_ctx):
    repository_ctx.file(
        "visibility/BUILD.bazel",
        """package_group(
    name = "package_group",
    packages = ["//..."],
)
""",
    )

    # Set by `periphery scan --bazel` (--repo_env) to its per-user output directory. Without it, as when
    # building Periphery itself, the root package has no BUILD file and only the visibility package exists.
    output_path = repository_ctx.getenv("PERIPHERY_BAZEL_OUTPUT_PATH")
    if output_path:
        repository_ctx.symlink(
            output_path + "/BUILD.bazel",
            "BUILD.bazel",
        )

generated_repo = repository_rule(
    implementation = _generated_repo_impl,
)

generated = module_extension(implementation = lambda _: generated_repo(name = "periphery_generated"))
