## Overview
A trigger modification was added for this mod:
- [`SHIPMENT_HEADER_A_U`](https://github.com/Blake-goofy/Jasco-mods/blob/main/JP5/SHIPMENT_HEADER_A_U.sql)

This is the same trigger file modified in JP5. JP6 adds logging functionality to track changes to the `CARRIER` and `CARRIER_SERVICE` fields in the `SHIPMENT_HEADER` table.

## Background
Orders were being changed to incorrect carrier or carrier service values after being interfaced into the system. When investigating these discrepancies, there was no audit trail to identify who or what (user or system process) was making these changes. This mod adds comprehensive logging to track all carrier and carrier service modifications.

## Business Logic

### Carrier Change Logging
- **Trigger condition**: Fires when the `CARRIER` field is updated on a shipment.
- **Action**: Logs every carrier change to the `PROCESS_HISTORY` table, regardless of whether the change was made by a user or a system process.
- **Business purpose**: Provides an audit trail to identify the source of incorrect carrier assignments and enables troubleshooting of carrier-related issues.

### Carrier Service Change Logging
- **Trigger condition**: Fires when the `CARRIER_SERVICE` field is updated on a shipment.
- **Action**: Logs every carrier service change to the `PROCESS_HISTORY` table, regardless of whether the change was made by a user or a system process.
- **Business purpose**: Provides an audit trail to identify the source of incorrect carrier service assignments and enables troubleshooting of service-level routing issues.

## Process History Logging

### Carrier Changes
- **IDENTIFIER1**: Shipment ID
- **IDENTIFIER2**: "Carrier changed"
- **MESSAGE**: A detailed description showing the old and new carrier values (e.g., "SHIP123 carrier was changed from FedEx to UPS.")
- **ACTION**: 150 (Information level)
- **USER_STAMP**: The user or system process that made the change
- **PROCESS_STAMP**: "SHIPMENT_HEADER_A_U Trigger"

### Carrier Service Changes
- **IDENTIFIER1**: Shipment ID
- **IDENTIFIER2**: "Carrier service changed"
- **MESSAGE**: A detailed description showing the old and new carrier service values (e.g., "SHIP123 carrier service was changed from Ground to Express.")
- **ACTION**: 150 (Information level)
- **USER_STAMP**: The user or system process that made the change
- **PROCESS_STAMP**: "SHIPMENT_HEADER_A_U Trigger"

This logging enables the team to quickly identify patterns and determine whether carrier changes are being made by specific users, automated processes, or system integrations.
