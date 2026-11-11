# AGENTS.md — Starforge NixOS

## Mission

Work on Starforge as a dependable, understandable NixOS workstation configuration. The goal is not merely to make the flake evaluate: people using the configuration should be able to understand what they can customize, diagnose common problems, and recover safely when something goes wrong.

This guide gives particular priority to:

1. **User configuration and customization** — make supported choices discoverable and safe to change without requiring users to understand the repository's internal module structure.
2. **Diagnostics and recovery** — explain system state and failures clearly, provide safe next steps, and preserve reliable recovery paths.
3. **Atomic, complete work** — do not leave silent half-implementations. A task must be completed as a coherent change or explicitly handed off at the exact place where work stopped.

These priorities do not authorize unrelated architectural rewrites or changes to the machine's security posture.

## Current project context

Treat the checked-out repository as the source of truth. At the time this guide was written, the project documentation describes the following layout and boundaries:

- `flake.nix`, `flake.lock` — flake inputs, pinned dependencies, formatter, development shell, and the `workstation` NixOS output.
- `hosts/workstation/` — the current machine-specific host profile. Its generated `hardware-configuration.nix` is a local, Git-ignored file prepared by `install.sh`.
- `modules/nixos/` — reusable system-level NixOS modules.
- `home/` — Home Manager modules for the workstation user; the login name is configured once through `starforge.user.username` in `hosts/workstation/default.nix`.
- `terminal-dotfiles` — a separate pinned input and the source of truth for terminal configuration and package manifests. Do not duplicate or take ownership of those files in Starforge.
- `docs/security-audit.md` — documented security-audit procedure.
- `nixcfg audit` — the existing documented, read-only security diagnostics entry point. Inspect its actual implementation and ownership before extending or changing it.

The current documented flake output is `nixosConfigurations.workstation`. The repository is presently a workstation-specific configuration, not a generic multi-host installer or a collection of finished user profiles.

**Verify all paths and names in the current checkout before relying on this context.** Repository layout, command ownership, and implementation details may have changed since this guide was written.

## Non-negotiable working principles

### 1. Atomicity and completion

Atomicity is a hard requirement, not a stylistic preference.

- A logical change must be delivered as a complete, coherent unit. Its configuration, implementation, integration, documentation, and relevant validation must agree.
- Do not add a visible setting that has no effect, a command that only partially works, a diagnostic check that cannot produce a meaningful result, or a recovery instruction that cannot be followed.
- Do not leave stubs, placeholder implementations, fake success messages, commented-out unfinished code, or TODO-only substitutes for requested functionality.
- Do not mark a task complete merely because some files were changed. Completion means the promised behavior exists and the relevant checks have been performed, or the remaining validation is explicitly disclosed.
- Prefer small vertical slices. If a large feature can be split into independently useful steps, implement and validate one complete step at a time rather than scattering half-finished pieces across the repository.
- Before finishing, inspect the complete diff for dangling references, dead options, unconnected settings, obsolete documentation, and work that was started but not completed.

**Default rule: either finish the change or do not leave the incomplete implementation behind.** If the work cannot be completed safely, revert the unfinished portion and report the blocker. Do not make an unfinished feature look implemented.

#### Exception for genuinely large or interrupted work

If a change is too large to finish in one pass and some work must remain in the working tree, the agent must leave a precise handoff **at the exact location where the work stopped**. A final chat summary or a generic entry in a distant TODO file is not sufficient.

At the nearest relevant code, module, script, or documentation section, add a clearly labelled note in this form:

```text
TODO(STARFORGE — INCOMPLETE): <short description>

Implemented:
- <specific behavior that is already complete>

Still required:
- [ ] <specific missing implementation or integration>
- [ ] <specific documentation or validation still required>

Next step:
- <concrete instruction for the next agent, including the relevant file/function/option>

Validation not yet completed:
- <exact command or manual check that remains>
```

Adapt the syntax to the file type (`#`, `//`, `/* */`, or an inline Markdown note). Keep the note adjacent to the unfinished implementation or directly inside the incomplete documentation section. Do not put it only in this root file, a PR description, or the final response.

Additional rules for an interrupted large change:

- Leave the repository in the most coherent and buildable state reasonably possible.
- Mark the unfinished area visibly as incomplete; never leave it looking production-ready.
- State what is already working and what is not. Be specific enough that another agent can continue without reconstructing the previous agent's intent.
- Include the exact next action and the validation still needed. “Finish this later” is not an acceptable handoff.
- Do not add fake defaults or silently disable a feature to hide the unfinished integration.
- If even a coherent partial state cannot be maintained, revert the incomplete change and leave the handoff in the relevant task document or issue instead.

