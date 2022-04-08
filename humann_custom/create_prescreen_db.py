#!/project/def-ilafores/common/humann3/bin/python

import os
import re
import sys
import logging
import humann.utilities
import humann.config
from humann.search import prescreen

if __name__ == '__main__':
    choco_db = sys.argv[0]
    bugs = sys.argv[1]
    print("choco_db=" + choco_db)
    print("bugs=" + bugs)
    #prescreen.create_custom_database("/project/def-ilafores/common/humann3/lib/python3.7/site-packages/humann/data/chocophlan", "boreal_moss-bugs_list.MPA.TXT")
