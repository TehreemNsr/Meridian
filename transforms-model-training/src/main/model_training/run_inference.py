"""
Meridian: score the 2023 test set with the published model.

Writes one row per rural county with closure_probability attached, and
reports test AUC-PR against the 2024 closures the model never saw.
"""

from transforms.api import Input, Output, lightweight, transform
from palantir_models.transforms import ModelInput
from sklearn.metrics import average_precision_score

FEATURES = [
    "obgyn_pc", "obgyn_tot", "do_obgyn_pc",
    "obgyn_55plus_share", "births_per_1000",
    "hpsa_score", "mcta_score",
    "min_margin", "has_hospital",
]
KEYS = ["fips_st_cnty", "year"]
LABEL = "closure_next"


@lightweight
@transform(
    testing_data_input=Input("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/meridian_test"),
    model_input=ModelInput("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/model_closure_output"),
    output=Output("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/meridian_scored_test"),
)
def compute(testing_data_input, model_input, output):
    raw = testing_data_input.pandas()
    df = raw.dropna(subset=FEATURES + [LABEL]).reset_index(drop=True)
    print(f"dropped {len(raw) - len(df)} rows with missing features or label")

    result = model_input.transform(df[FEATURES])
    scored = result.output_df.reset_index(drop=True)

    # both frames share a 0..n index after reset, so keys align row for row
    assert len(scored) == len(df), f"row count mismatch: scored={len(scored)} df={len(df)}"
    scored[KEYS] = df[KEYS]
    scored[LABEL] = df[LABEL]

    test_ap = average_precision_score(scored[LABEL], scored["closure_probability"])
    print("test rows:", len(scored))
    print("test positives:", int(scored[LABEL].sum()))
    print("TEST auc_pr:", test_ap)

    output.write_pandas(scored)