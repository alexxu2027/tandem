"""Citi Bike ingestion.

Planned scope:

- GBFS real-time feeds (``station_information``, ``station_status``) polled on
  a short interval to build the availability history.
- Monthly historical trip archives for training data.

The live feed collector is in ``gbfs.py``; trip archives are not implemented yet.
"""
