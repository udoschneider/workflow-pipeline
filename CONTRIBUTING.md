# Developing this package

The pipeline was extracted from a working private codebase, which is now one of its consumers. That shape — the package is upstream, every project including its birthplace is downstream — decides how changes get made.

## The rule that makes the rest follow

**Fix in the package. Never in a consumer.**

A consumer's copy of the spec and the skills is an *installed artifact*, replaced wholesale by the next update. Edit one in place and the change survives until someone reinstalls, then vanishes — silently, and usually not for the person who made it. That is not a discipline problem; it is what "installed" means.

Consumers are encouraged to enforce this rather than remember it. The reference consumer checksums each installed file and fails its build on a local edit, with a message naming the two legitimate destinations:

- true in any project → **upstream, here**
- true only there → **that project's `project/workflow/README.local.md`**

If you find yourself wanting to edit an installed file, one of those two is the answer. There is no third.

## The loop

Bugs surface in consumers. Fixes happen here. Verification happens in both.

1. **Observe in the consumer.** Symptoms are agent-behavioural as often as they are mechanical — a skill that reads a stale index, a `/name` that resolves nowhere, an instruction whose one required argument is unstated.
2. **Reproduce here.** Most defects reproduce against a scratch install; `test.sh` builds throwaway repositories for exactly this. If it reproduces, the consumer is no longer needed for the fix.
3. **Fix, then `./test.sh`.**
4. **Install into the consumer from your working copy** — not from a clone:
   ```sh
   ./install.sh /path/to/consumer
   ```
   `install.sh` resolves the package root from its own location, so it installs whatever is on disk, committed or not. **Push is not in the inner loop.** Iterate against the working copy; push when the fix is real.
5. **Push, then update the consumer for real** and run the consumer's own gate. A consumer that pins by checksum needs its recorded hashes refreshed as part of that step.

### Pull before you update a consumer

If a consumer installs from a local clone of this package rather than from the remote, **update that clone first, every time.** The install takes whatever is on disk; a stale clone therefore produces a consumer that is *internally consistent and silently out of date*.

That combination is the dangerous one. A consumer pinning by checksum will pass its own gates afterwards — the recorded hash matches what was installed, which is the only thing it checks. Nothing compares the installed version against upstream, so there is no signal at all.

Observed: a consumer ran for a day on a generator missing two fixes, with every gate green, because the fidelity check it did have compared generated *output* — and the missing fixes changed side effects, not output.

### Which repository to open a session in

**This one, by default.** Nearly all editing happens here, this is where `test.sh` runs, and you can install into a consumer from here at any point.

**A consumer, when the bug only exists in context.** "The agent didn't do X" needs that project's own instructions and its real corpus to reproduce. Observe there; carry the finding back here to fix. That is a diagnosis/fix split, not a development split — the fix still lands here.

Running it the other way around — rooted in a consumer, treating the package as a side target — works but fights you: every package operation needs absolute paths, and a consumer's own tooling (worktree isolation, sandboxing) may refuse commands that reach outside it.

## Verifying a change

`./test.sh` — bash and python3 only, no install step. It gates identity, portability, scaffold integrity, and generator behaviour, and it will tell you when a check **skipped** rather than folding that into a pass.

Two of its properties are worth understanding before you add to it:

- **The delivery check runs `install.sh` and inspects the result**, rather than grepping its source. An earlier version asserted two things textually — *every skill has a command file* and *the installer copies everything in `root/`* — and an entire directory fell into the space between two rules that were each individually green. Behavioural checks have no between.
- **The identity check reports `SKIPPED` on a fresh clone.** It reads `.identity-denylist`, which is deliberately not committed: publishing the list of names this package must never ship would publish exactly those names. If you maintain this package, copy `.identity-denylist.example` and fill it in. If you only consume it, that check is not yours to run — you have nothing to leak.

## Auditing before a release

Read the package cold, more than once, and preferably across model families.

Blind reads of this package by two different models found **disjoint** severe defects — each missed something the other caught — and two runs of the *same* model disagreed on their top finding. One clean pass is weak evidence, not a result.

What worked: a fresh clone, no context beyond the directory, and four questions —

1. Where could you not proceed?
2. What terms are used before being defined?
3. What is asserted that you cannot check?
4. **What did you misread first?**

The fourth has the highest hit rate by a wide margin. It surfaces the places a document actively misled a reader, which are strictly worse than the places it merely omitted something — and they are invisible to anyone who already knows the system.

## Things that keep going wrong

Each of these has cost a release. They are listed because knowing about a trap is demonstrably not the same as avoiding it.

- **Dotfiles do not survive packaging.** Three separate tools have silently dropped them — two search tools defaulting to skip, and a package manager's `**/*` glob. The scaffold and the ignore rules are therefore *written by the generator when absent* rather than carried as `.gitkeep`-style files. Prefer removing the dependency over defending each site; you cannot enumerate the tools that will handle this package.
- **One agent's conventions are not the neutral case.** Skills being invocable as `/name`, hooks existing, `CLAUDE.md` being *the* instructions file — each is false somewhere, and each failed silently when assumed. Ship for the agent you don't have.
- **The spec must not name a tool this package doesn't ship.** A close-out skill reads the spec to learn its obligations; the spec naming that skill back inverts the dependency and turns a pipeline rule into something that looks like one project's tooling. `test.sh` enforces this.
- **A packager's safe default can be fatal for this package.** OpenPackage defaults to `--conflicts namespace`: on a collision it installs alongside your file under a prefixed name rather than replacing it. That is a reasonable default for a package whose contents are addressed by name, and wrong for this one, where the spec, the skills and the generator all reference each other by path. The install reports success, every internal reference breaks, and the consumer keeps reading its own outdated copy. It only reproduces on a consumer that already has these files — so a greenfield test will never show it, and the consumers it hurts are exactly the ones migrating from an older copy.
- **Writing for someone who already knows the system.** The recurring failure mode, and the hardest to self-detect. It looks like undefined jargon, references to files only you can open, and instructions whose one required argument is left implicit.
