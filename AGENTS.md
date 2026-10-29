# Repository instructions

## Current product identity

The approved product is **رواق / Rewaq**. Read docs/rewaq-identity.md and docs/identity-baseline.json before UI, theme, native resource, documentation or build changes. Use shared BrandColors and the supplied RewaqLogo artwork. Never restore Sentrak display branding, Tajawal, or the previous blue primary palette from an older branch. Keep technical package/application identifiers stable.

## Starting and finishing work

- Fetch current remote state. Inspect the default branch, active branches, open PRs and recent commits before choosing a base. A default branch alone is not evidence that it includes the user's latest work.
- Check whether a newer identity or functional branch is missing from your base. Reconcile it before modifying the same areas. Preserve ongoing user/developer changes and report any unresolved conflict.
- Merge current product changes without replacing them wholesale with old copies. Review both parents and changed native resources.
- Run python3 tool/check_identity.py, formatting, Flutter analyze and relevant tests. Review new screenshots in light/dark modes before delivering a UI build.
- Build the APK from the exact intended commit. Report its SHA, app name and version. Never deliver an APK known to use an obsolete identity.
- Update the baseline only when the user explicitly authorizes changing the brand. Routine feature work must preserve it.
