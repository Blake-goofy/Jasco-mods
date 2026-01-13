## Overview
Two new views have were added for this mod:
- [`JP1_METADATA_INSIGHT_DIF_INCOMING_MESSAGE`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/views/JP1_METADATA_INSIGHT_DIF_INCOMING_MESSAGE.sql)
- [`JP1_METADATA_INSIGHT_DIF_OUTGOING_MESSAGE`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/views/JP1_METADATA_INSIGHT_DIF_OUTGOING_MESSAGE.sql)

These views are based on the original DIF views, but with the prefix `JP1_` added to their names.

## New Columns
Both new views include two additional columns:

### MESSAGE_TYPE
- **Source**: Extracted from the JSON in the `DATA` column.
- **Business purpose**: Team members often look for specific message types when investigating issues, so exposing that value lets them filter with a familiar attribute instead of relying on event IDs or descriptions.

### ROW
- **Source**: A computed row number added to every result so downstream filters can identify the newest messages.
- **Business purpose**: SCALE limits query results to 5000 rows, which can make it hard to see the most recent activity. The Row column supports the UI toggle so users instantly focus on the latest 100 messages without manual filtering.

## Visual Changes
The following images show the screen before and after the customization (for DIF Incoming). The same changes were also applied to DIF Outgoing.

### Before Customization
![Before Customization](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP1-dif-in-before.png)

### After Customization
![After Customization](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP1-dif-in-after.png)