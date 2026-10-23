#!/usr/bin/env ruby
# Kept for older local workflows; all targets now come from the same generator.
exec('python3', File.join(__dir__, 'gen_project.py'))
