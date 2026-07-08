# Run using bin/ci

CI.run do
  signoff_command = [
    "git diff --quiet",
    "git diff --cached --quiet",
    "git merge-base --is-ancestor HEAD @{upstream}",
    "gh signoff create -f"
  ].join(" && ")

  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: JavaScript", "bun run lint:js"

  step "Security: Bun audit", "bun audit"
  step "Security: Gem audit", "bin/bundler-audit check --update"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: RSpec", "bundle exec rspec"

  # Set CI_SIGNOFF=false to run the full gate without writing the GitHub commit status.
  if success?
    if ENV.fetch("CI_SIGNOFF", "true") == "false"
      heading "Signoff: skipped", "CI_SIGNOFF=false", type: :title
    else
      step "Signoff: All systems go. Ready for merge and deploy.", signoff_command
    end
  else
    failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  end
end
