#!/home/def-ilafores/programs/ILL_pipelineshumann3/bin/python

import os
import re
import sys
import logging
import humann.utilities
import humann.config
from humann.search import prescreen

if __name__ == '__main__':
    choco_db = sys.argv[1]
    bugs = sys.argv[2]
    print("chocophlan db=" + choco_db)
    print("bugs file=" + bugs)
    prescreen.create_custom_database(choco_db, bugs)
