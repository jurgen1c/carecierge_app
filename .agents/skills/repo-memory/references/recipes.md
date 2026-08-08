<!-- agent-memory:generated-reference repo-memory/recipes.md -->
# Recipes

Recipes capture repeatable workflows for implementation, debugging, release, review, or operations.

Create recipes when a task has reusable steps that future agents should follow. A useful recipe is repository-specific, likely to recur, and contains non-obvious ordering, safeguards, decision points, or verification. Keep one workflow per recipe and link related claims by ID instead of copying claim text.

Prefer recipes for procedures and claims for facts. If a recipe depends on a constraint, represent that constraint as a claim and connect it through graph relationships.

Do not create a recipe for a one-off incident, a generic development loop such as "edit, test, commit," or a single command whose usage is already obvious.

Useful commands:

```bash
agent-memory new recipe --system auth --title "Modify student OAuth safely"
agent-memory recipes list
agent-memory recipes search "student oauth"
agent-memory recipes show recipe.auth.modify_student_oauth
agent-memory context --recipe recipe.auth.modify_student_oauth
```
