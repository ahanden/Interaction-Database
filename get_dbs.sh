#!/bin/bash

grep "db" $1 | sed 's/.*db="//' | sed 's/".*//' | sort -u
