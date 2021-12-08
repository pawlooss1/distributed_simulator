"""
script joining metrics from different workers, aggregating each column as specified.
Each worker file should be named x_y.txt, where x and y denote worker's position.
First column in the metrics file must always be iteration number
You must specify column names (in proper order) and aggregation function in 'names_aggs'
"""
import os
import sys

import numpy as np
import pandas as pd

names_aggs = [('alive_rabbits', np.sum), ('sum_rabbits', np.sum), ('avg_rabbits', np.mean),
              ('lettuce', np.sum), ('sum_lettuce', np.sum), ('avg_lettuce', np.mean)]
output_path = "metrics_joined.csv"

if len(sys.argv) == 2:
    metrics_dir = sys.argv[1]
else:
    projects_dir = "/Users/agnieszkadutka/repos/inz/distributed_simulator"
    simulation = 'rabbits'
    metrics_dir = f"{projects_dir}/examples/{simulation}/metrics"
    print(f"usage: python metrics_adder.py metrics_dir"
          f"\nusing default metrics_dir: {metrics_dir}\n")


def read_workers_metrics(metrics_dir, verbose=False):
    """ reads grids from all the workers and converts them to frames.
    returns: map(worker_loc => frames)"""
    workers = {}
    for worker_file in os.listdir(metrics_dir):
        worker_file_path = os.path.join(metrics_dir, worker_file)
        worker_file_name = worker_file.split(".")[0]
        (x, y) = [int(c) for c in worker_file_name.split("_")]
        if verbose:
            print(f"processing worker {(x, y)}")
        workers[(x, y)] = read_metrics(worker_file_path)
    return workers


def read_metrics(worker_file_path):
    col_names = ["iter"]+[pair[0] for pair in names_aggs]
    df = pd.read_csv(worker_file_path, header=None,
                     sep=" ", names=col_names)
    return df


def join_workers(workers):
    df = workers[(1, 1)]
    for worker in workers.values():
        df = pd.concat([df, worker])
    aggs = {name: (name, agg) for (name, agg) in names_aggs}
    df = df.groupby("iter").agg(**aggs)
    return df


workers = read_workers_metrics(metrics_dir)
result = join_workers(workers)
print(result)
result.to_csv(output_path)
