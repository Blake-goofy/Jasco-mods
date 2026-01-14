## Overview
One stored procedure has been added for this mod:
- [`JP12_VelocityAssignment`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JP12_VelocityAssignment.sql)

This mod automatically assigns velocity classifications to items based on picking activity, ensuring faster-moving items are located near automation while evenly distributing inventory across warehouse zones to prevent overfilling.

The procedure updates `ITEM.ITEM_CATEGORY1` and `RECEIPT_DETAIL.ITEM_CATEGORY1` with velocity classifications (A, B, C, or D Mover, with optional "Heavy" suffix). These classifications drive location assignment during receipt putaway, placing high-velocity items near order prep areas and automation.

## How it works
- A scheduled job runs `JP12_VelocityAssignment` to calculate and assign velocities based on:
  - **Pick visits**: Number of times a location is visited (weighted 1x)
  - **Replen visits**: Number of replenishment visits (weighted 2x)
  - **Current inventory**: Existing pallet locations in the warehouse
  - **Incoming inventory**: Pallets on trailers in OKC or Dallas yards
- The procedure calculates a **target fill** percentage for each zone (A, B, C, D) to evenly distribute inventory across areas, preventing overfilling of high-velocity zones.
- Items are ranked by activity, and cumulative location counts determine velocity assignments, ensuring top movers fit in their target zones with room to spare.
- New items (received within 60 days based on `USER_DEF5`) are classified as A Movers initially.
- Heavy items (case weight exceeds `JP12_HEAVY_WEIGHT` threshold and not gaylords) receive "Heavy" suffix for specialized handling.

### Example: Even fill logic
Suppose the warehouse has 3,000 locations and currently 2,400 pallets across all items:
- **A area**: 1,000 locations → target fill = 800 locations (80%)
- **B area**: 1,200 locations → target fill = 960 locations (80%)
- **C area**: 600 locations → target fill = 480 locations (80%)
- **D area**: 200 locations → target fill = 160 locations (80%)

Now rank items by activity and count their cumulative pallet needs (current locations + incoming pallets on trailers in OKC/Dallas):
- Item #1 (most visits): 150 pallets → cumulative = 150
- Item #2: 90 pallets → cumulative = 240
- Item #3: 360 pallets → cumulative = 600
- Item #4: 150 pallets → cumulative = 750
- Item #5: 30 pallets → cumulative = 780
- ...and so on

**Velocity assignment**:
- Items #1-5 are **A Movers** (cumulative ≤ 800)
- Items #6+ are **B Movers** (cumulative > 800 and ≤ 1,760)
- Remaining items classified as C or D Movers

This leaves 220 empty A locations (1,000 - 780 = 220 available for growth).

**Why this beats arbitrary percentages**: If we simply said "top 10% of items are A Movers," we might classify 100 items as A Movers without considering their pallet counts. Those 100 items could require 1,000+ locations, completely filling A area. When the #1 mover gets a new receipt and needs more locations, it overflows to B area. With even fill logic, we proactively classify marginal items (like items near the 800 threshold) as B Movers, preserving A area space for top movers when they receive new inventory.

### Technical configuration
The heavy weight threshold is defined in system configuration as shown below:

![Technical value configuration](https://raw.githubusercontent.comBlake-goofy/Jasco-mods/main/images/JP12-technical-value.png)

### Personal alert (scheduled job)
A personal alert query executes `JP12_VelocityAssignment` on a weekly schedule to automatically assign velocities.

![Personal alert example](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP12-personal-alert.png)

### Installation note
Create a personal alert that executes the stored procedure `JP12_VelocityAssignment`, then configure a scheduled job to run this alert weekly.
