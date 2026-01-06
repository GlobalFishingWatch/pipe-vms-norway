#!/usr/bin/env python

from setuptools import find_packages, setup

setup(
    version='v3.3.10',
    author='engineering@globalfishingwatch.org',
    packages=find_packages(exclude=['test*.*', 'tests'])
)

