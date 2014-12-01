#!/bin/bash

ps -o %y -p $$ | tail -1 | cut -d/ -f1
