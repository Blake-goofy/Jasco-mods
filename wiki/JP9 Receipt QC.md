## Overview
Five database objects were created or modified for this mod:
- [`RECEIPT_DETAIL_A_I`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/triggers/RECEIPT_DETAIL_A_I.sql) (trigger)
- [`JP9_AddReceiptQC`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JP9_AddReceiptQC.sql) (stored procedure)
- [`JP9_RemoveReceiptQC`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JP9_RemoveReceiptQC.sql) (stored procedure)
- [`JP9_RPT_ReceiptOverviewHeader`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JP9_RPT_ReceiptOverviewHeader.sql) (stored procedure)
- [`JP9_RPT_ReceiptOverviewDetails`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/JP9_RPT_ReceiptOverviewDetails.sql) (stored procedure)
- [`EXP_LocateBefore`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/EXP_LocateBefore.sql) (stored procedure)

This mod automatically identifies and flags receipt lines that require Quality Control (QC) inspection based on specific criteria. The system intelligently handles duplicate QC assignments and ensures only one line per item/PO combination actually gets processed for QC, preventing wasted effort and duplicate inspections.

## Background
Jasco receives large quantities of new products that require quality control inspection. The QC process involves:
- **QC NEW**: New items that have never been received before need samples pulled for content photography and graphic design verification
- **QC TIMER**: Timer products require special inspection due to regulatory requirements and customer return history

Previously, QC assignment was manual and error-prone. When multiple receipt lines for the same item arrived on the same trailer, there was no mechanism to prevent duplicate QC assignments, resulting in wasted inspection effort. This mod automates the QC flagging process and implements "locking" logic to ensure only one line per item actually gets processed.

## How it works

### Step 1: Automatic QC Assignment (RECEIPT_DETAIL_A_I → JP9_AddReceiptQC)

When a new receipt line is interfaced into SCALE, the `RECEIPT_DETAIL_A_I` trigger fires and calls `JP9_AddReceiptQC` to evaluate QC criteria:

#### QC NEW Assignment
A receipt line is flagged as **QC NEW** if:
- `TOTAL_QTY > 60` (sufficient quantity to pull samples)
- The item has **never been received before** at this quantity level
- The item is not currently on an open receipt (`OPEN_QTY < TOTAL_QTY` or `RECEIPT_HEADER.USER_DEF1 = 'Printed'`)

When flagged, the system:
- Sets `RECEIPT_DETAIL.ITEM_CATEGORY7 = 'QC NEW'`
- Sets `RECEIPT_DETAIL.USER_DEF1` to the configured QC quantity (from `JP9_QC_NEW_QTY` technical value)
- Logs a process history record

#### QC TIMER Assignment
A receipt line is flagged as **QC TIMER** if:
- `TOTAL_QTY >= 400` (timers require higher quantity threshold)
- Item description contains "timer"
- Item is not a Mexican variant (`ITEM NOT LIKE '%MEX%'`)
- The item/PO combination has **never been received before**

When flagged, the system:
- Sets `RECEIPT_DETAIL.ITEM_CATEGORY7 = 'QC TIMER'` or `'QC NEW TIMER'` (if also meets QC NEW criteria)
- Calculates quantity using special logic: base QC quantity + case quantity (with 2x multiplier for high-volume/low-case items)
- Logs a process history record

**Important**: At this stage, if multiple receipt lines for the same item arrive on the same trailer, they will **all** be flagged as QC. This is intentional—the next step resolves duplicates.

### Step 2: QC Lock-In (Preventing Duplicates)

The system "locks in" one QC line and removes duplicate QC flags when either of these actions occurs:

#### Option A: Locate Container (EXP_LocateBefore)
When the first container for a QC-flagged item is located to a receiving location, `EXP_LocateBefore` calls `JP9_RemoveReceiptQC` with reason "located."

#### Option B: Print Receipt Document (JP9_RPT_ReceiptOverviewDetails)
When a receipt overview document is printed, `JP9_RPT_ReceiptOverviewDetails` calls `JP9_RemoveReceiptQC` with reason "printed."

### Step 3: Duplicate Removal Logic (JP9_RemoveReceiptQC)

`JP9_RemoveReceiptQC` performs the following:

1. **Identifies all receipt lines on the same trailer/date** that are marked as QC
2. **Selects the "primary" QC line** for each item (or item/PO combination for timers) - the first one by PO
3. **Removes or adjusts QC flags** on all other lines:
   - `QC NEW` → `NULL` (completely removed)
   - `QC NEW TIMER` → `QC TIMER` (removes the NEW portion)
   - `QC TIMER` → `NULL` (completely removed)
4. **Adjusts USER_DEF1 quantities** accordingly (subtracts the NEW quantity if removing NEW)
5. **Logs process history** for each line where QC was removed, explaining why

This ensures only one line per item actually gets processed through the QC workflow, preventing duplicate inspections.

### Trailer-Oriented Receipt Documents

Jasco's receiving process groups receipts by trailer. When multiple receipts arrive on the same trailer:
- All receipts associated with a trailer print on a **single combined document**
- It doesn't matter which receipt you select to print in SCALE—the document includes all trailer receipts
- The document shows a **QC indicator** next to lines that require inspection
- Once printed, the system assumes that document will be worked first, so other potential QC lines are cleared

![Receipt Overview Document](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP9-receipt-overview.png)

The image above shows the trailer-oriented receipt document with QC indicators displayed next to flagged lines.

### Technical Configuration

The mod relies on a technical value in `SYSTEM_CONFIG_DETAIL`:

![JP9 Technical Value](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP9-technical-value.png)

- **JP9_QC_NEW_QTY**: The base quantity to pull for QC NEW inspections (typically 2 eaches—one for content photography, one for graphic design verification)

The procedures include comprehensive error handling with audit logging when this technical value is not configured properly.

### Additional Logic in RECEIPT_DETAIL_A_I

The trigger also includes logic to correct `RECEIPT_HEADER.TOTAL_LINES`:
- Counts actual distinct receipt lines
- Compares to the `TOTAL_LINES` value on the header
- Corrects discrepancies and logs each correction to process history
- Uses a WHILE loop to create individual audit records for each corrected receipt

## Process History Logging

The mod creates comprehensive audit trails:

### JP9_AddReceiptQC
- **PROCESS**: "600" (QC Assignment)
- **ACTION**: "150" (Information)
- **MESSAGE**: Details which item was marked QC and why (e.g., "Item ABC123 from receipt ID RCV001 was marked QC NEW because the item has never been checked in as a QC NEW")

### JP9_RemoveReceiptQC
- **PROCESS**: "610" (QC Evaluation)  
- **ACTION**: "150" (Information)
- **MESSAGE**: Details which item had QC removed and why (e.g., "QC NEW removed for item ABC123 from receipt ID RCV002 because a different line of the same item was printed.")

### RECEIPT_DETAIL_A_I (TOTAL_LINES Correction)
- **PROCESS**: "Value changed"
- **ACTION**: "150" (Information)
- **MESSAGE**: Details the correction (e.g., "Receipt RCV001 TOTAL_LINES corrected from 5 to 7.")

## Installation notes
- Configure the technical value `JP9_QC_NEW_QTY` in `SYSTEM_CONFIG_DETAIL` (recommended value: 2)
- The Receipt Overview SSRS report must be configured to call `JP9_RPT_ReceiptOverviewHeader` and `JP9_RPT_ReceiptOverviewDetails`
