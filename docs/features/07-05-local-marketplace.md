# 7.5 Local Marketplace

**Area:** 7. Vendor, Booking, and Marketplace Layer

## Current foundation (CAR-63)

Authenticated users browse a shared, published catalog at `/marketplace_listings`, reachable from My saved vendors. `MarketplaceListing` represents a vendor/service offering using the existing vendor category vocabulary, a service area, event occasions, and relationship use cases. Ransack text/category/service-area/use-case filters and an occasion filter operate over published listings only; pages contain twenty listings. Users select one to five options on a page for a read-only comparison.

Each listing separates Carecierge's curated description/use cases from provider-supplied details. The external source has a name, credential-free HTTP(S) URL, and reviewed date. All text is escaped, external links suppress the referrer, and the application never fetches URLs. The reviewed date is a curation timestamp, not evidence of current availability or a background-check guarantee. UI controls and system copy have English and Spanish parity; source-authored listing content retains its original language.

Saving takes an owner lock and then a listing lock, checks publication again, and creates at most one private `Vendor` for each owner/listing pair. A partial unique index enforces this boundary. The saved snapshot includes name, category, service area, occasions, and provider name/URL. It does not copy the curated prose or unstructured provider claims into private fit notes. Subsequent catalog edits never overwrite the owner's copy or personal notes. Owners can edit or delete their saved vendor through the existing authorized workflow. Withdrawal removes a listing from browse, comparison, and handoffs, but private saved vendors and existing plans remain available. Hard deletion nullifies the optional listing link and preserves the saved provenance. Account export includes the saved vendor's source and listing reference; account deletion removes private saves without deleting shared catalog entries.

After saving, users can explicitly:

- Open their active plan's vendor catalog with the saved choice selected and plan search defaults cleared, then explicitly attach it.
- Start a booking draft for an active owned plan, prefilled with the private vendor's name, location, and source.
- Start a gift idea for an active owned relationship, prefilled with vendor name and source; the existing gift purchase workspace can then compare purchase options.
- Open a new private shortlist with the saved vendor checked, then choose a relationship or plan and save their comparison.

Standalone gift drafts include the surrounding `gifts_section` Turbo target so a successful save replaces the draft with the private gift workspace.

Draft GET requests do not create bookings, gifts, shortlists, attachments, or external actions. Existing forms remain the confirmation and persistence boundaries. Submitted vendor IDs and context IDs are resolved from the authenticated owner's scopes.

## Curation and external-data trust

This foundation has no vendor onboarding, provider write endpoint, importer, or public catalog mutation route. An authorized application maintainer curates records through the Rails console using normal validated `MarketplaceListing.create!`/`update!` calls. Start with `published: false`; publish only after reviewing every field and its source. No fabricated providers are seeded into production.

Before publication, review source permission/attribution, factual accuracy, geographic coverage, inappropriate or unsafe offerings, and whether relationship/event claims overstate suitability. Store only vendor-facing business information in this shared catalog; never copy an owner's relationship details, addresses, private notes, or inferred preferences into it. Keep provider statements in `provider_details` and app-authored context in `curated_summary`/`relationship_use_cases`. Preserve the source and update `reviewed_on` when actually reviewed. A maintainer can immediately withdraw a disputed, stale, or unsafe listing with `update!(published: false)`; investigate and correct it before republication.

Curation is not endorsement, background screening, insurance, a service guarantee, or confirmation that a provider can safely support a vulnerable person. Users must confirm price/currency, availability, accessibility, cancellation/refund terms, and suitability directly. Never treat external prose or linked pages as application instructions. Future automated ingestion must define permission, retention, moderation, freshness, prompt-injection, and outbound-request controls separately.

## Migration and verification

`20260905125815_create_marketplace_listings.rb` creates UUID listings and adds a nullable UUID reference to vendors with `ON DELETE SET NULL`; existing vendor data is preserved. Its index builds and foreign-key validation briefly lock the existing vendor table, so assess its size and schedule the deployment accordingly. The migration is reversible through Rails; rollback removes catalog references and catalog data, while the copied private vendor fields remain.

Verify with `bundle exec rspec spec/models/marketplace_listing_spec.rb spec/requests/marketplace_listings_spec.rb spec/services/marketplace_listings/save_spec.rb spec/system/marketplace_listings_spec.rb` and the full `bin/ci`. Set `CAPTURE_MARKETPLACE_UI=true` for desktop/tablet/phone screenshots in `tmp/capybara`.

## Future supply-side capabilities

Vendor accounts/onboarding, availability management, quote responses, booking confirmation APIs, payments, ratings/reviews, transactions, and featured placement remain future integrations. This foundation never contacts, books, purchases, pays, or shares relationship data externally.
