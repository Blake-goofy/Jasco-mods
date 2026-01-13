# Jasco-mods

This repository documents Jasco customizations that are implemented outside of the core Manhattan codebase. It exists to make each customization explicit, discoverable, and easy to evaluate during upgrades.

For detailed explanations of each mod please visit the [wiki](https://github.com/Blake-goofy/Jasco-mods/wiki).

## Purpose
- Capture what was customized, why it exists, and where the implementation lives.
- Help answer the questions: "Do we still need this customization?" and "What is related to this customization?"

## Available Mods
- **JP1** - [DIF insight](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP1%20DIF%20insight.md) - Enhanced DIF message views with message type filtering
- **JP2** - [Case label customers ODWS](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP2%20Case%20label%20customers%20ODWS.md) - Automated case label generation for specific customers
- **JP3** - [UD1 preserve](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP3%20UD1%20preserve.md) - Preserve USER_DEF1 values during inventory operations
- **JP4** - [Wave insight](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP4%20Wave%20insight.md) - Enhanced wave view with container estimates and validation flags
- **JP5** - [Freight terms change](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP5%20Freight%20terms%20change.md) - Automatic cleanup of third-party accessorials
- **JP6** - [Carrier change](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP6%20Carrier%20change.md) - Logging for carrier and carrier service changes
- **JP7** - [Order ready email](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP7%20Order%20ready%20email.md) - Automated pickup notifications for internal orders
- **JP8** - [Minimum weight staging redirect](https://github.com/Blake-goofy/Jasco-mods/blob/main/wiki/JP8%20Minimum%20weight%20staging%20redirect.md) - Dynamic staging location routing for lightweight pallets

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
