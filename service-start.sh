#!/bin/bash

fleetctl submit ./mean.service && fleetctl start mean.service; fleetctl journal -follow=true -lines=50 mean
