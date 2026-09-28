"""
Meridian: feature selection and temporal split.

Reads the rural county-year training table, derives births per 1,000
population, keeps the model columns, and splits by observation year:
    train = observation years <= 2022
    test  = observation year 2023 (labels are the 2024 closures)

A temporal split is used instead of a random one so the model is never
trained on years later than those it is evaluated on.
"""

from transforms.api import transform, Input, Output
from pyspark.sql import functions as F

FEATURES = [
    "obgyn_pc", "obgyn_tot", "do_obgyn_pc",
    "obgyn_55plus_share", "births_per_1000",
    "hpsa_score", "mcta_score",
    "min_margin", "has_hospital",
]
KEYS = ["fips_st_cnty", "year"]
LABEL = "closure_next"


@transform(
    training_table=Input("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/meridian_training_table"),
    train_output=Output("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/meridian_train"),
    test_output=Output("/Tehreem Nasir-f0cfdb/Meridian_Official_Build_TN/Datasets Clean/meridian_test"),
)
def compute(training_table, train_output, test_output):
    df = training_table.dataframe()

    # births and population are strongly correlated; a single rate replaces both
    df = df.withColumn("births_per_1000", F.col("births") / F.col("popn") * 1000)

    df = df.select(KEYS + FEATURES + [LABEL])

    train = df.filter(df.year <= 2022)
    test = df.filter(df.year == 2023)

    train_output.write_dataframe(train)
    test_output.write_dataframe(test)