#!/usr/bin/env rackup
require File.dirname(__FILE__) + "/app"

run SaveToGSheet.new('config.yaml')
