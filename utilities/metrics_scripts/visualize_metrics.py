import os
import sys

import pandas as pd
import matplotlib.pyplot as plt

if len(sys.argv) == 2:
    metrics_path = sys.argv[1]
else:
    metrics_path = "metrics_joined.csv"


def load_metrics(metrics_path):
    df = pd.read_csv(metrics_path)
    print(df)
    return df


def visualize(metrics):
    """ create your own plots here. """
    metrics.plot(x='iter', y=['alive_rabbits', 'lettuce'])


metrics = load_metrics(metrics_path)
visualize(metrics)
plt.show()
