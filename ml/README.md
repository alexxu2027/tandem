# ML

Station availability prediction. **Nothing here is implemented yet.**

| Package | Purpose |
| --- | --- |
| `features/` | Feature engineering shared by training and serving |
| `training/` | Model training pipelines |
| `evaluation/` | Backtesting, calibration, error metrics |
| `notebooks/` | Exploratory analysis only (see its README) |

## Why this is separate from the backend

Training pulls in heavy dependencies that the API has no use for. Keeping them
apart means the backend image stays small; the backend consumes trained
artifacts through `backend/app/prediction/`.

## Intended shape

The core problem: given a station, a future arrival time, and current
conditions, predict the probability that a bike (or a dock) will be available
when the rider gets there.

- Features are computed identically in training and serving to avoid skew.
- Evaluation splits by time, never at random — random splits leak the future
  into the training set and produce misleading scores.
- Trained artifacts are gitignored; they belong in object storage or a model
  registry, referenced by version.
