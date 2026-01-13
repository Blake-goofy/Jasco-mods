## Overview
Four altered stored procedure for this mod:
- [`INV_AdjustInv`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/INV_AdjustInv.sql)
- [`INV_PickFromLocation`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/INV_PickFromLocation.sql)
- [`INV_PutIntoLocation`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/INV_PutIntoLocation.sql)
- [`INV_InsertLocationInventory`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/INV_InsertLocationInventory.sql)


This mod preserves the ASRS decant location (stored in `LOCATION_INVENTORY.USER_DEF1`, "UD1") as inventory flows from replenishment -> in-transit (DECANT) -> picker ("-username") -> putaway destination. The change ensures the UD1 value applied for the decant extension (EX24) is not lost during putaway confirmation so the final on-hand record still references the ASRS location.

The change touches the inventory adjustment/put/pick stored procedures so UD1 captured at pick time follows through the putaway insert.

## Business purpose
- EX24 (decant extension) requires the ASRS target location in `LOCATION_INVENTORY.USER_DEF1` on the DECANT inventory record. Operations rely on that UD1 being carried forward to the final on-hand record so downstream automation and systems know which ASRS location to move the inventory into.
- Previously, a code path in putaway cleared the UD1 value, so after putaway the destination `LOCATION_INVENTORY` row had no UD1. That broke integrations and required manual fixes.
- This mod preserves UD1 through the pick and putaway flow so the destination record retains the ASRS location required by EX24.

## How it works (technical summary)
- `INV_PickFromLocation` collects and outputs the source inventory's `USER_DEF1` when picking to the picker location ("-username").
- `INV_AdjustInv` propagates that output and passes the `fromUserDef1` value into the put logic.
- `INV_PutIntoLocation` accepts and propagates that output and passes the `fromUserDef1` value into the insert logic.
- `INV_InsertLocationInventory` contains DECANT-aware logic and only applies the incoming `fromUserdef1` into the new `LOCATION_INVENTORY.USER_DEF1` when appropriate (for DECANT-style templates). With the put-side change, the `fromUserdef1` now reaches the insert and is written as UD1 on the destination inventory row.

## Notes / follow-ups
- The change is intentionally minimal and focused on preserving UD1. If you want explicit logging or history entries that record UD1 propagation, I can add that (low risk).
- If you need the UD1 propagation restricted to specific templates or use-cases beyond what's already enforced in `INV_InsertLocationInventory` (which checks `TEMPLATE_FIELD1 = 'DECANT'`), we can tighten the rule there.