## Overview
One new view has been added for this mod:
- [`JP4_METADATA_INSIGHT_WAVE_VIEW`](https://github.com/Blake-goofy/Jasco-mods/blob/main/JP4/JP4_METADATA_INSIGHT_WAVE_VIEW.sql)

This view is based on the original wave view, but with the prefix `JP4_` added to its name.

## New Columns
The new view includes four additional columns:

### CONTAINER_EST
- **Source**: Calculated from `SHIPMENT_DETAIL` by dividing `TOTAL_QTY` by the appropriate unit of measure conversion (CS, IP, or EA) to estimate how many containers will be created from the wave.
- **Business purpose**: Provides operations with an upfront estimate of container volume for capacity planning and dock scheduling before the wave is run. This is useful because we try to keep waves under 4,000 containers when possible for performance reasons.

### PREVENT_RUN
- **Source**: An indicator that determines whether the wave is safe to run based on validation rules (currently set to `N` as placeholder for future development).
- **Business purpose**: When set to `Y`, this flag greys out the Run button in the UI, preventing execution of waves that have validation issues. Common scenarios include:
  - A customer requires a specific unit of measure (e.g., cases only) but the order quantity makes that impossible (e.g., AMAZON.COM orders 16 EA of an item with a case quantity of 5).
  - A wave line requests more quantity than is available in the warehouse.
  
  These issues are typically resolved through customer support (order cancellation/adjustment back to host) or can be bypassed through a separate SCALE process not covered in this mod.

![Wave Run Button](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP4-wave-run.png)

### PREVENT_RELEASE
- **Source**: An indicator that determines whether the wave is safe to release based on inventory availability at allocated locations (currently set to `N` as placeholder for future development).
- **Business purpose**: When set to `Y`, this flag greys out the Release button in the UI after a wave has been run but before sufficient on-hand inventory exists at the locations being allocated. This prevents overselling when multiple waves compete for the same inventory. For example:
  - Location A has 100 on hand
  - Wave 1 allocates 100 from Location A (PREVENT_RELEASE = `N`)
  - Wave 2 allocates 100 from Location A (PREVENT_RELEASE = `N`)
  - Once Wave 1 releases, that quantity is dedicated to Wave 1
  - Wave 2 now shows PREVENT_RELEASE = `Y` until Location A is replenished

![Wave Release Button](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP4-wave-release.png)

### PRIORITY
- **Source**: Displays `LAUNCH_STATISTICS.USER_DEF7`, which stores the wave priority value.
- **Business purpose**: Controls the priority assigned to replenishment work instructions created during waving. This ensures that replenishments for higher-priority waves are executed first, supporting fulfillment and customer commitments.

## Visual Changes
The following images show the screen before and after the customization

### Before Customization
![Before Customization](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP4-wave-before.png)

### After Customization
![After Customization](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP4-wave-after.png)

## Installation note
The `PREVENT_RUN` and `PREVENT_RELEASE` columns are currently set to `N` (hardcoded) as placeholders for future development. The validation logic that determines when these flags should be `Y` will be implemented in a future phase.
