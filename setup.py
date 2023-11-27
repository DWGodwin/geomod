from setuptools import setup, find_packages

setup(
    name='py-geomod',
    version='1.0.0',
    author='Fatameh Kordi, Denys Godwin',
    author_email='fkordi@clarku.edu',
    description='A Python module to predict future land cover maps based on suitability and historical data.',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='http://github.com/dwgodwin/py-geomod',
    packages=find_packages(),
    install_requires=[
        'numpy',
    ],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'Intended Audience :: Science/Research',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
    ],
    keywords='land cover prediction, environmental modeling, GIS',

    include_package_data=True,

    entry_points={
        'console_scripts': [
            'py-geomod-predict=py-geomod.py-geomod:main',
        ],
    },

    python_requires='>=3.7',
)