### 2. Preserve declarative ownership

- Nix and Home Manager configuration are the source of truth for managed system and user settings.
- Do not edit generated runtime files under `/etc`, `$HOME/.config`, or other managed targets as a substitute for changing their declarative source.
- Do not introduce imperative configuration drift, one-off shell mutations, or runtime patching when the setting belongs in Nix.
- Do not create two competing owners for the same setting. Before adding a setting, find the current owner and extend that source of truth.
- Keep system-wide policy in NixOS modules and user-session preferences in Home Manager where appropriate.
- Preserve the separate `terminal-dotfiles` ownership boundary.

### 3. Understand before changing

Before implementing a feature:

1. Read the relevant module, its imports, and the current documentation.
2. Trace where the option is declared, how it is consumed, and which layer owns it.
3. Check whether the requested behavior already exists under another command or module.
4. Verify NixOS and Home Manager option names against the locked project inputs or authoritative documentation. Never invent option names based on memory.
5. Identify security, boot, hardware, and recovery implications before touching those areas.
6. Define the expected behavior and the validation required before editing.

Do not use a speculative redesign to avoid understanding the existing implementation.

## User configuration and customization

### Goal

A user should be able to discover supported personal settings and change them without editing unrelated system internals. Make the supported customization surface explicit, documented, and consistent.

### Ownership boundaries

Use the existing project boundaries unless there is a demonstrated reason to change them:

- `hosts/workstation/` owns machine-specific facts and hardware-dependent configuration.
- `modules/nixos/` owns reusable system-level behavior and system-wide policy.
- `home/` owns user-session and Home Manager settings; do not hard-code the login name in Home Manager modules.
- `terminal-dotfiles` owns terminal packages, terminal configuration, and its manifests.

Do not move a setting merely to make the directory structure look cleaner. Change ownership only when the current boundary causes a real maintenance or UX problem, and update every affected reference and document in the same complete change.

### Rules for adding user-facing options

- Prefer a small, clearly named, typed Nix option over asking users to edit implementation details in several files.
- Every public option must have a meaningful description and a safe, unsurprising default.
- Explain where the option belongs, what it changes, whether it requires rebuild/re-login/reboot, and any limitations.
- Keep related options together; avoid creating a large, arbitrary settings namespace with no concrete use case.
- Reuse existing options and settings where possible. Do not create aliases or duplicate controls for the same behavior.
- Keep hardware facts out of personal preference settings. A theme choice must not change hardware configuration; a GPU or storage requirement must not be presented as a cosmetic preference.
- Use Home Manager for per-user preferences when that is the natural owner. Use NixOS options for machine-wide services, drivers, system security, and other system policy.
- Do not require users to edit generated configuration files or files owned by another repository.
- Do not make customization bypass security controls, weaken safe defaults, or silently enable privileged services.
- Document dependencies and incompatibilities. If an option is meaningful only when another feature is enabled, express and validate that relationship instead of silently ignoring the setting.
- Avoid unsupported claims such as “works on any hardware” or “generic profile” while the repository remains tied to the current workstation.

### Scope discipline

Do not introduce a generic multi-host architecture, profile selector, configuration wizard, or a speculative option namespace as part of an ordinary customization task. Such work requires a concrete user need, a design that matches the actual supported use cases, and an explicit task to broaden the project's scope.

Do not add illustrative or hypothetical options (for example, a `gaming.enable` switch) as though they already exist. If proposing a future option, label it as a proposal and do not wire it into the live configuration until its behavior and ownership are defined.

### Documentation requirements

When adding or changing a user-facing option, update the relevant documentation in the same change. State:

- the exact option name and where it is configured;
- its default and accepted values;
- what it controls and what it does not control;
- whether it affects NixOS, Home Manager, or an external component;
- how to apply the change safely;
- any known hardware, session, or service prerequisites.

Examples must use real option names from the repository. Keep examples copyable and syntactically valid.

## Diagnostics and recovery

### Diagnostics must be safe by default

Diagnostics should explain system state, not change it.

