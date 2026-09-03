# 7.4 Quote Collection

**Area:** 7. Vendor, Booking, and Marketplace Layer

The app lets an owner manually record and compare vendor quotes for an event
plan. Quote management is private and review-only: Carecierge does not contact
vendors, send requests, make bookings, or perform payments.

## Capabilities

- Record a quote against an owner-scoped saved vendor and active event plan.
- Track amount, currency, scope, expiration, decision deadline, status, next
  action, and private notes.
- Compare multiple quotes for the same plan on desktop and mobile.
- Create an owner-controlled reminder prefilled from a quote deadline.
- Preserve quotes for review when a plan becomes completed or archived, with an
  owner-level quote history entry point.

## Possible Data Objects

- `VendorQuote`
- `Reminder`

## Implementation Notes

Vendor quote notes, scope, and next action are encrypted. Quote and reminder
access is owner-scoped, exports include the owner's decrypted quote data, and a
saved vendor cannot be deleted while a quote still references it. Quote removal
is explicit and detaches its reminder context without deleting reminder history.
The reminder handoff preserves its quote reference and deadline but does not copy
encrypted quote text into plaintext reminder fields.

Outbound quote requests, automated vendor communication, attachment handling,
booking conversion, and payment remain future capabilities. Any outbound action
must use the approval and automation-permission boundaries before it is added.
