## Overview
One stored procedure was modified for this mod:
- [`JPCI_AI0052_WorkCreationAfter`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JPCI_AI0052_WorkCreationAfter.sql)

This mod automatically places a hold on the final receipt container's putaway work instruction when all pallets from a receipt line have been checked in. This ensures the last pallet undergoes count verification before being put away, aligning with physical receiving practices and quality control requirements.

## Background
When Jasco receives large quantities of product across multiple pallets, the receiving team needs to verify that the correct quantity was received. Rather than counting every single pallet (which is time-consuming and redundant for full pallets), the team focuses on the **last pallet** because:

1. **Full pallets are self-evident** - It's easy to visually confirm a full pallet has the correct quantity without detailed counting
2. **The last pallet reveals discrepancies** - If there was an error on any prior pallets (too much or too little received), the final pallet would reflect the issue
3. **The last pallet is often partial** - Unlike the full pallets before it, the last pallet frequently contains a partial quantity and requires verification
4. **Efficiency** - This approach provides quality control without the overhead of counting every pallet

Previously, there was no automated way to hold the last pallet for verification, which sometimes resulted in drivers putting away unverified pallets or inventory staff searching for which pallet was the "last" one.

### Visual Identification
When the last pallet is identified, the system prints "LAST PALLET" on the receipt label, making it easy for receiving staff to identify which pallet requires verification:

![Last Pallet Label](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP10-receipt-lbl.png)

## How it works

### Work Creation Logic
When receipt putaway work is created (`JPCI_AI0052_WorkCreationAfter`), the system:

1. **Identifies receipt putaway work** for the current launch
2. **Checks if all pallets are checked in** - Only processes receipt lines where `OPEN_QTY = 0` (all containers have been received)
3. **Finds the last container** for that receipt line (using `MAX(INTERNAL_REC_CONT_NUM)`)
4. **Places a hold** on the work instruction by setting `HOLD_CODE = 'LAST PALLET'`

This happens automatically during the work creation process, so by the time drivers see their putaway work, the last pallet is already on hold.

### Physical Process
Once work is created with the last pallet on hold:

1. **Drivers set aside last pallets** - Pallets with the "LAST PALLET" hold are staged on the receiving dock instead of being put away
2. **Inventory team verifies** - The inventory control team:
   - Physically counts the quantity on the last pallet
   - Verifies the item matches the license plate label
   - Confirms the total received quantity is correct
3. **Label repositioning** - Once verified, the team moves the license plate from the **top** of the pallet to the **front** of the pallet to signify it has been counted and verified
4. **Hold removal** - The inventory team removes the `HOLD_CODE` from the work instruction in SCALE
5. **Putaway completion** - Drivers can now see and complete the putaway work for the verified pallet

## Process History Logging
The stored procedure logs each time last pallet holds are applied:
- **PROCESS**: "340" (Work creation)
- **ACTION**: "150" (Information)
- **IDENTIFIER1**: Launch number
- **IDENTIFIER2**: Count of work instructions placed on hold
- **MESSAGE**: Details how many last pallet work instructions were held (e.g., "2 last pallet work instruction(s) placed on hold for count verification.")
- **PROCESS_STAMP**: "JPCI_AI0052_WorkCreationAfter"

This provides an audit trail of when the hold logic was applied and how many pallets were affected.