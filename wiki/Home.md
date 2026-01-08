# Jasco-mods

This repository documents Jasco customizations that are implemented outside of the core Manhattan codebase. It exists to make each customization explicit, discoverable, and easy to evaluate during upgrades.

Purpose:
- Capture what was customized, why it exists, and where the implementation lives.
- Help answer the questions: "Do we still need this customization?" and "What is related to this customization?"

What this repo contains:
- Per-area folders (for example `JP1/`, `JP2/`) with SQL, scripts and README files describing each mod.
- Images and screenshots that show before/after UI or config examples.

How to use this repository during upgrades:
1. Open the folder for the affected area (e.g., `JP2/`) and read the README to understand business purpose and technical changes.
2. Review the stored-proc or script files referenced in the README to see exactly what was changed.
3. Decide whether the customization is still needed or can be replaced by a product feature.

Guidance for each customization README (what to include):
- Business purpose and owner
- Exact files changed or added
- How the customization is invoked (e.g., ODWS step, scheduled job)
- Any UI/config screens to maintain (screenshots recommended)

## Customizations

- [[JP1 Custom Views Update]]
- [[JP2 Case Label Customers ODWS Mod]]
