"""
Meridian: train the closure-risk model.

Fits a logistic regression on rural county-years from observation years
<= 2022 and publishes it to Foundry as a model asset. Features are
standardized so coefficients are comparable, and classes are weighted
because only about 2.5% of county-years are closures.

Evaluation on the held-out 2023 year happens in run_inference.py.
"""

from transforms.api import transform, Input, lightweight
from palantir_models.transforms import ModelOutput
from main.model_adapters.adapter import MeridianClosureAdapter
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

FEATURES = [
    "obgyn_pc", "obgyn_tot", "do_obgyn_pc",
    "obgyn_55plus_share", "births_per_1000",
    "hpsa_score", "mcta_score",
    "min_margin", "has_hospital",
]
KEYS = ["fips_st_cnty", "year"]
LABEL = "closure_next"


def train_model(training_df, experiment):
    params = {"class_weight": "balanced", "max_iter": 1000}
    experiment.log_params(params)

    training_df = training_df.dropna(subset=FEATURES)
    print("rows:", len(training_df))
    print("positives:", int(training_df[LABEL].sum()))
    print("nulls per feature:", training_df[FEATURES].isna().sum().to_dict())

    x_train = training_df[FEATURES]
    y_train = training_df[LABEL]

    model = Pipeline([
        ("scaler", StandardScaler()),
        ("clf", LogisticRegression(**params)),
    ])
    model.fit(x_train, y_train)

    print("coefs:", dict(zip(FEATURES, model.named_steps["clf"].coef_[0].round(4))))

    train_ap = average_precision_score(y_train, model.predict_proba(x_train)[:, 1])
    experiment.log_metric("train_auc_pr", train_ap)
    return model


@lightweight
@transform(
    training_data_input=Input("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/meridian_train"),
    model_output=ModelOutput("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/model_closure_output"),
)
def compute(training_data_input, model_output):
    training_df = training_data_input.pandas()
    experiment = model_output.create_experiment("meridian-logreg-v6_final")

    model = train_model(training_df, experiment)

    foundry_model = MeridianClosureAdapter(model)

    model_output.publish(
        model_adapter=foundry_model,
        experiment=experiment,
    )