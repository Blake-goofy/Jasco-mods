## Overview
A trigger modification was added for this mod:
- [`SHIPMENT_HEADER_A_U`](https://github.com/Blake-goofy/Jasco-mods/blob/main/JP5/SHIPMENT_HEADER_A_U.sql)

This trigger monitors changes to the `FREIGHT_TERMS` field in the `SHIPMENT_HEADER` table and automatically cleans up third-party billing accessorials when freight terms change away from third-party.

## Business Logic

### Freight Term Change Detection
- **Trigger condition**: Fires when the `FREIGHT_TERMS` field is updated on a shipment.
- **Specific action**: Only processes shipments where the freight terms changed **from** `3RD` (third-party) to any other value.
- **Business purpose**: When an order switches from third-party billing to another freight term (e.g., prepaid, collect), any lingering third-party accessorials must be removed to prevent billing errors.

### Accessorial Handling
The trigger performs a two-level cleanup:

1. **Shipment-level accessorials**: Deletes any `3rd Pty Billing` accessorials directly associated with the shipment header.
2. **Container-level accessorials**: Deletes any `3rd Pty Billing` accessorials associated with shipping containers linked to the shipment.

This ensures that all third-party billing charges are removed from both the parent shipment and its child containers when the freight terms change.

## Process History Logging
The trigger creates a record in the `PROCESS_HISTORY` table for every freight term change, including:
- **IDENTIFIER1**: Shipment ID
- **IDENTIFIER2**: "Freight terms changed"
- **MESSAGE**: A detailed description showing the old and new freight term descriptions (e.g., "SHIP123 freight terms were changed from Third Party to Prepaid, so the 3rd pty accessorials were deleted.")
- **ACTION**: 150 (Information level)
- **PROCESS_STAMP**: "SHIPMENT_HEADER_A_U Trigger"

The message dynamically indicates whether accessorials were deleted based on whether the change was from third-party to another term.
