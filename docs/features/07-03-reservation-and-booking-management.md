# 7.3 Reservation and Booking Management

**Area:** 7. Vendor, Booking, and Marketplace Layer

The app helps manage booking logistics after the user selects a vendor.

## Capabilities

- Draft vendor request.
- Track availability.
- Track quote.
- Track deposit.
- Store confirmation.
- Store cancellation policy.
- Add calendar event.
- Add payment reminder.
- Track final confirmation.

## Possible Data Objects

- `BookingRequest`
- `BookingStatus`
- `BookingConfirmation`
- `VendorMessage`
- `PaymentReminder`

## Implementation Notes

Initial implementation can be manual/status-based. Later versions can integrate directly with vendor systems or send emails/messages.

## Current Implementation (CAR-64)

Carecierge now provides a manual booking workspace inside each event plan. The
owner records whether an item is a reservation or booking, its title, provider,
date and local time, IANA time zone, location, lifecycle status, confirmation
details, cancellation policy, and notes. Free-text logistics are encrypted at
rest, and all booking inputs are filtered from request logs.

Each booking remains scoped to the authenticated owner and its event plan. It
can be created or changed only while the plan and relationship are active, but
it remains readable and explicitly removable afterward. Saving a booking keeps
one manual plan task and one timeline entry synchronized; terminal booking
statuses complete the task, while returning to a non-terminal status reopens
it. Optimistic locking prevents one stale form from silently overwriting a
newer edit. Booking-owned tasks can only be changed through booking status, and
their timeline rows contain generic status metadata rather than duplicating
encrypted booking titles or provider details in plaintext. Suggestion and
backup-plan workflows do not reuse or replace booking-owned tasks.

From a booking, the owner can choose to create confirmation, deposit, arrival,
or change reminders. The reminder form receives a useful schedule and title,
but nothing is scheduled until the owner reviews and submits it. Removing a
booking detaches reminder history before removing its booking task and timeline
entry. A private owner-scoped booking-history page keeps records navigable after
a plan is archived or its relationship is discarded. Booking data participates
in owner exports and account deletion.

This implementation does not contact providers, send booking requests, make
payments, or connect to external reservation systems. Those remain explicit
future integrations that must cross the product's approval and automation
boundaries.
