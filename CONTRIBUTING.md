# Contributing to Better Than Dato

Thanks for helping! This is a small app with a clear goal: a calm, native menu bar calendar that does a few things
well. Contributions that keep it that way are very welcome.

## Ways to contribute

- **Report a bug.** Open an issue with your macOS version, the app version (Settings → General → Updates), what you
  did, what you expected and what happened. Screenshots help. Please don't paste real calendar entries or other
  people's names or addresses; describe them or use made-up ones.
- **Suggest a feature.** Open an issue describing the problem it solves before writing code. Features that need
  their own sign-in to a calendar provider, or that recreate something macOS already does natively, are usually
  out of scope.
- **Send a pull request.** Bug fixes, new meeting providers, small focused features, documentation and tests.

## Getting started

1. Fork the repository and clone your fork.
2. Follow the setup in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Xcode is optional; the Command Line Tools are
   enough.
3. Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) to see where your change belongs.
4. Create a branch: `feat/short-description` or `fix/short-description`.

For anything bigger than a small fix, open an issue first so we can agree on the approach before you invest time.

## How we build things

These keep the app reliable and easy to change. Reviews check them.

1. **Behavior lives in `DatoCore`, with tests.** Anything that decides *what* to show or *when* something happens
   is a pure function or value type in `Sources/DatoCore`, tested in `Tests/DatoCoreTests`. The app target only
   fetches, stores and renders.
2. **Test first.** Write a failing test, watch it fail for the right reason, then make it pass.
3. **No hidden clocks.** DatoCore code takes `now` and `calendar` as parameters; never call `Date()` or
   `Calendar.current` there.
4. **EventKit stays in `CalendarService`.** Map to DatoCore's value types at the boundary.
5. **Native first.** Prefer what macOS provides over custom imitations.
6. **Match the surrounding code.** Small focused files, comments that explain *why*, no unused code.
7. **Fictional data only** in tests, docs, screenshots and the demo.

[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) walks through two complete examples (adding a meeting provider, adding
a setting).

## Commits

Small commits that each do one thing, with a prefix that says what kind of change it is (the existing history
follows this):

| Prefix | For |
|---|---|
| `feat:` / `feat(core):` / `feat(app):` | New behavior (core = DatoCore, app = app target) |
| `fix:` | Bug fixes |
| `docs:` | Documentation, demo video |
| `build:` / `chore:` | Scripts, packaging, housekeeping |

Explain *why* in the commit body when it isn't obvious from the diff.

## Pull request checklist

- [ ] `scripts/test.sh` passes, and new behavior has tests.
- [ ] `scripts/build-app.sh debug` succeeds.
- [ ] You ran the app (`scripts/run.sh`) and checked the affected parts of [docs/qa-checklist.md](docs/qa-checklist.md).
- [ ] UI changes include a screenshot in the PR description.
- [ ] README / ARCHITECTURE / DEVELOPMENT are updated if behavior, setup or structure changed.
- [ ] No real personal data anywhere in the diff.

If your change affects what the demo shows, mention it; the maintainer re-renders `docs/demo.mp4`
(`scripts/make-demo-video.sh`) before the next release.

## Releases

Maintainers publish releases with `scripts/release.sh <version>` after merging. Installed copies update themselves.
You don't need to bump versions in your pull request.

## Be kind

Assume good intent, keep feedback about the code, and help newcomers find their way. That's the whole code of
conduct.