- All status, health, audit, and doctor-style commands must be read-only by default.
- Do not restart, enable, disable, install, remove, reconfigure, rebuild, roll back, or kill services/processes from a diagnostic path.
- Do not require root for checks that can run unprivileged. If a check genuinely requires privileges, explain why, isolate it, and handle unavailable permission as a distinct result rather than failing the entire report.
- Never request, print, upload, or include secrets, private keys, tokens, passwords, recovery keys, or full sensitive configuration values in diagnostic output.
- Avoid dumping complete journals, environment variables, command lines, or configuration files when a narrow status or redacted excerpt is sufficient.
- A failed or unavailable diagnostic probe must not be reported as a healthy result.
- A feature that is intentionally disabled or not installed must not be reported as broken merely because its service or binary is absent.

### Make diagnostic results actionable

Use consistent, machine-readable internal result states and clear human-readable output. At minimum, distinguish:

- `OK` — the expected condition was verified;
- `WARN` — degraded, unusual, or potentially unsafe condition that does not prove immediate failure;
- `ERROR` — a required component or expected behavior is failing;
- `SKIP` / `N/A` — check does not apply because the feature is disabled, absent by design, unsupported, or not relevant to this host;
- `UNKNOWN` — the check could not establish the state (for example, missing permissions or unavailable tooling).

Do not collapse `UNKNOWN`, `SKIP`, and `ERROR` into the same result.

Each warning or error should, where possible, include:

1. **What was checked** — the exact component or expected condition.
2. **What was observed** — concise evidence, not an unbounded log dump.
3. **Why it matters** — the practical impact in plain language.
4. **What to do next** — a safe, concrete command or documentation link.
5. **Whether the action is read-only or changes the system** — never blur the distinction.

Use stable exit-code semantics for automation. Document them before exposing a command as a supported interface. Human-readable output should remain useful when color is unavailable or output is redirected.

### Extend existing diagnostics before adding a new interface

The project README currently documents `nixcfg audit` as a read-only security audit. Before adding a health checker, doctor command, or GUI diagnostic view:

- inspect where `nixcfg` comes from and which repository owns it;
- identify which checks already exist and avoid duplicate probes;
- decide whether a new check belongs in the existing audit, a separate health/status command, or documentation;
- preserve the existing command and its semantics unless a migration is explicitly requested;
- do not rename it to `starforge doctor` or invent a new CLI surface merely because that name appeared in a proposal.

Security auditing and general system health are related but not identical. Keep their scopes and severity semantics clear.

### Check real system state, not assumptions

- Check only services, binaries, devices, and features expected on the current host or explicitly enabled by configuration.
- Distinguish a failed unit from an inactive, disabled, masked, missing, or intentionally unused unit.
- Do not infer that a service is required merely because a package is installed.
- Do not assume a particular GPU, network interface, audio device, or peripheral exists unless the hardware profile or runtime probe establishes it.
- Keep checks bounded and resilient: a missing utility or a single inaccessible subsystem must not abort unrelated diagnostics.
- Avoid noisy warnings for expected conditions. A diagnostic that constantly cries wolf will be ignored.

### Recovery must be explicit and conservative

Recovery guidance must preserve user control and avoid destructive surprises.

- Prefer explaining the built-in NixOS generation and boot-menu recovery paths before inventing a custom rollback mechanism.
- Explain the difference between testing a generation, making it the default, and rolling back to a previous generation.
- Do not automatically activate a generation, switch boot entries, delete generations, garbage-collect rollback targets, or rewrite bootloader configuration.
- Do not automate Secure Boot key creation/enrollment, LUKS key changes, partitioning, formatting, filesystem repair, or disk-layout changes.
- Never treat a Btrfs snapshot on the same physical disk as an independent backup. State the limits of snapshots and the need for separate backups where relevant.
- Do not imply that a rollback can recover user data that was never backed up or reverse irreversible external actions.
- Recovery instructions must be specific to the actual bootloader, encryption, filesystem, and host profile. Do not copy generic commands that could target the wrong disk or configuration.
- For a proposed recovery action that changes system state, show the impact and require an explicit user decision. A diagnostic command must never silently turn into a repair command.

### Recovery documentation

For each newly documented failure path, include:

- the symptom and how to confirm it;
- prerequisites and any required access to the boot menu or recovery environment;
- the exact supported recovery steps for this host;
- expected effects and limitations;
- a verification step after recovery;
- a warning for operations that can affect bootability, encryption, storage, or user data.

Do not publish speculative recovery steps as tested procedures. Label untested procedures clearly.

## Security and hardware guardrails

The project contains machine-specific storage, bootloader, Secure Boot, encryption, and security configuration. Treat these as high-risk areas.

