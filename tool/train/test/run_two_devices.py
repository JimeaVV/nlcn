"""Runs the training notebook with the CPU split into two devices, so
MirroredStrategy really trains on two replicas, like Kaggle's T4 x2.

    python tool/train/test/run_two_devices.py <notebook.py>
"""
import runpy
import sys

import tensorflow as tf

cpu = tf.config.list_physical_devices('CPU')[0]
tf.config.set_logical_device_configuration(
    cpu, [tf.config.LogicalDeviceConfiguration()] * 2)
_mirrored = tf.distribute.MirroredStrategy
tf.distribute.MirroredStrategy = lambda *a, **k: _mirrored(
    devices=['/cpu:0', '/cpu:1'])
runpy.run_path(sys.argv[1], run_name='__main__')
