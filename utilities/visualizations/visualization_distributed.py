""" Script displays and saves to an mp4 file simulation reconstructed from saved grids from multiple workers.

Needed arguments:
grids_dir: directory with folders from each worker, where all grids' snapshots are stored.
Each worker produces a folder with a name 'row_col' where row and column number represents its position.
In each folder there are grids' snapshots:
        - each file is expected to contain numbers separated by space:
        - first 2 numbers are x and y dimension, respectively
        - next are x * y * 9, where each consecutive 9 numbers describe state of single cell (object and directions)
config_path: path to a csv file specifying animation configuration - currently only color specification available.
Needed columns are: label, number and color.

example config file:
    label,number,color
    rabbit,1,yellow
    lettuce,2,green
"""

import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from matplotlib import colors
import csv
import sys

def read_workers_grids(grids_dir, verbose=False):
    """ reads grids from all the workers and converts them to frames.
    returns: map(worker_loc => frames)"""
    workers = {}
    for worker_dir in os.listdir(grids_dir):
        worker_dir_path = os.path.join(grids_dir, worker_dir)
        (x, y) = [int(c) for c in worker_dir.split("_")]
        if verbose:
            print(f"processing worker {(x, y)}")
        workers[(x, y)] = read_grids(worker_dir_path)
    return workers


def read_grids(frames_dir, verbose=False):
    """ returns: numpy array of shape (n_frames, x_size, y_size, 9)"""
    x_size, y_size = 0, 0
    n_frames = len(os.listdir(frames_dir))
    grids = [0 for _x in range(n_frames)]

    for filename in os.listdir(frames_dir):
        grid_nr = int(filename.split("_")[1].split(".")[0]) - 1
        path = os.path.join(frames_dir, filename)
        with open(path, 'r') as f:
            file = f.read()
        file_int = [int(c) for c in file.split(" ")]
        [x_size, y_size] = file_int[:2]
        grid = file_int[2:]
        grid = np.array(grid).reshape((x_size, y_size, 9))
        grid = grid[1:-1, 1:-1]
        grids[grid_nr] = grid
    grids = np.array(grids)
    if verbose:
        print("--read_grids")
        print(f"found {n_frames} files")
        print(f"read grid shape: {x_size} x {y_size}")
    return grids


def grids_to_frames(grids, config_path, verbose=False):
    """ transform collection of 3d grids () into 2d frames"""
    color_map = read_config(config_path, verbose)
    objects, signals = to_objects_and_signals(grids)
    objects_rgb = objects_to_colors(objects, color_map)
    signals_rgb = signals_to_colors(signals)
    return objects_rgb + signals_rgb


def read_config(config_path, verbose=False):
    """ returns map {object number (int): color name (str)}"""
    with open(config_path, mode='r') as config_file:
        csv_reader = csv.DictReader(config_file, delimiter=',')
        nr_color_map = {0: 'black'}
        color_label_map = {'black': 'empty'}
        for row in csv_reader:
            nr_color_map[int(row['number'])] = row['color']
            color_label_map[row['color']] = row['label']
    if verbose:
        print("--read_config")
        print(f"color - object map: {color_label_map}")
        print(f"number - color map: {nr_color_map}")
    return nr_color_map


def to_objects_and_signals(grids):
    """ :param grids: collection of 3d grids, shape: (n_frames, x_size, y_size, 9)
        :returns:
            objects: np.array of shape  (n_frames, x_size, y_size)
            signals: np.array of shape  (n_frames, x_size, y_size)
            (sum of signals in all direction for a given cell)
     """
    objects = grids[:, :, :, 0]
    signals_3d = grids[:, :, :, 1:]
    signals_summed = np.sum(signals_3d, axis=3)
    signals = adjust_signals(signals_summed, objects)
    return objects, signals


def adjust_signals(signals, objects):
    """ normalize signals to fit in [0, 1] range and zero them on objects' positions """
    signals = (signals - np.amin(signals))
    signals = signals / np.amax(signals)
    return np.where(objects == 0, signals, 0)


def objects_to_colors(objects, color_map):
    """ map each object to appropriate color based on given color_map
        :param objects: np.array of shape (n_frames, x_size, y_size)
        :param color_map: maps number representing an object to color
        :returns np.array of shape (n_frames, x_size, y_size, 3)
    """
    shape = objects.shape
    objects_rgb = [get_object_color(obj, color_map)
                   for obj in objects.flatten()]
    return np.array(objects_rgb).reshape(*shape, -1)


def get_object_color(obj, color_map):
    " :returns 3d tuple (r, g, b), with each value being a float between 0 and 1 "
    color_name = color_map[obj]
    return colors.to_rgb(color_name)


def signals_to_colors(signals):
    """ map each signal to appropriate color in gray scale, where white - no signal, black - maximum signal
        :param signals: np.array of shape  (n_frames, x_size, y_size), of values in range [0, 1]
        :returns: np.array of shape  (n_frames, x_size, y_size, 3)
    """
    shape = signals.shape
    signals_rgb = [np.array(colors.to_rgb('white')) *
                   signal for signal in signals.flatten()]
    return np.array(signals_rgb).reshape(*shape, -1)


def get_signal_color(signal):
    " :returns 3d ARRAY [r, g, b], with each value being a float between 0 and 1 "
    return np.array(colors.to_rgb('white')) * signal


def join_workers_grids(workers):
    joined_grids = None
    x = 1
    while (x, 1) in workers.keys():
        joined_row = workers[(x, 1)]
        y = 2
        while (1, y) in workers.keys():
            joined_row = np.concatenate((joined_row, workers[(x, y)]), axis=2)
            y += 1
        joined_grids = joined_row if joined_grids is None else np.concatenate(
            (joined_grids, joined_row), axis=1)
        x += 1
    return joined_grids


projects_dir = sys.argv[1]
grids_dir = f"{projects_dir}/lib/grid_iterations"
config_path = f"{projects_dir}/config/animation_config.csv"

workers = read_workers_grids(grids_dir)
grids = join_workers_grids(workers)
frames = grids_to_frames(grids, config_path)

print(f"found workers: {workers.keys()}")
(n_frames, x, y, _colors) = frames.shape
print(f"created {n_frames} frames of size {(x,y)}")

fig, ax = plt.subplots()

ims = []
for frame in frames:
    im = ax.imshow(frame, animated=True)
    ims.append([im])

ani = animation.ArtistAnimation(fig, ims, interval=500, blit=True,
                                repeat=False)

ani.save("movie.mp4")
plt.show()
