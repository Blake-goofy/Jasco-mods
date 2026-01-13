
## Overview
Two stored procedures have been modified for this mod:
- [`EXP_CloseContainerAfter`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/EXP_CloseContainerAfter.sql)
- [`EXP_WorkCreationBefore`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/EXP_WorkCreationBefore.sql)

This mod temporarily removes dock area anchor criteria from Pallet Flow locations when lightweight pallets are closed, then restores the criteria during work creation. This prevents lightweight pallets from being routed to Pallet Flow staging areas and instead directs them to standard staging locations.

The behavior is controlled by two technical configuration values that define the minimum weight threshold and the target dock area.

## How it works

### EXP_CloseContainerAfter (Remove Criteria)
When a pallet container is closed:
1. The procedure checks if the pallet weight is below the configured minimum weight threshold (`JP8_MIN_WEIGHT`)
2. If the pallet is underweight, it temporarily removes the `DOCK_AREA_ANCHOR_CRITERIA` from all Pallet Flow locations
3. The original criteria value is stored in `LOCATION.USER_DEF1` for later restoration
4. This removal prevents the lightweight pallet from being staged in Pallet Flow areas
5. Process history logs the number of locations affected and the dock area description

### EXP_WorkCreationBefore (Restore Criteria)
During work creation:
1. The procedure checks if any locations have the stored dock area value in `USER_DEF1`
2. If found, it restores the `DOCK_AREA_ANCHOR_CRITERIA` from `USER_DEF1` back to its original value
3. Clears the `USER_DEF1` field to reset the temporary storage
4. Process history logs the restoration and number of locations affected

This temporary removal and restoration approach ensures that:
- Lightweight pallets bypass Pallet Flow staging
- Normal-weight pallets continue to use Pallet Flow staging
- The dock area criteria is properly maintained for subsequent operations

### Technical Configuration
Both procedures rely on technical values in `SYSTEM_CONFIG_DETAIL`:

![JP8 Technical Values](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP8-technical-values.png)

- **JP8_MIN_WEIGHT**: The minimum weight threshold (e.g., 150 lbs). Pallets below this weight trigger the dock area criteria removal.
- **JP8_DOCK_AREA**: The dock area filter object ID (e.g., 846). This identifies which dock area's anchor criteria should be temporarily removed.

The procedures include comprehensive error handling:
- Audit logging when technical values are not configured properly
- Process history logging for all criteria removals and restorations

### Installation note
Make sure to add the history process `JP8_MinWeightStageRedirect`