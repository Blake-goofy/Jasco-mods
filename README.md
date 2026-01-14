# Jasco-mods

This repository documents Jasco customizations that are implemented outside of the core Manhattan codebase. It exists to make each customization explicit, discoverable, and easy to evaluate during upgrades.

For detailed explanations of each mod please visit the [wiki](https://github.com/Blake-goofy/Jasco-mods/wiki).

## Purpose
- Capture what was customized, why it exists, and where the implementation lives.
- Help answer the questions: "Do we still need this customization?" and "What is related to this customization?"

## Available Mods
- **JP1** - [DIF insight](https://github.com/Blake-goofy/Jasco-mods/wiki/JP1-DIF-insight) - Enhanced DIF message views with message type filtering
- **JP2** - [Case label customers ODWS](https://github.com/Blake-goofy/Jasco-mods/wiki/JP2-Case-label-customers-ODWS) - Automated case label generation for specific customers
- **JP3** - [UD1 preserve](https://github.com/Blake-goofy/Jasco-mods/wiki/JP3-UD1-preserve) - Preserve USER_DEF1 values during inventory operations
- **JP4** - [Wave insight](https://github.com/Blake-goofy/Jasco-mods/wiki/JP4-Wave-insight) - Enhanced wave view with container estimates and validation flags
- **JP5** - [Freight terms change](https://github.com/Blake-goofy/Jasco-mods/wiki/JP5-Freight-terms-change) - Automatic cleanup of third-party accessorials
- **JP6** - [Carrier change](https://github.com/Blake-goofy/Jasco-mods/wiki/JP6-Carrier-change) - Logging for carrier and carrier service changes
- **JP7** - [Order ready email](https://github.com/Blake-goofy/Jasco-mods/wiki/JP7-Order-ready-email) - Automated pickup notifications for internal orders
- **JP8** - [Minimum weight staging redirect](https://github.com/Blake-goofy/Jasco-mods/wiki/JP8-Minimum-weight-staging-redirect) - Dynamic staging location routing for lightweight pallets
- **JP9** - [Receipt QC](https://github.com/Blake-goofy/Jasco-mods/wiki/JP9-Receipt-QC) - Automated QC assignment for receipt lines
- **JP10** - [Last receipt pallet hold](https://github.com/Blake-goofy/Jasco-mods/wiki/JP10-Last-receipt-pallet-hold) - Automatic hold on final receipt container for count verification
- **JP11** - [ASRS inventory recall](https://github.com/Blake-goofy/Jasco-mods/wiki/JP11-ASRS-inventory-recall) - Inventory transfer from ASRS to recall location via TGW integration
- **JP12** - [Velocity assignment](https://github.com/Blake-goofy/Jasco-mods/wiki/JP12-Velocity-assignment) - Automated velocity classification with smart capacity management to evenly distribute items across warehouse zones

## Repository Structure

```
Jasco-mods/
├── db-objects/            # All database objects
│   ├── views/             # Custom views
│   ├── stored-procedures/ # Custom and modified stored procedures
│   └── triggers/          # Custom triggers
├── wiki/                  # Documentation for each mod
├── images/                # Screenshots and diagrams
└── README.md              # This file
```

## What this repo contains
- **Database objects** organized by type (views, stored procedures, triggers)
- **Wiki documentation** with detailed explanations of each mod's business purpose and technical implementation
- **Images and screenshots** showing before/after UI or config examples

## How to use this repository during upgrades
1. Review the [wiki documentation](https://github.com/Blake-goofy/Jasco-mods/wiki) for the affected mod to understand business purpose and technical changes.
2. Navigate to the relevant database object in the `db-objects/` folder to see exactly what was changed.
3. Decide whether the customization is still needed or can be replaced by a product feature.

## Guidance for each customization (what to include in wiki)
- Business purpose and background
- Exact database objects changed or added
- How the customization is invoked (e.g., trigger, ODWS step, scheduled job)
- Any UI/config screens to maintain (screenshots recommended)
- Installation notes (e.g., process history requirements, technical values)
