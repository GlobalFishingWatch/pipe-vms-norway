#!/usr/bin/env python

"""
Setup script for pipe-vms-norway
"""
from setuptools import setup

import codecs

PACKAGE_NAME='pipe-vms-norway'

package = __import__('pipe_vms_norway')

with codecs.open('README.md', encoding='utf-8') as f:
    readme = f.read().strip()

setup(
    author=package.__author__,
    author_email=package.__email__,
    description=package.__doc__.strip(),
    include_package_data=True,
    license="Apache 2.0",
    long_description=readme,
    name=PACKAGE_NAME,
    py_modules=[],
    url=package.__source__,
    version=package.__version__,
    zip_safe=True
)
