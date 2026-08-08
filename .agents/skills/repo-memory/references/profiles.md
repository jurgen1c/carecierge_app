<!-- agent-memory:generated-reference repo-memory/profiles.md -->
# Profiles

Profile traits are small, explainable context snippets. They are not personalities and they do not override system, developer, user, or repository instructions.

Useful commands:

```bash
agent-memory profiles list
agent-memory profiles match --task "review auth changes"
agent-memory profiles show profile_trait.review.findings_first
agent-memory context --task "review auth changes" --profile review
agent-memory context --task "review auth changes" --profile-trait profile_trait.review.findings_first
```

Use profile traits for retrieval bias, output contracts, verification bias, risk lens, and scope control. Keep snippets short and resolve conflicts through `conflicts_with`.
