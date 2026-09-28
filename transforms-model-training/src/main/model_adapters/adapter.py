"""
Meridian: model adapter.

Wraps the trained logistic regression so Foundry can save, load, and call it.
    __init__  stores the fitted model
    api()     declares the input and output contract
    predict() scores incoming counties
"""

import palantir_models as pm

FEATURES = [
    "obgyn_pc", "obgyn_tot", "do_obgyn_pc",
    "obgyn_55plus_share", "births_per_1000",
    "hpsa_score", "mcta_score",
    "min_margin", "has_hospital",
]


class MeridianClosureAdapter(pm.ModelAdapter):

    # on publish, serialize whatever __init__ stores (dill)
    @pm.auto_serialize
    def __init__(self, model):
        self.model = model

    @classmethod
    def api(cls):
        # what a caller must send, and what comes back;
        # Foundry validates frames against this before predict runs
        inputs = {
            "input_df": pm.Pandas(columns=[(f, float) for f in FEATURES])
        }
        outputs = {
            "output_df": pm.Pandas(
                columns=[(f, float) for f in FEATURES] + [("closure_probability", float)]
            )
        }
        return inputs, outputs

    def predict(self, input_df):
        # copy so the caller's frame is left unchanged
        scored = input_df.copy()
        scored["closure_probability"] = self.model.predict_proba(input_df[FEATURES])[:, 1]
        return scored