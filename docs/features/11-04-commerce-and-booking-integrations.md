# 11.4 Commerce and Booking Integrations

**Area:** 11. Integrations

Integrate with vendors, products, reservations, and payment systems.

## Possible Integrations

- Restaurant reservation platforms
- Florist APIs
- E-commerce affiliate links
- Stripe
- Local delivery providers
- Google Maps / Places
- Vendor marketplace APIs

## Implementation Notes

This should be built after the planning workflows and approval queue are stable.

## Implemented boundary (CAR-74)

The relationship workspace offers **Provider records** for manual observations of
commerce, booking, vendor, and reservation providers. Owners record a source label,
optional safe HTTP(S) source URL and reference, reported status, and required failure
details when a provider action failed. The timestamp is when the owner saved the
observation; it is not a provider sync timestamp. Recovery clears stale failure notes.

Records can link to the same relationship's gift purchase plans, event plans, bookings,
quotes and directly attached reminders. Linked records retain their own status.
All changes require owner authorization and produce content-free audit evidence;
fields are encrypted, logs are filtered, exports include owner data, and deletion of
an attached context removes the local record. Removing a record never cancels anything
with a provider. Archived relationships retain readable and removable local history.

No API provider is configured by this feature. There are no credentials, live status
fetches, automatic purchases/bookings/payments, or executable provider actions.
Future adapters require their own explicit permission, consent, credential revocation,
failure and audit design before they can act. Current automation settings do not grant
this manual ledger any external authority.
