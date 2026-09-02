# 7.2 Vendor Shortlisting and Comparison

**Area:** 7. Vendor, Booking, and Marketplace Layer

Carecierge lets an authenticated owner compare a small set of saved vendors for
one active relationship or event plan. A shortlist is a private decision
workspace: it records tradeoffs and the user's choice but never contacts, books,
purchases from, pays, or otherwise acts through a vendor.

## Comparison Criteria

- Price
- Availability
- Location
- Why the vendor may fit
- Owner-authored notes
- Constraints that still need confirmation
- The next action the owner intends to take
- Source attribution and an optional source link

## Current Capabilities

- Create a named shortlist for an active relationship or an active event plan;
  event-plan context determines the relationship.
- Start with or later add saved vendor records owned by the same user.
- Compare no more than five options side by side so the surface remains calm and
  usable on small screens.
- Mark any option as a favorite independently from its decision state.
- Reject, restore, or select an option explicitly. Selecting a new vendor returns
  the prior selection to consideration so one shortlist has at most one selected
  option.
- Keep the shortlist readable after its event plan or relationship is archived;
  comparison details and decisions become read-only while the owner retains an
  explicit option-removal path.
- Paginate the private shortlist index at twenty comparisons per page.
- Encrypt shortlist titles, notes, constraints, and next actions at rest.
- Preserve comparison notes and decisions when deleting a saved vendor by
  requiring the owner to remove that vendor from each comparison first.
- Export decrypted comparison details, decisions, and embedded vendor provenance
  through owner-authorized data exports.
- Present the complete workflow in English and Spanish with no JavaScript
  required for creation, notes, or decisions.

## Possible Data Objects

- `VendorShortlist`
- `VendorOption`
- `Vendor`

## Implementation Notes

Shortlist and option lookups are policy-scoped through the owner. Creation and
mutation revalidate the active relationship and optional event-plan lifecycle.
Vendor IDs are re-resolved from the owner's catalog inside the owner lock before
an option is persisted, so stale or foreign records fail closed.
Mutations acquire the owner, relationship, optional plan, shortlist, and option
locks in that order. A database partial unique index provides a final guard that
only one option can be selected in a shortlist.
