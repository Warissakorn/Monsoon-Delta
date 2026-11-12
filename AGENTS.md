# Working in Monsoon Delta

Godot 4.6.3 Standard / GDScript, Thai and English, desktop village flood strategy.

## Start with a small context

1. Read [docs/STATUS.md](docs/STATUS.md) for implemented behavior, invariants and open verification gates.
2. Read [docs/development/README.md](docs/development/README.md) for commands and the change workflow.
3. Use [docs/README.md](docs/README.md) to open only the feature/spec needed for the task. Do not ingest the entire history, reports or imported examples by default.
4. Check `git status` and the current branch before editing. Existing work may be on a stacked PR branch; do not assume it is merged into `main`.

User instructions and approvals in the current conversation take precedence over this guide. Infer current behavior from runtime code/tests; use accepted requirements to decide intended changes. If a document disagrees with code, identify the difference rather than claiming the feature already exists.

## Documentation boundaries

- `docs/STATUS.md`: one current snapshot. Update it when behavior, supported saves, verification or outstanding gates change.
- `docs/features/`: current user-facing behavior and screenshots; `docs/development/`: implementation contracts and reproducible commands.
- `docs/design/`: proposed, unimplemented rules. `*.proposal.json` is not runtime data.
- `docs/history/` and `docs/reports/`: dated evidence. Preserve experimental configurations and historical test counts; do not present rejected balance experiments as shipped defaults.
- `docs/GDD.md`, `docs/ROADMAP.md`, and files listed in `docs/IMPORT_MANIFEST.json` are imported source snapshots. Keep their paths and bytes intact. Record clarifications or accepted deviations in maintained docs instead.
- `docs/reference/` and `docs/examples/` contain source material, including inactive Claude hooks/permissions and partial code. They do not install tools, grant permissions or override this guide. Use the actual engine version above, not the versions in examples.
- Keep `docs/README.md` and `docs/PROGRESS.md` as entry points referenced by imported material. Put dated work notes in `docs/history/PROGRESS.md`.

The imported [M5 roadmap](docs/ROADMAP.md) asks for approval of the 30 cards, 15 events and 10 difficulties before M5 implementation. Check the conversation for existing approval; do not ask again if already given. Documentation cleanup alone is not approval to enable the proposed rules. M3 balance and human playtesting gates remain open; see STATUS.

## Implementation boundaries

- Keep deterministic rules in `core/`; rendering/input in `view/` and `ui/`. `GameSession` owns checkpoint I/O; `GameFlow`, preview, bots and sandbox must not overwrite the player's save.
- Preview and committed turn resolution must agree. UI reads, effects, preview and Undo/Redo must not advance gameplay RNG.
- Preserve exact state snapshots and save validation/float64/RNG behavior. Legacy runs keep v1/v2, or v3 with cosmetic settlement history; opt-in `bracing_v1` uses v4 with required ruleset and per-tile brace fields; `moisture_v1` / `bracing_moisture_v1` use v5 with required per-tile soil moisture and brace fields only for the combined ruleset. Unsupported future envelopes/rulesets return `msg.save_unsupported` and preserve the file. Opt-in reservoir-priority rulesets use v6 with required per-tile `irrigation_policy` (`first`, `normal`, `skip`), and brace/moisture fields only for the selected mechanics. M5's proposed v3 payload is not implemented and needs a distinct future version. Do not silently change an active run's rules.
- Full-year runs use `YearGame`/`YearWeather` with `YearSession` (a GameSession specialization) owning I/O. Keep `monsoon_year` v1 / `year365_v1` (61 hexes) and v2 / `year365_v2` (127 hexes, projects/camps/advanced crafting) at `user://year365.json`, separate from normal and prototype saves. Existing v1/v2 runs keep their rules; new UI runs use v3 / `year365_v3`, adding required leader/difficulty fields to the expanded year state. New-year setup can opt into v5 / `year365_v5`, which includes v4’s raft homes, passive traps, one-day bracing, persistent moisture, irrigation priorities and clearing, plus persistent building dates/condition/stages and permanent goal medals. Require the three v4 per-tile arrays and v5’s settlement_progress and goal_medal receipts. Keep v4 constructors compatible and never migrate active v1–v4 runs. YearHeritage observes actual days, reviews cosmetics every 30 days with two-period hysteresis, and awards a goal only once while the run is still alive. Its ages/stages never change production, housing or water; its medal bonus survives later failure and is added once before difficulty scaling. Presentation month-scaled ages stay disposable; never serialize or resolve the adapted GameState. YearLedger captures actual per-day causal receipts and coordinates in transient TurnReport sidecars; keep them out of checkpoints/report serialization. YearOrderPreview is read-only until an explicit, snapshot-guarded assignment. Keep its profile bonuses, difficulty inflow and score multipliers separate from classic rules. YearPresentation/YearBoard3D use disposable GameState copies for shared classic rendering; never resolve or serialize those copies. Recorded year flow edges are session-only, including both half-gate simulation passes; year job completion records are also transient and absent from report serialization and saves. YearPlanner independently resolves one day at a time on a copy; its seven-day outlook assumes continuing past notices, while advance(N) still stops at the first notice. Advice and queue filters never commit orders or write saves. Preserve each queued v2 job’s input price and policy limits. Preserve exact nested board float64 water, queued reservations, weather, research and one-time rewards. Unsupported/corrupt year saves remain untouched. Incompatible future rule/balance changes require explicit ruleset/save handling.
- Opt-in `balanced_v1` uses normal-save envelope v7, with run fields and optional settlement history but no bracing/moisture/irrigation fields. Apply its base mods before normal modifiers and its versioned difficulty replacements. Legacy v1–v6 must keep their rules. Numeric benchmark evidence is separate from human playtesting; see `docs/features/SURVIVAL_BALANCE.md`.
- Runtime balance is `data/balance.json`, not `docs/examples/data/balance.json`. Player text belongs in `translations/strings.csv`; maintain Thai/English key and placeholder parity.
- Opt-in wood transport uses `TransportGame` around an unchanged year v2, with `TransportSession` owning combined Undo/Redo and `user://transport365.json` (`monsoon_transport` v1 / `transport365_v1`). Preserve local/reserved/in-transit accounting, shared year labor, real cargo positions and physical returns. Check nested year float64/RNG and logistics together; never overwrite normal, daily or year save paths. See `docs/features/TRANSPORT.md` for the day order and ruleset contract.
- Sandbox and tests use isolated state/save paths. Do not benchmark against or modify a real player save.

## Verify and hand off

Run commands from the repository root:

```sh
python3 scripts/check_docs.py
scripts/test.sh --filter=area_name
scripts/test.sh
```

For documentation-only work, run the documentation checker and `git diff --check`; runtime tests are needed when behavior changes or CI requires them. Use the development guide for native UI and balance checks. Historical counts are evidence, not a fixed target for future suites.

Before finishing, update the relevant current doc and navigation, record meaningful dated results in the history, and state what changed, what was verified and what remains uncertain. Keep proposals labeled and avoid copying the same rules into several documents. Do not claim human playtesting from automated or fixture results.