- Do not change disk UUIDs, partition identifiers, mount layout, LUKS settings, Btrfs subvolumes, or generated hardware configuration as collateral cleanup.
- Do not alter bootloader behavior, Secure Boot signing/enrollment, firmware security settings, or recovery keys without an explicit task and a verified recovery plan.
- Do not weaken firewall, AppArmor, USBGuard, sudo, kernel, audit, or sandbox policy to make a feature easier to implement.
- Do not add broad privileges, root execution, writable system paths, or blanket service exemptions where a narrow solution is possible.
- Preserve the existing security caveats and documented limitations. Do not turn an observed status into a stronger security guarantee than the evidence supports.
- Do not run `nixos-rebuild switch`, perform a deployment, or apply changes to the live workstation unless explicitly requested. Building/evaluating a configuration is not the same as activating it.
- Do not modify secrets or copy sensitive host details into examples, logs, issues, or public documentation.

## Nix implementation and validation

- Follow the existing formatting and module conventions. Do not reformat unrelated files.
- Keep `flake.lock` unchanged unless dependency updates are part of the task. Review lock-file changes deliberately.
- Do not change `system.stateVersion` as a routine maintenance action.
- Treat `hosts/workstation/hardware-configuration.nix` as local machine data: never commit it or copy its device identifiers/UUIDs into public docs. `install.sh` copies `/etc/nixos/hardware-configuration.nix` when present; otherwise, it asks before generating the local file. Preserve it during unrelated changes.
- Verify new option names against the project's locked Nixpkgs/Home Manager sources or authoritative upstream documentation.
- Prefer evaluation and build checks over assuming that syntactically valid Nix is operationally correct.

Use the repository's documented checks when applicable. The README currently describes these local validation steps:

```sh
mapfile -t nix_files < <(git ls-files "*.nix")
nix fmt -- "${nix_files[@]}"

nix develop path:.#default
for nix_file in "${nix_files[@]}"; do
  statix check "$nix_file"
done
deadnix --fail "${nix_files[@]}"

nix flake check path:. --no-build --no-update-lock-file --show-trace
nix build path:.#nixosConfigurations.workstation.config.system.build.toplevel --no-link
```

Adjust commands only when the current repository has changed. Do not claim that a check passed unless it was actually run and its exit status was inspected. If a check cannot be run, state exactly which check was skipped and why.

For changes affecting desktop behavior, a successful Nix build is necessary but not sufficient. Document the required runtime checks (for example: session startup, Niri behavior, Noctalia, portals, audio, display handling, or the relevant service) and distinguish checks actually performed from checks that still require the user's machine.

## Required workflow for every task

1. **Scope** — restate the requested behavior internally and identify explicit non-goals. Do not broaden the task.
2. **Inspect** — read the relevant source, imports, documentation, and current tests. Confirm ownership and existing behavior.
3. **Plan** — identify the smallest complete implementation and define acceptance criteria.
4. **Implement atomically** — finish the full vertical slice. Keep changes localized and avoid unrelated refactoring.
5. **Document** — update user-facing documentation when behavior, options, commands, defaults, limitations, or recovery steps change.
6. **Validate** — run the narrowest relevant checks, then broader repository checks when feasible. Inspect exit codes and output.
7. **Review the diff** — look for partial integrations, duplicate ownership, unsafe side effects, accidental lock-file changes, unrelated formatting, and missing documentation.
8. **Handoff honestly** — report what is complete, what was tested, what was not tested, and any remaining work. If work is incomplete, put the required continuation note next to the unfinished code or documentation as specified under Atomicity and completion.

## Definition of done

A task is done only when all applicable conditions are true:

- The requested behavior is implemented end-to-end, not merely scaffolded.
- The new or changed configuration has one clear declarative owner.
- Defaults, interactions, prerequisites, and limitations are intentional and documented.
- Diagnostics are read-only by default and do not misclassify expected absence as failure.
- Recovery guidance is accurate for the current host and does not overstate what can be recovered.
- Relevant evaluation, formatting, static analysis, build, and runtime checks have been run or explicitly listed as not run.
- No silent unfinished implementation, dangling reference, placeholder, or unexplained TODO remains.
- Any unavoidable incomplete work has a concrete, co-located handoff note describing exactly what remains and how to continue.

## Final response format for agents

Keep the final report concise and factual. Include:

- **Completed:** user-visible behavior and files changed.
- **Validation:** exact commands/checks run and their results.
- **Not verified:** runtime or hardware checks that could not be performed.
- **Remaining work:** only if something is genuinely incomplete; point to the co-located handoff note.

Never report partial work as complete. Never hide a blocker behind optimistic wording.