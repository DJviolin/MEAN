#!/bin/bash

fleetctl stop mean.service; echo "Now sleeping for 60 seconds..."; sleep 60; fleetctl unload mean.service; fleetctl destroy mean.service
