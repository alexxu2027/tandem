# Notebooks

Exploratory analysis only. Notebooks are for looking at data, not for producing
anything the application depends on — once an idea works, move it into
`ml/features/`, `ml/training/` or `ml/evaluation/` where it can be tested.

## Rules

- `.ipynb_checkpoints/` is gitignored.
- Clear outputs before committing: large embedded outputs bloat the repository
  and leak data.
- Never hardcode credentials. Read them from the environment like the rest of
  the codebase does.
- Reference data through `data/` paths rather than absolute local paths.
