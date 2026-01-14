## Overview
Two database objects were modified for this mod:
- [`JPCI_IBMMQ_DIFIncomingMessage`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JPCI_IBMMQ_DIFIncomingMessage.sql) (routing stored procedure)
- [`JP11_InventoryRecallAsrs`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JP11_InventoryRecallAsrs.sql) (stored procedure)

This mod processes inventory recalls from the ASRS (Automated Storage and Retrieval System) by transferring inventory from ASRS locations to a designated recall location. It replaces the previous approach of adjusting inventory out and back in, which created suspicious transaction patterns, with a clean transfer that maintains accurate inventory history.

## Background
Jasco's warehouse uses TGW's ASRS system to store and retrieve products. When products need to be recalled from the ASRS (either throught an adjustment or TGW's "recall at rejects" functionality), the inventory must be moved to a physical recall location where it can be inspected, repackaged, or moved to pick outside of the ASRS.

### Previous Process Issues
Before this mod:
1. Inventory had to be **adjusted out** of the ASRS location (creating a negative adjustment)
2. Then **adjusted back in** to the recall location (creating a positive adjustment)
3. This created suspicious-looking transaction patterns that appeared as if inventory was being removed and re-added
4. Transaction history didn't clearly show it was a transfer/move operation
5. Reports and audits flagged these patterns as potential inventory discrepancies

### New Process
With this mod:
- Inventory is **transferred** from ASRS to the recall location in a single operation
- Transaction history clearly records it as a "Move" transaction type
- Both "From" and "To" transaction records are created
- TGW sees the inventory as removed
- SCALE maintains accurate inventory balances and location tracking

## How it works

### Message Routing (JPCI_IBMMQ_DIFIncomingMessage)
When TGW sends an inventory adjustment message (Event ID 211):

1. The routing procedure extracts key values from the JSON message:
   - `UserId` - Who initiated the adjustment
   - `Gtin` - The product identifier
   - `QuantityChanged` - The quantity being adjusted
   - `Reason` - The reason code for the adjustment

2. **Checks if this is a recall operation**:
   - If `Reason` matches the configured technical value (`JP11_REASON_CODE`)
   - AND the quantity is negative (indicated by `-` in the value)
   - Then routes to `JP11_InventoryRecallAsrs`
   - Otherwise routes to standard inventory adjustment processing

### Technical Configuration

![JP11 Technical Values](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP11-technical-values.png)

Two technical values control the behavior:
- **JP11_REASON_CODE**: The reason code that triggers recall processing (typically "INVENTORYRECALL")
- **JP11_RECALL_LOC**: The physical location where recalled inventory is transferred to

## Future Enhancement Opportunities

### Use Base SCALE Inventory Procedures
Currently, the mod directly updates `LOCATION_INVENTORY` and inserts into `TRANSACTION_HISTORY`. A potential enhancement would be to leverage SCALE's built-in inventory adjustment stored procedures instead:
- `INV_AdjustInv`
- `INV_PickFromLocation`
- `INV_PutIntoLocation`

Benefits:
- Ensures consistency with SCALE's business rules
- Automatic handling of edge cases
- Reduces maintenance burden when SCALE upgrades
- Leverages existing validation and error handling

Trade-offs:
- May require adapting to SCALE's parameter structures
- Could add complexity if procedures don't support exact use case
- Need to ensure transaction history format remains consistent
- Need to handle the `REFERENCE_ID = @PROCESS_HIST` for transaction history

## Installation notes
- Configure technical value `JP11_REASON_CODE` (typically "INVENTORYRECALL")
- Configure technical value `JP11_RECALL_LOC` with the physical recall location
- Ensure the recall location exists in SCALE's `LOCATION` table
