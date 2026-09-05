# 8.3 Custom Gift Box Builder

**Area:** 8. Gift and Commerce Features

The app builds personalized gift boxes based on recipient preferences.

## Capabilities

- Select gift box theme.
- Set budget.
- Suggest items.
- Explain fit.
- Support local products.
- Track purchase and delivery.
- Save reaction.

## Gift Box Examples

- Coffee lover box
- Self-care box
- Local artisan box
- Book lover box
- New parent box
- Birthday box
- Recovery/support box
- Romantic box

## Possible Data Objects

- `GiftBox`
- `GiftBoxItem`
- `GiftBoxTheme`
- `GiftBoxOrder`

## Implementation Notes

This could become a strong commerce wedge.

## Implemented workspace (CAR-55)

Profile owners open **Gift boxes** to name an occasion, set an optional budget and
currency, and assemble up to 30 items. Each item has private notes, a vendor or
local maker, a safe purchase link, an optional decimal cost, and independent
purchased/ready checkboxes. Unknown costs remain outside the labeled known total.

Companion ideas use confirmed preferences for reading, coffee or gardening.
Constraints, dislikes, allergies, boundaries and exhausted budgets suppress these
local ideas; the owner chooses manually when interpretation is needed. The system
does not claim verified suitability, prices or availability and never contacts or
buys from vendors. Delivery links open the existing private reminder form for
explicit review and saving. Later box edits do not reschedule reminders.

Box content and item details are encrypted, exported with their owner profile and
deleted with it. Both English and Spanish are supported.
