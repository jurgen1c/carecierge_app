---
id: agent_workflow.authenticated_ui_uses_shared_shell_and_local_measures
type: fact
system: agent_workflow
status: current
confidence: high
severity: normal

title: Authenticated UI uses one shared shell and local reading measures

claim: >
  The application layout owns the single main landmark and shared authenticated navigation. Desktop uses a persistent 15rem sidebar from 1024px; smaller screens use a native disclosure menu with Escape, outside-focus/pointer and Turbo-cache closing. At enlarged text sizes the wordmark stays intact, the Menu control can wrap to a second row, and the open menu scrolls within the remaining viewport below the actual header height. Both derive links and role visibility from AppNavigationComponent. Main workspaces are fluid; local forms and prose retain readable measures. Today and profile layouts add useful columns according to available container width. Shared primitives use ViewComponent, dry-initializer and StyleVariantsHelper, following PRODUCT.md and DESIGN.md. Standalone form headings supply a document title only when the page has not already provided one.

source_files:
  - app/views/layouts/application.html.erb
  - app/views/components/app_navigation_component.rb
  - app/views/components/app_navigation_component.html.erb
  - app/javascript/controllers/app_menu_controller.js
  - app/assets/stylesheets/application.tailwind.css
  - PRODUCT.md
  - DESIGN.md

related_files:
  - app/helpers/workspace_helper.rb
  - app/helpers/style_variants_helper.rb
  - app/views/components/action_link_component.rb
  - app/views/components/action_link_component.html.erb
  - app/views/components/date_marker_component.rb
  - app/views/components/date_marker_component.html.erb
  - app/views/components/person_identity_component.rb
  - app/views/components/person_identity_component.html.erb
  - app/views/components/page_header_component.rb
  - app/views/components/page_header_component.html.erb
  - app/views/components/form_heading_component.rb
  - app/views/components/form_heading_component.html.erb
  - app/views/components/ui_icon_component.rb
  - app/views/components/ui_icon_component.html.erb
  - app/views/shared_relationship_spaces/index.html.erb
  - app/views/shared_relationship_spaces/_new_family.html.erb
  - app/views/event_plans/index.html.erb
  - app/views/gift_boxes/index.html.erb
  - spec/components/workspace_primitives_spec.rb
  - spec/requests/commitments_spec.rb
  - spec/components/previews/workspace_preview.rb
  - spec/requests/app_workspace_spec.rb
  - spec/system/workspace_experience_spec.rb
  - .impeccable/design.json

symbols:
  - AppNavigationComponent
  - WorkspaceHelper
  - FormHeadingComponent
  - PersonIdentityComponent
  - ActionLinkComponent
  - DateMarkerComponent
  - PageHeaderComponent

routes: []

tags:
  - agent_workflow
  - workspace
  - localization

verification:
  - bundle exec rspec spec/components/workspace_primitives_spec.rb spec/requests/app_workspace_spec.rb spec/system/workspace_experience_spec.rb
  - bun run build
  - bun run build:css
  - bun run lint:js

last_verified_commit: 7559337422b419fae6e64d414310574d502c8a70
---

# Authenticated UI uses one shared shell and local reading measures

## Claim

The application layout owns the single main landmark and shared authenticated navigation. Desktop uses a persistent 15rem sidebar from 1024px; smaller screens use a native disclosure menu with Escape, outside-focus/pointer and Turbo-cache closing. At enlarged text sizes the wordmark stays intact, the Menu control can wrap to a second row, and the open menu scrolls within the remaining viewport below the actual header height. Both derive links and role visibility from AppNavigationComponent. Main workspaces are fluid; local forms and prose retain readable measures. Today and profile layouts add useful columns according to available container width. Shared primitives use ViewComponent, dry-initializer and StyleVariantsHelper, following PRODUCT.md and DESIGN.md. Standalone form headings supply a document title only when the page has not already provided one.

## Why It Matters

A page-specific sidebar or global max-width recreates the navigation and wide-screen problems. The shell also owns document language, navigation focus and one main landmark; nested Turbo forms need local headings, not another page landmark.

## Verification

- `bundle exec rspec spec/components/workspace_primitives_spec.rb spec/requests/app_workspace_spec.rb spec/system/workspace_experience_spec.rb`
- `bun run build`
- `bun run build:css`
- `bun run lint:js`

Full `bin/ci` passed on `2d93680db18b6ed38fedaca363b27416b90346f3` with all claim-related examples included.
