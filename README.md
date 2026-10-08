# Neat Examples

This repository is a maintained incubator for SiMa Neat application examples.
It provides a place to develop, document, and validate examples independently
before proposing mature versions for the official
[`sima-neat/apps`](https://github.com/sima-neat/apps) repository.

This is not the official Neat examples repository. Examples here may explore
new workflows, depend on development software, or use temporary platform
workarounds. Each example documents its own prerequisites, supported versions,
security considerations, and validation status.

## Examples

| Directory | Description | Languages | Status |
| --- | --- | --- | --- |
| [`yolo26-container`](yolo26-container/) | Build and run YOLO26 Neat applications as Python or C++ containers on a Modalix DevKit | Python, C++ | Validated development example |

## Repository structure

Each top-level example is self-contained and should include:

- a README with setup, build, run, inspection, and cleanup instructions;
- source code that uses the public Neat API;
- pinned or clearly documented external asset requirements;
- documented compatibility assumptions and known limitations; and
- ignore rules that keep models, credentials, generated builds, and reports out
  of source control.

Shared infrastructure may be added later when two or more examples genuinely
benefit from it. Until then, examples favor explicit, local commands so they
remain easy to understand and move upstream independently.

## Using an example

Start with the README in the selected directory. Neat examples commonly
require:

- a compatible Neat SDK and Modalix DevKit;
- `sima-cli` authentication and SDK-to-DevKit pairing;
- Docker and Buildx on the development host;
- Docker configured on the DevKit; and
- model or media assets downloaded separately from source control.

Versions and additional hardware requirements vary by example. Do not assume
that an example validated against one SDK or platform release is compatible
with every release.

## Example lifecycle

Examples generally move through these stages:

1. Incubate the application and developer workflow in this repository.
2. Validate it on the documented SDK and hardware configuration.
3. Refine its API usage, error handling, security posture, and documentation.
4. Propose it for the official `sima-neat/apps` repository when it is ready for
   broader support.
5. Mark or remove the incubator copy after an upstream version becomes the
   maintained source of truth.

## Contributions

Keep changes scoped to one example whenever possible. Do not commit model
packages, generated binaries, container layers, credentials, private registry
tokens, or benchmark output. When changing runtime behavior, update the
example README with any relevant SDK, Neat, or platform compatibility details.

## License and third-party software

Repository source is licensed under the [MIT License](LICENSE). Model packages,
SiMa software, platform libraries, and other downloaded or bundled artifacts
are not relicensed by this repository and remain subject to their respective
terms. Confirm redistribution rights before publishing container images that
include third-party or SiMa runtime components.
