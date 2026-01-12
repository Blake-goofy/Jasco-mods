## Overview
Two new views have were added for this mod:
- [`JP1_METADATA_INSIGHT_DIF_INCOMING_MESSAGE`](https://github.com/Blake-goofy/Jasco-mods/blob/main/JP1/JP1_METADATA_INSIGHT_DIF_INCOMING_MESSAGE.sql)
- [`JP1_METADATA_INSIGHT_DIF_OUTGOING_MESSAGE`](https://github.com/Blake-goofy/Jasco-mods/blob/main/JP1/JP1_METADATA_INSIGHT_DIF_OUTGOING_MESSAGE.sql)

These views are based on the original DIF views, but with the prefix `JP1_` added to their names.

## New Columns
Both new views include two additional columns:
- **MESSAGE_TYPE**: Extracted from the JSON in the `DATA` column.
	- *Business purpose*: This allows team members to quickly filter for the specific message types they are interested in when investigating issues. The team is familiar with message type, and it is preferred over alternatives like event ID or event description for filtering and troubleshooting.
- **ROW**: Used for the toggle switch in the UI to allow displaying only the latest 100 messages ("Top 100" filter).
	- *Business purpose*: The Top 100 filter makes it easy to check if messages are being received and processed. Since SCALE limits results to 5000 rows, it can be difficult to see the latest messages when there is a high volume. The Top 100 filter simplifies this process, allowing users to quickly confirm recent message activity without additional manual filtering.

## Visual Changes
The following images show the screen before and after the customization (for DIF Incoming). The same changes were also applied to DIF Outgoing.

### Before Customization
![Before Customization](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP1-dif-in-before.png)

### After Customization
![After Customization](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP1-dif-in-after.png)