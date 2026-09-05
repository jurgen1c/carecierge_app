# 8.2 Gift Purchase Assistance

**Area:** 8. Gift and Commerce Features

The app helps users move from gift idea to purchase.

## Capabilities

- Save product links.
- Track purchase status.
- Track delivery date.
- Store shipping details.
- Suggest card message.
- Remind user to wrap or deliver.
- Add gift to history.

## Possible Data Objects

- `GiftPurchase`
- `GiftDelivery`
- `GiftMessage`
- `GiftStatus`

## Implementation Notes

Early version should not automatically purchase. Later versions can support user-approved purchase automation.


## Current workflow

From a saved gift, choose **Plan purchase** to keep a private budget, currency,
purchase/delivery/follow-up dates, shipping notes, and up to three vendor options.
Saved gift vendor estimates prefill an unconfirmed option. A suggestion compares
only saved costs within the budget and options the owner checked against their
constraints; prices and availability still need personal confirmation.

Purchase and delivery statuses record actions taken outside Carecierge. Saving
never buys, pays, contacts vendors, or shares shipping details. Reminder actions
open a form for review. Adding a purchase task explicitly creates one independent
checklist item in an active event plan for the same relationship; later purchase
plan edits do not update the task. Record the given date and reaction through the
existing gift-history flow. Purchase details appear in owner exports and are
removed with the gift.
